# ADR-043: Aufgeschobene Pixel-Verschiebung — Puffern statt Neubau je Tastendruck

## Status
✅ **Umgesetzt** (Spec 010 US1, Perf-Review nach Hardware-Test, 2026-09-01) –
`Source/LayerModel.lua`, `Source/EditorRoom.lua`, `Source/ZoomRoom.lua`

## Kontext
US1 (B + Pfeiltaste in der Zoom View verschiebt den Inhalt der aktiven Ebene
um 1 nativen Pixel, Wrap-Around) war seit Spec 010 als EINE Funktion gebaut:
`LayerModel.shiftLayerContent` dekodierte die volle 400×240-Ebene, verschob
sie in ein zweites Raster und baute alle 375 Tiles neu auf (inkl. Hash +
Dedup) — bei **jedem einzelnen Tastendruck**.

Der Nutzer meldete nach dem Testen auf echter Hardware: das Verschieben ist
"zu inperformant". Eine Standalone-Messung (375-Tile-Ebene, EIN Schritt)
bestaetigt das quantitativ:

| Operation | Anzahl |
|---|---|
| `image:sample()` (Decode + Hash) | **192.000** |
| `image.new()` (Tile-Neubau) | 375 |
| `drawPixel()` | 96.000 |
| `pushContext()`/`popContext()` | 375 |
| Wanduhr (Laptop, Vanilla-Lua) | 212 ms |

