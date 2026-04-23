PulpGameIOShared = {}

local json = (_G and rawget(_G, "json")) or (playdate and rawget(playdate, "json"))
local TEMPLATE_PATH = "data/HansDitherTemplate.json"
local cachedTemplate = nil

function PulpGameIOShared.deepCopy(value, seen)
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
        copy[PulpGameIOShared.deepCopy(key, seen)] = PulpGameIOShared.deepCopy(nestedValue, seen)
    end
    return copy
end

function PulpGameIOShared.isArrayLikeTable(value)
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

function PulpGameIOShared.mergeMissingFields(target, defaults, excludedKeys)
    for key, defaultValue in pairs(defaults) do
        if not (excludedKeys and excludedKeys[key]) then
            local currentValue = target[key]
            if currentValue == nil then
                target[key] = PulpGameIOShared.deepCopy(defaultValue)
            elseif type(currentValue) == "table" and type(defaultValue) == "table" then
                if not PulpGameIOShared.isArrayLikeTable(currentValue) and not PulpGameIOShared.isArrayLikeTable(defaultValue) then
                    PulpGameIOShared.mergeMissingFields(currentValue, defaultValue)
                end
            end
        end
    end
end

function PulpGameIOShared.stripUtf8Bom(content)
    if type(content) == "string" and string.byte(content, 1) == 239 and string.byte(content, 2) == 187 and string.byte(content, 3) == 191 then
        return string.sub(content, 4)
    end
    return content
end

function PulpGameIOShared.readJsonFile(path)
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

    local content = PulpGameIOShared.stripUtf8Bom(table.concat(lines, "\n"))
    if content == "" then
        error("Template-Datei ist leer: " .. path)
    end

    local decoded = json.decode(content)
    if type(decoded) ~= "table" then
        error("Template-Datei enthaelt kein gueltiges JSON-Objekt: " .. path)
    end
    return decoded
end

function PulpGameIOShared.getTemplate(gameName)
    if cachedTemplate == nil then
        cachedTemplate = PulpGameIOShared.readJsonFile(TEMPLATE_PATH)
    end
    local templateCopy = PulpGameIOShared.deepCopy(cachedTemplate)
    templateCopy.name = gameName or templateCopy.name
    return templateCopy
end

function PulpGameIOShared.collectEntriesWithId(list)
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

function PulpGameIOShared.indexEntriesById(list)
    local indexed = {}
    for _, value in ipairs(PulpGameIOShared.collectEntriesWithId(list)) do
        indexed[value.id] = value
    end
    return indexed
end

function PulpGameIOShared.allocateNextFreeId(usedIds)
    local nextId = 0
    while usedIds[nextId] do
        nextId = nextId + 1
    end
    return nextId
end

function PulpGameIOShared.makeSparseIdArray(maxId)
    local result = {}
    for i = 1, maxId + 1 do
        result[i] = false
    end
    return result
end

function PulpGameIOShared.ensureArrayField(target, fieldName)
    if type(target[fieldName]) ~= "table" then
        target[fieldName] = {}
    end
end

function PulpGameIOShared.ensureBlockList(scriptData)
    PulpGameIOShared.ensureArrayField(scriptData, "__blocks")
    if scriptData.__blocks[1] == nil then
        scriptData.__blocks[1] = {}
    end
end

function PulpGameIOShared.appendUnique(list, value)
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

function PulpGameIOShared.ensureEventHandler(scriptData, eventName)
    PulpGameIOShared.ensureBlockList(scriptData)

    local handler = scriptData[eventName]
    if type(handler) ~= "table" or handler[1] ~= "block" or type(handler[2]) ~= "number" then
        scriptData[eventName] = { "block", 0 }
    end

    PulpGameIOShared.appendUnique(scriptData.__srcOrder, eventName)
end

