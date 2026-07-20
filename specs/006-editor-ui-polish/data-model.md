# Phase 1 Data Model: Editor-UI-Verbesserungen

**Feature**: 006-editor-ui-polish | **Date**: 2026-07-19

Kein neues Persistenzformat (Constitution II) — alle hier beschriebenen
Strukturen sind reiner Laufzeit-Zustand innerhalb der jeweils genannten
Room-Module, aufbauend auf der bestehenden `imageData`-Struktur (Spec 001)
und den bereits vorhandenen Modul-Zuständen aus Spec 003.

---

## 1. Crank-Akkumulator (`EditorRoom.lua`, R1 — FR-004/005/006)

| Feld | Typ | Beschreibung |
|---|---|---|
| `crankAccumDegrees` | number (signiert) | Netto-Grad seit letztem Frame-Wechsel; positiv = vorwärts, negativ = rückwärts. Initial `0`. |

**Übergänge**:
- Bei jedem `EditorRoom:update()`-Aufruf OHNE gehaltene B-Taste:
  `change = playdate.getCrankChange(); crankAccumDegrees += change`.
- `crankAccumDegrees >= 360` → `crankAccumDegrees -= 360`, `tickForward()`.
- `crankAccumDegrees <= -360` → `crankAccumDegrees += 360`, `tickBackward()`.
- Kein Reset auf 0 bei Richtungswechsel — der signierte Wert gleicht sich
  durch Addition von selbst aus (research.md R1).
- Bei gehaltener B-Taste: `crankAccumDegrees` wird NICHT verändert
  (der Crank-Wert fließt stattdessen unverändert in die bestehende
  `getCrankTicks(4)`-Zoomkette, siehe research.md R1 Detailhinweis) —
  verhindert, dass beim Loslassen von B ein während des Zoomens
  "liegengebliebener" Bruchteil sofort einen Frame-Wechsel auslöst.

---

## 2. Bauchbinde-Sichtbarkeitszustand (`EditorRoom.lua`, R3 — FR-001/002/003)

| Feld | Typ | Beschreibung |
|---|---|---|
| `lastActivityMs` | number | `playdate.getCurrentTimeMilliseconds()`-Zeitpunkt der letzten Eingabe. Initial: Zeitpunkt von `entered()`. |

**Abgeleitete Werte (pro Frame in `draw()`/`update()` berechnet, kein
eigener State)**:
- `bauchbindeVisible = (nowMs - lastActivityMs) < 5000`
- `bauchbindeSide = (cursor.x <= GRID_COLS / 2) and "right" or "left"`
  (`GRID_COLS = 25`, `25/2 = 12.5` — `cursor.x` ist immer eindeutig ≤12
  oder ≥13, kein Gleichstand möglich)

**Aktivitäts-Ereignisse, die `lastActivityMs` aktualisieren** (FR-002 —
"jede Nutzereingabe"): `moveCursor()` (D-Pad, inkl. Repeat-Timer-Ticks),
`beginStroke()` (A-Druck), `pipette()` (B-Release ohne Zoom), Crank-Delta
`change ~= 0` (R1) UND `crankTicks ~= 0` während B-Zoom — jede tatsächliche
physische Eingabe zählt, unabhängig davon, ob sie eine sichtbare Wirkung
hatte (z. B. D-Pad gegen den Bildrand).

Das bereits bestehende `statusMessage`/`statusUntilMs`-Feld (Fehlertext
links) bleibt unverändert und unabhängig von diesem neuen Zustand — beide
Bauchbinden-Aufrufe (`drawBottom` für Frame-Position und für Statustext)
koexistieren wie bisher, nur der Frame-Positions-Aufruf wird jetzt an
`bauchbindeVisible` gebunden.

---

## 3. Zoom-Zellen-Rendering (`ZoomRoom.lua`, R2 — FR-007/008/009)

Kein neues Datenfeld — Wiederverwendung von `gridState[r][c]`,
`baselineGrid[r][c]` und `slots[sr][sc].originalImage`/`.editedImage`
(bereits vorhanden). Neue reine Rendering-Regel in `drawGrid()`:

```text
für jede Zelle (r, c):
  sr, sc = getSlotForCell(r, c)
  slot = slots[sr][sc]
  wenn slot.oob:
      Zelle weiß füllen (unverändert)
  sonst wenn gridState[r][c] == baselineGrid[r][c]:      -- unbearbeitet
      base = slot.editedImage or slot.originalImage
      lr, lc = lokale Pixel-Koordinaten im 16×16-Tile (aus r,c abgeleitet)
      vier Subpixel bei (lc,lr), (lc+1,lr), (lc,lr+1), (lc+1,lr+1) einzeln
      sampeln, als vier 5×5-Quadranten der 10×10-Zelle zeichnen
  sonst:                                                   -- bearbeitet
      Zelle flächig in gridState[r][c] ? schwarz : weiß füllen (unverändert)
```

Cursor/Gitterlinien-Overlay unverändert obenauf gezeichnet.

---

## 4. Kontext-/Pause-Ansicht (`EditorRoom.lua`, `main.lua`, R4 — FR-010/011/012/013)

**Neue Funktion**: `EditorRoom:buildPauseMenuImage() -> playdate.graphics.image`

Erzeugt ein 400×240-Bild, dessen relevanter Inhalt ausschließlich im
linken 200×240-Bereich liegt (SDK-Vorgabe, research.md R4). Nur aufgerufen
aus `main.lua`s `playdate.gameWillPause()`, NICHT pro Frame.

**Layout (linke 200px, alle Angaben in Pixeln, Ursprung oben links)**:

