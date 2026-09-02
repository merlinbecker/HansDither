-- ZoomRoom.lua
-- Mittlerer Zoom-Raum zwischen EditorRoom (25×15 Tiles à 16×16 px) und PixelRoom (16×16 px).
-- Zeigt den 3×3-Tile-Kontext um den Cursor als 24×24-Malraster; eine Zelle
-- entspricht einem 2×2-Pixelblock des Tiles (FR-010, halbe Auflösung).
-- Commit beim Rauszoomen läuft über EditorRoom:applyTileEdits (Dedup-Pfad, FR-012).

import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/crank"
import "PencilCursor"
import "PixelTransparency"
import "ImageStoreCodec"
import "UndoPrompt"   -- Spec 011: modaler Undo-Dialog (gemeinsames Singleton)

local gfx = playdate.graphics

ZoomRoom = {}

-- ── Konstanten ────────────────────────────────────────────────────────────────

local CELLS_PER_TILE = 8   -- Rasterzellen pro Tile (16 px / 2 px pro Zelle)
local PX_PER_CELL = 2      -- native Pixel pro Rasterzelle (2×2-Block, FR-010)
local TILE_PX = 16         -- Pixel pro Tile
local SLOTS = 3            -- Raster: 3×3 Tile-Slots
local GRID_COLS = CELLS_PER_TILE * SLOTS  -- 24 Zellen
local GRID_ROWS = CELLS_PER_TILE * SLOTS  -- 24 Zellen
local CELL_SIZE = 10       -- px pro Zelle auf dem Display (240×240 zentriert)
local SUBPIXEL_SIZE = 5    -- CELL_SIZE / 2: Kantenlaenge je Subpixel-Quadrant (R2, FR-007/009)

-- Grid zentriert: (400 - 240) / 2 = 80 px links, 0 px oben
local OFFSET_X = 80
local OFFSET_Y = 0

-- Strichelung für Zellgrenzen innerhalb der Tiles
local DASH_LEN = 2
local GAP_LEN = 2

local HOLD_INITIAL_DELAY_MS = 220
local HOLD_REPEAT_MS = 80

-- ── Modul-State ───────────────────────────────────────────────────────────────

local switchRoomFunction
local pixelRoom
local editorRoom

-- showGridLines: vom EditorRoom übernommen (FR-015)
local showGridLines = true

-- slots[slotRow][slotCol] = {tileX, tileY, frameIndexPos, originalIndex, originalImage, oob, editedImage}
local slots = {}

-- gridState[row][col] = bool (true = schwarz); baselineGrid = Dekodier-Snapshot
-- der Basisbilder — Zellen, die davon abweichen, hat der Nutzer geändert.
local gridState = {}
local baselineGrid = {}

-- Referenz auf imageData des Editors (für "All Similar" in-place, FR-015)
local imageDataRef = nil

-- Spec 010: ist die aktive Ebene die Basisebene? Bestimmt den "Nicht-Tinte"-
-- Zustand im PixelRoom (weiss vs. transparent). Default true (Basisebene).
local activeLayerIsBase = true

-- Cursor im 24×24-Grid (1-basiert)
local cursorRow = 12
local cursorCol = 12

-- Slot, in den zuletzt in den PixelRoom gezoomt wurde
local lastEditedSlotRow = nil
local lastEditedSlotCol = nil

local needsRedraw = true

-- Spec 008 (AD-035): statischer Hintergrund-Cache statt Vollbild-Neuzeichnung
-- pro Interaktion. cachedBackground enthaelt Checkerboard-Seiten, alle Zellen
-- im unbearbeiteten Subpixel-Zustand und die Gitterlinien; changedCells
-- sammelt die seit dem letzten Cache-Aufbau tatsaechlich geaenderten Zellen.
local cachedBackground = nil
local changedCells = {}
local backgroundDirty = true

-- Crank-Akkumulator (analog zu EditorRoom/PixelRoom)
local ticks = 0

local directionHold = {
    up = { active = false, nextMs = 0 },
    down = { active = false, nextMs = 0 },
    left = { active = false, nextMs = 0 },
    right = { active = false, nextMs = 0 }
}

