-- TileRoom.lua

import "CoreLibs/graphics"
import "CoreLibs/timer"
import "CoreLibs/ui"
import "CoreLibs/animation"
import "CoreLibs/crank"
import "CoreLibs/object" -- für playdate.graphics.image.new()
import "PixelRoom"
import "PulpGameIO"
import "loadingBar"
import "RoomOperation"
import "TileRoomPersistence"
import "TileRoomEditor"


local hashCache = {}
local gfx = playdate.graphics
local cellImagetable
local showGrid

TileRoom = {}

local switchRoomFunction
local nextRoom
local needsRedraw

local GRID_COLS = 25
local GRID_ROWS = 15
local CELL_SIZE = 8         -- 8x8 Pixel pro Tile (Datengröße, unveränderlich für JSON/Save/Load)
local DISPLAY_CELL_SIZE = 16 -- 16x16 Pixel pro Zelle im GridView (2x Pulp-Pixel auf nativem Display)
local SCREEN_W = 400        -- Playdate-Bildschirmbreite in Pixeln (native Auflösung)
local SCREEN_H = 240        -- Playdate-Bildschirmhoehe in Pixeln (native Auflösung)

local HOLD_INITIAL_DELAY_MS = 220
local HOLD_REPEAT_MS = 80

local EDIT_MODE_TILE_PICKER = "tile_picker"
local EDIT_MODE_ANIMATION = "animation"

local directionHold = {
    up = { active = false, nextMs = 0 },
    down = { active = false, nextMs = 0 },
    left = { active = false, nextMs = 0 },
    right = { active = false, nextMs = 0 }
}

-- Tile Picker: zeigt das aktuell gewählte Tile beim Crank-Drehen in einer Ecke an
local PICKER_TIMEOUT_MS = 3000 -- Fenster verschwindet nach 3s ohne Crank
local B_LONG_PRESS_MS = 1500
local ANIMATION_PLACEHOLDER_FRAME_COUNT = 8
local MODE_BADGE_DURATION_MS = 1500
local WIN_SIZE = 44            -- 1px Border + 6px Padding + 32px Tile (8x4) + 6px Padding + 1px Border
local WIN_MARGIN = 8           -- Abstand der Fensterecke zum Bildschirmrand
local tilePickerIndex = 3      -- aktuell angezeigter Tile-Index (min. 3, Tiles 1+2 werden übersprungen)
local tilePickerVisible = false
local tilePickerLastCrankMs = 0
local currentEditMode = EDIT_MODE_TILE_PICKER
local animationFramePlaceholderIndex = 1
local modeBadgeText = nil
local modeBadgeUntilMs = 0

local bPressTracking = {
    isDown = false,
    downStartMs = 0,
    longPressTriggered = false,
    longPressCancelled = false
}
local bShortPressPending = false

-- Datei-Verwaltung
local currentFileName = nil    -- Name des aktuell geöffneten Games (ohne Pfad)
local backRoom = nil           -- Raum, zu dem nach dem Speichern zurückgewechselt wird

-- Game State (v2): vollständiges Game-Objekt mit allen Rooms
local gameData = nil           -- v2-Game-Tabelle (rooms, tiles, frames)
local pulpState = nil          -- Vollstaendiges Pulp-Dokument + Zuordnungen
local currentRoomIndex = 1     -- 1-basierter Lua-Index in gameData.rooms
local roomLoadingBar = loadingBar.new()
local persistenceConfig = {
    gfx = gfx,
    gridCols = GRID_COLS,
    gridRows = GRID_ROWS,
    cellSize = CELL_SIZE,
    getGameData = function() return gameData end,
    setGameData = function(value) gameData = value end,
    getPulpState = function() return pulpState end,
    setPulpState = function(value) pulpState = value end,
    getCurrentRoomIndex = function() return currentRoomIndex end,
    setCurrentRoomIndex = function(value) currentRoomIndex = value end,
    getCellImagetable = function() return cellImagetable end,
    setCellImagetable = function(value) cellImagetable = value end,
    getHashCache = function() return hashCache end,
    setHashCache = function(value) hashCache = value end,
    getTilePickerIndex = function() return tilePickerIndex end,
    setTilePickerIndex = function(value) tilePickerIndex = value end,
    getShowGrid = function() return showGrid end,
    setShowGrid = function(value) showGrid = value end
}
local persistence = TileRoomPersistence.new(persistenceConfig)
local editor = nil

