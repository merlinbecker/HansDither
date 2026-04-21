-- TileRoom.lua

import "CoreLibs/graphics"
import "CoreLibs/timer"
import "CoreLibs/ui"
import "CoreLibs/animation"
import "CoreLibs/crank"
import "CoreLibs/object" -- für playdate.graphics.image.new()
import "PixelRoom"
import "PulpGameIO"


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

-- Datei-Verwaltung
local currentFileName = nil    -- Name des aktuell geöffneten Games (ohne Pfad)
local backRoom = nil           -- Raum, zu dem nach dem Speichern zurückgewechselt wird

-- Game State (v2): vollständiges Game-Objekt mit allen Rooms
local gameData = nil           -- v2-Game-Tabelle (rooms, tiles, frames)
local pulpState = nil          -- Vollstaendiges Pulp-Dokument + Zuordnungen
local currentRoomIndex = 1     -- 1-basierter Lua-Index in gameData.rooms

-- Show Grid: bestimmt, welches Tile als "leer" gilt
-- true  → Tile 1 (Grid) ist der Hintergrund, Löschen setzt auf 1
-- false → Tile 2 (Weiß) ist der Hintergrund, Löschen setzt auf 2
local showGrid = true

-- Matrix-Imagetable (2 Tiles, 8x8) laden (siehe 7.20.12 Image Table)
local origImagetable = gfx.imagetable.new("images/cellbg")
assert(origImagetable, "Imagetable konnte nicht geladen werden!")

-- hier wird die Tilemap geladen,
-- diese sollte eigentlich dann vom LoadRoom uebergeben werden.
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
-- Gibt den aktuellen Hintergrund-Tile-Index zurück (1=Grid, 2=Weiß).
local function getBackgroundTile()
    return showGrid and 1 or 2
end

local function toggleCurrentCell()
    local section, row, col = gridView:getSelection()
    if row and col then
        local current = tilemap:getTileAtPosition(col, row)
        if current == tilePickerIndex then
            -- Zelle löschen: auf aktuellen Hintergrund zurücksetzen
            tilemap:setTileAtPosition(col, row, getBackgroundTile())
        else
            -- Zelle mit dem aktuell gewählten Picker-Tile füllen
            tilemap:setTileAtPosition(col, row, tilePickerIndex)
        end
        needsRedraw = true
    end
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
    rebuildImagetableFromGameData()
    -- Ersten Room in Tilemap laden, damit kein stale State übrigbleibt
    if gameData and gameData.rooms and #gameData.rooms > 0 then
        currentRoomIndex = 1
        loadRoomIntoTilemap(1)
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

-- Speichert den aktuellen Room-State in gameData zurück und lädt einen anderen Room.
-- roomIdx: 1-basierter Lua-Index in gameData.rooms
function TileRoom:setRoom(roomIdx)
    -- Aktuellen Room-State sichern, bevor wir wechseln
    syncCurrentRoomToGameData()
    -- Neuen Room laden
    currentRoomIndex = roomIdx
    loadRoomIntoTilemap(roomIdx)
    tilePickerIndex = math.max(3, math.min(tilePickerIndex, cellImagetable:getLength()))
    needsRedraw = true
end

-- Erstellt einen neuen leeren Room im aktuellen Game.
-- Rückgabe: 1-basierter Lua-Index des neuen Rooms
function TileRoom:newRoom()
    if not gameData then
        -- Falls kein Game geladen: komplett neues Game erstellen
        -- createEmptyGameData erzeugt bereits einen Room (id=0), daher direkt diesen verwenden
        gameData = createEmptyGameData(currentFileName or "untitled")
        local normalizedDocument, normalizedState = PulpGameIO.buildSaveDocument(currentFileName or "untitled", gameData, nil)
        normalizedState.document = normalizedDocument
        pulpState = normalizedState
        rebuildImagetableFromGameData()
        currentRoomIndex = 1
        loadRoomIntoTilemap(1)
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
    loadRoomIntoTilemap(currentRoomIndex)
    tilePickerIndex = 3
    needsRedraw = true
    return currentRoomIndex
end

