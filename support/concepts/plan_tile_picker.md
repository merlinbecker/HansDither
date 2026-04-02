# Feature-Plan: Tile Picker Fenster via Crank

**Datum:** 2026-04-02  
**Datei:** `Source/TileRoom.lua`

---

## Anforderungen

- Crank drehen (ohne B gehalten) → kleines Preview-Fenster erscheint in einer Ecke
- Fenster zeigt jeweils ein Tile aus der Imagetable (Index 3 bis Ende; Tile 1 + 2 werden übersprungen)
- Jeder Crank-Tick = nächstes/vorheriges Tile (je nach Drehrichtung)
- Nach dem letzten Tile → Wrap auf Index 3
- Das Fenster erscheint in der Ecke, die am weitesten vom Cursor entfernt ist:
  - Cursor in linker Hälfte (col ≤ 12) → Fenster oben rechts
  - Cursor in rechter Hälfte (col > 12) → Fenster oben links
- 3 Sekunden kein Crank → Fenster verschwindet

---

## Neue State-Variablen (lokal in TileRoom.lua)

```lua
local tilePickerIndex = 3        -- aktuell gezeigter Tile-Index (min. 3)
local tilePickerVisible = false   -- ist das Fenster sichtbar?
local tilePickerLastCrankMs = 0  -- Zeitstempel des letzten Crank-Inputs (ms)
local PICKER_TIMEOUT_MS = 3000   -- 3 Sekunden Timeout
```

---

## Fenster-Layout

Das Tile ist 8×8 Pixel. Es wird **2× skaliert** mit `image:drawScaled(x, y, 2.0)` für bessere Lesbarkeit.

```
+----------------------+
| 1px border           |
|  +----------------+  |
|  | 2px padding    |  |
|  |  [16×16 tile]  |  |
|  | 2px padding    |  |
|  +----------------+  |
| 1px border           |
+----------------------+
Fenstergröße: 1+2+16+2+1 = 22×22 Pixel
```

---

## Neue Funktionen

### `drawTilePickerWindow()`  _(lokale Funktion)_

```lua
local WIN_SIZE = 22   -- 1px border + 2px pad + 16px tile + 2px pad + 1px border
local MARGIN = 4      -- Abstand zum Bildschirmrand
local SCREEN_W = 400  -- Playdate Bildschirmbreite

local function drawTilePickerWindow()
    if not tilePickerVisible then return end

    local _, _, selCol = gridView:getSelection()

    local px
    if selCol <= GRID_COLS / 2 then
        -- Cursor links → Fenster oben rechts
        px = SCREEN_W - WIN_SIZE - MARGIN
    else
        -- Cursor rechts → Fenster oben links
        px = MARGIN
    end
    local py = MARGIN

    -- Hintergrund (weiß)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(px, py, WIN_SIZE, WIN_SIZE)
    -- Rahmen (schwarz)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(px, py, WIN_SIZE, WIN_SIZE)
    -- Tile 2× skaliert
    local tile = cellImagetable:getImage(tilePickerIndex)
    if tile then
        tile:drawScaled(px + 3, py + 3, 2.0)
    end
end
```

---

## Änderungen in `TileRoom:update()`

Im bestehenden `else`-Zweig (wenn `upHeld == false`) wird bisher nur `ticks = 0` gesetzt.  
Hier wird nun auch der Crank für den Tile Picker abgefragt:

```lua
else
    ticks = 0
    -- Tile Picker: Crank ohne B-Taste
    local crankTicks = playdate.getCrankTicks(4)
    if crankTicks ~= 0 and cellImagetable:getLength() >= 3 then
        local maxTile = cellImagetable:getLength()
        tilePickerIndex = tilePickerIndex + (crankTicks > 0 and 1 or -1)
        if tilePickerIndex > maxTile then
            tilePickerIndex = 3
        elseif tilePickerIndex < 3 then
            tilePickerIndex = maxTile
        end
        tilePickerVisible = true
        tilePickerLastCrankMs = playdate.getCurrentTimeMilliseconds()
        needsRedraw = true
    end
    -- Timeout-Prüfung
    if tilePickerVisible then
        if playdate.getCurrentTimeMilliseconds() - tilePickerLastCrankMs > PICKER_TIMEOUT_MS then
            tilePickerVisible = false
            needsRedraw = true
        end
    end
end
```

**Wichtig:** `getCrankTicks` ist stateful (kumulativ seit letztem Aufruf). Da der Aufruf jetzt im `else`-Zweig passiert und der bestehende Aufruf für B+Crank im `if upHeld`-Zweig liegt, sind beide **strikt getrennt** – kein Konflikt.

---

## Änderungen im Draw-Block (`if needsRedraw then`)

Nach dem bestehenden Draw-Code wird das Picker-Fenster gezeichnet:

```lua
if needsRedraw then
    gfx.clear(gfx.kColorWhite)
    tilemap:draw(0, 0)
    gridView:drawInRect(0, 0, GRID_COLS * CELL_SIZE, GRID_ROWS * CELL_SIZE)
    drawTilePickerWindow()   -- NEU
    needsRedraw = false
end
```

---

## Änderungen in `TileRoom:entered()`

Picker-Zustand zurücksetzen, damit kein altes Fenster aufpoppt:

```lua
function TileRoom:entered()
    needsRedraw = true
    tilePickerVisible = false
    print("Entered TileRoom")
end
```

---

## Randfälle

| Situation | Verhalten |
|---|---|
| Nur Tiles 1+2 vorhanden (kein Tile ab 3) | Picker erscheint nicht |
| Index läuft über letzten Tile | Wrap auf 3 |
| Index fällt unter 3 (rückwärts crank) | Wrap auf letzten Tile |
| B wird gehalten | Picker-Timeout läuft weiter, Fenster bleibt bis Timeout sichtbar |
| Neues Tile per `setNewTile()` hinzugefügt | Picker zeigt beim nächsten Crank automatisch das neue Tile (da `getLength()` größer) |

---

## Kein Konflikt mit B+Crank (Raumwechsel)

Der bestehende B+Crank-Mechanismus (Switch zu PixelRoom) ist unverändert.  
`getCrankTicks(4)` wird nur einmal pro Frame aufgerufen, entweder für B+Crank (room switch) **oder** für Tile Picker – nie für beides gleichzeitig.

---

## Playdate SDK APIs genutzt

- `image:drawScaled(x, y, scale)` – Tile skaliert zeichnen  
- `playdate.getCurrentTimeMilliseconds()` – Timeout-Messung  
- `playdate.getCrankTicks(ticksPerRevolution)` – Crank-Delta pro Frame  
- `gfx.fillRect()` / `gfx.drawRect()` – Fenster-Hintergrund und Rahmen  
