import "CoreLibs/graphics"

local gfx = playdate.graphics

loadingBar = {}
loadingBar.__index = loadingBar

local SCREEN_W = 400
local SCREEN_H = 240
local BOX_W = 140
local BOX_H = 46
local BAR_W = 110
local BAR_H = 10

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

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
    instance.progress = 0
    instance.failed = false
    return instance
end

function loadingBar:show(title, detailText)
    self.visible = true
    self.failed = false
    self.title = title or self.title or "Loading..."
    self.detail = detailText or ""
    self.progress = 0
end

function loadingBar:setTitle(title)
    self.title = title or self.title
end

function loadingBar:setDetail(detailText)
    self.detail = detailText or ""
end

function loadingBar:updateFraction(fraction, detailText)
    self.visible = true
    self.failed = false
    self.progress = clamp(tonumber(fraction) or 0, 0, 1)
    if detailText ~= nil then
        self.detail = detailText
    end
end

function loadingBar:updateProgress(current, total, detailText)
    local safeTotal = tonumber(total) or 0
    local safeCurrent = tonumber(current) or 0
    if safeTotal <= 0 then
        self:updateFraction(0, detailText)
        return
    end
    self:updateFraction(safeCurrent / safeTotal, detailText)
end

function loadingBar:finish()
    self.visible = false
    self.failed = false
    self.progress = 0
    self.detail = ""
end

function loadingBar:fail(detailText)
    self.visible = true
    self.failed = true
    self.progress = 1
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
    local barX = boxX + (BOX_W - BAR_W) // 2
    local barY = boxY + 18
    local fillWidth = math.floor((BAR_W - 2) * clamp(self.progress, 0, 1))

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(boxX, boxY, BOX_W, BOX_H)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(boxX, boxY, BOX_W, BOX_H)

    gfx.drawTextAligned(truncateText(self.title, 22), SCREEN_W // 2, boxY + 4, kTextAlignment.center)
    gfx.drawRect(barX, barY, BAR_W, BAR_H)

    if fillWidth > 0 then
        gfx.fillRect(barX + 1, barY + 1, fillWidth, BAR_H - 2)
    end

    local detailText = self.detail
    if self.failed then
        detailText = "Error: " .. tostring(detailText or "")
    end
    gfx.drawTextAligned(truncateText(detailText, 28), SCREEN_W // 2, boxY + 31, kTextAlignment.center)
end

return loadingBar