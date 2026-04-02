-- StartRaum.lua

import "CoreLibs/graphics"
import "CoreLibs/timer"
import "CoreLibs/ui"
import "CoreLibs/animation"
import "CoreLibs/crank"
import "CoreLibs/object" -- für playdate.graphics.image.new()
import "PixelRoom"


--
-- imageHash(image): Erzeugt einen einfachen Hash für ein playdate.graphics.image
-- Damit können Tiles verglichen werden, ohne die Bilddaten direkt zu vergleichen.
-- Nutzt image:sample(x, y) für alle Pixel und berechnet daraus einen Hashwert.
-- Für kleine Tiles (z.B. 8x8 oder 16x16) ist das performant genug.
-- https://de.wikipedia.org/wiki/FNV_(Informatik)
-- Rückgabe: Hex-String als Hashrepräsentation
--
function imageHash(image)
    local w, h = image:getSize()
    -- FNV-1a Offset Basis als signed 32-bit: 0x811C9DC5 = -2128831035
    -- Playdate nutzt 32-bit Lua-Integers (max 2147483647), daher darf 2166136261 nicht direkt verwendet werden.
    local hash = -2128831035
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local pixel = image:sample(x, y) or 0 -- 0=weiß, 1=schwarz, 2=transparent
            -- FNV-1a Hash Schritt: XOR dann Multiplikation
            -- Kein % 4294967296 nötig: 32-bit Lua wrapat Integer-Overflow automatisch
            hash = hash ~ pixel
            hash = hash * 16777619
        end
    end
    -- Hex-String zurückgeben (8-stellig); %x formatiert Integer als unsigned, also korrekt für negative Werte
    return string.format("%08x", hash)
end


--
-- findOrAppendImage(imagetable, image, hashCache):
-- Sucht, ob das Bild (per Hash) schon in der Imagetable ist.
-- Falls ja, gibt den Index des ersten Treffers zurück.
-- Falls nein, hängt das Bild an die Imagetable an, cached den Hash und gibt den neuen Index zurück.
-- hashCache ist ein Array mit den Hashes der Imagetable (Index = Bildindex)
--
-- Rückgabe: Index (1-basiert)
--

local hashCache = {}
--
-- findOrAppendImage(imagetable, image, hashCache):
-- Sucht, ob das Bild (per Hash) schon in der Imagetable ist.
-- Falls ja, gibt den Index und die unveränderte Imagetable zurück.
-- Falls nein, erzeugt eine neue Imagetable mit dem Bild am Ende, cached den Hash und gibt neuen Index und neue Imagetable zurück.
-- Rückgabe: index, imagetable
function findOrAppendImage(imagetable, image, hashCache)
    local imgHash = imageHash(image)
    -- Prüfe, ob Hash schon im Cache ist
    for idx, cachedHash in ipairs(hashCache) do
        if cachedHash == imgHash then
            return idx, imagetable -- Bild schon vorhanden
        end
    end
    -- Bild ist neu: Neue Imagetable mit zusätzlichem Bild erzeugen
    local oldCount = imagetable:getLength()
    local newTable = playdate.graphics.imagetable.new(oldCount + 1)
    for i = 1, oldCount do
        newTable:setImage(i, imagetable:getImage(i))
    end
    newTable:setImage(oldCount + 1, image)
    hashCache[oldCount + 1] = imgHash
    return oldCount + 1, newTable
end


local gfx = playdate.graphics

TileRoom = {}

local switchRoomFunction
local nextRoom
local needsRedraw

local GRID_COLS = 25
local GRID_ROWS = 15
local CELL_SIZE = 8 -- 8x8 Pixel pro Zelle, wenn die Skalierung aus ist, 16x16
local SCREEN_W = 200 -- Playdate-Bildschirmbreite in Pixeln

local upHeld = false

-- Tile Picker: zeigt das aktuell gewählte Tile beim Crank-Drehen in einer Ecke an
local PICKER_TIMEOUT_MS = 3000 -- Fenster verschwindet nach 3s ohne Crank
local WIN_SIZE = 22            -- 1px Border + 2px Padding + 16px Tile (8x2) + 2px Padding + 1px Border
local WIN_MARGIN = 4           -- Abstand der Fensterecke zum Bildschirmrand
local tilePickerIndex = 3      -- aktuell angezeigter Tile-Index (min. 3, Tiles 1+2 werden übersprungen)
local tilePickerVisible = false
local tilePickerLastCrankMs = 0

