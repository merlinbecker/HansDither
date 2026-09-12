# Contract: Frame Management Room & Consolidated Overlay Bar

**Feature**: `specs/010-layer-management-with-transparency/`

**Added**: 2026-09-06 (Eighth Round — from hardware testing). **Revised**: 2026-09-06 (Ninth Round, `/speckit-clarify` — controls aligned to `SelectionRoom`, delete/duplicate on the system menu); 2026-09-07 (Tenth Round — tile picker opens only after a full crank revolution). Covers `FR-018`–`FR-022`, `FR-025`, `FR-028`, `SC-004`, `SC-007`, `SC-008`.

Flat codebase (no `Source/Rooms/`). Files: `Source/FrameManagementView.lua` (rewritten), `Source/Bauchbinde.lua` (vertical anchor added — `drawBottom` signature preserved; also used by `SelectionRoom.lua:456`), `Source/EditorRoom.lua` (overlay draw + no change to the entry gesture). `main.lua` already wires `FrameManagementView:init(switchRoom, EditorRoom)`.

---

## FrameManagementView (persistent room)

### Lifecycle

| Method | Contract |
|---|---|
| `FrameManagementView:init(switchRoom, editorRoom)` | Unchanged. Stores the DI refs. |
| `FrameManagementView:setImageData(imageData, currentFrame)` | Set by `EditorRoom` before `switchRoom`. `cursor = clamp(currentFrame, 1, frameCount())`, `marked = nil`. |
| `FrameManagementView:entered()` | `marked=nil`, `confirmingDelete=nil`, `bReleasedSinceEnter=false`, `crankAccu=0`. Build `thumbCache[1..n]` (one `scaledImage` per frame, from `imageData.frames[f]` + `imageData.imagetable`). Build `gridview` (`numColumns=3`, `numRows=ceil(n/3)`, `changeRowOnColumnWrap=false`). `getSystemMenu():removeAllMenuItems()`, then **register "delete frame" and "duplicate frame"** *(Ninth Round — mirrors `SelectionRoom:buildSystemMenu`)*. |
| `FrameManagementView:update()` | Read `playdate.getCrankTicks(4)` **once** → `crankAccu` (never `getCrankChange()` in this room — CR-01). If `not buttonIsPressed(kButtonB)` → `bReleasedSinceEnter=true`. If `buttonIsPressed(kButtonB)` and `bReleasedSinceEnter` and `crankAccu >= ZOOM_TICK_THRESHOLD` → `returnToEditor()`. Redraw when `needsRedraw`. **No B-release exit.** |
| `FrameManagementView:inputHandler()` | **While `confirmingDelete`**: `AButtonDown` → `confirmDelete()`, `BButtonDown` → `cancelDelete()`, all else inert (modal, mirrors `SelectionRoom`). **Otherwise**: `up/down/left/rightButtonDown` → `marked` set: `moveMarked(dx,dy)`; else `moveCursor(dx,dy)`. `AButtonDown` → `pressA()`. No crank handler here (crank is read in `update()`). |
| *(removed)* | `bWasHeld`, the held→released exit in `update()`, the `ROW_H`/`LIST_X`/`LIST_Y` list renderer. |

### Behaviour