local function markDirty()
    needsRedraw = true
end

local roomOperation = RoomOperation.new(roomLoadingBar, markDirty)

local function isOperationActive()
    return roomOperation and roomOperation:isActive() or false
end

-- Show Grid: bestimmt, welches Tile als "leer" gilt
-- true  → Tile 1 (Grid) ist der Hintergrund, Löschen setzt auf 1
-- false → Tile 2 (Weiß) ist der Hintergrund, Löschen setzt auf 2
showGrid = true

-- Matrix-Imagetable (2 Tiles, 8x8) laden (siehe 7.20.12 Image Table)
local origImagetable = gfx.imagetable.new("images/cellbg")
assert(origImagetable, "Imagetable konnte nicht geladen werden!")

-- hier wird die Tilemap geladen,
-- diese sollte eigentlich dann vom LoadRoom uebergeben werden.
-- Neue Imagetable mit 3 Einträgen anlegen
cellImagetable = gfx.imagetable.new(3)
local img1=origImagetable:getImage(1)
cellImagetable:setImage(1, img1)
hashCache[1]=persistence:imageHash(img1)

local img2=origImagetable
cellImagetable:setImage(2, origImagetable:getImage(2))
hashCache[2]=persistence:imageHash(origImagetable:getImage(2))

-- Schwarzes Tile erzeugen und als drittes Tile anhängen
local blackTile = gfx.image.new(CELL_SIZE, CELL_SIZE)
gfx.pushContext(blackTile)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, CELL_SIZE, CELL_SIZE)
gfx.popContext()
cellImagetable:setImage(3, blackTile)
hashCache[3]=persistence:imageHash(blackTile)



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
local gridView = playdate.ui.gridview.new(DISPLAY_CELL_SIZE, DISPLAY_CELL_SIZE)
gridView:setNumberOfSections(1)
gridView:setNumberOfColumns(GRID_COLS)
gridView:setNumberOfRowsInSection(1, GRID_ROWS)

-- Cursor-Blinker (immer looping)
local cursorBlinker = playdate.graphics.animation.blinker.new(500, 500, true, nil, true)
cursorBlinker:startLoop()

local lastBlinkState = cursorBlinker.on
local needsRedraw = true

persistenceConfig.tilemap = tilemap
persistenceConfig.origImagetable = origImagetable
persistenceConfig.blackTile = blackTile

-- Offscreen-Buffer für Tilemap: 8x8-Tiles werden in 200x120-Buffer gerendert
-- und dann 2x skaliert auf das native 400x240-Display gezogen.
local tilemapBuffer = gfx.image.new(GRID_COLS * CELL_SIZE, GRID_ROWS * CELL_SIZE, gfx.kColorWhite)

editor = TileRoomEditor.new({
    gfx = gfx,
    tilemap = tilemap,
    gridView = gridView,
    cursorBlinker = cursorBlinker,
    cellSize = DISPLAY_CELL_SIZE,
    screenW = SCREEN_W,
    screenH = SCREEN_H,
    gridCols = GRID_COLS,
    winSize = WIN_SIZE,
    winMargin = WIN_MARGIN,
    directionHold = directionHold,
    holdInitialDelayMs = HOLD_INITIAL_DELAY_MS,
    holdRepeatMs = HOLD_REPEAT_MS,
    getCellImagetable = function() return cellImagetable end,
    getTilePickerIndex = function() return tilePickerIndex end,
    getTilePickerVisible = function() return tilePickerVisible end,
    getTilePickerLastCrankMs = function() return tilePickerLastCrankMs end,
    getShowGrid = function() return showGrid end,
    markDirty = markDirty
})

-- Mittelwert initiale Selektion in der Bildschirmmitte (12, 8) in Sektion 1
-- setSelection(section, row, column)
gridView:setSelection(1, math.floor(GRID_ROWS / 2) + 1, math.floor(GRID_COLS / 2) + 1)


-- Zeichne eine Zelle und optional Cursor, bei Auswahl
function gridView:drawCell(section, row, column, selected, x, y, width, height)
    editor:drawCell(section, row, column, selected, x, y, width, height)
end

-- Initialize the room with shared data and dependencies
-- backRoomReference: Raum für "Save + Back" (LoadRoom)
function TileRoom:init(switchRoom, nextRoomReference, backRoomReference)
    switchRoomFunction = switchRoom
    nextRoom = nextRoomReference
    backRoom = backRoomReference
    needsRedraw = true
