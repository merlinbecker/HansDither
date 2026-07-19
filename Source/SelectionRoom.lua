-- SelectionRoom.lua — Auswahlscreen (Hub der App, Spec 002).
--
-- 3×3-Kreisraster aller gespeicherten Bilder + "Neu"-Eintrag; A öffnet den
-- Editor, das Systemmenü bietet new/copy/delete. SDK-Bausteine hier:
--  * playdate.ui.gridview  — Raster-Layout, Selektion und Scrolling
--  * playdate.keyboard     — Bildschirmtastatur für die Namenseingabe
--  * playdate.getSystemMenu() — die drei freien Slots im System-Menü
-- Ersetzt GameRoom und LoadRoom/LoadRoomGrid aus v0.2.

import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/object"
import "CoreLibs/keyboard"
import "ImageStore"
import "Bauchbinde"
import "SyncService"

local gfx = playdate.graphics

-- Namenszeile am unteren Rand (gleiches Banner wie die Frame-Anzeige im Editor)
local bauchbinde = Bauchbinde.new(gfx)

SelectionRoom = {}

-- Abhängigkeiten (werden über init() injiziert)
local switchRoomFunction
local editorRoom

-- Zustand
local entries = {}           -- Liste der Einträge (Bilder + Neu-Eintrag)
local gridview               -- playdate.ui.gridview
local selectedIndex = 1      -- Aktuell selektierter Eintrag (1-basiert)
local thumbCache = {}         -- Cache für maskierte Thumbnails: id -> image
local confirmingDelete = nil -- nil oder {id, name} für Bestätigungsdialog
local pendingAction = nil     -- Keyboard-Flow-Zustand
local pendingCommitName = nil -- bestätigter Name; verarbeitet erst, wenn das Keyboard ganz zu ist
local needsRedraw = true

-- Crank-Sync-Geste (Spec 004, FR-002): kumulierte Rotation bei selektiertem
-- Bild, ≥720° im Uhrzeigersinn löst SyncService:startSync() aus. Ersetzt den
-- ursprünglich vorgesehenen System-Menü-Eintrag (research.md R1: SDK erlaubt
-- max. 3 Einträge, hier bereits ausgeschöpft).
local crankAccumDegrees = 0

-- Zellgrößen für 3x3 Raster
local CELL_WIDTH = 133
local CELL_HEIGHT = 80
local CIRCLE_DIAMETER = 72

-- Initialisiert den Room
function SelectionRoom:init(switchRoom, editorRoomReference)
    switchRoomFunction = switchRoom
    editorRoom = editorRoomReference
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
    
    -- Zustand zurücksetzen (inkl. Keyboard-Reste, falls der Raum
    -- mitten in einem Eingabe-Flow verlassen wurde)
    confirmingDelete = nil
    pendingAction = nil
    pendingCommitName = nil
    crankAccumDegrees = 0
    playdate.keyboard.keyboardWillHideCallback = nil
    SelectionRoom:setSelectedIndex(1)
    
    needsRedraw = true
    print("Entered SelectionRoom")
end

