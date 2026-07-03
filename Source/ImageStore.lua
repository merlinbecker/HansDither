-- ImageStore.lua
-- Modul für die Verwaltung von Bildern im nativen PDI-Speicherformat
-- Ersetzt die PulpGameIO*-Module ab v0.3.0

import "CoreLibs/graphics"
import "CoreLibs/object"

local gfx = playdate.graphics

ImageStore = {}

-- Privater Index-Cache
local indexCache = nil

-- Lädt den Index aus dem Datastore oder legt einen neuen an
function ImageStore.getIndex()
    if indexCache then
        return indexCache
    end

    local success, data = pcall(function()
        return playdate.datastore.read("saves/index")
    end)

    if success and data then
        -- Validiere Index-Struktur
        if type(data) == "table" and data.version and data.images then
            indexCache = data
            return indexCache
        end
    end

    -- Erstelle neuen leeren Index
    indexCache = {
        version = 1,
        lastEditedId = nil,
        images = {}
    }
    ImageStore.writeIndex()
    return indexCache
end

-- Schreibt den Index in den Datastore
function ImageStore.writeIndex()
    if indexCache then
        playdate.datastore.write(indexCache, "saves/index")
    end
end

-- Invalidiert den Index-Cache (z.B. nach Änderungen)
function ImageStore.invalidateIndex()
    indexCache = nil
end

-- Gibt alle Bilder zurück, absteigend nach lastEdited sortiert
function ImageStore.listImages()
    local index = ImageStore.getIndex()
    local images = {}
    
    -- Kopiere Bilder-Array
    for i, img in ipairs(index.images or {}) do
        images[i] = img
    end
    
    -- Sortiere absteigend nach lastEdited
    table.sort(images, function(a, b)
        return (a.lastEdited or 0) > (b.lastEdited or 0)
    end)
    
    return images
end

-- Sanitisiert einen Namen zu einer gültigen ID
-- Regeln: Kleinschreibung, nur a–z/0–9/`-`, Leerzeichen→`-`
function ImageStore.sanitizeName(name)
    if not name or type(name) ~= "string" then
        return ""
    end
    
    local sanitized = string.lower(name)
    -- Ersetze alle Zeichen, die nicht a-z, 0-9 oder - sind
    sanitized = string.gsub(sanitized, "[^a-z0-9%-]", "-")
    -- Entferne doppelte Bindestriche
    sanitized = string.gsub(sanitized, "--+", "-")
    -- Entferne führende/abschließende Bindestriche
    sanitized = string.gsub(sanitized, "^-", "")
    sanitized = string.gsub(sanitized, "-$", "")
    
    -- Falls leer, nutze Fallback
    if sanitized == "" then
        sanitized = "unnamed"
    end
    
    return sanitized
end

-- Prüft, ob eine ID bereits vergeben ist
function ImageStore.isIdTaken(id)
    local index = ImageStore.getIndex()
    for _, img in ipairs(index.images or {}) do
        if img.id == id then
            return true
        end
    end
    return false
end

-- Erstellt ein neues Bild
function ImageStore.createImage(name)
    if not name or type(name) ~= "string" then
        return nil, "Invalid name"
    end
    
    -- Sanitisieren des Namens
    local id = ImageStore.sanitizeName(name)
    
    -- Kollisionsprüfung
    if ImageStore.isIdTaken(id) then
        return nil, "name-taken"
    end
    
    -- Erstelle den saves-Ordner für dieses Bild
    local savePath = "saves/" .. id
    playdate.file.mkdir(savePath)
    
    -- Erstelle Initialdaten über Codec-Helfer
    -- 1 Frame mit allen Indizes = 1 (Weiß-Tile)
    local whiteTile = ImageStoreCodec.createWhiteTile()
    local blackTile = ImageStoreCodec.createBlackTile()
    
    -- Erstelle Imagetable mit den Basistiles
    local imagetable = playdate.graphics.imagetable.new(2)
    imagetable:setImage(1, whiteTile)
    imagetable:setImage(2, blackTile)
    
    -- Erstelle Frame-Daten (alle Positionen = 1 für Weiß)
    local frameData = {}
    for i = 1, 375 do
        frameData[i] = 1
    end
    
    local frames = {frameData}  -- Ein Frame
    
    -- Erstelle imageData für das initiale Save
    local imageData = {
        id = id,
        name = name,
        imagetable = imagetable,
        frames = frames,
        hashIndex = {}
    }
    
    -- Speichere das Bild über den Codec
    local saveCo = ImageStoreCodec.newSaveOperation(imageData)
    
    -- Führe die Save-Operation synchron aus (da dies in createImage aufgerufen wird)
    local success, err = coroutine.resume(saveCo)
    while coroutine.status(saveCo) == "suspended" do
        success, err = coroutine.resume(saveCo)
        if not success then
            break
        end
    end
    
    if not success then
        return nil, err or "Save failed"
    end
    
    return id