end

-- Setzt den Dateinamen des aktuell geöffneten Games.
-- Wird von LoadRoom/GameRoom aufgerufen, bevor zu TileRoom gewechselt wird.
function TileRoom:setFileName(name)
    currentFileName = name
end

-- Setzt Game-Kontext: name + v2-Daten, baut Imagetable aus tiles/frames auf.
-- Wird von LoadRoom aufgerufen, bevor ein Room geladen wird.
function TileRoom:setGame(name, data, externalPulpState)
    currentFileName = name
    gameData = data
    pulpState = externalPulpState

    if gameData and not pulpState then
        local normalizedDocument, normalizedState = PulpGameIO.buildSaveDocument(name, gameData, nil)
        normalizedState.document = normalizedDocument
        pulpState = normalizedState
    end

    -- Imagetable aus v2 tiles/frames aufbauen
    persistence:rebuildImagetableFromGameData()
    -- Ersten Room in Tilemap laden, damit kein stale State übrigbleibt
    if gameData and gameData.rooms and #gameData.rooms > 0 then
        currentRoomIndex = 1
        persistence:loadRoomIntoTilemap(1)
    end
end

-- Gibt die aktuelle gameData-Tabelle zurück (für LoadRoom/GameRoom).
function TileRoom:getGameData()
    return gameData
end

-- Gibt das vollstaendige Pulp-Dokument samt Zuordnungen zurueck.
-- LoadRoom nutzt diesen Zustand, damit spaetere Saves vorhandene Pulp-Attribute behalten.
function TileRoom:getPulpDocument()
    return pulpState
end

function TileRoom:getEditMode()
    return currentEditMode
end

function TileRoom:isTilePickerMode()
    return currentEditMode == EDIT_MODE_TILE_PICKER
end

function TileRoom:isAnimationMode()
    return currentEditMode == EDIT_MODE_ANIMATION
end

function TileRoom:setEditMode(mode)
    if mode == EDIT_MODE_TILE_PICKER or mode == EDIT_MODE_ANIMATION then
        currentEditMode = mode
        if currentEditMode == EDIT_MODE_ANIMATION then
            tilePickerVisible = false
        end
        needsRedraw = true
    end
end

function TileRoom:toggleEditMode()
    if currentEditMode == EDIT_MODE_TILE_PICKER then
        currentEditMode = EDIT_MODE_ANIMATION
        tilePickerVisible = false
        modeBadgeText = "animationMode"
        modeBadgeUntilMs = (playdate.getCurrentTimeMilliseconds() or 0) + MODE_BADGE_DURATION_MS
    else
        currentEditMode = EDIT_MODE_TILE_PICKER
        modeBadgeText = "tileMode"
        modeBadgeUntilMs = (playdate.getCurrentTimeMilliseconds() or 0) + MODE_BADGE_DURATION_MS
    end
    needsRedraw = true
end

function TileRoom:getAnimationFramePlaceholderIndex()
    return animationFramePlaceholderIndex
end

function TileRoom:setAnimationFramePlaceholderIndex(value)
    if not value then return end
    animationFramePlaceholderIndex = value
    needsRedraw = true
end

function TileRoom:consumeBShortPress()
    if bShortPressPending then
        bShortPressPending = false
        return true
    end
    return false
end

function TileRoom:showTilePicker()
    tilePickerVisible = true
    tilePickerLastCrankMs = playdate.getCurrentTimeMilliseconds() or 0
    needsRedraw = true
end

function TileRoom:updateTilePickerTimeout()
    if not tilePickerVisible then return end
    local nowMs = playdate.getCurrentTimeMilliseconds() or 0
    if nowMs - tilePickerLastCrankMs > PICKER_TIMEOUT_MS then
        tilePickerVisible = false
        needsRedraw = true
    end
end

function TileRoom:pickTileFromCurrentCell()
    local _, selRow, selCol = gridView:getSelection()
    if not selRow or not selCol then return false end

    local pickedIndex = tilemap:getTileAtPosition(selCol, selRow)
    if not pickedIndex then return false end

    local maxTile = cellImagetable and cellImagetable:getLength() or 0
    if maxTile < 1 then return false end
    if pickedIndex < 1 or pickedIndex > maxTile then return false end

    tilePickerIndex = pickedIndex
    TileRoom:showTilePicker()
    return true