-- Setzt Tilemap und Imagetable auf den Ausgangszustand zurück (neues leeres Game).
-- Erstellt Game mit einem leeren Room und den 3 Basis-Tiles.
function TileRoom:newMap()
    gameData = createEmptyGameData(currentFileName or "untitled")
    local normalizedDocument, normalizedState = PulpGameIO.buildSaveDocument(currentFileName or "untitled", gameData, nil)
    normalizedState.document = normalizedDocument
    pulpState = normalizedState
    rebuildImagetableFromGameData()
    currentRoomIndex = 1
    loadRoomIntoTilemap(1)
    tilePickerIndex = 3
    needsRedraw = true
end

-- ── Internes Datenmodell ──────────────────────────────────────────────────────

-- Erstellt ein leeres v2-Game-Objekt mit 3 Basis-Tiles und einem leeren Room.
function createEmptyGameData(name)
    -- Basis-Frames aus Runtime-Images
    local baseTileImages = {
        origImagetable:getImage(1),
        origImagetable:getImage(2),
        blackTile
    }
    local frames = {}
    local baseNames = { "white", "grid", "black" }
    for i, img in ipairs(baseTileImages) do
        local data = encodeFrameData(img)
        frames[i] = { id = i - 1, data = data }
    end
    local tiles = {}
    for i = 1, 3 do
        tiles[i] = {
            id = i - 1,
            name = baseNames[i],
            type = 0,
            frames = { i - 1 }
        }
    end
    -- Ein leerer Room (alle Tiles = 0 = white)
    local emptyRoomTiles = {}
    for j = 1, GRID_COLS * GRID_ROWS do
        emptyRoomTiles[j] = 0
    end
    local rooms = {
        {
            id = 0,
            name = "Room 1",
            tiles = emptyRoomTiles
        }
    }
    return {
        version = 2,
        name = name,
        rooms = rooms,
        tiles = tiles,
        frames = frames
    }
end

-- Serialisiert ein Tile-Bild als flaches 64er-Pixel-Array (v2 Frame-Format).
-- Rückgabe: Array mit 64 Einträgen (0=weiß, 1=schwarz, 2=transparent)
function encodeFrameData(image)
    local w, h = image:getSize()
    local pixels = {}
    local n = 1
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local p = image:sample(x, y)
            if p == gfx.kColorBlack then
                pixels[n] = 1
            elseif p == gfx.kColorClear then
                pixels[n] = 2
            else
                pixels[n] = 0
            end
            n = n + 1
        end
    end
    return pixels
end

-- Rekonstruiert ein 8×8-Tile-Bild aus Frame-Daten (flaches 64er-Array).
local function decodeFrameData(frameData)
    if not frameData or type(frameData) ~= "table" then return nil end
    -- Unterstützt sowohl v2 (flaches Array) als auch v1 ({w, h, pixels})
    local pixels, w, h
    if frameData.pixels then
        -- v1-Format: {w=8, h=8, pixels={...}}
        w = tonumber(frameData.w) or 8
        h = tonumber(frameData.h) or 8
        pixels = frameData.pixels
    else
        -- v2-Format: flaches 64er-Array direkt als data
        w = 8
        h = 8
        pixels = frameData
    end
    if type(pixels) ~= "table" then return nil end

    local img = gfx.image.new(w, h, gfx.kColorClear)
    gfx.pushContext(img)
        local n = 1
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local p = pixels[n]
                if p == 1 then
                    gfx.setColor(gfx.kColorBlack)
                    gfx.drawPixel(x, y)
                elseif p == 0 then
                    gfx.setColor(gfx.kColorWhite)
                    gfx.drawPixel(x, y)
                end
                n = n + 1
            end
        end
    gfx.popContext()
    return img
end

-- Prüft, ob encode/decode für ein Tile verlustfrei ist.
local function tileRoundtripOk(image)
    local decoded = decodeFrameData(encodeFrameData(image))
    if not decoded then return false end
    return imageHash(image) == imageHash(decoded)
end

