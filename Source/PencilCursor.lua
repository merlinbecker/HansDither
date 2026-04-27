import "CoreLibs/graphics"

local gfx = playdate.graphics

PencilCursor = {}

local imageCache = {}

local function getCheckerCursorImage(width, height)
    local key = tostring(width) .. "x" .. tostring(height)
    local image = imageCache[key]
    if image then
        return image
    end

    image = gfx.image.new(width, height, gfx.kColorWhite)
    gfx.pushContext(image)
        for py = 0, height - 1 do
            for px = 0, width - 1 do
                if ((px + py) % 2) == 0 then
                    gfx.setColor(gfx.kColorBlack)
                else
                    gfx.setColor(gfx.kColorWhite)
                end
                gfx.drawPixel(px, py)
            end
        end
    gfx.popContext()

    imageCache[key] = image
    return image
end

-- Zeichnet den Cursor moeglichst einfach als gedithertes Overlay.
function PencilCursor.draw(x, y, width, height)
    if not x or not y or not width or not height then return end
    local drawWidth = math.floor(width)
    local drawHeight = math.floor(height)
    if drawWidth < 1 or drawHeight < 1 then return end

    local image = getCheckerCursorImage(drawWidth, drawHeight)
    image:drawFaded(math.floor(x), math.floor(y), 0.5, gfx.image.kDitherTypeDiagonalLine)
end
