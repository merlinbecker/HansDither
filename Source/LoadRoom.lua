-- LoadRoom.lua
-- Room-Auswahl innerhalb eines Games.
-- Zeigt alle Rooms eines Games in einem 3-Spalten-Grid.
-- Wird von GameRoom aufgerufen, nachdem ein Game ausgewählt wurde.

import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/timer"
import "CoreLibs/keyboard"
import "PulpGameIO"

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

local directionHold = {
    up = { active = false, nextMs = 0 },
    down = { active = false, nextMs = 0 },
    left = { active = false, nextMs = 0 },
    right = { active = false, nextMs = 0 }
}

local gridView
local updateMenuItems

-- Konstanten
local GRID_COLS = 3
local MAX_ROOMS = 6
local CELL_W    = 64
local CELL_H    = 28

-- Game-Kontext
local currentGameName = nil   -- Name des aktuell geöffneten Games
local currentGameData = nil   -- v2 Game-Daten (rooms, tiles, frames)
local currentPulpState = nil  -- Vollstaendiges Pulp-Dokument + Zuordnungen
local roomNames       = {}    -- Array von Room-Namen für Anzeige
local previewCache    = {}    -- {[roomIndex] = gfx.image|nil}, 1-basiert

-- ── Hilfsfunktionen ──────────────────────────────────────────────────────────

-- Lädt Room-Previews aus dem Datastore.
local function loadRoomPreviews()
    previewCache = {}
    if not currentGameData or not currentGameData.rooms then return end
    for i, room in ipairs(currentGameData.rooms) do
        previewCache[i] = playdate.datastore.readImage(
            "saves/" .. currentGameName .. "_room" .. room.id .. "_preview"
        )
    end
end

-- Aktualisiert die Room-Namen-Liste aus gameData.
local function refreshRoomNames()
    roomNames = {}
    if not currentGameData or not currentGameData.rooms then return end
    for _, room in ipairs(currentGameData.rooms) do
        table.insert(roomNames, room.name or ("Room " .. (room.id + 1)))
    end
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
        -- Initial speichern
        nextRoom:saveToFile()
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
    refreshRoomNames()
    loadRoomPreviews()
end