-- Rendert ein Preview-Bild aus der aktuellen Tilemap.
local function renderPreviewImage()
    local previewImg = gfx.image.new(GRID_COLS * CELL_SIZE, GRID_ROWS * CELL_SIZE, gfx.kColorWhite)
    gfx.pushContext(previewImg)
        tilemap:draw(0, 0)
    gfx.popContext()
    return previewImg
end

-- Rendert ein Preview für einen bestimmten Room (ohne die Tilemap zu verändern).
-- Temporär: setzt Tilemap-Daten, rendert, stellt dann wieder her.
local function renderRoomPreview(roomData)
    -- Room-Tiles von 0-basiert auf 1-basiert konvertieren
    local runtimeTiles = {}
    for i, tileId in ipairs(roomData.tiles) do
        runtimeTiles[i] = tileId + 1
    end
    -- Tilemap-State sichern
    local savedData, savedWidth = tilemap:getTiles()
    -- Temporär setzen
    tilemap:setTiles(runtimeTiles, GRID_COLS)
    local preview = renderPreviewImage()
    -- Wiederherstellen
    tilemap:setTiles(savedData, savedWidth)
    return preview
end

-- Baut die Runtime-Imagetable und den hashCache aus gameData.tiles/frames auf.
function rebuildImagetableFromGameData()
    if not gameData then return end
    local tileCount = #gameData.tiles
    local freshTable = gfx.imagetable.new(tileCount)
    hashCache = {}
    for i, tileDef in ipairs(gameData.tiles) do
        -- Jedes Tile hat genau einen Frame (für jetzt)
        local frameId = tileDef.frames[1] -- 0-basiert
        local frameObj = nil
        -- Frame-Objekt per ID finden
        for _, f in ipairs(gameData.frames) do
            if f.id == frameId then
                frameObj = f
                break
            end
        end
        if frameObj then
            local img = decodeFrameData(frameObj.data)
            if img then
                freshTable:setImage(i, img)
                hashCache[i] = imageHash(img)
            end
        end
    end
    cellImagetable = freshTable
    tilemap:setImageTable(cellImagetable)
end

-- Lädt einen Room (per 1-basiertem Lua-Index) aus gameData in die Tilemap.
function loadRoomIntoTilemap(roomIdx)
    if not gameData or not gameData.rooms[roomIdx] then return end
    local roomData = gameData.rooms[roomIdx]
    -- Room-Tiles: 0-basiert (Speicherformat) → 1-basiert (Runtime)
    local runtimeTiles = {}
    local countGrid = 0
    local countWhite = 0
    for i, tileId in ipairs(roomData.tiles) do
        local runtimeIdx = tileId + 1
        runtimeTiles[i] = runtimeIdx
        if runtimeIdx == 1 then
            countGrid = countGrid + 1
        elseif runtimeIdx == 2 then
            countWhite = countWhite + 1
        end
    end
    -- showGrid beim Laden aus den Raumdaten ableiten.
    -- Wenn eines der beiden Basis-Tiles dominiert, verwenden wir dieses als Hintergrundmodus.
    if countGrid > countWhite then
        showGrid = true
    elseif countWhite > countGrid then
        showGrid = false
    end
    tilemap:setTiles(runtimeTiles, GRID_COLS)
end

-- Synchronisiert den aktuellen Tilemap-State zurück in gameData.rooms[currentRoomIndex].
function syncCurrentRoomToGameData()
    if not gameData or not gameData.rooms[currentRoomIndex] then return end
    local data, _ = tilemap:getTiles()
    -- Runtime (1-basiert) → Speicher (0-basiert)
    local savedTiles = {}
    for i, runtimeIdx in ipairs(data) do
        savedTiles[i] = runtimeIdx - 1
    end
    gameData.rooms[currentRoomIndex].tiles = savedTiles
end

