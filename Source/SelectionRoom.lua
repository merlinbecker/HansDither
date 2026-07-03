-- SelectionRoom.lua
-- Neuer Auswahlscreen für Hans Dither v0.3.0
-- Ersetzt GameRoom und LoadRoom/LoadRoomGrid

import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/object"

local gfx = playdate.graphics

SelectionRoom = {}

-- Abhängigkeiten (werden über init() injiziert)
local switchRoomFunction
local editorRoom
local titleRoom

-- Zustand
local entries = {}           -- Liste der Einträge (Bilder + Neu-Eintrag)
local gridview               -- playdate.ui.gridview
local selectedIndex = 1      -- Aktuell selektierter Eintrag (1-basiert)
local thumbCache = {}         -- Cache für maskierte Thumbnails: id -> image
local confirmingDelete = nil -- nil oder {id, name} für Bestätigungsdialog
local pendingAction = nil     -- Keyboard-Flow-Zustand
local needsRedraw = true

-- Zellgrößen für 3x3 Raster
local CELL_WIDTH = 133
local CELL_HEIGHT = 80
local CIRCLE_DIAMETER = 72

-- Initialisiert den Room
function SelectionRoom:init(switchRoom, editorRoomReference, titleRoomReference)
    switchRoomFunction = switchRoom
    editorRoom = editorRoomReference
    titleRoom = titleRoomReference
    needsRedraw = true
    print("SelectionRoom initialized")
end

-- Wird aufgerufen, wenn der Room betreten wird
function SelectionRoom:entered()
    -- Einträge neu laden
    SelectionRoom:reloadEntries()
    
    -- Thumbnail-Cache leeren
    thumbCache = {}
    
    -- Gridview aufbauen
    SelectionRoom:buildGridview()
    
    -- Systemmenü aufbauen
    SelectionRoom:buildSystemMenu()
    
    -- Zustand zurücksetzen
    confirmingDelete = nil
    pendingAction = nil
    selectedIndex = 1
    
    needsRedraw = true
    print("Entered SelectionRoom")
end

