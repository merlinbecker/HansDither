-- Migration.lua
-- v1→v2 Migrationslogik für Hans Dither Speicherformat.
-- Alle Migrationsfunktionen sind in dieser Datei isoliert.
-- Zum Entfernen: diese Datei löschen und alle Zeilen mit "-- MIGRATION:" in anderen Dateien entfernen.

Migration = {}

-- Prüft ob Daten im alten v1-Format vorliegen und migriert werden müssen.
function Migration.needsMigration(data)
    if not data then return false end
    return data.version == nil or data.version < 2
end

-- Prüft ob der Index im alten Format {names:[...]} vorliegt.
function Migration.needsIndexMigration(indexData)
    if not indexData then return false end
    return indexData.names ~= nil and indexData.games == nil
end

-- Konvertiert den alten Index {names:[...]} ins neue Format {games:[...]}.
function Migration.migrateIndex(oldIndex)
    if not oldIndex then return { games = {} } end
    return { games = oldIndex.names or {} }
end

-- Erzeugt Frame-Daten für die 3 Basis-Tiles (white, grid, black).
-- Die Pixel-Daten werden aus den Runtime-Images extrahiert.
-- baseTileImages: Array mit den 3 Basis-Tile-Images (1=white, 2=grid, 3=black)
local function createBaseFrames(baseTileImages)
    local frames = {}
    for i, img in ipairs(baseTileImages) do
        local w, h = img:getSize()
        local data = {}
        local n = 1
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local p = img:sample(x, y)
                if p == playdate.graphics.kColorBlack then
                    data[n] = 1
                elseif p == playdate.graphics.kColorClear then
                    data[n] = 2
                else
                    data[n] = 0
                end
                n = n + 1
            end
        end
        -- 0-basierte IDs: Tile 1 → Frame 0, Tile 2 → Frame 1, Tile 3 → Frame 2
        frames[i] = { id = i - 1, data = data }
    end
    return frames
end

-- Konvertiert v1-Daten ins v2-Format.
-- oldData: die gelesenen v1-Daten (mit data, width, customTileData, etc.)
-- gameName: Name des Games
-- baseTileImages: Array mit den 3 Basis-Tile-Images [white, grid, black]
-- Rückgabe: v2-Game-Tabelle
function Migration.migrateV1ToV2(oldData, gameName, baseTileImages)
    local v2 = {
        version = 2,
        name = gameName,
        rooms = {},
        tiles = {},
        frames = {}
    }

    -- 1. Frames aus Basis-Tiles erzeugen (0, 1, 2)
    v2.frames = createBaseFrames(baseTileImages)

    -- 2. Tiles für Basis-Tiles (0=white, 1=grid, 2=black)
    local baseNames = { "white", "grid", "black" }
    for i = 1, 3 do
        v2.tiles[i] = {
            id = i - 1,
            name = baseNames[i],
            type = 0,
            frames = { i - 1 } -- 0-basierte Frame-ID
        }
    end

    -- 3. Custom Tiles (v1 Index 4+ → v2 Index 3+)
    local customTileIndices = oldData.customTileIndices or {}
    local customTileData = oldData.customTileData or {}

    -- Falls keine customTileIndices vorhanden, aus customTileData-Keys ableiten
    if #customTileIndices == 0 then
        for k, _ in pairs(customTileData) do
            local idx = tonumber(k)
            if idx and idx >= 4 then
                table.insert(customTileIndices, idx)
            end
        end
        table.sort(customTileIndices)
    end

    -- Mapping: v1 Tile-Index (1-basiert) → v2 Tile-ID (0-basiert)
    -- Basis: v1[1]→v2[0], v1[2]→v2[1], v1[3]→v2[2]
    -- Custom: v1[4]→v2[3], v1[5]→v2[4], ...
    -- Da v1 Custom-Tiles Lücken haben können (z.B. 4,5,7), bauen wir ein kompaktes Mapping.
    local v1ToV2TileId = {}
    v1ToV2TileId[1] = 0
    v1ToV2TileId[2] = 1
    v1ToV2TileId[3] = 2

    local nextV2Id = 3 -- nächste freie v2-ID (0-basiert)
    for _, v1Idx in ipairs(customTileIndices) do
        local tileData = customTileData[tostring(v1Idx)] or customTileData[v1Idx]
        if tileData and tileData.pixels then
            -- Frame erzeugen
            local frameId = nextV2Id
            v2.frames[#v2.frames + 1] = {
                id = frameId,
                data = tileData.pixels
            }
            -- Tile erzeugen
            v2.tiles[#v2.tiles + 1] = {
                id = nextV2Id,
                name = "tile_" .. nextV2Id,
                type = 0,
                frames = { frameId }
            }
            v1ToV2TileId[v1Idx] = nextV2Id
            nextV2Id = nextV2Id + 1
        end
    end

    -- 4. Room aus v1 tilemap-data erzeugen
    local roomTiles = {}
    local v1Data = oldData.data or {}
    for i, v1TileIdx in ipairs(v1Data) do
        -- v1 ist 1-basiert, v2 ist 0-basiert
        local v2Id = v1ToV2TileId[v1TileIdx]
        if v2Id == nil then
            -- Unbekannter Tile-Index: auf 0 (white) fallen
            v2Id = 0
            print("Migration: Unbekannter v1 Tile-Index " .. tostring(v1TileIdx) .. " auf 0 gesetzt")
        end
        roomTiles[i] = v2Id
    end

    v2.rooms[1] = {
        id = 0,
        name = "Room 1",
        tiles = roomTiles
    }

    return v2
end

return Migration