end

local function resetBPressTracking()
    bPressTracking.isDown = false
    bPressTracking.downStartMs = 0
    bPressTracking.longPressTriggered = false
    bPressTracking.longPressCancelled = false
end

local function cancelBLongPress()
    if not bPressTracking.isDown then return end
    bPressTracking.longPressCancelled = true
end

local function updateBPressTiming()
    local nowMs = playdate.getCurrentTimeMilliseconds()
    local isDownNow = playdate.buttonIsPressed(playdate.kButtonB)
    local events = {
        isDown = isDownNow,
        shortPress = false,
        longPress = false
    }

    if isDownNow and not bPressTracking.isDown then
        bPressTracking.isDown = true
        bPressTracking.downStartMs = nowMs
        bPressTracking.longPressTriggered = false
        bPressTracking.longPressCancelled = false
    elseif isDownNow and bPressTracking.isDown then
        if not bPressTracking.longPressCancelled and nowMs - bPressTracking.downStartMs >= B_LONG_PRESS_MS then
            bPressTracking.longPressTriggered = true
            events.longPress = true
            -- Solange B gehalten wird, nach jeweils 1.5s erneut ein Long-Press-Event ausloesen.
            bPressTracking.downStartMs = nowMs
        end
    elseif not isDownNow and bPressTracking.isDown then
        if not bPressTracking.longPressTriggered and not bPressTracking.longPressCancelled then
            events.shortPress = true
        end
        resetBPressTracking()
    end

    return events
end

-- Speichert den aktuellen Room-State in gameData zurück und lädt einen anderen Room.
-- roomIdx: 1-basierter Lua-Index in gameData.rooms
function TileRoom:setRoom(roomIdx)
    -- Aktuellen Room-State sichern, bevor wir wechseln
    persistence:syncCurrentRoomToGameData()
    -- Neuen Room laden
    currentRoomIndex = roomIdx
    persistence:loadRoomIntoTilemap(roomIdx)
    tilePickerIndex = math.max(3, math.min(tilePickerIndex, cellImagetable:getLength()))
    needsRedraw = true
end

-- Erstellt einen neuen leeren Room im aktuellen Game.
-- Rückgabe: 1-basierter Lua-Index des neuen Rooms
function TileRoom:newRoom()
    if not gameData then
        -- Falls kein Game geladen: komplett neues Game erstellen
        -- createEmptyGameData erzeugt bereits einen Room (id=0), daher direkt diesen verwenden
        gameData = persistence:createEmptyGameData(currentFileName or "untitled")
        local normalizedDocument, normalizedState = PulpGameIO.buildSaveDocument(currentFileName or "untitled", gameData, nil)
        normalizedState.document = normalizedDocument
        pulpState = normalizedState
        persistence:rebuildImagetableFromGameData()
        currentRoomIndex = 1
        persistence:loadRoomIntoTilemap(1)
        tilePickerIndex = 3
        needsRedraw = true
        return 1
    end
    -- Neue Room-ID = höchste vorhandene + 1 (0-basiert im Speicherformat)
    local maxId = -1
    for _, room in ipairs(gameData.rooms) do
        if room.id > maxId then maxId = room.id end
    end
    local newId = maxId + 1
    -- Leere Tile-Daten: alle auf 0 (white, 0-basiert)
    local emptyTiles = {}
    for i = 1, GRID_COLS * GRID_ROWS do
        emptyTiles[i] = 0
    end
    local newRoom = {
        id = newId,
        name = "Room " .. (newId + 1),
        tiles = emptyTiles
    }
    table.insert(gameData.rooms, newRoom)
    if pulpState and pulpState.roomMetadataById then
        pulpState.roomMetadataById[newId] = nil
    end
    -- Neuen Room direkt laden
    currentRoomIndex = #gameData.rooms
    persistence:loadRoomIntoTilemap(currentRoomIndex)
    tilePickerIndex = 3
    needsRedraw = true
    return currentRoomIndex
end

-- Setzt Tilemap und Imagetable auf den Ausgangszustand zurück (neues leeres Game).
-- Erstellt Game mit einem leeren Room und den 3 Basis-Tiles.
function TileRoom:newMap()
    gameData = persistence:createEmptyGameData(currentFileName or "untitled")
    local normalizedDocument, normalizedState = PulpGameIO.buildSaveDocument(currentFileName or "untitled", gameData, nil)
    normalizedState.document = normalizedDocument
    pulpState = normalizedState
    persistence:rebuildImagetableFromGameData()
    currentRoomIndex = 1
    persistence:loadRoomIntoTilemap(1)
    tilePickerIndex = 3
    needsRedraw = true