-- Berechnet die benötigte Zeilenanzahl für das Grid.
local function getGridRows()
    return math.max(1, math.ceil((1 + #roomNames) / GRID_COLS))
end

local function moveSelection(direction)
    if direction == "up" then
        gridView:selectPreviousRow(true, true, true)
    elseif direction == "down" then
        gridView:selectNextRow(true, true, true)
    elseif direction == "left" then
        gridView:selectPreviousColumn(true, true, true)
    elseif direction == "right" then
        gridView:selectNextColumn(true, true, true)
    else
        return
    end
    updateMenuItems()
    needsRedraw = true
end

local function startDirectionHold(direction)
    local state = directionHold[direction]
    if not state then return end
    moveSelection(direction)
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
                moveSelection(direction)
                state.nextMs = nowMs + HOLD_REPEAT_MS
            end
        end
    end
end

-- ── GridView ──────────────────────────────────────────────────────────────────
gridView = playdate.ui.gridview.new(CELL_W, CELL_H)
gridView:setNumberOfColumns(GRID_COLS)
gridView:setCellPadding(1, 1, 1, 1)

-- Aktualisiert das Systemmenü: immer "Zurueck", optional "Loeschen".
updateMenuItems = function()
    local menu = playdate.getSystemMenu()
    menu:removeAllMenuItems()
    -- "Zurueck" zum GameRoom (immer sichtbar)
    menu:addMenuItem("Zurueck", function()
        if backRoom and switchRoomFunction then
            switchRoomFunction(backRoom)
        end
    end)
    local _, row, col = gridView:getSelection()
    local linearIndex = (row - 1) * GRID_COLS + col
    if linearIndex > 1 and #roomNames > 1 then
        local roomIdx = linearIndex - 1
        if roomIdx <= #roomNames then
            menu:addMenuItem("loeschen", function()
                deleteRoom(roomIdx)
                gridView:setNumberOfRows(getGridRows())
                gridView:setSelection(1, 1, 1)
                updateMenuItems()
                needsRedraw = true
            end)
        end
    end
end

-- Zeichnet eine Zelle.
function gridView:drawCell(section, row, column, selected, x, y, width, height)
    local linearIndex = (row - 1) * GRID_COLS + column
    local totalCells  = 1 + #roomNames
    if linearIndex > totalCells then return end

    if selected then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(x, y, width, height)
    else
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(x, y, width, height)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRect(x, y, width, height)
    end

    if linearIndex == 1 then
        if selected then
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        else
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
        end
        gfx.drawTextAligned("+", x + width // 2, y + height // 2 - 5, kTextAlignment.center)
    else
        local roomIdx = linearIndex - 1
        if roomIdx <= #roomNames then
            local preview = previewCache[roomIdx]
            if preview then
                local px = x + (width  - 40) // 2
                local py = y + (height - 24) // 2
                if selected then
                    gfx.setImageDrawMode(gfx.kDrawModeInverted)
                else
                    gfx.setImageDrawMode(gfx.kDrawModeCopy)
                end
                preview:drawScaled(px, py, 0.2)
            else
                if selected then
                    gfx.setColor(gfx.kColorWhite)
                else
                    gfx.setColor(gfx.kColorBlack)
                end
                gfx.drawRect(x + (width - 30) // 2, y + (height - 18) // 2, 30, 18)
            end
        end
    end

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
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
    if isNew then
        -- Neues Game: TileRoom erstellt die Daten, wir brauchen ein leeres Game
        -- TileRoom:newMap() wird beim ersten Room-Öffnen aufgerufen
        currentGameData = nil
        currentPulpState = nil
    else
        local saved = playdate.datastore.read("saves/" .. gameName)
        if saved then
            local preparedGameData, preparedPulpState = PulpGameIO.prepareLoadedGame(gameName, saved)
            currentGameData = preparedGameData
            currentPulpState = preparedPulpState
        end
    end
    refreshRoomNames()
end

function LoadRoom:update()
    processDirectionHold()

    -- Verzögerter Room-Wechsel nach Keyboard-Close
    if pendingOpenIdx and not playdate.keyboard.isVisible() then
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
        gfx.clear(gfx.kColorWhite)

        -- Titelzeile: Game-Name
        local title = currentGameName or "Hans Dither"
        gfx.drawText(title, 4, 2)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawLine(0, 12, 199, 12)

        -- Grid
        gridView:drawInRect(1, 13, 198, 90)

        -- Trennlinie unten
        gfx.setColor(gfx.kColorBlack)
        gfx.drawLine(0, 104, 199, 104)

        -- Unterer Info-Bereich
        local infoText
        if playdate.keyboard.isVisible() then
            local t = playdate.keyboard.text
            infoText = "> " .. (t or "")
        else
            local _, row, col = gridView:getSelection()
            local idx = (row - 1) * GRID_COLS + col
            if idx == 1 then
                if #roomNames >= MAX_ROOMS then
                    infoText = "[Max. " .. MAX_ROOMS .. " Rooms erreicht]"
                else
                    infoText = "[+ Neuer Room]"
                end
            else
                infoText = roomNames[idx - 1] or ""
            end
        end
        gfx.drawText(infoText, 4, 108)

        needsRedraw = false
    end

    playdate.timer.updateTimers()
end

function LoadRoom:entered()
    clearDirectionHold()
    local menu = playdate.getSystemMenu()
    menu:removeAllMenuItems()
    refreshRoomNames()
    loadRoomPreviews()
    gridView:setNumberOfRows(getGridRows())
    gridView:setSelection(1, 1, 1)
    updateMenuItems()
    -- Nach Rückkehr aus TileRoom: gameData aktualisieren (könnte gespeichert worden sein)
    if currentGameName and nextRoom and nextRoom.getGameData then
        local updatedData = nextRoom:getGameData()
        if updatedData and updatedData.name == currentGameName then
            currentGameData = updatedData
            if nextRoom.getPulpDocument then
                currentPulpState = nextRoom:getPulpDocument()
            end
            refreshRoomNames()
            loadRoomPreviews()
        end
    end
    needsRedraw = true
    print("Entered LoadRoom")
end

-- ── Input Handler ─────────────────────────────────────────────────────────────

function LoadRoom:inputHandler()
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
            local _, row, col = gridView:getSelection()
            local linearIndex = (row - 1) * GRID_COLS + col
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
            -- Zurück zum GameRoom
            if backRoom and switchRoomFunction then
                switchRoomFunction(backRoom)
            end
        end
    }
end
