# ADR-043: Pixel-Verschiebung wirkt nur auf die Cursor-Zelle (2-Tile-Streifen)

## Status
✅ **Umgesetzt** (Spec 010 US1, Einschraenkung aus dem Hardware-Test,
2026-09-01) – `Source/LayerModel.lua` (`shiftTileContent`),
`Source/EditorRoom.lua` (`shiftActiveLayer`), `Source/ZoomRoom.lua`

## Kontext
US1 verschiebt in der Zoom View per **B + Pfeiltaste** Pixelinhalt um genau
1 nativen Pixel. Urspruenglich (Spec 010) verschob das den **gesamten
400×240-Inhalt der aktiven Ebene** mit Wrap-Around und baute alle 375 Tiles
neu auf.

Zwei aufeinanderfolgende Rueckmeldungen aus dem Hardware-Test:

1. **Zu langsam.** Gemessen ~192.000 `image:sample()`-Aufrufe + 375
   `image.new()` **pro Tastendruck** — auf dem Geraet spuerbar ruckelig.
   *(Erste Loesung, verworfen: dieselbe Ganz-Ebenen-Verschiebung, aber die
   Materialisierung ans Gesten-Ende aufschieben — `pendingShift` /
   `flushLayerShift`. Wurde durch Punkt 2 hinfaellig.)*
2. **Falscher Umfang.** Verschoben werden soll nur die **Zelle, auf der der
   Cursor steht**, nicht der ganze Screen. Man soll damit eine Tile in eine
   benachbarte schieben koennen; der Inhalt wandert in den Nachbarn und
   **bleibt dort**, dessen Pixel werden ersetzt.

## Entscheidungs-Treiber
- Verschieben ist eine **lokale** Operation (eine Zelle, ein Nachbar), nicht
  screen-weit.
- Der Inhalt soll bei wiederholtem Druecken Spalte fuer Spalte in den
  Nachbarn wandern und dort bleiben (**Akkumulation**), nicht nur als
  1px-Streifen kurz aufblitzen (der Nutzer hat sich beim Nachfragen
  ausdruecklich fuer die Akkumulation entschieden).
- „nur die Cursor-Zelle wird verschoben“ **und** „Inhalt wandert in den
  Nachbarn“ zugleich: der Nachbar verschiebt sich mit, aber sein eigener
  Inhalt wird dabei ersetzt/rausgeschoben — nicht an eine dritte Zelle
  weitergereicht.
- Nach der Umfangs-Einschraenkung ist die Operation ohnehin billig
  (~2500 Ops/Tastendruck) → **synchron** je Tastendruck, keine
  aufgeschobene Materialisierung noetig.
- Headless-Testbarkeit (Constitution V): bleibt auf dem Pure-Lua-Decode/
  Rebuild-Pfad, kein `image:draw()`-Blit (Mock-No-op).

## Optionen

| Option | Vorteile | Nachteile |
|--------|----------|-----------|
| **A: 2-Tile-Streifen (Cursor-Zelle + der eine Nachbar in Schieberichtung) als Ganzes um 1px schieben; abgewandte Kante der Cursor-Zelle -> Nicht-Tinte, abgewandte Kante des Nachbarn faellt weg** | lokal (max. 2 Tiles); Inhalt wandert + bleibt; synchron billig genug; kein Wrap noetig | der Nachbar aendert sich mit (aber nur der EINE Nachbar) |
| B: nur die Cursor-Zelle schieben, der austretende 1px-Streifen ersetzt bloss den Randstreifen des Nachbarn (kein Mitschieben) | minimal invasiv | Inhalt akkumuliert nicht im Nachbarn — jeder Druck ueberschreibt denselben Streifen; „Tile in Nachbar schieben“ funktioniert nicht wie erwartet (vom Nutzer explizit abgelehnt) |
| C: Ganz-Ebenen-Verschiebung + aufgeschobene Materialisierung (erste ADR-043-Fassung) | loest nur das Perf-Problem | falscher Umfang (ganzer Screen); `pendingShift` als zweiter impliziter Session-Zustand |

## Entscheidung
**Option A.** `LayerModel.shiftTileContent(entry, active1, cellIdx, direction,
getTile, registerTile)`:

- `shiftDelta(direction)` → `(dx,dy)` fuer den 1px-Schritt.
- **Ausgangszelle** (`cellIdx`): jedes Pixel kommt von `(px-dx, py-dy)`;
  liegt die Quelle ausserhalb 0..15, wird die von der Schieberichtung
  abgewandte Randkante mit `offState` gefuellt (ebenenabhaengig: `EMPTY`/
  weiss auf der Basisebene, `TRANSPARENT` auf den oberen Ebenen).
- **Nachbar in Schieberichtung** (`neighborIdx`, sofern im 25×15-Raster):
  ebenfalls um 1px in dieselbe Richtung geschoben; die der Ausgangszelle
  **zugewandte** Randkante bekommt den austretenden Streifen der
  Ausgangszelle (`cur[edgeY or py][edgeX or px]`), die **abgewandte**
  Randkante faellt weg (kein Wrap, keine dritte Zelle).
