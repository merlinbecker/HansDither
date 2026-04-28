-- LoadRoom.lua
-- Room-Auswahl innerhalb eines Games.
-- Zeigt alle Rooms eines Games in einem 3-Spalten-Grid.
-- Wird von GameRoom aufgerufen, nachdem ein Game ausgewählt wurde.

import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/timer"
import "CoreLibs/keyboard"
import "PulpGameIO"
import "loadingBar"
import "RoomOperation"
import "LoadRoomGrid"

local gfx = playdate.graphics

LoadRoom = {}

local switchRoomFunction
local nextRoom           -- TileRoom
local backRoom           -- GameRoom
local needsRedraw

local pendingOpenIdx     -- 1-basierter Room-Index für verzögertes Öffnen
local pendingOpenIsNew = false

local HOLD_INITIAL_DELAY_MS = 220
local HOLD_REPEAT_MS = 90

local gridView
local updateMenuItems
local roomGrid

-- Konstanten
local GRID_COLS = 3
local MAX_ROOMS = 6
local CELL_W    = 128
local CELL_H    = 56

-- Game-Kontext
local currentGameName = nil   -- Name des aktuell geöffneten Games
local currentGameData = nil   -- v2 Game-Daten (rooms, tiles, frames)
local currentPulpState = nil  -- Vollstaendiges Pulp-Dokument + Zuordnungen
local roomLoadingBar  = loadingBar.new()
local roomOperation = nil
local shouldLoadGameOnEnter = false
local currentGameIsNew = false

local function markDirty()
    needsRedraw = true
end

local function isOperationActive()
    return roomOperation and roomOperation:isActive() or false
end

local function startLoadOperation()
    if currentGameIsNew or not currentGameName then
        return
    end

    roomOperation:start("Loading...", "reading save", function()
        return coroutine.create(function()
            local function yieldProgress(fraction, detail)
                roomLoadingBar:updateFraction(fraction, detail)
                needsRedraw = true
                coroutine.yield()
            end

        coroutine.yield()

        local saved = playdate.datastore.read("saves/" .. currentGameName)
        if not saved then
            currentGameData = nil
            currentPulpState = nil
            roomGrid:refreshRoomNames(currentGameData)
            roomGrid:loadRoomPreviews(currentGameData, currentGameName)
            gridView:setNumberOfRows(roomGrid:getGridRows())
            gridView:setSelection(1, 1, 1)
            updateMenuItems()
            roomLoadingBar:updateFraction(1, "no save found")
            needsRedraw = true
            coroutine.yield()
            return
        end

            roomLoadingBar:updateFraction(0.1, "analyzing...")
            needsRedraw = true
            coroutine.yield()

            local preparedGameData, preparedPulpState = PulpGameIO.prepareLoadedGame(
                currentGameName,
                saved,
                function(phase, current, total, detail)
                    if phase == "tiles" then
                        local ratio = total > 0 and (current / total) or 1
                        yieldProgress(0.15 + (0.35 * ratio), detail)
                    elseif phase == "rooms" then
                        local ratio = total > 0 and (current / total) or 1
                        yieldProgress(0.5 + (0.2 * ratio), detail)
                    elseif phase == "prepare" then
                        yieldProgress(0.12, detail)
                    elseif phase == "normalize" then
                        yieldProgress(0.72, detail)
                    elseif phase == "sparse-tiles" then
                        yieldProgress(0.78, detail)
                    elseif phase == "sparse-frames" then
                        yieldProgress(0.82, detail)
                    elseif phase == "finalize" then
                        yieldProgress(0.86, detail)
                    elseif phase == "done" then
                        yieldProgress(0.9, detail)
                    else
                        local ratio = total > 0 and (current / total) or 1
                        yieldProgress(0.7 + (0.15 * ratio), detail)
                    end
                end
            )
        currentGameData = preparedGameData
        currentPulpState = preparedPulpState

            roomLoadingBar:updateFraction(0.93, "updating rooms")
            roomGrid:refreshRoomNames(currentGameData)
            needsRedraw = true
            coroutine.yield()

            roomLoadingBar:updateFraction(0.97, "loading previews")
            roomGrid:loadRoomPreviews(currentGameData, currentGameName)
            gridView:setNumberOfRows(roomGrid:getGridRows())
            gridView:setSelection(1, 1, 1)
            updateMenuItems()
            needsRedraw = true
            coroutine.yield()

            roomLoadingBar:updateFraction(1, "Done")
            needsRedraw = true
            coroutine.yield()
        end)
    end)
end

