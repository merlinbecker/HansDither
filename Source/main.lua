-- main.lua — Einstiegspunkt der App.
--
-- Playdate-Grundlagen, die man hier sieht:
--  * import ist eine pdc-Compile-Direktive (wie #include, einmalig pro Datei);
--    sie darf NUR auf Dateiebene stehen, nie in Funktionen.
--  * Das SDK ruft playdate.update() ca. 30x/Sekunde auf — unsere einzige
--    "Game Loop". Wir delegieren an den jeweils aktiven Raum.
--  * playdate.inputHandlers ist ein Stack: push/pop tauscht die Button-
--    Callbacks aus, ohne dass Räume sich gegenseitig kennen müssen.

-- CoreLibs sind optionale SDK-Lua-Module; erst nach dem Import existieren
-- z.B. playdate.timer oder playdate.ui.gridview.
import "CoreLibs/graphics"
import "CoreLibs/timer"
import "CoreLibs/ui"
import "CoreLibs/animation"
import "CoreLibs/crank"
import "CoreLibs/object"

-- Räume und Module (Reihenfolge egal, import lädt jede Datei genau einmal;
-- weitere Module wie ImageStore/RoomOperation importieren die Räume selbst)
import "TitleRoom"
import "PixelRoom"
import "ZoomRoom"
import "SelectionRoom"
import "EditorRoom"
import "ImageStoreCodec"

-- Natives 400×240-Rendering ohne Skalierung
-- (SDK: playdate.display.setScale — 2/4/8 würden das Bild vergrößern)
playdate.display.setScale(1)

-- Der aktuell aktive Raum; jeder Raum implementiert das gleiche Interface:
-- init(...), entered(), update(), inputHandler()
local currentRoom = nil

-- Zentraler Raumwechsel: Input-Handler tauschen und den neuen Raum
-- über entered() initialisieren. Wird per Dependency Injection an alle
-- Räume gereicht — kein Raum importiert einen anderen direkt.
function switchRoom(newRoom)
    currentRoom = newRoom
    playdate.display.setScale(1)
    playdate.inputHandlers.pop()                             -- alten Handler entfernen
    playdate.inputHandlers.push(currentRoom:inputHandler())  -- neuen aktivieren
    currentRoom:entered()
end

-- Raum-Graph verdrahten (siehe arc42 Kap. 5):
-- TitleRoom → SelectionRoom → EditorRoom ⇄ ZoomRoom ⇄ PixelRoom
TitleRoom:init(switchRoom, SelectionRoom)
SelectionRoom:init(switchRoom, EditorRoom)
EditorRoom:init(switchRoom, ZoomRoom, SelectionRoom)
ZoomRoom:init(switchRoom, PixelRoom, EditorRoom)
PixelRoom:init(switchRoom, ZoomRoom)

-- Startraum aktivieren (wie switchRoom, nur ohne pop — der Stack ist noch leer)
currentRoom = TitleRoom
currentRoom:entered()
playdate.inputHandlers.push(currentRoom:inputHandler())

-- Die Game Loop des SDK: muss definiert sein, sonst zeigt der Simulator
-- nur einen schwarzen Bildschirm. Räume zeichnen selbst (kein Sprite-System).
function playdate.update()
    -- playdate.graphics.generateQRCode (Spec 004, SyncService) ist Timer-
    -- getrieben (siehe CoreLibs/qrcode.lua) und braucht daher eine laufende
    -- Timer-Pumpe, sonst feuert ihr Callback nie.
    playdate.timer.updateTimers()
    currentRoom:update()
end

-- SDK-Lifecycle-Hook: wird beim Beenden/Home-Button aufgerufen (Contract E-03,
-- Spec 001 FR-005). Zeit ist knapp, daher läuft die Save-Coroutine hier
-- synchron bis zum Ende durch statt frameweise wie im EditorRoom.
function playdate.gameWillTerminate()
    -- Aktive Zoomstufen committen zuerst ihren Zustand in Richtung EditorRoom
    if currentRoom == PixelRoom then
        PixelRoom:commitForTerminate()
        ZoomRoom:commitForTerminate()
    elseif currentRoom == ZoomRoom then
        ZoomRoom:commitForTerminate()
    end

    if currentRoom == EditorRoom or currentRoom == ZoomRoom or currentRoom == PixelRoom then
        local imageData = EditorRoom:getImageData()
        if imageData then
            local saveCo = ImageStoreCodec.newSaveOperation(imageData)
            local ok, err = true, nil
            while coroutine.status(saveCo) ~= "dead" do
                ok, err = coroutine.resume(saveCo)
                if not ok then break end
            end
            print("Terminate save:", ok and "success" or tostring(err))
        end
    end
end

-- Spec 006 R4/AD-031: SDK-Lifecycle-Hook, wird kurz vor dem Pausieren
-- aufgerufen — genau der laut SDK-Doku vorgesehene Zeitpunkt, um das
-- Menü-Bild zu aktualisieren. Läuft nur beim tatsächlichen Pausieren
-- (nicht pro Frame), kein Performance-Risiko.
function playdate.gameWillPause()
    if currentRoom == EditorRoom or currentRoom == ZoomRoom or currentRoom == PixelRoom then
        playdate.setMenuImage(EditorRoom:buildPauseMenuImage())
    else
        playdate.setMenuImage(nil)
    end
end
