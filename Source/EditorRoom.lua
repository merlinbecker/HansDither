-- EditorRoom.lua
-- Neuer 16x16-Tile-Editor für Hans Dither v0.3.0
-- Ersetzt den alten TileRoom mit Pulp-Kopplung

import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/timer"
import "CoreLibs/object"

local gfx = playdate.graphics

EditorRoom = {}

-- Abhängigkeiten (werden über init() injiziert)
local switchRoomFunction
local zoomRoom
local selectionRoom

-- Zustand (gemäß data-model.md)
local imageData = nil           -- {id, name, imagetable, frames, hashIndex}
local currentFrame = 1          -- 1..#frames
local tilemap = nil             -- playdate.graphics.tilemap (25x15)
local cursor = {x = 1, y = 1}    -- 1..25 / 1..15 (tile-koordinaten)
local activeTile = nil          -- number/nil: Pipetten-Auswahl; nil = Toggle-Modus
local zoomTickAccu = 0          -- Tick-Akkumulator für B+Crank
local showGrid = true           -- Grid-Overlay an/aus
local savingOperation = nil    -- aktuelle Save-Operation
local loadingOperation = nil    -- aktuelle Load-Operation
local needsRedraw = true
local pendingImageId = nil      -- ID für asynchrones Laden

-- B-Throw Variablen
local zoomBTimer = nil
local zoomBHeld = false

-- Richtungshalten für Cursor-Bewegung
local moveTimer = nil
local moveDirection = nil
local moveRepeatDelay = 0.3     -- Sekunden bis zur Wiederholung
local moveRepeatInterval = 0.1 -- Sekunden zwischen Wiederholungen

-- Lädt die Bauchbinde für Frame-Anzeige
import "Source/Bauchbinde"
local bauchbinde = Bauchbinde.new(gfx)

-- Lädt den PencilCursor
import "Source/PencilCursor"

-- Initialisiert den Room
function EditorRoom:init(switchRoom, zoomRoomReference, selectionRoomReference)
    switchRoomFunction = switchRoom
    zoomRoom = zoomRoomReference
    selectionRoom = selectionRoomReference
    needsRedraw = true
    
    -- Initialisiere Bauchbinde
    bauchbinde:init()
    
    print("EditorRoom initialized")
end

-- Setzt die Bild-ID für den Editor
function EditorRoom:setImage(id)
    if not id then return end
    
    -- Speichere die ID für späteres Laden
    pendingImageId = id
    print("EditorRoom: Image ID set to:", id)
end

-- Wird aufgerufen, wenn der Room betreten wird
function EditorRoom:entered()
    print("Entered EditorRoom")
    
    -- Startet Load-Operation wenn eine Bild-ID gesetzt ist
    if pendingImageId then
        EditorRoom:startLoadOperation(pendingImageId)
        pendingImageId = nil
    else
        -- Kein Bild geladen - zurück zum Auswahlscreen
        if switchRoomFunction and selectionRoom then
            switchRoomFunction(selectionRoom)
        end
    end
end

-- Startet die Load-Operation
function EditorRoom:startLoadOperation(id)
    import "Source/ImageStoreCodec"
    import "Source/RoomOperation"
    import "Source/loadingBar"
    
    -- Erstelle LoadingBar
    local loadingBarInstance = loadingBar.new()
    
    -- Erstelle RoomOperation
    local operation = RoomOperation.new(loadingBarInstance)
    
    -- Starte Load-Operation
    local loadCo = ImageStoreCodec.newLoadOperation(id)
    
    operation:start("Lade Bild...", "Bitte warten", function()
        return loadCo
    end, function()
        -- Erfolg: imageData ist geladen
        local success, result = coroutine.resume(loadCo)
        
        while coroutine.status(loadCo) == "suspended" do
            local phase = coroutine.resume(loadCo)
            if phase then
                loadingBarInstance:setDetail(phase)
            end
            success, result = coroutine.resume(loadCo)
        end
        
        if success and result then
            EditorRoom:handleLoadSuccess(result)
        else
            EditorRoom:handleLoadError(result or "Unknown error")
        end
    end)
    
    loadingOperation = operation
end