end

-- Kopiert ein Bild
function ImageStore.copyImage(id)
    if not id or type(id) ~= "string" then
        return nil, "Invalid id"
    end
    
    local index = ImageStore.getIndex()
    local sourceImage = nil
    
    -- Finde das Quellbild
    for _, img in ipairs(index.images or {}) do
        if img.id == id then
            sourceImage = img
            break
        end
    end
    
    if not sourceImage then
        return nil, "Image not found"
    end
    
    -- Auto-Suffix für den neuen Namen
    local newName = sourceImage.name .. "-copy"
    local newId = ImageStore.sanitizeName(newName)
    
    -- Stelle sicher, dass der neue Name einzigartig ist
    local suffix = 1
    while ImageStore.isIdTaken(newId) do
        newName = sourceImage.name .. "-copy-" .. suffix
        newId = ImageStore.sanitizeName(newName)
        suffix = suffix + 1
    end
    
    -- Kopiere Dateien
    local sourcePath = "saves/" .. id
    local destPath = "saves/" .. newId
    
    -- Erstelle Zielordner
    playdate.file.mkdir(destPath)
    
    -- Kopiere frames.json
    local framesData = playdate.datastore.read(sourcePath .. "/frames")
    if framesData then
        playdate.datastore.write(framesData, destPath .. "/frames")
    end
    
    -- Kopiere sheet.pdi
    local sheet = playdate.datastore.readImage(sourcePath .. "/sheet")
    if sheet then
        playdate.datastore.writeImage(sheet, destPath .. "/sheet")
    end
    
    -- Kopiere preview.pdi
    local preview = playdate.datastore.readImage(sourcePath .. "/preview")
    if preview then
        playdate.datastore.writeImage(preview, destPath .. "/preview")
    end
    
    -- Erstelle Index-Eintrag
    table.insert(index.images, {
        id = newId,
        name = newName,
        frameCount = sourceImage.frameCount,
        lastEdited = playdate.getSecondsSinceEpoch()
    })
    
    -- Schreibe Index
    ImageStore.writeIndex()
    
    return newId
end

-- Löscht ein Bild
function ImageStore.deleteImage(id)
    if not id or type(id) ~= "string" then
        return false
    end
    
    local index = ImageStore.getIndex()
    local savePath = "saves/" .. id
    
    -- Entferne Dateien und Ordner
    playdate.file.delete(savePath .. "/frames")
    playdate.file.delete(savePath .. "/sheet")
    playdate.file.delete(savePath .. "/preview")
    playdate.file.delete(savePath)
    
    -- Entferne Index-Eintrag
    local newImages = {}
    for _, img in ipairs(index.images or {}) do
        if img.id ~= id then
            table.insert(newImages, img)
        end
    end
    index.images = newImages
    
    -- Bestimme neuen lastEditedId (jüngstes verbleibendes Bild oder nil)
    if #index.images == 0 then
        index.lastEditedId = nil
    else
        -- Sortiere nach lastEdited und nimm das neueste
        table.sort(index.images, function(a, b)
            return (a.lastEdited or 0) > (b.lastEdited or 0)
        end)
        index.lastEditedId = index.images[1].id
    end
    
    -- Schreibe Index
    ImageStore.writeIndex()
    
    return true
end

-- Gibt das Vorschaubild eines Bildes zurück
function ImageStore.getPreviewImage(id)
    if not id or type(id) ~= "string" then
        return nil
    end
    
    local savePath = "saves/" .. id
    return playdate.datastore.readImage(savePath .. "/preview")
end

-- Gibt das Vorschaubild des zuletzt bearbeiteten Bildes zurück
function ImageStore.getLastEditedPreview()
    local index = ImageStore.getIndex()
    if not index.lastEditedId then
        return nil
    end
    return ImageStore.getPreviewImage(index.lastEditedId)
end

return ImageStore