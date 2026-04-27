-- StartRaum.lua
import "CoreLibs/graphics"

local gfx = playdate.graphics
local SCREEN_WIDTH = 400
local SCREEN_HEIGHT = 240

TitleRoom = {}

local switchRoomFunction
local nextRoom
local needsRedraw
local metadataRows

local function getMetadataRows()
    local meta = playdate.metadata or {}
    return {
        tostring(meta["description"] or "n/a"),
        "Build: " .. tostring(meta["buildNumber"] or "n/a"),
        "Version: " .. tostring(meta["version"] or "n/a")
    }
end

local function drawCheckerBackground()
    -- Dithered background using Bayer 8x8
    gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    gfx.setColor(gfx.kColorBlack)
end

local function drawPanelLine(text, x, y, w)
    local panelHeight = 20
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(x, y, w, panelHeight)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText(text, x + 6, y + 3)
end

print("StartRaum loaded")
-- Initialize the room with shared data and dependencies
function TitleRoom:init(switchRoom,nextRoomReference)
    switchRoomFunction = switchRoom
    nextRoom = nextRoomReference
    needsRedraw = true
    metadataRows = getMetadataRows()
end

-- Update logic for StartRaum
function TitleRoom:update()
    if needsRedraw then
        drawCheckerBackground()

        drawPanelLine("Hans-Dither", 88, 26, 224)
        drawPanelLine(metadataRows[1], 28, 66, 344)
        drawPanelLine(metadataRows[2], 28, 90, 344)
        drawPanelLine(metadataRows[3], 28, 114, 344)

        local footerY = SCREEN_HEIGHT - 24
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(8, footerY, SCREEN_WIDTH - 16, 16)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawText("still under development, press (A)", 12, footerY + 3)
        print("Drawing TitleRoom")
        needsRedraw = false
    end
end

function TitleRoom:entered()
    metadataRows = getMetadataRows()
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
