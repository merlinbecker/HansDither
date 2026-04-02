-- LoadRoom.lua
-- LoadRoom soll beim Laden der einzlenen Projekte helfen



import "CoreLibs/graphics"
local gfx = playdate.graphics

LoadRoom = {}

local switchRoomFunction
local nextRoom
local needsRedraw

print("LoadRoom loaded")
-- Initialize the room with shared data and dependencies
function LoadRoom:init(switchRoom,nextRoomReference)
    switchRoomFunction = switchRoom
    nextRoom = nextRoomReference
    needsRedraw = true
end

-- Update logic for StartRaum
function LoadRoom:update()
    if needsRedraw then
        -- Example: Draw the title screen here
        gfx.clear(gfx.kColorWhite)
        gfx.drawText("LoadRoom", 0,0)
        print("Drawing LoadRoom")
        needsRedraw = false
    end
end

function LoadRoom:entered()
    needsRedraw = true
    print("Entered LoadRoom")
end

-- Input handler for StartRaum
function LoadRoom:inputHandler()
    return {
        AButtonDown = function()
            -- Transition to the next room
            if switchRoomFunction and nextRoom then
                switchRoomFunction(nextRoom)
            else
                print("Error: switchRoomFunction or nextRoom not set")
            end
        end
    }
end
