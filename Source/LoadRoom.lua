-- LoadRoom.lua
-- Datei-Browser für Hans Dither.
-- Drei-Spalten-Ansicht, max. 6 Dateien, Löschen per Systemmenü.
-- Tastatur nur bei Scale 1 verfügbar: vor/nach Eingabe wird Scale umgeschaltet.

import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/timer"
import "CoreLibs/keyboard"

local gfx = playdate.graphics

LoadRoom = {}

local switchRoomFunction
local nextRoom
local needsRedraw

-- Konstanten
local GRID_COLS = 3
local MAX_FILES = 6
-- Zell-Innengröße (ohne Padding). Padding 1px ringsum → Gesamt-Zelle 66×30 px.
-- 3 Spalten × 66 = 198 px Breite, 3 Zeilen × 30 = 90 px Höhe.
local CELL_W    = 64
local CELL_H    = 28

-- Datenliste und Vorschau-Cache
local savedNames  = {}   -- Array von Dateinamen {"map1", "map2", …}
local previewCache = {}  -- {[name] = gfx.image|nil}

-- ── Datastore-Hilfsfunktionen ─────────────────────────────────────────────────

-- Liest die gespeicherte Index-Datei aus dem Datastore.
local function readSaveIndex()
    local idx = playdate.datastore.read("saves/index")
    return (idx and idx.names) and idx.names or {}
end

-- Ergänzt die Index-Datei um einen neuen Namen (Duplikate ignoriert).
local function addToIndex(name)
    playdate.file.mkdir("saves")
    local idx = playdate.datastore.read("saves/index") or {names = {}}
    for _, n in ipairs(idx.names) do
        if n == name then return end
    end
    table.insert(idx.names, name)
    playdate.datastore.write(idx, "saves/index")
end

-- Befüllt previewCache mit den Vorschaubildern aller übergebenen Dateinamen.
local function loadPreviews(names)
    previewCache = {}
    for _, name in ipairs(names) do
        previewCache[name] = playdate.datastore.readImage("saves/" .. name .. "_preview")
    end
end

-- Löscht alle Dateien eines Projekts und entfernt es aus dem Index.
local function deleteSave(name)
    -- JSON-Tilemap-Datei
    playdate.datastore.delete("saves/" .. name)
    -- Vorschaubild
    local prev = "saves/" .. name .. "_preview.pdi"
    if playdate.file.exists(prev) then playdate.file.delete(prev) end
    -- Custom-Tile-Bilder (Index 4+)
    local i = 4
    while true do
        local p = "saves/" .. name .. "_img" .. i .. ".pdi"
        if not playdate.file.exists(p) then break end
        playdate.file.delete(p)
        i += 1
    end
    -- Aus Index-Datei entfernen
    local idx = playdate.datastore.read("saves/index") or {names = {}}
    for j, n in ipairs(idx.names) do
        if n == name then table.remove(idx.names, j); break end
    end
    playdate.datastore.write(idx, "saves/index")
end

