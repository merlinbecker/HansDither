-- ImageStoreCodec.lua
-- Modul für die Kodierung/Dekodierung von Bildern im nativen PDI-Speicherformat
-- Coroutine-basierte Save/Load-Operationen für RoomOperation

import "CoreLibs/graphics"
import "CoreLibs/object"

local gfx = playdate.graphics

ImageStoreCodec = {}

-- Erzeugt eine neue Save-Operation als Coroutine
function ImageStoreCodec.newSaveOperation(imageData)
    return coroutine.create(function()
        -- Validierung der Eingabedaten
        if not imageData or not imageData.id then
            error("Invalid imageData: id required")
        end
        
        local id = imageData.id
        local name = imageData.name or "unnamed"
        local imagetable = imageData.imagetable
        local frames = imageData.frames or {}
        local hashIndex = imageData.hashIndex or {}
        
        -- Phase 1: Dedup (T014 - wird später in US2 implementiert, hier zunächst ohne Dedup)
        -- Für MVP: alle Tiles werden als einzigartig behandelt
        coroutine.yield("Dedup")
        
        -- Zähle tatsächliche Anzahl der Tiles
        local tileCount = imagetable and imagetable:getLength() or 0
        if tileCount < 2 then
            -- Stelle sicher, dass mindestens die Basistiles (Weiß/Schwarz) vorhanden sind
            tileCount = 2
        end
        
        -- Phase 2: Sheet komponieren
        coroutine.yield("Sheet")
        
        -- Erstelle Sheet-Image mit der richtigen Größe
        local sheetWidth, sheetHeight = ImageStoreCodec.getSheetDimensions(tileCount)
        local sheet = gfx.image.new(sheetWidth, sheetHeight, gfx.kColorClear)
        
        -- Zeichne alle Tiles in das Sheet
        gfx.pushContext(sheet)
            for i = 1, tileCount do
                local tileImg = imagetable:getImage(i)
                if tileImg then
                    local x, y = ImageStoreCodec.tileIndexToPosition(i)
                    gfx.drawImage(tileImg, x, y)
                end
            end
        gfx.popContext()
        
        -- Phase 3: Frames JSON erstellen und speichern
        coroutine.yield("Frames")
        
        local framesTable = ImageStoreCodec.createFramesTable(name, frames, tileCount)
        
        -- Stelle sicher, dass der saves-Ordner für dieses Bild existiert
        local savePath = "saves/" .. id
        playdate.file.mkdir(savePath)
        
        -- Speichere frames.json
        playdate.datastore.write(framesTable, savePath .. "/frames")
        
        -- Phase 4: Bilddaten speichern (Sheet)
        coroutine.yield("Bilddaten")
        
        -- Speichere sheet.pdi
        playdate.datastore.writeImage(sheet, savePath .. "/sheet")
        
        -- Phase 5: Preview erstellen und speichern
        coroutine.yield("Preview")
        
        -- Erstelle Preview aus dem ersten Frame (400x240)
        local preview = ImageStoreCodec.createPreviewFromFrame(frames[1], imagetable)
        playdate.datastore.writeImage(preview, savePath .. "/preview")
        
        -- Phase 6: Index aktualisieren (MUSS die letzte Phase sein - C-06)
        coroutine.yield("Index")
        
        -- Aktualisiere Index
        ImageStoreCodec.updateIndexAfterSave(id, name, #frames, preview)
    end)
end

-- Hilfsfunktion: Erstellt ein Preview-Image aus einem Frame
function ImageStoreCodec.createPreviewFromFrame(frameData, imagetable)
    if not frameData or not imagetable then
        -- Fallback: Weißes 400x240 Bild
        local preview = gfx.image.new(400, 240, gfx.kColorWhite)
        gfx.pushContext(preview)
            gfx.fillRect(0, 0, 400, 240)
        gfx.popContext()
        return preview
    end
    
    -- Erstelle ein Tilemap und rendere den Frame
    local tilemap = gfx.tilemap.new()
    tilemap:setImageTable(imagetable)
    
    -- Setze die Tiles für den Frame
    local frameTiles = {}
    for i, tileIndex in ipairs(frameData) do
        frameTiles[i] = tileIndex or 1  -- Fallback auf Tile 1 (Weiß)
    end
    tilemap:setTiles(frameTiles, 25)
    
    -- Rendere in ein 400x240 Bild
    local preview = gfx.image.new(400, 240, gfx.kColorWhite)
    gfx.pushContext(preview)
        tilemap:draw(0, 0)
    gfx.popContext()
    
    return preview
end

-- Hilfsfunktion: Aktualisiert den Index nach dem Speichern
function ImageStoreCodec.updateIndexAfterSave(id, name, frameCount, previewImage)
    -- hole aktuellen Index
    local index = ImageStore.getIndex()
    
    -- Aktualisiere oder erstelle Bild-Eintrag
    local found = false
    for _, img in ipairs(index.images or {}) do
        if img.id == id then
            img.name = name
            img.frameCount = frameCount
            img.lastEdited = playdate.getSecondsSinceEpoch()
            found = true
            break
        end
    end
    
    if not found then
        table.insert(index.images, {
            id = id,
            name = name,
            frameCount = frameCount,
            lastEdited = playdate.getSecondsSinceEpoch()
        })
    end
    
    -- Aktualisiere lastEditedId
    index.lastEditedId = id
    
    -- Schreibe Index
    ImageStore.writeIndex()
end

-- Erzeugt eine neue Load-Operation als Coroutine
function ImageStoreCodec.newLoadOperation(id)
    return coroutine.create(function()
        if not id or type(id) ~= "string" then
            error("Invalid image id")
        end
        
        local savePath = "saves/" .. id
        
        -- Phase 1: Frames lesen
        coroutine.yield("Frames lesen")
        
        local framesTable = playdate.datastore.read(savePath .. "/frames")
        if not framesTable then
            error("frames.json not found or invalid")
        end
        
        -- Validierung der frames.json Struktur
        if type(framesTable) ~= "table" or not framesTable.frames or not framesTable.tileCount then
            error("Invalid frames.json structure")
        end
        
        local frames = framesTable.frames
        local tileCount = framesTable.tileCount or 0
        local name = framesTable.name or "unnamed"
        
        -- Phase 2: Bilddaten lesen (Sheet)
        coroutine.yield("Bilddaten lesen")
        
        local sheet = playdate.datastore.readImage(savePath .. "/sheet")
        if not sheet then
            error("sheet.pdi not found")
        end
        
        -- Phase 3: Slicing - Imagetable aus Sheet erstellen
        coroutine.yield("Slicing")
        
        local imagetable, hashIndex = ImageStoreCodec.sliceSheetToImagetable(sheet, tileCount)
        
        -- Phase 4: Validierung
        coroutine.yield("Validierung")
        
        -- Validierung der Frame-Daten
        local validatedFrames = {}
        for frameIdx, frameData in ipairs(frames or {}) do
            if type(frameData) == "table" and #frameData == 375 then
                local validatedFrame = {}
                for posIdx, tileIndex in ipairs(frameData) do
                    -- Validierung: 1 <= tileIndex <= tileCount
                    local validatedIndex = tonumber(tileIndex)
                    if not validatedIndex or validatedIndex < 1 or validatedIndex > tileCount then
                        validatedIndex = 1  -- Fallback auf Weiß-Tile
                    end
                    validatedFrame[posIdx] = validatedIndex
                end
                validatedFrames[frameIdx] = validatedFrame
            end
        end
        
        -- Erstelle Ergebnis
        local imageData = {
            id = id,
            name = name,
            imagetable = imagetable,
            frames = validatedFrames,
            hashIndex = hashIndex
        }
        
        -- Return the loaded imageData
        return imageData
    end)
end

-- Hilfsfunktion: Erstellt eine Imagetable aus einem Sheet-Image durch Slicing
function ImageStoreCodec.sliceSheetToImagetable(sheet, tileCount)
    if not sheet then
        return gfx.imagetable.new(1), {}
    end
    
    local tileCount = tonumber(tileCount) or 0
    if tileCount < 1 then
        tileCount = 1
    end
    
    -- Erstelle Imagetable mit der richtigen Größe
    local imagetable = gfx.imagetable.new(tileCount)
    local hashIndex = {}
    
    -- Für jedes Tile, extrahiere die 16x16 Zelle aus dem Sheet
    for i = 1, tileCount do
        local x, y = ImageStoreCodec.tileIndexToPosition(i)
        
        -- Extrahiere die Zelle als neues Image
        local tileImg = gfx.image.new(16, 16, gfx.kColorClear)
        gfx.pushContext(tileImg)
            gfx.drawImage(sheet, -x, -y)  -- Zeichne den Ausschnitt
        gfx.popContext()
        
        imagetable:setImage(i, tileImg)
        
        -- Berechne Hash für Dedup
        hashIndex[ImageStoreCodec.hashTile(tileImg)] = i
    end
    
    return imagetable, hashIndex
end

-- Erzeugt ein Voll-Weißes 16x16 Tile
function ImageStoreCodec.createWhiteTile()
    local img = gfx.image.new(16, 16, gfx.kColorWhite)
    gfx.pushContext(img)
        gfx.fillRect(0, 0, 16, 16)
    gfx.popContext()
    return img
end

-- Erzeugt ein Voll-Schwarzes 16x16 Tile
function ImageStoreCodec.createBlackTile()
    local img = gfx.image.new(16, 16, gfx.kColorWhite) -- Start mit weiß
    gfx.pushContext(img)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0, 0, 16, 16)
    gfx.popContext()
    return img
