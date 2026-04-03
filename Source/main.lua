-- main.lua
import "CoreLibs/graphics"
import "CoreLibs/timer"
import "CoreLibs/ui"
import "CoreLibs/animation"
import "CoreLibs/crank"
import "CoreLibs/object" -- für playdate.graphics.image.new()

-- Load rooms
import "TitleRoom"
import "LoadRoom"
import "TileRoom"


local gfx = playdate.graphics
-- Playdate Skalierung: 2 -> logische Größe 200x120 (Pulp-Auflösung)
playdate.display.setScale(2)


--import "Source/ZweiterRaum"
--import "DritterRaum"

-- Shared data table
local sharedData = {}

-- Current room
local currentRoom = nil

function switchRoom(newRoom)
    -- Transition to a new room
    currentRoom = newRoom
    playdate.inputHandlers.pop() -- Remove the current input handler
    playdate.inputHandlers.push(currentRoom.inputHandler()) -- Add the new input handler
    currentRoom:entered() -- Call the entered function of the new rooms
end

-- Initialize rooms with shared data and dependencies
TitleRoom:init(switchRoom,LoadRoom)
LoadRoom:init(switchRoom,TileRoom)
TileRoom:init(switchRoom, PixelRoom, LoadRoom)
PixelRoom:init(switchRoom,TileRoom)
--ZweiterRaum.init(sharedData, switchRoom, DritterRaum)
--DritterRaum.init(sharedData, switchRoom, StartRaum)

-- Set the initial room
currentRoom = TitleRoom
currentRoom:entered()
-- Set up input handlers
playdate.inputHandlers.push(currentRoom:inputHandler())

function playdate.update()
    -- Call the update function of the current room
    currentRoom:update()
end

-- Speichert beim Beenden, wenn der TileRoom aktiv ist.
function playdate.gameWillTerminate()
    if currentRoom == TileRoom and TileRoom and TileRoom.saveToFile then
        TileRoom:saveToFile()
    end
end

-- Example transitions (to be implemented in room-specific input handlers)
-- switchRoom(ZweiterRaum)
-- switchRoom(DritterRaum)