-- ── Hilfsfunktionen ───────────────────────────────────────────────────────────

local function getSlotForCell(row, col)
    return math.ceil(row / CELLS_PER_TILE), math.ceil(col / CELLS_PER_TILE)
end

-- Dekodiert ein 16×16-Image mit 2×2-Blockauslese in gridState + baselineGrid.
-- nil (out-of-bounds) setzt alle Zellen des Slots auf weiß.
local function decodeImageIntoGrids(img, slotRow, slotCol)
    local baseRow = (slotRow - 1) * CELLS_PER_TILE
    local baseCol = (slotCol - 1) * CELLS_PER_TILE
    for r = 1, CELLS_PER_TILE do
        for c = 1, CELLS_PER_TILE do
            local value = false
            if img then
                value = (img:sample((c - 1) * PX_PER_CELL, (r - 1) * PX_PER_CELL) == gfx.kColorBlack)
            end
            gridState[baseRow + r][baseCol + c] = value
            baselineGrid[baseRow + r][baseCol + c] = value
        end
    end
end

-- Baut das aktuelle 16×16-Arbeitsbild eines Slots: Basisbild (editiert oder
-- original) plus alle Zellabweichungen als 2×2-Blöcke (erhält Pixel-Details,
-- die feiner als das 24×24-Raster sind).
--
-- Spec 010 / Review F6: der "aus"-Zustand einer Zelle ist ebenenabhaengig.
-- Auf der Basisebene ist er opakes Weiss; auf einer OBEREN Ebene (2/3) muss er
-- `kColorClear` (transparent) sein — sonst stanzt das Radieren eines Pixels ein
-- opakes weisses Loch, das die darunterliegenden Ebenen beim Compositing/Save
-- verdeckt (nur ein KOMPLETT weisses Tile mappt `writeActiveLayerPosition`
-- wieder auf ABSENT). Konsistent mit PixelRoom, das ebenfalls nach `kColorClear`
-- radiert.
local function buildWorkingImage(slotRow, slotCol)
    local slot = slots[slotRow][slotCol]
    local base = slot.editedImage or slot.originalImage
    local offColor = activeLayerIsBase and gfx.kColorWhite or gfx.kColorClear
    local img
    if base then
        img = base:copy()
    else
        -- eine noch nicht in der Tilemap vorhandene Zelle ("absent") faengt auf
        -- der Basisebene weiss an, auf den Ebenen 2-3 transparent.
        img = gfx.image.new(TILE_PX, TILE_PX, offColor)
    end
    local baseRow = (slotRow - 1) * CELLS_PER_TILE
    local baseCol = (slotCol - 1) * CELLS_PER_TILE
    gfx.pushContext(img)
        for r = 1, CELLS_PER_TILE do
            for c = 1, CELLS_PER_TILE do
                local value = gridState[baseRow + r][baseCol + c]
                if value ~= baselineGrid[baseRow + r][baseCol + c] then
                    gfx.setColor(value and gfx.kColorBlack or offColor)
                    gfx.fillRect((c - 1) * PX_PER_CELL, (r - 1) * PX_PER_CELL, PX_PER_CELL, PX_PER_CELL)
                end
            end
        end
    gfx.popContext()
    return img
end

-- Sichtbarkeits-Vergleich zweier Tiles: gemeinsame Implementierung im Codec
local imagesEqual = ImageStoreCodec.imagesVisiblyEqual

local function slotHasCellEdits(slotRow, slotCol)
    local baseRow = (slotRow - 1) * CELLS_PER_TILE
    local baseCol = (slotCol - 1) * CELLS_PER_TILE
    for r = 1, CELLS_PER_TILE do
        for c = 1, CELLS_PER_TILE do
            if gridState[baseRow + r][baseCol + c] ~= baselineGrid[baseRow + r][baseCol + c] then
                return true
            end
        end
    end
    return false
end

-- ── Rendering ─────────────────────────────────────────────────────────────────

local function drawDashedVLine(x, y1, y2)
    local y = y1
    while y < y2 do
        local yEnd = math.min(y + DASH_LEN - 1, y2 - 1)
        gfx.drawLine(x, y, x, yEnd)
        y = y + DASH_LEN + GAP_LEN
    end
