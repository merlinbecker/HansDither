-- PixelRoom.lua
-- Innerste Zoomstufe: ein einzelnes Tile mit echten 16×16 Pixeln; ein
-- Malvorgang setzt genau 1 nativen Pixel (FR-011).
-- "All Similar" und "Invert" bleiben als Systemmenü-Funktionen erhalten (FR-015).
--
-- Spec 010 (US2): das 16x16-Malraster hat DREI Zustaende je Pixel
-- (PixelTransparency): OPAQUE (schwarz), TRANSPARENT (durchsichtig, kColorClear)
-- und EMPTY (weiss). A-Druck toggelt opak<->leer (Radierer, wie Spec 008),
-- B-Druck malt transparent (FR-007). "Empty" aus "Transparent" erreicht man
-- mit A (transparent->opak) und nochmal A (opak->leer) — die Playdate-Hardware
-- hat keine dedizierte dritte Maltaste ("Y" in den Plan-Artefakten existiert
-- nicht). Transparente Pixel landen als kColorClear im Tile und werden ueber
-- den 3-Zustands-hashTile getrennt dedupliziert (spec.md Edge Case Z.104).
import "CoreLibs/graphics"
import "PixelTransparency"
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

-- Grid-Zustand: 3-Zustands-Code je Zelle (PixelTransparency: 0=opak/schwarz,
-- 1=transparent, 2=leer/weiss). Default EMPTY.
local gridState = {}
local OPAQUE = PixelTransparency.OPAQUE
local TRANSPARENT = PixelTransparency.TRANSPARENT
local EMPTY = PixelTransparency.EMPTY

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

-- Spec 008 (AD-036): signierter Grad-Akkumulator fuer die Pixel-Rotation,
-- analog zu crankAccumDegrees in EditorRoom.lua (Spec 006). Crank ohne
-- gehaltene B-Taste war hier bislang wirkungslos - freier Eingabekanal.
local rotationAccumDegrees = 0

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

    local state = gridState[row][column]
    if state == OPAQUE then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(x + 1, y + 1, width - 2, height - 2)
    elseif state == TRANSPARENT then
        -- Schachbrettmuster = "transparent" (Industriestandard, FR-011);
        -- sichtbar verschieden von opak (schwarz) und leer (weiss).
        gfx.setPattern({ 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55 })
        gfx.fillRect(x + 1, y + 1, width - 2, height - 2)
        gfx.setColor(gfx.kColorBlack)  -- Pattern wieder auf Volltonfarbe zuruecksetzen
    end
    -- EMPTY: weisser Zellhintergrund bleibt

    -- Cursor immer in der selektierten Zelle zeichnen
    local isCursor = (section == selSection and row == selRow and column == selCol)
    if isCursor then
        PencilCursor.draw(x, y, width, height)
    end
end


function PixelRoom:setCurrentTile(tile, tileIndex)
    currentTileIndex = tileIndex
    rotationAccumDegrees = 0 -- Spec 008: kein Uebertrag zwischen Bearbeitungssitzungen
    for y = 1, GRID_ROWS do
        gridState[y] = {}
        for x = 1, GRID_COLS do
            -- 3-Zustands-Code aus der Pixelfarbe (schwarz/clear/weiss).
            gridState[y][x] = PixelTransparency.sampleState(tile, x - 1, y - 1)
        end
    end
end

-- Spec 008 (AD-036, FR-005/FR-006): exakter Index-Remap auf dem 16x16-
-- Bool-Raster - kein SDK-Bildtransform (image:rotatedImage()/drawRotated()
-- sind laut SDK-Doku "quite slow" und potenziell dimensions-/resampling-
-- behaftet, research.md R3). Neue Tabelle aufbauen statt In-Place-Remap, da
-- sich Lese- und Schreibposition sonst ueberlappen wuerden.
local function rotateGridClockwise()
    local newGrid = {}
    for r = 1, GRID_ROWS do
        newGrid[r] = {}
        for c = 1, GRID_COLS do
            newGrid[r][c] = gridState[GRID_ROWS + 1 - c][r]
        end
    end
    gridState = newGrid
    needsRedraw = true
end

local function rotateGridCounterClockwise()
    local newGrid = {}
    for r = 1, GRID_ROWS do
        newGrid[r] = {}
        for c = 1, GRID_COLS do
            newGrid[r][c] = gridState[c][GRID_ROWS + 1 - r]
        end
    end
    gridState = newGrid
    needsRedraw = true
end

