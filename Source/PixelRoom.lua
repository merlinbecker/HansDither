-- PixelRoom.lua
-- Innerste Zoomstufe: ein einzelnes Tile mit echten 16×16 Pixeln; ein
-- Malvorgang setzt genau 1 nativen Pixel (FR-011).
-- "All Similar" und "Invert" bleiben als Systemmenü-Funktionen erhalten (FR-015).
--
-- Spec 010 (US2, 6. Runde — Hardware-Test): gemalt wird AUSSCHLIESSLICH mit A.
-- Auf der Basisebene toggelt ein A-Strich zwischen Tinte (OPAQUE) und EMPTY/
-- weiss (2 Zustaende, wie zuvor) — die Basisebene kennt keine Transparenz.
-- Auf den Ebenen 2-3 durchlaeuft ein A-Strich stattdessen einen 3-Zustands-
-- Zyklus OPAQUE -> EMPTY/weiss -> TRANSPARENT/kColorClear -> OPAQUE: ein
-- gemalter Strich malt zunaechst Tinte, ein weiterer A-Strich auf demselben
-- Pixel macht daraus weiss, ein dritter macht daraus transparent (Radierer).
-- Eine dedizierte dritte Maltaste ("Y" in den Plan-Artefakten) existiert auf
-- der Playdate nicht, daher zyklt A durch alle 3 Zustaende. B malt NICHT
-- (frueher FR-007): B ist allein der Zoom-Out-Modifier — B halten + Kurbel
-- zurueck verlaesst den PixelRoom (update(), Contract PR-01); ein einzelner
-- B-Tipp bleibt folgenlos. Transparente Pixel landen als kColorClear im Tile
-- und werden ueber den 3-Zustands-hashTile getrennt dedupliziert (spec.md
-- Edge Case Z.104).
import "CoreLibs/graphics"
import "PixelTransparency"
import "PencilCursor"
import "UndoPrompt"   -- Spec 011: modaler Undo-Dialog (gemeinsames Singleton)
local gfx = playdate.graphics

PixelRoom = {}

local switchRoomFunction
local nextRoom
local editorRoom      -- Spec 011: fuer Rotation-Snapshot + Schuettel-Weiterleitung
local needsRedraw

local GRID_COLS = 16
local GRID_ROWS = 16
local CELL_SIZE = 14  -- 16 × 14 = 224 px, zentriert auf 400×240
local PADDING_X = (400 - GRID_COLS * CELL_SIZE) // 2  -- 88 px
local PADDING_Y = (240 - GRID_ROWS * CELL_SIZE) // 2  -- 8 px

local HOLD_INITIAL_DELAY_MS = 220
local HOLD_REPEAT_MS = 80

-- Grid-Zustand: 3-Zustands-Code je Zelle (PixelTransparency: 0=opak/schwarz,
-- 1=transparent, 2=leer/weiss).
local gridState = {}
local OPAQUE = PixelTransparency.OPAQUE
local TRANSPARENT = PixelTransparency.TRANSPARENT
local EMPTY = PixelTransparency.EMPTY

-- Spec 010 (Third Round): der "Nicht-Tinte"-Zustand ist ebenenabhaengig —
-- EMPTY (weiss) auf der Basisebene, TRANSPARENT auf den Ebenen 2-3. Wird von
-- der ZoomRoom je aktiver Ebene gesetzt (setCurrentTile); Default EMPTY
-- (Basisebene / Alt-Aufrufer).
local offState = EMPTY

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

-- Spec 011: Pre-Rotation-Snapshot der bearbeiteten Zelle. Wird beim ERSTEN
-- rotateGrid*() einer Bearbeitungssitzung genommen (nicht bei setCurrentTile --
-- sonst gingen zuvor gemalte Pixel beim Undo mit verloren) und beim Commit an
-- EditorRoom:recordRotation() weitergereicht (via ZoomRoom:setNewTile).
local rotationSnapshotImage = nil
local rotationSnapshotTaken = false

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


