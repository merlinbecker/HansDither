-- Bauchbinde.lua — kleines Text-Banner am Bildschirmrand (z.B. "Frame 2/4"
-- im EditorRoom). Reines Zeichen-Helferlein ohne SDK-Magie; gfx wird
-- injiziert, damit das Modul headless testbar bleibt.
--
-- Spec 010 (Eighth Round, FR-028): `draw()` nimmt zusaetzlich einen
-- vertikalen Anker ("top"/"bottom") und mehrere Zeilen — so teilen sich
-- Frame/Ebenen-Label und Statusmeldung EINE cursorabgewandte Leiste.
-- `drawBottom()` bleibt signaturgleich als duenner Wrapper (Caller
-- SelectionRoom.lua:456 unveraendert).
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

-- lines: String ODER Array von Strings (leere werden verworfen).
-- side: "left" | "right" (horizontale Haelfte, dem Cursor gegenueber).
-- vAnchor: "top" | "bottom" (vertikaler Rand, dem Cursor gegenueber).
function Bauchbinde:draw(lines, side, vAnchor, screenW, screenH)
    if type(lines) == "string" then lines = { lines } end

    local shown = {}
    for _, t in ipairs(lines or {}) do
        if t and t ~= "" then shown[#shown + 1] = t end
    end
    if #shown == 0 then return end

    local maxTextW, lineH = 0, 0
    for _, t in ipairs(shown) do
        local w, h = self.gfx.getTextSize(t)
        if w > maxTextW then maxTextW = w end
        if h > lineH then lineH = h end
    end

    local bandW = maxTextW + (self.paddingX * 2)
    -- Einzeiler: exakt wie frueher (self.height). Mehrzeiler: waechst.
    local bandH = self.height
    if #shown > 1 then
        bandH = math.max(self.height, #shown * lineH + 8)
    end

    local bandX
    if side == "right" then
        bandX = screenW - bandW - self.margin
    else
        bandX = self.margin
    end

    local bandY
    if vAnchor == "top" then
        bandY = self.margin
    else
        bandY = screenH - bandH - self.margin
    end

    if bandX < 0 then bandX = 0 end
    if bandY < 0 then bandY = 0 end

    -- Bauchbinde ist immer gleich: weisser Hintergrund, schwarzer Rand, schwarze Schrift.
    self.gfx.setColor(self.gfx.kColorWhite)
    self.gfx.fillRect(bandX, bandY, bandW, bandH)
    self.gfx.setColor(self.gfx.kColorBlack)
    self.gfx.drawRect(bandX, bandY, bandW, bandH)

    local textY = bandY + ((bandH - #shown * lineH) // 2)
    for i, t in ipairs(shown) do
        self.gfx.drawText(t, bandX + self.paddingX, textY + (i - 1) * lineH)
    end
end

-- Rueckwaerts kompatibel: Einzeiler unten, gleiche Signatur wie bisher.
function Bauchbinde:drawBottom(text, side, screenW, screenH)
    self:draw(text, side, "bottom", screenW, screenH)
end

return Bauchbinde
