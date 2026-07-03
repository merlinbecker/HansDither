-- main.lua
import "CoreLibs/graphics"
import "CoreLibs/timer"
import "CoreLibs/ui"
import "CoreLibs/animation"
import "CoreLibs/crank"
import "CoreLibs/object" -- für playdate.graphics.image.new()

-- Load rooms
import "TitleRoom"
import "GameRoom"
import "LoadRoom"
import "TileRoom"
import "ZoomRoom"


local gfx = playdate.graphics
playdate.display.setScale(1)

-- Shared data table
local sharedData = {}

-- Current room
local currentRoom = nil

function switchRoom(newRoom)
    -- Transition to a new room
    currentRoom = newRoom
    -- Alle Räume nutzen natives 400x240-Rendering.
    playdate.display.setScale(1)
    playdate.inputHandlers.pop() -- Remove the current input handler
    playdate.inputHandlers.push(currentRoom.inputHandler()) -- Add the new input handler
    currentRoom:entered() -- Call the entered function of the new rooms
end

-- Initialize rooms with shared data and dependencies
-- Import SelectionRoom (neuer Auswahlscreen für v0.3.0)
import "Source/SelectionRoom"
import "Source/EditorRoom"

TitleRoom:init(switchRoom, SelectionRoom)
SelectionRoom:init(switchRoom, EditorRoom, TitleRoom)  -- EditorRoom als neuer Editor
EditorRoom:init(switchRoom, ZoomRoom, SelectionRoom)
GameRoom:init(switchRoom, LoadRoom)
LoadRoom:init(switchRoom, TileRoom, GameRoom)
TileRoom:init(switchRoom, ZoomRoom, LoadRoom)
ZoomRoom:init(switchRoom, PixelRoom, EditorRoom)  -- ZoomRoom verweist jetzt auf EditorRoom
PixelRoom:init(switchRoom, ZoomRoom)
--ZweiterRaum.init(sharedData, switchRoom, DritterRaum)
--DritterRaum.init(sharedData, switchRoom, StartRaum)

-- Set the initial room
currentRoom = TitleRoom
currentRoom:entered()
-- Set up input handlers
playdate.inputHandlers.push(currentRoom:inputHandler())

function playdate.update()
    -- Handle Crank input for EditorRoom
    if currentRoom == EditorRoom then
        EditorRoom:handleCrank()
    end
    
    -- Call the update function of the current room
    currentRoom:update()
end

-- DEBUG: Testfunktion für ImageStore - kann in der Simulator-Konsole aufgerufen werden
function testImageStore()
    import "Source/ImageStore"
    import "Source/ImageStoreCodec"
    
    -- Test 1: Index leeren/neu erstellen
    print("=== Test 1: Index ===")
    local index = ImageStore.getIndex()
    print("Index version:", index.version)
    print("Bilder:", #index.images)
    
    -- Test 2: Bild erstellen
    print("\n=== Test 2: Bild erstellen ===")
    local newId, err = ImageStore.createImage("Test Bild 1")
    if newId then
        print("Erstellt Bild mit ID:", newId)
    else
        print("Fehler:", err)
    end
    
    -- Test 3: Bild auflisten
    print("\n=== Test 3: Bilder auflisten ===")
    local images = ImageStore.listImages()
    for i, img in ipairs(images) do
        print(i, ":", img.id, "(", img.name, ")", "Frames:", img.frameCount)
    end
    
    -- Test 4: Bild kopieren
    print("\n=== Test 4: Bild kopieren ===")
    if newId then
        local copyId, err = ImageStore.copyImage(newId)
        if copyId then
            print("Kopiert zu ID:", copyId)
        else
            print("Fehler:", err)
        end
    end
    
    -- Test 5: Bild laden
    print("\n=== Test 5: Bild laden ===")
    if newId then
        local loadCo = ImageStoreCodec.newLoadOperation(newId)
        local success, result = coroutine.resume(loadCo)
        while coroutine.status(loadCo) == "suspended" do
            print("Phase:", coroutine.resume(loadCo))
        end
        
        if success and result then
            print("Geladen erfolgreich")
            print("ImageData:", result.id, "Frames:", #result.frames)
            print("TileCount:", result.imagetable and result.imagetable:getLength() or 0)
        else
            print("Ladefehler:", result)
        end
    end
    
    -- Test 6: Vorschaubild
    print("\n=== Test 6: Vorschaubild ===")
    if newId then
        local preview = ImageStore.getPreviewImage(newId)
        if preview then
            print("Preview geladen:", preview:getSize())
        else
            print("Preview nicht verfügbar")
        end
    end
    
    print("\n=== Tests abgeschlossen ===")
end

-- Speichert beim Beenden, wenn der EditorRoom oder ZoomRoom aktiv ist.
function playdate.gameWillTerminate()
    -- Prüfe EditorRoom
    if currentRoom == EditorRoom then
        local imageData = EditorRoom.getImageData()
        if imageData then
            import "Source/ImageStoreCodec"
            local saveCo = ImageStoreCodec.newSaveOperation(imageData)
            
            -- Synchron ausführen
            local success, err = coroutine.resume(saveCo)
            while coroutine.status(saveCo) == "suspended" do
                success, err = coroutine.resume(saveCo)
                if not success then break end
            end
            print("Terminate save:", success and "success" or err)
        end
    -- Prüfe ZoomRoom (sollte auch speichern)
    elseif currentRoom == ZoomRoom then
        -- TODO: T010 - ZoomRoom sollte seinen Zustand in EditorRoom committen
        print("Terminate: ZoomRoom active - TODO implement commit")
    -- Fallback für alten TileRoom
    elseif currentRoom == TileRoom and TileRoom and TileRoom.saveToFile then
        TileRoom:saveToFile()
    end
end