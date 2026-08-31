-- EditorRoom.lua
-- Nativer 16x16-Tile-Editor für Hans Dither v0.3.0 (AD-016/AD-019):
-- 25x15-Raster auf 400x240, Crank = Animationsframes, B+Crank = Zoomkette.
-- Ersetzt den alten TileRoom mit Pulp-Kopplung.

import "CoreLibs/graphics"
import "CoreLibs/ui"
import "CoreLibs/timer"
import "CoreLibs/crank"
import "CoreLibs/object"
import "Bauchbinde"
import "PencilCursor"
import "LayerModel"
import "ImageStoreCodec"
import "RoomOperation"
import "loadingBar"

local gfx = playdate.graphics

EditorRoom = {}

-- ── Konstanten ────────────────────────────────────────────────────────────────

local GRID_COLS = 25
local GRID_ROWS = 15
local TILE_PX = 16
local MAX_FRAMES = 12

-- Zoom-Trigger: Tick-Akkumulation bei gehaltenem B, Schwelle wie ZoomRoom/PixelRoom
local ZOOM_TICK_THRESHOLD = 4

-- SDK-Key-Repeat (Constitution I) statt eigener Timer-Ketten
local KEY_REPEAT_DELAY_MS = 300
local KEY_REPEAT_MS = 100

local STATUS_MESSAGE_MS = 4000

-- ── Abhängigkeiten (via init() injiziert) ─────────────────────────────────────

local switchRoomFunction
local zoomRoom
local selectionRoom

-- ── Zustand (data-model.md "EditorRoom-Zustand") ──────────────────────────────

local imageData = nil            -- {id, name, imagetable, frames, hashIndex}
local currentFrame = 1           -- 1..#frames
local tilemap = nil              -- playdate.graphics.tilemap (25x15)
local cursor = { x = 1, y = 1 }  -- Tile-Koordinaten 1..25 / 1..15
local activeTile = nil           -- number/nil: Pipetten-Auswahl; nil = Toggle-Modus
local zoomTickAccu = 0           -- Tick-Akkumulator für B+Crank; Reset bei B-Release
local crankAccumDegrees = 0      -- Spec 006 R1: signierter Grad-Akkumulator fuer Frame-Navigation ohne B
local bUsedForZoom = false       -- Crank während B-Hold unterdrückt die Pipette
local showGrid = true            -- Grid-Overlay an/aus (Checkmark-Menüeintrag)
local loadingOperation = nil     -- RoomOperation während des Ladens
local savingOperation = nil      -- RoomOperation während "save + exit"
local needsRedraw = true
local pendingImageId = nil       -- via setImage(id), geladen in entered()
local statusMessage = nil        -- Fehlerstatus (Bauchbinde links)
local statusUntilMs = 0
local lastActivityMs = 0         -- Spec 006 R3: letzte Nutzereingabe fuer Bauchbinden-Inaktivitaets-Timer
local bauchbindeVisible = true   -- abgeleitet aus lastActivityMs (data-model.md Abschnitt 2); als Feld
                                  -- gehalten, damit update() den Uebergang sichtbar->unsichtbar per
                                  -- needsRedraw auch OHNE andere Eingabe erkennt (analog statusMessage)

local overlay = loadingBar.new()
local bauchbinde = Bauchbinde.new(gfx)

-- keyRepeat-Timer je Richtung
local moveTimers = {}

-- ── Hilfsfunktionen ───────────────────────────────────────────────────────────

local function cursorCellIndex()
    return (cursor.y - 1) * GRID_COLS + cursor.x
end

local function operationRunning()
    return loadingOperation ~= nil or savingOperation ~= nil
end

local function inputBlocked()
    return operationRunning() or imageData == nil
end

-- Sichtbarkeits-Vergleich zweier Tiles: gemeinsame Implementierung im Codec
local imagesEqual = ImageStoreCodec.imagesVisiblyEqual

local function showStatus(text)
    statusMessage = text
    statusUntilMs = playdate.getCurrentTimeMilliseconds() + STATUS_MESSAGE_MS
    needsRedraw = true
end

local function updateTilemapFrame()
    if not tilemap or not imageData then return end
    local frame = imageData.frames[currentFrame]
    if frame and #frame == GRID_COLS * GRID_ROWS then
        tilemap:setTiles(frame, GRID_COLS)
    end
end