end

local function drawDashedHLine(x1, x2, y)
    local x = x1
    while x < x2 do
        local xEnd = math.min(x + DASH_LEN - 1, x2 - 1)
        gfx.drawLine(x, y, xEnd, y)
        x = x + DASH_LEN + GAP_LEN
    end
end

-- Zeichnet genau eine Zelle an ihrer Bildschirmposition: unbearbeitete Zellen
-- zeigen die echten 2x2-Quellpixel als vier 5x5-Subpixel-Quadranten (R2,
-- FR-007/009); bearbeitete Zellen bleiben ein flaechiger 10x10-Block (FR-008
-- - Editier-Ergebnis ist real einheitlich, keine Subpixel-Illusion vortaeuschen).
-- Wird sowohl beim einmaligen Cache-Aufbau (alle Zellen) als auch beim
-- Overlay-Redraw (nur changedCells) verwendet (Spec 008, AD-035).
--
-- Onion-Skin (Bugfix, Debugging-Session 2026-09-01): fehlt der aktiven Ebene
-- an dieser Stelle ein Pixel (kColorClear oder die Zelle traegt ueberhaupt
-- kein Tile bei — "absent"), scheint slot.backgroundImage durch (die darunter
-- liegenden Ebenen, pixelgenau vorkompositiert von EditorRoom.buildZoomContext
-- via LayerModel.compositeBelow). Rein visuell — editiert/committet wird
-- weiterhin ausschliesslich fg (die aktive Ebene selbst, siehe buildWorkingImage).
local function sampleWithBackground(fg, bg, px, py)
    local sample = fg and fg:sample(px, py) or nil
    if sample == nil or sample == gfx.kColorClear then
        sample = bg and bg:sample(px, py) or gfx.kColorWhite
    end
    return sample
end

local function drawCell(r, c)
    local x = OFFSET_X + (c - 1) * CELL_SIZE
    local y = OFFSET_Y + (r - 1) * CELL_SIZE
    local sr, sc = getSlotForCell(r, c)
    local slot = slots[sr][sc]
    local fg = (slot and not slot.oob) and (slot.editedImage or slot.originalImage) or nil
    local bg = (slot and not slot.oob) and slot.backgroundImage or nil
    local base = fg or bg

    if base and gridState[r][c] == baselineGrid[r][c] then
        local baseRow = (sr - 1) * CELLS_PER_TILE
        local baseCol = (sc - 1) * CELLS_PER_TILE
        local px = (c - baseCol - 1) * PX_PER_CELL
        local py = (r - baseRow - 1) * PX_PER_CELL
        local quadrants = {
            { sampleWithBackground(fg, bg, px, py), x, y },
            { sampleWithBackground(fg, bg, px + 1, py), x + SUBPIXEL_SIZE, y },
            { sampleWithBackground(fg, bg, px, py + 1), x, y + SUBPIXEL_SIZE },
            { sampleWithBackground(fg, bg, px + 1, py + 1), x + SUBPIXEL_SIZE, y + SUBPIXEL_SIZE }
        }
        for _, q in ipairs(quadrants) do
            gfx.setColor(q[1] == gfx.kColorBlack and gfx.kColorBlack or gfx.kColorWhite)
            gfx.fillRect(q[2], q[3], SUBPIXEL_SIZE, SUBPIXEL_SIZE)
        end
    else
        gfx.setColor(gridState[r][c] and gfx.kColorBlack or gfx.kColorWhite)
        gfx.fillRect(x, y, CELL_SIZE, CELL_SIZE)
    end
end

