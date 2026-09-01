-- EditorRoom.lua
-- Nativer 16x16-Tile-Editor für Hans Dither v0.3.0 (AD-016/AD-019):
-- 25x15-Raster auf 400x240. Steuerung (Spec 010 Steuerungs-Redesign):
--   D-Pad            = Cursor bewegen
--   Crank (ohne B)   = Tile-Picker-Overlay (aktive Kachel reihum waehlen)
--   B halten + Hoch/Runter  = aktive Ebene +1 / -1 (Wrap 1..3)
--   B halten + Links/Rechts = Frame zurueck / vor (Rechts am Ende: neuer Frame)
--   B + Crank vorwaerts / rueckwaerts = Zoomkette / Frame-Verwaltung (unveraendert)
--   B kurz (ohne weitere Eingabe) = Pipette; zeigt kurz "Tile N picked"
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

-- Spec 010 (Steuerungs-Redesign): Crank ohne B waehlt reihum eine Kachel
-- (Tile-Picker). Ein Kachelschritt je PICKER_DEGREES_PER_TILE Grad
-- Netto-Kurbeldrehung; das Overlay bleibt PICKER_VISIBLE_MS nach der letzten
-- Bewegung sichtbar. "Tile N picked" (Pipette) blendet nach PICK_MESSAGE_MS aus.
local PICKER_DEGREES_PER_TILE = 30
local PICKER_VISIBLE_MS = 1500
local PICK_MESSAGE_MS = 1500

-- SDK-Key-Repeat (Constitution I) statt eigener Timer-Ketten
local KEY_REPEAT_DELAY_MS = 300
local KEY_REPEAT_MS = 100

local STATUS_MESSAGE_MS = 4000

-- ── Abhängigkeiten (via init() injiziert) ─────────────────────────────────────

local switchRoomFunction
local zoomRoom
local selectionRoom
local frameManagementView   -- Spec 010 US4

-- ── Zustand (data-model.md "EditorRoom-Zustand") ──────────────────────────────

local imageData = nil            -- {id, name, imagetable, frames, hashIndex}
local currentFrame = 1           -- 1..#frames
local tilemap = nil              -- playdate.graphics.tilemap (25x15)
local cursor = { x = 1, y = 1 }  -- Tile-Koordinaten 1..25 / 1..15
local activeTile = nil           -- number/nil: Pipetten-Auswahl; nil = Toggle-Modus
local zoomTickAccu = 0           -- Tick-Akkumulator für B+Crank; Reset bei B-Release
local crankAccumDegrees = 0      -- Spec 010: signierter Grad-Akkumulator fuer den Tile-Picker (Crank ohne B)
local bUsedForZoom = false       -- Crank während B-Hold unterdrückt die Pipette
local bNavConsumed = false       -- B+D-Pad hat Ebene/Frame gewechselt -> Pipette bei B-Release unterdruecken
local pickerVisible = false      -- Tile-Picker-Overlay sichtbar (abgeleitet aus pickerUntilMs)
local pickerUntilMs = 0
local pickerTileList = nil       -- Cache der referenzierten Tile-Indizes; nil = neu bauen (bei Tile-Mutation invalidiert)
local pickMessage = nil          -- "Tile N picked" (Pipette); ersetzt kurz das Bauchbinden-Label
local pickMessageUntilMs = 0
local pickMessageVisible = false -- abgeleitet; Uebergangs-Redraw wie bauchbindeVisible
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