-- offStateCode: 3-Zustands-Code des "Nicht-Tinte"-Zustands der aktiven Ebene
-- (PixelTransparency.EMPTY fuer die Basisebene, .TRANSPARENT fuer Ebenen 2-3).
-- Optional; Default EMPTY.
function PixelRoom:setCurrentTile(tile, tileIndex, offStateCode)
    currentTileIndex = tileIndex
    offState = (offStateCode == TRANSPARENT) and TRANSPARENT or EMPTY
    rotationAccumDegrees = 0 -- Spec 008: kein Uebertrag zwischen Bearbeitungssitzungen
    rotationSnapshotImage = nil   -- Spec 011: neue Sitzung -> neuer Rotation-Snapshot
    rotationSnapshotTaken = false
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

-- Pencil-Strich: der A-Tastendruck bestimmt den Malwert des ganzen Strichs.
--  * Basisebene (offState == EMPTY): 2-Zustands-Toggle wie bisher — A auf
--    Tinte malt weiss, sonst Tinte (FR-008).
--  * Ebenen 2-3 (offState == TRANSPARENT): 3-Zustands-Zyklus OPAQUE -> EMPTY
--    -> TRANSPARENT -> OPAQUE (weiss ist auf den oberen Ebenen ein
--    eigenstaendiger, mit A erreichbarer Malzustand, nicht nur ein
--    Durchgangswert zu transparent).
-- Bewegungen mit gehaltenem A malen denselben Wert weiter. B startet keinen
-- Strich (Spec 010, 5. Runde — Hardware-Test) — nur A malt.
local strokeValue = nil   -- 3-Zustands-Code des laufenden Strichs, nil = kein Strich

local function paintCurrentCell(value)
    local _, row, col = gridView:getSelection()
    if row and col and gridState[row] then
        gridState[row][col] = value
        needsRedraw = true
    end
end

-- Naechster Malwert fuer einen A-Strich, ausgehend vom aktuellen Zustand der
-- Zelle unter dem Cursor (6. Runde): auf Ebenen 2-3 ein 3-Zustands-Zyklus,
-- auf der Basisebene weiterhin ein 2-Zustands-Toggle.
local function nextStrokeValue(current)
    if offState == TRANSPARENT then
        if current == OPAQUE then return EMPTY
        elseif current == EMPTY then return TRANSPARENT
        else return OPAQUE end
    end
    return (current == OPAQUE) and offState or OPAQUE
end

local function beginStroke()
    local _, row, col = gridView:getSelection()
    if not (row and col and gridState[row]) then return end
    strokeValue = nextStrokeValue(gridState[row][col])
    paintCurrentCell(strokeValue)
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
        -- Laufender Strich malt weiter, solange A gehalten wird
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

-- Baut das 16×16-Tile-Bild aus dem aktuellen gridState. Der Canvas startet in
-- der Farbe des ebenenabhaengigen "Nicht-Tinte"-Zustands (weiss auf Ebene 1,
-- kColorClear auf Ebenen 2-3); nur davon abweichende Pixel werden gesetzt.
local function buildTileImage()
    local bg = PixelTransparency.toColor(offState)
    local newTile = gfx.image.new(GRID_COLS, GRID_ROWS, bg)
    gfx.pushContext(newTile)
        for y = 1, GRID_ROWS do
            for x = 1, GRID_COLS do
                local color = PixelTransparency.toColor(gridState[y][x])
                if color ~= bg then
                    gfx.setColor(color)
                    gfx.drawPixel(x - 1, y - 1)
                end
            end
        end
    gfx.popContext()
    return newTile
end

-- Spec 011: den 16x16-Zustand VOR der ersten Rotation dieser Sitzung sichern
-- (Undo der Rotation stellt genau dieses Bild wieder her; zuvor gemalte Pixel
-- bleiben erhalten, weil der Snapshot erst bei der Rotation genommen wird).
local function snapshotBeforeRotation()
    if not rotationSnapshotTaken then
        rotationSnapshotImage = buildTileImage()
        rotationSnapshotTaken = true
    end