end

-- Speichert das aktuelle Game im v2-Format.
function TileRoom:saveToFile(afterSave)
    if not currentFileName or not gameData then return end
    if isOperationActive() then return end

    local name = currentFileName
    playdate.file.mkdir("saves")

    roomOperation:start("Speichere Spiel...", "Vorbereitung", function()
        return coroutine.create(function()
            local function yieldProgress(fraction, detail)
                roomLoadingBar:updateFraction(fraction, detail)
                needsRedraw = true
                coroutine.yield()
            end

            coroutine.yield()

            roomLoadingBar:updateFraction(0.1, "Room synchronisieren")
            persistence:syncCurrentRoomToGameData()
            needsRedraw = true
            coroutine.yield()

            roomLoadingBar:updateFraction(0.15, "Tiles komprimieren")
            local compacted = persistence:compactTileState(function(current, total, detail)
                local ratio = total > 0 and (current / total) or 1
                yieldProgress(0.15 + (0.25 * ratio), detail)
            end)
            cellImagetable = compacted.imageTable
            hashCache = compacted.hashCache
            tilemap:setImageTable(cellImagetable)
            tilePickerIndex = compacted.tilePickerIndex
            pulpState = PulpGameIO.remapTileMappings(pulpState, compacted.oldToNew)
            persistence:loadRoomIntoTilemap(currentRoomIndex)
            needsRedraw = true
            coroutine.yield()

            roomLoadingBar:updateFraction(0.45, "Tiles serialisieren")
            local v2Tiles = {}
            local v2Frames = {}
            local baseNames = { "white", "grid", "black" }
            for i = 1, compacted.maxTile do
                local img = cellImagetable:getImage(i)
                if img then
                    local frameId = i - 1
                    local tileName = i <= 3 and baseNames[i] or ("tile_" .. frameId)
                    v2Tiles[i] = {
                        id = frameId,
                        name = tileName,
                        type = 0,
                        frames = { frameId }
                    }
                    v2Frames[i] = {
                        id = frameId,
                        data = persistence:encodeFrameData(img)
                    }
                    if not persistence:tileRoundtripOk(img) then
                        print("Warnung: Rekonstruktionstest fehlgeschlagen fuer Tile:", i)
                    end
                end

                if compacted.maxTile > 0 and (i == compacted.maxTile or i == 1 or i % 8 == 0) then
                    yieldProgress(0.45 + (0.2 * (i / compacted.maxTile)), "Tile " .. i .. " von " .. compacted.maxTile)
                end
            end
            gameData.tiles = v2Tiles
            gameData.frames = v2Frames
            gameData.name = name
            needsRedraw = true
            coroutine.yield()

            roomLoadingBar:updateFraction(0.68, "Dokument aufbauen")
            local outputDocument, outputState = PulpGameIO.buildSaveDocument(
                name,
                gameData,
                pulpState,
                { currentRoomIndex = currentRoomIndex },
                function(phase, current, total, detail)
                    local ratio = total > 0 and (current / total) or 1
                    yieldProgress(0.68 + (0.14 * ratio), detail)
                end
            )
            outputState.document = outputDocument
            pulpState = outputState
            gameData.version = outputDocument.version
            needsRedraw = true
            coroutine.yield()

            roomLoadingBar:updateFraction(0.88, "JSON schreiben")
            playdate.datastore.write(outputDocument, "saves/" .. name)
            needsRedraw = true
            coroutine.yield()

            roomLoadingBar:updateFraction(0.95, "Vorschaubilder schreiben")
            local currentRoomId = gameData.rooms[currentRoomIndex].id
            local currentPreview = persistence:renderPreviewImage()
            playdate.datastore.writeImage(currentPreview, "saves/" .. name .. "_room" .. currentRoomId .. "_preview")

            if currentRoomIndex == 1 then
                playdate.datastore.writeImage(currentPreview, "saves/" .. name .. "_preview")
            else
                local firstRoomPreview = persistence:renderRoomPreview(gameData.rooms[1])
                playdate.datastore.writeImage(firstRoomPreview, "saves/" .. name .. "_preview")
            end

            needsRedraw = true
            coroutine.yield()

            roomLoadingBar:updateFraction(1, "Fertig")
            needsRedraw = true
            coroutine.yield()
        end)
    end, afterSave)