-- Lädt die Einträge neu
function SelectionRoom:reloadEntries()
    -- Hole Bilder vom ImageStore
    import "Source/ImageStore"
    local images = ImageStore.listImages() or {}
    
    -- Erstelle Einträge-Array
    entries = {}
    for i, img in ipairs(images) do
        table.insert(entries, {
            kind = "image",
            id = img.id,
            name = img.name,
            frameCount = img.frameCount,
            lastEdited = img.lastEdited
        })
    end
    
    -- Füge Neu-Eintrag hinzu
    table.insert(entries, {
        kind = "new"
    })
    
    print("Loaded " .. #entries .. " entries")
end

-- Erstellt das Gridview
function SelectionRoom:buildGridview()
    local numColumns = 3
    local numRows = math.ceil(#entries / numColumns)
    
    gridview = playdate.ui.gridview.new(CELL_WIDTH, CELL_HEIGHT)
    gridview:setNumberOfColumns(numColumns)
    gridview:setNumberOfRows(numRows)
    gridview.changeRowOnColumnWrap = false
    
    -- Setze die drawCell-Funktion
    gridview.drawCell = function(section, row, column, selected, x, y, width, height)
        SelectionRoom:drawCell(section, row, column, selected, x, y, width, height)
    end
end

-- Baut das Systemmenü auf
function SelectionRoom:buildSystemMenu()
    -- Menü entfernen und neu aufbauen
    playdate.getSystemMenu():removeAllMenuItems()
    
    -- Drei Menüeinträge
    local menu = playdate.getSystemMenu()
    
    -- "new image" Menüpunkt
    menu:addMenuItem("new image", function()
        SelectionRoom:handleNewImage()
    end)
    
    -- "copy image" Menüpunkt (nur wirksam bei Bildauswahl)
    menu:addMenuItem("copy image", function()
        SelectionRoom:handleCopyImage()
    end)
    
    -- "delete image" Menüpunkt (nur wirksam bei Bildauswahl)
    menu:addMenuItem("delete image", function()
        SelectionRoom:handleDeleteImage()
    end)
end

-- Zeichnet eine Zelle im Gridview
function SelectionRoom:drawCell(section, row, column, selected, x, y, width, height)
    -- Berechne den Eintrags-Index
    local index = (row - 1) * 3 + column
    if index < 1 or index > #entries then
        return
    end
    
    local entry = entries[index]
    
    -- Zeichne Hintergrund
    if selected then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(x, y, width, height)
        gfx.setColor(gfx.kColorBlack)
    else
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(x, y, width, height)
        gfx.setColor(gfx.kColorWhite)
    end
    
    -- Zeichne Kreis in der Zelle
    local circleX = x + (width - CIRCLE_DIAMETER) / 2
    local circleY = y + (height - CIRCLE_DIAMETER) / 2
    
    -- Kreis Hintergrund
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(circleX + CIRCLE_DIAMETER/2, circleY + CIRCLE_DIAMETER/2, CIRCLE_DIAMETER/2)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawCircleAtPoint(circleX + CIRCLE_DIAMETER/2, circleY + CIRCLE_DIAMETER/2, CIRCLE_DIAMETER/2)
    
    -- Zeichne Thumbnail oder Platzhalter
    if entry.kind == "image" then
        SelectionRoom:drawImageThumbnail(entry, circleX, circleY)
    else
        -- Neu-Eintrag: leerer Kreis mit + 
        gfx.setColor(gfx.kColorBlack)
        gfx.drawText("+", circleX + CIRCLE_DIAMETER/2 - 4, circleY + CIRCLE_DIAMETER/2 - 6)
    end
    
    -- Selektionsring
    if selected then
        gfx.setColor(gfx.kColorWhite)
        gfx.drawCircleAtPoint(circleX + CIRCLE_DIAMETER/2, circleY + CIRCLE_DIAMETER/2, CIRCLE_DIAMETER/2 + 3)
    end
end

-- Zeichnet das Thumbnail für ein Bild
function SelectionRoom:drawImageThumbnail(entry, circleX, circleY)
    local thumbImg = SelectionRoom:getThumbnail(entry.id)
    if thumbImg then
        -- Zeichne das Thumbnail in den Kreis
        local thumbX = circleX + (CIRCLE_DIAMETER - thumbImg:getSize()) / 2
        local thumbY = circleY + (CIRCLE_DIAMETER - thumbImg:getHeight()) / 2
        gfx.drawImage(thumbImg, thumbX, thumbY)
    else
        -- Platzhalter für fehlendes Preview
        gfx.setColor(gfx.kColorBlack)
        gfx.drawText("?", circleX + CIRCLE_DIAMETER/2 - 3, circleY + CIRCLE_DIAMETER/2 - 6)
    end
end

-- Hole oder erstelle Thumbnail aus Cache
function SelectionRoom:getThumbnail(id)
    if not id then return nil end
    
    -- Prüfe Cache
    if thumbCache[id] then
        return thumbCache[id]
    end
    
    -- Versuche Preview-Bild zu laden
    import "Source/ImageStore"
    local preview = ImageStore.getPreviewImage(id)
    
    if not preview then
        -- Kein Preview verfügbar, erstellt Platzhalter
        thumbCache[id] = nil
        return nil
    end
    
    -- Erstelle kreisförmig maskiertes Thumbnail
    local thumb = SelectionRoom:createCircularThumbnail(preview)
    thumbCache[id] = thumb
    return thumb
end

-- Erstellt ein kreisförmig maskiertes Thumbnail aus einem Preview-Bild
function SelectionRoom:createCircularThumbnail(preview)
    -- Erstelle ein kreisförmiges Maskenbild
    local mask = gfx.image.new(CIRCLE_DIAMETER, CIRCLE_DIAMETER, gfx.kColorClear)
    gfx.pushContext(mask)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(CIRCLE_DIAMETER/2, CIRCLE_DIAMETER/2, CIRCLE_DIAMETER/2)
    gfx.popContext()
    
    -- Extrahieren den zentralen Ausschnitt aus dem Preview (400x240 -> 72x72)
    local previewWidth, previewHeight = preview:getSize()
    local srcX = (previewWidth - CIRCLE_DIAMETER) / 2
    local srcY = (previewHeight - CIRCLE_DIAMETER) / 2
    
    -- Erstelle Thumbnail-Image
    local thumb = gfx.image.new(CIRCLE_DIAMETER, CIRCLE_DIAMETER, gfx.kColorClear)
    gfx.pushContext(thumb)
        -- Zeichne den Ausschnitt aus dem Preview
        gfx.drawImage(preview, -srcX, -srcY)
    gfx.popContext()
    
    -- Maskierung anwenden
    thumb:setMaskImage(mask)
    
    return thumb
end

-- Zeichnet den Bestätigungsdialog
function SelectionRoom:drawConfirmDeleteDialog()
    if not confirmingDelete then return end
    
    local dialogWidth = 200
    local dialogHeight = 80
    local dialogX = (400 - dialogWidth) / 2
    local dialogY = (240 - dialogHeight) / 2
    
    -- Hintergrund
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(dialogX, dialogY, dialogWidth, dialogHeight)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(dialogX, dialogY, dialogWidth, dialogHeight)
    
    -- Text
    local name = confirmingDelete.name or "this image"
    gfx.drawText("Delete " .. name .. "?", dialogX + 10, dialogY + 10)
    gfx.drawText("(A) delete", dialogX + 10, dialogY + 30)
    gfx.drawText("(B) cancel", dialogX + 10, dialogY + 50)
end

-- Zeichnet Keyboard-Overlay
function SelectionRoom:drawKeyboardOverlay()
    if pendingAction ~= "keyboard" then return end
    
    -- Abdunklung
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, 400, 240)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawText("Enter image name:", 10, 10)
end

-- Hauptupdate-Funktion
function SelectionRoom:update()
    if needsRedraw then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0, 0, 400, 240)
        
        -- Zeichne Gridview
        if gridview then
            gridview:drawInRect(0, 0, 400, 240)
        end
        
        -- Zeichne Overlays
        SelectionRoom:drawConfirmDeleteDialog()
        SelectionRoom:drawKeyboardOverlay()
        
        needsRedraw = false
    end
