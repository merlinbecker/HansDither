-- FrameManagementView.lua
-- Spec 010 US4 — Frame-Verwaltung. Eighth Round (Hardware-Test): aus dem
-- modalen "B halten"-List-View wird ein DAUERHAFTER Room mit einem
-- playdate.ui.gridview-Thumbnail-Raster. Ninth Round (/speckit-clarify):
-- die Steuerung spiegelt den Bild-Auswahl-Room (SelectionRoom) plus den
-- Zusatz "Verschieben".
--
-- Betreten : EditorRoom "Tile View", B + Kurbel rueckwaerts (unveraendert).
-- Verlassen: B + Kurbel VORWAERTS — erst scharf, nachdem B seit dem
--            Betreten mindestens einmal losgelassen wurde (bReleasedSinceEnter);
--            so wirft der Kurbel-Nachlauf der Eintrittsgeste einen nicht
--            sofort wieder raus (FR-022).
--
-- Steuerung (wie SelectionRoom + Zusatz):
--   D-Pad             : Raster-Cursor bewegen (hebt eine Markierung auf)
--   A                 : Frame markieren / Markierung aufheben (reiner
--                       Umschalter — A LOESCHT NIE)
--   D-Pad bei markiert : markierten Frame in der Sequenz verschieben
--                       (Links/Rechts = +/-1, Hoch/Runter = +/- eine
--                       Rasterzeile = NUM_COLS Positionen als sequenzielle
--                       Nachbar-Swaps; an den Enden geklemmt)
--   System-Menue      : "delete frame" (A/B-Bestaetigungsdialog, wirkt auf
--                       den Cursor-Frame, abgelehnt bei nur 1 Frame) und
--                       "duplicate frame" (tiefe Kopie direkt dahinter,
--                       abgelehnt bei 12 Frames)
--   B (bei offenem Dialog) : Abbrechen

import "CoreLibs/graphics"
import "CoreLibs/ui"
import "LayerModel"   -- cloneFrameLayers / copyArray (deleteFrame-Snapshot + duplicate)

local gfx = playdate.graphics
local SCREEN_WIDTH = 400
local SCREEN_HEIGHT = 240

local NUM_COLS = 3
local CELL_W = 132
local CELL_H = 104
local FRAME_CAP = 12          -- harte Obergrenze (wie UndoHistory.FRAME_CAP)
local EXIT_TICK_THRESHOLD = 4 -- wie EditorRoom.ZOOM_TICK_THRESHOLD

FrameManagementView = {}

local switchRoomFunction
local editorRoom

local imageData = nil
local cursor = 1               -- 1-basiert, Position in der Frame-Sequenz
local marked = nil             -- 1-basiert oder nil
local returnFrame = 1
local bReleasedSinceEnter = false
local confirmingDelete = nil   -- true, solange der A/B-Loeschdialog offen ist
local crankAccu = 0
local thumbCache = {}          -- [pos] = gfx.image (400x240, per drawScaled skaliert gezeichnet)
local gridview = nil
local needsRedraw = true

-- ── Abhaengigkeiten ─────────────────────────────────────────────────────────

function FrameManagementView:init(switchRoom, editorRoomReference)
    switchRoomFunction = switchRoom
    editorRoom = editorRoomReference
    needsRedraw = true
end

