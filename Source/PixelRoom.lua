-- StartRaum.lua
import "CoreLibs/graphics"
import "PencilCursor"
local gfx = playdate.graphics

PixelRoom = {}

local switchRoomFunction
local nextRoom
local needsRedraw

-- am rand sind dann 20 pixel, die gefuellt werden müssen
local GRID_COLS = 8
local GRID_ROWS = 8
local CELL_SIZE = 30 -- 30x30 Pixel pro Zelle (native 400x240, entspricht 2x Pulp-Pixel)
local PADDING = 80   -- (400 - 8*30) / 2 = 80 px Seitenrand

local HOLD_INITIAL_DELAY_MS = 220
local HOLD_REPEAT_MS = 80

-- Grid-Zustand: false=weiß, true=schwarz
local gridState = {}

-- Change All Similar Tiles: wenn true, wird beim Verlassen das bestehende
-- Tile in-place überschrieben statt ein neues anzulegen.
local changeAllSimilar = false
local currentTileIndex = nil -- 1-basierter Index des bearbeiteten Tiles in der Imagetable

local directionHold = {
    up = { active = false, nextMs = 0 },
    down = { active = false, nextMs = 0 },
    left = { active = false, nextMs = 0 },
    right = { active = false, nextMs = 0 }
}

local ticks = 0

local gridView = playdate.ui.gridview.new(CELL_SIZE, CELL_SIZE)
gridView:setNumberOfSections(1)
gridView:setNumberOfColumns(GRID_COLS)
gridView:setNumberOfRowsInSection(1, GRID_ROWS)
gridView:setSelection(1, math.floor(GRID_ROWS / 2) + 1, math.floor(GRID_COLS / 2) + 1)

-- Zeichne eine Zelle und optional Cursor, bei Auswahl
function gridView:drawCell(section, row, column, selected, x, y, width, height)
    local selSection, selRow, selCol = gridView:getSelection()
    -- Immer Gridzelle zeichnen
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(x, y, width, height)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(x, y, width, height)

    local isBlack = gridState[row][column]
        if isBlack then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(x+1, y+1, width-2, height-2)
        end
    -- Cursor immer in der selektierten Zelle zeichnen
    local isCursor = (section == selSection and row == selRow and column == selCol)
    if isCursor then
        PencilCursor.draw(x, y, width, height)
    end
end


function PixelRoom:setCurrentTile(tile, tileIndex)
    currentTileIndex = tileIndex
    for y = 1, GRID_ROWS do
    gridState[y] = {}
        for x = 1, GRID_COLS do
            local color=tile:sample(x-1, y-1)
            gridState[y][x] = color==gfx.kColorBlack
            
        end
    end
end

-- A-Button toggelt Zelleninhalt an der aktuellen Cursor-Position
local function toggleCurrentCell()
    local section, row, col = gridView:getSelection()
    if row and col and gridState[row] then
        gridState[row][col] = not gridState[row][col]
        needsRedraw = true
    end
end

local function moveCursor(direction)
    local _, oldRow, oldCol = gridView:getSelection()
    if direction == "up" then
        gridView:selectPreviousRow(false, true, false)
    elseif direction == "down" then
        gridView:selectNextRow(false, true, false)
    elseif direction == "left" then
        gridView:selectPreviousColumn(false, true, false)
    elseif direction == "right" then
        gridView:selectNextColumn(false, true, false)
    else
        return
    end

    local _, newRow, newCol = gridView:getSelection()
    if oldRow ~= newRow or oldCol ~= newCol then
        if playdate.buttonIsPressed(playdate.kButtonA) then
            toggleCurrentCell()
        else
            needsRedraw = true
        end
    end
end

local function startDirectionHold(direction)
    local state = directionHold[direction]
    if not state then return end
    moveCursor(direction)
    state.active = true
    state.nextMs = playdate.getCurrentTimeMilliseconds() + HOLD_INITIAL_DELAY_MS
end

local function stopDirectionHold(direction)
    local state = directionHold[direction]
    if not state then return end
    state.active = false
end

local function clearDirectionHold()
    for _, state in pairs(directionHold) do
        state.active = false
    end