-- Distinkte, tatsaechlich referenzierte Tile-Indizes (aufsteigend). Faktischer
-- Scan ohne Beigaben — gemeinsame Quelle fuer den Tile-Picker (Spec 010) UND
-- die Pause-/Kontext-Ansicht (buildPauseMenuImage, Spec 006 CR-06 / FR-011).
-- Quelle sind die EBENEN-Positionen (`frameLayers`), NICHT der flache
-- Composite-Cache `imageData.frames`: dort gewinnt je Zelle nur die oberste
-- nicht-leere Ebene, sodass eine Kachel, die nur auf einer verdeckten (oberen
-- oder unteren) Ebene liegt, herausfiele — im Picker koennte sie mitten in der
-- Sitzung verschwinden, sobald eine hoehere Ebene die Zelle abdeckt; in der
-- Pause-Ansicht wuerde sie in "Tiles: N" fehlen.
-- NICHT imagetable:getLength(): Sitzungs-Edits haengen neue Tiles an und
-- verwaisen alte; erst das Speichern (pruneUnusedTilesLayered) raeumt auf.
-- Den Abwahl-Slot (Index 1) haengt NUR pickerList() an — sonst zaehlte die
-- Pause-Ansicht bei Bildern ohne Zelle=1 eine Kachel zu viel.
local function referencedTileIndices()
    if not imageData then return {} end
    local seen, list = {}, {}
    local entries = imageData.frameLayers
    if entries then
        for _, entry in ipairs(entries) do
            for _, layer in ipairs(entry.layers or {}) do
                for _, idx in ipairs(layer.positions or {}) do
                    if idx and idx ~= 0 and not seen[idx] then
                        seen[idx] = true
                        list[#list + 1] = idx
                    end
                end
            end
        end
    elseif imageData.frames then
        for _, frame in ipairs(imageData.frames) do
            for _, idx in ipairs(frame) do
                if idx and idx ~= 0 and not seen[idx] then
                    seen[idx] = true
                    list[#list + 1] = idx
                end
            end
        end
    end
    table.sort(list)
    return list
end

-- Gecachte Fassung fuer den Tile-Picker: `stepTilePicker` kann bei schnellem
-- Kurbeln ~12x pro update() feuern, dazu einmal je draw() — ohne Cache waeren
-- das ~13 Voll-Scans (3x375 Zellen) je Frame. Der Cache wird bei jeder
-- Tile-Mutation invalidiert (`recompositeCell`/`recompositeCurrentFrame` und
-- `entered()` setzen `pickerTileList = nil`). buildPauseMenuImage nutzt
-- bewusst den frischen, faktischen Scan (seltener Aufruf, Genauigkeit zaehlt).
--
-- Index 1 (Weiss) wird hier — und NUR hier — vorne angehaengt: er ist der
-- Abwahl-/Toggle-Slot des Pickers und muss auch dann erreichbar sein, wenn
-- keine Zelle Kachel 1 referenziert (sonst bliebe der Picker bei einer
-- Ein-Element-Liste haengen). Die Liste bleibt aufsteigend sortiert.
local function pickerList()
    if not pickerTileList then
        pickerTileList = referencedTileIndices()
        if pickerTileList[1] ~= 1 then
            table.insert(pickerTileList, 1, 1)
        end
    end
    return pickerTileList
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
    pickerTileList = nil  -- Tile-Menge kann sich geaendert haben
    needsRedraw = true
end

-- Kompositiert den gesamten aktuellen Frame neu (nach Frame-Wechsel,
-- "clear screen", Ebenen-Add/Delete).
local function recompositeCurrentFrame()
    local entry = currentEntry()
    if not entry then return end
    imageData.frames[currentFrame] = LayerModel.compositeToFlat(entry)
    updateTilemapFrame()
    pickerTileList = nil  -- Tile-Menge kann sich geaendert haben
    needsRedraw = true
end

-- Spec 010 US3 (FR-013/014/017): aktive Ebene um delta zyklen (Wrap 1..count).
local function cycleActiveLayer(delta)
    local entry = currentEntry()
    if not entry then return end
    local before = imageData.activeLayer or 1
    imageData.activeLayer = LayerModel.cycleActive(entry, before, delta)
    if imageData.activeLayer ~= before then
        needsRedraw = true
    end
end

-- Anzeige-Infos fuer den Ebenen-Indikator (FR-015) / Tests.
function EditorRoom:getActiveLayerInfo()
    local entry = currentEntry()
    if not entry then return nil end
    local i = LayerModel.clampActive(entry, imageData.activeLayer or 1)
    return { index = i, count = #entry.layers, name = entry.layers[i].name }
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

-- Schreibt eine Tile-Position in die AKTIVE Ebene. Auf oberen Ebenen wird das
-- Weiss-Basistile (1) als "absent" (0) abgelegt — sonst wuerde der Radierer
-- (A auf opak -> Tile 1) die darunterliegenden Ebenen dauerhaft mit Weiss
-- verdecken, ohne Rueckweg zu transparent. Auf der Basisebene bleibt 1 =
-- Voll-Weiss (dort ist "absent" nicht vorgesehen).
local function writeActiveLayerPosition(cellIdx, tileIdx)
    local layer = activeLayerObj()
    if not layer then return end
    if layer.layerIndex ~= 0 and tileIdx == LayerModel.WHITE_TILE then
        tileIdx = LayerModel.ABSENT
    end
    layer.positions[cellIdx] = tileIdx
end

local function setCell(idx)
    writeActiveLayerPosition(cursorCellIndex(), idx)
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

local function setPickMessage(text)
    pickMessage = text
    pickMessageUntilMs = playdate.getCurrentTimeMilliseconds() + PICK_MESSAGE_MS
    pickMessageVisible = true
    needsRedraw = true
end

-- B (kurz): Pipette; auf Weiß (Index 1) -> Abwahl (FR-003, research.md R4).
-- Spec 010: zeigt zusaetzlich kurz "Tile N picked" in der Bauchbinde.
local function pipette()
    lastActivityMs = playdate.getCurrentTimeMilliseconds()
    local idx = imageData.frames[currentFrame][cursorCellIndex()]
    if idx == 1 then
        activeTile = nil
    else
        activeTile = idx
    end
    setPickMessage(string.format("Tile %d picked", idx))
    needsRedraw = true
end

-- Spec 010 (Steuerungs-Redesign): Crank ohne B schaltet die aktive Kachel-
-- Auswahl (activeTile) reihum durch die tatsaechlich referenzierten Tiles.
-- Landet sie auf Index 1 (Weiss), gilt das wie die Pipette auf Weiss: Abwahl
-- (activeTile = nil, Toggle-Modus).
local function stepTilePicker(dir)
    local list = pickerList()
    if #list == 0 then return end
    local current = activeTile or 1
    local pos = 1
    for i, v in ipairs(list) do
        if v == current then pos = i; break end
    end
    pos = ((pos - 1 + dir) % #list) + 1
    local picked = list[pos]
    -- Index 1 (Weiss) = Abwahl/Toggle-Modus. KEIN `and nil or` — das ergaebe
    -- in Lua immer `picked` (true and nil -> nil, nil or picked -> picked).
    if picked == 1 then
        activeTile = nil
    else
        activeTile = picked
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

-- Spec 010 (Steuerungs-Redesign): B halten + D-Pad. Hoch/Runter = aktive Ebene
-- +1 / -1 (Wrap 1..3), Links/Rechts = Frame zurueck / vor. Setzt bNavConsumed,
-- damit der anschliessende B-Release nicht zusaetzlich die Pipette ausloest.
local function bDpadNav(kind, delta)
    if inputBlocked() then return end
    bNavConsumed = true
    lastActivityMs = playdate.getCurrentTimeMilliseconds()
    if kind == "layer" then
        cycleActiveLayer(delta)
    elseif delta > 0 then
        tickForward()
    else
        tickBackward()
    end
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
        imageData = imageData,
        -- Spec 010: bestimmt den "Nicht-Tinte"-Zustand im PixelRoom
        -- (weiss auf der Basisebene, transparent auf Ebenen 2-3).
        activeLayerIsBase = (layer ~= nil and layer.layerIndex == 0),
    }
end

local function zoomIn()
    if not zoomRoom or inputBlocked() then return end
    zoomRoom:setFromEditorContext(buildZoomContext())
    switchRoomFunction(zoomRoom)
end

-- Spec 010 US4 (FR-018): B + Kurbel rueckwaerts oeffnet die Frame-Verwaltung.
local function openFrameManagementView()
    if not frameManagementView or inputBlocked() then return end
    frameManagementView:setImageData(imageData, currentFrame)
    switchRoomFunction(frameManagementView)
end

-- Commit beim Rauszoomen: Dedup über hashIndex + Pixelvergleich, sonst neues Tile;
-- schreibt ausschließlich in die AKTIVE Ebene des currentFrame (FR-012/FR-013,
-- Spec 010: nur die aktive Ebene ist editierbar) und kompositiert je Zelle neu.
function EditorRoom:applyTileEdits(edits)
    if not imageData then return end
    if not activeLayerObj() then return end
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
        writeActiveLayerPosition(edit.frameIndexPos, idx)
        recompositeCell(edit.frameIndexPos)
    end
    updateTilemapFrame()
    needsRedraw = true
end

-- Spec 010 US1 (revidiert 2026-09-01, Einschraenkung aus dem Hardware-Test —
-- ADR-043): verschiebt den Pixelinhalt der Zelle `cellIdx` der aktiven Ebene
-- um 1 nativen Pixel. Ausgangszelle + der eine Nachbar in Schieberichtung
-- bilden fuer den Schritt einen 2-Tile-Streifen, der als Ganzes verschoben
-- wird: der Inhalt wandert in den Nachbarn und bleibt dort, dessen abgewandte
-- Randkante faellt weg; die freigewordene Kante der Ausgangszelle wird
-- geleert. KEIN Wrap, KEINE Ganz-Ebenen-Verschiebung. `cellIdx` ist die
-- Zielzelle (1..375); ohne Angabe die Zelle unter dem Editor-Cursor.
-- Aufgerufen von der ZoomRoom (B + Pfeiltaste) mit der Zelle unter dem
-- Zoom-Cursor. Nur der aktuelle Frame ist betroffen (FR-004).
function EditorRoom:shiftActiveLayer(direction, cellIdx)
    if not imageData then return false end
    local entry = currentEntry()
    if not entry then return false end
    if not activeLayerObj() then return false end
    cellIdx = cellIdx or cursorCellIndex()
    local getTile = function(idx) return imageData.imagetable:getImage(idx) end
    local registerTile = function(img)
        local hash = ImageStoreCodec.hashTile(img)
        local existing = imageData.hashIndex[hash]
        if existing and imagesEqual(imageData.imagetable:getImage(existing), img) then
            return existing
        end
        local idx = appendTileImage(img)
        imageData.hashIndex[hash] = idx
        return idx
    end
    local changed = LayerModel.shiftTileContent(
        entry, imageData.activeLayer or 1, cellIdx, direction, getTile, registerTile)
    if not changed then return false end
    for _, ci in ipairs(changed) do
        recompositeCell(ci)
    end
    return true
end

-- Frischer 3x3-Zoom-Kontext an der aktuellen Cursorposition — von der ZoomRoom
-- nach einem Shift genutzt (jetzt nur 1-2 Tiles betroffen, aber der volle
-- Kontext ist billig genug).
function EditorRoom:currentZoomContext()
    return buildZoomContext()
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
        function()
            -- B nachtraeglich gedrueckt (Richtungstaste war schon gehalten):
            -- Cursor einfrieren, statt gegen die B+D-Pad-Navigation zu laufen.
            if playdate.buttonIsPressed(playdate.kButtonB) then return end
            moveCursor(dx, dy)
        end
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

-- ── Crank (contracts CR-01) ─────────────────────────────────────────────────
-- Mit gehaltenem B: Zoomkette / Frame-Verwaltung (unveraendert, Tick-basiert).
-- Ohne B: Tile-Picker — je PICKER_DEGREES_PER_TILE Grad Netto-Kurbeldrehung
-- schaltet die aktive Kachel-Auswahl (activeTile) eine Position weiter, mit
-- Wrap am Listenende. Frame- und Ebenen-Wechsel liegen jetzt auf B + D-Pad
-- (bDpadNav), NICHT mehr auf der Kurbel.
--
-- Pro Aufruf wird GENAU EINE Crank-Lese-API verwendet (CR-01): getCrankTicks()
-- im B-Zweig, getCrankChange() im Picker-Zweig — nie beide im selben Frame,
-- sonst gehen Grad-/Tick-Anteile verloren (research.md R1 Detailhinweis).

local function handleCrank()
    if playdate.buttonIsPressed(playdate.kButtonB) then
        crankAccumDegrees = 0  -- kein Rest aus einer vorherigen Picker-Drehung
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
            -- Spec 010 US4: B + Kurbel rueckwaerts -> Frame-Verwaltung
            -- (frueher: No-op "aeusserste Zoomstufe").
            zoomTickAccu = 0
            openFrameManagementView()
        end
    else
        zoomTickAccu = 0
        local change = playdate.getCrankChange() or 0
        if change ~= 0 then
            lastActivityMs = playdate.getCurrentTimeMilliseconds()
            pickerVisible = true
            pickerUntilMs = playdate.getCurrentTimeMilliseconds() + PICKER_VISIBLE_MS
            needsRedraw = true
        end
        crankAccumDegrees = crankAccumDegrees + change
        while crankAccumDegrees >= PICKER_DEGREES_PER_TILE do
            crankAccumDegrees = crankAccumDegrees - PICKER_DEGREES_PER_TILE
            stepTilePicker(1)
        end
        while crankAccumDegrees <= -PICKER_DEGREES_PER_TILE do
            crankAccumDegrees = crankAccumDegrees + PICKER_DEGREES_PER_TILE
            stepTilePicker(-1)
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

-- Spec 010: Kachel-Auswahl-Overlay (Crank ohne B). Filmstreifen aus
-- PICKER_STRIP Kacheln, die aktuelle mittig umrahmt, darunter "Tile N".
-- Wird nur gezeichnet, solange pickerVisible (Auto-Ausblendung in update()).
local PICKER_STRIP = 7
local PICKER_CELL = 22

local function drawTilePickerOverlay()
    local list = pickerList()
    if #list == 0 then return end
    local current = activeTile or 1
    local pos = 1
    for i, v in ipairs(list) do
        if v == current then pos = i; break end
    end

    local half = (PICKER_STRIP - 1) // 2
    local panelW = PICKER_STRIP * PICKER_CELL + 16
    local panelH = PICKER_CELL + 30
    local px = (400 - panelW) // 2
    local py = (240 - panelH) // 2

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(px, py, panelW, panelH)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(px, py, panelW, panelH)

    local cy = py + 6
    for s = -half, half do
        local li = ((pos - 1 + s) % #list) + 1
        local tileIdx = list[li]
        local img = imageData.imagetable and imageData.imagetable:getImage(tileIdx)
        local cx = px + 8 + (s + half) * PICKER_CELL + (PICKER_CELL - TILE_PX) // 2
        if img then img:draw(cx, cy) end
        if s == 0 then
            gfx.drawRect(cx - 3, cy - 3, TILE_PX + 6, TILE_PX + 6)
        end
    end
    gfx.drawText(string.format("Tile %d", current), px + 8, py + panelH - 18)
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
            local label
            if pickMessageVisible and pickMessage then
                -- Spec 010: die Pipette meldet kurz "Tile N picked" — ersetzt
                -- fuer PICK_MESSAGE_MS das normale Frame/Ebenen-Label im selben
                -- Bauchbinden-Balken (keine zweite Bandzeile).
                label = pickMessage
            else
                -- Spec 010 FR-015: Ebenen-Indikator (Index/Anzahl + Name) neben
                -- der Frame-Anzeige. Bei nur einer Ebene bleibt es bei "Frame x/y".
                label = string.format("Frame %d/%d", currentFrame, #imageData.frames)
                local li = EditorRoom:getActiveLayerInfo()
                if li and li.count > 1 then
                    label = string.format("%s  L%d/%d %s", label, li.index, li.count, li.name or "")
                end
            end
            bauchbinde:drawBottom(label, side, 400, 240)
        end
    end
    if imageData and pickerVisible then
        drawTilePickerOverlay()
    end
    if statusMessage then
        bauchbinde:drawBottom(statusMessage, "left", 400, 240)
    end
    overlay:draw()
end

-- ── Room-Lifecycle ────────────────────────────────────────────────────────────

function EditorRoom:init(switchRoom, zoomRoomReference, selectionRoomReference, frameManagementViewReference)
    switchRoomFunction = switchRoom
    zoomRoom = zoomRoomReference
    selectionRoom = selectionRoomReference
    frameManagementView = frameManagementViewReference
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
    bNavConsumed = false
    pickerVisible = false
    pickerTileList = nil  -- Frame-Verwaltung kann Frames umgeordnet/geloescht haben
    pickMessage = nil
    pickMessageVisible = false
    lastActivityMs = playdate.getCurrentTimeMilliseconds()
    bauchbindeVisible = true
    needsRedraw = true

    if pendingImageId then
        local id = pendingImageId
        pendingImageId = nil
        buildSystemMenu()
        startLoadOperation(id)
    elseif imageData then
        -- Rückkehr aus der Zoomkette / Frame-Verwaltung: Menü neu registrieren
        -- (die anderen Räume räumen es ab).
        buildSystemMenu()
        -- Spec 010 US4: die Frame-Verwaltung kann Frames umgeordnet/geloescht
        -- haben. currentFrame in den (evtl. kuerzeren) Bereich klemmen; wenn
        -- die View einen Rueckkehr-Frame gesetzt hat, dorthin.
        local n = imageData.frameLayers and #imageData.frameLayers or 1
        if imageData.returnFrame then
            currentFrame = imageData.returnFrame
            imageData.returnFrame = nil
        end
        currentFrame = math.max(1, math.min(currentFrame, n))
        imageData.activeLayer = LayerModel.clampActive(
            imageData.frameLayers and imageData.frameLayers[currentFrame], imageData.activeLayer or 1)
        if tilemap then updateTilemapFrame() end
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

    -- CR-06 (FR-011): frisches, aufsteigendes Set tatsaechlich referenzierter
    -- Tile-Indizes — NICHT imagetable:getLength() (zaehlt nie mehr referenzierte
    -- Alt-Eintraege mit). Seit Spec 010 derselbe faktische Scan wie fuer den
    -- Tile-Picker (referencedTileIndices scannt die Ebenen-Positionen, sodass
    -- auch eine nur auf einer verdeckten Ebene liegende Kachel gezaehlt wird —
    -- der fruehere Scan des flachen Composite-Cache hat solche Kacheln
    -- uebersehen). Der Abwahl-Slot des Pickers (Index 1) haengt NUR pickerList()
    -- an, nicht dieser Scan — die Pause-Anzahl bleibt faktisch korrekt.
    local distinctIndices = referencedTileIndices()
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

    -- Spec 010: Tile-Picker-Overlay nach PICKER_VISIBLE_MS ohne Kurbelbewegung
    -- ausblenden; danach den Grad-Rest verwerfen, damit ein spaeterer Anstupser
    -- nicht sofort weiterschaltet.
    if pickerVisible and playdate.getCurrentTimeMilliseconds() > pickerUntilMs then
        pickerVisible = false
        crankAccumDegrees = 0
        needsRedraw = true
    end
    -- "Tile N picked"-Hinweis: Uebergangs-Redraw auch ohne weitere Eingabe
    -- (analog Bauchbinde/statusMessage).
    if pickMessage then
        local vis = playdate.getCurrentTimeMilliseconds() <= pickMessageUntilMs
        if vis ~= pickMessageVisible then
            pickMessageVisible = vis
            needsRedraw = true
        end
        if not vis then pickMessage = nil end
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
            -- spaeter Pipette, Zoom oder B+D-Pad-Navigation ausgeloest wird
            -- (sonst wuerde ein langes B-Halten ohne weitere Eingabe die
            -- Bauchbinde faelschlich ausblenden lassen, bevor B los ist)
            lastActivityMs = playdate.getCurrentTimeMilliseconds()
            bUsedForZoom = false
            bNavConsumed = false
            zoomTickAccu = 0
        end,
        BButtonUp = function()
            -- CR-02: B-Release zaehlt IMMER als Aktivitaet, auch wenn die
            -- Pipette unten uebersprungen wird; pipette() setzt lastActivityMs
            -- zwar ebenfalls, aber nur im Nicht-Zoom/Nicht-Nav-Fall
            lastActivityMs = playdate.getCurrentTimeMilliseconds()
            -- Pipette nur, wenn B NICHT fuer Zoom (Crank) oder Ebene/Frame
            -- (D-Pad) benutzt wurde — der kurze B-Tipp allein ist die Pipette.
            if not bUsedForZoom and not bNavConsumed and not inputBlocked() then
                pipette()
            end
            bUsedForZoom = false
            bNavConsumed = false
            zoomTickAccu = 0
        end,
        -- Spec 010: B gehalten -> D-Pad wechselt Ebene (Hoch/Runter) bzw. Frame
        -- (Links/Rechts). Ohne B: normale Cursor-Bewegung (mit Key-Repeat).
        upButtonDown = function()
            if not inputBlocked() and playdate.buttonIsPressed(playdate.kButtonB) then
                bDpadNav("layer", 1)
            else
                startMove("up", 0, -1)
            end
        end,
        upButtonUp = function() stopMove("up") end,
        downButtonDown = function()
            if not inputBlocked() and playdate.buttonIsPressed(playdate.kButtonB) then
                bDpadNav("layer", -1)
            else
                startMove("down", 0, 1)
            end
        end,
        downButtonUp = function() stopMove("down") end,
        leftButtonDown = function()
            if not inputBlocked() and playdate.buttonIsPressed(playdate.kButtonB) then
                bDpadNav("frame", -1)
            else
                startMove("left", -1, 0)
            end
        end,
        leftButtonUp = function() stopMove("left") end,
        rightButtonDown = function()
            if not inputBlocked() and playdate.buttonIsPressed(playdate.kButtonB) then
                bDpadNav("frame", 1)
            else
                startMove("right", 1, 0)
            end
        end,
        rightButtonUp = function() stopMove("right") end
    }
end

return EditorRoom
