
import "CoreLibs/graphics"
import "CoreLibs/timer"
import "CoreLibs/ui"
import "CoreLibs/animation"
import "CoreLibs/crank"
import "CoreLibs/object" -- für playdate.graphics.image.new()

local gfx = playdate.graphics
-- Playdate Skalierung: 2 -> logische Größe 200x120 (Pulp-Auflösung)
playdate.display.setScale(2)


local GRID_COLS = 25
local GRID_ROWS = 15
local CELL_SIZE = 8 -- 8x8 Pixel pro Zelle, wenn die Skalierung aus ist, 16x16


-- Matrix-Imagetable (2 Tiles, 8x8) laden (siehe 7.20.12 Image Table)
local origImagetable = gfx.imagetable.new("images/cellbg")
assert(origImagetable, "Imagetable konnte nicht geladen werden!")


-- todo: bessere Imagetable laden, dann kann ich mir die Erstellung des schwarzen Tiles sparen
-- Neue Imagetable mit 3 Einträgen anlegen
local cellImagetable = gfx.imagetable.new(3)
cellImagetable:setImage(1, origImagetable:getImage(1))
cellImagetable:setImage(2, origImagetable:getImage(2))

-- Schwarzes Tile erzeugen und als drittes Tile anhängen
local blackTile = gfx.image.new(CELL_SIZE, CELL_SIZE)
gfx.pushContext(blackTile)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, CELL_SIZE, CELL_SIZE)
gfx.popContext()
cellImagetable:setImage(3, blackTile)



-- Schritt 1: Tilemap initialisieren (alle Tiles auf 1 = Hintergrund)
local tilemap = gfx.tilemap.new()
tilemap:setSize(GRID_COLS, GRID_ROWS)
tilemap:setImageTable(cellImagetable)
for y = 1, GRID_ROWS do
    for x = 1, GRID_COLS do
        tilemap:setTileAtPosition(x, y, 1)
    end
end


-- GridView bleibt für Cursor-Handling erhalten
local gridView = playdate.ui.gridview.new(CELL_SIZE, CELL_SIZE)
gridView:setNumberOfSections(1)
gridView:setNumberOfColumns(GRID_COLS)
gridView:setNumberOfRowsInSection(1, GRID_ROWS)

-- Cursor-Blinker (immer looping)
local cursorBlinker = playdate.graphics.animation.blinker.new(500, 500, true, nil, true)
cursorBlinker:startLoop()

-- Mittelwert initiale Selektion in der Bildschirmmitte (12, 8) in Sektion 1
-- setSelection(section, row, column)
gridView:setSelection(1, math.floor(GRID_ROWS / 2) + 1, math.floor(GRID_COLS / 2) + 1)


-- Zeichne eine Zelle und optional Cursor, bei Auswahl
function gridView:drawCell(section, row, column, selected, x, y, width, height)
    local selSection, selRow, selCol = gridView:getSelection()
    -- Die Tilemap wird im Haupt-Draw (playdate.update) gezeichnet!
    -- Cursor immer in der selektierten Zelle zeichnen
    local isCursor = (section == selSection and row == selRow and column == selCol)
    if isCursor and cursorBlinker.on then
        local tileIndex = tilemap:getTileAtPosition(column, row)
        local cx = x + width / 2
        local cy = y + height / 2
        if tileIndex == 3 then
            gfx.setColor(gfx.kColorWhite)
        else
            gfx.setColor(gfx.kColorBlack)
        end
        gfx.fillCircleAtPoint(cx, cy, 2)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
end

local needsRedraw = true

-- A-Button toggelt Zelleninhalt an der aktuellen Cursor-Position
local function toggleCurrentCell()
    local section, row, col = gridView:getSelection()
    if row and col then
        local current = tilemap:getTileAtPosition(col, row)
        if current == 3 then
            tilemap:setTileAtPosition(col, row, 1)
        else
            tilemap:setTileAtPosition(col, row, 3)
        end
        needsRedraw = true
    end
end

-- D-Pad und A-Button Input-Handler

-- Zoom-Input-Handling: D-Pad Up + Crank
local upHeld = false
local pixelZoomActive = false

