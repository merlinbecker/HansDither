# Quickstart: Layer Management, Precise Pixel Shifting & Transparency Support

**Feature**: `specs/010-layer-management-with-transparency/`

**Purpose**: End-to-end validation scenarios that prove the feature works as specified

---

## Prerequisites

- Hans-Dither source code cloned and built successfully (Spec 009 merged)
- Playdate Simulator available (`pdc` and simulator tools)
- buildNumber incremented in `Source/pdxinfo` before testing
- Spec 009 (Tile Cleanup) is deployed (Layer feature depends on robust tile management)

---

## Test Scenario 1: Layer & Frame Switching with B + D-Pad (US3, Fourth Round)

**Goal**: Verify that the 3 fixed layers cycle via **B + Up/Down** and frames step via **B + Left/Right**, with the Crank reserved for the tile picker.

**Setup**:
1. Create a new Hans-Dither project with 3 frames (every frame already has 3 layers — nothing to "create")
2. In Frame 1:
   - Layer 1 (bottom): draw a background pattern (its non-ink pixels are white)
   - Layer 2: cycle to it (hold B + press Up), draw a character sprite (its non-ink pixels are transparent)
   - Layer 3: cycle to it, draw an effect overlay
3. Save the image

**Test Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Enter Tile View, verify Frame 1 is displayed with all 3 layers composited | All 3 layers visible: background at bottom, character in middle, effects transparent on top |
| 2 | Verify layer indicator shows "L1/3 Layer 1" | On-screen indicator displays active layer index + name |
| 3 | Hold B, press Up once | Layer indicator changes to "L2/3 ..." |
| 4 | While still holding B, press Up again | Layer indicator changes to "L3/3 ..." |
| 5 | While still holding B, press Up again | Layer indicator changes to "L1/3 ..." (wraparound) |
| 6 | Still holding B, press Right once | Frame indicator changes to "Frame 2/3"; active layer index unchanged |
| 7 | Holding B, press Down twice | On Frame 2 (also 3 layers): active layer goes Layer 1 → Layer 3 → Layer 2 |
| 8 | Holding B, press Left back to Frame 1 | Frame 1's active layer index is preserved; every frame always has 3 layers |
| 9 | Release B, turn the Crank | The **tile picker** overlay appears (Scenario 7) — it does **not** switch layer or frame |

**Acceptance Criteria**:
- ✅ Layer cycling works forward (B + Up) and backward (B + Down), wrapping Layer 3 → Layer 1
- ✅ Frame stepping works with B + Left/Right; B + Right on the last frame appends a new frame
- ✅ The Crank alone switches neither layer nor frame (it drives the tile picker)
- ✅ Every frame always has the same 3 layers; the active index is preserved across frame switches

---

## Test Scenario 2: Pixel Transparency (US2)

**Goal**: Verify that transparent pixels can be placed, stored, and rendered distinctly.

**Setup**:
1. Open the Scenario 1 image, Frame 1
2. Cycle to **Layer 2** (hold B + press Up) — transparency only exists on Layers 2–3
3. Enter Zoom View, then Pixel View on a Layer 2 tile

