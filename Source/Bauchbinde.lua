Bauchbinde = {}
Bauchbinde.__index = Bauchbinde

function Bauchbinde.new(gfx, config)
    return setmetatable({
        gfx = gfx,
        margin = (config and config.margin) or 4,
        paddingX = (config and config.paddingX) or 4,
        height = (config and config.height) or 22
    }, Bauchbinde)
end

function Bauchbinde:drawBottom(text, side, screenW, screenH)
    if not text or text == "" then return end

    local textW, textH = self.gfx.getTextSize(text)
    local bandW = textW + (self.paddingX * 2)
    local bandH = self.height
    local bandY = screenH - bandH - self.margin
    local bandX

    if side == "right" then
        bandX = screenW - bandW - self.margin
    else
        bandX = self.margin
    end

    if bandX < 0 then bandX = 0 end
    if bandY < 0 then bandY = 0 end

    -- Bauchbinde ist immer gleich: weisser Hintergrund, schwarzer Rand, schwarze Schrift.
    self.gfx.setColor(self.gfx.kColorWhite)
    self.gfx.fillRect(bandX, bandY, bandW, bandH)
    self.gfx.setColor(self.gfx.kColorBlack)
    self.gfx.drawRect(bandX, bandY, bandW, bandH)

    local textY = bandY + ((bandH - textH) // 2)
    self.gfx.drawText(text, bandX + self.paddingX, textY)
end

return Bauchbinde
