-- PixelTransparency.lua
-- Spec 010 (US2, contracts/layer-api.md "Transparency Helpers"): 3-Zustands-
-- Modell fuer einen EINZELNEN Pixel. Die Transparenz wird — anders als der
-- fruehe data-model.md-Entwurf (375er-Array je Tile-Zelle) vorsah — PRO PIXEL
-- gefuehrt und lebt direkt im 1-Bit-Tile-Bild als Playdate-Farbe:
--
--   OPAQUE      (0)  gemalter Pixel            -> gfx.kColorBlack ODER kColorWhite
--   TRANSPARENT (1)  durchsichtig gemalt       -> gfx.kColorClear
--   EMPTY       (2)  nicht gemalt / radiert    -> gfx.kColorWhite
--
-- "opaque" ist orthogonal zur Farbe: ein deckend-weisser Pixel ist ebenso
-- opak wie ein schwarzer. Im Pixel-Editor (PixelRoom) unterscheidet sich
-- "empty" (weiss) sichtbar von "transparent" (Schachbrett); im gespeicherten
-- Tile fallen beide auf "kein schwarzer Ink"-Pixel zusammen, wobei EMPTY als
-- kColorWhite und TRANSPARENT als kColorClear abgelegt wird und damit ueber
-- den 3-Zustands-Hash (ImageStoreCodec.hashTile) getrennt dedupliziert wird
-- (spec.md Edge Case Zeile 104).

import "CoreLibs/graphics"

PixelTransparency = {}

PixelTransparency.OPAQUE = 0
PixelTransparency.TRANSPARENT = 1
PixelTransparency.EMPTY = 2

local STATE_TO_BYTE = { opaque = 0, transparent = 1, empty = 2 }
local BYTE_TO_STATE = { [0] = "opaque", [1] = "transparent", [2] = "empty" }

-- state ("opaque"|"transparent"|"empty") -> 0|1|2
function PixelTransparency.encode(state)
    return STATE_TO_BYTE[state] or PixelTransparency.OPAQUE
end

-- 0|1|2 -> "opaque"|"transparent"|"empty"
function PixelTransparency.decode(byte)
    return BYTE_TO_STATE[byte] or "opaque"
end

function PixelTransparency.isTransparent(byte)
    return byte == PixelTransparency.TRANSPARENT
end

function PixelTransparency.isOpaque(byte)
    return byte == PixelTransparency.OPAQUE or byte == nil
end

function PixelTransparency.isEmpty(byte)
    return byte == PixelTransparency.EMPTY
end

-- Klemmt einen beliebigen Wert auf einen gueltigen Zustand (0/1/2); alles
-- andere (nil, Fremdwerte aus defekten Speicherdateien) faellt auf opak
-- zurueck (FR-010: Rueckwaertskompatibilitaet — Alt-Tiles sind schwarz/weiss
-- und damit durchgehend opak).
function PixelTransparency.sanitize(value)
    if value == 0 or value == 1 or value == 2 then
        return value
    end
    return PixelTransparency.OPAQUE
end

-- ── Bruecke Pixel-Editor <-> 1-Bit-Tile ──────────────────────────────────────
--
-- Der PixelRoom haelt sein 16x16-Malraster als 3-Zustands-Codes; buildTileImage
-- schreibt daraus ein Tile, setCurrentTile liest es zurueck. black == "opaque
-- schwarz", white == "empty", clear == "transparent". Ein deckend-weiss
-- gemalter Pixel ist in dieser Codebasis nicht von "radiert" unterscheidbar
-- (der A-Strich radiert bereits nach Weiss) und wird daher wie EMPTY gefuehrt.

-- 3-Zustands-Code eines Pixels aus einer Playdate-Farbe (gfx.kColor*).
function PixelTransparency.fromColor(color)
    local gfx = playdate.graphics
    if color == gfx.kColorBlack then
        return PixelTransparency.OPAQUE
    elseif color == gfx.kColorClear then
        return PixelTransparency.TRANSPARENT
    end
    return PixelTransparency.EMPTY
end

-- Playdate-Farbe (gfx.kColor*) fuer einen 3-Zustands-Code.
function PixelTransparency.toColor(byte)
    local gfx = playdate.graphics
    if byte == PixelTransparency.OPAQUE then
        return gfx.kColorBlack
    elseif byte == PixelTransparency.TRANSPARENT then
        return gfx.kColorClear
    end
    return gfx.kColorWhite
end

-- Liest den 3-Zustands-Code an Pixel (x,y) eines 16x16-Tile-Bildes
-- (SDK: image:sample(x,y), 0-basiert).
function PixelTransparency.sampleState(image, x, y)
    if not image then return PixelTransparency.EMPTY end
    return PixelTransparency.fromColor(image:sample(x, y))
end

return PixelTransparency
