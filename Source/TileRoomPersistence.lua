TileRoomPersistence = {}
TileRoomPersistence.__index = TileRoomPersistence

function TileRoomPersistence.new(config)
    return setmetatable({ config = config }, TileRoomPersistence)
end

function TileRoomPersistence:imageHash(image)
    local w, h = image:getSize()
    local hash = -2128831035
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local pixel = image:sample(x, y) or 0
            hash = hash ~ pixel
            hash = hash * 16777619
        end
    end
    return string.format("%08x", hash)
end

function TileRoomPersistence:findOrAppendImage(imagetable, image, hashCache)
    local imgHash = self:imageHash(image)
    for idx, cachedHash in ipairs(hashCache) do
        if cachedHash == imgHash then
            return idx, imagetable
        end
    end

    local newTable = playdate.graphics.imagetable.new(imagetable:getLength() + 1)
    for i = 1, imagetable:getLength() do
        newTable:setImage(i, imagetable:getImage(i))
    end
    newTable:setImage(imagetable:getLength() + 1, image)
    hashCache[imagetable:getLength() + 1] = imgHash
    return imagetable:getLength() + 1, newTable
end

function TileRoomPersistence:encodeFrameData(image)
    local gfx = self.config.gfx
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

function TileRoomPersistence:decodeFrameData(frameData)
    if not frameData or type(frameData) ~= "table" then return nil end

    local pixels, w, h
    if frameData.pixels then
        w = tonumber(frameData.w) or 8
        h = tonumber(frameData.h) or 8
        pixels = frameData.pixels
    else
        w = 8
        h = 8
        pixels = frameData
    end
    if type(pixels) ~= "table" then return nil end

    local gfx = self.config.gfx
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

function TileRoomPersistence:tileRoundtripOk(image)
    local decoded = self:decodeFrameData(self:encodeFrameData(image))
    if not decoded then return false end
    return self:imageHash(image) == self:imageHash(decoded)
end

function TileRoomPersistence:createEmptyGameData(name)
    local cfg = self.config
    local baseTileImages = {
        cfg.origImagetable:getImage(1),
        cfg.origImagetable:getImage(2),
        cfg.blackTile
    }
    local frames = {}
    local baseNames = { "white", "grid", "black" }
    for i, img in ipairs(baseTileImages) do
        frames[i] = { id = i - 1, data = self:encodeFrameData(img) }
    end
    local tiles = {}
    for i = 1, 3 do
        tiles[i] = { id = i - 1, name = baseNames[i], type = 0, frames = { i - 1 } }
    end
    local emptyRoomTiles = {}
    for j = 1, cfg.gridCols * cfg.gridRows do
        emptyRoomTiles[j] = 0
    end
    return {
        version = 2,
        name = name,
        rooms = { { id = 0, name = "Room 1", tiles = emptyRoomTiles } },
        tiles = tiles,
        frames = frames
    }
end

function TileRoomPersistence:renderPreviewImage()
    local cfg = self.config
    local previewImg = cfg.gfx.image.new(cfg.gridCols * cfg.cellSize, cfg.gridRows * cfg.cellSize, cfg.gfx.kColorWhite)
    cfg.gfx.pushContext(previewImg)
        cfg.tilemap:draw(0, 0)
    cfg.gfx.popContext()
    return previewImg
end

function TileRoomPersistence:renderRoomPreview(roomData)
    local runtimeTiles = {}
    for i, tileId in ipairs(roomData.tiles) do
        runtimeTiles[i] = tileId + 1
    end
    local savedData, savedWidth = self.config.tilemap:getTiles()
    self.config.tilemap:setTiles(runtimeTiles, self.config.gridCols)
    local preview = self:renderPreviewImage()
    self.config.tilemap:setTiles(savedData, savedWidth)
    return preview
end

