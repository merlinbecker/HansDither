-- ZoomRoom.lua
-- Mittlerer Zoom-Raum zwischen TileRoom (25×15 Tiles) und PixelRoom (8×8 Pixel).
-- Zeigt 3×3 Tiles rund um den aktuellen Cursor als 24×24 editierbare Zellen an.
-- Jede Zelle entspricht einem Pixel des Tiles (5×5 px auf dem Bildschirm, bei Scale 2).

import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/animation"
import "CoreLibs/crank"

local gfx = playdate.graphics

ZoomRoom = {}

-- ── Konstanten ────────────────────────────────────────────────────────────────

local TILE_SIZE  = 8   -- Pixel pro Tile (8×8)
local SLOTS      = 3   -- Raster: 3×3 Tile-Slots
local GRID_COLS  = TILE_SIZE * SLOTS  -- 24 Zellen
local GRID_ROWS  = TILE_SIZE * SLOTS  -- 24 Zellen
local CELL_SIZE  = 5   -- px pro Zelle (logisch, Display-Scale 2)

-- Grid zentriert: (200 - 120) / 2 = 40 px links, 0 px oben (passt exakt in 200×120)
local OFFSET_X   = 40
local OFFSET_Y   = 0

-- Strichelung für Pixel-Grenzen (Dash/Gap in Zellen-Einheiten × CELL_SIZE)
local DASH_LEN   = 2   -- px Strich
local GAP_LEN    = 2   -- px Lücke

-- ── Modul-State ───────────────────────────────────────────────────────────────

local switchRoomFunction
local pixelRoom
local tileRoom

-- showGridLines: übernommen von TileRoom, steuert ob Intertile-Grenzen (gestrichelt) gezeichnet werden.
local showGridLines = true

-- gridState[row][col] = bool  (true = schwarz, false = weiß)
-- row/col jeweils 1..24 (GRID_ROWS × GRID_COLS)
local gridState = {}

-- tileSlots[slotRow][slotCol] = { tileIndex = <int>, originalTileIndex = <int> }
-- slotRow/slotCol jeweils 1..3 (SLOTS × SLOTS)
-- tileIndex = 0 bedeutet "Slot war leer / out-of-bounds → nicht in Tilemap schreiben"
local tileSlots = {}

-- Cursor im 24×24-Grid (1-basiert)
local cursorRow = 1
local cursorCol = 1

-- Merkt sich, in welchem Slot zuletzt in PixelRoom gezoomt wurde (für Rückgabe).
local lastEditedSlotRow = nil
local lastEditedSlotCol = nil

-- Tilemap-Koordinaten des Cursor-Tiles (aus TileRoom-Kontext), für Commit-Berechnung.
local contextCursorTileCol = 1
local contextCursorTileRow = 1

local needsRedraw = true

-- Blinker analog TileRoom / PixelRoom
local cursorBlinker = playdate.graphics.animation.blinker.new(500, 500, true, nil, true)
cursorBlinker:startLoop()
local lastBlinkState = cursorBlinker.on

-- Crank-Akkumulator (analog zu TileRoom/PixelRoom)
local ticks  = 0
local upHeld = false

-- ── Hilfsfunktionen ───────────────────────────────────────────────────────────

-- Gibt (slotRow, slotCol) im Bereich 1..3 für eine Zellen-Position zurück.
local function getSlotForCell(row, col)
    return math.ceil(row / TILE_SIZE), math.ceil(col / TILE_SIZE)
end

-- Dekodiert ein 8×8-gfx.image in gridState für den angegebenen Slot (1-basiert).
-- Wenn tile nil ist (out-of-bounds), werden alle Zellen des Slots auf weiß (false) gesetzt.
local function decodeTileIntoGridState(tile, slotRow, slotCol)
    local baseRow = (slotRow - 1) * TILE_SIZE
    local baseCol = (slotCol - 1) * TILE_SIZE
    for r = 1, TILE_SIZE do
        for c = 1, TILE_SIZE do
            if tile then
                local color = tile:sample(c - 1, r - 1)
                gridState[baseRow + r][baseCol + c] = (color == gfx.kColorBlack)
            else
                gridState[baseRow + r][baseCol + c] = false
            end
        end
    end