-- Lädt die Einträge neu
function SelectionRoom:reloadEntries()
    -- Hole Bilder vom ImageStore
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
    
    -- drawCell-Callback: das Gridview ruft ihn als METHODE auf
    -- (self:drawCell(...)), der erste Parameter ist also das Gridview selbst.
    -- Ohne self-Parameter verschieben sich alle Argumente um eins!
    gridview.drawCell = function(self, section, row, column, selected, x, y, width, height)
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

    -- Alle Zellen hell; die Selektion invertiert NICHT mehr, sondern zeigt
    -- einen doppelten Ring um den Kreis plus die Namenszeile unten (update()).
    local centerX = x + width / 2
    local centerY = y + height / 2
    local radius = CIRCLE_DIAMETER / 2
    local circleX = centerX - radius
    local circleY = centerY - radius

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(x, y, width, height)

    -- Kreis: weiß gefüllt mit schwarzem Rand
    -- (SDK: fill/drawCircleAtPoint nehmen Mittelpunkt + Radius)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(centerX, centerY, radius)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawCircleAtPoint(centerX, centerY, radius)

    -- Zeichne Thumbnail oder Platzhalter
    if entry.kind == "image" then
        SelectionRoom:drawImageThumbnail(entry, circleX, circleY)
    else
        -- Neu-Eintrag: leerer Kreis mit +
        gfx.setColor(gfx.kColorBlack)
        gfx.drawText("+", centerX - 4, centerY - 6)
    end

    -- Selektion: doppelter Ring um den Kreis
    if selected then
        gfx.setColor(gfx.kColorBlack)
        gfx.drawCircleAtPoint(centerX, centerY, radius + 3)
        gfx.drawCircleAtPoint(centerX, centerY, radius + 4)
    end
end

-- Zeichnet das Thumbnail für ein Bild
function SelectionRoom:drawImageThumbnail(entry, circleX, circleY)
    local thumbImg = SelectionRoom:getThumbnail(entry.id)
    if thumbImg then
        -- Zeichne das Thumbnail zentriert in den Kreis.
        -- SDK: image:getSize() liefert Breite UND Höhe (getWidth/getHeight
        -- existieren für Images nicht!)
        local thumbW, thumbH = thumbImg:getSize()
        local thumbX = circleX + (CIRCLE_DIAMETER - thumbW) / 2
        local thumbY = circleY + (CIRCLE_DIAMETER - thumbH) / 2
        thumbImg:draw(thumbX, thumbY)
    else
        -- Platzhalter für fehlendes Preview
        gfx.setColor(gfx.kColorBlack)
        gfx.drawText("?", circleX + CIRCLE_DIAMETER/2 - 3, circleY + CIRCLE_DIAMETER/2 - 6)
    end
end

-- Hole oder erstelle Thumbnail aus Cache.
-- false ist der Negativ-Cache ("Preview fehlt"): ohne ihn würde jeder Redraw
-- erneut von der Platte lesen — bei offenem Keyboard wäre das jeder Frame.
function SelectionRoom:getThumbnail(id)
    if not id then return nil end

    local cached = thumbCache[id]
    if cached ~= nil then
        return cached or nil  -- false -> nil (Platzhalter zeichnen)
    end

    -- Preview von der Platte lesen (SDK: playdate.datastore.readImage via ImageStore)
    local preview = ImageStore.getPreviewImage(id)

    if not preview then
        thumbCache[id] = false
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
        -- Zeichne den Ausschnitt aus dem Preview (SDK: image:draw)
        preview:draw(-srcX, -srcY)
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

-- Zeichnet Keyboard-Overlay: Grid bleibt sichtbar, unten links die Eingabezeile
function SelectionRoom:drawKeyboardOverlay()
    if pendingAction ~= "keyboard" then return end

    local panelHeight = 24
    local panelY = 240 - panelHeight
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, panelY, 400, panelHeight)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(0, panelY, 399, panelY)
    gfx.drawText("Name: " .. (playdate.keyboard.text or ""), 8, panelY + 5)
end