-- Baut den statischen Hintergrund (Checkerboard-Seiten, alle 576 Zellen im
-- jeweils aktuellen Zustand, Gitterlinien) einmalig in cachedBackground
-- (Spec 008, AD-035, research.md R1) statt ihn bei jeder Interaktion neu zu
-- berechnen. Wird nur bei backgroundDirty (Kontextwechsel, neues Tile,
-- Grid-Toggle) aufgerufen, nicht bei reiner Cursorbewegung/Malstrich.
local function buildBackgroundCache()
    local totalW = GRID_COLS * CELL_SIZE
    local totalH = GRID_ROWS * CELL_SIZE
    local canvasW = OFFSET_X + totalW + OFFSET_X

    if not cachedBackground then
        cachedBackground = gfx.image.new(canvasW, totalH)
    end

    gfx.pushContext(cachedBackground)
        gfx.setPattern({ 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55 })
        gfx.fillRect(0, 0, OFFSET_X, totalH)
        gfx.fillRect(OFFSET_X + totalW, 0, OFFSET_X, totalH)
        gfx.setColor(gfx.kColorBlack)

        for r = 1, GRID_ROWS do
            for c = 1, GRID_COLS do
                drawCell(r, c)
            end
        end

        if showGridLines then
            gfx.setColor(gfx.kColorBlack)
            for c = 1, GRID_COLS - 1 do
                if c % CELLS_PER_TILE ~= 0 then
                    drawDashedVLine(OFFSET_X + c * CELL_SIZE, OFFSET_Y, OFFSET_Y + totalH)
                end
            end
            for r = 1, GRID_ROWS - 1 do
                if r % CELLS_PER_TILE ~= 0 then
                    drawDashedHLine(OFFSET_X, OFFSET_X + totalW, OFFSET_Y + r * CELL_SIZE)
                end
            end
        end

        gfx.setColor(gfx.kColorBlack)
        for s = 0, SLOTS do
            local x = OFFSET_X + s * CELLS_PER_TILE * CELL_SIZE
            gfx.drawLine(x, OFFSET_Y, x, OFFSET_Y + totalH - 1)
            local y = OFFSET_Y + s * CELLS_PER_TILE * CELL_SIZE
            gfx.drawLine(OFFSET_X, y, OFFSET_X + totalW - 1, y)
        end
    gfx.popContext()

    changedCells = {}
    backgroundDirty = false
end

-- Redraw (Spec 008, AD-035, Contract ZR-01): blittet den Cache (ein Aufruf)
-- und uebermalt nur tatsaechlich geaenderte Zellen statt das gesamte Raster
-- neu zu berechnen. Editier-/Commit-Logik bleibt unveraendert (Contract ZR-03).
local function drawGrid()
    if backgroundDirty or not cachedBackground then
        buildBackgroundCache()
    end

    cachedBackground:draw(0, 0)

    -- WICHTIG: changedCells NICHT hier leeren - der Cache selbst kennt diese
    -- Aenderungen nicht (nur ein voller Rebuild in buildBackgroundCache()
    -- uebernimmt sie dauerhaft). Wuerde die Liste hier geleert, wuerde die
    -- Zelle beim naechsten Redraw wieder auf den (veralteten) Cache-Stand
    -- zurueckfallen - genau der zuvor beobachtete Bug (Malstrich verschwindet
    -- bei der naechsten Cursorbewegung).
    for _, cell in ipairs(changedCells) do
        drawCell(cell.row, cell.col)
    end

    -- Cursor
    local cx = OFFSET_X + (cursorCol - 1) * CELL_SIZE
    local cy = OFFSET_Y + (cursorRow - 1) * CELL_SIZE
    PencilCursor.draw(cx, cy, CELL_SIZE, CELL_SIZE)
end

-- ── Interne Aktionen ──────────────────────────────────────────────────────────

-- Zoom-In: Arbeitsbild des Cursor-Slots an PixelRoom übergeben (Z-02: nur in-bounds).
local function zoomIntoPixelRoom()
    local slotRow, slotCol = getSlotForCell(cursorRow, cursorCol)
    local slot = slots[slotRow][slotCol]
    if not slot or slot.oob then
        return
    end
    lastEditedSlotRow = slotRow
    lastEditedSlotCol = slotCol
    -- Spec 010: "Nicht-Tinte"-Zustand je aktiver Ebene weiterreichen.
    local offStateCode = activeLayerIsBase and PixelTransparency.EMPTY or PixelTransparency.TRANSPARENT
    pixelRoom:setCurrentTile(buildWorkingImage(slotRow, slotCol), slot.originalIndex, offStateCode)
    switchRoomFunction(pixelRoom)