end

-- Spec 011: liefert das Pre-Rotation-Bild dieser Sitzung (oder nil) und setzt
-- den Snapshot zurueck. Von ZoomRoom:setNewTile beim Commit aufgerufen.
function PixelRoom:consumeRotationSnapshot()
    local img = rotationSnapshotImage
    rotationSnapshotImage = nil
    rotationSnapshotTaken = false
    return img
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

-- Spec 011: PixelRoom -> Tile View. Committet das bearbeitete Tile (ueber
-- ZoomRoom, das dabei einen etwaigen Rotation-Snapshot in den Undo-Verlauf
-- gibt) und die offenen Zoom-Raster-Edits, dann zurueck in den EditorRoom.
-- Genau die etablierte PixelRoom-Exit-Kette aus main.lua:gameWillTerminate.
local function commitAndReturnToEditor()
    commitToZoomRoom()
    if nextRoom and nextRoom.commitForTerminate then nextRoom:commitForTerminate() end
    if switchRoomFunction and editorRoom then switchRoomFunction(editorRoom) end
end

-- Initialize the room with shared data and dependencies
function PixelRoom:init(switchRoom, nextRoomReference, editorRoomReference)
    switchRoomFunction = switchRoom
    nextRoom = nextRoomReference
    editorRoom = editorRoomReference   -- Spec 011
    for y = 1, GRID_ROWS do
        gridState[y] = {}
        for x = 1, GRID_COLS do
            gridState[y][x] = offState
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

    -- Spec 011: Schuettel-Sample lesen + an EditorRoom weiterreichen. Der
    -- Callback committet bei erkannter Kante SOFORT und wechselt in den Tile
    -- View. Review F9: danach MUSS update() zurueckkehren, sonst malt der Rest
    -- (Crank-Block, Malraster + UndoPrompt.draw) das Pixel-Raster fuer einen
    -- Frame ueber den neuen Raum.
    do
        local ax, ay, az = playdate.readAccelerometer()
        if ax and editorRoom and editorRoom.onShakeSample then
            local roomLeft = false
            editorRoom:onShakeSample(ax, ay, az, function()
                roomLeft = true
                commitAndReturnToEditor()
            end)
            if roomLeft then return end
        end
    end

    -- Spec 008 (AD-036, Contract PR-01): pro update() wird GENAU EINE
    -- Crank-Lese-API verwendet - analog zu EditorRoom:handleCrank() (Spec
    -- 006 CR-01). Bei gehaltener B-Taste bleibt getCrankTicks(4) fuer die
    -- Zoom-Out-Geste zustaendig (unveraendert); ohne B treibt getCrankChange()
    -- den neuen Rotations-Akkumulator - beide Lesepfade duerfen nie im
    -- selben Frame gemeinsam aufgerufen werden, sonst gehen Grad-/Tick-
    -- Anteile verloren (research.md R2 Detailhinweis).
    -- Spec 011: bei offenem Undo-Dialog keinerlei Crank-/Rotations-/Zoom-Aktion.
    local bHeld = playdate.buttonIsPressed(playdate.kButtonB)
    if UndoPrompt.isOpen() then
        -- Crank-Reste verwerfen, damit nach dem Dialog kein Nachholwert wirkt
        if bHeld then playdate.getCrankTicks(4) else playdate.getCrankChange() end
    elseif bHeld then
        local crankTicks = playdate.getCrankTicks(4) or 0
        -- Standard-Lua statt pdc-Kurzform "+=" (haelt die Datei headless testbar)
        ticks = ticks + crankTicks
        if ticks <= -4 then
            ticks = 0
            if switchRoomFunction then
                commitToZoomRoom()
                switchRoomFunction(nextRoom)
                return   -- Review F9: Raum gewechselt -> restliches update() nicht mehr ausfuehren
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
            snapshotBeforeRotation()   -- Spec 011: Pre-Rotation-Zustand sichern
            rotateGridClockwise()
        elseif rotationAccumDegrees <= -360 then
            rotationAccumDegrees = rotationAccumDegrees + 360
            snapshotBeforeRotation()
            rotateGridCounterClockwise()
        end
    end

    if needsRedraw or UndoPrompt.isOpen() then
        -- draw a background
        gfx.clear(gfx.kColorWhite)
        gfx.setPattern({ 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55 })
        gfx.fillRect(0, 0, 400, 240)
        gridView:drawInRect(PADDING_X, PADDING_Y, GRID_COLS * CELL_SIZE, GRID_ROWS * CELL_SIZE)
        UndoPrompt.draw()   -- Spec 011: modaler Dialog ueber dem Malraster
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
    playdate.startAccelerometer()   -- Spec 011 (FR-017): Sensor in den Editier-Views aktiv
    -- System-Menü: Checkbox "All Similar" + "Invert"
    local menu = playdate.getSystemMenu()
    menu:removeAllMenuItems()
    menu:addCheckmarkMenuItem("All Similar", changeAllSimilar, function(checked)
        changeAllSimilar = checked
    end)
    menu:addMenuItem("Invert", function()
        -- Spec 010: Tinte <-> "Nicht-Tinte"-Zustand der aktiven Ebene tauschen
        -- (offState = weiss auf Ebene 1, transparent auf Ebenen 2-3).
        for y = 1, GRID_ROWS do
            for x = 1, GRID_COLS do
                local s = gridState[y][x]
                if s == OPAQUE then
                    gridState[y][x] = offState
                elseif s == offState then
                    gridState[y][x] = OPAQUE
                end
            end
        end
        needsRedraw = true
    end)
    print("Entered PixelRoom")
