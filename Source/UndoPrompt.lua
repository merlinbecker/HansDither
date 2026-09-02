-- UndoPrompt.lua
-- Spec 011 (Foundational, data-model.md §5 / contracts C-011-4): EIN globaler,
-- vollstaendig modaler Ja/Nein-Bestaetigungsdialog fuer das Schuettel-Undo.
-- Nachgebildet dem bewaehrten Muster SelectionRoom.drawConfirmDeleteDialog /
-- `confirmingDelete` (Constitution IV -- bewaehrte Muster wiederverwenden).
--
-- Die drei Editier-Raeume (EditorRoom/ZoomRoom/PixelRoom) rufen am Ende ihres
-- draw() UndoPrompt.draw() und pruefen in ihren Inputhandlern zuerst
-- UndoPrompt.isOpen(): A -> handleA(), B -> handleB(), alle anderen Eingaben
-- werden geschluckt (FR-013). Eine zweite Schuettel-Kante bei offenem Dialog
-- ist wirkungslos (open() ist No-op, FR-015).

import "CoreLibs/graphics"

local gfx = playdate.graphics

UndoPrompt = {}

local isOpen = false
local label = ""
local onConfirm = nil

-- open(label, onConfirm): oeffnet den Dialog. No-op, wenn bereits offen
-- (FR-015 -- zweites Schuetteln aendert weder label noch onConfirm).
function UndoPrompt.open(lbl, confirm)
    if isOpen then return end
    isOpen = true
    label = lbl or ""
    onConfirm = confirm
end

function UndoPrompt.isOpen()
    return isOpen
end

-- Aktuell angezeigtes Label (leer, wenn zu). Fuer Tests / Debug-Ausgaben.
function UndoPrompt.currentLabel()
    return isOpen and label or ""
end

-- "(A) Ja": onConfirm GENAU EINMAL ausfuehren, dann schliessen. Erst schliessen,
-- dann callen -- ein re-entranter Pfad sieht den Dialog bereits geschlossen.
function UndoPrompt.handleA()
    local cb = onConfirm
    isOpen = false
    onConfirm = nil
    if cb then cb() end
end

-- "(B) Nein": schliessen ohne onConfirm.
function UndoPrompt.handleB()
    isOpen = false
    onConfirm = nil
end

-- Defensiv beim Raumwechsel.
function UndoPrompt.reset()
    isOpen = false
    onConfirm = nil
end

function UndoPrompt.draw()
    if not isOpen then return end
    local w, h = 220, 84
    local x = (400 - w) // 2
    local y = (240 - h) // 2

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(x, y, w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(x, y, w, h)

    gfx.drawText(label, x + 12, y + 10)
    gfx.drawText("(A) Ja", x + 12, y + 36)
    gfx.drawText("(B) Nein", x + 12, y + 56)
end

return UndoPrompt
