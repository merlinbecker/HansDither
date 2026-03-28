import "CoreLibs/graphics"
import "CoreLibs/timer"
import "CoreLibs/ui"
import "CoreLibs/animation"

local gfx = playdate.graphics

-- Playdate Skalierung: 2 -> logische Größe 200x120 (Pulp-Auflösung)
playdate.display.setScale(2)

local GRID_COLS = 25
local GRID_ROWS = 15
local CELL_SIZE = 8 -- 8x8 Pixel pro Zelle, wenn die Skalierung aus ist, 16x16

-- Grid-Zustand: false=weiß, true=schwarz
local gridState = {}
for y = 1, GRID_ROWS do
    gridState[y] = {}
    for x = 1, GRID_COLS do
        gridState[y][x] = false
    end
end

-- GridView erstellen und konfigurieren
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
    -- Debug-Ausgabe für Koordinaten
    -- print("drawCell: section="..section.." row="..row.." col="..column)
    local selSection, selRow, selCol = gridView:getSelection()
    -- print("Selection: section="..selSection.." row="..selRow.." col="..selCol)

    -- Immer Gridzelle zeichnen
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(x, y, width, height)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(x, y, width, height)

    -- Zelle füllen (schwarz) nur bei true
    local isBlack = gridState[row][column]
    if isBlack then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(x+1, y+1, width-2, height-2)
    end

    -- Cursor immer in der selektierten Zelle zeichnen
    local isCursor = (section == selSection and row == selRow and column == selCol)
    if isCursor and cursorBlinker.on then
        local cx = x + width / 2
        local cy = y + height / 2
        if isBlack then
            gfx.setColor(gfx.kColorWhite)
            -- gfx.setImageDrawMode(gfx.kDrawModeInverted)
        else
            -- gfx.setImageDrawMode(gfx.kDrawModeCopy)
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
    if row and col and gridState[row] then
        gridState[row][col] = not gridState[row][col]
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
        gridView:drawInRect(0, 0, GRID_COLS * CELL_SIZE, GRID_ROWS * CELL_SIZE)
        needsRedraw = false
    end

    -- Timer-Update für CoreLib-Timer und GridView (z.B. Scroll- und Blinker-Handling)
    -- Siehe: 7.32 UI Components.md ("playdate.ui.gridview uses playdate.timer internally")
    -- und 7.20.9 Animation.md (Blinker.Timer-Updates via playdate.timer.updateTimers)
    playdate.timer.updateTimers()
end