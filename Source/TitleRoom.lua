-- StartRaum.lua
import "CoreLibs/graphics"

local gfx = playdate.graphics

TitleRoom = {}

local switchRoomFunction
local nextRoom
local needsRedraw

print("StartRaum loaded")
-- Initialize the room with shared data and dependencies
function TitleRoom:init(switchRoom,nextRoomReference)
    switchRoomFunction = switchRoom
    nextRoom = nextRoomReference
    needsRedraw = true
end

-- Update logic for StartRaum
function TitleRoom:update()
    if needsRedraw then
        -- Example: Draw the title screen here
        gfx.clear(gfx.kColorWhite)
        gfx.drawText("TITLEROOM", 0,0)
        print("Drawing TitleRoom")
        needsRedraw = false
    end
end

function TitleRoom:entered()
    needsRedraw = true
    print("Entered TitleRoom")
end

-- Input handler for StartRaum
function TitleRoom:inputHandler()
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