function PulpGameIOShared.mergeScriptValue(target, defaults)
    for key, defaultValue in pairs(defaults) do
        local currentValue = target[key]
        if currentValue == nil then
            target[key] = PulpGameIOShared.deepCopy(defaultValue)
        elseif type(currentValue) == "table" and type(defaultValue) == "table" then
            if PulpGameIOShared.isArrayLikeTable(currentValue) and PulpGameIOShared.isArrayLikeTable(defaultValue) then
                if #currentValue == 0 and #defaultValue > 0 then
                    target[key] = PulpGameIOShared.deepCopy(defaultValue)
                end
            else
                PulpGameIOShared.mergeScriptValue(currentValue, defaultValue)
            end
        end
    end
end

function PulpGameIOShared.buildScriptKey(scriptEntry)
    if type(scriptEntry) ~= "table" then
        return nil
    end
    return tostring(scriptEntry.type) .. ":" .. tostring(scriptEntry.id)
end

function PulpGameIOShared.getPrimaryTemplateScript(template)
    if type(template) ~= "table" or type(template.scripts) ~= "table" then
        return nil
    end
    for _, scriptEntry in ipairs(template.scripts) do
        if type(scriptEntry) == "table" and scriptEntry.id == 0 and scriptEntry.type == 0 then
            return PulpGameIOShared.deepCopy(scriptEntry)
        end
    end
    return nil
end

function PulpGameIOShared.keepOnlyPrimaryScript(document, template)
    local primaryScript = PulpGameIOShared.getPrimaryTemplateScript(template)
    if primaryScript ~= nil then
        document.scripts = { primaryScript }
    else
        document.scripts = {}
    end
    document.script = 0
end

function PulpGameIOShared.keepTemplateAudioDefinitions(document, template)
    document.song = template.song or -1
    document.songs = PulpGameIOShared.deepCopy(template.songs or {})
    document.sounds = PulpGameIOShared.deepCopy(template.sounds or {})
end

function PulpGameIOShared.normalizeScriptData(scriptEntry)
    if type(scriptEntry) ~= "table" then
        return
    end
    if type(scriptEntry.data) ~= "table" then
        scriptEntry.data = {}
    end

    local scriptData = scriptEntry.data
    PulpGameIOShared.ensureArrayField(scriptData, "__blocks")
    PulpGameIOShared.ensureArrayField(scriptData, "__comments")
    PulpGameIOShared.ensureArrayField(scriptData, "__srcOrder")

    if scriptEntry.type == 0 then
        PulpGameIOShared.ensureEventHandler(scriptData, "load")
        PulpGameIOShared.ensureEventHandler(scriptData, "change")
        return
    end
    if scriptEntry.type == 1 then
        if scriptData.enter ~= nil or #scriptData.__srcOrder > 0 or #scriptData.__blocks > 0 then
            PulpGameIOShared.ensureEventHandler(scriptData, "enter")
        end
        return
    end
    if scriptEntry.type == 2 then
        local knownEvents = { "update", "crank", "draw", "cancel", "confirm", "paint", "erase" }
        for _, eventName in ipairs(knownEvents) do
            PulpGameIOShared.ensureEventHandler(scriptData, eventName)
        end
    end
end

function PulpGameIOShared.normalizeScripts(document)
    if type(document.scripts) ~= "table" then
        document.scripts = {}
    end
    for _, scriptEntry in pairs(document.scripts) do
        PulpGameIOShared.normalizeScriptData(scriptEntry)
    end
end

function PulpGameIOShared.documentLooksStructured(data)
    return type(data) == "table"
        and type(data.rooms) == "table"
        and type(data.tiles) == "table"
        and type(data.frames) == "table"
end

function PulpGameIOShared.buildBaseDocument(gameName, existingDocument)
    local document = existingDocument and PulpGameIOShared.deepCopy(existingDocument) or PulpGameIOShared.getTemplate(gameName)
    local template = PulpGameIOShared.getTemplate(gameName)
    PulpGameIOShared.mergeMissingFields(document, template, { rooms = true, tiles = true, frames = true })
    PulpGameIOShared.keepOnlyPrimaryScript(document, template)
    PulpGameIOShared.keepTemplateAudioDefinitions(document, template)
    document.name = gameName or document.name or template.name
    document.version = template.version or 1
    document.rooms = document.rooms or {}
    document.tiles = document.tiles or {}
    document.frames = document.frames or {}
    PulpGameIOShared.normalizeScripts(document)
    return document