Auf dem Playdate (168 MHz Cortex-M7, deutlich langsamerer Lua-Interpreter
als ein Laptop) ist das plausibel **mehrere hundert ms bis niedrige
Sekunden je Tastendruck** — spuerbar ruckelig beim Halten der Pfeiltaste,
genau das im `spec.md`-Risk-Record vorhergesehene Risiko ("Tile
recalculation on every pixel shift could cause lag").

## Entscheidungs-Treiber
- **Ein Druck = ein sichtbarer Schritt**, aber der teure Teil (375-Tile-
  Rebuild + Rehash) muss nicht bei jedem Druck bezahlt werden — nur EINMAL
  fuer eine ganze Verschiebe-Geste.
- **Kein Datenverlust**: eine offene, noch nicht materialisierte Sitzung
  darf nie verloren gehen — auch nicht beim abrupten Verlassen (Home-Taste
  waehrend B noch gehalten).
- **Malen respektiert den Shift, nicht umgekehrt**: malt der Nutzer
  zwischen zwei Schueben (B kurz losgelassen, dann A), darf der Flush den
  Malstrich nicht ueberschreiben.
- **Konsistente Live-Vorschau**: die Zoom-View-Anzeige muss bei jedem
  Tastendruck aktuell aussehen, auch waehrend die kanonischen Tiles noch
  nicht gebaut sind.
- Headless-Testbarkeit bleibt erhalten (Constitution V) — der Mock kennt
  `image:draw()` nicht als Blit-Operation; eine reine Blit-Loesung waere
  ungetestet.

## Optionen

| Option | Vorteile | Nachteile |
|--------|----------|-----------|
| **A: Verschiebung puffern — einmal dekodieren, Tastendruecke nur als Wrap-Versatz akkumulieren, am Ende der Geste EINMAL materialisieren** | 375-Tile-Rebuild nur 1x statt Nx; Decode nur 1x; bleibt auf dem bestehenden Pure-Lua-Pfad (Mock/Tests unveraendert gueltig) | Materialisierung muss an jeder Stelle nachgezogen werden, die kanonische Tiles/Positionen braucht (mehrere Aufrufstellen statt einer) |
| B: Rebuild pro Tastendruck beschleunigen (Blit-pro-Tile statt 256×`drawPixel`, `image:draw()` statt Pixel-Schleife) | einfacherer Kontrollfluss (keine Sitzung) | bleibt O(375 Tiles) je Tastendruck (~50 ms geschaetzt, immer noch spuerbar); `image:draw()` ist im Headless-Mock ein No-op — bricht die bestehende Shift-Testabdeckung, ohne den Mock zu erweitern |
| C: Tastendruecke per Timer entprellen (Debounce), dann Option B | wenig strukturelle Aenderung | ein Playdate-Tastendruck feuert `*ButtonDown` nicht wiederholt (kein SDK-Auto-Repeat) — ein schneller Tipper bleibt beim vollen Einzelschritt-Preis; loest das Problem nicht an der Wurzel |

## Entscheidung
**Option A.** `LayerModel.shiftLayerContent` bleibt als synchroner
Einzelschritt-Wrapper bestehen (bestehende Aufrufer/Tests unveraendert
gueltig), zerlegt aber intern in drei Bausteine:

```
decodeLayerGrid(layer, getTile)                        -- 1x: alle 96000 Pixel lesen
materializeShiftedGrid(layer, grid, offX, offY, reg)    -- 1x: 375 Tiles bauen + hashen
imageFromGrid(grid, offX, offY, tileCol0, tileRow0)     -- Live-Vorschau, EIN Tile
```

**`EditorRoom.shiftActiveLayer(direction)`** dekodiert die aktive Ebene nur
beim ERSTEN Tastendruck einer Sitzung (`pendingShift = {frame, layerRef,
grid, offX, offY}`); jeder weitere Tastendruck derselben Sitzung
inkrementiert nur `offX`/`offY` modulo 400/240 — **O(1)**. Materialisiert
wird ausschliesslich in **`EditorRoom:flushLayerShift()`**: baut die 375
Tiles aus `grid` durch den Wrap-Versatz gelesen (`materializeShiftedGrid`)
und kompositiert den Frame neu. Idempotent (No-op ohne offene Sitzung).

**Offset-Algebra** (Korrektheitsbeweis fuer die Aufschiebung): Modulo-
Arithmetik ist additiv — `((x % n) - b) % n == (x - b) % n`. Also ergibt N
sequentielle 1px-Verschiebungen um `(dx,dy)` dieselbe gelesene Position wie
eine einzige Verschiebung um `(N·dx, N·dy)`. N gepufferte Tastendruecke +
EIN Flush sind damit exakt aequivalent zu N sofortigen
`shiftLayerContent`-Aufrufen — bewiesen durch einen Vergleichstest
(`tests/headless_tests.lua`: "N kleine Schritte == EIN grosser Schritt").

**`EditorRoom.buildZoomContext()`** erkennt eine offene Sitzung fuer die
aktive Ebene (`pendingShift.layerRef == layer`) und synthetisiert die 3×3-
Vorschau-Slots direkt aus `pendingShift.grid` (`LayerModel.imageFromGrid`,
9 Tiles × 256 Pixel statt 375 Tiles × 256 Pixel + Hash) — die Zoom-View
bleibt bei jedem Tastendruck visuell aktuell, ohne die Sitzung zu
materialisieren. `slot.originalIndex` bleibt dabei bewusst der alte,
noch nicht geflushte Wert; nichts liest ihn, bevor ein Flush ihn aktuell
gemacht hat (siehe Flush-Aufrufstellen unten).

### Flush-Aufrufstellen (MUSS vor jedem kanonischen Zugriff laufen)
- `EditorRoom:applyTileEdits()` — Malstrich zuerst gegen den geflushten
  Stand anwenden (sonst wuerde ein spaeterer Flush den Strich ueberschreiben).
- `ZoomRoom`: `zoomIntoPixelRoom()` (sonst zeigt "All Similar" im PixelRoom
  auf einen verwaisten Tile-Index), `commitAndReturnToEditor()`,
  `commitForTerminate()`, neuer `BButtonUp`-Handler (natuerlicher
  Sitzungsabschluss, aber kein Muss — jeder echte Ausgang flusht bereits
  selbst).
- `EditorRoom:entered()` (defensives Sicherheitsnetz) und
  `buildPauseMenuImage()` (Home-Taste kann waehrend gehaltenem B feuern,
  kein Tastenereignis in der ZoomRoom wuerde das sonst abfangen).

### Begruendung
- Der teure Teil (Rebuild + Rehash) faellt von **O(Tastendruecke)** auf
  **O(1) pro Geste** — unabhaengig davon, wie oft die Pfeiltaste waehrend
  einer B-Haltung gedrueckt wird.
- Bleibt vollstaendig auf dem bestehenden Pure-Lua-Decode/-Rebuild-Pfad;
  keine Blit-basierte Abkuerzung noetig, die im Headless-Mock ungetestet
  bliebe.
- Die Zoom-View-Vorschau bleibt pixelgenau aktuell, weil sie direkt aus
  demselben gepufferten Raster liest, das am Ende materialisiert wird —
  keine zwei Quellen der Wahrheit.

### Konsequenzen
- **Positiv**: Halten der Pfeiltaste fuehlt sich am Geraet direkt an;
  10 gepufferte Schritte kosten (Decode + O(1)×10 + 1 Flush) statt
  10× (Decode + Rebuild + Rehash).
- **Negativ**: `pendingShift` fuegt einen zweiten, impliziten
  Session-Zustand ein, den neuer Code an den kanonischen Daten
  (`imageData.frameLayers`/`frames`/`imagetable`) bedenken muss — ein
  neuer EditorRoom-Pfad, der diese Daten liest, MUSS zuerst
  `flushLayerShift()` aufrufen oder die pendingShift-Semantik explizit
  respektieren.
- **Test-Nachtrag**: `newMockImage` bekam eine `copy()`-Methode
  (SDK-Aequivalent) — bislang von keinem Test beruehrt, weil
  `ZoomRoom.buildWorkingImage()` den `copy()`-Pfad nur bei einem echten,
  nicht-nil `originalImage` nimmt; die gepufferte Vorschau liefert jetzt
  ein solches synthetisiertes Bild.
- Headless: vier neue Testabschnitte (Pufferung + Offset-Algebra,
  Malen-fluscht-zuerst, ZoomRoom-Flush-Aufrufstellen inkl. Terminate-ohne-
  B-Release, Reinzoomen-fluscht-zuerst) + Fix der bestehenden
  `shiftActiveLayer`-Assertion (jetzt mit explizitem `flushLayerShift()`).
  393 Assertions gruen, `pdc` sauber, buildNumber 29.

## Offen (Phase 7, Simulator/Hardware)
- Geraete-Messung der tatsaechlichen Framerate beim Halten der Pfeiltaste
  (T053/T054) — die Standalone-Messung lief auf dem Laptop unter Vanilla-
  Lua, nicht im Playdate-Simulator.
- Option B (Blit-pro-Tile statt `drawPixel`-Schleife) bleibt als weitere
  Beschleunigung von `materializeShiftedGrid` selbst offen, falls ein
  einzelner Flush (z.B. am Gestenende) noch spuerbar ist; erfordert eine
  Mock-Erweiterung fuer `image:draw()`.

## Related
- [ADR-041: Compositing-Cache und Frame-Verwaltung](ADR-041-Compositing-Cache-und-Frame-Verwaltung.md)
- [ADR-035: Zoom-Room-Redraw-Cache](ADR-035-Zoom-Room-Redraw-Cache.md) (dasselbe Muster — Cache statt Neuberechnung pro Interaktion — hier auf die Verschiebe-Geste angewendet)
- [specs/010-layer-management-with-transparency/research.md: R6](../../specs/010-layer-management-with-transparency/research.md)
- [specs/010-layer-management-with-transparency/spec.md: FR-002, Architecture Governance, Technical Debt & Risk Mitigation](../../specs/010-layer-management-with-transparency/spec.md)