-- Öffnet den TileRoom für einen bestimmten Room.
-- roomIdx: 1-basierter Lua-Index in gameData.rooms
local function openTileRoom(roomIdx, isNew)
    -- Game-Daten an TileRoom übergeben
    nextRoom:setGame(currentGameName, currentGameData, currentPulpState)
    if isNew then
        -- Neuen Room erstellen und laden
        local newIdx = nextRoom:newRoom()
        -- gameData wird von TileRoom aktualisiert
        currentGameData = nextRoom:getGameData()
        currentPulpState = nextRoom:getPulpDocument()
    else
        nextRoom:setRoom(roomIdx)
    end
    switchRoomFunction(nextRoom)
end

-- Merkt einen Room-Wechsel vor (für nach Keyboard-Close).
local function queueOpenTileRoom(roomIdx, isNew)
    pendingOpenIdx = roomIdx
    pendingOpenIsNew = isNew and true or false
end

-- Löscht einen Room aus dem aktuellen Game.
-- roomIdx: 1-basierter Lua-Index
local function deleteRoom(roomIdx)
    if not currentGameData or not currentGameData.rooms then return end
    -- Mindestens 1 Room muss bleiben
    if #currentGameData.rooms <= 1 then return end
    -- Room-Preview löschen
    local room = currentGameData.rooms[roomIdx]
    if room then
        local prevPath = "saves/" .. currentGameName .. "_room" .. room.id .. "_preview.pdi"
        if playdate.file.exists(prevPath) then
            playdate.file.delete(prevPath)
        end
    end
    -- Room aus gameData entfernen
    table.remove(currentGameData.rooms, roomIdx)
    -- Game speichern
    playdate.datastore.write(currentGameData, "saves/" .. currentGameName)
    -- Listen aktualisieren
    roomGrid:refreshRoomNames(currentGameData)
    roomGrid:loadRoomPreviews(currentGameData, currentGameName)
end

-- ── GridView ──────────────────────────────────────────────────────────────────
gridView = playdate.ui.gridview.new(CELL_W, CELL_H)
gridView:setNumberOfColumns(GRID_COLS)
gridView:setCellPadding(1, 1, 1, 1)
roomGrid = LoadRoomGrid.new({
    gfx = gfx,
    gridView = gridView,
    gridCols = GRID_COLS,
    maxRooms = MAX_ROOMS,
    holdInitialDelayMs = HOLD_INITIAL_DELAY_MS,
    holdRepeatMs = HOLD_REPEAT_MS
})

-- Nach gridView-Aufbau initialisieren, da isOperationActive von roomOperation abhaengt
roomOperation = RoomOperation.new(roomLoadingBar, markDirty)

-- Aktualisiert das Systemmenü: immer "Zurueck", optional "Loeschen".
updateMenuItems = function()
    local menu = playdate.getSystemMenu()
    menu:removeAllMenuItems()
    -- "Zurueck" zum GameRoom (immer sichtbar)
    menu:addMenuItem("Back", function()
        if backRoom and switchRoomFunction then
            switchRoomFunction(backRoom)
        end
    end)
    local _, row, col = gridView:getSelection()
    local linearIndex = (row - 1) * GRID_COLS + col
    local roomNames = roomGrid:getRoomNames()
    if linearIndex > 1 and #roomNames > 1 then
        local roomIdx = linearIndex - 1
        if roomIdx <= #roomNames then
            menu:addMenuItem("loeschen", function()
                deleteRoom(roomIdx)
                gridView:setNumberOfRows(roomGrid:getGridRows())
                gridView:setSelection(1, 1, 1)
                updateMenuItems()
                needsRedraw = true
            end)
        end
    end
end

-- Zeichnet eine Zelle.
function gridView:drawCell(section, row, column, selected, x, y, width, height)
    roomGrid:drawCell(section, row, column, selected, x, y, width, height)
end

-- ── Room-Lifecycle ────────────────────────────────────────────────────────────

function LoadRoom:init(switchRoom, nextRoomReference, backRoomReference)
    switchRoomFunction = switchRoom
    nextRoom = nextRoomReference
    backRoom = backRoomReference
    needsRedraw = true
end

-- Wird von GameRoom aufgerufen, bevor zu LoadRoom gewechselt wird.
-- Lädt Game-Daten und bereitet Room-Liste vor.
function LoadRoom:setGame(gameName, isNew)
    currentGameName = gameName
    currentGameIsNew = isNew and true or false
    shouldLoadGameOnEnter = not currentGameIsNew
    currentGameData = nil
    currentPulpState = nil
    roomGrid:refreshRoomNames(currentGameData)
end