end

function PulpGameIOShared.buildRoomDocument(roomData, existingRoom, externalTileIds)
    local roomDocument = existingRoom and PulpGameIOShared.deepCopy(existingRoom) or {
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
        mappedTiles[index] = externalTileIds[internalTileId + 1] or 0
    end
    roomDocument.tiles = mappedTiles
    if roomDocument.song == nil then roomDocument.song = -1 end
    if type(roomDocument.exits) ~= "table" then roomDocument.exits = {} end
    return roomDocument
end

function PulpGameIOShared.buildTileDocument(tileData, existingTile, externalTileId, externalFrameId)
    local tileDocument = existingTile and PulpGameIOShared.deepCopy(existingTile) or {
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

function PulpGameIOShared.buildFrameDocument(frameData, existingFrame, externalFrameId)
    local frameDocument = existingFrame and PulpGameIOShared.deepCopy(existingFrame) or { id = externalFrameId, data = PulpGameIOShared.deepCopy(frameData.data or {}) }
    frameDocument.id = externalFrameId
    frameDocument.data = PulpGameIOShared.deepCopy(frameData.data or {})
    return frameDocument
end

function PulpGameIOShared.roomIdExists(rooms, roomId)
    for _, room in ipairs(PulpGameIOShared.collectEntriesWithId(rooms)) do
        if room.id == roomId then
            return true
        end
    end
    return false
end

function PulpGameIOShared.updateEditorAndPlayerState(document, options)
    if type(document.player) ~= "table" then document.player = {} end
    if type(document.editor) ~= "table" then document.editor = {} end

    local roomEntries = PulpGameIOShared.collectEntriesWithId(document.rooms)
    local tileEntries = PulpGameIOShared.collectEntriesWithId(document.tiles)
    local frameEntries = PulpGameIOShared.collectEntriesWithId(document.frames)
    local songEntries = PulpGameIOShared.collectEntriesWithId(document.songs)
    local soundEntries = PulpGameIOShared.collectEntriesWithId(document.sounds)

    if #roomEntries > 0 then
        local desiredRoomId = nil
        if options and options.currentRoomIndex and roomEntries[options.currentRoomIndex] then
            desiredRoomId = roomEntries[options.currentRoomIndex].id
        elseif PulpGameIOShared.roomIdExists(document.rooms, document.player.room) then
            desiredRoomId = document.player.room
        else
            desiredRoomId = roomEntries[1].id
        end
        document.player.room = desiredRoomId
        document.editor.activeRoomId = desiredRoomId
    end

    local function ensureActiveId(entries, fieldName)
        if #entries == 0 then return end
        local activeId = document.editor[fieldName]
        local valid = false
        for _, entry in ipairs(entries) do
            if entry.id == activeId then
                valid = true
                break
            end
        end
        if not valid then
            document.editor[fieldName] = entries[1].id
        end
    end

    ensureActiveId(tileEntries, "activeTileId")
    ensureActiveId(frameEntries, "activeFrameId")
    ensureActiveId(songEntries, "activeSongId")
    ensureActiveId(soundEntries, "activeSoundId")

    PulpGameIOShared.ensureArrayField(document.editor, "sortedTiles")
    local sortedFrameIds = {}
    for _, tile in ipairs(tileEntries) do
        local frameId = type(tile.frames) == "table" and tile.frames[1] or nil
        if type(frameId) == "number" then
            sortedFrameIds[#sortedFrameIds + 1] = frameId
        end
    end
    document.editor.sortedTiles[5] = sortedFrameIds
end

function PulpGameIOShared.incrementBuildNumber(document)
    local currentBuildNumber = tonumber(document.buildNumber)
    if currentBuildNumber == nil then currentBuildNumber = 0 end
    document.buildNumber = tostring(currentBuildNumber + 1)
end

return PulpGameIOShared