end

-- Baut ein 8×8-gfx.image aus gridState für den angegebenen Slot.
local function buildTileImageForSlot(slotRow, slotCol)
    local img = gfx.image.new(TILE_SIZE, TILE_SIZE, gfx.kColorWhite)
    gfx.pushContext(img)
        gfx.setColor(gfx.kColorBlack)
        local baseRow = (slotRow - 1) * TILE_SIZE
        local baseCol = (slotCol - 1) * TILE_SIZE
        for r = 1, TILE_SIZE do
            for c = 1, TILE_SIZE do
                if gridState[baseRow + r][baseCol + c] then
                    gfx.drawPixel(c - 1, r - 1)
                end
            end
        end
    gfx.popContext()
    return img
end

-- Vergleicht zwei Bilder pixelgenau.
local function imagesEqual(a, b)
    if a == nil and b == nil then return true end
    if a == nil or b == nil then return false end
    local aw, ah = a:getSize()
    local bw, bh = b:getSize()
    if aw ~= bw or ah ~= bh then return false end
    for y = 0, ah - 1 do
        for x = 0, aw - 1 do
            if a:sample(x, y) ~= b:sample(x, y) then
                return false
            end
        end
    end
    return true
end

-- ── Rendering ─────────────────────────────────────────────────────────────────

-- Zeichnet eine gestrichelte vertikale Linie (px-koordinaten).
local function drawDashedVLine(x, y1, y2)
    local y = y1
    while y < y2 do
        local yEnd = math.min(y + DASH_LEN - 1, y2 - 1)
        gfx.drawLine(x, y, x, yEnd)
        y = y + DASH_LEN + GAP_LEN
    end
end

-- Zeichnet eine gestrichelte horizontale Linie (px-koordinaten).
local function drawDashedHLine(x1, x2, y)
    local x = x1
    while x < x2 do
        local xEnd = math.min(x + DASH_LEN - 1, x2 - 1)
        gfx.drawLine(x, y, xEnd, y)
        x = x + DASH_LEN + GAP_LEN
    end
end

