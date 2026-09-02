-- UndoHistory.lua
-- Spec 011 (Foundational, data-model.md §1 / contracts C-011-1): Ringpuffer der
-- letzten <= 3 "riskanten" Operationen (Clear Screen, Frame loeschen, 90°-
-- Rotation, Pixel-Verschiebung). Reine Lua-Tabellen, kein SDK-Zugriff,
-- headless-testbar. Reiner Sitzungszustand -- NICHT persistiert (FR-008).
--
-- Eintragsformen (data-model.md §2):
--   content     : { kind="content", op="clear"|"rotate"|"shift", frameIndex,
--                   layerArrayIndex, cells = { [cellIdx] = {prevPosIndex, prevImage} },
--                   runOpen }
--   deleteFrame : { kind="deleteFrame", op="deleteFrame", index,
--                   frameLayersEntry, framesEntry }
--
-- entries[1] = AELTESTER, entries[#entries] = JUENGSTER.

UndoHistory = {}
UndoHistory.__index = UndoHistory

local MAX_ENTRIES = 3
local FRAME_CAP = 12  -- harte Frame-Obergrenze (wie EditorRoom.MAX_FRAMES)

function UndoHistory.new()
    return setmetatable({ entries = {}, MAX = MAX_ENTRIES }, UndoHistory)
end

-- FR-001: anhaengen, bei Ueberlauf den aeltesten (vorne) verdraengen.
function UndoHistory:push(entry)
    self.entries[#self.entries + 1] = entry
    while #self.entries > self.MAX do
        table.remove(self.entries, 1)
    end
end

local function frameCountOf(imageData)
    return (imageData and imageData.frameLayers and #imageData.frameLayers) or 0
end

-- Juengsten ANWENDBAREN Eintrag liefern; juengere nicht-anwendbare dabei
-- entfernen. Nicht anwendbar:
--   * content mit fehlendem/ungueltigem frameIndex           (FR-006)
--   * deleteFrame, dessen Wiedereinfuegen die 12-Grenze bricht (FR-007)
-- reason == "frame-limit", wenn dabei ein deleteFrame an der Grenze verworfen
-- wurde (steuert nur den Meldungstext in EditorRoom:undoRequest).
function UndoHistory:peekValid(imageData)
    local reason = nil
    local n = frameCountOf(imageData)
    for i = #self.entries, 1, -1 do
        local e = self.entries[i]
        local applicable = true
        if e.kind == "content" then
            if not e.frameIndex or e.frameIndex < 1 or e.frameIndex > n then
                applicable = false
            end
        elseif e.kind == "deleteFrame" then
            if n >= FRAME_CAP then
                applicable = false
                reason = "frame-limit"
            end
        end
        if applicable then
            return e, reason
        end
        table.remove(self.entries, i)
    end
    return nil, reason
end

-- Juengsten Eintrag entfernen (nach erfolgreichem Undo, FR-004).
function UndoHistory:pop()
    if #self.entries > 0 then
        table.remove(self.entries)
    end
end

-- FR-008: Verlauf leeren (Bildwechsel / Verlassen des Editors).
function UndoHistory:clear()
    self.entries = {}
end

function UndoHistory:isEmpty()
    return #self.entries == 0
end

-- Coalescing (data-model.md §4): den juengsten Eintrag liefern, wenn er
-- denselben laufenden "Run" fortsetzt (gleiches op/Ziel UND runOpen == true).
-- Sonst nil -> Aufrufer pusht einen neuen Eintrag.
function UndoHistory:coalesceTarget(op, frameIndex, layerArrayIndex)
    local e = self.entries[#self.entries]
    if e and e.runOpen and e.kind == "content" and e.op == op
        and e.frameIndex == frameIndex and e.layerArrayIndex == layerArrayIndex then
        return e
    end
    return nil
end

return UndoHistory
