-- PixelRoom.lua
-- Innerste Zoomstufe: ein einzelnes Tile mit echten 16×16 Pixeln; ein
-- Malvorgang setzt genau 1 nativen Pixel (FR-011).
-- "All Similar" und "Invert" bleiben als Systemmenü-Funktionen erhalten (FR-015).
import "CoreLibs/graphics"
import "PencilCursor"
local gfx = playdate.graphics

PixelRoom = {}

local switchRoomFunction
local nextRoom
local needsRedraw

local GRID_COLS = 16
local GRID_ROWS = 16
local CELL_SIZE = 14  -- 16 × 14 = 224 px, zentriert auf 400×240
local PADDING_X = (400 - GRID_COLS * CELL_SIZE) // 2  -- 88 px
local PADDING_Y = (240 - GRID_ROWS * CELL_SIZE) // 2  -- 8 px

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

-- Das 16×16-Malraster ist ein SDK-Gridview; Selektion = Malcursor
-- (SDK: playdate.ui.gridview aus CoreLibs/ui)
local gridView = playdate.ui.gridview.new(CELL_SIZE, CELL_SIZE)
gridView:setNumberOfSections(1)
gridView:setNumberOfColumns(GRID_COLS)
gridView:setNumberOfRowsInSection(1, GRID_ROWS)
gridView:setSelection(1, math.floor(GRID_ROWS / 2) + 1, math.floor(GRID_COLS / 2) + 1)

-- drawCell-Callback: hier bewusst mit Doppelpunkt definiert
-- (function gridView:drawCell), damit self korrekt belegt ist —
-- das Gridview ruft den Callback als Methode auf.
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
        gfx.fillRect(x + 1, y + 1, width - 2, height - 2)
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
            local color = tile:sample(x - 1, y - 1)
            gridState[y][x] = color == gfx.kColorBlack
        end
    end
end

-- Pencil-Strich: Der A-Druck bestimmt den Malwert des ganzen Strichs —
-- Pixel war schwarz -> Strich malt Weiß (Radierer), sonst Schwarz.
-- Bewegungen mit gehaltenem A malen denselben Wert weiter.
local strokeValue = nil  -- true/false = Malwert des laufenden Strichs, nil = kein Strich

local function paintCurrentCell(value)
    local _, row, col = gridView:getSelection()
    if row and col and gridState[row] then
        gridState[row][col] = value
        needsRedraw = true
    end
end

local function beginStroke()
    local _, row, col = gridView:getSelection()
    if row and col and gridState[row] then
        strokeValue = not gridState[row][col]
        paintCurrentCell(strokeValue)
    end
end

local function endStroke()
    strokeValue = nil
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
        -- Laufender A-Strich malt weiter (SDK: playdate.buttonIsPressed)
        if strokeValue ~= nil and playdate.buttonIsPressed(playdate.kButtonA) then
            paintCurrentCell(strokeValue)
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

-- Baut das 16×16-Tile-Bild aus dem aktuellen gridState.
local function buildTileImage()
    local newTile = gfx.image.new(GRID_COLS, GRID_ROWS, gfx.kColorWhite)
    gfx.pushContext(newTile)
        gfx.setColor(gfx.kColorBlack)
        for y = 1, GRID_ROWS do
            for x = 1, GRID_COLS do
                if gridState[y][x] then
                    gfx.drawPixel(x - 1, y - 1)
                end
            end
        end
    gfx.popContext()
    return newTile
end

-- Übergibt das bearbeitete Tile an den ZoomRoom (Standard: Dedup-Pfad;
-- "All Similar": in-place, wirkt auf alle Verwendungen — FR-013-Ausnahme).
local function commitToZoomRoom()
    local newTile = buildTileImage()
    if changeAllSimilar and currentTileIndex then
        nextRoom:updateExistingTile(newTile, currentTileIndex)
    else
        nextRoom:setNewTile(newTile)
    end
end

-- Initialize the room with shared data and dependencies
function PixelRoom:init(switchRoom, nextRoomReference)
    switchRoomFunction = switchRoom
    nextRoom = nextRoomReference
    for y = 1, GRID_ROWS do
        gridState[y] = {}
        for x = 1, GRID_COLS do
            gridState[y][x] = false
        end
    end
    needsRedraw = true
end

-- Terminate-Hook (Contract E-03): Zustand an ZoomRoom übergeben, ohne Room-Wechsel.
function PixelRoom:commitForTerminate()
    if nextRoom then
        commitToZoomRoom()
    end
end

function PixelRoom:update()
    processDirectionHold()

    -- Ticks in jedem Update lesen (stateful), ohne B verwerfen —
    -- sonst entlaedt sich aufgestauter Zaehler beim ersten B-Frame.
    local crankTicks = playdate.getCrankTicks(4) or 0
    local bHeld = playdate.buttonIsPressed(playdate.kButtonB)
    if bHeld then
        -- Standard-Lua statt pdc-Kurzform "+=" (haelt die Datei headless testbar)
        ticks = ticks + crankTicks
        if ticks <= -4 then
            ticks = 0
            if switchRoomFunction then
                commitToZoomRoom()
                switchRoomFunction(nextRoom)
            end
        elseif ticks > 0 then
            -- Innerste Zoomstufe: Vorwärtszoom ist No-op
            ticks = 0
        end
    else
        ticks = 0
    end

    if needsRedraw then
        -- draw a background
        gfx.clear(gfx.kColorWhite)
        gfx.setPattern({ 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55 })
        gfx.fillRect(0, 0, 400, 240)
        gridView:drawInRect(PADDING_X, PADDING_Y, GRID_COLS * CELL_SIZE, GRID_ROWS * CELL_SIZE)

        needsRedraw = false
    end
    playdate.timer.updateTimers()
end

function PixelRoom:entered()
    clearDirectionHold()
    endStroke()
    ticks = 0
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
            beginStroke()
        end,
        AButtonUp = function()
            endStroke()
        end
    }
end
