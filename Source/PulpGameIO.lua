-- PulpGameIO.lua
--
-- Dieses Modul kapselt die Umwandlung zwischen zwei Datenformen:
-- 1. einem kompakten, internen Arbeitsformat fuer den Editor
-- 2. einem vollstaendigen, Pulp-kompatiblen Dokument fuer das Speichern
--
-- Der Editor arbeitet weiterhin mit kompakten, lueckenlosen Tile-/Frame-Indizes.
-- Beim Laden werden Pulp-Dokumente auf dieses Arbeitsformat normalisiert.
-- Beim Speichern wird aus dem Arbeitsformat wieder ein kompatibles Pulp-Dokument
-- aufgebaut, wobei vorhandene Attribute aus einem bereits existierenden Dokument
-- so weit wie moeglich erhalten bleiben.

import "Migration"

PulpGameIO = {}

-- Das SDK stellt JSON je nach Kontext als globales `json` bereit.
-- `playdate.json` ist im Runtime-Kontext hier nicht gesetzt, daher zuerst
-- das globale Objekt verwenden und nur als Fallback auf playdate.json gehen.
local json = (_G and rawget(_G, "json")) or (playdate and rawget(playdate, "json"))

-- Die Template-Datei liegt im Source-Verzeichnis als JSON und wird vom Compiler
-- als unbekannte Daten-Datei in das .pdx uebernommen. So ist sie zur Laufzeit
-- auch ohne Zugriff auf Repo-Dateien verfuegbar.
local TEMPLATE_PATH = "data/HansDitherTemplate.json"

local function deepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy
    for key, nestedValue in pairs(value) do
        copy[deepCopy(key, seen)] = deepCopy(nestedValue, seen)
    end
    return copy
end

local function isArrayLikeTable(value)
    if type(value) ~= "table" then
        return false
    end

    local count = 0
    for key, _ in pairs(value) do
        if type(key) ~= "number" then
            return false
        end
        count = count + 1
    end
    return count == #value
end

local function mergeMissingFields(target, defaults, excludedKeys)
    for key, defaultValue in pairs(defaults) do
        if not (excludedKeys and excludedKeys[key]) then
            local currentValue = target[key]
            if currentValue == nil then
                target[key] = deepCopy(defaultValue)
            elseif type(currentValue) == "table" and type(defaultValue) == "table" then
                if not isArrayLikeTable(currentValue) and not isArrayLikeTable(defaultValue) then
                    mergeMissingFields(currentValue, defaultValue)
                end
            end
        end
    end
end

local cachedTemplate = nil

local function stripUtf8Bom(content)
    if type(content) == "string" and string.byte(content, 1) == 239 and string.byte(content, 2) == 187 and string.byte(content, 3) == 191 then
        return string.sub(content, 4)
    end
    return content
end