-- Berechnet die benötigte Zeilenanzahl für das Grid.
local function getGridRows()
    -- 1 Zelle für „+Neu", dann savedNames
    return math.max(1, math.ceil((1 + #savedNames) / GRID_COLS))
end

-- ── GridView ──────────────────────────────────────────────────────────────────
-- Innere Zellgröße 64×28 + 1px Padding ringsum = Gesamtzelle 66×30 px
local gridView = playdate.ui.gridview.new(CELL_W, CELL_H)
gridView:setNumberOfColumns(GRID_COLS)
gridView:setCellPadding(1, 1, 1, 1)

-- Zeigt „Loeschen" im Systemmenü wenn eine Datei-Zelle selektiert ist;
-- entfernt den Eintrag bei der „+Neu"-Zelle.
local function updateMenuItems()
    local menu = playdate.getSystemMenu()
    menu:removeAllMenuItems()
    local _, row, col = gridView:getSelection()
    local linearIndex = (row - 1) * GRID_COLS + col
    if linearIndex > 1 then
        local name = savedNames[linearIndex - 1]
        if name then
            -- Callback wird aufgerufen, wenn der Nutzer den Menüpunkt bestätigt
            menu:addMenuItem("loeschen", function()
                deleteSave(name)
                savedNames = readSaveIndex()
                loadPreviews(savedNames)
                gridView:setNumberOfRows(getGridRows())
                gridView:setSelection(1, 1, 1)
                updateMenuItems()
                needsRedraw = true
            end)
        end
    end
end

-- Zeichnet eine Zelle:
-- Linearer Index 1 = „+Neu", Index 2..n+1 = savedNames[1..n]
function gridView:drawCell(section, row, column, selected, x, y, width, height)
    local linearIndex = (row - 1) * GRID_COLS + column
    local totalCells  = 1 + #savedNames
    -- Überzählige Zellen (letzte Zeile teilweise leer) leer lassen
    if linearIndex > totalCells then return end

    -- Hintergrund der Zelle
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
        -- „+Neu"-Zelle: großes „+" zentriert
        if selected then
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        else
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
        end
        -- „+" vertikal und horizontal zentriert im inneren Bereich
        gfx.drawTextAligned("+", x + width // 2, y + height // 2 - 5, kTextAlignment.center)
    else
        -- Datei-Zelle: Preview-Bild, skaliert auf 0.2 → 40×24 px, zentriert in 64×28
        local name = savedNames[linearIndex - 1]
        if name then
            local preview = previewCache[name]
            if preview then
                local px = x + (width  - 40) // 2
                local py = y + (height - 24) // 2
                -- Invertierter Zeichenmodus bei Selektion (weiße Pixel auf schwarzem Bg)
                if selected then
                    gfx.setImageDrawMode(gfx.kDrawModeInverted)
                else
                    gfx.setImageDrawMode(gfx.kDrawModeCopy)
                end
                preview:drawScaled(px, py, 0.2)
            else
                -- Kein Preview vorhanden: leerer Platzhalter-Rahmen
                if selected then
                    gfx.setColor(gfx.kColorWhite)
                else
                    gfx.setColor(gfx.kColorBlack)
                end
                gfx.drawRect(x + (width - 30) // 2, y + (height - 18) // 2, 30, 18)
            end
        end
    end

    -- Zeichenmodus zurücksetzen
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

-- ── Room-Lifecycle ────────────────────────────────────────────────────────────

function LoadRoom:init(switchRoom, nextRoomReference)
    switchRoomFunction = switchRoom
    nextRoom = nextRoomReference
    needsRedraw = true
end

function LoadRoom:update()
    -- Keyboard offen: B-Taste bricht die Eingabe ab
    if playdate.keyboard.isVisible() then
        if playdate.buttonJustPressed(playdate.kButtonB) then
            playdate.keyboard.hide()  -- löst keyboardWillHideCallback(false) aus
        end
        -- Vorschautext im unteren Bereich soll live mitscrollen
        needsRedraw = true
    end

    if needsRedraw or gridView.isScrolling then
        gfx.clear(gfx.kColorWhite)

        -- Titelzeile (y 0..12)
        gfx.drawText("Hans Dither", 4, 2)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawLine(0, 12, 199, 12)

        -- Grid (y 13..102: 3 Zeilen × 30 px = 90 px)
        gridView:drawInRect(1, 13, 198, 90)

        -- Trennlinie unten
        gfx.setColor(gfx.kColorBlack)
        gfx.drawLine(0, 104, 199, 104)

        -- ── Unterer Info-Bereich (y 105..119) ────────────────────────────────
        -- Keyboard geöffnet: aktuell eingetippten Text als Live-Vorschau anzeigen
        -- Keyboard zu: Namen der selektierten Zelle anzeigen
        local infoText
        if playdate.keyboard.isVisible() then
            local t = playdate.keyboard.text
            infoText = "> " .. (t or "")
        else
            local _, row, col = gridView:getSelection()
            local idx = (row - 1) * GRID_COLS + col
            if idx == 1 then
                if #savedNames >= MAX_FILES then
                    infoText = "[Max. " .. MAX_FILES .. " Dateien erreicht]"
                else
                    infoText = "[+ Neue Karte]"
                end
            else
                infoText = savedNames[idx - 1] or ""
            end
        end
        gfx.drawText(infoText, 4, 108)

        needsRedraw = false
    end

    playdate.timer.updateTimers()
end

function LoadRoom:entered()
    -- Systemmenü aufräumen (z.B. TileRoom-Items entfernen)
    playdate.getSystemMenu():removeAllMenuItems()
    -- Dateiliste und Vorschaubilder aktualisieren
    savedNames = readSaveIndex()
    loadPreviews(savedNames)
    gridView:setNumberOfRows(getGridRows())
    gridView:setSelection(1, 1, 1)
    updateMenuItems()
    needsRedraw = true
    print("Entered LoadRoom")
end

-- ── Input Handler ─────────────────────────────────────────────────────────────

function LoadRoom:inputHandler()
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
                -- „+ Neue Karte": nur wenn MAX_FILES noch nicht erreicht
                if #savedNames >= MAX_FILES then return end
                -- Keyboard benötigt Display-Scale 1
                playdate.display.setScale(1)
                playdate.keyboard.show("")
                playdate.keyboard.keyboardWillHideCallback = function(confirmed)
                    playdate.display.setScale(2)
                    if confirmed then
                        local name = playdate.keyboard.text
                        if name and #name > 0 then
                            addToIndex(name)
                            nextRoom:setFileName(name)
                            nextRoom:newMap()
                            switchRoomFunction(nextRoom)
                            return  -- Raum verlassen → kein needsRedraw nötig
                        end
                    end
                    -- Abbruch oder leerer Name: zurück zur Liste
                    savedNames = readSaveIndex()
                    gridView:setNumberOfRows(getGridRows())
                    updateMenuItems()
                    needsRedraw = true
                end
            else
                -- Vorhandene Datei öffnen
                local name = savedNames[linearIndex - 1]
                if name then
                    nextRoom:setFileName(name)
                    nextRoom:loadFromFile(name)
                    switchRoomFunction(nextRoom)
                end
            end
        end
    }
end