end

-- Sammelt Edits aller geänderten in-bounds-Slots (Z-03: kein Commit ohne Änderung).
local function collectEdits()
    local edits = {}
    for sr = 1, SLOTS do
        for sc = 1, SLOTS do
            local slot = slots[sr][sc]
            if slot and not slot.oob then
                if slot.editedImage ~= nil or slotHasCellEdits(sr, sc) then
                    local img = buildWorkingImage(sr, sc)
                    if not imagesEqual(img, slot.originalImage) then
                        table.insert(edits, {
                            frameIndexPos = slot.frameIndexPos,
                            newImage = img
                        })
                    end
                end
            end
        end
    end
    return edits
end

local function commitAndReturnToEditor()
    local edits = collectEdits()
    if #edits > 0 then
        editorRoom:applyTileEdits(edits)
    end
    if editorRoom.endShiftRun then editorRoom:endShiftRun() end  -- Spec 011: Verschiebe-Run schliessen
    switchRoomFunction(editorRoom)
end

-- Spec 010 US1 (revidiert 2026-09-01, Einschraenkung aus dem Hardware-Test):
-- B + Pfeiltaste verschiebt den Inhalt der Zelle unter dem Zoom-Cursor um 1
-- nativen Pixel (nicht den ganzen Screen). Der Inhalt wandert dabei in die
-- Nachbarzelle in Schieberichtung und bleibt dort (2-Tile-Streifen, siehe
-- LayerModel.shiftTileContent). Vorher werden offene Zell-Edits des
-- Zoomrasters committet. Danach den 3x3-Kontext frisch holen, aber den
-- Zoom-Cursor stehen lassen, damit wiederholtes B + Pfeil dieselbe Zelle
-- weiterschiebt. Nur der aktuelle Frame ist betroffen (FR-004).
local function shiftActiveLayerContent(direction)
    if not (editorRoom and editorRoom.shiftActiveLayer) then return end
    local edits = collectEdits()
    if #edits > 0 and editorRoom.applyTileEdits then
        editorRoom:applyTileEdits(edits)
    end
    local sr, sc = getSlotForCell(cursorRow, cursorCol)
    local slot = slots[sr] and slots[sr][sc]
    if not slot or slot.oob then return end
    if editorRoom:shiftActiveLayer(direction, slot.frameIndexPos) then
        if editorRoom.currentZoomContext then
            -- setFromEditorContext() zentriert den Cursor und setzt `ticks`
            -- auf 0. Cursor hier bewusst zuruecksetzen (dieselbe Zelle bleibt
            -- Ziel); `ticks`-Reset ist gewollt (ein Shift ist kein Zoom).
            local savedRow, savedCol = cursorRow, cursorCol
            ZoomRoom:setFromEditorContext(editorRoom:currentZoomContext())
            cursorRow, cursorCol = savedRow, savedCol
        end
        needsRedraw = true
        backgroundDirty = true
    end
end

-- Pencil-Strich: Der A-Druck bestimmt den Malwert des ganzen Strichs —
-- Zelle war schwarz -> Strich malt Weiß (Radierer), sonst Schwarz.
-- Bewegungen mit gehaltenem A malen denselben Wert weiter.
local strokeValue = nil  -- true/false = Malwert des laufenden Strichs, nil = kein Strich

-- Traegt eine Zelle in changedCells ein, falls noch nicht enthalten (Spec 008,
-- data-model.md Abschnitt 1) - Grundlage fuer den Overlay-Redraw in drawGrid().
local function markCellChanged(row, col)
    for _, cell in ipairs(changedCells) do
        if cell.row == row and cell.col == col then
            return
        end
    end
    table.insert(changedCells, { row = row, col = col })
end

local function paintCurrentCell(value)
    gridState[cursorRow][cursorCol] = value
    markCellChanged(cursorRow, cursorCol)
    needsRedraw = true
end

local function beginStroke()
    strokeValue = not gridState[cursorRow][cursorCol]
    paintCurrentCell(strokeValue)
end

local function endStroke()
    strokeValue = nil
end