end

-- Lädt ein gespeichertes Game aus dem Datastore.
function TileRoom:loadFromFile(name)
    local saved = playdate.datastore.read("saves/" .. name)
    if not saved then return end

    currentFileName = name
    local preparedGameData, preparedPulpState = PulpGameIO.prepareLoadedGame(name, saved)
    if not preparedGameData then
        return
    end
    gameData = preparedGameData
    pulpState = preparedPulpState

    persistence:rebuildImagetableFromGameData()

    -- Ersten Room laden
    currentRoomIndex = 1
    persistence:loadRoomIntoTilemap(1)

    tilePickerIndex = math.max(3, math.min(tilePickerIndex, cellImagetable:getLength()))
    needsRedraw = true
end

-- Counter for ticks 
local ticks=0

-- Update logic for StartRaum
function TileRoom:update()
    if isOperationActive() then
        roomOperation:resume(function(err)
            print("TileRoom operation failed:", tostring(err))
        end)
    else
        editor:processDirectionHold()
    end

    cursorBlinker:updateAll()
    if cursorBlinker.on ~= lastBlinkState then
        lastBlinkState = cursorBlinker.on
        needsRedraw = true
    end
    -- Zoom-Trigger: B gehalten + Crank
    if isOperationActive() then
        ticks = 0
        resetBPressTracking()
    else
        local nowMs = playdate.getCurrentTimeMilliseconds()
        local crankTicks = playdate.getCrankTicks(4) or 0
        local zoomHeld = playdate.buttonIsPressed(playdate.kButtonB)
        if zoomHeld and crankTicks ~= 0 then
            if not bPressTracking.isDown then
                bPressTracking.isDown = true
                bPressTracking.downStartMs = nowMs
                bPressTracking.longPressTriggered = false
            end
            cancelBLongPress()
        end

        local bEvents = updateBPressTiming()
        if bEvents.longPress then
            TileRoom:toggleEditMode()
        end
        if bEvents.shortPress then
            bShortPressPending = true
        end
        if TileRoom:consumeBShortPress() and TileRoom:isTilePickerMode() then
            TileRoom:pickTileFromCurrentCell()
        end

        if zoomHeld then
            ticks += crankTicks
            if ticks >=4 then
                ticks=0
                if switchRoomFunction then
                    local context = TileRoom:getTileContext3x3()
                    nextRoom:setFromTileContext(context)
                    switchRoomFunction(nextRoom)
                end
            end
        else
            ticks = 0
            if TileRoom:isTilePickerMode() then
                -- Tile Picker: Crank ohne B-Taste scrollt durch Tiles ab Index 3
                -- getCrankTicks ist stateful – wird pro Frame genau einmal ausgelesen
                if crankTicks ~= 0 and cellImagetable:getLength() >= 3 then
                    local maxTile = cellImagetable:getLength()
                    -- Index in Richtung des Crank-Ticks verschieben (+1 oder -1)
                    tilePickerIndex = tilePickerIndex + (crankTicks > 0 and 1 or -1)
                    -- Wrap: Index bleibt zwischen 3 und maxTile
                    if tilePickerIndex > maxTile then
                        tilePickerIndex = 3
                    elseif tilePickerIndex < 3 then
                        tilePickerIndex = maxTile
                    end
                    TileRoom:showTilePicker()
                end
            elseif TileRoom:isAnimationMode() and crankTicks ~= 0 then
                animationFramePlaceholderIndex = animationFramePlaceholderIndex + (crankTicks > 0 and 1 or -1)
                if animationFramePlaceholderIndex > ANIMATION_PLACEHOLDER_FRAME_COUNT then
                    animationFramePlaceholderIndex = 1
                elseif animationFramePlaceholderIndex < 1 then
                    animationFramePlaceholderIndex = ANIMATION_PLACEHOLDER_FRAME_COUNT
                end
                needsRedraw = true
            end
        end

        TileRoom:updateTilePickerTimeout()
    end

    if needsRedraw then
        gfx.clear(gfx.kColorWhite)
            -- Tilemap in 200x120-Buffer zeichnen, dann 2x auf natives 400x240-Display skalieren
            gfx.lockFocus(tilemapBuffer)
                tilemap:draw(0, 0)
            gfx.unlockFocus()
            tilemapBuffer:drawScaled(0, 0, 2.0)
            -- Cursor-Overlay via gridView mit 16x16-Zellen (DISPLAY_CELL_SIZE)
            gridView:drawInRect(0, 0, GRID_COLS * DISPLAY_CELL_SIZE, GRID_ROWS * DISPLAY_CELL_SIZE)
        -- Tile Picker Popup (erscheint bei Crank ohne B, verschwindet nach 3s)
        editor:drawTilePickerWindow()
        if modeBadgeText then
            local nowMs = playdate.getCurrentTimeMilliseconds() or 0
            if nowMs <= modeBadgeUntilMs then
                editor:drawModeBauchbinde(modeBadgeText, "left")
            else
                modeBadgeText = nil
            end
        end
        roomLoadingBar:draw()
        needsRedraw = false
    end

    -- Timer-Update für CoreLib-Timer und GridView (z.B. Scroll- und Blinker-Handling)
    playdate.timer.updateTimers()