end

-- Eingabehandler
function SelectionRoom:inputHandler()
    return {
        AButtonDown = function()
            SelectionRoom:handleAButton()
        end,
        BButtonDown = function()
            SelectionRoom:handleBButton()
        end,
        upButtonDown = function()
            SelectionRoom:handleUpButton()
        end,
        downButtonDown = function()
            SelectionRoom:handleDownButton()
        end,
        leftButtonDown = function()
            SelectionRoom:handleLeftButton()
        end,
        rightButtonDown = function()
            SelectionRoom:handleRightButton()
        end
    }
end

-- Behandelt A-Taste
function SelectionRoom:handleAButton()
    if confirmingDelete then
        -- Bestätigung des Löschens
        SelectionRoom:confirmDelete()
        return
    end
    
    if pendingAction then
        -- Keyboard-Flow wird von SDK-Keyboard selbst behandelt
        return
    end
    
    local entry = entries[selectedIndex]
    if not entry then return end
    
    if entry.kind == "new" then
        -- Neu-Eintrag: Keyboard öffnen
        SelectionRoom:openKeyboard()
    else
        -- Bild auswählen: Editor öffnen (Stub bis Spec 003)
        SelectionRoom:openEditor(entry.id)
    end
end

-- Behandelt B-Taste
function SelectionRoom:handleBButton()
    if confirmingDelete then
        -- Abbrechen des Löschens
        confirmingDelete = nil
        needsRedraw = true
        return
    end
    
    if pendingAction then
        -- Keyboard abbrechen
        pendingAction = nil
        playdate.keyboard.hide()
        needsRedraw = true
        return
    end
    
    -- Zurück zum TitleRoom
    if switchRoomFunction and titleRoom then
        switchRoomFunction(titleRoom)
    end