-- Vom EditorRoom vor switchRoom gesetzt: gemeinsames imageData + aktiver Frame.
function FrameManagementView:setImageData(data, currentFrame)
    imageData = data
    local n = (imageData and imageData.frameLayers and #imageData.frameLayers) or 1
    cursor = math.max(1, math.min(currentFrame or 1, n))
    marked = nil
end

-- ── Hilfen ──────────────────────────────────────────────────────────────────

local function frameCount()
    return (imageData and imageData.frameLayers and #imageData.frameLayers) or 0
end

-- Vertauscht zwei Frames in BEIDEN Arrays (frameLayers = Wahrheit,
-- frames = flacher Composite-Cache) — sie muessen im Gleichschritt bleiben.
local function swapFrames(a, b)
    imageData.frameLayers[a], imageData.frameLayers[b] =
        imageData.frameLayers[b], imageData.frameLayers[a]
    if imageData.frames then
        imageData.frames[a], imageData.frames[b] =
            imageData.frames[b], imageData.frames[a]
    end
end

local function notifyReindex(op)
    if editorRoom and editorRoom.onFramesReindexed then
        editorRoom:onFramesReindexed(op)
    end
end

local function gridPos(i)
    local row = math.ceil(i / NUM_COLS)
    local col = ((i - 1) % NUM_COLS) + 1
    return row, col
end

local function syncGridSelection()
    if not gridview then return end
    local row, col = gridPos(cursor)
    gridview:setSelection(1, row, col)
    gridview:scrollToCell(1, row, col, false)
end

local function buildThumbnails()
    thumbCache = {}
    if not (imageData and imageData.frames) then return end
    local tm = gfx.tilemap.new()
    if imageData.imagetable and tm.setImageTable then
        tm:setImageTable(imageData.imagetable)
    end
    for f = 1, #imageData.frames do
        local img = gfx.image.new(SCREEN_WIDTH, SCREEN_HEIGHT, gfx.kColorWhite)
        gfx.pushContext(img)
            tm:setTiles(imageData.frames[f], 25)
            tm:draw(0, 0)
        gfx.popContext()
        thumbCache[f] = img
    end
end

-- ── Aktionen ────────────────────────────────────────────────────────────────

local function moveCursor(dx, dy)
    local n = frameCount()
    if n == 0 then return end
    local _, col = gridPos(cursor)
    local target = cursor
    if dx ~= 0 then
        local newCol = col + dx
        if newCol >= 1 and newCol <= NUM_COLS then target = cursor + dx end
    elseif dy ~= 0 then
        target = cursor + dy * NUM_COLS
    end
    if target < 1 or target > n then return end
    if target ~= cursor then
        cursor = target
        marked = nil            -- Cursor bewegen hebt die Markierung auf
        needsRedraw = true
        syncGridSelection()
    end
end

-- Markierten Frame in der Sequenz verschieben. Hoch/Runter = NUM_COLS
-- Positionen, ausgefuehrt als sequenzielle NACHBAR-Swaps — so bleibt die
-- Frame-Umnummerierung fuer Spec 011 eine Folge von {swapped}-Schritten.
local function moveMarked(dx, dy)
    if not marked then return end
    local steps = (dx ~= 0) and 1 or NUM_COLS
    local sign  = (((dx ~= 0) and dx or dy) > 0) and 1 or -1
    local moved = false
    for _ = 1, steps do
        local t = marked + sign
        if t < 1 or t > frameCount() then break end
        swapFrames(marked, t)
        thumbCache[marked], thumbCache[t] = thumbCache[t], thumbCache[marked]
        notifyReindex({ swapped = { marked, t } })
        marked = t
        cursor = t
        moved = true
    end
    if moved then
        needsRedraw = true
        syncGridSelection()
    end
end

-- A: reiner Markieren/Aufheben-Umschalter (loescht NIE — Ninth Round).
local function pressA()
    marked = (marked == cursor) and nil or cursor
    needsRedraw = true
end

-- System-Menue "delete frame": wirkt auf den Cursor-Frame, ueber den
-- A/B-Bestaetigungsdialog. Abgelehnt (kein Dialog) bei nur 1 Frame.
local function onMenuDelete()
    if frameCount() <= 1 then return end
    confirmingDelete = true
    needsRedraw = true
end

local function confirmDelete()
    if not confirmingDelete then return end
    local i = cursor
    if frameCount() > 1 then
        -- Reihenfolge (Spec 011, Review F4): erst entfernen, dann den
        -- bestehenden Undo-Verlauf umnummerieren, ZULETZT den deleteFrame-
        -- Eintrag mit dem Ursprungsindex anhaengen.
        local layersCopy = LayerModel.cloneFrameLayers(imageData.frameLayers[i])
        local flatCopy = imageData.frames and LayerModel.copyArray(imageData.frames[i]) or nil
        table.remove(imageData.frameLayers, i)
        if imageData.frames then table.remove(imageData.frames, i) end
        table.remove(thumbCache, i)
        notifyReindex({ removed = i })
        if editorRoom and editorRoom.recordDeleteFrame then
            editorRoom:recordDeleteFrame(i, layersCopy, flatCopy)
        end
        marked = nil
        cursor = math.max(1, math.min(cursor, frameCount()))
    end
    confirmingDelete = nil
    needsRedraw = true
    syncGridSelection()
end

local function cancelDelete()
    confirmingDelete = nil
    needsRedraw = true
end

-- System-Menue "duplicate frame": tiefe Kopie des Cursor-Frames direkt
-- dahinter. Abgelehnt bei FRAME_CAP Frames.
local function onMenuDuplicate()
    if frameCount() >= FRAME_CAP or frameCount() == 0 then return end
    local i = cursor
    local layersCopy = LayerModel.cloneFrameLayers(imageData.frameLayers[i])
    local flatCopy = imageData.frames and LayerModel.copyArray(imageData.frames[i]) or nil
    table.insert(imageData.frameLayers, i + 1, layersCopy)
    if imageData.frames then table.insert(imageData.frames, i + 1, flatCopy) end
    table.insert(thumbCache, i + 1, thumbCache[i])   -- identischer Inhalt -> Bild teilen
    notifyReindex({ inserted = i + 1 })
    cursor = i + 1
    marked = nil
    needsRedraw = true
    syncGridSelection()
end

local function returnToEditor()
    returnFrame = cursor
    if imageData then
        imageData.returnFrame = returnFrame   -- vom EditorRoom in entered() gelesen
    end
    if switchRoomFunction and editorRoom then
        switchRoomFunction(editorRoom)
    end
end

-- ── Rendering ───────────────────────────────────────────────────────────────

function FrameManagementView:drawCell(section, row, column, selected, x, y, w, h)
    local index = (row - 1) * NUM_COLS + column
    if index < 1 or index > frameCount() then return end

    local inset = 6
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(x, y, w, h)

    local img = thumbCache[index]
    if img and img.drawScaled then
        img:drawScaled(x + inset, y + inset, (w - inset * 2) / SCREEN_WIDTH)
    end
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(x + inset, y + inset, w - inset * 2, h - inset * 2)

    if index == marked then
        gfx.drawRect(x + 2, y + 2, w - 4, h - 4)
        gfx.drawRect(x + 3, y + 3, w - 6, h - 6)   -- doppelter Rahmen = markiert
    end
    if index == cursor then
        gfx.drawRect(x, y, w, h)                    -- Auswahlring
    end
    gfx.drawText(string.format("Frame %d/%d", index, frameCount()), x + inset, y + h - 14)
end

local function drawConfirmDialog()
    local dw, dh = 200, 80
    local dx, dy = (400 - dw) // 2, (240 - dh) // 2
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(dx, dy, dw, dh)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(dx, dy, dw, dh)
    gfx.drawText(string.format("Delete Frame %d?", cursor), dx + 10, dy + 10)
    gfx.drawText("(A) delete", dx + 10, dy + 30)
    gfx.drawText("(B) cancel", dx + 10, dy + 50)
end

local function draw()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("Frames  A mark / D-Pad move / menu delete-duplicate / B+crank fwd back", 8, 4)
    if gridview then
        gridview:drawInRect(0, 20, 400, 220)
    end
    if frameCount() <= 1 then
        gfx.drawText("(last frame cannot be deleted)", 8, 224)
    end
    if confirmingDelete then
        drawConfirmDialog()
    end
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────

function FrameManagementView:entered()
    marked = nil
    confirmingDelete = nil
    bReleasedSinceEnter = false
    crankAccu = 0
    needsRedraw = true

    buildThumbnails()

    local n = math.max(1, frameCount())
    gridview = playdate.ui.gridview.new(CELL_W, CELL_H)
    gridview:setNumberOfColumns(NUM_COLS)
    gridview:setNumberOfRows(math.ceil(n / NUM_COLS))
    gridview.changeRowOnColumnWrap = false
    gridview.drawCell = function(_, section, row, column, sel, x, y, w, h)
        FrameManagementView:drawCell(section, row, column, sel, x, y, w, h)
    end
    syncGridSelection()

    -- System-Menue wie SelectionRoom:buildSystemMenu (Ninth Round).
    local menu = playdate.getSystemMenu()
    menu:removeAllMenuItems()
    menu:addMenuItem("delete frame", function() onMenuDelete() end)
    menu:addMenuItem("duplicate frame", function() onMenuDuplicate() end)

    print("Entered FrameManagementView (Room)")
end

function FrameManagementView:update()
    -- Verlassen: B + Kurbel VORWAERTS, scharf erst nach einem B-Release.
    local ticks = playdate.getCrankTicks(4) or 0
    if not playdate.buttonIsPressed(playdate.kButtonB) then
        bReleasedSinceEnter = true
        crankAccu = 0
    else
        crankAccu = math.max(0, crankAccu + ticks)
        if bReleasedSinceEnter and crankAccu >= EXIT_TICK_THRESHOLD then
            returnToEditor()
            return
        end
    end

    if needsRedraw then
        draw()
        needsRedraw = false
    end
end

function FrameManagementView:inputHandler()
    return {
        upButtonDown = function()
            if confirmingDelete then return end
            if marked then moveMarked(0, -1) else moveCursor(0, -1) end
        end,
        downButtonDown = function()
            if confirmingDelete then return end
            if marked then moveMarked(0, 1) else moveCursor(0, 1) end
        end,
        leftButtonDown = function()
            if confirmingDelete then return end
            if marked then moveMarked(-1, 0) else moveCursor(-1, 0) end
        end,
        rightButtonDown = function()
            if confirmingDelete then return end
            if marked then moveMarked(1, 0) else moveCursor(1, 0) end
        end,
        AButtonDown = function()
            if confirmingDelete then confirmDelete() else pressA() end
        end,
        BButtonDown = function()
            if confirmingDelete then cancelDelete() end
        end,
    }
end

return FrameManagementView