local inputHandler = {
    upButtonDown = function()
        upHeld = true
        gridView:selectPreviousRow(false, true, false)
        needsRedraw = true
    end,
    upButtonUp = function()
        upHeld = false
    end,
    downButtonDown = function()
        gridView:selectNextRow(false, true, false)
        needsRedraw = true
    end,
    leftButtonDown = function()
        gridView:selectPreviousColumn(false, true, false)
        needsRedraw = true
    end,
    rightButtonDown = function()
        gridView:selectNextColumn(false, true, false)
        needsRedraw = true
    end,
    AButtonDown = function()
        toggleCurrentCell()
    end
}
playdate.inputHandlers.push(inputHandler, true)

local lastBlinkState = cursorBlinker.on


-- Kontext-Grid-Konstanten (laut Plan3)
local CONTEXT_TILES_W = 14
local CONTEXT_TILES_H = 8
local TILE_PIXELS = 8 -- 8x8 Pixel pro Tile
local PIXEL_CELL_SIZE = 15 -- Jede editierbare Pixelzelle ist 15x15 Pixel

-- Arbeitsdaten für Pixel-Zoom-Modus
local pixelZoomGridView = nil
local contextTileImages = {} -- [tileX][tileY] = Arbeits-gfx.image (8x8)
local contextTileIndices = {} -- [tileX][tileY] = Tile-Index im Hauptgrid
local contextOriginX, contextOriginY = nil, nil -- Linke obere Tile-Koordinate im Hauptgrid
local contextCursorTileX, contextCursorTileY = nil, nil -- Tile-Koordinate des Cursors im Kontextgrid
local contextCursorPixelX, contextCursorPixelY = nil, nil -- Pixel-Koordinate im Tile

function enterPixelZoomMode()
    pixelZoomActive = true
    print("Pixel-Zoom aktiviert")

    -- 1. Aktuelle Grid- und Cursor-Position sichern
    local selSection, selRow, selCol = gridView:getSelection()
    -- Cursor im Hauptgrid: (selCol, selRow)

    -- 2. Kontextbereich bestimmen (linke obere Ecke im Hauptgrid)
    contextOriginX = math.max(1, selCol - math.floor(CONTEXT_TILES_W / 2))
    contextOriginY = math.max(1, selRow - math.floor(CONTEXT_TILES_H / 2))
    -- Kontextgrid nicht über Gridgrenzen hinaus
    if contextOriginX + CONTEXT_TILES_W - 1 > GRID_COLS then
        contextOriginX = GRID_COLS - CONTEXT_TILES_W + 1
    end
    if contextOriginY + CONTEXT_TILES_H - 1 > GRID_ROWS then
        contextOriginY = GRID_ROWS - CONTEXT_TILES_H + 1
    end
    contextOriginX = math.max(1, contextOriginX)
    contextOriginY = math.max(1, contextOriginY)

    -- 3. Kontext-Tiles und Arbeitsbilder anlegen
    contextTileImages = {}
    contextTileIndices = {}
    for ty = 1, CONTEXT_TILES_H do
        contextTileImages[ty] = {}
        contextTileIndices[ty] = {}
        for tx = 1, CONTEXT_TILES_W do
            local gridX = contextOriginX + tx - 1
            local gridY = contextOriginY + ty - 1
            local tileIdx = tilemap:getTileAtPosition(gridX, gridY)
            contextTileIndices[ty][tx] = tileIdx
            -- Hole das Tile-Image (8x8) aus der Imagetable
            local tileImg = cellImagetable:getImage(tileIdx)
            -- Arbeitskopie erzeugen
            local workImg = gfx.image.new(TILE_PIXELS, TILE_PIXELS)
            gfx.pushContext(workImg)
                if tileImg then tileImg:draw(0, 0) end
            gfx.popContext()
            contextTileImages[ty][tx] = workImg
        end
    end

    -- 4. GridView für Pixel-Editing erzeugen (14*8 x 8*8 Zellen, jede 15x15 Pixel)
    pixelZoomGridView = playdate.ui.gridview.new(PIXEL_CELL_SIZE, PIXEL_CELL_SIZE)
    pixelZoomGridView:setNumberOfSections(1)
    pixelZoomGridView:setNumberOfColumns(CONTEXT_TILES_W * TILE_PIXELS)
    pixelZoomGridView:setNumberOfRowsInSection(1, CONTEXT_TILES_H * TILE_PIXELS)

    -- 5. Cursor mittig auf das aktuelle Tile und Pixel setzen
    contextCursorTileX = math.floor(CONTEXT_TILES_W / 2) + 1
    contextCursorTileY = math.floor(CONTEXT_TILES_H / 2) + 1
    contextCursorPixelX = 4 -- Mitte von 8x8 Pixel
    contextCursorPixelY = 4
    local cursorCol = (contextCursorTileX - 1) * TILE_PIXELS + contextCursorPixelX
    local cursorRow = (contextCursorTileY - 1) * TILE_PIXELS + contextCursorPixelY
    pixelZoomGridView:setSelection(1, cursorRow, cursorCol)

    -- 6. Zeichenfunktion für Pixel-GridView überschreiben
    function pixelZoomGridView:drawCell(section, row, column, selected, x, y, width, height)
        -- Berechne, zu welchem Tile und Pixel diese Zelle gehört
        local tileX = math.floor((column - 1) / TILE_PIXELS) + 1
        local tileY = math.floor((row - 1) / TILE_PIXELS) + 1
        local pixelX = ((column - 1) % TILE_PIXELS) + 1
        local pixelY = ((row - 1) % TILE_PIXELS) + 1
        local workImg = nil
        if contextTileImages[tileY] and contextTileImages[tileY][tileX] then
            workImg = contextTileImages[tileY][tileX]
        end
        -- Pixelwert abfragen
        pixelval = workImg:sample(pixelX - 1, pixelY - 1) 
        print(pixelval)
        -- Zelle zeichnen
        if pixelVal == kColorBlack  then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(x, y, width, height)
        else
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRect(x, y, width, height)
            gfx.setColor(gfx.kColorBlack)
            gfx.drawRect(x, y, width, height)
        end
        
        -- Cursor
        local isCursor = (section == selSection and row == selRow and column == selCol)
        if isCursor and cursorBlinker.on then
            local cx = x + width / 2
            local cy = y + height / 2
            if pixelVal == kColorBlack  then
                gfx.setColor(gfx.kColorWhite)
            else
                gfx.setColor(gfx.kColorBlack)
            end
            gfx.fillCircleAtPoint(cx, cy, 2)
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
        end
        
        if selected then
            gfx.setColor(gfx.kColorBlack)
            gfx.drawRect(x+2, y+2, width-4, height-4)
        end
    end

    needsRedraw = true