-- Entfernt unbenutzte Tiles und zieht die verbleibenden Indizes kompakt nach.
-- Basis-Tiles 1..3 bleiben immer erhalten.
-- Berücksichtigt alle Rooms des Games, nicht nur den aktuellen.
local function compactTileState()
    -- Zuerst: aktuellen Room-State in gameData synchronisieren
    syncCurrentRoomToGameData()

    local maxTile = cellImagetable:getLength()

    -- Alle in irgendeinem Room benutzten Tiles sammeln (1-basierte Runtime-IDs)
    local used = { [1] = true, [2] = true, [3] = true }
    for _, room in ipairs(gameData.rooms) do
        for _, tileId0 in ipairs(room.tiles) do
            -- 0-basiert → 1-basiert
            local runtimeIdx = tileId0 + 1
            if type(runtimeIdx) == "number" then
                used[runtimeIdx] = true
            end
        end
    end

    local oldToNew = {}
    local newToOld = {}
    local newCount = 0
    for oldIdx = 1, maxTile do
        if used[oldIdx] then
            local img = cellImagetable:getImage(oldIdx)
            if img or oldIdx <= 3 then
                newCount = newCount + 1
                oldToNew[oldIdx] = newCount
                newToOld[newCount] = oldIdx
            else
                print("Warnung: Benutztes Tile ohne Bild wird entfernt:", oldIdx)
            end
        end
    end

    -- Alle Rooms remappen (0-basiert)
    for _, room in ipairs(gameData.rooms) do
        for i, tileId0 in ipairs(room.tiles) do
            local runtimeOld = tileId0 + 1
            local runtimeNew = oldToNew[runtimeOld]
            if not runtimeNew then
                runtimeNew = 1
                print("Warnung: Undefinierter Tile-Index in Room auf 0 gesetzt:", tileId0)
            end
            room.tiles[i] = runtimeNew - 1  -- zurück auf 0-basiert
        end
    end

    -- Neue Imagetable aufbauen
    local newTable = gfx.imagetable.new(newCount)
    local newHashCache = {}
    for newIdx = 1, newCount do
        local oldIdx = newToOld[newIdx]
        local img = cellImagetable:getImage(oldIdx)
        if img then
            newTable:setImage(newIdx, img)
            newHashCache[newIdx] = imageHash(img)
        end
    end

    local removedCount = 0
    for oldIdx = 4, maxTile do
        if not oldToNew[oldIdx] then
            removedCount = removedCount + 1
        end
    end
    if removedCount > 0 then
        print("Info: Unbenutzte Tiles entfernt:", removedCount)
    end

    local remappedPickerIndex = oldToNew[tilePickerIndex] or 3
    remappedPickerIndex = math.max(3, math.min(remappedPickerIndex, newCount))

    return {
        imageTable = newTable,
        hashCache = newHashCache,
        maxTile = newCount,
        tilePickerIndex = remappedPickerIndex,
        oldToNew = oldToNew
    }
end