| Bereich | Position | Inhalt |
|---|---|---|
| Titelzeile | `x=8, y=6` | Bildname (falls vorhanden) |
| Tile-Raster | `x=8, y=26`, Zellgröße 14×14 (13px Kachel + 1px Rand), 12 Spalten × 10 Zeilen = Raster 168×140px | Bis zu 120 unterschiedliche Tiles als 13×13-Vorschau (Tile auf 13px skaliert oder zentriert, je nach Bildqualität — Detailentscheidung Implementierung), nach Erstellungsreihenfolge (Assumption spec.md) |
| Gesamtzahl | `x=8, y=172` | `"Tiles: " .. totalDistinctTileCount` (FR-011) — unten links wie gefordert |
| Metainformationen | `x=8, y=188` bis `y=232` | `"Frames: " .. #imageData.frames` (FR-012, Pflicht-Minimum); Raum für weitere Metadaten in Folge-Iterationen |

**`totalDistinctTileCount`-Berechnung** (FR-011, NICHT `imagetable:getLength()`
— Begründung research.md R4):

```lua
local seen = {}
local count = 0
for _, frame in ipairs(imageData.frames) do
    for _, tileIndex in ipairs(frame) do
        if not seen[tileIndex] then
            seen[tileIndex] = true
            count = count + 1
        end
    end
end
```

**Truncation (FR-013)**: Übersteigt `count` die 120 Rasterplätze, werden
nur die ersten 120 nach Erstellungsreihenfolge (aufsteigender Tile-Index,
gemäß Assumption in spec.md) als Vorschau gezeichnet; `count` selbst bleibt
der vollständige, echte Wert.

**Aufruf-Kontext**: `main.lua`s neuer `playdate.gameWillPause()`-Hook ruft
`buildPauseMenuImage()` nur auf, wenn `currentRoom` `EditorRoom`, `ZoomRoom`
oder `PixelRoom` ist (alle drei referenzieren dasselbe `imageData` bzw.
`imageDataRef`) — sonst `playdate.setMenuImage(nil)` (kein Bild, z. B. auf
dem Titelscreen).

---

## 5. VHS-Effekt-Zustand (`SelectionRoom.lua`, R5 — FR-017)

**Korrigiert während der Implementierung** (research.md R5): nicht
`gfx.setDitherPattern` (kein Phasen-Offset), sondern `gfx.setPattern(pattern,
x, y)` — Feld-Namen unten entsprechend angepasst.

| Feld | Typ | Beschreibung |
|---|---|---|
| `vhsPhaseTimerMs` | number | Zeitpunkt des nächsten Phasenwechsels |
| `vhsPhaseX`, `vhsPhaseY` | number (0..7) | aktueller Phasen-Offset für `gfx.setPattern(VHS_PATTERN, vhsPhaseX, vhsPhaseY)`, zyklisch fortschreitend |

Nur aktiv, während ein Vollbild-Hintergrund (Abschnitt 6) gezeichnet wird.
Konkretes Muster (`VHS_PATTERN`, ein irreguläres 8-Byte-Bitmuster statt
Schachbrett) und Wechselintervall (`VHS_PHASE_INTERVAL_MS = 80`) sind als
Konstanten in `SelectionRoom.lua` festgelegt; finale visuelle Kalibrierung
bleibt offen (siehe plan.md Architecture Governance, T023).

---

## 6. Titelscreen-Auswahl-Animation (`SelectionRoom.lua`, R6 — FR-016/018)

| Feld | Typ | Beschreibung |
|---|---|---|
| `fullImageData` | `imageData` oder `nil` | Voll geladene Frame-/Imagetable-Daten des AKTUELL selektierten Eintrags; `nil`, solange nicht geladen. |
| `fullImageLoadOperation` | `RoomOperation` oder `nil` | Laufender Lazy-Load (Coroutine, bestehendes Muster), `nil` wenn abgeschlossen/keiner läuft. |
| `fullImageForId` | string oder `nil` | ID des Eintrags, für den `fullImageData`/`fullImageLoadOperation` gelten — bei Selektionswechsel Abgleich gegen den neu selektierten Eintrag. |
| `titleAnimFrame` | number | Aktuell angezeigter Frame-Index (1..#`fullImageData.frames`) des Vollbild-Hintergrunds. |
| `titleAnimTimerMs` | number | Zeitpunkt des nächsten Frame-Wechsels (fester Intervall, z. B. wie im Editor üblich). |

**Übergänge**:
- Selektionswechsel (`entry ~= fullImageForId`): laufenden
  `fullImageLoadOperation` verwerfen (kein Commit/Cancel-Callback nötig, da
  reiner Lesevorgang ohne Seiteneffekt), `fullImageForId = neue ID`,
  `fullImageLoadOperation = ImageStoreCodec.newLoadOperation(id)` über
  `RoomOperation` gestartet, `fullImageData = nil` bis Abschluss.
- Solange `fullImageData == nil`: bisheriges statisches Kreis-Rendering für
  den selektierten Eintrag beibehalten (kein Sprung/Leerbild, research.md R6).
- Nach Laden: `fullImageData` gesetzt, `titleAnimFrame = 1`,
  `titleAnimTimerMs` gestartet — ab dann Vollbild-Rendering statt Kreis für
  DIESEN Eintrag; alle anderen Einträge unverändert (FR-018).
- Bei nur 1 Frame (`#fullImageData.frames == 1`, Edge Case spec.md):
  `titleAnimFrame` bleibt dauerhaft `1`, kein Timer-Wechsel — Standbild mit
  VHS-Effekt (FR-016 Acceptance Scenario 4).