function TileRoomPersistence:rebuildImagetableFromGameData()
    local gameData = self.config.getGameData()
    if not gameData then return end

    local freshTable = self.config.gfx.imagetable.new(#gameData.tiles)
    local hashCache = {}
    for i, tileDef in ipairs(gameData.tiles) do
        local frameId = tileDef.frames[1]
        local frameObj = nil
        for _, frame in ipairs(gameData.frames) do
            if frame.id == frameId then
                frameObj = frame
                break
            end
        end
        if frameObj then
            local img = self:decodeFrameData(frameObj.data)
            if img then
                freshTable:setImage(i, img)
                hashCache[i] = self:imageHash(img)
            end
        end
    end
    self.config.setHashCache(hashCache)
    self.config.setCellImagetable(freshTable)
    self.config.tilemap:setImageTable(freshTable)
end

function TileRoomPersistence:loadRoomIntoTilemap(roomIdx)
    local gameData = self.config.getGameData()
    if not gameData or not gameData.rooms[roomIdx] then return end

    local roomData = gameData.rooms[roomIdx]
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
    if countGrid > countWhite then
        self.config.setShowGrid(true)
    elseif countWhite > countGrid then
        self.config.setShowGrid(false)
    end
    self.config.tilemap:setTiles(runtimeTiles, self.config.gridCols)
end

function TileRoomPersistence:syncCurrentRoomToGameData()
    local gameData = self.config.getGameData()
    local currentRoomIndex = self.config.getCurrentRoomIndex()
    if not gameData or not gameData.rooms[currentRoomIndex] then return end

    local data = self.config.tilemap:getTiles()
    local savedTiles = {}
    for i, runtimeIdx in ipairs(data) do
        savedTiles[i] = runtimeIdx - 1
    end
    gameData.rooms[currentRoomIndex].tiles = savedTiles
end

function TileRoomPersistence:compactTileState(progressCallback)
    self:syncCurrentRoomToGameData()

    local gameData = self.config.getGameData()
    local cellImagetable = self.config.getCellImagetable()
    local maxTile = cellImagetable:getLength()
    local totalRooms = #(gameData.rooms or {})
    local used = { [1] = true, [2] = true, [3] = true }

    for roomIndex, room in ipairs(gameData.rooms) do
        for _, tileId0 in ipairs(room.tiles) do
            local runtimeIdx = tileId0 + 1
            if type(runtimeIdx) == "number" then
                used[runtimeIdx] = true
            end
        end
        if progressCallback then
            progressCallback(roomIndex, totalRooms, "Tiles pruefen " .. roomIndex .. " von " .. totalRooms)
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

    for roomIndex, room in ipairs(gameData.rooms) do
        for i, tileId0 in ipairs(room.tiles) do
            local runtimeOld = tileId0 + 1
            local runtimeNew = oldToNew[runtimeOld]
            if not runtimeNew then
                runtimeNew = 1
                print("Warnung: Undefinierter Tile-Index in Room auf 0 gesetzt:", tileId0)
            end
            room.tiles[i] = runtimeNew - 1
        end
        if progressCallback then
            progressCallback(roomIndex, totalRooms, "Rooms remappen " .. roomIndex .. " von " .. totalRooms)
        end
    end

    local newTable = self.config.gfx.imagetable.new(newCount)
    local newHashCache = {}
    for newIdx = 1, newCount do
        local oldIdx = newToOld[newIdx]
        local img = cellImagetable:getImage(oldIdx)
        if img then
            newTable:setImage(newIdx, img)
            newHashCache[newIdx] = self:imageHash(img)
        end
        if progressCallback and (newIdx == newCount or newIdx == 1 or newIdx % 8 == 0) then
            progressCallback(newIdx, newCount, "Imagetable bauen " .. newIdx .. " von " .. newCount)
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

    local remappedPickerIndex = oldToNew[self.config.getTilePickerIndex()] or 3
    remappedPickerIndex = math.max(3, math.min(remappedPickerIndex, newCount))

    return {
        imageTable = newTable,
        hashCache = newHashCache,
        maxTile = newCount,
        tilePickerIndex = remappedPickerIndex,
        oldToNew = oldToNew
    }
end

return TileRoomPersistence