end

function TileRoom:entered()
    editor:clearDirectionHold()
    needsRedraw = true
    resetBPressTracking()
    bShortPressPending = false
    -- Tile Picker zurücksetzen, damit kein altes Fenster beim Raumeintritt sichtbar ist
    tilePickerVisible = false
    -- Systemmenü: alte Items entfernen, dann "Save + Back" hinzufügen (nur wenn Dateiname gesetzt)
    local menu = playdate.getSystemMenu()
    menu:removeAllMenuItems()
    if currentFileName then
        -- Beim Auslösen: speichern und zurück zum LoadRoom wechseln
        menu:addMenuItem("Save + Back", function()
            TileRoom:saveToFile(function()
                if backRoom and switchRoomFunction then
                    switchRoomFunction(backRoom)
                end
            end)
        end)
    end
    -- Checkbox: Show Grid – tauscht Tile 1 (Grid) ↔ Tile 2 (Weiß) als Hintergrund
    menu:addCheckmarkMenuItem("Show Grid", showGrid, function(checked)
        showGrid = checked
        -- Alle Tiles 1↔2 in der Tilemap tauschen
        local data, width = tilemap:getTiles()
        for i, tileIdx in ipairs(data) do
            if tileIdx == 1 then
                data[i] = 2
            elseif tileIdx == 2 then
                data[i] = 1
            end
        end
        tilemap:setTiles(data, width)
        needsRedraw = true
    end)
    print("Entered TileRoom")
end


function TileRoom:setNewTile(tile)
    -- Prüfe, ob das Tile schon in der Imagetable ist oder angehängt werden muss
    local index, newTable = persistence:findOrAppendImage(cellImagetable, tile, hashCache)
    cellImagetable = newTable
    tilemap:setImageTable(cellImagetable)
    -- Aktuelle Zelle auf das neue Tile setzen
    local selSection, selRow, selCol = gridView:getSelection()
    tilemap:setTileAtPosition(selCol, selRow, index)
    -- gameData tiles/frames synchron halten: neues Tile ggf. als Tile+Frame anhängen
    if gameData and index > #gameData.tiles then
        local frameId = index - 1 -- 0-basiert
        gameData.frames[index] = {
            id = frameId,
            data = persistence:encodeFrameData(tile)
        }
        gameData.tiles[index] = {
            id = frameId,
            name = "tile_" .. frameId,
            type = 0,
            frames = { frameId }
        }
    end
end

-- Überschreibt ein bestehendes Tile in-place (für "Change All Similar Tiles").
-- Alle Zellen in der Tilemap, die diesen Index verwenden, zeigen automatisch das neue Bild.
function TileRoom:updateExistingTile(tile, tileIndex)
    if not tileIndex or tileIndex < 1 then return end
    -- Bild in der Imagetable ersetzen
    cellImagetable:setImage(tileIndex, tile)
    hashCache[tileIndex] = persistence:imageHash(tile)
    tilemap:setImageTable(cellImagetable)
    -- gameData synchron halten
    if gameData and tileIndex <= #gameData.tiles then
        local tileDef = gameData.tiles[tileIndex]
        local frameId = tileDef.frames[1]
        -- Frame-Daten aktualisieren
        for _, f in ipairs(gameData.frames) do
            if f.id == frameId then
                f.data = persistence:encodeFrameData(tile)
                break
            end
        end
    end
    needsRedraw = true
end