-- Matrix-Imagetable (2 Tiles, 8x8) laden (siehe 7.20.12 Image Table)
local origImagetable = gfx.imagetable.new("images/cellbg")
assert(origImagetable, "Imagetable konnte nicht geladen werden!")

-- hier wird die Tilemap geladen, 
-- diese sollte eigentlich dann vom LoadRoom übergeben werden.
-- todo: bessere Imagetable laden, dann kann ich mir die Erstellung des schwarzen Tiles sparen
-- Neue Imagetable mit 3 Einträgen anlegen
local cellImagetable = gfx.imagetable.new(3)
local img1=origImagetable:getImage(1)
cellImagetable:setImage(1, img1)
hashCache[1]=imageHash(img1)

local img2=origImagetable
cellImagetable:setImage(2, origImagetable:getImage(2))
hashCache[2]=imageHash(origImagetable:getImage(2))

-- Schwarzes Tile erzeugen und als drittes Tile anhängen
local blackTile = gfx.image.new(CELL_SIZE, CELL_SIZE)
gfx.pushContext(blackTile)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, CELL_SIZE, CELL_SIZE)
gfx.popContext()
cellImagetable:setImage(3, blackTile)
hashCache[3]=imageHash(blackTile)



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
local gridView = playdate.ui.gridview.new(CELL_SIZE, CELL_SIZE)
gridView:setNumberOfSections(1)
gridView:setNumberOfColumns(GRID_COLS)
gridView:setNumberOfRowsInSection(1, GRID_ROWS)

-- Cursor-Blinker (immer looping)
local cursorBlinker = playdate.graphics.animation.blinker.new(500, 500, true, nil, true)
cursorBlinker:startLoop()

local lastBlinkState = cursorBlinker.on
local needsRedraw = true

-- Mittelwert initiale Selektion in der Bildschirmmitte (12, 8) in Sektion 1
-- setSelection(section, row, column)
gridView:setSelection(1, math.floor(GRID_ROWS / 2) + 1, math.floor(GRID_COLS / 2) + 1)