| Function | Contract |
|---|---|
| `frameCount()` | `#imageData.frameLayers` (≥ 1). |
| `moveCursor(dx, dy)` | 3-column grid math: `left/right` = `cursor ± 1` within the row; `up/down` = `cursor ± 3`. Clamp to `[1, frameCount()]`. On change: `marked = nil`, `needsRedraw = true`. |
| `pressA()` *(Ninth Round)* | Plain toggle: `marked ~= cursor` → `marked = cursor`; `marked == cursor` → `marked = nil`. **Never deletes.** |
| `moveMarked(dx, dy)` | `steps = (dx ~= 0) and 1 or numColumns`; `sign = ((dx ~= 0) and dx or dy) > 0 and 1 or -1`. Repeat up to `steps` times: `t = marked + sign`; **stop** if `t < 1` or `t > frameCount()`; `swapFrames(marked, t)`; `editorRoom:onFramesReindexed({ swapped = { marked, t } })`; swap `thumbCache[marked]`/`thumbCache[t]`; `marked = t`; `cursor = t`. `needsRedraw = true`. Does **not** clear `marked`. |
| `swapFrames(a, b)` | Unchanged — swaps `imageData.frameLayers[a]↔[b]` and `imageData.frames[a]↔[b]` in lockstep. |
| **menu "delete frame"** *(Ninth Round)* | If `frameCount() <= 1` → no-op (no dialog). Else `confirmingDelete = true` (target = the `cursor` frame). |
| `confirmDelete()` *(Ninth Round)* | `i = cursor`; `layersCopy = LayerModel.cloneFrameLayers(imageData.frameLayers[i])`, `flatCopy = LayerModel.copyArray(imageData.frames[i])`; `table.remove` from `frameLayers`, `frames`, `thumbCache`; `editorRoom:onFramesReindexed({ removed = i })`; `editorRoom:recordDeleteFrame(i, layersCopy, flatCopy)`; `marked = nil`; `cursor = clamp(cursor, 1, frameCount())`; `confirmingDelete = nil`. |
| `cancelDelete()` *(Ninth Round)* | `confirmingDelete = nil`. No state change. |
| **menu "duplicate frame"** *(Ninth Round)* | If `frameCount() >= 12` → no-op. Else `i = cursor`; deep-copy: `LayerModel.cloneFrameLayers(imageData.frameLayers[i])` + `LayerModel.copyArray(imageData.frames[i])`; `table.insert` both at `i+1`; rebuild/insert `thumbCache[i+1]`; `editorRoom:onFramesReindexed({ inserted = i+1 })`; `cursor = i+1`. |
| `returnToEditor()` | `imageData.returnFrame = cursor`; `switchRoomFunction(editorRoom)`. (`EditorRoom:entered()` reads `returnFrame`, clamps `currentFrame` — unchanged.) |
| `draw()` | `gridview:drawInRect(0, 0, 400, 240)`. `drawCell(section, row, col, selected, x, y, w, h)` → `index = (row-1)*3 + col`; skip if `> frameCount()`; draw `thumbCache[index]` centred in the cell; frame border if `index == marked`; selection ring if `index == cursor`; "Frame i/n" caption. **If `confirmingDelete`**: draw the confirm dialog last, in the `SelectionRoom:drawConfirmDeleteDialog` style ("Delete Frame N?  (A) Yes  (B) No"). |

### Invariants

- `1 <= cursor <= frameCount()`; `marked ∈ {nil} ∪ [1, frameCount()]`.
- `#thumbCache == frameCount()` after every `entered()` / `moveMarked` / `confirmDelete` / duplicate.
- `imageData.frameLayers` and `imageData.frames` stay equal length and in lockstep.
- Spec 011's `onFramesReindexed` is passed `{ swapped = {i, i±1} }` (adjacent, one per reorder step), `{ removed = i }` (delete), or `{ inserted = i }` (duplicate) — never a multi-slot move. The `{ inserted }` case is new in the Ninth Round; `undoHistory:remapFrames` must handle it as the mirror of `{ removed }`.
- The room never starts the accelerometer; shake is not evaluated here (Spec 011 FR-010).

---

## EditorRoom (entry gesture + overlay draw)

| Element | Contract |
|---|---|
| Entry gesture | **Unchanged.** `handleCrank`: `buttonIsPressed(kButtonB)` and `zoomTickAccu <= -ZOOM_TICK_THRESHOLD` → `openFrameManagementView()` (which calls `frameManagementView:setImageData(imageData, currentFrame)` then `switchRoomFunction(frameManagementView)`). |
| `openFrameManagementView()` | Unchanged guard: `frameManagementView and not inputBlocked()`. |
| `EditorRoom:entered()` (return trip) | Unchanged: reads `imageData.returnFrame`, clamps `currentFrame` + `activeLayer` into the (possibly shorter/reordered) sequence, `updateTilemapFrame()`, rebuilds the system menu. |
| Overlay draw | `vAnchor = (cursor.y <= GRID_ROWS / 2) and "bottom" or "top"`. Compose **one** content block: line 1 = `pickMessageVisible and pickMessage` or the `"Frame x/y  L#/# name"` label; line 2 = `statusMessage` (if set) in the **same** band; the tile-picker filmstrip stacked in the same anchored region when `pickerVisible`. Draw via `bauchbinde:draw(lines, hSide, vAnchor, 400, 240)`. **No** second fixed-side `drawBottom` for `statusMessage`. `UndoPrompt.draw()` still called last (separate layer). |
| `drawTilePickerOverlay()` | Horizontal centring kept. Vertical position becomes `vAnchor`-relative (`vAnchor=="top"` → `py = margin`; `"bottom"` → `py = 240 - panelH - margin - labelH`). Never screen-centre. |
| Picker activation *(Tenth Round, 2026-09-07)* | `handleCrank` no-B branch: while `not pickerVisible`, `pickerArmDegrees += getCrankChange()` (signed); `math.abs(pickerArmDegrees) >= PICKER_ACTIVATE_DEGREES` (`360`) → `pickerVisible = true`, `pickerArmDegrees = 0`, `crankAccumDegrees = 0` (opening turn selects no tile), then `return`. While `pickerVisible`, the unchanged `crankAccumDegrees` / `PICKER_DEGREES_PER_TILE` (`30`) stepping runs. Any `change ~= 0` sets `lastActivityMs` (keeps the label alive mid-gesture). `pickerArmDegrees` reset to 0 on: activation, the `pickerUntilMs` auto-hide, any `buttonIsPressed(kButtonB)` frame, `entered()`. CR-01 intact (no-B branch uses only `getCrankChange()`). |

