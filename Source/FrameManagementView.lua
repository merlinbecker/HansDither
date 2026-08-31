-- FrameManagementView.lua
-- Spec 010 US4 (Third Round): Frame-Verwaltung. Erreichbar aus dem EditorRoom
-- ("Tile View") durch Halten von B + Kurbel rueckwaerts. Listet ALLE
-- Animationsframes; der Nutzer kann Frames neu anordnen und loeschen, damit
-- die Animation steuerbar bleibt. KEINE Ebenen-Verwaltung — Ebenen sind eine
-- feste Struktur von 3 pro Frame.
--
-- Steuerung (research.md R5, an die B-Halte-Geste angepasst):
--   D-Pad hoch/runter : Listen-Cursor bewegen (hebt eine Markierung auf)
--   A                 : Frame unter dem Cursor markieren
--   A auf markiertem  : markierten Frame LOESCHEN (abgelehnt bei nur 1 Frame)
--                       — zweiter A-Druck = die Zwei-Schritt-Bestaetigung
--                       (Session-1-Klarstellung; B ist durch die Halte-Geste
--                       belegt, daher A statt B zum Bestaetigen)
--   Links / Rechts    : markierten Frame eine Position frueher / spaeter
--                       (an den Enden geklemmt); Cursor + Markierung folgen
--   B loslassen       : zurueck zum Tile View (currentFrame wird geklemmt)

import "CoreLibs/graphics"

local gfx = playdate.graphics
local SCREEN_WIDTH = 400
local SCREEN_HEIGHT = 240

FrameManagementView = {}

local switchRoomFunction
local editorRoom

local imageData = nil
local cursor = 1        -- 1-basiert, Position in der Frame-Liste
local marked = nil      -- 1-basiert oder nil
local returnFrame = 1   -- Frame, zu dem der EditorRoom zurueckkehren soll
local bWasHeld = false
local needsRedraw = true

-- ── Abhaengigkeiten ──────────────────────────────────────────────────────────

function FrameManagementView:init(switchRoom, editorRoomReference)
    switchRoomFunction = switchRoom
    editorRoom = editorRoomReference
    needsRedraw = true
end

-- Vom EditorRoom vor switchRoom gesetzt: das gemeinsame imageData plus der
-- aktuell im Editor aktive Frame (Startposition des Cursors).
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

local function moveMarked(delta)
    if not marked then return end
    local target = marked + delta
    if target < 1 or target > frameCount() then return end  -- an den Enden geklemmt
    swapFrames(marked, target)
    marked = target
    cursor = target
    needsRedraw = true
end

local function deleteMarked()
    if not marked then return end
    if frameCount() <= 1 then return end  -- mindestens 1 Frame bleibt (FR-020)
    table.remove(imageData.frameLayers, marked)
    if imageData.frames then table.remove(imageData.frames, marked) end
    marked = nil
    cursor = math.max(1, math.min(cursor, frameCount()))
    needsRedraw = true
end

local function moveCursor(delta)
    local n = frameCount()
    if n == 0 then return end
    local newCursor = math.max(1, math.min(cursor + delta, n))
    if newCursor ~= cursor then
        cursor = newCursor
        marked = nil  -- Cursor bewegen hebt die Markierung auf
        needsRedraw = true
    end
end

local function pressA()
    if marked == cursor then
        deleteMarked()
    else
        marked = cursor
        needsRedraw = true
    end
end

local function returnToEditor()
    returnFrame = cursor
    if imageData then
        imageData.returnFrame = returnFrame  -- vom EditorRoom in entered() gelesen
    end
    if switchRoomFunction and editorRoom then
        switchRoomFunction(editorRoom)
    end
end

-- ── Rendering ───────────────────────────────────────────────────────────────

local ROW_H = 18
local LIST_X = 40
local LIST_Y = 30

local function draw()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("Frames  (A mark / A again delete, </> move, release B: back)", 8, 6)

    local n = frameCount()
    for i = 1, n do
        local y = LIST_Y + (i - 1) * ROW_H
        local isCursor = (i == cursor)
        local isMarked = (i == marked)

        if isCursor then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(LIST_X - 6, y - 2, 200, ROW_H)
            gfx.setColor(gfx.kColorWhite)
        else
            gfx.setColor(gfx.kColorBlack)
        end

        local label = string.format("Frame %d / %d", i, n)
        if isMarked then label = "[*] " .. label end
        gfx.drawText(label, LIST_X, y)
        gfx.setColor(gfx.kColorBlack)
    end

    if n <= 1 then
        gfx.drawText("(last frame cannot be deleted)", LIST_X, LIST_Y + n * ROW_H + 6)
    end
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────

function FrameManagementView:entered()
    bWasHeld = playdate.buttonIsPressed(playdate.kButtonB)  -- meist true (Eintritts-Geste)
    needsRedraw = true
    playdate.getSystemMenu():removeAllMenuItems()
    print("Entered FrameManagementView")
end

function FrameManagementView:update()
    -- Zurueck zum Tile View, sobald B von "gehalten" auf "los" wechselt.
    -- WICHTIG: `bWasHeld` wird bei JEDEM gehaltenen B (neu) gesetzt — nicht nur
    -- beim Eintritt. Sonst gaebe es eine Sackgasse: kommt die letzte
    -- Kurbel-Tick der Eintrittsgeste erst NACH dem B-Release an, waere
    -- `bWasHeld` false und der einzige Ausgang (gehalten->los) nie mehr
    -- ausloesbar. So genuegt ein erneuter B-Tipp, um herauszukommen.
    local bHeld = playdate.buttonIsPressed(playdate.kButtonB)
    if bHeld then
        bWasHeld = true
    elseif bWasHeld then
        returnToEditor()
        return
    end

    if needsRedraw then
        draw()
        needsRedraw = false
    end
end

function FrameManagementView:inputHandler()
    return {
        upButtonDown = function() moveCursor(-1) end,
        downButtonDown = function() moveCursor(1) end,
        leftButtonDown = function() moveMarked(-1) end,
        rightButtonDown = function() moveMarked(1) end,
        AButtonDown = function() pressA() end,
    }
end

return FrameManagementView
