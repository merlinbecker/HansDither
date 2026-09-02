-- ShakeDetector.lua
-- Spec 011 (Foundational, data-model.md §3 / contracts C-011-3): erkennt eine
-- bewusste Links-Rechts-Schuettelbewegung ("einmal nach links und rechts") aus
-- dem Accelerometer-Sample-Strom. Das Playdate SDK bietet kein Shake-Ereignis
-- (nur playdate.readAccelerometer -> rohe g-Werte), daher diese Eigenlogik --
-- begruendete SDK-Abweichung, siehe ADR-044.
--
-- Reiner Zustandsautomat, kein SDK-Zugriff, keine Allokation im Normalfall ->
-- headless-testbar mit synthetischen (x, nowMs)-Folgen.
--
-- Algorithmus (X-Achse = Geraete-Laengsachse):
--   * Ausschlag  x > +T  bzw.  x < -T  merkt seinen Zeitpunkt.
--   * Liegen ein +T- und ein -T-Ausschlag <= W ms auseinander -> KANTE.
--   * Nach einer Kante gilt R ms Refraktaersperre (kein weiteres Feuern).
-- T/W/R sind Startwerte; der genaue Schwellwert wird auf Hardware justiert
-- (Spec Open #4, ADR-044).

ShakeDetector = {}
ShakeDetector.__index = ShakeDetector

local DEFAULT_T = 0.85    -- Schwellwert |x| in g
local DEFAULT_W = 500     -- ms: Fenster zwischen den beiden Ausschlaegen
local DEFAULT_R = 1200    -- ms: Refraktaerzeit nach einer Kante

function ShakeDetector.new(opts)
    opts = opts or {}
    return setmetatable({
        T = opts.T or DEFAULT_T,
        W = opts.W or DEFAULT_W,
        R = opts.R or DEFAULT_R,
        lastPosMs = nil,
        lastNegMs = nil,
        blockedUntilMs = 0,
    }, ShakeDetector)
end

-- feed(x, y, z, nowMs) -> bool. Liefert genau dann true, wenn eine saubere
-- Links-Rechts-Sequenz erkannt wird und keine Refraktaersperre aktiv ist.
function ShakeDetector:feed(x, y, z, nowMs)
    x = x or 0
    nowMs = nowMs or 0

    if nowMs < self.blockedUntilMs then
        return false
    end

    if x > self.T then
        self.lastPosMs = nowMs
    elseif x < -self.T then
        self.lastNegMs = nowMs
    end

    if self.lastPosMs and self.lastNegMs
        and math.abs(self.lastPosMs - self.lastNegMs) <= self.W then
        self.blockedUntilMs = nowMs + self.R
        self.lastPosMs = nil
        self.lastNegMs = nil
        return true
    end

    return false
end

function ShakeDetector:reset()
    self.lastPosMs = nil
    self.lastNegMs = nil
    self.blockedUntilMs = 0
end

return ShakeDetector