-- Behandelt erfolgreichen Load
function EditorRoom:handleLoadSuccess(imageDataResult)
    imageData = imageDataResult
    currentFrame = 1
    activeTile = nil
    zoomTickAccu = 0
    needsRedraw = true
    
    -- Tilemap aufbauen
    EditorRoom:buildTilemap()
    
    -- Systemmenü aufbauen
    EditorRoom:buildSystemMenu()
    
    -- Bauchbinde aktualisieren
    EditorRoom:updateBauchbinde()
    
    -- PencilCursor Position setzen (wird beim Zeichnen verwendet)
    
    loadingOperation = nil
    print("EditorRoom: Load successful, image:", imageData.id, "frames:", #imageData.frames)
end

-- Behandelt Load-Fehler
function EditorRoom:handleLoadError(error)
    loadingOperation = nil
    print("EditorRoom: Load failed:", error)
    
    -- Zurück zum Auswahlscreen
    if switchRoomFunction and selectionRoom then
        switchRoomFunction(selectionRoom)
    end
end

-- Baut die Tilemap auf
function EditorRoom:buildTilemap()
    if not imageData or not imageData.imagetable then
        return
    end
    
    -- Erstelle neue Tilemap
    tilemap = gfx.tilemap.new()
    tilemap:setImageTable(imageData.imagetable)
    tilemap:setSize(25, 15)
    
    -- Setze die Tiles für den aktuellen Frame
    EditorRoom:updateTilemap()
end

-- Aktualisiert die Tilemap mit dem aktuellen Frame
function EditorRoom:updateTilemap()
    if not tilemap or not imageData or not imageData.frames then
        return
    end
    
    local frame = imageData.frames[currentFrame]
    if frame and #frame == 375 then
        tilemap:setTiles(frame, 25)
    end
end

-- Baut das Systemmenü auf
function EditorRoom:buildSystemMenu()
    playdate.getSystemMenu():removeAllMenuItems()
    
    local menu = playdate.getSystemMenu()
    
    -- "save + exit" Menüpunkt
    menu:addMenuItem("save + exit", function()
        EditorRoom:handleSaveAndExit()
    end)
    
    -- "delete frame" Menüpunkt (nur bei > 1 Frame)
    menu:addMenuItem("delete frame", function()
        EditorRoom:handleDeleteFrame()
    end)
    
    -- "show grid" Menüpunkt mit Checkmark
    menu:addCheckmarkMenuItem("show grid", showGrid, function(checked)
        showGrid = checked
        needsRedraw = true
    end)
end

-- Aktualisiert die Bauchbinde
function EditorRoom:updateBauchbinde()
    if not imageData or not imageData.frames then return end
    
    return string.format("Frame %d/%d", currentFrame, #imageData.frames)
end

-- Behandelt Save + Exit
function EditorRoom:handleSaveAndExit()
    if not imageData then return end
    
    import "Source/ImageStoreCodec"
    import "Source/RoomOperation"
    import "Source/loadingBar"
    
    -- Erstelle LoadingBar
    local loadingBarInstance = loadingBar.new()
    
    -- Erstelle RoomOperation
    local operation = RoomOperation.new(loadingBarInstance)
    savingOperation = operation
    
    -- Starte Save-Operation
    local saveCo = ImageStoreCodec.newSaveOperation(EditorRoom:getImageData())
    
    operation:start("Speichere Bild...", "Bitte warten", function()
        return saveCo
    end, function()
        -- Erfolg: zurück zum Auswahlscreen
        EditorRoom:handleSaveSuccess()
    end)
end

-- Behandelt erfolgreichen Save
function EditorRoom:handleSaveSuccess()
    savingOperation = nil
    
    -- Zurück zum Auswahlscreen
    if switchRoomFunction and selectionRoom then
        switchRoomFunction(selectionRoom)
    end
end

-- Behandelt Löschen eines Frames
function EditorRoom:handleDeleteFrame()
    if not imageData or not imageData.frames or #imageData.frames <= 1 then
        return  -- Kann letzten Frame nicht löschen
    end
    
    -- Frame löschen
    table.remove(imageData.frames, currentFrame)
    
    -- Anpassen currentFrame wenn nötig
    if currentFrame > #imageData.frames then
        currentFrame = #imageData.frames
    end
    
    -- Tilemap aktualisieren
    EditorRoom:updateTilemap()
    
    -- Bauchbinde aktualisieren
    EditorRoom:updateBauchbinde()
    
    needsRedraw = true
end

-- Gibt die aktuellen ImageData zurück (für Terminate-Hook)
function EditorRoom:getImageData()
    return imageData
end

-- Hauptupdate-Funktion
function EditorRoom:update()
    if needsRedraw then
        EditorRoom:draw()
        needsRedraw = false
    end
    
    -- LoadingBar-Updates während des Ladens
    if loadingOperation then
        loadingOperation:resume()
    end
    
    -- SavingBar-Updates während des Speicherns
    if savingOperation then
        savingOperation:resume()
    end
end

-- Zeichnet den Editor
function EditorRoom:draw()
    -- Hintergrund
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 0, 400, 240)
    
    -- Tilemap zeichnen
    if tilemap then
        tilemap:draw(0, 0)
    end
    
    -- Grid-Overlay zeichnen (wenn aktiviert)
    if showGrid then
        EditorRoom:drawGrid()
    end
    
    -- PencilCursor zeichnen (statische Methode)
    PencilCursor.draw((cursor.x - 1) * 16, (cursor.y - 1) * 16, 16, 16)
    
    -- Bauchbinde zeichnen
    local frameText = EditorRoom:updateBauchbinde()
    if bauchbinde and frameText then
        bauchbinde:drawBottom(frameText, "right", 400, 240)
    end
end

-- Zeichnet das Grid-Overlay
function EditorRoom:drawGrid()
    gfx.setColor(gfx.kColorBlack)
    
    -- Vertikale Linien
    for x = 1, 24 do
        local px = x * 16
        gfx.drawLine(px, 0, px, 240)
    end
    
    -- Horizontale Linien  
    for y = 1, 14 do
        local py = y * 16
        gfx.drawLine(0, py, 400, py)
    end
end

-- Eingabehandler
function EditorRoom:inputHandler()
    return {
        AButtonDown = function()
            EditorRoom:handleAButton()
        end,
        BButtonDown = function()
            EditorRoom:handleBButtonDown()
        end,
        BButtonUp = function()
            EditorRoom:handleBButtonUp()
        end,
        upButtonDown = function()
            EditorRoom:handleUpButton()
        end,
        downButtonDown = function()
            EditorRoom:handleDownButton()
        end,
        leftButtonDown = function()
            EditorRoom:handleLeftButton()
        end,
        rightButtonDown = function()
            EditorRoom:handleRightButton()
        end,
        upButtonUp = function()
            EditorRoom:handleButtonUp()
        end,
        downButtonUp = function()
            EditorRoom:handleButtonUp()
        end,
        leftButtonUp = function()
            EditorRoom:handleButtonUp()
        end,
        rightButtonUp = function()
            EditorRoom:handleButtonUp()
        end
    }
end

-- Behandelt A-Taste (Zeichnen/Toggle)
function EditorRoom:handleAButton()
    if savingOperation or loadingOperation then return end
    
    -- Berechne Zellenposition
    local cellIndex = (cursor.y - 1) * 25 + cursor.x
    
    if activeTile then
        -- Mit aktivem Tile: setzen oder zurück auf Weiß
        if imageData.frames and imageData.frames[currentFrame] then
            if imageData.frames[currentFrame][cellIndex] == activeTile then
                -- Rücksetzen auf Weiß (Index 1)
                imageData.frames[currentFrame][cellIndex] = 1
            else
                -- Setze aktives Tile
                imageData.frames[currentFrame][cellIndex] = activeTile
            end
        end
    else
        -- Ohne aktives Tile: Toggle Weiß(1) ↔ Schwarz(2)
        if imageData.frames and imageData.frames[currentFrame] then
            if imageData.frames[currentFrame][cellIndex] == 1 then
                imageData.frames[currentFrame][cellIndex] = 2  -- Schwarz
            else
                imageData.frames[currentFrame][cellIndex] = 1  -- Weiß
            end
        end
    end
    
    -- Tilemap aktualisieren
    EditorRoom:updateTilemap()
    needsRedraw = true
end

-- Behandelt B-Taste (Pipette oder Zoom-Trigger)
function EditorRoom:handleBButtonDown()
    if savingOperation or loadingOperation then return end
    
    -- Starte Timer für Richtungshalten
    if moveTimer then
        moveTimer:remove()
        moveTimer = nil
    end
    
    -- Starte Timer für B-Throw (Zoom-Trigger)
    zoomBTimer = playdate.timer.new(moveRepeatDelay * 1000, function()
        zoomBHeld = true
    end)
end

function EditorRoom:handleBButtonUp()
    if zoomBTimer then
        zoomBTimer:remove()
        zoomBTimer = nil
    end
    
    if not zoomBHeld then
        -- Kurzes B: Pipette
        EditorRoom:handlePipette()
    end
    
    zoomBHeld = false
end

-- Behandelt Pipette (B kurz)
function EditorRoom:handlePipette()
    if savingOperation or loadingOperation then return end
    
    -- Berechne Zellenposition
    local cellIndex = (cursor.y - 1) * 25 + cursor.x
    
    if imageData.frames and imageData.frames[currentFrame] then
        local tileIndex = imageData.frames[currentFrame][cellIndex]
        if tileIndex == 1 then
            -- Abwahl (Weiß)
            activeTile = nil
        else
            -- Pipette: aktives Tile setzen
            activeTile = tileIndex
        end
    end
    
    print("Pipette: activeTile =", activeTile or "nil")
    needsRedraw = true
end

-- Behandelt Richtungstasten
function EditorRoom:handleUpButton()
    if savingOperation or loadingOperation then return end
    EditorRoom:moveCursor(0, -1)
end

function EditorRoom:handleDownButton()
    if savingOperation or loadingOperation then return end
    EditorRoom:moveCursor(0, 1)
end

function EditorRoom:handleLeftButton()
    if savingOperation or loadingOperation then return end
    EditorRoom:moveCursor(-1, 0)
end

function EditorRoom:handleRightButton()
    if savingOperation or loadingOperation then return end
    EditorRoom:moveCursor(1, 0)
end

function EditorRoom:handleButtonUp()
    if moveTimer then
        moveTimer:remove()
        moveTimer = nil
    end
    moveDirection = nil
end

-- Bewegt den Cursor
function EditorRoom:moveCursor(dx, dy)
    local newX = cursor.x + dx
    local newY = cursor.y + dy
    
    -- Randbehandlung
    if newX < 1 then newX = 1 end
    if newX > 25 then newX = 25 end
    if newY < 1 then newY = 1 end
    if newY > 15 then newY = 15 end
    
    if newX ~= cursor.x or newY ~= cursor.y then
        cursor.x = newX
        cursor.y = newY
        
        -- PencilCursor aktualisieren (wird direkt beim Zeichnen verwendet)
        
        -- Richtungshalten einrichten
        moveDirection = {dx, dy}
        if not moveTimer then
            moveTimer = playdate.timer.new(moveRepeatDelay * 1000, function()
                EditorRoom:moveCursor(moveDirection[1], moveDirection[2])
                -- Wiederhole alle moveRepeatInterval
                moveTimer = playdate.timer.new(moveRepeatInterval * 1000, function()
                    EditorRoom:moveCursor(moveDirection[1], moveDirection[2])
                end)
            end)
        end
        
        needsRedraw = true
    end
end

-- Behandelt Crank-Eingaben (wird separatgerufen)
function EditorRoom:handleCrank()
    if savingOperation or loadingOperation then return end
    
    -- Prüfe ob B gehalten wird (für Zoom)
    if zoomBHeld then
        -- B+Crank: Zoom-Trigger
        local crankChange = playdate.getCrankTicks(4)
        if crankChange > 0 then
            -- Vorwärts: in den ZoomRoom
            EditorRoom:zoomIn()
        elseif crankChange < 0 then
            -- Rückwärts: aus dem ZoomRoom (falls wir dort sind)
            -- Da wir im EditorRoom sind, gibt es nichts zu tun
        end
        return
    end
    
    -- Normale Crank-Nutzung (ohne B): Frame-Wechsel
    local crankChange = playdate.getCrankTicks(4)
    if crankChange == 0 then return end
    
    -- Verarbeite jeden Tick einzeln
    for i = 1, math.abs(crankChange) do
        if crankChange > 0 then
            EditorRoom:tickForward()
        else
            EditorRoom:tickBackward()
        end
    end
end

-- Frame vorwärts (Crank vorwärts)
function EditorRoom:tickForward()
    if not imageData or not imageData.frames then return end
    
    if currentFrame < #imageData.frames then
        -- Wechsle zum nächsten Frame
        currentFrame = currentFrame + 1
    elseif #imageData.frames < 12 then
        -- Erstelle neuen Frame als Kopie des aktuellen
        local newFrame = {}
        for i, tileIndex in ipairs(imageData.frames[currentFrame]) do
            newFrame[i] = tileIndex
        end
        table.insert(imageData.frames, newFrame)
        currentFrame = currentFrame + 1
    else
        -- Rotation: zurück zum ersten Frame
        currentFrame = 1
    end
    
    -- Tilemap aktualisieren
    EditorRoom:updateTilemap()
    needsRedraw = true
end

-- Frame rückwärts (Crank rückwärts)
function EditorRoom:tickBackward()
    if not imageData or not imageData.frames then return end
    
    if currentFrame > 1 then
        -- Wechsle zum vorherigen Frame
        currentFrame = currentFrame - 1
    else
        -- Rotation: zum letzten Frame
        currentFrame = #imageData.frames
    end
    
    -- Tilemap aktualisieren
    EditorRoom:updateTilemap()
    needsRedraw = true
end

-- Zoom in den ZoomRoom
function EditorRoom:zoomIn()
    if not zoomRoom then return end
    
    -- TODO: Kontext für ZoomRoom vorbereiten
    print("EditorRoom: Zooming in...")
    
    -- Für jetzt: direkt wechseln (ohne Kontext)
    if switchRoomFunction then
        switchRoomFunction(zoomRoom)
    end
end

return EditorRoom