end

-- Navigation: Hoch
function SelectionRoom:handleUpButton()
    if confirmingDelete or pendingAction then return end
    
    local newIndex = selectedIndex - 3
    if newIndex < 1 then
        newIndex = 1
    end
    
    SelectionRoom:setSelectedIndex(newIndex)
end

-- Navigation: Runter
function SelectionRoom:handleDownButton()
    if confirmingDelete or pendingAction then return end
    
    local newIndex = selectedIndex + 3
    if newIndex > #entries then
        newIndex = #entries
    end
    
    SelectionRoom:setSelectedIndex(newIndex)
end

-- Navigation: Links
function SelectionRoom:handleLeftButton()
    if confirmingDelete or pendingAction then return end
    
    local row = math.ceil(selectedIndex / 3) - 1  -- 0-basierte Zeile
    local col = ((selectedIndex - 1) % 3) + 1      -- 1-basierte Spalte
    
    local newCol = col - 1
    if newCol < 1 then
        newCol = 1
    end
    
    local newIndex = row * 3 + newCol
    if newIndex > #entries then
        newIndex = #entries
    end
    
    SelectionRoom:setSelectedIndex(newIndex)
end

-- Navigation: Rechts
function SelectionRoom:handleRightButton()
    if confirmingDelete or pendingAction then return end
    
    local row = math.ceil(selectedIndex / 3) - 1  -- 0-basierte Zeile
    local col = ((selectedIndex - 1) % 3) + 1      -- 1-basierte Spalte
    
    local newCol = col + 1
    local maxCol = 3
    if newCol > maxCol then
        newCol = maxCol
    end
    
    local newIndex = row * 3 + newCol
    if newIndex > #entries then
        newIndex = #entries
    end
    
    SelectionRoom:setSelectedIndex(newIndex)
end

-- Setzt den selektierten Index und aktualisiert Gridview
function SelectionRoom:setSelectedIndex(newIndex)
    if newIndex < 1 or newIndex > #entries then return end
    
    selectedIndex = newIndex
    
    -- Gridview-Selektion aktualisieren
    if gridview then
        local row = math.ceil(selectedIndex / 3)
        local col = ((selectedIndex - 1) % 3) + 1
        gridview:setSelectedCell(row, col)
        
        -- Scrollen wenn nötig
        gridview:scrollToCell(row, col)
    end
    
    needsRedraw = true
end

-- Behandelt Löschaktion aus dem Menü
function SelectionRoom:handleDeleteImage()
    if confirmingDelete or pendingAction then return end
    
    local entry = entries[selectedIndex]
    if not entry or entry.kind ~= "image" then return end
    
    -- Bestätigungsdialog öffnen
    confirmingDelete = {
        id = entry.id,
        name = entry.name or "this image"
    }
    needsRedraw = true
end

-- Bestätigt das Löschen
function SelectionRoom:confirmDelete()
    if not confirmingDelete then return end
    
    import "Source/ImageStore"
    local success = ImageStore.deleteImage(confirmingDelete.id)
    
    if success then
        -- Einträge neu laden
        SelectionRoom:reloadEntries()
        
        -- Gridview neu aufbauen
        SelectionRoom:buildGridview()
        
        -- Selektionsregel: gleiche Position, wenn möglich
        if selectedIndex > #entries then
            selectedIndex = #entries
        end
        
        -- Thumbnail-Cache invalidieren
        thumbCache = {}
        
        -- Bestätigungsdialog schließen
        confirmingDelete = nil
        needsRedraw = true
    end
end