local function moveCursor(direction)
    local oldRow = cursorRow
    local oldCol = cursorCol

    if direction == "up" then
        if cursorRow > 1 then cursorRow = cursorRow - 1 end
    elseif direction == "down" then
        if cursorRow < GRID_ROWS then cursorRow = cursorRow + 1 end
    elseif direction == "left" then
        if cursorCol > 1 then cursorCol = cursorCol - 1 end
    elseif direction == "right" then
        if cursorCol < GRID_COLS then cursorCol = cursorCol + 1 end
    else
        return
    end

    if oldRow ~= cursorRow or oldCol ~= cursorCol then
        -- Laufender A-Strich malt weiter (SDK: playdate.buttonIsPressed)
        if strokeValue ~= nil and playdate.buttonIsPressed(playdate.kButtonA) then
            paintCurrentCell(strokeValue)
        else
            needsRedraw = true
        end
    end
end

local function startDirectionHold(direction)
    local state = directionHold[direction]
    if not state then return end
    moveCursor(direction)
    state.active = true
    state.nextMs = playdate.getCurrentTimeMilliseconds() + HOLD_INITIAL_DELAY_MS
end

local function stopDirectionHold(direction)
    local state = directionHold[direction]
    if not state then return end
    state.active = false
end

local function clearDirectionHold()
    for _, state in pairs(directionHold) do
        state.active = false
    end
end

local function processDirectionHold()
    local nowMs = playdate.getCurrentTimeMilliseconds()
    local buttonByDirection = {
        up = playdate.kButtonUp,
        down = playdate.kButtonDown,
        left = playdate.kButtonLeft,
        right = playdate.kButtonRight
    }
    for direction, state in pairs(directionHold) do
        if state.active then
            local button = buttonByDirection[direction]
            if not playdate.buttonIsPressed(button) then
                state.active = false
            elseif nowMs >= state.nextMs then
                moveCursor(direction)
                state.nextMs = nowMs + HOLD_REPEAT_MS
            end
        end
    end
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- switchRoom     : globale switchRoom-Funktion aus main.lua
-- nextPixelRoom  : PixelRoom-Objekt (Zoom-In-Ziel)
-- nextEditorRoom : EditorRoom-Objekt (Commit-Ziel / Zoom-Out)
function ZoomRoom:init(switchRoom, nextPixelRoom, nextEditorRoom)
    switchRoomFunction = switchRoom
    pixelRoom = nextPixelRoom
    editorRoom = nextEditorRoom

    for r = 1, GRID_ROWS do
        gridState[r] = {}
        baselineGrid[r] = {}
        for c = 1, GRID_COLS do
            gridState[r][c] = false
            baselineGrid[r][c] = false
        end
    end

    for sr = 1, SLOTS do
        slots[sr] = {}
        for sc = 1, SLOTS do
            slots[sr][sc] = { oob = true }
        end
    end

    cursorRow = CELLS_PER_TILE + math.ceil(CELLS_PER_TILE / 2)
    cursorCol = CELLS_PER_TILE + math.ceil(CELLS_PER_TILE / 2)

    needsRedraw = true
end

-- Empfängt den 3×3-Kontext vom EditorRoom (contracts Abschnitt 3):
-- ctx = { slots (3×3, je {tileX, tileY, frameIndexPos, originalIndex, originalImage, oob}),
--         gridState (24×24, 2×2-Blockauslese), showGrid, imageData }
function ZoomRoom:setFromEditorContext(ctx)
    imageDataRef = ctx.imageData
    showGridLines = (ctx.showGrid ~= false)
    activeLayerIsBase = (ctx.activeLayerIsBase ~= false)  -- Default: Basisebene

    for sr = 1, SLOTS do
        for sc = 1, SLOTS do
            local slot = ctx.slots[sr][sc]
            slot.editedImage = nil
            slots[sr][sc] = slot
        end
    end

    for r = 1, GRID_ROWS do
        for c = 1, GRID_COLS do
            local value = ctx.gridState[r][c] and true or false
            gridState[r][c] = value
            baselineGrid[r][c] = value
        end
    end

    -- Cursor auf Zentrum des mittleren Slots (= Editor-Cursor-Tile)
    cursorRow = CELLS_PER_TILE + math.ceil(CELLS_PER_TILE / 2)
    cursorCol = CELLS_PER_TILE + math.ceil(CELLS_PER_TILE / 2)

    lastEditedSlotRow = nil
    lastEditedSlotCol = nil
    ticks = 0
    needsRedraw = true
    backgroundDirty = true -- Spec 008 (AD-035): neuer Kontext invalidiert den Cache