end

function exitPixelZoomMode()
    pixelZoomActive = false
    print("Pixel-Zoom deaktiviert")
    -- Hier folgt im nächsten Schritt das Rückübernehmen der Tiles
end




function playdate.update()
    -- Blink-Animation aktualisieren; wenn Blinkzustand wechselt, Neuzeichnen anstoßen
    cursorBlinker:updateAll()
    if cursorBlinker.on ~= lastBlinkState then
        lastBlinkState = cursorBlinker.on
        needsRedraw = true
    end
    -- todo, nochmal durchtesten und der drank muss wirklich einmal 360 grad durchgehen
    -- Zoom-Trigger: D-Pad Up gehalten + Crank
    if upHeld and not pixelZoomActive then
        local ticks = playdate.getCrankTicks(1)
        if ticks > 0 then
            enterPixelZoomMode()
        end
    elseif upHeld and pixelZoomActive then
        local ticks = playdate.getCrankTicks(1)
        if ticks < 0 then
            exitPixelZoomMode()
        end
    end


    if needsRedraw then
        gfx.clear(gfx.kColorWhite)
        if pixelZoomActive and pixelZoomGridView then
            -- Pixel-Zoom-Grid zeichnen (volle Fläche, z.B. 210x120)
            pixelZoomGridView:drawInRect(0, 0, CONTEXT_TILES_W * TILE_PIXELS * PIXEL_CELL_SIZE, CONTEXT_TILES_H * TILE_PIXELS * PIXEL_CELL_SIZE)
        else
            -- Schritt 5: Tilemap zeichnen (Grid)
            tilemap:draw(0, 0)
            -- Cursor-Overlay via gridView (ruft drawCell für selektierte Zelle auf)
            gridView:drawInRect(0, 0, GRID_COLS * CELL_SIZE, GRID_ROWS * CELL_SIZE)
        end
        needsRedraw = false
    end

    -- Timer-Update für CoreLib-Timer und GridView (z.B. Scroll- und Blinker-Handling)
    playdate.timer.updateTimers()
end