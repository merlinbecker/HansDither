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
TitleRoom:init(switchRoom, GameRoom)
GameRoom:init(switchRoom, LoadRoom)
LoadRoom:init(switchRoom, TileRoom, GameRoom)
TileRoom:init(switchRoom, ZoomRoom, LoadRoom)
ZoomRoom:init(switchRoom, PixelRoom, TileRoom)
PixelRoom:init(switchRoom, ZoomRoom)
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