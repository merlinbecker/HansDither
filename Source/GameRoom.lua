-- GameRoom.lua
-- Game-Auswahl-Screen: zeigt alle gespeicherten Games in einem 3-Spalten-Grid.
-- Adaptiert vom LoadRoom-Pattern.

import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/timer"
import "CoreLibs/keyboard"
import "Migration" -- MIGRATION: Index-Migration

local gfx = playdate.graphics

GameRoom = {}

local switchRoomFunction
local nextRoom           -- LoadRoom
local needsRedraw

local pendingOpenName
local pendingOpenIsNew = false

-- Konstanten
local GRID_COLS = 3
local MAX_GAMES = 6
local CELL_W    = 64
local CELL_H    = 28

-- Datenliste und Vorschau-Cache
local savedGames   = {}   -- Array von Game-Namen {"game1", "game2", …}
local previewCache = {}   -- {[name] = gfx.image|nil}

-- ── Datastore-Hilfsfunktionen ─────────────────────────────────────────────────

-- Liest die gespeicherte Index-Datei. Unterstützt altes und neues Format.
local function readGameIndex()
    local idx = playdate.datastore.read("saves/index")
    if not idx then return {} end
    -- MIGRATION: Altes Format {names:[...]} konvertieren
    if Migration.needsIndexMigration(idx) then
        idx = Migration.migrateIndex(idx)
        playdate.datastore.write(idx, "saves/index")
        print("Info: Index von v1 (names) zu v2 (games) migriert")
    end
    return idx.games or {}
end

-- Ergänzt die Index-Datei um einen neuen Game-Namen (Duplikate ignoriert).
local function addToIndex(name)
    playdate.file.mkdir("saves")
    local idx = playdate.datastore.read("saves/index") or { games = {} }
    -- MIGRATION: Altes Format {names:[...]} konvertieren
    if Migration.needsIndexMigration(idx) then
        idx = Migration.migrateIndex(idx)
    end
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
    -- Alte v1-Dateien aufräumen (falls Migration noch nicht erfolgt war)
    local i = 4
    while true do
        local p = "saves/" .. name .. "_img" .. i .. ".pdi"
        if not playdate.file.exists(p) then break end
        playdate.file.delete(p)
        i = i + 1
    end
    -- Aus Index entfernen
    local idx = playdate.datastore.read("saves/index") or { games = {} }
    if Migration.needsIndexMigration(idx) then -- MIGRATION:
        idx = Migration.migrateIndex(idx) -- MIGRATION:
    end -- MIGRATION:
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

-- ── GridView ──────────────────────────────────────────────────────────────────
local gridView = playdate.ui.gridview.new(CELL_W, CELL_H)
gridView:setNumberOfColumns(GRID_COLS)
gridView:setCellPadding(1, 1, 1, 1)

-- Zeigt „Loeschen" im Systemmenü wenn eine Game-Zelle selektiert ist.
local function updateMenuItems()
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
            gridView:selectPreviousRow(true, true, true)
            updateMenuItems()
            needsRedraw = true
        end,
        downButtonDown = function()
            gridView:selectNextRow(true, true, true)
            updateMenuItems()
            needsRedraw = true
        end,
        leftButtonDown = function()
            gridView:selectPreviousColumn(true, true, true)
            updateMenuItems()
            needsRedraw = true
        end,
        rightButtonDown = function()
            gridView:selectNextColumn(true, true, true)
            updateMenuItems()
            needsRedraw = true
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