-- Zeichnet das 24×24-Zellraster mit Zellinhalt, Linienstilen und Cursor.
local function drawGrid()
    local totalW = GRID_COLS * CELL_SIZE
    local totalH = GRID_ROWS * CELL_SIZE

    -- 0. Seitflächen links und rechts des Grids: Checkerboard-Pattern wie PixelRoom
    gfx.setPattern({ 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55 })
    gfx.fillRect(0, 0, OFFSET_X, totalH)
    gfx.fillRect(OFFSET_X + totalW, 0, OFFSET_X, totalH)
    gfx.setColor(gfx.kColorBlack)

    -- 1. Zellen zeichnen (Pixel-Inhalt)
    for r = 1, GRID_ROWS do
        for c = 1, GRID_COLS do
            local x = OFFSET_X + (c - 1) * CELL_SIZE
            local y = OFFSET_Y + (r - 1) * CELL_SIZE
            if gridState[r][c] then
                gfx.setColor(gfx.kColorBlack)
                gfx.fillRect(x, y, CELL_SIZE, CELL_SIZE)
            else
                gfx.setColor(gfx.kColorWhite)
                gfx.fillRect(x, y, CELL_SIZE, CELL_SIZE)
            end
        end
    end

    -- 2. Pixelgrenzen innerhalb der Tiles: gestrichelte Linien (nur wenn showGridLines)
    if showGridLines then
        gfx.setColor(gfx.kColorBlack)
        -- Vertikale Zwischenlinien (gestrichelt, nicht an Tile-Grenzen)
        for c = 1, GRID_COLS - 1 do
            local x = OFFSET_X + c * CELL_SIZE
            local isTileBorder = (c % TILE_SIZE == 0)
            if not isTileBorder then
                drawDashedVLine(x, OFFSET_Y, OFFSET_Y + totalH)
            end
        end
        -- Horizontale Zwischenlinien (gestrichelt, nicht an Tile-Grenzen)
        for r = 1, GRID_ROWS - 1 do
            local y = OFFSET_Y + r * CELL_SIZE
            local isTileBorder = (r % TILE_SIZE == 0)
            if not isTileBorder then
                drawDashedHLine(OFFSET_X, OFFSET_X + totalW, y)
            end
        end
    end

    -- 3. Tile-Grenzen: durchgezogene Linien (alle 8 Zellen + Außenrahmen)
    gfx.setColor(gfx.kColorBlack)
    -- Vertikale Tile-Grenzen
    for s = 0, SLOTS do
        local x = OFFSET_X + s * TILE_SIZE * CELL_SIZE
        gfx.drawLine(x, OFFSET_Y, x, OFFSET_Y + totalH - 1)
    end
    -- Horizontale Tile-Grenzen
    for s = 0, SLOTS do
        local y = OFFSET_Y + s * TILE_SIZE * CELL_SIZE
        gfx.drawLine(OFFSET_X, y, OFFSET_X + totalW - 1, y)
    end

    -- 4. Cursor zeichnen (invertierter 3×3-Pixel-Dot, nur wenn Blinker an)
    if cursorBlinker.on then
        local cx = OFFSET_X + (cursorCol - 1) * CELL_SIZE
        local cy = OFFSET_Y + (cursorRow - 1) * CELL_SIZE
        local isBlack = gridState[cursorRow][cursorCol]
        if isBlack then
            gfx.setColor(gfx.kColorWhite)
        else
            gfx.setColor(gfx.kColorBlack)
        end
        -- Zentraler Dot: 3×3 px innerhalb der 5×5-Zelle (1px Rand)
        gfx.fillRect(cx + 1, cy + 1, CELL_SIZE - 2, CELL_SIZE - 2)
    end
end

-- ── Interne Aktionen ──────────────────────────────────────────────────────────

-- Zoom-In: aktuellen Slot-Tile-Inhalt an PixelRoom übergeben und dorthin wechseln.
-- Out-of-bounds-Slots (tileIndex == 0 und originalTileIndex == 0) können nicht gezoomt werden.
local function zoomIntoPixelRoom()
    local slotRow, slotCol = getSlotForCell(cursorRow, cursorCol)
    local slot = tileSlots[slotRow][slotCol]
    -- Nur in gültige (in-bounds) Slots zoomen
    if slot.originalTileIndex == 0 and slot.tileIndex == 0 then
        return  -- Out-of-bounds-Slot: Zoom abbrechen
    end
    lastEditedSlotRow = slotRow
    lastEditedSlotCol = slotCol
    local tile    = buildTileImageForSlot(slotRow, slotCol)
    local tileIdx = slot.tileIndex
    pixelRoom:setCurrentTile(tile, tileIdx)
    switchRoomFunction(pixelRoom)
end

