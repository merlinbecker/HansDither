-- ImageStoreCodec.lua
-- Modul für die Kodierung/Dekodierung von Bildern im nativen PDI-Speicherformat
-- Coroutine-basierte Save/Load-Operationen für RoomOperation
--
-- Spec 010 (Foundational, contracts/save-format.md): frames.json traegt ab
-- sofort Version "1.1" mit verschachtelten Layern je Frame statt flacher
-- 375er-Arrays (Spec 009, version = 1). Massgeblich ist imageData.frameLayers
-- (1..3 Ebenen je Frame, LayerModel-Format). Fehlt es (Alt-Aufrufer/Tests,
-- die nur imageData.frames setzen), wird defensiv je Frame ein 1-Ebenen-
-- Entry daraus gebaut — identisch zum v1.0->v1.1-Upgrade beim Laden.
-- imageData.frames bleibt zusaetzlich als flaches, KOMPOSITIERTES Array
-- erhalten (Tilemap-Rendering, Pause-Ansicht, Vorschau, Alt-Tests) — siehe
-- LayerModel.compositeToFlat().
--
-- Transparenz wird NICHT je Zelle in frames.json gefuehrt (der data-model.md-
-- Entwurf sah ein 375er transparency-Array vor); sie lebt pro Pixel als
-- kColorClear direkt im Tile-Bild und wird ueber den 3-Zustands-hashTile()
-- getrennt dedupliziert (spec.md Edge Case Zeile 104).

import "CoreLibs/graphics"
import "CoreLibs/object"
import "PixelTransparency"
import "LayerModel"

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

        -- Spec 010: frameLayers ist die massgebliche Quelle (1..3 verschachtelte
        -- Ebenen je Frame). Fehlt sie (Alt-Aufrufer/Tests, die nur das flache
        -- imageData.frames setzen), wird defensiv je Frame ein 1-Ebenen-Entry
        -- daraus gebaut — identisch zum v1.0->v1.1-Upgrade beim Laden.
        local frameLayers = imageData.frameLayers
        if not frameLayers then
            frameLayers = {}
            for i, flat in ipairs(imageData.frames or {}) do
                frameLayers[i] = LayerModel.newFrameLayersFromFlat(flat)
            end
        end

        -- Phase 1: Tile-Bereinigung (Spec 009 FR-001..003, Spec 010 ueber alle
        -- Frames UND Ebenen hinweg) — entfernt ungenutzte Tiles (ausser den
        -- Basistiles) und nummeriert die verbleibenden lückenlos neu. Reine
        -- Transformation: imageData bleibt unverändert (research.md R2 zu
        -- Spec 009 — der Editor verlässt nach "save + exit" immer den Raum,
        -- ein Live-State-Sync ist dadurch nicht nötig).
        coroutine.yield("Dedup")

        -- Zähle tatsächliche Anzahl der Tiles
        local tileCount = imagetable and imagetable:getLength() or 0
        if tileCount < 2 then
            -- Stelle sicher, dass mindestens die Basistiles (Weiß/Schwarz) vorhanden sind
            tileCount = 2
        end

        imagetable, frameLayers, tileCount =
            ImageStoreCodec.pruneUnusedTilesLayered(imagetable, frameLayers, tileCount)

        -- Flaches, kompositiertes Frame-Array fuer Vorschau + Frame-Zaehler
        -- (der Rest der Codebasis erwartet dieses Format).
        local compositedFrames = {}
        for i, entry in ipairs(frameLayers) do
            compositedFrames[i] = LayerModel.compositeToFlat(entry)
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
                    -- SDK: image:draw(x, y) — es gibt KEIN gfx.drawImage()!
                    tileImg:draw(x, y)
                end
            end
        gfx.popContext()
        
        -- Phase 3: Frames JSON erstellen und speichern
        coroutine.yield("Frames")

        local framesTable = ImageStoreCodec.createFramesTableV11(name, frameLayers, tileCount)

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
        
        -- Erstelle Preview aus dem ersten (kompositierten) Frame (400x240)
        local preview = ImageStoreCodec.createPreviewFromFrame(compositedFrames[1], imagetable)
        playdate.datastore.writeImage(preview, savePath .. "/preview")

        -- Phase 6: Index aktualisieren (MUSS die letzte Phase sein - C-06)
        coroutine.yield("Index")

        -- Aktualisiere Index
        ImageStoreCodec.updateIndexAfterSave(id, name, #frameLayers, preview)
    end)