-- Behandelt Kopieraktion aus dem Menü
function SelectionRoom:handleCopyImage()
    if confirmingDelete or pendingAction then return end
    
    local entry = entries[selectedIndex]
    if not entry or entry.kind ~= "image" then return end
    
    import "Source/ImageStore"
    local newId, err = ImageStore.copyImage(entry.id)
    
    if newId then
        -- Einträge neu laden
        SelectionRoom:reloadEntries()
        
        -- Gridview neu aufbauen
        SelectionRoom:buildGridview()
        
        -- Thumbnail-Cache invalidieren
        thumbCache = {}
        
        -- Selektiere die Kopie
        for i, e in ipairs(entries) do
            if e.kind == "image" and e.id == newId then
                selectedIndex = i
                break
            end
        end
        
        needsRedraw = true
    else
        print("Copy failed:", err)
    end
end

-- Behandelt neue Bild-Aktion aus dem Menü
function SelectionRoom:handleNewImage()
    if confirmingDelete or pendingAction then return end
    
    -- Gleich wie A auf Neu-Eintrag
    SelectionRoom:openKeyboard()
end

-- Öffnet die Bildschirmtastatur
function SelectionRoom:openKeyboard()
    pendingAction = "keyboard"
    
    -- Passe an: v0.3.0 Namenseingabe
    playdate.keyboard.show("Enter image name")
    
    -- Callback für Keyboard-Eingabe
    playdate.keyboard.setText("")
    playdate.keyboard.setTextChangeCallback(function(text)
        -- Hier könnte man Validierung machen, aber wir warten auf Bestätigung
    end)
    
    playdate.keyboard.setCommitCallback(function(text)
        SelectionRoom:handleKeyboardCommit(text)
    end)
    
    playdate.keyboard.setCancelCallback(function()
        pendingAction = nil
        needsRedraw = true
    end)
    
    needsRedraw = true
end

-- Behandelt die Bestätigung der Tastatureingabe
function SelectionRoom:handleKeyboardCommit(text)
    if not text or text == "" then
        pendingAction = nil
        needsRedraw = true
        return
    end
    
    import "Source/ImageStore"
    local newId, err = ImageStore.createImage(text)
    
    pendingAction = nil
    playdate.keyboard.hide()
    
    if newId then
        -- Einträge neu laden
        SelectionRoom:reloadEntries()
        
        -- Gridview neu aufbauen
        SelectionRoom:buildGridview()
        
        -- Thumbnail-Cache invalidieren
        thumbCache = {}
        
        -- Selektiere das neue Bild
        for i, e in ipairs(entries) do
            if e.kind == "image" and e.id == newId then
                selectedIndex = i
                break
            end
        end
        
        -- Editor öffnen (Stub bis Spec 003)
        SelectionRoom:openEditor(newId)
    else
        -- Bei Namenskollision oder Fehler: Versuche mit Suffix
        if err == "name-taken" then
            local newName = text .. "-1"
            local suffix = 1
            while ImageStore.isIdTaken(ImageStore.sanitizeName(newName)) do
                suffix = suffix + 1
                newName = text .. "-" .. suffix
            end
            
            -- Versuche nochmal
            local retryId = ImageStore.createImage(newName)
            if retryId then
                SelectionRoom:reloadEntries()
                SelectionRoom:buildGridview()
                thumbCache = {}
                
                for i, e in ipairs(entries) do
                    if e.kind == "image" and e.id == retryId then
                        selectedIndex = i
                        break
                    end
                end
                
                SelectionRoom:openEditor(retryId)
            end
        end
        
        needsRedraw = true
    end
end

-- Öffnet den Editor (Stub bis Spec 003)
function SelectionRoom:openEditor(id)
    print("Opening editor with image id:", id)
    
    -- Stub: Log und Rückkehr (bis Spec 003 den Editor implementiert)
    if editorRoom and editorRoom.setImage then
        editorRoom:setImage(id)
        switchRoomFunction(editorRoom)
    else
        print("Editor not available, returning to selection")
        needsRedraw = true
    end
end

return SelectionRoom