end

-- Konvertiert einen Tile-Index in Sheet-Koordinaten (0-basiert)
-- Tile n (1-basiert) liegt bei Zelle ((n-1) % 25, floor((n-1) / 25))
function ImageStoreCodec.tileIndexToPosition(tileIndex)
    local oneBasedIndex = tonumber(tileIndex) or 1
    if oneBasedIndex < 1 then oneBasedIndex = 1 end
    
    local zeroBasedIndex = oneBasedIndex - 1
    local x = (zeroBasedIndex % 25) * 16  -- 25 Tiles pro Zeile, Zellgröße 16px
    local y = math.floor(zeroBasedIndex / 25) * 16
    
    return x, y
end

-- Berechnet Sheet-Abmessungen aus Tile-Anzahl
-- Breite = min(tileCount, 25) × 16, Höhe = ceil(tileCount / 25) × 16
function ImageStoreCodec.getSheetDimensions(tileCount)
    local count = tonumber(tileCount) or 0
    if count < 1 then count = 1 end
    
    local tilesPerRow = 25
    local rows = math.ceil(count / tilesPerRow)
    local cols = math.min(count, tilesPerRow)
    
    return cols * 16, rows * 16
end

-- Berechnet die Umkehrfunktion: Sheet-Position → Tile-Index (1-basiert)
function ImageStoreCodec.positionToTileIndex(x, y, gridWidth)
    local gridW = tonumber(gridWidth) or 25
    local cellX = math.floor((tonumber(x) or 0) / 16)
    local cellY = math.floor((tonumber(y) or 0) / 16)
    
    return cellX + cellY * gridW + 1  -- +1 für 1-basierte Indizes