end

-- Ermittelt die über alle Frames hinweg tatsächlich referenzierten Tiles,
-- entfernt alle anderen (ausser den beiden Basistiles) aus der Tile-
-- Sammlung und nummeriert die verbleibenden lückenlos neu durch
-- (data-model.md Abschnitt 1, Spec 009 FR-001..003).
--
-- Reine Funktion ohne Seiteneffekt: liest imagetable/frames nur lesend,
-- verändert weder das übergebene imagetable-Objekt noch imageData
-- (research.md R2 zu Spec 009).
--
-- Invariante: liefert IMMER mindestens 2 Tiles (Basistiles Weiss/Schwarz,
-- Index 1/2) zurück — unabhängig davon, ob sie in frames referenziert
-- werden (EditorRoom.lua-Toggle-Invariante: Malen ohne Pipetten-Auswahl
-- wechselt zwischen genau diesen beiden Indizes).
function ImageStoreCodec.pruneUnusedTiles(imagetable, frames, tileCount)
    local count = tonumber(tileCount) or 0

    -- Basistiles sind immer "genutzt", unabhängig von ihrer tatsächlichen
    -- Verwendung in frames
    local used = { [1] = true, [2] = true }

    for _, frame in ipairs(frames or {}) do
        for _, tileIndex in ipairs(frame) do
            local idx = tonumber(tileIndex)
            if idx then
                used[idx] = true
            end
        end
    end

    -- keepList: aufsteigend sortierte, gültige (1 <= idx <= count) Indizes
    local keepList = {}
    for idx in pairs(used) do
        if idx >= 1 and idx <= count then
            table.insert(keepList, idx)
        end
    end
    table.sort(keepList)

    -- Sicherheitsnetz: ohne gültige Tiles (z. B. count == 0) bleiben
    -- mindestens die Basistiles erhalten
    if #keepList == 0 then
        keepList = { 1, 2 }
    end

    -- remap[alterIndex] = neuerIndex (1-basiert, lückenlos)
    local remap = {}
    for newIdx, oldIdx in ipairs(keepList) do
        remap[oldIdx] = newIdx
    end

    -- Neue Imagetable mit den verbleibenden Tiles befüllen
    local newImagetable = gfx.imagetable.new(#keepList)
    if imagetable then
        for newIdx, oldIdx in ipairs(keepList) do
            newImagetable:setImage(newIdx, imagetable:getImage(oldIdx))
        end
    end

    -- Frame-Positionsdaten auf die neuen Indizes ummappen; ungültige oder
    -- durch die Bereinigung entfallene Alt-Indizes fallen auf das
    -- Weiss-Basistile zurück (kann bei referenzierten Tiles nicht
    -- vorkommen, dient als Sicherheitsnetz)
    local newFrames = {}
    for f, frame in ipairs(frames or {}) do
        local newFrame = {}
        for i, tileIndex in ipairs(frame) do
            local oldIdx = tonumber(tileIndex)
            newFrame[i] = (oldIdx and remap[oldIdx]) or remap[1]
        end
        newFrames[f] = newFrame
    end

    return newImagetable, newFrames, #keepList
end

-- Spec 010: Layer-Variante von pruneUnusedTiles(). Bereinigt ueber ALLE
-- Ebenen ALLER Frames hinweg (Tiles werden zwischen Ebenen und Frames
-- geteilt, ein per-Ebene-Prune waere gegen die gemeinsame Imagetable
-- unsound — T009 dahingehend angepasst). "absent" (0) belegt keinen Slot
-- und bleibt 0. Liefert (newImagetable, newFrameLayers, newTileCount);
-- frameLayers wird tief kopiert, imageData bleibt unveraendert.
function ImageStoreCodec.pruneUnusedTilesLayered(imagetable, frameLayers, tileCount)
    local count = tonumber(tileCount) or 0

    local used = { [1] = true, [2] = true }
    for _, entry in ipairs(frameLayers or {}) do
        for _, layer in ipairs(entry.layers or {}) do
            for _, tileIndex in ipairs(layer.positions or {}) do
                local idx = tonumber(tileIndex)
                if idx and idx >= 1 then
                    used[idx] = true
                end
            end
        end
    end

    local keepList = {}
    for idx in pairs(used) do
        if idx >= 1 and idx <= count then
            table.insert(keepList, idx)
        end
    end
    table.sort(keepList)
    if #keepList == 0 then
        keepList = { 1, 2 }
    end

    local remap = {}
    for newIdx, oldIdx in ipairs(keepList) do
        remap[oldIdx] = newIdx
    end

    local newImagetable = gfx.imagetable.new(#keepList)
    if imagetable then
        for newIdx, oldIdx in ipairs(keepList) do
            newImagetable:setImage(newIdx, imagetable:getImage(oldIdx))
        end
    end

    local newFrameLayers = {}
    for f, entry in ipairs(frameLayers or {}) do
        local newLayers = {}
        for l, layer in ipairs(entry.layers or {}) do
            local newPositions = {}
            for i, tileIndex in ipairs(layer.positions or {}) do
                local oldIdx = tonumber(tileIndex)
                if not oldIdx or oldIdx == 0 then
                    newPositions[i] = 0
                else
                    newPositions[i] = remap[oldIdx] or remap[1]
                end
            end
            newLayers[l] = {
                layerIndex = layer.layerIndex or (l - 1),
                name = layer.name or ("Layer " .. l),
                positions = newPositions,
                visible = layer.visible ~= false,
            }
        end
        newFrameLayers[f] = { duration = entry.duration or 100, layers = newLayers }
    end

    return newImagetable, newFrameLayers, #keepList
end

-- Hilfsfunktion: Erstellt ein Preview-Image aus einem Frame
function ImageStoreCodec.createPreviewFromFrame(frameData, imagetable)
    if not frameData or not imagetable then
        -- Fallback: weißes 400x240-Bild. SDK: image.new(w, h, bgcolor)
        -- füllt bereits mit der Hintergrundfarbe — KEIN fillRect nötig
        -- (fillRect ohne setColor malt mit der zuletzt gesetzten Farbe,
        -- typischerweise Schwarz!).
        return gfx.image.new(400, 240, gfx.kColorWhite)
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

        -- 375-Positions-Array validieren. 1 <= idx <= tileCount; ungueltig ->
        -- Weiss (1). allowAbsent: obere Ebenen duerfen 0 ("traegt nichts bei")
        -- behalten, die Basisebene nicht.
        local function validatePositions(arr, allowAbsent)
            local out = {}
            for i = 1, 375 do
                local v = tonumber(arr[i])
                if v == 0 and allowAbsent then
                    out[i] = 0
                elseif not v or v < 1 or v > tileCount then
                    out[i] = 1
                else
                    out[i] = math.floor(v)
                end
            end
            return out
        end

        -- Spec 010: frames.json ist entweder v1.0 (flaches 375-Array je Frame)
        -- oder v1.1 (Frame = {frameIndex, duration, layers = {...}}). Erkennung
        -- ueber die Struktur des ersten Frames, nicht ueber das version-Feld
        -- (robuster gegen fehlende/fehlerhafte Versionsangaben — FR-010).
        local first = frames and frames[1]
        local isLayered = type(first) == "table" and type(first.layers) == "table"

        local frameLayers = {}
        if isLayered then
            for _, fd in ipairs(frames) do
                if type(fd) == "table" and type(fd.layers) == "table" and #fd.layers >= 1 then
                    local builtLayers = {}
                    local n = math.min(#fd.layers, LayerModel.MAX_LAYERS)
                    for j = 1, n do
                        local ld = fd.layers[j]
                        if type(ld) == "table" and type(ld.positions) == "table"
                            and #ld.positions == 375 then
                            builtLayers[#builtLayers + 1] = {
                                layerIndex = #builtLayers,
                                name = ld.name or ("Layer " .. (#builtLayers + 1)),
                                positions = validatePositions(ld.positions, #builtLayers >= 1),
                                visible = ld.visible ~= false,
                            }
                        end
                    end
                    if #builtLayers >= 1 then
                        frameLayers[#frameLayers + 1] = {
                            duration = tonumber(fd.duration) or 100,
                            layers = builtLayers,
                        }
                    end
                end
            end
        else
            -- v1.0 -> v1.1 Upgrade: jeder flache Frame wird zur Basisebene
            -- "Layer 1" (alle Pixel opak, contracts/save-format.md).
            for _, frameData in ipairs(frames or {}) do
                if type(frameData) == "table" and #frameData == 375 then
                    frameLayers[#frameLayers + 1] =
                        LayerModel.newFrameLayersFromFlat(validatePositions(frameData, false))
                end
            end
        end

        -- Waren alle Frames defekt, liefern wir einen weißen Leerframe:
        -- der Editor verlässt sich darauf, dass frames[1] existiert.
        if #frameLayers == 0 then
            local emptyFrame = {}
            for i = 1, 375 do emptyFrame[i] = 1 end
            frameLayers[1] = LayerModel.newFrameLayersFromFlat(emptyFrame)
        end

        -- Flaches, kompositiertes Array fuer Tilemap/Vorschau/Pause-Ansicht.
        local validatedFrames = {}
        for i, entry in ipairs(frameLayers) do
            validatedFrames[i] = LayerModel.compositeToFlat(entry)
        end

        -- Erstelle Ergebnis
        local imageData = {
            id = id,
            name = name,
            imagetable = imagetable,
            frames = validatedFrames,
            frameLayers = frameLayers,
            activeLayer = 1,
            hashIndex = hashIndex
        }

        -- Return the loaded imageData
        return imageData
    end)
end

-- Hilfsfunktion: Erstellt eine Imagetable aus einem Sheet-Image durch Slicing.
--
-- Invariante des Editors: Index 1 = Voll-Weiß, Index 2 = Voll-Schwarz.
-- Malen ohne Pipetten-Auswahl toggelt zwischen genau diesen Indizes —
-- die Imagetable wird deshalb IMMER mit mindestens diesen Basistiles
-- aufgebaut, auch wenn das Sheet fehlt oder unvollständig ist.
function ImageStoreCodec.sliceSheetToImagetable(sheet, tileCount)
    local count = math.max(tonumber(tileCount) or 0, 2)

    -- SDK: gfx.imagetable.new(count) legt count leere Slots an
    local imagetable = gfx.imagetable.new(count)
    local hashIndex = {}

    local sheetW, sheetH = 0, 0
    if sheet then
        sheetW, sheetH = sheet:getSize()
    end

    for i = 1, count do
        local x, y = ImageStoreCodec.tileIndexToPosition(i)
        local tileImg

        if sheet and x + 16 <= sheetW and y + 16 <= sheetH then
            -- Zelle aus dem Sheet ausschneiden: negativer Offset schiebt den
            -- gewünschten Ausschnitt in den 16×16-Kontext (SDK: image:draw)
            tileImg = gfx.image.new(16, 16, gfx.kColorClear)
            gfx.pushContext(tileImg)
                sheet:draw(-x, -y)
            gfx.popContext()
        elseif i == 2 then
            -- Sheet deckt das Basistile nicht ab: Schwarz-Tile erzeugen
            tileImg = ImageStoreCodec.createBlackTile()
        else
            -- Fehlende Tiles fallen auf Weiß zurück (Index 1 und alle Luecken)
            tileImg = ImageStoreCodec.createWhiteTile()
        end

        imagetable:setImage(i, tileImg)

        -- Berechne Hash für Dedup
        hashIndex[ImageStoreCodec.hashTile(tileImg)] = i
    end

    return imagetable, hashIndex
end

-- Erzeugt ein Voll-Weißes 16x16 Tile.
-- SDK: image.new(w, h, bgcolor) füllt bereits weiß. Das frühere
-- pushContext+fillRect OHNE setColor übermalte das Tile mit der gerade
-- aktiven Zeichenfarbe (meist Schwarz) — das "weiße" Basis-Tile war
-- dadurch schwarz, und damit jedes neue Bild samt Preview.
function ImageStoreCodec.createWhiteTile()
    return gfx.image.new(16, 16, gfx.kColorWhite)
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

-- Vergleicht zwei Bilder auf sichtbare Gleichheit. Spec 010: DREI Zustaende
-- zaehlen — schwarz, weiss und transparent (kColorClear). Damit gelten zwei
-- Tiles mit gleichem Schwarz-Muster, aber unterschiedlicher Transparenz als
-- verschieden (spec.md Edge Case Zeile 104). Alt-Tiles (nur schwarz/weiss)
-- verhalten sich unveraendert. Wird vom Dedup beim Tile-Commit genutzt
-- (EditorRoom/ZoomRoom). SDK: image:sample(x, y) liest die Pixelfarbe
-- (0-basiert).
local function pixelClass(sample)
    if sample == gfx.kColorBlack then return 1 end
    if sample == gfx.kColorClear then return 2 end
    return 0  -- weiss / undefiniert
end

function ImageStoreCodec.imagesVisiblyEqual(a, b)
    if a == nil and b == nil then return true end
    if a == nil or b == nil then return false end
    local aw, ah = a:getSize()
    local bw, bh = b:getSize()
    if aw ~= bw or ah ~= bh then return false end
    for y = 0, ah - 1 do
        for x = 0, aw - 1 do
            if pixelClass(a:sample(x, y)) ~= pixelClass(b:sample(x, y)) then
                return false
            end
        end
    end
    return true
end

-- FNV-1a Hash über 16x16 Tile. Spec 010: 3-Zustands-Klasse je Pixel
-- (0 = weiss, 1 = schwarz, 2 = transparent) statt binaer schwarz/nicht-
-- schwarz, sonst wuerden transparenz-unterschiedliche Tiles kollidieren.
function ImageStoreCodec.hashTile(image)
    if not image then return "00000000" end

    local w, h = image:getSize()
    local hash = -2128831035  -- FNV-1a 32-bit offset basis

    for y = 0, h - 1 do
        for x = 0, w - 1 do
            hash = hash ~ pixelClass(image:sample(x, y))
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

-- Spec 010: frames.json v1.1 mit verschachtelten Ebenen je Frame
-- (contracts/save-format.md). frameLayers ist im LayerModel-Format
-- ({duration, layers = {{layerIndex, name, positions[375], visible}, ...}}).
-- Frames mit ungueltiger Ebenenzahl (0 oder > 3) oder Positions-Laenge != 375
-- werden verworfen (defensiv, wie schon createFramesTable).
function ImageStoreCodec.createFramesTableV11(name, frameLayers, tileCount)
    local framesData = {
        version = "1.1",
        name = name or "unnamed",
        gridWidth = 25,
        gridHeight = 15,
        tileCount = tonumber(tileCount) or 0,
        frames = {},
    }

    if type(frameLayers) == "table" then
        for i, entry in ipairs(frameLayers) do
            local layers = entry and entry.layers
            if type(layers) == "table" and #layers >= 1 and #layers <= LayerModel.MAX_LAYERS then
                local outLayers = {}
                local ok = true
                for j, layer in ipairs(layers) do
                    if type(layer.positions) ~= "table" or #layer.positions ~= LayerModel.POSITIONS then
                        ok = false
                        break
                    end
                    outLayers[j] = {
                        layerIndex = j - 1,
                        name = layer.name or ("Layer " .. j),
                        positions = layer.positions,
                        visible = layer.visible ~= false,
                    }
                end
                if ok then
                    framesData.frames[#framesData.frames + 1] = {
                        frameIndex = #framesData.frames,
                        duration = tonumber(entry.duration) or 100,
                        layers = outLayers,
                    }
                end
            end
        end
    end

    return framesData
end

return ImageStoreCodec