-- Crank-Sync-Geste: misst kumulierte Rotation, solange ein Bild selektiert
-- ist und kein anderer modaler Zustand (Löschbestätigung, Keyboard,
-- laufender Sync, Pairing-Prompt) aktiv ist. WICHTIG: playdate.getCrankChange()
-- MUSS jeden Frame abgefragt werden, sonst summiert sich beim nächsten Aufruf
-- ein "Nachholwert" aus der Pause auf und könnte sofort ungewollt auslösen
-- (gleiches Prinzip wie playdate.getCrankTicks(4)-Drain in EditorRoom).
function SelectionRoom:handleCrank()
    local crankChange = playdate.getCrankChange()

    local entry = entries[selectedIndex]
    local canAccumulate = entry
        and entry.kind == "image"
        and not confirmingDelete
        and not pendingAction
        and not playdate.keyboard.isVisible()
        and not SyncService:isBusy()
        and not SyncService:isShowingQrOverlay()

    if not canAccumulate then
        crankAccumDegrees = 0
        return
    end

    -- Erste tatsächliche Kurbel-Bewegung bei Bildauswahl: Hinweis dauerhaft
    -- ausblenden (Nutzer-Feedback — kennt die Geste ab hier, siehe showCrankHint).
    if crankChange ~= 0 then
        SyncService:markCrankUsed()
    end

    -- Nur Uhrzeigersinn zählt; Gegendrehen baut Fortschritt wieder ab
    -- (kein hartes Zurücksetzen bei jedem kleinen Wackler zurück, siehe
    -- research.md R2 — sustained Gegendrehen läuft ohnehin gegen 0).
    crankAccumDegrees = math.max(0, crankAccumDegrees + crankChange)

    if crankAccumDegrees >= SyncService.SYNC_GESTURE_THRESHOLD_DEGREES then
        crankAccumDegrees = 0
        SyncService:startSync(entry.id)
        needsRedraw = true
    end
end

-- Hauptupdate-Funktion
function SelectionRoom:update()
    -- Laufende Sync-Coroutine antreiben (Login-Check oder Upload) UND
    -- automatisches Pairing-Polling prüfen (research.md R11) — muss vor
    -- allen frühen Returns laufen, sonst friert der Vorgang ein.
    SyncService:tick()

    SelectionRoom:handleCrank()

    -- Aufgeschobener Keyboard-Commit: erst ausführen, wenn das Keyboard
    -- vollständig zugeklappt ist und update/Input-Stack wieder uns gehören —
    -- erst dann ist ein Raumwechsel in den Editor gefahrlos möglich.
    if pendingCommitName and not playdate.keyboard.isVisible() then
        local name = pendingCommitName
        pendingCommitName = nil
        SelectionRoom:handleKeyboardCommit(name)
        return
    end

    -- Solange das Keyboard offen ist, jeden Frame neu zeichnen,
    -- damit der getippte Text und die Keyboard-Animation sichtbar sind
    if playdate.keyboard.isVisible() then
        needsRedraw = true
    end

    -- Während eines laufenden Syncs/Uploads oder mit sichtbarem Crank-
    -- Hinweis (animiertes crankIndicator-Icon) jeden Frame neu zeichnen,
    -- gleiches Prinzip wie operationRunning() in EditorRoom. Hinweis nur
    -- bis zur ersten tatsächlichen Kurbel-Nutzung (Nutzer-Feedback).
    local entryForSync = entries[selectedIndex]
    local showCrankHint = entryForSync
        and entryForSync.kind == "image"
        and not confirmingDelete
        and not pendingAction
        and not SyncService:isBusy()
        and not SyncService:isShowingQrOverlay()
        and not SyncService:hasUsedCrank()

    if needsRedraw or SyncService:isBusy() or SyncService:isShowingQrOverlay() or showCrankHint then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0, 0, 400, 240)

        -- Zeichne Gridview
        if gridview then
            gridview:drawInRect(0, 0, 400, 240)
        end

        -- Namenszeile unten links: Name des selektierten Bilds bzw. Neu-Eintrag.
        -- Entfällt, solange die Keyboard-Eingabezeile den unteren Rand belegt.
        if pendingAction ~= "keyboard" then
            local entry = entries[selectedIndex]
            if entry then
                local label = (entry.kind == "new") and "+ New Image" or (entry.name or entry.id)
                bauchbinde:drawBottom(label, "left", 400, 240)
            end
        end

        -- Zeichne Overlays
        SelectionRoom:drawConfirmDeleteDialog()
        SelectionRoom:drawKeyboardOverlay()

        -- Statuszeile + Crank-Hinweis: unten rechts gestapelt, direkt oberhalb
        -- des SDK-Crank-Indicators (der sich selbst unten rechts positioniert,
        -- siehe CoreLibs/ui/crankIndicator.lua) — damit "am unteren Bildrand"
        -- statt oben, und unabhängig von der Bauchbinde (die unten links den
        -- Bildnamen zeigt, siehe oben).
        -- Ausgeblendet, solange SyncService ein Vollbild-Overlay zeigt
        -- (loadingBar oder QR-Ergebnisscreen) — die decken den ganzen
        -- Bildschirm ab, eine Statuszeile darunter wäre ohnehin unsichtbar
        -- bzw. würde bei einer nicht-opaken Overlay-Ecke durchscheinen.
        local _, crankBubbleY = playdate.ui.crankIndicator:getBounds()
        if not SyncService:isBusy() and not SyncService:isShowingQrOverlay() then
            SelectionRoom:drawSyncStatus(crankBubbleY - 32)
        end

        -- Crank-Hinweis (FR-002a): Text + animiertes SDK-Icon, nur bei
        -- Bildauswahl und außerhalb anderer modaler Zustände
        if showCrankHint then
            local hint = playdate.isCrankDocked() and "unfold crank to sync" or "crank to sync"
            gfx.setColor(gfx.kColorBlack)
            gfx.drawTextAligned(hint, 396, crankBubbleY - 16, kTextAlignment.right)
            playdate.ui.crankIndicator:draw()
        end

        -- Sync-Overlay (loadingBar während Login-Check/Upload, Pairing-QR-Prompt)
        SyncService:draw()

        needsRedraw = false
    end
