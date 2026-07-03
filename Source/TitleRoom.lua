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

local backgroundImage = nil

local function drawCheckerBackground()
    -- Dithered background using Bayer 8x8
    gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    gfx.setColor(gfx.kColorBlack)
end

-- Zeichnet den Hintergrund (letztes bearbeitetes Bild oder Dither-Fallback)
function TitleRoom:drawBackground()
    -- Versuche, das zuletzt bearbeitete Bild zu laden
    import "Source/ImageStore"
    local preview = ImageStore.getLastEditedPreview()
    
    if preview then
        -- Zeichne das Preview-Bild vollflächig
        gfx.drawImage(preview, 0, 0)
        backgroundImage = preview
    else
        -- Fallback: Bayer-Dither
        drawCheckerBackground()
        backgroundImage = nil
    end
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
        -- Zeichne Hintergrund (letztes bearbeitetes Bild oder Dither-Fallback)
        TitleRoom:drawBackground()

        drawPanelLine("Hans Dither, 1 bit Pixel 'n Tile Editor", 88, 26, 224)
        drawPanelLine(metadataRows[1], 28, 66, 344)
        drawPanelLine(metadataRows[2], 28, 90, 344)
        drawPanelLine(metadataRows[3], 28, 114, 344)

        local footerY = SCREEN_HEIGHT - 24
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(8, footerY, SCREEN_WIDTH - 16, 16)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawText(metadataRows[3] .. " - still under development - Press A", 12, footerY + 3)
        print("Drawing TitleRoom")
        needsRedraw = false
    end
end

function TitleRoom:entered()
    metadataRows = getMetadataRows()
    backgroundImage = nil  -- Reset Hintergrund-Cache
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