end

-- Empfängt ein bearbeitetes Tile von PixelRoom (Standardpfad: Dedup beim Commit).
function ZoomRoom:setNewTile(tile)
    if lastEditedSlotRow and lastEditedSlotCol then
        local slot = slots[lastEditedSlotRow][lastEditedSlotCol]
        slot.editedImage = tile
        decodeImageIntoGrids(tile, lastEditedSlotRow, lastEditedSlotCol)
        -- Spec 011: hat der PixelRoom in dieser Sitzung rotiert, den Pre-Rotation-
        -- Zustand dieser Zelle in den Undo-Verlauf geben (frameIndexPos = 1..375).
        if pixelRoom and pixelRoom.consumeRotationSnapshot
            and editorRoom and editorRoom.recordRotation then
            local prevImg = pixelRoom:consumeRotationSnapshot()
            if prevImg and slot.frameIndexPos then
                editorRoom:recordRotation(slot.frameIndexPos, prevImg)
            end
        end
    end
    needsRedraw = true
    backgroundDirty = true -- Spec 008 (AD-035): Quellbild des Slots hat sich geaendert
end

-- "All Similar" (FR-015, FR-013-Ausnahme): überschreibt das Tile in-place in der
-- Imagetable und wirkt damit auf alle Verwendungen über alle Frames hinweg.
function ZoomRoom:updateExistingTile(tile, tileIndex)
    if not (imageDataRef and tileIndex and tileIndex > 0) then
        ZoomRoom:setNewTile(tile)
        return
    end

    local imagetable = imageDataRef.imagetable
    local oldImage = imagetable:getImage(tileIndex)
    if oldImage then
        local oldHash = ImageStoreCodec.hashTile(oldImage)
        if imageDataRef.hashIndex[oldHash] == tileIndex then
            imageDataRef.hashIndex[oldHash] = nil
        end
    end
    imagetable:setImage(tileIndex, tile)
    imageDataRef.hashIndex[ImageStoreCodec.hashTile(tile)] = tileIndex

    -- Alle Kontext-Slots mit diesem Index zeigen jetzt das geänderte Tile
    for sr = 1, SLOTS do
        for sc = 1, SLOTS do
            local slot = slots[sr][sc]
            if slot and not slot.oob and slot.originalIndex == tileIndex then
                slot.originalImage = tile
                slot.editedImage = nil
                decodeImageIntoGrids(tile, sr, sc)
            end
        end
    end
    needsRedraw = true
    backgroundDirty = true -- Spec 008 (AD-035): ein oder mehrere Slot-Quellbilder haben sich geaendert
end

-- Terminate-Hook (Contract E-03): ausstehende Änderungen ohne Room-Wechsel committen.
function ZoomRoom:commitForTerminate()
    local edits = collectEdits()
    if #edits > 0 and editorRoom then
        editorRoom:applyTileEdits(edits)
    end
end

-- ── Room-Lifecycle ────────────────────────────────────────────────────────────

function ZoomRoom:entered()
    clearDirectionHold()
    endStroke()
    ticks = 0
    needsRedraw = true
    backgroundDirty = true -- Spec 008 (AD-035): defensiv, setFromEditorContext() setzt es bereits
    playdate.startAccelerometer()   -- Spec 011 (FR-017): Sensor in den Editier-Views aktiv
    if editorRoom and editorRoom.endShiftRun then editorRoom:endShiftRun() end  -- Spec 011: Run nicht ueber Zoom->Pixel->Zoom offen lassen
    playdate.getSystemMenu():removeAllMenuItems()
end

