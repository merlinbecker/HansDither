-- TitleRoom.lua — Startscreen (Splash).
--
-- Zeigt das zuletzt bearbeitete Bild als Hintergrund (Spec 002 US2) plus
-- Titel-/Versionszeilen und wartet auf A. Der Raum ist eine Einbahnstraße:
-- Es geht nur vorwärts zum SelectionRoom, nie zurück hierher.
import "CoreLibs/graphics"
import "ImageStore"

local gfx = playdate.graphics
local SCREEN_WIDTH = 400
local SCREEN_HEIGHT = 240

TitleRoom = {}

-- Abhängigkeiten (via init() injiziert, siehe main.lua)
local switchRoomFunction
local nextRoom

-- Räume zeichnen nur bei Bedarf neu — das Display behält den letzten
-- Framebuffer, solange niemand zeichnet ("dirty flag"-Muster aller Räume).
local needsRedraw
local metadataRows

-- pdxinfo-Werte (Version, buildNumber, …) stellt das SDK als Tabelle
-- playdate.metadata bereit.
local function getMetadataRows()
    local meta = playdate.metadata or {}
    return {
        tostring(meta["description"] or "n/a"),
        "Build: " .. tostring(meta["buildNumber"] or "n/a"),
        "Version: " .. tostring(meta["version"] or "n/a")
    }
end

-- Fallback-Hintergrund: 50%-Grau als Bayer-Dithering
-- (SDK: gfx.setDitherPattern(alpha, ditherType) wirkt auf folgende fills)
local function drawCheckerBackground()
    gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    gfx.setColor(gfx.kColorBlack)
end

-- Hintergrund: zuletzt bearbeitetes Bild, sonst Dither-Fallback (Spec 002 US2)
function TitleRoom:drawBackground()
    local preview = ImageStore.getLastEditedPreview()
    if preview then
        preview:draw(0, 0)
    else
        drawCheckerBackground()
    end
end

-- Weißer Balken mit schwarzem Text (die "Panels" des Startscreens)
local function drawPanelLine(text, x, y, w)
    local panelHeight = 20
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(x, y, w, panelHeight)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText(text, x + 6, y + 3)
end

-- switchRoom: Raumwechsel-Funktion aus main.lua
-- nextRoomReference: SelectionRoom (Ziel bei A-Druck)
function TitleRoom:init(switchRoom, nextRoomReference)
    switchRoomFunction = switchRoom
    nextRoom = nextRoomReference
    needsRedraw = true
    metadataRows = getMetadataRows()
end

function TitleRoom:update()
    if needsRedraw then
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
        needsRedraw = false
    end
end

-- Lifecycle: von switchRoom() bei jedem Betreten aufgerufen
function TitleRoom:entered()
    metadataRows = getMetadataRows()
    needsRedraw = true
    print("Entered TitleRoom")
end

-- Button-Callbacks für playdate.inputHandlers.push() (siehe main.lua switchRoom)
function TitleRoom:inputHandler()
    return {
        AButtonDown = function()
            if switchRoomFunction and nextRoom then
                switchRoomFunction(nextRoom)
            else
                print("Error: switchRoomFunction or nextRoom not set")
            end
        end
    }
end
