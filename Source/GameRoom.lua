-- GameRoom.lua
-- Game-Auswahl-Screen: zeigt alle gespeicherten Games in einem 3-Spalten-Grid.
-- Adaptiert vom LoadRoom-Pattern.

import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/timer"
import "CoreLibs/keyboard"

local gfx = playdate.graphics

GameRoom = {}

local switchRoomFunction
local nextRoom           -- LoadRoom
local needsRedraw

local pendingOpenName
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
local MAX_GAMES = 6
local CELL_W    = 64
local CELL_H    = 28

-- Datenliste und Vorschau-Cache
local savedGames   = {}   -- Array von Game-Namen {"game1", "game2", …}
local previewCache = {}   -- {[name] = gfx.image|nil}

-- ── Datastore-Hilfsfunktionen ─────────────────────────────────────────────────

-- Liest die gespeicherte Index-Datei im aktuellen Format.
local function readGameIndex()
    local idx = playdate.datastore.read("saves/index")
    if not idx then return {} end
    if type(idx.games) ~= "table" then return {} end
    return idx.games
end

-- Ergänzt die Index-Datei um einen neuen Game-Namen (Duplikate ignoriert).
local function addToIndex(name)
    playdate.file.mkdir("saves")
    local idx = playdate.datastore.read("saves/index") or { games = {} }
    if not idx.games then idx.games = {} end
    for _, n in ipairs(idx.games) do
        if n == name then return end
    end
    table.insert(idx.games, name)
    playdate.datastore.write(idx, "saves/index")
end

-- Befüllt previewCache mit den Vorschaubildern aller Games.
local function loadPreviews(names)
    previewCache = {}
    for _, name in ipairs(names) do
        previewCache[name] = playdate.datastore.readImage("saves/" .. name .. "_preview")
    end
end

-- Öffnet den LoadRoom für ein Game.
local function openLoadRoom(name, isNew)
    nextRoom:setGame(name, isNew)
    switchRoomFunction(nextRoom)
end

-- Merkt einen Room-Wechsel vor.
local function queueOpenLoadRoom(name, isNew)
    pendingOpenName = name
    pendingOpenIsNew = isNew and true or false
end

-- Löscht alle Dateien eines Games und entfernt es aus dem Index.
local function deleteGame(name)
    -- Game-Daten lesen, um Room-IDs für Preview-Löschung zu erhalten
    local data = playdate.datastore.read("saves/" .. name)
    -- Game-JSON löschen
    playdate.datastore.delete("saves/" .. name)
    -- Game-Preview
    local prev = "saves/" .. name .. "_preview.pdi"
    if playdate.file.exists(prev) then playdate.file.delete(prev) end
    -- Room-Previews: über tatsächliche Room-IDs iterieren (nicht sequenziell proben)
    if data and data.rooms then
        for _, room in ipairs(data.rooms) do
            local p = "saves/" .. name .. "_room" .. room.id .. "_preview.pdi"
            if playdate.file.exists(p) then playdate.file.delete(p) end
        end
    else
        -- Fallback für v1-Daten oder fehlende Game-Datei: sequenziell proben
        local i = 0
        while true do
            local p = "saves/" .. name .. "_room" .. i .. "_preview.pdi"
            if not playdate.file.exists(p) then break end
            playdate.file.delete(p)
            i = i + 1
        end
    end
    -- Aus Index entfernen
    local idx = playdate.datastore.read("saves/index") or { games = {} }
    local games = idx.games or {}
    for j, n in ipairs(games) do
        if n == name then table.remove(games, j); break end
    end
    idx.games = games
    playdate.datastore.write(idx, "saves/index")
end

-- Berechnet die benötigte Zeilenanzahl für das Grid.
local function getGridRows()
    return math.max(1, math.ceil((1 + #savedGames) / GRID_COLS))
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

-- Zeigt „Loeschen" im Systemmenü wenn eine Game-Zelle selektiert ist.
updateMenuItems = function()
    local menu = playdate.getSystemMenu()
    menu:removeAllMenuItems()
    local _, row, col = gridView:getSelection()
    local linearIndex = (row - 1) * GRID_COLS + col
    if linearIndex > 1 then
        local name = savedGames[linearIndex - 1]
        if name then
            menu:addMenuItem("loeschen", function()
                deleteGame(name)
                savedGames = readGameIndex()
                loadPreviews(savedGames)
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
    local totalCells  = 1 + #savedGames
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
        local name = savedGames[linearIndex - 1]
        if name then
            local preview = previewCache[name]
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

function GameRoom:init(switchRoom, nextRoomReference)
    switchRoomFunction = switchRoom
    nextRoom = nextRoomReference
    needsRedraw = true
end

function GameRoom:update()
    processDirectionHold()

    if pendingOpenName and not playdate.keyboard.isVisible() then
        local name = pendingOpenName
        local isNew = pendingOpenIsNew
        pendingOpenName = nil
        pendingOpenIsNew = false
        openLoadRoom(name, isNew)
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

        -- Titelzeile
        gfx.drawText("Hans Dither", 4, 2)
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
                if #savedGames >= MAX_GAMES then
                    infoText = "[Max. " .. MAX_GAMES .. " Games erreicht]"
                else
                    infoText = "[+ Neues Game]"
                end
            else
                infoText = savedGames[idx - 1] or ""
            end
        end
        gfx.drawText(infoText, 4, 108)

        needsRedraw = false
    end

    playdate.timer.updateTimers()
end

function GameRoom:entered()
    clearDirectionHold()
    playdate.getSystemMenu():removeAllMenuItems()
    savedGames = readGameIndex()
    loadPreviews(savedGames)
    gridView:setNumberOfRows(getGridRows())
    gridView:setSelection(1, 1, 1)
    updateMenuItems()
    needsRedraw = true
    print("Entered GameRoom")
end

-- ── Input Handler ─────────────────────────────────────────────────────────────

function GameRoom:inputHandler()
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
                -- „+ Neues Game": nur wenn MAX_GAMES noch nicht erreicht
                if #savedGames >= MAX_GAMES then return end
                playdate.display.setScale(1)
                playdate.keyboard.show("")
                playdate.keyboard.keyboardWillHideCallback = function(confirmed)
                    playdate.display.setScale(2)
                    if confirmed then
                        local name = playdate.keyboard.text
                        if name and #name > 0 then
                            addToIndex(name)
                            queueOpenLoadRoom(name, true)
                            return
                        end
                    end
                    savedGames = readGameIndex()
                    gridView:setNumberOfRows(getGridRows())
                    updateMenuItems()
                    needsRedraw = true
                end
            else
                -- Vorhandenes Game öffnen
                local name = savedGames[linearIndex - 1]
                if name then
                    queueOpenLoadRoom(name, false)
                end
            end
        end
    }
end