end

-- Statuszeile unten rechts (siehe Aufrufstelle oben): Verknüpfungsstatus
-- (FR-012) + kurzzeitige Meldungen
function SelectionRoom:drawSyncStatus(y)
    local msg = SyncService:getTransientStatusMessage()
    local text = msg or SyncService:getStatusText()
    gfx.setColor(gfx.kColorBlack)
    gfx.drawTextAligned(text, 396, y, kTextAlignment.right)
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

-- Blockiert Navigation/Auswahl, solange der Sync-Prompt (QR+PIN) sichtbar
-- ist oder eine Sync-Coroutine läuft — modal wie confirmingDelete/pendingAction.
function SelectionRoom:syncModalActive()
    return SyncService:isShowingQrOverlay() or SyncService:isBusy()
end

-- Behandelt A-Taste
function SelectionRoom:handleAButton()
    if SelectionRoom:syncModalActive() then return end

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
    if SyncService:dismissQrOverlay() then
        needsRedraw = true
        return
    end

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
    
    -- Der Auswahlscreen ist die Basis-Ebene: kein Rücksprung zum TitleRoom
    -- (Start → Auswahl → Editor, der Startscreen ist nur ein Splash)
end

-- Navigation: Hoch
function SelectionRoom:handleUpButton()
    if confirmingDelete or pendingAction or SelectionRoom:syncModalActive() then return end
    
    local newIndex = selectedIndex - 3
    if newIndex < 1 then
        newIndex = 1
    end
    
    SelectionRoom:setSelectedIndex(newIndex)
end

-- Navigation: Runter
function SelectionRoom:handleDownButton()
    if confirmingDelete or pendingAction or SelectionRoom:syncModalActive() then return end
    
    local newIndex = selectedIndex + 3
    if newIndex > #entries then
        newIndex = #entries
    end
    
    SelectionRoom:setSelectedIndex(newIndex)
end