**Test Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Cursor at pixel (5, 5) in Pixel View | Cursor visible in 16×16 grid |
| 2 | Press A | Black ink pixel at (5, 5) |
| 3 | Press A again on (5, 5) | Pixel (5, 5) erases to the checkerboard pattern (transparent — Layer 2's non-ink state) |
| 4 | Move to (6, 5), press A twice | Pixel (6, 5) goes ink → transparent, same as step 2–3 |
| 5 | Move to (5, 5), press B (tap) | **Nothing happens** — B does not paint in Pixel View (Fifth Round) |
| 6 | Verify visual distinction: ink (black) vs. transparent (checkerboard) | The two states are clearly different |
| 7 | Zoom out to Tile View | Where Layer 2 is transparent, Layer 1 shows through |
| 8 | Save, close, reload | Transparent pixels preserved; the Layer 2 tile round-trips distinctly from a white tile |

Then repeat on **Layer 1**: an A-press on an ink pixel erases to **white** — Layer 1 has no transparent state. A B-tap does nothing here either.

**Acceptance Criteria**:
- ✅ A places ink; A on an ink pixel erases to the layer's non-ink state (transparent on Layers 2–3, white on Layer 1)
- ✅ B does **not** paint — a lone B-tap in Pixel View is inert; B held + Crank backward still zooms out
- ✅ Transparent pixels render with checkerboard in Pixel View
- ✅ Transparent pixels let lower layers show through in Tile View
- ✅ Transparent tiles persist through save/reload, distinct from white tiles
- ✅ Legacy images load with black/white pixels only (no transparency)

---

## Test Scenario 3: Per-tile Pixel Shifting (US1, revised 2026-09-01 — ADR-043)

**Goal**: Verify that B + arrow nudges **only the cursor's tile** by 1 pixel, and that content crossing the tile boundary moves into the neighbour tile and stays.

**Setup**:
1. Create new Hans-Dither project
2. Zoom into one tile; draw a shape that touches the **right edge** of that tile (e.g. a vertical line at local x=15) plus one pixel mid-tile
3. Make sure the tile to the right also has some drawn content, so you can see it being overwritten
4. Save image

**Test Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | In Zoom View on that tile (Layer 1) | Cursor's tile is the centre of the 3×3 context; right neighbour visible |
| 2 | Hold B and press Right once | The tile's content moves right 1px; the right-edge column crosses into the **left edge of the right neighbour**; the neighbour's own content shifted right too and its far (right) column fell off; **no other tile changed**; the tile's left column is now blank (Layer-1 white) |
| 3 | Hold B, press Right ~15 more times | The shape walks fully out of the source tile and accumulates in the right neighbour, overwriting what was there; the source tile ends up empty |
| 4 | Move cursor (no B) to a tile at the far-right column of the tile grid, hold B, press Right | Only that tile changes; the column that crosses the boundary is discarded (no wrap, no neighbour) |
| 5 | Hold B and press Up / Down / Left on a mid-grid tile | Same behaviour toward the top / bottom / left neighbour respectively |
| 6 | Save, reload | Shifted positions preserved exactly |
| 7 | Repeat on Frame 2, then check Frame 1 | Frame 1 unchanged (shifts are per-frame) |
| 8 | On Layer 2/3, shift a tile whose only content crosses out | The emptied upper-layer tile becomes fully transparent (shows Layer 1 through); its content is now in the neighbour |

**Acceptance Criteria**:
- ✅ B + arrow shifts **only the cursor's tile + its one neighbour** in the push direction — never the whole screen
- ✅ Content crossing the boundary moves into the neighbour and stays there; repeated presses accumulate it there (the neighbour's far edge falls off)
- ✅ A pixel not on the leading edge just moves 1px and stays in the tile
- ✅ At the tile-grid edge: only the source tile changes, the crossing strip is discarded (no wrap)
- ✅ Source tile's vacated edge = the layer's non-ink state (white on Layer 1, transparent on Layers 2–3)
- ✅ Shifted positions persist through save/reload; shifts are per-frame
- ✅ Each key press feels instant (the shift touches ≤ 2 tiles — ADR-043; device FPS check still open, T053/T054)

---

## Test Scenario 4: Frame Management Room (US4, Ninth Round — controls mirror the project-selection room)

**Goal**: Verify the persistent Frame Management Room — enter/stay/reorder/delete/duplicate/exit — with a thumbnail grid and `SelectionRoom`-style controls.

**Setup**:
1. Create a new image with 6 frames; draw something distinct in each so the thumbnails are tellable apart
2. Save the image

**Test Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | In Tile View, hold B and rotate Crank **backward** (counterclockwise) | Frame Management Room opens: Frame 1–6 as rectangular thumbnails in a 3-column grid |
| 2 | Release B and the Crank; wait | The room **stays open** (no hold needed) |
| 3 | D-Pad around the grid (up/down = ±3, left/right = ±1) | The selection ring moves between thumbnails; no frame moves |
| 4 | Cursor on Frame 3, press A | Frame 3 gets a marked border |
| 5 | Press A again | The mark clears (A is a plain toggle — it never deletes) |
| 6 | Press A on Frame 3, then press Right | Frame 3 moves one position later → order 1,2,4,3,5,6; the mark follows and stays |
| 7 | Press Down | Frame 3 moves ~one grid row later (up to 3 positions, clamped) → order 1,2,4,5,6,3; the mark follows |
| 8 | Press A | The mark clears; the new order stays |
| 9 | Put the cursor on a frame, open the system menu → **"delete frame"** | A confirm dialog appears: "Delete Frame N?  (A) Yes  (B) No" |
| 10 | Press A in the dialog | The frame is removed; the grid shrinks to 5 |
| 11 | Cursor on a frame, system menu → **"duplicate frame"** | A deep copy is inserted directly after; the grid grows to 6; cursor is on the new copy |
| 12 | Delete frames via the menu until 1 remains | The "delete frame" item is **rejected** with no dialog when only 1 frame is left |
| 13 | Release B, then hold B and rotate the Crank **forward** | Returns to Tile View; `currentFrame` clamped into the reordered/shortened sequence |
| 14 | Save and reload | The new frame order and count persist |
| 15 | Re-enter the room, immediately (still holding B from entry) crank **forward** without releasing B | **Nothing happens** — the exit is armed only after B has been released once (R-32 guard) |

**Acceptance Criteria**:
- ✅ Enter with B + Crank backward; the room persists after B/Crank release
- ✅ Frames shown as a rectangular thumbnail grid; controls mirror the project-selection room (D-Pad navigates, A marks/unmarks, B is back/cancel)
- ✅ A is a plain mark/unmark toggle — it never deletes
- ✅ D-Pad moves the marked frame (Left/Right ±1, Up/Down ±one grid row as sequential adjacent steps, clamped); the mark follows and is not cleared by moving
- ✅ "delete frame" (system menu) acts on the cursor frame, shows an A/B confirm dialog, and is rejected with no dialog at 1 frame
- ✅ "duplicate frame" (system menu) deep-copies the cursor frame directly after it; rejected at 12 frames
- ✅ Leave with B + Crank forward, armed only after one B-release; `currentFrame` clamped
- ✅ Reorder / delete persist through save/reload
- ✅ No accidental exit from entry-gesture crank residual (step 12)
- ✅ No Layer View; the room's system menu has exactly "delete frame" + "duplicate frame"

---

## Test Scenario 5: Backward Compatibility (v1.0 Images)

**Goal**: Verify that images created under Spec 009 load correctly without errors.

**Setup**:
1. Have a valid Spec 009 image file (v1.0 JSON + PDI) ready
2. Attempt to load in Hans-Dither

**Test Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Load a Spec 009 image in Tile View | Loads without error, renders identically |
| 2 | Hold B + press Up to cycle layers | Cycles Layer 1 → 2 → 3 → 1; Layer 1 holds the old content, Layers 2–3 are empty |
| 3 | Enter Pixel View on Layer 1 | Pixels are ink / white only (no transparency on Layer 1) |
| 4 | Save image | File is written in v1.1 format — one layer entry on disk (empty Layers 2–3 omitted) |
| 5 | Reload image | Renders identically to Step 1; still 3 layers in the editor |
| 6 | Verify JSON | `"version": "1.1"`, `frames[].layers` present, no `transparency` field |

**Acceptance Criteria**:
- ✅ Spec 009 images load without dialog or error
- ✅ Auto-upgrade: old content → Layer 1; Layers 2–3 added empty (3 layers in editor)
- ✅ Save writes v1.1; empty upper layers omitted from disk
- ✅ User sees no disruption

---

## Test Scenario 6: Multi-Layer Compositing (Visual)

**Goal**: Verify that multiple layers render correctly in Tile View with proper stacking order.

**Setup**:
1. Any frame (all frames have 3 layers)
2. Layer 1: draw a background pattern (its non-ink pixels are white)
3. Layer 2: draw a character sprite with some transparent pixels
4. Layer 3: draw an effect overlay, mostly transparent

**Test Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Tile View | All 3 layers composited, Layer 1 bottom → Layer 3 top |
| 2 | Check transparent regions | Where Layers 2/3 are transparent, the layer below shows through |
| 3 | Cycle to Layer 1 (B + Up) | Indicator "L1/3 Layer 1"; still composited with the others |
| 4 | Draw in Zoom/Pixel View | Only Layer 1 changes; Layers 2 & 3 untouched |
| 5 | Cycle to Layer 2 | Indicator "L2/3 Layer 2" |
| 6 | Draw in Zoom/Pixel View | Only Layer 2 changes; Layers 1 & 3 untouched |

**Acceptance Criteria**:
- ✅ Layers render in correct stacking order (0 bottom, N-1 top)
- ✅ Active layer is editable; inactive layers read-only
- ✅ Transparent pixels are visually transparent (see through to layers below)
- ✅ Drawing on one layer doesn't affect other layers

---

## Test Scenario 7: Tile Picker & Eyedropper Toast (US5, Fourth Round; picker activation revised Tenth Round)

**Goal**: Verify the Crank opens a tile picker that cycles the referenced tiles, and that the eyedropper shows a "Tile N picked" toast.

**Setup**:
1. Open any image that uses several distinct tiles (draw a few different 16×16 tiles if needed)

**Test Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 0a | In Tile View, with B **not** held, jiggle the Crank back and forth a little (well under a full turn) | **Nothing happens** — no picker overlay (Tenth Round: opens only on a full revolution) |
| 0b | Turn the Crank one **full revolution** (either direction) | The picker overlay appears; it is **not** yet on a new tile (the opening turn selects nothing) |
| 1 | Keep turning the Crank slowly | The filmstrip overlay sits inside the cursor-opposite bar; the highlighted tile changes ~1 per 30° of rotation; "Tile N" is shown below it |
| 2 | Keep turning past the last tile | Selection wraps back to tile 1 (white = "no selection") |
| 3 | Turn the Crank the other way | Selection steps backward, wrapping at tile 1 → last tile |
| 4 | Stop turning, wait ~2 s | The overlay auto-hides; the selected tile is now the active drawing tile |
| 5 | Press A over an empty cell | The cell is painted with the picked tile |
| 6 | Move the cursor onto a non-white tile, give a short B-tap (no Crank, no D-Pad during the hold) | Bauchbinde briefly shows "Tile N picked"; after ~1.5 s it reverts to "Frame x/y ..." |
| 7 | Hold B and press Up/Down/Left/Right | Layer / frame switches (Scenario 1) — the B-tap eyedropper does **not** also fire |

**Acceptance Criteria**:
- ✅ A partial turn or back-and-forth jiggle does **not** open the picker; a full crank revolution (either direction) does, without selecting a tile (Tenth Round)
- ✅ After the auto-hide, another full revolution is needed to re-open (the fine 30°/tile stepping only applies while the picker is open)
- ✅ Crank (no B) opens the tile picker and cycles the referenced tiles with wraparound
- ✅ The picker never shows orphaned session tiles (only tiles referenced in the layer positions)
- ✅ A tile that exists only on a layer covered by a higher layer is still reachable in the picker (and does not disappear when the higher layer covers its cell)
- ✅ Overlay auto-hides ~1.5 s after the last rotation; the selection persists as the active tile
- ✅ Eyedropper shows "Tile N picked" for ~1.5 s
- ✅ A B-release that followed a B + D-Pad navigation does not fire the eyedropper

---

## Test Scenario 8: Consolidated Overlay Bar Never Covers the Cursor (FR-028 / SC-008, Eighth Round)

**Goal**: Verify all passive Tile View overlay chrome sits in one bar on the edge opposite the cursor and never hides the cursor's tile or overlaps itself.

**Setup**:
1. Open any image with several distinct referenced tiles and more than one layer (so the "L#/# name" segment shows)

**Test Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Move the tile cursor into the **top half** of the grid (row ≤ 7) | The frame/layer label bar sits along the **bottom** edge |
| 2 | Move the cursor into the **bottom half** (row ≥ 8) | The bar moves to the **top** edge; it never covers the cursor's tile |
| 3 | With the cursor in the bottom half, turn the Crank to open the tile picker | The picker filmstrip appears **inside the same top bar** — not centred over the artwork — stacked with the label line, nothing overlapping |
| 4 | Trigger a status message (e.g. attempt an invalid action) with the cursor on the **right** half | The status text shares the same bar as the frame/layer label without overdrawing it (previously both landed bottom-left) |
| 5 | Move the cursor to the exact vertical middle | The bar defaults to the bottom edge |
| 6 | Trigger the Spec 011 shake→undo dialog while the bar is visible | The `UndoPrompt` box draws as its own modal layer, clear of the bar; A/B still only affect the dialog |

**Acceptance Criteria**:
- ✅ One bar carries frame/layer label + tile picker + "Tile N picked" toast + status
- ✅ Bar anchors to the edge opposite the cursor (top-half cursor → bottom bar, and vice versa; tie → bottom)
- ✅ The bar never covers the cursor's tile, for any cursor row
- ✅ No two bar elements overdraw each other
- ✅ The tile picker is never drawn screen-centred over the artwork
- ✅ The Spec 011 `UndoPrompt` stays a separate modal layer, coordinated so it never overlaps the bar

---

## Constitution V Gates (Mandatory)

**Gate 1: Headless Tests**
```bash
cd /Users/merlinbecker/code/HansDither
lua tests/headless_tests.lua
```

**Expected Output**: 
- All tests pass
- Final line: `ALLE TESTS BESTANDEN`

**Gate 2: Build + buildNumber Increment**
```bash
# Increment buildNumber in Source/pdxinfo
# Then run build:
pdc Source "Hans Dither.pdx"
```

**Expected Output**:
- Build succeeds without errors
- Binary `Hans Dither.pdx` created/updated
- Simulator/device can launch the binary

---

## Validation Checklist

- [ ] **US1 (Per-tile Pixel Shifting)**: Test Scenario 3 passes — B + arrow shifts only the cursor's tile + one neighbour, content migrates into the neighbour, no wrap at the grid edge, persists
- [ ] **US2 (Transparency)**: Test Scenario 2 passes — an A-press on ink erases to the layer's non-ink state (transparent on Layers 2–3); B does not paint; transparent pixels stored/rendered/persisted
- [ ] **US3 (Layer/Frame Switching)**: Test Scenario 1 passes — B + Up/Down = layer, B + Left/Right = frame, Crank switches neither
- [ ] **US4 (Frame Management Room, Eighth + Ninth Round)**: Test Scenario 4 passes — persistent room (B+Crank in/out, armed exit), thumbnail grid, `SelectionRoom`-style controls, A mark/unmark toggle, D-Pad reorder, system-menu "delete frame" (A/B confirm, min. 1) + "duplicate frame" (max 12), persists
- [ ] **US5 (Tile Picker + Toast)**: Test Scenario 7 passes — jiggle/partial turn does not open the picker, a full revolution does (Tenth Round); once open the Crank cycles referenced tiles with wrap; eyedropper shows "Tile N picked"
- [ ] **FR-028 / SC-008 (Consolidated overlay, Eighth Round)**: Test Scenario 8 passes — one cursor-opposite bar, never covers the cursor, no self-overlap, picker not screen-centred, `UndoPrompt` separate layer
- [ ] **Backward Compat**: Test Scenario 5 passes — v1.0 images load as Layer 1 + two empty upper layers
- [ ] **Compositing**: Test Scenario 6 passes — 3 layers render correctly, editing isolated to the active layer
- [ ] **Gate 1 (Tests)**: `lua tests/headless_tests.lua` passes with "ALLE TESTS BESTANDEN"
- [ ] **Gate 2 (Build)**: `pdc Source "Hans Dither.pdx"` succeeds, buildNumber incremented
- [ ] **Round-Trip**: Save/reload tested in all scenarios — data persists exactly

---

## Troubleshooting

| Issue | Diagnosis | Resolution |
|-------|-----------|-----------|
| Frame Management View doesn't open | B + Crank-backward not bound in `EditorRoom.handleCrank` | Check the `zoomTickAccu <= -ZOOM_TICK_THRESHOLD` branch (B-held branch) |
| B + Up/Down or B + Left/Right doesn't switch layer/frame | `*ButtonDown` handler not checking `buttonIsPressed(kButtonB)` before `startMove` | Check `EditorRoom:inputHandler` — B-held routes to `bDpadNav` |
| Crank does nothing / no tile-picker overlay | no-B branch of `handleCrank` not accumulating into `pickerArmDegrees`, or `pickerVisible` never set | Check `handleCrank` else-branch: `pickerArmDegrees` must reach `PICKER_ACTIVATE_DEGREES` (360) to open, then `crankAccumDegrees` drives the 30°/tile steps + `drawTilePickerOverlay` gate in `draw()` |
| Tile picker pops up from the smallest crank touch | pre-Tenth-Round behaviour (`if change ~= 0 then pickerVisible = true`) still in place | no-B branch must gate on `math.abs(pickerArmDegrees) >= PICKER_ACTIVATE_DEGREES` before setting `pickerVisible`; reset `pickerArmDegrees` on activation / auto-hide / B-hold / `entered()` |
| Tile picker cycles through blank/garbage tiles, or a drawn tile is unreachable | iterating `imagetable:getLength()`, or scanning the flat composite cache (drops covered-layer tiles) | `referencedTileIndices()` must scan `frameLayers[*].layers[*].positions` (skip `0`), keeping index 1 |
| B-tap after B + D-Pad also picks a tile | `bNavConsumed` not latched in `bDpadNav`, or derived from live button state | Set it inside `bDpadNav`; clear only in `BButtonDown`/`BButtonUp` |
| "Tile N picked" never disappears | no timeout-transition redraw for `pickMessage` | Mirror the `bauchbindeVisible` pattern in `update()` |
| Transparent pixels render as white | Tile built without `kColorClear`, or `hashTile` not 3-class | Check `PixelRoom.buildTileImage` + `ImageStoreCodec.hashTile` |
| Upper-layer eraser leaves opaque white | `writeActiveLayerPosition` not mapping white→absent on Layers 2–3 | Check `EditorRoom.writeActiveLayerPosition` |
| Multi-layer edit lost on save | `imageData.frames` mutated directly instead of `frameLayers` | All edits must go through the active layer + `recompositeCell` |
| Pixel shift causes visual corruption | Tile recalculation incomplete | Debug `LayerModel.shiftTileContent` (the 2-tile strip build + `writeCell` dedup) |
| B + arrow shifts the whole screen, not one tile | Calling a whole-layer shift (removed `LayerModel.shiftLayerContent`) instead of `LayerModel.shiftTileContent(entry, active1, cellIdx, dir, …)` | `EditorRoom:shiftActiveLayer` must pass a `cellIdx`; ZoomRoom passes `slots[<cursor slot>].frameIndexPos` (ADR-043) |
| Content that crosses the tile boundary disappears instead of landing in the neighbour | `shiftTileContent` not writing the neighbour, or `neighborIdx` computed wrong (off-grid check) | Neighbour = source cell ± the direction delta, only if inside the 25×15 grid; it gets the source's facing edge and shifts along (2-tile strip) |
| Shift wraps around the tile grid edge | Leftover wrap logic (the removed whole-layer shift wrapped; per-tile does not) | At the grid edge `neighborIdx` is `nil` → only the source tile changes, crossing strip discarded (ADR-043) |
| Old images don't load | Structure-based v1.0 detection failed | Check `newLoadOperation`'s `frames[1].layers` test + pad-to-3 |
| buildNumber not incremented | Manual step forgotten | Increment once per `pdc` run |
| Frame Room closes the instant you enter it | Exit not armed — forward crank residual from the entry gesture triggers exit | `bReleasedSinceEnter` must gate the B+Crank-forward exit; reset it false in `entered()` (R-32 / ADR-048) |
| Frame Room won't close | `getCrankTicks(4)` not read in `update()`, or `bReleasedSinceEnter` never set | Read crank once per `update()`; set `bReleasedSinceEnter=true` on any frame B is not pressed |
| Multi-row reorder scrambles the intervening frames | Single `swapFrames(from, from±3)` instead of sequential adjacent swaps | Up/Down = up to `numColumns` adjacent `swapFrames` steps, each with its own `onFramesReindexed({swapped})` (Spec-011-safe) |
| Undo after a reorder points at the wrong frame | `onFramesReindexed` not called per swap, or called with a non-adjacent pair | One `{swapped={i,i±1}}` call per adjacent step; never a multi-slot payload |
| Frame Room feels laggy on entry | 12 thumbnails rebuilt every `draw()` | Build `thumbCache` once in `entered()`; swap the two touched entries alongside `swapFrames`; `table.remove` on delete (R11 / R-33) |
| Tile picker still draws over the artwork | `drawTilePickerOverlay` still uses `py=(240-panelH)//2` | Make `py` `vAnchor`-relative; the picker renders inside the consolidated bar (FR-028 / ADR-049) |
| Label and status text overlap bottom-left | Two `bauchbinde:drawBottom` calls at fixed sides | Compose one content block; `statusMessage` is a second line in the same band |
| "delete frame" / "duplicate frame" menu items missing in the Frame Room | `entered()` still calls only `removeAllMenuItems()` without re-adding | Register both after `removeAllMenuItems()`, like `SelectionRoom:buildSystemMenu` (Ninth Round) |
| A-press in the Frame Room deletes instead of toggling the mark | `pressA()` still has the old "second A deletes" / `movedSinceMark` branch | `pressA()` is a plain `marked = (marked == cursor) and nil or cursor` toggle; delete lives on the menu callback |
| "delete frame" removes without asking | Menu callback deletes directly instead of setting `confirmingDelete` | Set `confirmingDelete=true`; do the removal in the dialog's A handler (mirror `SelectionRoom.confirmDelete`) |

---

**Status**: ✅ Quickstart updated for the Fourth-Round Tile View control redesign (B + D-Pad navigation, Crank tile picker, eyedropper toast, Scenario 7). Fifth Round (Pixel View: B stops painting) folded into Scenario 2. Scenario 3 rewritten for the per-tile pixel shift (ADR-043). **Eighth Round (2026-09-06)**: Scenario 4 for the persistent Frame Management Room, new Scenario 8 (consolidated overlay bar / SC-008), plus eight Troubleshooting rows. **Ninth Round (2026-09-06, `/speckit-clarify`)**: Scenario 4 re-cut — controls mirror the project-selection room, A is a mark/unmark toggle, delete + duplicate are system-menu actions with an A/B confirm dialog. **Tenth Round (2026-09-07)**: Scenario 7 gains steps 0a/0b — the tile picker opens only after a full crank revolution (jiggle/partial turn does nothing); two Troubleshooting rows added.
