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

## Test Scenario 1: Layer Cycling with Crank (US3)

**Goal**: Verify that the 3 fixed layers can be cycled forward/backward via Crank + Up/Down without interfering with frame cycling.

**Setup**:
1. Create a new Hans-Dither project with 3 frames (every frame already has 3 layers — nothing to "create")
2. In Frame 1:
   - Layer 1 (bottom): draw a background pattern (its non-ink pixels are white)
   - Layer 2: cycle to it (hold Up + Crank), draw a character sprite (its non-ink pixels are transparent)
   - Layer 3: cycle to it, draw an effect overlay
3. Save the image

**Test Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Enter Tile View, verify Frame 1 is displayed with all 3 layers composited | All 3 layers visible: background at bottom, character in middle, effects transparent on top |
| 2 | Verify layer indicator shows "Layer 1 (Active)" | On-screen indicator displays active layer |
| 3 | Hold Up arrow key and rotate Crank clockwise once | Layer indicator changes to "Layer 2 (Active)" |
| 4 | While still holding Up, rotate Crank once more | Layer indicator changes to "Layer 3 (Active)" |
| 5 | While still holding Up, rotate Crank once more | Layer indicator changes to "Layer 1 (Active)" (wraparound) |
| 6 | Release Up arrow, rotate Crank clockwise once | Frame indicator changes to "Frame 2" (layer cycling stops, frame cycling resumes) |
| 7 | Hold Down arrow, rotate Crank twice counterclockwise | On Frame 2 (also 3 layers): active layer goes Layer 1 → Layer 3 → Layer 2 |
| 8 | Release Down, rotate Crank back to Frame 1 | Frame 1's active layer is whatever it was last (Layer 3 from step 5); Frame 2 kept its own active layer (Layer 2) — the index is per-frame session state |

**Acceptance Criteria**:
- ✅ Layer cycling works forward (Up + Crank) and backward (Down + Crank)
- ✅ Layer index wraps around (Layer 3 → Layer 1)
- ✅ Layer cycling does not interfere with frame cycling (Crank alone)
- ✅ Every frame always has the same 3 layers; the active index is preserved across frame switches

---

## Test Scenario 2: Pixel Transparency (US2)

**Goal**: Verify that transparent pixels can be placed, stored, and rendered distinctly.

**Setup**:
1. Open the Scenario 1 image, Frame 1
2. Cycle to **Layer 2** (hold Up + Crank) — transparency only exists on Layers 2–3
3. Enter Zoom View, then Pixel View on a Layer 2 tile

**Test Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Cursor at pixel (5, 5) in Pixel View | Cursor visible in 16×16 grid |
| 2 | Press A | Black ink pixel at (5, 5) |
| 3 | Move to (6, 5), press B | Pixel (6, 5) shows the checkerboard pattern (transparent) |
| 4 | Move to (5, 5), press A again | Pixel (5, 5) toggles back to transparent (Layer 2's non-ink state — the eraser) |
| 5 | Verify visual distinction: ink (black) vs. transparent (checkerboard) | The two states are clearly different |
| 6 | Zoom out to Tile View | Where Layer 2 is transparent, Layer 1 shows through |
| 7 | Save, close, reload | Transparent pixels preserved; the Layer 2 tile round-trips distinctly from a white tile |

Then repeat on **Layer 1**: B-press produces **white** (identical to the A-eraser) — Layer 1 has no transparent state.

**Acceptance Criteria**:
- ✅ A places ink; A on an ink pixel erases to the layer's non-ink state
- ✅ B places the layer's non-ink state — transparent on Layers 2–3, white on Layer 1
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
- ✅ Tiles recalculate after each shift (no visual corruption)
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
| 2 | Hold Up + Crank to cycle layers | Cycles Layer 1 → 2 → 3 → 1; Layer 1 holds the old content, Layers 2–3 are empty |
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
| 3 | Cycle to Layer 1 (Up + Crank) | Indicator "L1/3 Layer 1"; still composited with the others |
| 4 | Draw in Zoom/Pixel View | Only Layer 1 changes; Layers 2 & 3 untouched |
| 5 | Cycle to Layer 2 | Indicator "L2/3 Layer 2" |
| 6 | Draw in Zoom/Pixel View | Only Layer 2 changes; Layers 1 & 3 untouched |

**Acceptance Criteria**:
- ✅ Layers render in correct stacking order (0 bottom, N-1 top)
- ✅ Active layer is editable; inactive layers read-only
- ✅ Transparent pixels are visually transparent (see through to layers below)
- ✅ Drawing on one layer doesn't affect other layers

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
- [ ] **US2 (Transparency)**: Test Scenario 2 passes — B places the layer's non-ink state; transparent pixels stored/rendered/persisted on Layers 2–3
- [ ] **US3 (Layer Cycling)**: Test Scenario 1 passes — Crank cycles the 3 fixed layers, doesn't interfere with frames
- [ ] **US4 (Frame Management View)**: Test Scenario 4 passes — reorder + delete frames (min. 1), persists
- [ ] **Backward Compat**: Test Scenario 5 passes — v1.0 images load as Layer 1 + two empty upper layers
- [ ] **Compositing**: Test Scenario 6 passes — 3 layers render correctly, editing isolated to the active layer
- [ ] **Gate 1 (Tests)**: `lua tests/headless_tests.lua` passes with "ALLE TESTS BESTANDEN"
- [ ] **Gate 2 (Build)**: `pdc Source "Hans Dither.pdx"` succeeds, buildNumber incremented
- [ ] **Round-Trip**: Save/reload tested in all scenarios — data persists exactly

---

## Troubleshooting

| Issue | Diagnosis | Resolution |
|-------|-----------|-----------|
| Frame Management View doesn't open | B + Crank-backward not bound in `EditorRoom.handleCrank` | Check the `zoomTickAccu <= -ZOOM_TICK_THRESHOLD` branch |
| Transparent pixels render as white | Tile built without `kColorClear`, or `hashTile` not 3-class | Check `PixelRoom.buildTileImage` + `ImageStoreCodec.hashTile` |
| Upper-layer eraser leaves opaque white | `writeActiveLayerPosition` not mapping white→absent on Layers 2–3 | Check `EditorRoom.writeActiveLayerPosition` |
| Multi-layer edit lost on save | `imageData.frames` mutated directly instead of `frameLayers` | All edits must go through the active layer + `recompositeCell` |
| Pixel shift causes visual corruption | Tile recalculation incomplete | Debug `LayerModel.shiftLayerContent` + layered prune |
| Old images don't load | Structure-based v1.0 detection failed | Check `newLoadOperation`'s `frames[1].layers` test + pad-to-3 |
| buildNumber not incremented | Manual step forgotten | Increment once per `pdc` run |

---

**Status**: ✅ Quickstart updated for the Third-Round fixed-3-layer clarification.