local function readJsonFile(path)
    if not json or type(json.decode) ~= "function" then
        error("JSON-Decoder ist nicht verfuegbar; Template kann nicht geladen werden.")
    end

    local file, err = playdate.file.open(path, playdate.file.kFileRead)
    if not file then
        error("Konnte Template-Datei nicht oeffnen: " .. path .. " " .. tostring(err))
    end

    local lines = {}
    while true do
        local line = file:readline()
        if line == nil then
            break
        end
        lines[#lines + 1] = line
    end
    file:close()

    local content = stripUtf8Bom(table.concat(lines, "\n"))
    if content == "" then
        error("Template-Datei ist leer: " .. path)
    end

    local decoded = json.decode(content)
    if type(decoded) ~= "table" then
        error("Template-Datei enthaelt kein gueltiges JSON-Objekt: " .. path)
    end
    return decoded
end

local function getTemplate(gameName)
    if cachedTemplate == nil then
        cachedTemplate = readJsonFile(TEMPLATE_PATH)
    end
    local templateCopy = deepCopy(cachedTemplate)
    templateCopy.name = gameName or templateCopy.name
    return templateCopy
end

local function collectEntriesWithId(list)
    local entries = {}
    if type(list) ~= "table" then
        return entries
    end

    for _, value in pairs(list) do
        if type(value) == "table" and value.id ~= nil then
            entries[#entries + 1] = value
        end
    end

    table.sort(entries, function(a, b)
        return (a.id or 0) < (b.id or 0)
    end)
    return entries
end

local function indexEntriesById(list)
    local indexed = {}
    for _, value in ipairs(collectEntriesWithId(list)) do
        indexed[value.id] = value
    end
    return indexed
end

local function allocateNextFreeId(usedIds)
    local nextId = 0
    while usedIds[nextId] do
        nextId = nextId + 1
    end
    return nextId
end

local function makeSparseIdArray(maxId)
    local result = {}
    for i = 1, maxId + 1 do
        result[i] = false
    end
    return result
end

local function ensureArrayField(target, fieldName)
    if type(target[fieldName]) ~= "table" then
        target[fieldName] = {}
    end
end

local function ensureBlockList(scriptData)
    ensureArrayField(scriptData, "__blocks")
    if scriptData.__blocks[1] == nil then
        scriptData.__blocks[1] = {}
    end
end

local function appendUnique(list, value)
    if type(list) ~= "table" or type(value) ~= "string" or value == "" then
        return
    end

    for _, existingValue in ipairs(list) do
        if existingValue == value then
            return
        end
    end
    list[#list + 1] = value
end

local function ensureEventHandler(scriptData, eventName)
    ensureBlockList(scriptData)

    local handler = scriptData[eventName]
    if type(handler) ~= "table" or handler[1] ~= "block" or type(handler[2]) ~= "number" then
        scriptData[eventName] = { "block", 0 }
    end

    appendUnique(scriptData.__srcOrder, eventName)
end

local function mergeScriptValue(target, defaults)
    for key, defaultValue in pairs(defaults) do
        local currentValue = target[key]
        if currentValue == nil then
            target[key] = deepCopy(defaultValue)
        elseif type(currentValue) == "table" and type(defaultValue) == "table" then
            if isArrayLikeTable(currentValue) and isArrayLikeTable(defaultValue) then
                if #currentValue == 0 and #defaultValue > 0 then
                    target[key] = deepCopy(defaultValue)
                end
            else
                mergeScriptValue(currentValue, defaultValue)
            end
        end
    end
end

local function buildScriptKey(scriptEntry)
    if type(scriptEntry) ~= "table" then
        return nil
    end
    return tostring(scriptEntry.type) .. ":" .. tostring(scriptEntry.id)
end

local function getPrimaryTemplateScript(template)
    if type(template) ~= "table" or type(template.scripts) ~= "table" then
        return nil
    end

    for _, scriptEntry in ipairs(template.scripts) do
        if type(scriptEntry) == "table" and scriptEntry.id == 0 and scriptEntry.type == 0 then
            return deepCopy(scriptEntry)
        end
    end

    return nil
end

local function keepOnlyPrimaryScript(document, template)
    local primaryScript = getPrimaryTemplateScript(template)
    if primaryScript ~= nil then
        document.scripts = { primaryScript }
    else
        document.scripts = {}
    end

    document.script = 0
end

local function keepTemplateAudioDefinitions(document, template)
    document.song = template.song or -1
    document.songs = deepCopy(template.songs or {})
    document.sounds = deepCopy(template.sounds or {})
end

local function mergeScriptsFromTemplate(targetScripts, defaultScripts)
    if type(targetScripts) ~= "table" or type(defaultScripts) ~= "table" then
        return
    end

    local targetByKey = {}
    for _, scriptEntry in pairs(targetScripts) do
        local key = buildScriptKey(scriptEntry)
        if key ~= nil then
            targetByKey[key] = scriptEntry
        end
    end

    for index, defaultScript in pairs(defaultScripts) do
        if type(defaultScript) == "table" then
            local key = buildScriptKey(defaultScript)
            local targetScript = key and targetByKey[key] or nil
            if targetScript == nil and targetScripts[index] == nil then
                targetScripts[index] = deepCopy(defaultScript)
            elseif targetScript ~= nil then
                mergeScriptValue(targetScript, defaultScript)
            end
        elseif targetScripts[index] == nil then
            targetScripts[index] = defaultScript
        end
    end
end

local function normalizeScriptData(scriptEntry)
    if type(scriptEntry) ~= "table" then
        return
    end

    if type(scriptEntry.data) ~= "table" then
        scriptEntry.data = {}
    end

    local scriptData = scriptEntry.data
    ensureArrayField(scriptData, "__blocks")
    ensureArrayField(scriptData, "__comments")
    ensureArrayField(scriptData, "__srcOrder")

    if scriptEntry.type == 0 then
        ensureEventHandler(scriptData, "load")
        ensureEventHandler(scriptData, "change")
        return
    end

    if scriptEntry.type == 1 then
        if scriptData.enter ~= nil or #scriptData.__srcOrder > 0 or #scriptData.__blocks > 0 then
            ensureEventHandler(scriptData, "enter")
        end
        return
    end

    if scriptEntry.type == 2 then
        local knownEvents = { "update", "crank", "draw", "cancel", "confirm", "paint", "erase" }
        for _, eventName in ipairs(knownEvents) do
            ensureEventHandler(scriptData, eventName)
        end
    end
end

local function normalizeScripts(document)
    if type(document.scripts) ~= "table" then
        document.scripts = {}
    end

    for _, scriptEntry in pairs(document.scripts) do
        normalizeScriptData(scriptEntry)
    end
end

local function documentLooksStructured(data)
    return type(data) == "table"
        and type(data.rooms) == "table"
        and type(data.tiles) == "table"
        and type(data.frames) == "table"
end

local function buildBaseDocument(gameName, existingDocument)
    local document = existingDocument and deepCopy(existingDocument) or getTemplate(gameName)
    local template = getTemplate(gameName)

    mergeMissingFields(document, template, {
        rooms = true,
        tiles = true,
        frames = true
    })

    keepOnlyPrimaryScript(document, template)
    keepTemplateAudioDefinitions(document, template)

    document.name = gameName or document.name or template.name
    document.version = template.version or 1
    document.rooms = document.rooms or {}
    document.tiles = document.tiles or {}
    document.frames = document.frames or {}
    normalizeScripts(document)
    return document
end

local function buildRoomDocument(roomData, existingRoom, externalTileIds)
    local roomDocument = existingRoom and deepCopy(existingRoom) or {
        id = roomData.id,
        name = roomData.name or ("Room " .. (roomData.id + 1)),
        song = -1,
        exits = {},
        tiles = {},
        script = 0
    }

    roomDocument.id = roomData.id
    roomDocument.name = roomData.name or roomDocument.name
    roomDocument.script = 0

    local mappedTiles = {}
    for index, internalTileId in ipairs(roomData.tiles or {}) do
        local internalIndex = internalTileId + 1
        mappedTiles[index] = externalTileIds[internalIndex] or 0
    end
    roomDocument.tiles = mappedTiles

    if roomDocument.song == nil then roomDocument.song = -1 end
    if type(roomDocument.exits) ~= "table" then roomDocument.exits = {} end
    return roomDocument
end

local function buildTileDocument(tileData, existingTile, externalTileId, externalFrameId)
    local tileDocument = existingTile and deepCopy(existingTile) or {
        id = externalTileId,
        fps = 1,
        name = tileData.name or ("tile_" .. externalTileId),
        type = tileData.type or 0,
        btype = -1,
        solid = false,
        frames = { externalFrameId }
    }

    tileDocument.id = externalTileId
    tileDocument.name = tileData.name or tileDocument.name or ("tile_" .. externalTileId)
    tileDocument.frames = { externalFrameId }
    tileDocument.script = nil
    if tileDocument.fps == nil then tileDocument.fps = 1 end
    if tileDocument.type == nil then tileDocument.type = tileData.type or 0 end
    if tileDocument.btype == nil then tileDocument.btype = -1 end
    if tileDocument.solid == nil then tileDocument.solid = false end
    return tileDocument
end

local function buildFrameDocument(frameData, existingFrame, externalFrameId)
    local frameDocument = existingFrame and deepCopy(existingFrame) or {
        id = externalFrameId,
        data = deepCopy(frameData.data or {})
    }
    frameDocument.id = externalFrameId
    frameDocument.data = deepCopy(frameData.data or {})
    return frameDocument
end

local function roomIdExists(rooms, roomId)
    for _, room in ipairs(collectEntriesWithId(rooms)) do
        if room.id == roomId then
            return true
        end
    end
    return false
end

local function updateEditorAndPlayerState(document, options)
    if type(document.player) ~= "table" then
        document.player = {}
    end
    if type(document.editor) ~= "table" then
        document.editor = {}
    end

    local roomEntries = collectEntriesWithId(document.rooms)
    local tileEntries = collectEntriesWithId(document.tiles)
    local frameEntries = collectEntriesWithId(document.frames)
    local songEntries = collectEntriesWithId(document.songs)
    local soundEntries = collectEntriesWithId(document.sounds)

    if #roomEntries > 0 then
        local desiredRoomId = nil
        if options and options.currentRoomIndex and roomEntries[options.currentRoomIndex] then
            desiredRoomId = roomEntries[options.currentRoomIndex].id
        elseif roomIdExists(document.rooms, document.player.room) then
            desiredRoomId = document.player.room
        else
            desiredRoomId = roomEntries[1].id
        end

        document.player.room = desiredRoomId
        document.editor.activeRoomId = desiredRoomId
    end

    if #tileEntries > 0 then
        local tileId = document.editor.activeTileId
        local validTileId = false
        for _, tile in ipairs(tileEntries) do
            if tile.id == tileId then
                validTileId = true
                break
            end
        end
        if not validTileId then
            document.editor.activeTileId = tileEntries[1].id
        end
    end

    if #frameEntries > 0 then
        local frameId = document.editor.activeFrameId
        local validFrameId = false
        for _, frame in ipairs(frameEntries) do
            if frame.id == frameId then
                validFrameId = true
                break
            end
        end
        if not validFrameId then
            document.editor.activeFrameId = frameEntries[1].id
        end
    end

    if #songEntries > 0 then
        local songId = document.editor.activeSongId
        local validSongId = false
        for _, song in ipairs(songEntries) do
            if song.id == songId then
                validSongId = true
                break
            end
        end
        if not validSongId then
            document.editor.activeSongId = songEntries[1].id
        end
    end

    if #soundEntries > 0 then
        local soundId = document.editor.activeSoundId
        local validSoundId = false
        for _, sound in ipairs(soundEntries) do
            if sound.id == soundId then
                validSoundId = true
                break
            end
        end
        if not validSoundId then
            document.editor.activeSoundId = soundEntries[1].id
        end
    end

    ensureArrayField(document.editor, "sortedTiles")
    local sortedFrameIds = {}
    for _, tile in ipairs(tileEntries) do
        local frameId = nil
        if type(tile.frames) == "table" then
            frameId = tile.frames[1]
        end
        if type(frameId) == "number" then
            sortedFrameIds[#sortedFrameIds + 1] = frameId
        end
    end
    document.editor.sortedTiles[5] = sortedFrameIds
end

local function incrementBuildNumber(document)
    local currentBuildNumber = tonumber(document.buildNumber)
    if currentBuildNumber == nil then
        currentBuildNumber = 0
    end
    document.buildNumber = tostring(currentBuildNumber + 1)
end

local function extractWorkingStateFromDocument(document, gameName)
    local tileEntries = collectEntriesWithId(document.tiles)
    local frameEntriesById = indexEntriesById(document.frames)
    local roomEntries = collectEntriesWithId(document.rooms)

    local workingFrames = {}
    local workingTiles = {}
    local workingRooms = {}
    local tileIdByInternalIndex = {}
    local frameIdByInternalIndex = {}
    local roomMetadataById = {}
    local externalTileIdToInternalId = {}

    for internalIndex, tile in ipairs(tileEntries) do
        local externalFrameId = nil
        if type(tile.frames) == "table" then
            externalFrameId = tile.frames[1]
        end
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
            data = deepCopy(externalFrame and externalFrame.data or {})
        }
    end

    for roomIndex, room in ipairs(roomEntries) do
        roomMetadataById[room.id] = deepCopy(room)

        local mappedTiles = {}
        for tileIndex, externalTileId in ipairs(room.tiles or {}) do
            mappedTiles[tileIndex] = externalTileIdToInternalId[externalTileId] or 0
        end

        workingRooms[roomIndex] = {
            id = room.id,
            name = room.name or ("Room " .. (room.id + 1)),
            tiles = mappedTiles
        }
    end

    return {
        version = 1,
        name = gameName or document.name,
        rooms = workingRooms,
        tiles = workingTiles,
        frames = workingFrames
    }, {
        document = deepCopy(document),
        tileIdByInternalIndex = tileIdByInternalIndex,
        frameIdByInternalIndex = frameIdByInternalIndex,
        roomMetadataById = roomMetadataById
    }
end

function PulpGameIO.remapTileMappings(pulpState, oldToNew)
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

function PulpGameIO.buildSaveDocument(gameName, gameData, pulpState, options)
    local existingDocument = pulpState and pulpState.document or nil
    local baseDocument = buildBaseDocument(gameName, existingDocument)

    local existingTilesById = indexEntriesById(baseDocument.tiles)
    local existingFramesById = indexEntriesById(baseDocument.frames)
    local roomMetadataById = deepCopy(pulpState and pulpState.roomMetadataById or {})
    local tileIdByInternalIndex = deepCopy(pulpState and pulpState.tileIdByInternalIndex or {})
    local frameIdByInternalIndex = deepCopy(pulpState and pulpState.frameIdByInternalIndex or {})

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
            externalTileId = allocateNextFreeId(usedTileIds)
        end
        usedTileIds[externalTileId] = true
        tileIdByInternalIndex[internalIndex] = externalTileId
        mappedExternalTileIds[internalIndex] = externalTileId
        if externalTileId > maxTileId then maxTileId = externalTileId end

        local externalFrameId = frameIdByInternalIndex[internalIndex]
        if externalFrameId == nil or usedFrameIds[externalFrameId] then
            externalFrameId = allocateNextFreeId(usedFrameIds)
        end
        usedFrameIds[externalFrameId] = true
        frameIdByInternalIndex[internalIndex] = externalFrameId
        if externalFrameId > maxFrameId then maxFrameId = externalFrameId end

        local existingTile = existingTilesById[externalTileId]
        local existingFrame = existingFramesById[externalFrameId]

        outputTiles[externalTileId + 1] = buildTileDocument(tileData, existingTile, externalTileId, externalFrameId)
        outputFrames[externalFrameId + 1] = buildFrameDocument(gameData.frames[internalIndex] or {}, existingFrame, externalFrameId)
    end

    if maxTileId >= 0 then
        local sparseTiles = makeSparseIdArray(maxTileId)
        for _, tile in pairs(outputTiles) do
            if type(tile) == "table" and tile.id ~= nil then
                sparseTiles[tile.id + 1] = tile
            end
        end
        baseDocument.tiles = sparseTiles
    else
        baseDocument.tiles = {}
    end

    if maxFrameId >= 0 then
        local sparseFrames = makeSparseIdArray(maxFrameId)
        for _, frame in pairs(outputFrames) do
            if type(frame) == "table" and frame.id ~= nil then
                sparseFrames[frame.id + 1] = frame
            end
        end
        baseDocument.frames = sparseFrames
    else
        baseDocument.frames = {}
    end

    for _, roomData in ipairs(gameData.rooms or {}) do
        local existingRoom = roomMetadataById[roomData.id]
        local roomDocument = buildRoomDocument(roomData, existingRoom, mappedExternalTileIds)
        outputRooms[roomData.id + 1] = roomDocument
        roomMetadataById[roomData.id] = deepCopy(roomDocument)
        if roomData.id > maxRoomId then maxRoomId = roomData.id end
    end

    if maxRoomId >= 0 then
        local sparseRooms = makeSparseIdArray(maxRoomId)
        for _, room in pairs(outputRooms) do
            if type(room) == "table" and room.id ~= nil then
                sparseRooms[room.id + 1] = room
            end
        end
        baseDocument.rooms = sparseRooms
    else
        baseDocument.rooms = {}
    end

    updateEditorAndPlayerState(baseDocument, options)
    incrementBuildNumber(baseDocument)

    return baseDocument, {
        document = deepCopy(baseDocument),
        tileIdByInternalIndex = tileIdByInternalIndex,
        frameIdByInternalIndex = frameIdByInternalIndex,
        roomMetadataById = roomMetadataById
    }
end

function PulpGameIO.prepareLoadedGame(gameName, savedData, baseTileImages)
    if not savedData then
        return nil, nil, false
    end

    if documentLooksStructured(savedData) and not Migration.needsMigration(savedData) then
        local workingGameData, pulpState = extractWorkingStateFromDocument(savedData, gameName)
        local normalizedDocument, normalizedState = PulpGameIO.buildSaveDocument(gameName, workingGameData, pulpState)
        normalizedState.document = normalizedDocument
        return workingGameData, normalizedState, false
    end

    local migratedGameData = Migration.migrateV1ToV2(savedData, gameName, baseTileImages)
    local normalizedDocument, normalizedState = PulpGameIO.buildSaveDocument(gameName, migratedGameData, nil)
    normalizedState.document = normalizedDocument
    return migratedGameData, normalizedState, true
end

return PulpGameIO