- Fehlt der Nachbar (Rasterrand), aendert sich **nur** die Ausgangszelle;
  der austretende Streifen ist weg.
- `writeCell`: dedupliziert ueber den vom Aufrufer injizierten
  `registerTile`; eine komplett transparente Zelle wird auf oberen Ebenen
  als `ABSENT` (0) abgelegt (wie bisher).
- Rueckgabe: sortierte Liste der geaenderten Zell-Indizes (1 oder 2).

`EditorRoom:shiftActiveLayer(direction, cellIdx)` ruft `shiftTileContent`
und `recompositeCell` fuer jede geaenderte Zelle; ohne `cellIdx` die Zelle
unter dem Editor-Cursor (`cursorCellIndex()`). `ZoomRoom.shiftActiveLayerContent`
ermittelt die Zelle unter dem **Zoom-Cursor**
(`slots[getSlotForCell(cursorRow,cursorCol)].frameIndexPos`), reicht sie
durch und laesst den Zoom-Cursor nach dem Shift stehen — so schiebt
wiederholtes B + Pfeil dieselbe Zelle weiter.

### Begruendung
- Synchron (~2500 Ops) statt der ~192.000 Ops der Ganz-Ebenen-Version →
  keine `pendingShift`/`flushLayerShift`-Mechanik, kein zweiter impliziter
  Session-Zustand, keine Flush-Aufrufstellen zu pflegen.
- Der 2-Tile-Streifen ist die einzige Lesart, die „nur die Cursor-Zelle
  verschieben“ **und** „Inhalt wandert in den Nachbarn und bleibt“ zugleich
  erfuellt.
- Kein Wrap: an der Kante geht Inhalt bewusst verloren (der Nutzer akzeptiert
  das explizit — „wenn dort schon Pixel sind, werden diese einfach
  ersetzt“). Das frueher fuer die Ganz-Ebenen-Version gewaehlte Wrap-Around
  (kein Datenverlust) entfaellt damit.

### Konsequenzen
- **Positiv**: lokal + billig + synchron; das gesamte Deferral-Geruest der
  ersten ADR-043-Fassung (`pendingShift`, `flushLayerShift`,
  `buildZoomContext`-Synthese, `BButtonUp`, 6 Flush-Aufrufstellen) faellt
  ersatzlos weg.
- **Negativ**: an der Cursor-Zelle vorbeigeschobener Inhalt geht am
  Rasterrand verloren; der eine Nachbar aendert sich mit (dessen abgewandte
  Kante faellt weg).
- **Entfaellt**: `LayerModel.shiftLayerContent` + `decodeLayerGrid` +
  `materializeShiftedGrid` + `imageFromGrid`; die Ganz-Ebenen-Wrap-Semantik
  (spec.md Edge Case „Pixel Shift Beyond Boundaries“).
- **Test-Nachtrag** (aus der ersten Fassung, bleibt): `newMockImage` hat
  eine `copy()`-Methode (SDK-Aequivalent).
- Headless: die 5 Ganz-Screen-/Deferral-Testabschnitte durch per-Tile-Tests
  ersetzt (nur Cursor-Zelle + 1 Nachbar geaendert; Inhalt wandert + bleibt;
  Akkumulation ueber 2 Druecke; alle 4 Richtungen; Rasterrand ohne Nachbar;
  obere Ebene → `absent`; `EditorRoom:shiftActiveLayer(dir, cellIdx)`;
  ZoomRoom reicht die Cursor-Zelle durch). 394 Assertions gruen, `pdc`
  sauber, buildNumber 30.

## Historie
- **Erste Fassung (Datei `ADR-043-Aufgeschobene-Pixel-Verschiebung.md`,
  verworfen):** Ganz-Ebenen-Verschiebung, Materialisierung ans Gesten-Ende
  aufgeschoben (`pendingShift`/`flushLayerShift`, Offset-Algebra,
  `buildZoomContext`-Synthese, `BButtonUp`). Wurde durch die zweite
  Hardware-Rueckmeldung („nur die Cursor-Zelle“) hinfaellig — die
  Perf-Messung daraus (~192.000 `image:sample()` je Tastendruck) bleibt als
  Begruendung dafuer relevant, warum die Ganz-Ebenen-Version keine gute Idee
  war.

## Offen (Phase 7, Simulator/Hardware)
- Geraete-Messung: ein per-Tile-Schritt sollte klar unter 16 ms liegen,
  aber am Geraet gegenpruefen (T053/T054).

## Related
- [ADR-041: Compositing-Cache und Frame-Verwaltung](ADR-041-Compositing-Cache-und-Frame-Verwaltung.md)
- [ADR-036: Pixel-Rotation Index-Remap](ADR-036-Pixel-Rotation-Index-Remap.md) (verwandtes Muster: exaktes Index-Remap auf einem 16x16-Raster statt SDK-Bildtransform)
- [specs/010-layer-management-with-transparency/research.md: R6](../../specs/010-layer-management-with-transparency/research.md)
- [specs/010-layer-management-with-transparency/spec.md: FR-001/FR-002, Edge Cases, Architecture Governance](../../specs/010-layer-management-with-transparency/spec.md)