-- Navigation: Links
function SelectionRoom:handleLeftButton()
    if confirmingDelete or pendingAction or SelectionRoom:syncModalActive() then return end
    
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
    if confirmingDelete or pendingAction or SelectionRoom:syncModalActive() then return end
    
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

    if newIndex ~= selectedIndex then
        crankAccumDegrees = 0
    end
    selectedIndex = newIndex

    -- Gridview-Selektion aktualisieren
    if gridview then
        local row = math.ceil(selectedIndex / 3)
        local col = ((selectedIndex - 1) % 3) + 1
        gridview:setSelection(1, row, col)

        -- Scrollen wenn nötig
        gridview:scrollToCell(1, row, col)
    end
    
    needsRedraw = true
end

-- Behandelt Löschaktion aus dem Menü
function SelectionRoom:handleDeleteImage()
    if confirmingDelete or pendingAction or SelectionRoom:syncModalActive() then return end
    
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
    
    local success = ImageStore.deleteImage(confirmingDelete.id)
    
    if success then
        -- Einträge neu laden
        SelectionRoom:reloadEntries()
        
        -- Gridview neu aufbauen
        SelectionRoom:buildGridview()
        
        -- Selektionsregel: gleiche Position, wenn möglich
        SelectionRoom:setSelectedIndex(math.min(selectedIndex, #entries))
        
        -- Thumbnail-Cache invalidieren
        thumbCache = {}
        
        -- Bestätigungsdialog schließen
        confirmingDelete = nil
        needsRedraw = true
    end
end

-- Behandelt Kopieraktion aus dem Menü
function SelectionRoom:handleCopyImage()
    if confirmingDelete or pendingAction or SelectionRoom:syncModalActive() then return end
    
    local entry = entries[selectedIndex]
    if not entry or entry.kind ~= "image" then return end
    
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
                SelectionRoom:setSelectedIndex(i)
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
    if confirmingDelete or pendingAction or SelectionRoom:syncModalActive() then return end
    
    -- Gleich wie A auf Neu-Eintrag
    SelectionRoom:openKeyboard()
end

-- Öffnet die Bildschirmtastatur.
-- Das SDK-Keyboard (CoreLibs/keyboard) übernimmt Input + eigenes Rendering
-- rechts im Bild; unser update() zeichnet währenddessen weiter das Raster.
-- Callbacks werden als Felder zugewiesen (es gibt KEINE set*Callback-Funktionen):
--   keyboardWillHideCallback(ok), textChangedCallback(), keyboard.text
function SelectionRoom:openKeyboard()
    pendingAction = "keyboard"

    -- OK-Taste liefert okPressed=true, Abbruch (B) false.
    -- WICHTIG: Der Callback feuert beim START der Zuklapp-Animation — das
    -- Keyboard hat playdate.update und den Input-Handler-Stack noch
    -- "ausgeliehen". Hier direkt den Raum zu wechseln korrumpiert den
    -- Handler-Stack (das spätere Pop des Keyboards entfernte sonst den
    -- Handler des neuen Raums). Deshalb nur den Namen vormerken; verarbeitet
    -- wird er in update(), sobald keyboard.isVisible() false ist
    -- (gleiches Muster wie der GameRoom in v0.2).
    playdate.keyboard.keyboardWillHideCallback = function(okPressed)
        -- Callback abhängen: er gehört nur zu dieser einen Eingabe und darf
        -- nicht in andere Räume hinein weiterleben
        playdate.keyboard.keyboardWillHideCallback = nil
        if okPressed then
            pendingCommitName = playdate.keyboard.text
        else
            pendingAction = nil
            needsRedraw = true
        end
    end

    -- Der Parameter von show() ist der vorausgefüllte Textinhalt, kein Prompt
    playdate.keyboard.show("")

    needsRedraw = true
end

-- Behandelt die Bestätigung der Tastatureingabe
function SelectionRoom:handleKeyboardCommit(text)
    if not text or text == "" then
        pendingAction = nil
        needsRedraw = true
        return
    end
    
    local newId, err = ImageStore.createImage(text)
    
    pendingAction = nil

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
                SelectionRoom:setSelectedIndex(i)
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
                        SelectionRoom:setSelectedIndex(i)
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