function LoadRoom:update()
    if isOperationActive() then
        roomOperation:resume(function(err)
            print("LoadRoom operation failed:", tostring(err))
        end)
    else
        roomGrid:processDirectionHold(function()
            updateMenuItems()
            needsRedraw = true
        end)
    end

    -- Verzögerter Room-Wechsel nach Keyboard-Close
    if not isOperationActive() and pendingOpenIdx and not playdate.keyboard.isVisible() then
        local roomIdx = pendingOpenIdx
        local isNew = pendingOpenIsNew
        pendingOpenIdx = nil
        pendingOpenIsNew = false
        openTileRoom(roomIdx, isNew)
        return
    end

    if playdate.keyboard.isVisible() then
        if playdate.buttonJustPressed(playdate.kButtonB) then
            playdate.keyboard.hide()
        end
        needsRedraw = true
    end

    if needsRedraw or gridView.isScrolling then
        roomGrid:draw(currentGameName, playdate.keyboard.isVisible(), playdate.keyboard.text)

        roomLoadingBar:draw()

        needsRedraw = false
    end

    playdate.timer.updateTimers()
end

function LoadRoom:entered()
    roomGrid:clearDirectionHold()
    local menu = playdate.getSystemMenu()
    menu:removeAllMenuItems()
    -- Nach Rückkehr aus TileRoom: gameData aktualisieren (könnte gespeichert worden sein)
    if currentGameName and nextRoom and nextRoom.getGameData then
        local updatedData = nextRoom:getGameData()
        if updatedData and updatedData.name == currentGameName then
            currentGameData = updatedData
            if nextRoom.getPulpDocument then
                currentPulpState = nextRoom:getPulpDocument()
            end
            roomGrid:refreshRoomNames(currentGameData)
            roomGrid:loadRoomPreviews(currentGameData, currentGameName)
        end
    end

    if currentGameIsNew then
        roomGrid:refreshRoomNames(currentGameData)
        roomGrid:loadRoomPreviews(currentGameData, currentGameName)
        gridView:setNumberOfRows(roomGrid:getGridRows())
        gridView:setSelection(1, 1, 1)
        updateMenuItems()
    elseif shouldLoadGameOnEnter then
        shouldLoadGameOnEnter = false
        startLoadOperation()
    else
        roomGrid:refreshRoomNames(currentGameData)
        roomGrid:loadRoomPreviews(currentGameData, currentGameName)
        gridView:setNumberOfRows(roomGrid:getGridRows())
        gridView:setSelection(1, 1, 1)
        updateMenuItems()
    end
    needsRedraw = true
    print("Entered LoadRoom")
end

-- ── Input Handler ─────────────────────────────────────────────────────────────

function LoadRoom:inputHandler()
    return {
        upButtonDown = function()
            if isOperationActive() then return end
            roomGrid:startDirectionHold("up", function()
                updateMenuItems()
                needsRedraw = true
            end)
        end,
        upButtonUp = function()
            if isOperationActive() then return end
            roomGrid:stopDirectionHold("up")
        end,
        downButtonDown = function()
            if isOperationActive() then return end
            roomGrid:startDirectionHold("down", function()
                updateMenuItems()
                needsRedraw = true
            end)
        end,
        downButtonUp = function()
            if isOperationActive() then return end
            roomGrid:stopDirectionHold("down")
        end,
        leftButtonDown = function()
            if isOperationActive() then return end
            roomGrid:startDirectionHold("left", function()
                updateMenuItems()
                needsRedraw = true
            end)
        end,
        leftButtonUp = function()
            if isOperationActive() then return end
            roomGrid:stopDirectionHold("left")
        end,
        rightButtonDown = function()
            if isOperationActive() then return end
            roomGrid:startDirectionHold("right", function()
                updateMenuItems()
                needsRedraw = true
            end)
        end,
        rightButtonUp = function()
            if isOperationActive() then return end
            roomGrid:stopDirectionHold("right")
        end,
        AButtonDown = function()
            if isOperationActive() then return end
            local _, row, col = gridView:getSelection()
            local linearIndex = (row - 1) * GRID_COLS + col
            local roomNames = roomGrid:getRoomNames()
            if linearIndex == 1 then
                -- „+ Neuer Room": nur wenn MAX_ROOMS noch nicht erreicht
                if #roomNames >= MAX_ROOMS then return end
                if not currentGameData then
                    -- Neues Game: erstelle und lade direkt
                    queueOpenTileRoom(1, true)
                else
                    -- Neuen Room hinzufügen
                    queueOpenTileRoom(#roomNames + 1, true)
                end
            else
                -- Vorhandenen Room öffnen
                local roomIdx = linearIndex - 1
                if roomIdx <= #roomNames then
                    queueOpenTileRoom(roomIdx, false)
                end
            end
        end,
        BButtonDown = function()
            if isOperationActive() then return end
            -- Zurück zum GameRoom
            if backRoom and switchRoomFunction then
                switchRoomFunction(backRoom)
            end
        end
    }
end