### Pure helpers (headless-testable — new)

| Function | Contract |
|---|---|
| `overlayAnchor(cursorY, rows)` | `"bottom"` if `cursorY <= rows / 2`, else `"top"`. |
| `overlayRegionRect(anchor, contentH, screenH)` | `{ x = 0, y = (anchor == "top") and MARGIN or (screenH - contentH - MARGIN), w = 400, h = contentH }`. |
| `cursorCellRect(cx, cy)` | `{ x = (cx-1)*16, y = (cy-1)*16, w = 16, h = 16 }`. |
| **SC-008 invariant** | ∀ `cy ∈ [1, GRID_ROWS]`: `overlayRegionRect(overlayAnchor(cy, GRID_ROWS), h, 240)` ∩ `cursorCellRect(cx, cy)` = ∅. Picker visible → label / filmstrip / status sub-rects pairwise disjoint. |

---

## Bauchbinde

| Method | Contract |
|---|---|
| `Bauchbinde.new(gfx, config?)` | Unchanged (`margin`, `paddingX`, `height`). |
| `Bauchbinde:draw(lines, hSide, vAnchor, screenW, screenH)` | **New.** `lines` = string or array of strings. `vAnchor` `"top"` → `bandY = margin`; `"bottom"` → `bandY = screenH - bandH - margin`. `bandH` grows for multi-line. `hSide` `"left"|"right"` unchanged. White fill, black border, black text. |
| `Bauchbinde:drawBottom(text, side, screenW, screenH)` | **Kept with the exact current signature** as a thin wrapper: `self:draw(text, side, "bottom", screenW, screenH)`. The one other caller — `SelectionRoom.lua:456` `bauchbinde:drawBottom(label, "left", 400, 240)` — is therefore unaffected. Only `EditorRoom` calls the new `draw`. |

---

## Spec 011 compatibility

| Hook | Contract |
|---|---|
| `editorRoom:onFramesReindexed({ swapped = {a, b} })` | Called once per adjacent swap during reorder (a multi-row move = several calls). Unchanged signature. |
| `editorRoom:onFramesReindexed({ removed = i })` | Called once on confirmed delete, **before** `recordDeleteFrame`. Unchanged. |
| `editorRoom:onFramesReindexed({ inserted = i })` *(Ninth Round — NEW)* | Called once on "duplicate frame". `undoHistory:remapFrames` must shift entries at `>= i` up by one — the mirror of `{ removed }`. Payload shape to be finalised in `/speckit-tasks`. |
| `editorRoom:recordDeleteFrame(i, layersCopy, flatCopy)` | Called last on confirmed delete with the original index + deep copies. Unchanged. |
| `UndoPrompt` | Stays a separate modal layer in `EditorRoom.draw` (Spec 011 FR-013 — full modality; not folded into the overlay bar). |
| Shake / accelerometer | Not started, not evaluated in `FrameManagementView` (Spec 011 FR-010 exclusion list). |

---

**Status**: ✅ Contract complete — Eighth-Round Frame Room + overlay bar, **Ninth-Round control alignment** (delete/duplicate on the system menu, `SelectionRoom` confirm dialog, A = mark/unmark toggle), **Tenth-Round picker activation gate** (`pickerArmDegrees`, full revolution to open — implemented, headless green, buildNumber 41). `FR-021`/`FR-022` refinements are in `spec.md` (Ninth Round). Hardware follow-up in ADR-042 *Nachtrag (10. Runde)* / T094.