-- Zeichne eine Zelle und optional Cursor, bei Auswahl
function gridView:drawCell(section, row, column, selected, x, y, width, height)
    local selSection, selRow, selCol = gridView:getSelection()
    -- Die Tilemap wird im Haupt-Draw (playdate.update) gezeichnet!
    -- Cursor immer in der selektierten Zelle zeichnen
    local isCursor = (section == selSection and row == selRow and column == selCol)
    if isCursor and cursorBlinker.on then
        local tileIndex = tilemap:getTileAtPosition(column, row)
        local cx = x + width / 2
        local cy = y + height / 2
        -- Cursor-Farbe per Pixel-Sample der Tile-Mitte bestimmen.
        -- sample() gibt gfx.kColorWhite, gfx.kColorBlack oder gfx.kColorClear zurück.
        local tile = cellImagetable:getImage(tileIndex)
        local centerPixel = tile and tile:sample(CELL_SIZE // 2, CELL_SIZE // 2) or gfx.kColorWhite
        if centerPixel == gfx.kColorBlack then
            -- Tile-Mitte ist schwarz → Cursor weiß für Sichtbarkeit
            gfx.setColor(gfx.kColorWhite)
        else
            -- Tile-Mitte ist weiß oder transparent → Cursor schwarz
            gfx.setColor(gfx.kColorBlack)
        end
        gfx.fillCircleAtPoint(cx, cy, 2)
    end
end



--
-- drawTilePickerWindow(): Zeichnet das Tile-Picker-Popup in der Ecke, die am weitesten
-- vom Cursor entfernt ist. Links -> oben rechts, Rechts -> oben links.
-- Das Tile wird 2x skaliert (image:drawScaled) für bessere Lesbarkeit.
-- Wird nur gezeichnet, wenn tilePickerVisible == true.
--
local function drawTilePickerWindow()
    if not tilePickerVisible then return end

    -- Position: gegenüberliegende horizontale Seite zum Cursor
    local _, _, selCol = gridView:getSelection()
    local px
    if selCol <= GRID_COLS / 2 then
        -- Cursor in linker Hälfte → Fenster oben rechts
        px = SCREEN_W - WIN_SIZE - WIN_MARGIN
    else
        -- Cursor in rechter Hälfte → Fenster oben links
        px = WIN_MARGIN
    end
    local py = WIN_MARGIN

    -- Hintergrund (weiß, damit das Tile auf klarem Grund erscheint)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(px, py, WIN_SIZE, WIN_SIZE)
    -- Rahmen (schwarz, 1px)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(px, py, WIN_SIZE, WIN_SIZE)
    -- Tile 2x skaliert (8x8 → 16x16) mit 3px Abstand zum Fensterrand
    local tile = cellImagetable:getImage(tilePickerIndex)
    if tile then
        tile:drawScaled(px + 3, py + 3, 2.0)
    end
end

-- A-Button malt mit dem aktuell im Tile Picker gewählten Tile (tilePickerIndex).
-- Ist die Zelle bereits auf tilePickerIndex gesetzt, wird sie auf Tile 1 (Hintergrund) zurückgesetzt.
local function toggleCurrentCell()
    local section, row, col = gridView:getSelection()
    if row and col then
        local current = tilemap:getTileAtPosition(col, row)
        if current == tilePickerIndex then
            -- Zelle löschen: auf Hintergrund-Tile zurücksetzen
            tilemap:setTileAtPosition(col, row, 1)
        else
            -- Zelle mit dem aktuell gewählten Picker-Tile füllen
            tilemap:setTileAtPosition(col, row, tilePickerIndex)
        end
        needsRedraw = true
    end
end

-- Initialize the room with shared data and dependencies
function TileRoom:init(switchRoom,nextRoomReference)
    switchRoomFunction = switchRoom
    nextRoom = nextRoomReference
    needsRedraw = true

end

-- Counter for ticks 
local ticks=0

-- Update logic for StartRaum
function TileRoom:update()
    cursorBlinker:updateAll()
    if cursorBlinker.on ~= lastBlinkState then
        lastBlinkState = cursorBlinker.on
        needsRedraw = true
    end
    -- todo, nochmal durchtesten und der drank muss wirklich einmal 360 grad durchgehen
    -- Zoom-Trigger: D-Pad Up gehalten + Crank
    if upHeld then
        ticks += playdate.getCrankTicks(4)
        if ticks >=4 then
            ticks=0
            if switchRoomFunction then
                --set the tilemap and the current position for editing
                -- hier setzen, dann switchen
                local selSection, selRow, selCol = gridView:getSelection()
                local tileIndex = tilemap:getTileAtPosition(selCol, selRow)
                local tile = cellImagetable:getImage(tileIndex)
                nextRoom:setCurrentTile(tile)
                switchRoomFunction(nextRoom)
            end
        end
    else
        ticks = 0
        -- Tile Picker: Crank ohne B-Taste scrollt durch Tiles ab Index 3
        -- getCrankTicks ist stateful – wird nur hier aufgerufen, wenn B NICHT gehalten ist
        local crankTicks = playdate.getCrankTicks(4)
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
            tilePickerVisible = true
            tilePickerLastCrankMs = playdate.getCurrentTimeMilliseconds()
            needsRedraw = true
        end
        -- Timeout-Prüfung: Fenster ausblenden, wenn 3s kein Crank
        if tilePickerVisible then
            if playdate.getCurrentTimeMilliseconds() - tilePickerLastCrankMs > PICKER_TIMEOUT_MS then
                tilePickerVisible = false
                needsRedraw = true
            end
        end
    end

    if needsRedraw then
        gfx.clear(gfx.kColorWhite)
        -- Schritt 5: Tilemap zeichnen (Grid)
        tilemap:draw(0, 0)
        -- Cursor-Overlay via gridView (ruft drawCell für selektierte Zelle auf)
        gridView:drawInRect(0, 0, GRID_COLS * CELL_SIZE, GRID_ROWS * CELL_SIZE)
        -- Tile Picker Popup (erscheint bei Crank ohne B, verschwindet nach 3s)
        drawTilePickerWindow()
        needsRedraw = false
    end

    -- Timer-Update für CoreLib-Timer und GridView (z.B. Scroll- und Blinker-Handling)
    playdate.timer.updateTimers()
end

function TileRoom:entered()
    needsRedraw = true
    -- Tile Picker zurücksetzen, damit kein altes Fenster beim Raumeintritt sichtbar ist
    tilePickerVisible = false
    print("Entered TileRoom")
end


function TileRoom:setNewTile(tile)
    -- Prüfe, ob das Tile schon in der Imagetable ist oder angehängt werden muss
    local index, newTable = findOrAppendImage(cellImagetable, tile, hashCache)
    cellImagetable = newTable
    tilemap:setImageTable(cellImagetable)
    -- Aktuelle Zelle auf das neue Tile setzen
    local selSection, selRow, selCol = gridView:getSelection()
    tilemap:setTileAtPosition(selCol, selRow, index)
end

-- Input handler for StartRaum
function TileRoom:inputHandler()
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
