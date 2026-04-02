-- StartRaum.lua
import "CoreLibs/graphics"
local gfx = playdate.graphics

PixelRoom = {}

local switchRoomFunction
local nextRoom
local needsRedraw

-- am rand sind dann 20 pixel, die gefuellt werden müssen
local GRID_COLS = 8
local GRID_ROWS = 8
local CELL_SIZE = 15 -- 15x15 Pixel pro Zelle, wenn die Skalierung aus ist, 8x8
local PADDING=40

-- Grid-Zustand: false=weiß, true=schwarz
local gridState = {}

local gridView = playdate.ui.gridview.new(CELL_SIZE, CELL_SIZE)
gridView:setNumberOfSections(1)
gridView:setNumberOfColumns(GRID_COLS)
gridView:setNumberOfRowsInSection(1, GRID_ROWS)
gridView:setSelection(1, math.floor(GRID_ROWS / 2) + 1, math.floor(GRID_COLS / 2) + 1)


-- Cursor-Blinker (immer looping)
local cursorBlinker = playdate.graphics.animation.blinker.new(500, 500, true, nil, true)
cursorBlinker:startLoop()
local lastBlinkState = cursorBlinker.on

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
    if isCursor and cursorBlinker.on then
        local cx = x + width / 2
        local cy = y + height / 2
        if isBlack then
            gfx.setColor(gfx.kColorWhite)
        else
            gfx.setColor(gfx.kColorBlack)
        end
        gfx.fillCircleAtPoint(cx, cy, 2)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
end


function PixelRoom:setCurrentTile(tile)
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
    cursorBlinker:updateAll()
    if cursorBlinker.on ~= lastBlinkState then
        lastBlinkState = cursorBlinker.on
        needsRedraw = true
    end

    if upHeld then
        ticks += playdate.getCrankTicks(4)
        if ticks <=-4 then
            ticks=0
            if switchRoomFunction then
                --set the tilemap and the current position for editing
                -- hier setzen, dann switchen
                -- Schwarzes Tile erzeugen und als drittes Tile anhängen
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
                nextRoom:setNewTile(newTile)
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
        gfx.fillRect(0,0, 200, 120)
        -- Example: Draw the title screen here
        gridView:drawInRect(PADDING, 0, GRID_COLS * CELL_SIZE, GRID_ROWS * CELL_SIZE)
        
        needsRedraw = false
    end
    playdate.timer.updateTimers()
end

function PixelRoom:entered()
    needsRedraw = true
    print("Entered TitleRoom")
end

-- Input handler for StartRaum
function PixelRoom:inputHandler()
    return {
    upButtonDown = function()
        upHeld = false
        gridView:selectPreviousRow(false, true, false)
        needsRedraw = true
    end,
    upButtonUp = function()
        upHeld = false
    end,
    downButtonDown = function()
        upHeld = false
        gridView:selectNextRow(false, true, false)
        needsRedraw = true
    end,
    leftButtonDown = function()
        upHeld = false
        gridView:selectPreviousColumn(false, true, false)
        needsRedraw = true
    end,
    rightButtonDown = function()
        upHeld = false
        gridView:selectNextColumn(false, true, false)
        needsRedraw = true
    end,
    AButtonDown = function()
        upHeld = false
        toggleCurrentCell()
    end,
    BButtonDown = function()
        upHeld = true
    end,
    BButtonUp = function()
        upHeld = false
    end
}
end