-- Commit: geaenderte, gueltige Slots als Batch an TileRoom uebergeben, dann zurueckwechseln.
-- Out-of-bounds-Slots (originalTileIndex == 0 und tileIndex == 0) werden uebersprungen.
local function commitAndReturnToTileRoom()
    local edits = {}
    for sr = 1, SLOTS do
        for sc = 1, SLOTS do
            local slot = tileSlots[sr][sc]
            -- Out-of-bounds-Slots überspringen (waren von Anfang an ungültig)
            if slot.originalTileIndex > 0 or slot.tileIndex > 0 then
                -- Tilemap-Koordinaten berechnen: Cursor-Slot ist immer (2,2)
                local dr = sr - 2
                local dc = sc - 2
                local tileCol = contextCursorTileCol + dc
                local tileRow = contextCursorTileRow + dr
                local img = buildTileImageForSlot(sr, sc)
                -- Nur geaenderte Tiles committen.
                -- Geaenderte Tiles gehen immer ueber den Neu/Dedupe-Pfad in TileRoom
                -- (findOrAppendImage + Hashvergleich), analog zum PixelRoom-Standardpfad.
                if not imagesEqual(img, slot.originalTileImage) then
                    table.insert(edits, {
                        tileCol       = tileCol,
                        tileRow       = tileRow,
                        image         = img,
                        existingIndex = 0
                    })
                end
            end
        end
    end
    if #edits > 0 then
        tileRoom:applyTileEditsBatch(edits)
    end
    switchRoomFunction(tileRoom)
end

-- Toggelt Zellinhalt an der aktuellen Cursor-Position.
local function toggleCurrentCell()
    gridState[cursorRow][cursorCol] = not gridState[cursorRow][cursorCol]
    needsRedraw = true
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- Initialisiert ZoomRoom mit Abhängigkeiten.
-- switchRoom      : globale switchRoom-Funktion aus main.lua
-- nextPixelRoom   : PixelRoom-Objekt (Zoom-In-Ziel)
-- nextTileRoom    : TileRoom-Objekt (Commit-Ziel / Zoom-Out)
function ZoomRoom:init(switchRoom, nextPixelRoom, nextTileRoom)
    switchRoomFunction = switchRoom
    pixelRoom          = nextPixelRoom
    tileRoom           = nextTileRoom

    -- gridState auf weiß initialisieren
    for r = 1, GRID_ROWS do
        gridState[r] = {}
        for c = 1, GRID_COLS do
            gridState[r][c] = false
        end
    end

    -- tileSlots initialisieren (alle leer/ungültig)
    for sr = 1, SLOTS do
        tileSlots[sr] = {}
        for sc = 1, SLOTS do
            tileSlots[sr][sc] = { tileIndex = 0, originalTileIndex = 0 }
        end
    end

    -- Cursor auf Mitte des Zentrums-Tiles
    cursorRow = TILE_SIZE + math.ceil(TILE_SIZE / 2)  -- Zeile 12
    cursorCol = TILE_SIZE + math.ceil(TILE_SIZE / 2)  -- Spalte 12

    needsRedraw = true
end

-- Empfängt 3×3-Tile-Kontext von TileRoom und befüllt gridState + tileSlots.
-- context = {
--   tiles        = { [1..9] = gfx.image|nil },   -- nil für out-of-bounds
--   tileIndices  = { [1..9] = int },              -- 1-basierter Imagetable-Index
--   cursorSlot   = int  (1-9, Standard 5 = Mitte)
-- }
function ZoomRoom:setFromTileContext(context)
    -- Tilemap-Cursor-Koordinaten für späteres Commit speichern
    contextCursorTileCol = context.cursorTileCol or 1
    contextCursorTileRow = context.cursorTileRow or 1
    showGridLines        = (context.showGrid ~= false)  -- nil zählt als true

    local slotIdx = 1
    for sr = 1, SLOTS do
        tileSlots[sr] = tileSlots[sr] or {}
        for sc = 1, SLOTS do
            local tile      = context.tiles[slotIdx]
            local tileIndex = context.tileIndices[slotIdx] or 0
            tileSlots[sr][sc] = {
                tileIndex         = tileIndex,
                originalTileIndex = tileIndex,
                originalTileImage = tile
            }
            -- nil-Tiles (out-of-bounds) werden in decodeTileIntoGridState auf weiß gesetzt
            decodeTileIntoGridState(tile, sr, sc)
            slotIdx = slotIdx + 1
        end
    end

    -- Cursor auf Zentrum des angegebenen Slots positionieren
    local cs    = context.cursorSlot or 5
    local csRow = math.ceil(cs / SLOTS)
    local csCol = ((cs - 1) % SLOTS) + 1
    cursorRow = (csRow - 1) * TILE_SIZE + math.ceil(TILE_SIZE / 2)
    cursorCol = (csCol - 1) * TILE_SIZE + math.ceil(TILE_SIZE / 2)

    lastEditedSlotRow = nil
    lastEditedSlotCol = nil
    needsRedraw = true
