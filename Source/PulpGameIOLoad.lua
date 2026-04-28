PulpGameIOLoad = {}

local function extractWorkingStateFromDocument(document, gameName, progressCallback)
    local shared = PulpGameIOShared
    local tileEntries = shared.collectEntriesWithId(document.tiles)
    local frameEntriesById = shared.indexEntriesById(document.frames)
    local roomEntries = shared.collectEntriesWithId(document.rooms)
    local totalTiles = #tileEntries
    local totalRooms = #roomEntries

    local workingFrames = {}
    local workingTiles = {}
    local workingRooms = {}
    local tileIdByInternalIndex = {}
    local frameIdByInternalIndex = {}
    local roomMetadataById = {}
    local externalTileIdToInternalId = {}

    for internalIndex, tile in ipairs(tileEntries) do
        local externalFrameId = type(tile.frames) == "table" and tile.frames[1] or nil
        local externalFrame = frameEntriesById[externalFrameId]

        tileIdByInternalIndex[internalIndex] = tile.id
        frameIdByInternalIndex[internalIndex] = externalFrameId ~= nil and externalFrameId or tile.id
        externalTileIdToInternalId[tile.id] = internalIndex - 1

        workingTiles[internalIndex] = {
            id = internalIndex - 1,
            name = tile.name or ("tile_" .. (internalIndex - 1)),
            type = tile.type or 0,
            frames = { internalIndex - 1 }
        }
        workingFrames[internalIndex] = {
            id = internalIndex - 1,
            data = shared.deepCopy(externalFrame and externalFrame.data or {})
        }

        if progressCallback and (internalIndex == totalTiles or internalIndex == 1 or internalIndex % 8 == 0) then
            progressCallback("tiles", internalIndex, totalTiles, "tiles " .. internalIndex .. " / " .. totalTiles)
        end
    end

    for roomIndex, room in ipairs(roomEntries) do
        roomMetadataById[room.id] = shared.deepCopy(room)
        local mappedTiles = {}
        for tileIndex, externalTileId in ipairs(room.tiles or {}) do
            mappedTiles[tileIndex] = externalTileIdToInternalId[externalTileId] or 0
        end
        workingRooms[roomIndex] = {
            id = room.id,
            name = room.name or ("Room " .. (room.id + 1)),
            tiles = mappedTiles
        }
        if progressCallback then
            progressCallback("rooms", roomIndex, totalRooms, "Rooms " .. roomIndex .. " / " .. totalRooms)
        end
    end

    return {
        version = 1,
        name = gameName or document.name,
        rooms = workingRooms,
        tiles = workingTiles,
        frames = workingFrames
    }, {
        document = shared.deepCopy(document),
        tileIdByInternalIndex = tileIdByInternalIndex,
        frameIdByInternalIndex = frameIdByInternalIndex,
        roomMetadataById = roomMetadataById
    }
end

function PulpGameIOLoad.remapTileMappings(pulpState, oldToNew)
    if not pulpState or type(oldToNew) ~= "table" then
        return pulpState
    end
    local remappedTileIds = {}
    local remappedFrameIds = {}
    for oldIndex, newIndex in pairs(oldToNew) do
        remappedTileIds[newIndex] = pulpState.tileIdByInternalIndex and pulpState.tileIdByInternalIndex[oldIndex] or nil
        remappedFrameIds[newIndex] = pulpState.frameIdByInternalIndex and pulpState.frameIdByInternalIndex[oldIndex] or nil
    end
    pulpState.tileIdByInternalIndex = remappedTileIds
    pulpState.frameIdByInternalIndex = remappedFrameIds
    return pulpState
end

function PulpGameIOLoad.prepareLoadedGame(gameName, savedData, progressCallback)
    local shared = PulpGameIOShared
    if not savedData then
        return nil, nil, false
    end
    if not shared.documentLooksStructured(savedData) then
        print("Warnung: Nicht unterstuetztes Legacy-Save-Format fuer " .. tostring(gameName))
        return nil, nil, false
    end
    if progressCallback then
        progressCallback("prepare", 0, 1, "Dokument analysieren")
    end

    local workingGameData, pulpState = extractWorkingStateFromDocument(savedData, gameName, progressCallback)
    if progressCallback then
        progressCallback("normalize", 0, 1, "Speicherstand normalisieren")
    end

    local normalizedDocument, normalizedState = PulpGameIOSave.buildSaveDocument(gameName, workingGameData, pulpState, nil, progressCallback)
    normalizedState.document = normalizedDocument
    if progressCallback then
        progressCallback("done", 1, 1, "Laden abgeschlossen")
    end
    return workingGameData, normalizedState, false
end

return PulpGameIOLoad