end

-- FNV-1a Hash über 16x16 Tile
-- Basierend auf dem Muster aus TileRoomPersistence.lua
function ImageStoreCodec.hashTile(image)
    if not image then return "00000000" end
    
    local w, h = image:getSize()
    local hash = -2128831035  -- FNV-1a 32-bit offset basis
    
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local pixel = image:sample(x, y) or 0
            -- Für 1-Bit-Bilder: 0=weiß/clear, 1=schwarz/black, andere Werte möglich
            local byteValue = pixel == gfx.kColorBlack and 1 or 0
            hash = hash ~ byteValue
            hash = hash * 16777619
        end
    end
    
    return string.format("%08x", hash)
end

-- Erzeugt die frames.json Tabellenstruktur
-- Struktur: {version=1, name, gridWidth=25, gridHeight=15, tileCount, frames={...}}
function ImageStoreCodec.createFramesTable(name, frames, tileCount)
    local framesData = {
        version = 1,
        name = name or "unnamed",
        gridWidth = 25,
        gridHeight = 15,
        tileCount = tonumber(tileCount) or 0,
        frames = {}
    }
    
    -- frames ist ein Array von Frame-Daten (375 Indizes pro Frame)
    if type(frames) == "table" then
        for i, frame in ipairs(frames) do
            if type(frame) == "table" and #frame == 375 then
                framesData.frames[i] = frame
            end
        end
    end
    
    return framesData
end

return ImageStoreCodec