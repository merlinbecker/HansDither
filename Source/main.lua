
import "CoreLibs/graphics"
import "CoreLibs/timer"
import "CoreLibs/ui"
import "CoreLibs/animation"
print("seit`1")
import "CoreLibs/object" -- für playdate.graphics.image.new()

local gfx = playdate.graphics
-- Playdate Skalierung: 2 -> logische Größe 200x120 (Pulp-Auflösung)
playdate.display.setScale(2)


local GRID_COLS = 25
local GRID_ROWS = 15
local CELL_SIZE = 8 -- 8x8 Pixel pro Zelle, wenn die Skalierung aus ist, 16x16


-- Matrix-Imagetable (2 Tiles, 8x8) laden (siehe 7.20.12 Image Table)
local origImagetable = gfx.imagetable.new("images/cellbg")
assert(origImagetable, "Imagetable konnte nicht geladen werden!")

-- Neue Imagetable mit 3 Einträgen anlegen
local cellImagetable = gfx.imagetable.new(3)
cellImagetable:setImage(1, origImagetable:getImage(1))
cellImagetable:setImage(2, origImagetable:getImage(2))

-- Schwarzes Tile erzeugen und als drittes Tile anhängen
local blackTile = gfx.image.new(CELL_SIZE, CELL_SIZE)
gfx.pushContext(blackTile)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, CELL_SIZE, CELL_SIZE)
gfx.popContext()
cellImagetable:setImage(3, blackTile)


-- Kein separates gridState mehr nötig, Tilemap ist die Datenquelle


-- Schritt 1: Tilemap initialisieren (alle Tiles auf 1 = Hintergrund)
local tilemap = gfx.tilemap.new()
tilemap:setSize(GRID_COLS, GRID_ROWS)
tilemap:setImageTable(cellImagetable)
for y = 1, GRID_ROWS do
    for x = 1, GRID_COLS do
        tilemap:setTileAtPosition(x, y, 1)
    end
end


-- GridView bleibt für Cursor-Handling erhalten
local gridView = playdate.ui.gridview.new(CELL_SIZE, CELL_SIZE)
gridView:setNumberOfSections(1)
gridView:setNumberOfColumns(GRID_COLS)
gridView:setNumberOfRowsInSection(1, GRID_ROWS)

-- Cursor-Blinker (immer looping)
local cursorBlinker = playdate.graphics.animation.blinker.new(500, 500, true, nil, true)
cursorBlinker:startLoop()

-- Mittelwert initiale Selektion in der Bildschirmmitte (12, 8) in Sektion 1
-- setSelection(section, row, column)
gridView:setSelection(1, math.floor(GRID_ROWS / 2) + 1, math.floor(GRID_COLS / 2) + 1)

-- Zeichne eine Zelle und optional Cursor, bei Auswahl


function gridView:drawCell(section, row, column, selected, x, y, width, height)
    local selSection, selRow, selCol = gridView:getSelection()
    -- Die Tilemap wird im Haupt-Draw (playdate.update) gezeichnet!

    -- Cursor immer in der selektierten Zelle zeichnen
    local isCursor = (section == selSection and row == selRow and column == selCol)
    if isCursor and cursorBlinker.on then
        local tileIndex = tilemap:getTileAtPosition(column, row)
        local cx = x + width / 2
        local cy = y + height / 2
        if tileIndex == 3 then
            gfx.setColor(gfx.kColorWhite)
        else
            gfx.setColor(gfx.kColorBlack)
        end
        gfx.fillCircleAtPoint(cx, cy, 2)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
end

local needsRedraw = true

-- A-Button toggelt Zelleninhalt an der aktuellen Cursor-Position


local function toggleCurrentCell()
    local section, row, col = gridView:getSelection()
    if row and col then
        local current = tilemap:getTileAtPosition(col, row)
        if current == 3 then
            tilemap:setTileAtPosition(col, row, 1)
        else
            tilemap:setTileAtPosition(col, row, 3)
        end
        needsRedraw = true
    end
end

-- D-Pad und A-Button Input-Handler
local inputHandler = {
    upButtonDown = function()
        gridView:selectPreviousRow(false, true, false)
        needsRedraw = true
    end,

    downButtonDown = function()
        gridView:selectNextRow(false, true, false)
        needsRedraw = true
    end,

    leftButtonDown = function()
        gridView:selectPreviousColumn(false, true, false)
        needsRedraw = true
    end,

    rightButtonDown = function()
        gridView:selectNextColumn(false, true, false)
        needsRedraw = true
    end,

    AButtonDown = function()
        toggleCurrentCell()
    end
}
playdate.inputHandlers.push(inputHandler, true)

local lastBlinkState = cursorBlinker.on


function playdate.update()
    -- Blink-Animation aktualisieren; wenn Blinkzustand wechselt, Neuzeichnen anstoßen
    cursorBlinker:updateAll()
    if cursorBlinker.on ~= lastBlinkState then
        lastBlinkState = cursorBlinker.on
        needsRedraw = true
    end

    if needsRedraw then
        gfx.clear(gfx.kColorWhite)
        -- Schritt 5: Tilemap zeichnen (Grid)
        print("Drawing tilemap...")
        print("Tilemap size: " ..tilemap:getTileAtPosition(1,1))
        tilemap:draw(0, 0)
        -- Cursor-Overlay via gridView (ruft drawCell für selektierte Zelle auf)
        gridView:drawInRect(0, 0, GRID_COLS * CELL_SIZE, GRID_ROWS * CELL_SIZE)
        needsRedraw = false
    end

    -- Timer-Update für CoreLib-Timer und GridView (z.B. Scroll- und Blinker-Handling)
    playdate.timer.updateTimers()
end