function ZoomRoom:update()
    processDirectionHold()

    -- Spec 011: Schuettel-Sample lesen + an EditorRoom weiterreichen. Erkennt der
    -- Detektor eine Kante, committet der Callback SOFORT (synchron) und wechselt
    -- in den Tile View (V25). Review F9: danach MUSS update() zurueckkehren --
    -- sonst laeuft der Rest (Crank-Block, gfx.clear + drawGrid + UndoPrompt.draw)
    -- weiter und malt das Zoom-Raster fuer einen Frame ueber den neuen Raum.
    do
        local ax, ay, az = playdate.readAccelerometer()
        if ax and editorRoom and editorRoom.onShakeSample then
            local roomLeft = false
            editorRoom:onShakeSample(ax, ay, az, function()
                roomLeft = true
                commitAndReturnToEditor()
            end)
            if roomLeft then return end
        end
    end

    -- Zoom-Trigger: B gehalten + Crank. Ticks in jedem Update lesen (stateful),
    -- ohne B verwerfen — sonst entlaedt sich aufgestauter Zaehler beim ersten B-Frame.
    local crankTicks = playdate.getCrankTicks(4) or 0
    local bHeld = playdate.buttonIsPressed(playdate.kButtonB)
    if UndoPrompt.isOpen() then
        ticks = 0   -- Spec 011: bei offenem Dialog keine Zoom-/Shift-Aktion
    elseif bHeld then
        -- Standard-Lua statt pdc-Kurzform "+=" (haelt die Datei headless testbar)
        ticks = ticks + crankTicks
        if ticks >= 4 then
            ticks = 0
            zoomIntoPixelRoom()
            return   -- Review F9: Raum gewechselt -> restliches update() nicht mehr ausfuehren
        elseif ticks <= -4 then
            ticks = 0
            commitAndReturnToEditor()
            return   -- Review F9: dito
        end
    else
        ticks = 0
    end

    if needsRedraw or UndoPrompt.isOpen() then
        gfx.clear(gfx.kColorWhite)
        drawGrid()
        UndoPrompt.draw()   -- Spec 011: modaler Dialog ueber dem Zoom-Raster
        needsRedraw = false
    end

    playdate.timer.updateTimers()
end

-- Pfeil-Down-Handler: mit gehaltenem B verschiebt die Pfeiltaste den
-- Ebeneninhalt um 1 Pixel (US1, FR-001), sonst bewegt sie den Cursor.
local function arrowDown(direction)
    if UndoPrompt.isOpen() then return end   -- Spec 011 FR-013: Dialog schluckt D-Pad
    if playdate.buttonIsPressed(playdate.kButtonB) then
        shiftActiveLayerContent(direction)
    else
        startDirectionHold(direction)
    end
end

function ZoomRoom:inputHandler()
    -- Spec 011 FR-013: bei offenem Undo-Dialog schluckt der Raum alle Eingaben;
    -- nur A (Ja) und B (Nein) wirken auf den Dialog.
    return {
        upButtonDown = function() arrowDown("up") end,
        upButtonUp = function() if UndoPrompt.isOpen() then return end stopDirectionHold("up") end,
        downButtonDown = function() arrowDown("down") end,
        downButtonUp = function() if UndoPrompt.isOpen() then return end stopDirectionHold("down") end,
        leftButtonDown = function() arrowDown("left") end,
        rightButtonDown = function() arrowDown("right") end,
        leftButtonUp = function() if UndoPrompt.isOpen() then return end stopDirectionHold("left") end,
        rightButtonUp = function() if UndoPrompt.isOpen() then return end stopDirectionHold("right") end,
        AButtonDown = function()
            if UndoPrompt.isOpen() then UndoPrompt.handleA(); needsRedraw = true; return end
            beginStroke()
        end,
        AButtonUp = function()
            if UndoPrompt.isOpen() then return end
            endStroke()
        end,
        BButtonDown = function()
            if UndoPrompt.isOpen() then UndoPrompt.handleB(); needsRedraw = true end
        end,
        BButtonUp = function()
            -- Spec 011: B loslassen schliesst den offenen Verschiebe-Run.
            if not UndoPrompt.isOpen() and editorRoom and editorRoom.endShiftRun then
                editorRoom:endShiftRun()
            end
        end,
    }
end