end

local function processDirectionHold()
    local nowMs = playdate.getCurrentTimeMilliseconds()
    local buttonByDirection = {
        up = playdate.kButtonUp,
        down = playdate.kButtonDown,
        left = playdate.kButtonLeft,
        right = playdate.kButtonRight
    }
    for direction, state in pairs(directionHold) do
        if state.active then
            local button = buttonByDirection[direction]
            if not playdate.buttonIsPressed(button) then
                state.active = false
            elseif nowMs >= state.nextMs then
                moveCursor(direction)
                state.nextMs = nowMs + HOLD_REPEAT_MS
            end
        end
    end
end


-- Initialize the room with shared data and dependencies
function PixelRoom:init(switchRoom,nextRoomReference)
    switchRoomFunction = switchRoom
    nextRoom = nextRoomReference
    for y = 1, GRID_ROWS do
    gridState[y] = {}
        for x = 1, GRID_COLS do
            gridState[y][x] =false
        end
    end
    needsRedraw = true
end

-- Update logic for StartRaum
function PixelRoom:update()
    processDirectionHold()

    local bHeld = playdate.buttonIsPressed(playdate.kButtonB)
    if bHeld then
        local crankTicks = playdate.getCrankTicks(4) or 0
        ticks += crankTicks
        if ticks <=-4 then
            ticks=0
            if switchRoomFunction then
                -- Tile-Bild aus gridState erzeugen
                local newTile = gfx.image.new(GRID_COLS, GRID_ROWS,gfx.kColorWhite)
                gfx.pushContext(newTile)
                    gfx.setColor(gfx.kColorBlack)
                    for y = 1, GRID_ROWS do
                        for x = 1, GRID_COLS do
                            if gridState[y][x] then
                                gfx.drawPixel(x-1, y-1)
                            end
                        end
                    end
                gfx.popContext()
                if changeAllSimilar and currentTileIndex then
                    -- In-place: bestehendes Tile überschreiben
                    nextRoom:updateExistingTile(newTile, currentTileIndex)
                else
                    -- Standard: neues Tile anlegen / deduplizieren
                    nextRoom:setNewTile(newTile)
                end
                switchRoomFunction(nextRoom)
            end
        end
    else 
        ticks=0
    end



    if needsRedraw then
        -- draw a background
        gfx.clear(gfx.kColorWhite)
        gfx.setPattern({ 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55 })
        gfx.fillRect(0, 0, 400, 240)
        -- Example: Draw the title screen here
        gridView:drawInRect(PADDING, 0, GRID_COLS * CELL_SIZE, GRID_ROWS * CELL_SIZE)
        
        needsRedraw = false
    end
    playdate.timer.updateTimers()
end

function PixelRoom:entered()
    clearDirectionHold()
    needsRedraw = true
    -- System-Menü: Checkbox "All Similar" + "Invert"
    local menu = playdate.getSystemMenu()
    menu:removeAllMenuItems()
    menu:addCheckmarkMenuItem("All Similar", changeAllSimilar, function(checked)
        changeAllSimilar = checked
    end)
    menu:addMenuItem("Invert", function()
        for y = 1, GRID_ROWS do
            for x = 1, GRID_COLS do
                gridState[y][x] = not gridState[y][x]
            end
        end
        needsRedraw = true
    end)
    print("Entered PixelRoom")
end

-- Input handler for StartRaum
function PixelRoom:inputHandler()
    return {
    upButtonDown = function()
        startDirectionHold("up")
    end,
    upButtonUp = function()
        stopDirectionHold("up")
    end,
    downButtonDown = function()
        startDirectionHold("down")
    end,
    downButtonUp = function()
        stopDirectionHold("down")
    end,
    leftButtonDown = function()
        startDirectionHold("left")
    end,
    leftButtonUp = function()
        stopDirectionHold("left")
    end,
    rightButtonDown = function()
        startDirectionHold("right")
    end,
    rightButtonUp = function()
        stopDirectionHold("right")
    end,
    AButtonDown = function()
        toggleCurrentCell()
    end
}
end