end

function PixelRoom:inputHandler()
    -- Spec 011 FR-013: bei offenem Undo-Dialog schluckt der Raum alle Eingaben;
    -- nur A (Ja) und B (Nein) wirken auf den Dialog.
    return {
        upButtonDown = function()
            if UndoPrompt.isOpen() then return end
            startDirectionHold("up")
        end,
        upButtonUp = function()
            if UndoPrompt.isOpen() then return end
            stopDirectionHold("up")
        end,
        downButtonDown = function()
            if UndoPrompt.isOpen() then return end
            startDirectionHold("down")
        end,
        downButtonUp = function()
            if UndoPrompt.isOpen() then return end
            stopDirectionHold("down")
        end,
        leftButtonDown = function()
            if UndoPrompt.isOpen() then return end
            startDirectionHold("left")
        end,
        leftButtonUp = function()
            if UndoPrompt.isOpen() then return end
            stopDirectionHold("left")
        end,
        rightButtonDown = function()
            if UndoPrompt.isOpen() then return end
            startDirectionHold("right")
        end,
        rightButtonUp = function()
            if UndoPrompt.isOpen() then return end
            stopDirectionHold("right")
        end,
        AButtonDown = function()
            if UndoPrompt.isOpen() then UndoPrompt.handleA(); needsRedraw = true; return end
            beginStroke()
        end,
        AButtonUp = function()
            if UndoPrompt.isOpen() then return end
            endStroke()
        end,
        -- Spec 010 (US2, 5. Runde — Hardware-Test): B malt NICHT mehr (frueher
        -- FR-007). B ist allein der Zoom-Out-Modifier — B halten + Kurbel
        -- zurueck verlaesst den PixelRoom (siehe update(), Contract PR-01).
        -- Der einzelne B-Tipp bleibt bewusst folgenlos (kein stray Pixel beim
        -- Loslassen der Zoom-Geste mehr). Spec 011: bei offenem Dialog = (B) Nein.
        BButtonDown = function()
            if UndoPrompt.isOpen() then UndoPrompt.handleB(); needsRedraw = true end
        end,
        BButtonUp = function() end
    }
end