end

-- Empfängt ein neues (dedupliziertes) Tile von PixelRoom nach dem Zoom-Back.
-- Wird ins gridState des zuletzt bearbeiteten Slots dekodiert; tileIndex = 0
-- signalisiert beim Commit, dass TileRoom ein neues Tile anlegen soll.
function ZoomRoom:setNewTile(tile)
    if lastEditedSlotRow and lastEditedSlotCol then
        decodeTileIntoGridState(tile, lastEditedSlotRow, lastEditedSlotCol)
        tileSlots[lastEditedSlotRow][lastEditedSlotCol].tileIndex = 0
    end
    needsRedraw = true
end

-- Empfaengt ein aktualisiertes Tile von PixelRoom nach dem Zoom-Back.
-- Das Tile wird ins gridState dekodiert; der tileIndex wird nur als Rueckgabe-Metadatum mitgefuehrt.
-- Beim Commit nutzt ZoomRoom fuer geaenderte Slots immer den Neu/Dedupe-Pfad.
function ZoomRoom:updateExistingTile(tile, tileIndex)
    if lastEditedSlotRow and lastEditedSlotCol then
        decodeTileIntoGridState(tile, lastEditedSlotRow, lastEditedSlotCol)
        tileSlots[lastEditedSlotRow][lastEditedSlotCol].tileIndex = tileIndex or 0
    end
    needsRedraw = true
end

-- ── Room-Lifecycle ────────────────────────────────────────────────────────────

function ZoomRoom:entered()
    needsRedraw = true
    local menu = playdate.getSystemMenu()
    menu:removeAllMenuItems()
    print("Entered ZoomRoom")
end

function ZoomRoom:update()
    cursorBlinker:updateAll()
    if cursorBlinker.on ~= lastBlinkState then
        lastBlinkState = cursorBlinker.on
        needsRedraw = true
    end

    -- Zoom-Trigger: B gehalten + Crank
    if upHeld then
        ticks += playdate.getCrankTicks(4)
        if ticks >= 4 then
            ticks = 0
            -- Crank vorwärts → in PixelRoom zoomen
            zoomIntoPixelRoom()
        elseif ticks <= -4 then
            ticks = 0
            -- Crank rückwärts → commit und zurück zu TileRoom
            commitAndReturnToTileRoom()
        end
    else
        ticks = 0
    end

    if needsRedraw then
        gfx.clear(gfx.kColorWhite)
        drawGrid()
        needsRedraw = false
    end

    playdate.timer.updateTimers()
end

function ZoomRoom:inputHandler()
    return {
        upButtonDown = function()
            upHeld = false
            if cursorRow > 1 then cursorRow = cursorRow - 1 end
            needsRedraw = true
        end,
        upButtonUp = function()
            upHeld = false
        end,
        downButtonDown = function()
            upHeld = false
            if cursorRow < GRID_ROWS then cursorRow = cursorRow + 1 end
            needsRedraw = true
        end,
        leftButtonDown = function()
            upHeld = false
            if cursorCol > 1 then cursorCol = cursorCol - 1 end
            needsRedraw = true
        end,
        rightButtonDown = function()
            upHeld = false
            if cursorCol < GRID_COLS then cursorCol = cursorCol + 1 end
            needsRedraw = true
        end,
        AButtonDown = function()
            upHeld = false
            toggleCurrentCell()
        end,
        BButtonDown = function()
            upHeld = true
        end,
        BButtonUp = function()
            upHeld = false
        end
    }
end
