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

## Test Scenario 3: Pixel Shifting (US1)

**Goal**: Verify that pixel-by-pixel shifting works with automatic tile recalculation.

**Setup**:
1. Create new Hans-Dither project
2. In Zoom View, draw a simple shape (e.g., 3×3 block of opaque pixels in top-left of zoom area)
3. Record pixel positions visually
4. Save image

**Test Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | In Zoom View, enter Layer 1 with the 3×3 shape | Shape visible in top-left quadrant of zoom view |
| 2 | Hold B-button and press Up arrow once | Shape shifts up by exactly 1 pixel; tiles recalculated; shape remains intact |
| 3 | While B still held, press Right arrow once | Shape shifts right by 1 pixel; tiles recalculated |
| 4 | Release B, observe shape position | Shape is now 1 pixel up and 1 pixel right from original |
| 5 | Save image | Save completes without errors |
| 6 | Reload image in Zoom View | Shape remains in shifted position (up 1, right 1) |
| 7 | Hold B and press Left arrow twice | Shape shifts left 2 pixels (now net 1 up, 1 left from original) |
| 8 | Hold B and press Down once | Shape shifts down 1 pixel (now 1 left from original) |
| 9 | Save and reload | Position preserved exactly |

**Acceptance Criteria**:
- ✅ Pixel shifts work in all 4 directions (Up/Down/Left/Right)
- ✅ Each key press shifts exactly 1 pixel
- ✅ Tiles recalculate after each shift (no visual corruption); *(Perf review, 2026-09-01: this now happens once per shift **gesture** rather than per key press — see ADR-043 — the preview still updates on every key press)*
- ✅ Repeated key presses while holding B feel responsive, not laggy (ADR-043 — device-level FPS confirmation still open, T053/T054)
- ✅ Shifted positions persist through save/reload
- ✅ Shifts are independent per frame (Frame 2 shifts don't affect Frame 1)

---

## Test Scenario 4: Frame Management View (US4)

**Goal**: Verify that the Frame Management View lets the user reorder and delete frames.

**Setup**:
1. Create a new image with 4 frames; draw something distinct in each so they are tellable apart
2. Save the image

**Test Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | In Tile View, hold B and rotate Crank counterclockwise | Frame Management View opens, listing Frame 1–4 in order |
| 2 | D-Pad down to the Frame 3 entry, press A | Frame 3 is marked (visual indicator) |
| 3 | Press Left | The marked frame moves one slot earlier — the list now reads 1, 3, 2, 4 |
| 4 | Press Left again | List reads 3, 1, 2, 4 |
| 5 | Press Left again | No-op — the marked frame is already first |
| 6 | Move the cursor (D-Pad) to the last entry, press A to mark it, press A again | The mark is confirmed on the first A, the second A deletes it; the list shrinks to 3 |
| 7 | Delete two more frames (A to mark, A again to delete) | The 3rd deletion (down to 1 frame) is **rejected** — at least one frame remains |
| 8 | Release B | Back in Tile View; the animation now plays in the reordered/shortened sequence; `currentFrame` is clamped into range |
| 9 | Save and reload | The new frame order and count persist |

**Acceptance Criteria**:
- ✅ Frame Management View accessible via one B + Crank-backward gesture in Tile View
- ✅ A marks a frame; a second A on the marked frame deletes it (two-step); Left/Right move it (clamped)
- ✅ Deletion rejected when only 1 frame remains
- ✅ Releasing B returns to Tile View with `currentFrame` clamped
- ✅ Reorder / delete persist through save/reload
- ✅ There is no Layer View — layers are fixed at 3 and not managed here

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

## Test Scenario 7: Tile Picker & Eyedropper Toast (US5, Fourth Round)

**Goal**: Verify the Crank opens a tile picker that cycles the referenced tiles, and that the eyedropper shows a "Tile N picked" toast.

**Setup**:
1. Open any image that uses several distinct tiles (draw a few different 16×16 tiles if needed)

**Test Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | In Tile View, with B **not** held, turn the Crank slowly | A filmstrip overlay appears centred on screen; the highlighted tile changes ~1 per 30° of rotation; "Tile N" is shown below it |
| 2 | Keep turning past the last tile | Selection wraps back to tile 1 (white = "no selection") |
| 3 | Turn the Crank the other way | Selection steps backward, wrapping at tile 1 → last tile |
| 4 | Stop turning, wait ~2 s | The overlay auto-hides; the selected tile is now the active drawing tile |
| 5 | Press A over an empty cell | The cell is painted with the picked tile |
| 6 | Move the cursor onto a non-white tile, give a short B-tap (no Crank, no D-Pad during the hold) | Bauchbinde briefly shows "Tile N picked"; after ~1.5 s it reverts to "Frame x/y ..." |
| 7 | Hold B and press Up/Down/Left/Right | Layer / frame switches (Scenario 1) — the B-tap eyedropper does **not** also fire |

**Acceptance Criteria**:
- ✅ Crank (no B) opens the tile picker and cycles the referenced tiles with wraparound
- ✅ The picker never shows orphaned session tiles (only tiles referenced in the layer positions)
- ✅ A tile that exists only on a layer covered by a higher layer is still reachable in the picker (and does not disappear when the higher layer covers its cell)
- ✅ Overlay auto-hides ~1.5 s after the last rotation; the selection persists as the active tile
- ✅ Eyedropper shows "Tile N picked" for ~1.5 s
- ✅ A B-release that followed a B + D-Pad navigation does not fire the eyedropper

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

- [ ] **US1 (Pixel Shifting)**: Test Scenario 3 passes — shifts work, tiles recalculate, persist
- [ ] **US2 (Transparency)**: Test Scenario 2 passes — an A-press on ink erases to the layer's non-ink state (transparent on Layers 2–3); B does not paint; transparent pixels stored/rendered/persisted
- [ ] **US3 (Layer/Frame Switching)**: Test Scenario 1 passes — B + Up/Down = layer, B + Left/Right = frame, Crank switches neither
- [ ] **US4 (Frame Management View)**: Test Scenario 4 passes — reorder + delete frames (min. 1), persists
- [ ] **US5 (Tile Picker + Toast)**: Test Scenario 7 passes — Crank cycles referenced tiles with wrap; eyedropper shows "Tile N picked"
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
| Crank does nothing / no tile-picker overlay | no-B branch of `handleCrank` not accumulating into `crankAccumDegrees`, or `pickerVisible` never set | Check `handleCrank` else-branch + `drawTilePickerOverlay` gate in `draw()` |
| Tile picker cycles through blank/garbage tiles, or a drawn tile is unreachable | iterating `imagetable:getLength()`, or scanning the flat composite cache (drops covered-layer tiles) | `referencedTileIndices()` must scan `frameLayers[*].layers[*].positions` (skip `0`), keeping index 1 |
| B-tap after B + D-Pad also picks a tile | `bNavConsumed` not latched in `bDpadNav`, or derived from live button state | Set it inside `bDpadNav`; clear only in `BButtonDown`/`BButtonUp` |
| "Tile N picked" never disappears | no timeout-transition redraw for `pickMessage` | Mirror the `bauchbindeVisible` pattern in `update()` |
| Transparent pixels render as white | Tile built without `kColorClear`, or `hashTile` not 3-class | Check `PixelRoom.buildTileImage` + `ImageStoreCodec.hashTile` |
| Upper-layer eraser leaves opaque white | `writeActiveLayerPosition` not mapping white→absent on Layers 2–3 | Check `EditorRoom.writeActiveLayerPosition` |
| Multi-layer edit lost on save | `imageData.frames` mutated directly instead of `frameLayers` | All edits must go through the active layer + `recompositeCell` |
| Pixel shift causes visual corruption | Tile recalculation incomplete | Debug `LayerModel.shiftLayerContent` + layered prune |
| Holding the shift arrow key feels laggy / drops frames | Full 375-tile rebuild + rehash was paid on every key press (~192,000 `image:sample()` calls measured for one step) | Should be resolved by ADR-043 (materialization deferred to `EditorRoom:flushLayerShift()`, once per gesture) — if still slow on device, profile the single flush call itself (T054); it stays O(375 tiles), just paid once instead of N times |
| Canonical tiles look stale right after a shift (e.g. pause-menu preview, save) | An open shift session (`EditorRoom.pendingShift`) was never flushed before the read | Every canonical read path must call `EditorRoom:flushLayerShift()` first (ADR-043 lists the call sites) — a new code path reading `imageData.frameLayers`/`frames`/`imagetable` needs one too |
| Old images don't load | Structure-based v1.0 detection failed | Check `newLoadOperation`'s `frames[1].layers` test + pad-to-3 |
| buildNumber not incremented | Manual step forgotten | Increment once per `pdc` run |

---

**Status**: ✅ Quickstart updated for the Fourth-Round Tile View control redesign (B + D-Pad navigation, Crank tile picker, eyedropper toast). Scenario 7 added. Fifth Round (Pixel View: B stops painting) and the pixel-shift perf review (ADR-043, deferred materialization) folded into Scenario 2 and Scenario 3 respectively, plus two new Troubleshooting rows.