-- Gibt den 3×3-Tile-Kontext rund um den aktuellen Cursor zurück.
-- Tiles außerhalb des Rasters werden als nil/0 übergeben (out-of-bounds).
-- Rückgabe-Tabelle:
--   context.tiles[1..9]       – gfx.image oder nil (out-of-bounds)
--   context.tileIndices[1..9] – Imagetable-Index (1-basiert) oder 0 (out-of-bounds)
--   context.cursorSlot        – 1-9, der Slot in dem der Cursor steht (immer 5 = Mitte)
--   context.cursorTileCol     – Tilemap-Spalte des Cursors (1-basiert)
--   context.cursorTileRow     – Tilemap-Zeile des Cursors (1-basiert)
function TileRoom:getTileContext3x3()
    local _, selRow, selCol = gridView:getSelection()
    local tiles        = {}
    local tileIndices  = {}
    local slotIdx = 1
    for dr = -1, 1 do
        for dc = -1, 1 do
            local tileCol = selCol + dc
            local tileRow = selRow + dr
            if tileCol >= 1 and tileCol <= GRID_COLS
            and tileRow >= 1 and tileRow <= GRID_ROWS then
                local idx = tilemap:getTileAtPosition(tileCol, tileRow)
                tiles[slotIdx]       = cellImagetable:getImage(idx)
                tileIndices[slotIdx] = idx
            else
                tiles[slotIdx]       = nil
                tileIndices[slotIdx] = 0
            end
            slotIdx = slotIdx + 1
        end
    end
    return {
        tiles            = tiles,
        tileIndices      = tileIndices,
        cursorSlot       = 5,   -- Mitte des 3×3-Rasters
        cursorTileCol    = selCol,
        cursorTileRow    = selRow,
        showGrid         = showGrid
    }
end

-- Nimmt eine Liste von Tile-Edits aus ZoomRoom entgegen und schreibt sie in Tilemap
-- und Imagetable. Jeder Edit hat folgende Felder:
--   edit.tileCol        – Tilemap-Spalte (1-basiert)
--   edit.tileRow        – Tilemap-Zeile  (1-basiert)
--   edit.image          – gfx.image (neues Tile-Bild)
--   edit.existingIndex  – >0: In-place überschreiben; 0: neu deduplizieren
function TileRoom:applyTileEditsBatch(edits)
    if not edits or #edits == 0 then return end
    for _, edit in ipairs(edits) do
        -- Nur gültige Koordinaten verarbeiten
        if edit.tileCol >= 1 and edit.tileCol <= GRID_COLS
        and edit.tileRow >= 1 and edit.tileRow <= GRID_ROWS
        and edit.image then
            local finalIndex
            if edit.existingIndex and edit.existingIndex > 0 then
                -- In-place: Bild im bestehenden Slot ersetzen
                cellImagetable:setImage(edit.existingIndex, edit.image)
                hashCache[edit.existingIndex] = persistence:imageHash(edit.image)
                tilemap:setImageTable(cellImagetable)
                finalIndex = edit.existingIndex
                -- gameData Frame-Daten synchron halten
                if gameData and edit.existingIndex <= #gameData.tiles then
                    local tileDef = gameData.tiles[edit.existingIndex]
                    local frameId = tileDef.frames[1]
                    for _, f in ipairs(gameData.frames) do
                        if f.id == frameId then
                            f.data = persistence:encodeFrameData(edit.image)
                            break
                        end
                    end
                end
            else
                -- Neu: deduplizieren oder anhängen
                local newIdx, newTable = persistence:findOrAppendImage(cellImagetable, edit.image, hashCache)
                cellImagetable = newTable
                tilemap:setImageTable(cellImagetable)
                finalIndex = newIdx
                -- gameData synchron halten
                if gameData and newIdx > #gameData.tiles then
                    local frameId = newIdx - 1
                    gameData.frames[newIdx] = {
                        id   = frameId,
                        data = persistence:encodeFrameData(edit.image)
                    }
                    gameData.tiles[newIdx] = {
                        id     = frameId,
                        name   = "tile_" .. frameId,
                        type   = 0,
                        frames = { frameId }
                    }
                end
            end
            tilemap:setTileAtPosition(edit.tileCol, edit.tileRow, finalIndex)
        end
    end
    needsRedraw = true
end

-- Input handler for StartRaum
function TileRoom:inputHandler()
    return editor:buildInputHandler(isOperationActive)
end