-- Pencil-Strich: der erste Tastendruck bestimmt den Malwert des ganzen Strichs.
--  * A auf opakem Pixel -> Strich malt EMPTY (Radierer, Spec 008); sonst OPAQUE.
--  * B -> Strich malt TRANSPARENT (FR-007).
-- Bewegungen mit gehaltener Starttaste malen denselben Wert weiter.
local strokeValue = nil   -- 3-Zustands-Code des laufenden Strichs, nil = kein Strich
local strokeButton = nil  -- "A" | "B" | nil

local function paintCurrentCell(value)
    local _, row, col = gridView:getSelection()
    if row and col and gridState[row] then
        gridState[row][col] = value
        needsRedraw = true
    end
end

local function beginStroke(button)
    local _, row, col = gridView:getSelection()
    if not (row and col and gridState[row]) then return end
    strokeButton = button
    if button == "B" then
        strokeValue = TRANSPARENT
    else
        strokeValue = (gridState[row][col] == OPAQUE) and EMPTY or OPAQUE
    end
    paintCurrentCell(strokeValue)
end

local function endStroke()
    strokeValue = nil
    strokeButton = nil
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
        -- Laufender Strich malt weiter, solange die Starttaste gehalten wird
        local heldButton = (strokeButton == "B") and playdate.kButtonB or playdate.kButtonA
        if strokeValue ~= nil and playdate.buttonIsPressed(heldButton) then
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

-- Baut das 16×16-Tile-Bild aus dem aktuellen gridState. OPAQUE -> schwarzer
-- Pixel, TRANSPARENT -> kColorClear (durchsichtig), EMPTY -> weisser
-- Hintergrund bleibt.
local function buildTileImage()
    local newTile = gfx.image.new(GRID_COLS, GRID_ROWS, gfx.kColorWhite)
    gfx.pushContext(newTile)
        for y = 1, GRID_ROWS do
            for x = 1, GRID_COLS do
                local state = gridState[y][x]
                if state == OPAQUE then
                    gfx.setColor(gfx.kColorBlack)
                    gfx.drawPixel(x - 1, y - 1)
                elseif state == TRANSPARENT then
                    gfx.setColor(gfx.kColorClear)
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
            gridState[y][x] = EMPTY
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

    -- Spec 008 (AD-036, Contract PR-01): pro update() wird GENAU EINE
    -- Crank-Lese-API verwendet - analog zu EditorRoom:handleCrank() (Spec
    -- 006 CR-01). Bei gehaltener B-Taste bleibt getCrankTicks(4) fuer die
    -- Zoom-Out-Geste zustaendig (unveraendert); ohne B treibt getCrankChange()
    -- den neuen Rotations-Akkumulator - beide Lesepfade duerfen nie im
    -- selben Frame gemeinsam aufgerufen werden, sonst gehen Grad-/Tick-
    -- Anteile verloren (research.md R2 Detailhinweis).
    local bHeld = playdate.buttonIsPressed(playdate.kButtonB)
    if bHeld then
        local crankTicks = playdate.getCrankTicks(4) or 0
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
        local change = playdate.getCrankChange() or 0
        rotationAccumDegrees = rotationAccumDegrees + change
        if rotationAccumDegrees >= 360 then
            rotationAccumDegrees = rotationAccumDegrees - 360
            rotateGridClockwise()
        elseif rotationAccumDegrees <= -360 then
            rotationAccumDegrees = rotationAccumDegrees + 360
            rotateGridCounterClockwise()
        end
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
    rotationAccumDegrees = 0 -- Spec 008: defensiv, setCurrentTile() setzt es bereits zurueck
    needsRedraw = true
    -- System-Menü: Checkbox "All Similar" + "Invert"
    local menu = playdate.getSystemMenu()
    menu:removeAllMenuItems()
    menu:addCheckmarkMenuItem("All Similar", changeAllSimilar, function(checked)
        changeAllSimilar = checked
    end)
    menu:addMenuItem("Invert", function()
        -- Spec 010: opak <-> leer tauschen; transparente Pixel bleiben.
        for y = 1, GRID_ROWS do
            for x = 1, GRID_COLS do
                local s = gridState[y][x]
                if s == OPAQUE then
                    gridState[y][x] = EMPTY
                elseif s == EMPTY then
                    gridState[y][x] = OPAQUE
                end
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
            beginStroke("A")
        end,
        AButtonUp = function()
            endStroke()
        end,
        -- Spec 010 (US2, FR-007): B malt einen transparenten Pixel. Die
        -- B+Crank-Zoom-Out-Geste (update(), Contract PR-01) bleibt unberuehrt —
        -- ein kurzer B-Tipp malt, B-Halten+Kurbeln zoomt (und malt dabei einen
        -- transparenten Pixel als Nebeneffekt, analog EditorRoom-Pipette).
        BButtonDown = function()
            beginStroke("B")
        end,
        BButtonUp = function()
            endStroke()
        end
    }
end
