PulpGameIOSave = {}

function PulpGameIOSave.buildSaveDocument(gameName, gameData, pulpState, options, progressCallback)
    local shared = PulpGameIOShared
    local existingDocument = pulpState and pulpState.document or nil
    local baseDocument = shared.buildBaseDocument(gameName, existingDocument)
    local totalTiles = #(gameData.tiles or {})
    local totalRooms = #(gameData.rooms or {})

    local existingTilesById = shared.indexEntriesById(baseDocument.tiles)
    local existingFramesById = shared.indexEntriesById(baseDocument.frames)
    local roomMetadataById = shared.deepCopy(pulpState and pulpState.roomMetadataById or {})
    local tileIdByInternalIndex = shared.deepCopy(pulpState and pulpState.tileIdByInternalIndex or {})
    local frameIdByInternalIndex = shared.deepCopy(pulpState and pulpState.frameIdByInternalIndex or {})

    local usedTileIds = {}
    local usedFrameIds = {}
    local mappedExternalTileIds = {}
    local outputTiles = {}
    local outputFrames = {}
    local outputRooms = {}
    local maxTileId = -1
    local maxFrameId = -1
    local maxRoomId = -1

    for internalIndex, tileData in ipairs(gameData.tiles or {}) do
        local externalTileId = tileIdByInternalIndex[internalIndex]
        if externalTileId == nil or usedTileIds[externalTileId] then
            externalTileId = shared.allocateNextFreeId(usedTileIds)
        end
        usedTileIds[externalTileId] = true
        tileIdByInternalIndex[internalIndex] = externalTileId
        mappedExternalTileIds[internalIndex] = externalTileId
        if externalTileId > maxTileId then maxTileId = externalTileId end

        local externalFrameId = frameIdByInternalIndex[internalIndex]
        if externalFrameId == nil or usedFrameIds[externalFrameId] then
            externalFrameId = shared.allocateNextFreeId(usedFrameIds)
        end
        usedFrameIds[externalFrameId] = true
        frameIdByInternalIndex[internalIndex] = externalFrameId
        if externalFrameId > maxFrameId then maxFrameId = externalFrameId end

        outputTiles[externalTileId + 1] = shared.buildTileDocument(tileData, existingTilesById[externalTileId], externalTileId, externalFrameId)
        outputFrames[externalFrameId + 1] = shared.buildFrameDocument(gameData.frames[internalIndex] or {}, existingFramesById[externalFrameId], externalFrameId)

        if progressCallback and (internalIndex == totalTiles or internalIndex == 1 or internalIndex % 8 == 0) then
            progressCallback("tiles", internalIndex, totalTiles, "Dokument: Tile " .. internalIndex .. " von " .. totalTiles)
        end
    end

    if maxTileId >= 0 then
        local sparseTiles = shared.makeSparseIdArray(maxTileId)
        for _, tile in pairs(outputTiles) do
            if type(tile) == "table" and tile.id ~= nil then
                sparseTiles[tile.id + 1] = tile
            end
        end
        baseDocument.tiles = sparseTiles
    else
        baseDocument.tiles = {}
    end
    if progressCallback then
        progressCallback("sparse-tiles", maxTileId >= 0 and maxTileId + 1 or 0, maxTileId >= 0 and maxTileId + 1 or 0, "Dokument: Tile-Liste finalisieren")
    end

    if maxFrameId >= 0 then
        local sparseFrames = shared.makeSparseIdArray(maxFrameId)
        for _, frame in pairs(outputFrames) do
            if type(frame) == "table" and frame.id ~= nil then
                sparseFrames[frame.id + 1] = frame
            end
        end
        baseDocument.frames = sparseFrames
    else
        baseDocument.frames = {}
    end
    if progressCallback then
        progressCallback("sparse-frames", maxFrameId >= 0 and maxFrameId + 1 or 0, maxFrameId >= 0 and maxFrameId + 1 or 0, "Dokument: Frame-Liste finalisieren")
    end

    for roomIndex, roomData in ipairs(gameData.rooms or {}) do
        local roomDocument = shared.buildRoomDocument(roomData, roomMetadataById[roomData.id], mappedExternalTileIds)
        outputRooms[roomData.id + 1] = roomDocument
        roomMetadataById[roomData.id] = shared.deepCopy(roomDocument)
        if roomData.id > maxRoomId then maxRoomId = roomData.id end
        if progressCallback then
            progressCallback("rooms", roomIndex, totalRooms, "Dokument: Room " .. roomIndex .. " von " .. totalRooms)
        end
    end

    if maxRoomId >= 0 then
        local sparseRooms = shared.makeSparseIdArray(maxRoomId)
        for _, room in pairs(outputRooms) do
            if type(room) == "table" and room.id ~= nil then
                sparseRooms[room.id + 1] = room
            end
        end
        baseDocument.rooms = sparseRooms
    else
        baseDocument.rooms = {}
    end
    if progressCallback then
        progressCallback("finalize", 1, 1, "Dokument finalisieren")
    end

    shared.updateEditorAndPlayerState(baseDocument, options)
    shared.incrementBuildNumber(baseDocument)

    return baseDocument, {
        document = shared.deepCopy(baseDocument),
        tileIdByInternalIndex = tileIdByInternalIndex,
        frameIdByInternalIndex = frameIdByInternalIndex,
        roomMetadataById = roomMetadataById
    }
end

return PulpGameIOSave