-- Speichert das aktuelle Game im v2-Format.
function TileRoom:saveToFile()
    if not currentFileName or not gameData then return end
    local name = currentFileName
    playdate.file.mkdir("saves")

    -- 1. Aktuellen Room-State in gameData synchronisieren
    syncCurrentRoomToGameData()

    -- 2. Tiles komprimieren (über alle Rooms)
    local compacted = compactTileState()
    cellImagetable = compacted.imageTable
    hashCache = compacted.hashCache
    tilemap:setImageTable(cellImagetable)
    tilePickerIndex = compacted.tilePickerIndex
    pulpState = PulpGameIO.remapTileMappings(pulpState, compacted.oldToNew)

    -- Aktuellen Room neu in Tilemap laden (Indizes wurden remapped)
    loadRoomIntoTilemap(currentRoomIndex)

    -- 3. v2-Tiles und Frames aus der komprimierten Imagetable aufbauen
    local v2Tiles = {}
    local v2Frames = {}
    local baseNames = { "white", "grid", "black" }
    for i = 1, compacted.maxTile do
        local img = cellImagetable:getImage(i)
        if img then
            local frameId = i - 1 -- 0-basiert
            local tileName
            if i <= 3 then
                tileName = baseNames[i]
            else
                tileName = "tile_" .. frameId
            end
            v2Tiles[i] = {
                id = frameId,
                name = tileName,
                type = 0,
                frames = { frameId }
            }
            v2Frames[i] = {
                id = frameId,
                data = encodeFrameData(img)
            }
            if not tileRoundtripOk(img) then
                print("Warnung: Rekonstruktionstest fehlgeschlagen fuer Tile:", i)
            end
        end
    end

    -- 4. gameData aktualisieren
    gameData.tiles = v2Tiles
    gameData.frames = v2Frames
    gameData.name = name

    -- 5. Vollstaendiges Pulp-Dokument erzeugen und speichern.
    -- Dabei bleiben bereits vorhandene, nicht vom Editor verwaltete Felder erhalten.
    local outputDocument, outputState = PulpGameIO.buildSaveDocument(
        name,
        gameData,
        pulpState,
        { currentRoomIndex = currentRoomIndex }
    )
    outputState.document = outputDocument
    pulpState = outputState
    gameData.version = outputDocument.version
    playdate.datastore.write(outputDocument, "saves/" .. name)

    -- 6. Preview-Bilder generieren
    -- Aktueller Room-Preview (Dateiname nutzt room.id, nicht den Lua-Index)
    local currentRoomId = gameData.rooms[currentRoomIndex].id
    local currentPreview = renderPreviewImage()
    playdate.datastore.writeImage(currentPreview, "saves/" .. name .. "_room" .. currentRoomId .. "_preview")

    -- Game-Preview = Preview des ersten Rooms
    if currentRoomIndex == 1 then
        playdate.datastore.writeImage(currentPreview, "saves/" .. name .. "_preview")
    else
        -- Ersten Room temporär rendern
        local firstRoomPreview = renderRoomPreview(gameData.rooms[1])
        playdate.datastore.writeImage(firstRoomPreview, "saves/" .. name .. "_preview")
    end

    needsRedraw = true
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

    rebuildImagetableFromGameData()

    -- Ersten Room laden
    currentRoomIndex = 1
    loadRoomIntoTilemap(1)

    tilePickerIndex = math.max(3, math.min(tilePickerIndex, cellImagetable:getLength()))
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
    -- Zoom-Trigger: D-Pad Up gehalten + Crank
    if upHeld then
        ticks += playdate.getCrankTicks(4)
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
    -- Systemmenü: alte Items entfernen, dann "Save + Back" hinzufügen (nur wenn Dateiname gesetzt)
    local menu = playdate.getSystemMenu()
    menu:removeAllMenuItems()
    if currentFileName then
        -- Beim Auslösen: speichern und zurück zum LoadRoom wechseln
        menu:addMenuItem("Save + Back", function()
            TileRoom:saveToFile()
            if backRoom and switchRoomFunction then
                switchRoomFunction(backRoom)
            end
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
    local index, newTable = findOrAppendImage(cellImagetable, tile, hashCache)
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
            data = encodeFrameData(tile)
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
    hashCache[tileIndex] = imageHash(tile)
    tilemap:setImageTable(cellImagetable)
    -- gameData synchron halten
    if gameData and tileIndex <= #gameData.tiles then
        local tileDef = gameData.tiles[tileIndex]
        local frameId = tileDef.frames[1]
        -- Frame-Daten aktualisieren
        for _, f in ipairs(gameData.frames) do
            if f.id == frameId then
                f.data = encodeFrameData(tile)
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
                hashCache[edit.existingIndex] = imageHash(edit.image)
                tilemap:setImageTable(cellImagetable)
                finalIndex = edit.existingIndex
                -- gameData Frame-Daten synchron halten
                if gameData and edit.existingIndex <= #gameData.tiles then
                    local tileDef = gameData.tiles[edit.existingIndex]
                    local frameId = tileDef.frames[1]
                    for _, f in ipairs(gameData.frames) do
                        if f.id == frameId then
                            f.data = encodeFrameData(edit.image)
                            break
                        end
                    end
                end
            else
                -- Neu: deduplizieren oder anhängen
                local newIdx, newTable = findOrAppendImage(cellImagetable, edit.image, hashCache)
                cellImagetable = newTable
                tilemap:setImageTable(cellImagetable)
                finalIndex = newIdx
                -- gameData synchron halten
                if gameData and newIdx > #gameData.tiles then
                    local frameId = newIdx - 1
                    gameData.frames[newIdx] = {
                        id   = frameId,
                        data = encodeFrameData(edit.image)
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
