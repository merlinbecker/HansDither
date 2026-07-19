-- loadingBar.lua — modales Warte-Overlay für Save/Load/Sync-Operationen.
-- Wird von RoomOperation gesteuert (show/setDetail/finish/fail) und vom
-- jeweiligen Raum in dessen draw() gezeichnet.
--
-- Zeigt einen Text-Spinner statt eines Fortschrittsbalkens (R23): keiner der
-- Aufrufer (SyncService, EditorRoom, RoomOperation) kennt einen echten
-- Fortschrittsanteil (Netzwerk-Requests/Datei-I/O melden nur Phasen-Text,
-- keine Prozentzahl) — ein Balken, der nie über 0% hinauskommt, täuscht
-- Fortschritt nur vor. Das SDK bietet kein natives Spinner/Activity-
-- Indicator-Widget (verifiziert gegen Inside Playdate.html — nur
-- playdate.ui.crankIndicator existiert, und der ist für Crank-Aufforderungen
-- gedacht, keine generische Warteanzeige). Der Spinner hier nutzt nur bereits
-- im Projekt verifizierte Primitiven (gfx.drawTextAligned,
-- playdate.getCurrentTimeMilliseconds), keine neue SDK-Fläche.
import "CoreLibs/graphics"

local gfx = playdate.graphics

loadingBar = {}
loadingBar.__index = loadingBar

local SCREEN_W = 400
local SCREEN_H = 240
local BOX_W = 140
local BOX_H = 46

local SPINNER_FRAMES = { "|", "/", "-", "\\" }
local SPINNER_FRAME_MS = 150

local function truncateText(text, maxChars)
    text = tostring(text or "")
    if #text <= maxChars then
        return text
    end
    if maxChars <= 3 then
        return string.sub(text, 1, maxChars)
    end
    return string.sub(text, 1, maxChars - 3) .. "..."
end

function loadingBar.new()
    local instance = setmetatable({}, loadingBar)
    instance.visible = false
    instance.title = "Loading..."
    instance.detail = ""
    instance.failed = false
    instance.startMs = 0
    return instance
end

function loadingBar:show(title, detailText)
    self.visible = true
    self.failed = false
    self.title = title or self.title or "Loading..."
    self.detail = detailText or ""
    self.startMs = playdate.getCurrentTimeMilliseconds()
end

function loadingBar:setTitle(title)
    self.title = title or self.title
end

function loadingBar:setDetail(detailText)
    self.detail = detailText or ""
end

function loadingBar:finish()
    self.visible = false
    self.failed = false
    self.detail = ""
end

function loadingBar:fail(detailText)
    self.visible = true
    self.failed = true
    self.detail = detailText or "Error"
end

function loadingBar:isVisible()
    return self.visible
end

function loadingBar:draw()
    if not self.visible then
        return
    end

    local boxX = (SCREEN_W - BOX_W) // 2
    local boxY = (SCREEN_H - BOX_H) // 2

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(boxX, boxY, BOX_W, BOX_H)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(boxX, boxY, BOX_W, BOX_H)

    gfx.drawTextAligned(truncateText(self.title, 22), SCREEN_W // 2, boxY + 4, kTextAlignment.center)

    if self.failed then
        gfx.drawTextAligned("!!", SCREEN_W // 2, boxY + 18, kTextAlignment.center)
    else
        local elapsedMs = playdate.getCurrentTimeMilliseconds() - self.startMs
        local frameIndex = (elapsedMs // SPINNER_FRAME_MS) % #SPINNER_FRAMES + 1
        gfx.drawTextAligned(SPINNER_FRAMES[frameIndex], SCREEN_W // 2, boxY + 18, kTextAlignment.center)
    end

    local detailText = self.detail
    if self.failed then
        detailText = "Error: " .. tostring(detailText or "")
    end
    gfx.drawTextAligned(truncateText(detailText, 28), SCREEN_W // 2, boxY + 31, kTextAlignment.center)
end

return loadingBar