-- ── Layer-Zugriff (Spec 010) ─────────────────────────────────────────────────
--
-- imageData.frameLayers[f] = {duration, layers = {1..3 Ebenen}} ist die
-- massgebliche Quelle. imageData.frames[f] ist ein daraus abgeleiteter,
-- flacher 375er-Cache fuer Tilemap/Vorschau/Pause-Ansicht — nach JEDER
-- Ebenen-Mutation neu kompositiert. imageData.activeLayer (1-basiert) ist
-- reiner Sitzungszustand; nur die aktive Ebene ist editierbar (spec.md US3).

local function currentEntry()
    return imageData and imageData.frameLayers and imageData.frameLayers[currentFrame]
end

local function activeLayerObj()
    local entry = currentEntry()
    if not entry then return nil end
    imageData.activeLayer = LayerModel.clampActive(entry, imageData.activeLayer or 1)
    return entry.layers[imageData.activeLayer]
end

-- Kompositiert genau eine Zelle des aktuellen Frames neu in den flachen
-- Cache + die Tilemap (nach einer Einzelzellen-Mutation).
local function recompositeCell(cellIdx)
    local entry = currentEntry()
    if not entry or not imageData.frames[currentFrame] then return end
    local idx = LayerModel.compositeAt(entry, cellIdx)
    imageData.frames[currentFrame][cellIdx] = idx
    if tilemap then
        local x = ((cellIdx - 1) % GRID_COLS) + 1
        local y = ((cellIdx - 1) // GRID_COLS) + 1
        tilemap:setTileAtPosition(x, y, idx)
    end
    needsRedraw = true
end

-- Kompositiert den gesamten aktuellen Frame neu (nach Frame-Wechsel,
-- "clear screen", Ebenen-Add/Delete).
local function recompositeCurrentFrame()
    local entry = currentEntry()
    if not entry then return end
    imageData.frames[currentFrame] = LayerModel.compositeToFlat(entry)
    updateTilemapFrame()
    needsRedraw = true
end

-- Hängt ein Tile an die Imagetable an; wächst die Table notfalls durch Neuaufbau.
local function appendTileImage(img)
    local it = imageData.imagetable
    local n = it:getLength()
    local ok = pcall(function() it:setImage(n + 1, img) end)
    if not ok or it:getLength() < n + 1 then
        local grown = gfx.imagetable.new(n + 1)
        for i = 1, n do
            grown:setImage(i, it:getImage(i))
        end
        grown:setImage(n + 1, img)
        imageData.imagetable = grown
        if tilemap then
            tilemap:setImageTable(grown)
        end
    end
    return n + 1
end

-- ── Mal-Operationen (data-model.md) ───────────────────────────────────────────

local function setCell(idx)
    local layer = activeLayerObj()
    if layer then
        layer.positions[cursorCellIndex()] = idx
    end
    recompositeCell(cursorCellIndex())
end

-- Pencil-Strich (FR-004): Der A-Druck legt fest, was der ganze Strich malt.
-- Steht der Cursor beim Drücken auf dem aktiven Zeichen-Tile (bzw. Schwarz),
-- malt der Strich Weiß (Radierer) — sonst das Zeichen-Tile (bzw. Schwarz).
-- Solange A gehalten bleibt, malen auch Cursor-Bewegungen mit diesem Wert,
-- statt jede Zelle einzeln zu invertieren.
local strokeTileIdx = nil  -- Tile-Index des laufenden A-Strichs; nil = kein Strich

local function beginStroke()
    lastActivityMs = playdate.getCurrentTimeMilliseconds()
    -- Toggle-Wert aus der AKTIVEN Ebene (nicht dem Composite): "absent" (0)
    -- einer oberen Ebene zaehlt wie eine leere Weiss-Zelle.
    local layer = activeLayerObj()
    local current = layer and layer.positions[cursorCellIndex()] or 1
    if current == 0 then current = 1 end
    if activeTile then
        strokeTileIdx = (current == activeTile) and 1 or activeTile
    else
        strokeTileIdx = (current == 1) and 2 or 1
    end
    setCell(strokeTileIdx)
end

local function endStroke()
    strokeTileIdx = nil
end

-- B (kurz): Pipette; auf Weiß (Index 1) -> Abwahl (FR-003, research.md R4)
local function pipette()
    lastActivityMs = playdate.getCurrentTimeMilliseconds()
    local idx = imageData.frames[currentFrame][cursorCellIndex()]
    if idx == 1 then
        activeTile = nil
    else
        activeTile = idx
    end
    needsRedraw = true
end

-- ── Frame-Operationen (FR-006/FR-007, data-model.md) ──────────────────────────

local function tickForward()
    local entries = imageData.frameLayers
    if currentFrame < #entries then
        currentFrame = currentFrame + 1
    elseif #entries < MAX_FRAMES then
        -- Neuer Frame = tiefe Kopie des aktuellen (mit allen Ebenen).
        local copy = LayerModel.cloneFrameLayers(entries[currentFrame])
        entries[#entries + 1] = copy
        imageData.frames[#entries] = LayerModel.compositeToFlat(copy)
        currentFrame = currentFrame + 1
    else
        currentFrame = 1
    end
    imageData.activeLayer = LayerModel.clampActive(entries[currentFrame], imageData.activeLayer or 1)
    updateTilemapFrame()
    needsRedraw = true
end

local function tickBackward()
    if currentFrame > 1 then
        currentFrame = currentFrame - 1
    else
        currentFrame = #imageData.frameLayers
    end
    imageData.activeLayer = LayerModel.clampActive(imageData.frameLayers[currentFrame], imageData.activeLayer or 1)
    updateTilemapFrame()
    needsRedraw = true
end

-- FR-008a: aktiven Frame löschen, Nachrücker aktiv; letzter Frame gesperrt.
-- Bleibt im Code (Spec 006 AD-032), hat aber seit AD-032 keinen Menü-
-- Aufrufer mehr (ersetzt durch clearCurrentFrame() unten, Spec 008/AD-037).
local function deleteCurrentFrame()
    if inputBlocked() then return end
    local entries = imageData.frameLayers
    if #entries <= 1 then return end
    table.remove(entries, currentFrame)
    table.remove(imageData.frames, currentFrame)
    if currentFrame > #entries then
        currentFrame = #entries
    end
    imageData.activeLayer = LayerModel.clampActive(entries[currentFrame], imageData.activeLayer or 1)
    updateTilemapFrame()
    needsRedraw = true
end

-- Spec 008 (AD-037, FR-011/012/013/015): ersetzt "reset frame" (Spec 006/
-- AD-032) VOLLSTAENDIG - setzt jeden der 375 Tile-Indizes des aktiven
-- Frames auf den Basis-Index 1 (Voll-Weiss, ImageStoreCodec-Invariante);
-- andere Frames bleiben unberuehrt. Im Unterschied zu deleteCurrentFrame()
-- oben (AD-032) bleibt resetCurrentFrameToPrevious() NICHT als toter Code
-- erhalten - FR-011 fordert die vollstaendige Entfernung der Funktion.
-- Spec 010: leert die AKTIVE Ebene des aktuellen Frames (Basisebene ->
-- Voll-Weiss/1, obere Ebene -> komplett "absent"/0); andere Ebenen und
-- Frames bleiben unberuehrt. Bei Ein-Ebenen-Bildern identisch zum bisherigen
-- Verhalten (Spec 008 AD-037).
local function clearCurrentFrame()
    if inputBlocked() then return end
    local layer = activeLayerObj()
    if not layer then return end
    local fill = (layer.layerIndex == 0) and 1 or 0
    for i = 1, #layer.positions do
        layer.positions[i] = fill
    end
    recompositeCurrentFrame()
end

-- ── Zoomkette (FR-009/FR-010, contracts Abschnitt 3) ──────────────────────────

-- 3x3-Slot-Kontext um den Cursor + 24x24-gridState (2x2-Blockauslese des
-- 48x48-Pixelkontexts); out-of-bounds-Slots sind markiert und nicht editierbar.
local function buildZoomContext()
    -- Spec 010: die Zoomkette editiert ausschliesslich die AKTIVE Ebene.
    -- "absent" (0) einer oberen Ebene -> kein Quellbild (leere Zelle).
    local layer = activeLayerObj()
    local positions = layer and layer.positions or imageData.frames[currentFrame]
    local slots = {}
    for dr = -1, 1 do
        local row = {}
        for dc = -1, 1 do
            local tx = cursor.x + dc
            local ty = cursor.y + dr
            local slot = { tileX = tx, tileY = ty }
            if tx >= 1 and tx <= GRID_COLS and ty >= 1 and ty <= GRID_ROWS then
                slot.oob = false
                slot.frameIndexPos = (ty - 1) * GRID_COLS + tx
                slot.originalIndex = positions[slot.frameIndexPos]
                slot.originalImage = (slot.originalIndex and slot.originalIndex ~= 0)
                    and imageData.imagetable:getImage(slot.originalIndex) or nil
            else
                slot.oob = true
            end
            row[dc + 2] = slot
        end
        slots[dr + 2] = row
    end

    local gridState = {}
    for r = 1, 24 do
        gridState[r] = {}
        for c = 1, 24 do
            local slot = slots[math.ceil(r / 8)][math.ceil(c / 8)]
            if slot.oob or not slot.originalImage then
                gridState[r][c] = false
            else
                local localR = ((r - 1) % 8)
                local localC = ((c - 1) % 8)
                gridState[r][c] = (slot.originalImage:sample(localC * 2, localR * 2) == gfx.kColorBlack)
            end
        end
    end

    return {
        slots = slots,
        gridState = gridState,
        showGrid = showGrid,
        imageData = imageData
    }
end

local function zoomIn()
    if not zoomRoom or inputBlocked() then return end
    zoomRoom:setFromEditorContext(buildZoomContext())
    switchRoomFunction(zoomRoom)
end

-- Commit beim Rauszoomen: Dedup über hashIndex + Pixelvergleich, sonst neues Tile;
-- schreibt ausschließlich in die AKTIVE Ebene des currentFrame (FR-012/FR-013,
-- Spec 010: nur die aktive Ebene ist editierbar) und kompositiert je Zelle neu.
function EditorRoom:applyTileEdits(edits)
    if not imageData then return end
    local layer = activeLayerObj()
    if not layer then return end
    for _, edit in ipairs(edits or {}) do
        local hash = ImageStoreCodec.hashTile(edit.newImage)
        local existing = imageData.hashIndex[hash]
        local idx
        if existing and imagesEqual(imageData.imagetable:getImage(existing), edit.newImage) then
            idx = existing
        else
            idx = appendTileImage(edit.newImage)
            imageData.hashIndex[hash] = idx
        end
        layer.positions[edit.frameIndexPos] = idx
        recompositeCell(edit.frameIndexPos)
    end
    updateTilemapFrame()
    needsRedraw = true
end

-- ── Load / Save (Contract E-01/E-02, research.md R1/R6/R7) ────────────────────

local function handleLoadError(err)
    loadingOperation = nil
    print("EditorRoom: Load failed:", tostring(err))
    if switchRoomFunction and selectionRoom then
        switchRoomFunction(selectionRoom)
    end
end

local function handleLoadSuccess(result)
    loadingOperation = nil
    if not result then
        handleLoadError("Load lieferte keine Daten")
        return
    end
    imageData = result
    currentFrame = 1
    activeTile = nil
    zoomTickAccu = 0
    cursor.x = 1
    cursor.y = 1

    -- Spec 010: defensiv — falls ein Aufrufer nur flache frames liefert,
    -- je Frame eine Basisebene daraus bauen. imageData.frames bleibt der
    -- flache Composite-Cache.
    if not imageData.frameLayers then
        imageData.frameLayers = {}
        for i, flat in ipairs(imageData.frames or {}) do
            imageData.frameLayers[i] = LayerModel.newFrameLayersFromFlat(flat)
        end
    end
    imageData.activeLayer = LayerModel.clampActive(imageData.frameLayers[1], imageData.activeLayer or 1)

    tilemap = gfx.tilemap.new()
    tilemap:setImageTable(imageData.imagetable)
    tilemap:setSize(GRID_COLS, GRID_ROWS)
    updateTilemapFrame()

    needsRedraw = true
    print("EditorRoom: Load successful, image:", imageData.id, "frames:", #imageData.frames)
end

local function startLoadOperation(id)
    local operation = RoomOperation.new(overlay)
    loadingOperation = operation
    operation:start("Loading...", "", function()
        return ImageStoreCodec.newLoadOperation(id)
    end, function(result)
        handleLoadSuccess(result)
    end)
end

local function handleSaveAndExit()
    if inputBlocked() then return end
    local operation = RoomOperation.new(overlay)
    savingOperation = operation
    operation:start("Saving...", "", function()
        return ImageStoreCodec.newSaveOperation(imageData)
    end, function()
        savingOperation = nil
        if switchRoomFunction and selectionRoom then
            switchRoomFunction(selectionRoom)
        end
    end)
end

-- ── Systemmenü (research.md R6: genau 3 Slots) ────────────────────────────────

-- Spec 008 AD-037/EM-01: "reset frame" durch "clear screen" ersetzt (kein
-- freier vierter Slot, wie schon bei AD-032) — "show grid" unveraendert.
local function buildSystemMenu()
    local menu = playdate.getSystemMenu()
    menu:removeAllMenuItems()
    menu:addMenuItem("save + exit", function()
        handleSaveAndExit()
    end)
    menu:addMenuItem("clear screen", function()
        clearCurrentFrame()
    end)
    menu:addCheckmarkMenuItem("show grid", showGrid, function(checked)
        showGrid = checked
        needsRedraw = true
    end)
end

-- ── Cursor (FR-002: D-Pad, Halten wiederholt via SDK-keyRepeatTimer) ──────────

local function moveCursor(dx, dy)
    if inputBlocked() then return end
    lastActivityMs = playdate.getCurrentTimeMilliseconds()
    local newX = math.max(1, math.min(GRID_COLS, cursor.x + dx))
    local newY = math.max(1, math.min(GRID_ROWS, cursor.y + dy))
    if newX ~= cursor.x or newY ~= cursor.y then
        cursor.x = newX
        cursor.y = newY
        -- Laufender A-Strich: neue Zelle mit dem Strichwert malen
        -- (SDK: playdate.buttonIsPressed fragt den Live-Zustand ab)
        if strokeTileIdx and playdate.buttonIsPressed(playdate.kButtonA) then
            setCell(strokeTileIdx)
        end
        needsRedraw = true
    end
end

local function startMove(direction, dx, dy)
    if moveTimers[direction] then
        moveTimers[direction]:remove()
    end
    moveTimers[direction] = playdate.timer.keyRepeatTimerWithDelay(
        KEY_REPEAT_DELAY_MS, KEY_REPEAT_MS,
        function() moveCursor(dx, dy) end
    )
end

local function stopMove(direction)
    if moveTimers[direction] then
        moveTimers[direction]:remove()
        moveTimers[direction] = nil
    end
end

local function clearMoveTimers()
    for direction in pairs(moveTimers) do
        stopMove(direction)
    end
end

-- ── Crank (FR-004/FR-005/FR-006, contracts CR-01): ohne B = volle Umdrehung
-- fuer Frame-Navigation, mit B = Zoom (unveraendert) ──────────────────────────
--
-- Pro Aufruf wird GENAU EINE Crank-Lese-API verwendet (CR-01) — niemals
-- beide im selben Frame, sonst gehen Grad-/Tick-Anteile verloren
-- (research.md R1 Detailhinweis).

local function handleCrank()
    if playdate.buttonIsPressed(playdate.kButtonB) then
        local crankTicks = playdate.getCrankTicks(4) or 0
        if crankTicks ~= 0 then
            bUsedForZoom = true
            lastActivityMs = playdate.getCurrentTimeMilliseconds()
        end
        zoomTickAccu = zoomTickAccu + crankTicks
        if zoomTickAccu >= ZOOM_TICK_THRESHOLD then
            zoomTickAccu = 0
            zoomIn()
        elseif zoomTickAccu <= -ZOOM_TICK_THRESHOLD then
            -- Äußerste Zoomstufe: Rückwärtszoom ist No-op
            zoomTickAccu = 0
        end
    else
        zoomTickAccu = 0
        -- Spec 006 R1: signierter Netto-Akkumulator statt sofortigem Tick bei
        -- 90°-Rasterung — wechselt den Frame erst bei einer vollen 360°-Umdrehung
        -- ab der AKTUELLEN Kurbelposition (FR-004/005); Teildrehungen und
        -- Richtungswechsel heben sich im Summenwert von selbst auf, kein
        -- Reset auf 0 noetig (FR-006 - Einklappen mitten in der Drehung laesst
        -- den Akkumulator einfach liegen).
        local change = playdate.getCrankChange() or 0
        if change ~= 0 then
            lastActivityMs = playdate.getCurrentTimeMilliseconds()
        end
        crankAccumDegrees = crankAccumDegrees + change
        if crankAccumDegrees >= 360 then
            crankAccumDegrees = crankAccumDegrees - 360
            tickForward()
        elseif crankAccumDegrees <= -360 then
            crankAccumDegrees = crankAccumDegrees + 360
            tickBackward()
        end
    end
end

-- ── Rendering ─────────────────────────────────────────────────────────────────

local function drawGridOverlay()
    gfx.setColor(gfx.kColorBlack)
    for x = 1, GRID_COLS - 1 do
        gfx.drawLine(x * TILE_PX, 0, x * TILE_PX, 240)
    end
    for y = 1, GRID_ROWS - 1 do
        gfx.drawLine(0, y * TILE_PX, 400, y * TILE_PX)
    end
end

local function draw()
    gfx.clear(gfx.kColorWhite)
    if tilemap then
        tilemap:draw(0, 0)
        if showGrid then
            drawGridOverlay()
        end
    end
    if imageData then
        PencilCursor.draw((cursor.x - 1) * TILE_PX, (cursor.y - 1) * TILE_PX, TILE_PX, TILE_PX)
        -- Spec 006 R3/CR-02/CR-03: blendet nach 5s Inaktivitaet aus (FR-001) und
        -- zeigt auf der dem Cursor gegenueberliegenden Bildschirmhaelfte (FR-003)
        if bauchbindeVisible then
            local side = (cursor.x <= GRID_COLS / 2) and "right" or "left"
            bauchbinde:drawBottom(string.format("Frame %d/%d", currentFrame, #imageData.frames), side, 400, 240)
        end
    end
    if statusMessage then
        bauchbinde:drawBottom(statusMessage, "left", 400, 240)
    end
    overlay:draw()
end

-- ── Room-Lifecycle ────────────────────────────────────────────────────────────

function EditorRoom:init(switchRoom, zoomRoomReference, selectionRoomReference)
    switchRoomFunction = switchRoom
    zoomRoom = zoomRoomReference
    selectionRoom = selectionRoomReference
    needsRedraw = true
end

-- Von SelectionRoom vor switchRoom gesetzt (Contract E-01: lädt nichts synchron)
function EditorRoom:setImage(id)
    if not id then return end
    pendingImageId = id
end

function EditorRoom:entered()
    clearMoveTimers()
    endStroke()
    zoomTickAccu = 0
    crankAccumDegrees = 0
    bUsedForZoom = false
    lastActivityMs = playdate.getCurrentTimeMilliseconds()
    bauchbindeVisible = true
    needsRedraw = true

    if pendingImageId then
        local id = pendingImageId
        pendingImageId = nil
        buildSystemMenu()
        startLoadOperation(id)
    elseif imageData then
        -- Rückkehr aus der Zoomkette: Menü neu registrieren (Zoomräume räumen es ab)
        buildSystemMenu()
    else
        -- Kein Bild gesetzt: zurück zum Auswahlscreen
        if switchRoomFunction and selectionRoom then
            switchRoomFunction(selectionRoom)
        end
    end
end

function EditorRoom:getImageData()
    return imageData
end

-- Spec 006 R4/CR-05..CR-07: 400x240-Bild fuer playdate.setMenuImage(); relevanter
-- Inhalt ausschliesslich in x in [0,200) (SDK-Vorgabe, rechte Haelfte vom System-
-- Menue ueberdeckt). Nur aus main.lua:gameWillPause() aufgerufen, NICHT pro Frame
-- (kein Performance-Risiko). nil, wenn kein imageData geladen ist.
local PAUSE_GRID_COLS = 12
local PAUSE_GRID_ROWS = 10
local PAUSE_MAX_TILES = PAUSE_GRID_COLS * PAUSE_GRID_ROWS  -- 120 (FR-010)
local PAUSE_CELL_SIZE = 14  -- 13px Kachel + 1px Rand
local PAUSE_TILE_SIZE = 13
local PAUSE_TILE_SCALE = PAUSE_TILE_SIZE / TILE_PX

function EditorRoom:buildPauseMenuImage()
    if not imageData then return nil end

    -- CR-06: NICHT imagetable:getLength() (koennte nie mehr referenzierte
    -- Alt-Eintraege mitzaehlen) - frisches Set tatsaechlich referenzierter
    -- Tile-Indizes ueber alle imageData.frames[*] hinweg (FR-011)
    local seen = {}
    local distinctIndices = {}
    for _, frame in ipairs(imageData.frames) do
        for _, tileIndex in ipairs(frame) do
            if not seen[tileIndex] then
                seen[tileIndex] = true
                table.insert(distinctIndices, tileIndex)
            end
        end
    end
    table.sort(distinctIndices)
    local totalDistinctTileCount = #distinctIndices

    local img = gfx.image.new(400, 240, gfx.kColorWhite)
    gfx.pushContext(img)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawText(imageData.name or "", 8, 6)

        -- CR-07: bei > 120 nur die ersten 120 (aufsteigender Tile-Index) als
        -- Vorschau; totalDistinctTileCount bleibt der vollstaendige Wert (FR-013)
        local shown = math.min(totalDistinctTileCount, PAUSE_MAX_TILES)
        for i = 1, shown do
            local tileIndex = distinctIndices[i]
            local tileImg = imageData.imagetable:getImage(tileIndex)
            if tileImg then
                local col = (i - 1) % PAUSE_GRID_COLS
                local row = (i - 1) // PAUSE_GRID_COLS
                tileImg:drawScaled(8 + col * PAUSE_CELL_SIZE, 26 + row * PAUSE_CELL_SIZE, PAUSE_TILE_SCALE)
            end
        end

        gfx.drawText("Tiles: " .. totalDistinctTileCount, 8, 172)  -- FR-011
        gfx.drawText("Frames: " .. #imageData.frames, 8, 188)      -- FR-012
    gfx.popContext()

    return img
end

function EditorRoom:update()
    playdate.timer.updateTimers()

    if statusMessage and playdate.getCurrentTimeMilliseconds() > statusUntilMs then
        statusMessage = nil
        needsRedraw = true
    end

    -- Spec 006 R3: Uebergang sichtbar->unsichtbar (bzw. umgekehrt) durch reinen
    -- Zeitablauf erkennen und genau EINEN Redraw ausloesen — sonst wuerde die
    -- Bauchbinde bei komplett fehlender Eingabe nie tatsaechlich verschwinden,
    -- da draw() ausschliesslich bei needsRedraw==true laeuft (analog statusMessage)
    if imageData then
        local nowVisible = (playdate.getCurrentTimeMilliseconds() - lastActivityMs) < 5000
        if nowVisible ~= bauchbindeVisible then
            bauchbindeVisible = nowVisible
            needsRedraw = true
        end
    end

    if loadingOperation then
        loadingOperation:resume(function(err)
            handleLoadError(err)
        end)
        playdate.getCrankTicks(4) -- Ticks verwerfen (stateful), sonst Frame-Sprung nach der Operation
    elseif savingOperation then
        savingOperation:resume(function(err)
            savingOperation = nil
            showStatus("Save failed: " .. tostring(err))
        end)
        playdate.getCrankTicks(4)
    elseif imageData then
        handleCrank()
    end

    if needsRedraw or operationRunning() then
        draw()
        needsRedraw = false
    end
end

function EditorRoom:inputHandler()
    return {
        AButtonDown = function()
            if inputBlocked() then return end
            beginStroke()
        end,
        AButtonUp = function()
            endStroke()
        end,
        BButtonDown = function()
            -- CR-02: B-Druck zaehlt als Aktivitaet unabhaengig davon, ob
            -- spaeter Pipette oder Zoom ausgeloest wird (sonst wuerde ein
            -- langes B-Halten ohne Crank-Bewegung die Bauchbinde
            -- faelschlich ausblenden lassen, bevor B losgelassen wird)
            lastActivityMs = playdate.getCurrentTimeMilliseconds()
            bUsedForZoom = false
            zoomTickAccu = 0
        end,
        BButtonUp = function()
            -- CR-02: B-Release zaehlt IMMER als Aktivitaet, auch wenn die
            -- Pipette unten uebersprungen wird (bUsedForZoom==true); pipette()
            -- setzt lastActivityMs zwar ebenfalls, aber nur im Nicht-Zoom-Fall
            lastActivityMs = playdate.getCurrentTimeMilliseconds()
            -- Pipette bei B-Release ohne akkumulierte Zoom-Ticks
            if not bUsedForZoom and not inputBlocked() then
                pipette()
            end
            bUsedForZoom = false
            zoomTickAccu = 0
        end,
        upButtonDown = function() startMove("up", 0, -1) end,
        upButtonUp = function() stopMove("up") end,
        downButtonDown = function() startMove("down", 0, 1) end,
        downButtonUp = function() stopMove("down") end,
        leftButtonDown = function() startMove("left", -1, 0) end,
        leftButtonUp = function() stopMove("left") end,
        rightButtonDown = function() startMove("right", 1, 0) end,
        rightButtonUp = function() stopMove("right") end
    }
end

return EditorRoom
