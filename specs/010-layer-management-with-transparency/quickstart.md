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

**Goal**: Verify that layers can be cycled forward/backward via Crank + Up/Down keys without interfering with frame cycling.

**Setup**:
1. Create a new Hans-Dither project with 3 frames
2. In Frame 1, create 3 layers:
   - Layer 1 (Background): Draw 5 tiles of a background pattern
   - Layer 2 (Character): Draw 2 tiles of a character sprite
   - Layer 3 (Effects): Draw 1 transparent tile with an effect overlay
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
| 7 | Hold Down arrow, rotate Crank twice counterclockwise | Layer cycles backward: Frame 2 Layer 1 → (no change, Frame 2 has only 1 layer) |
| 8 | Release Down, verify Frame 1 and Layer 3 have separate state | Switch back to Frame 1 via Crank (normal frame cycle). Verify Layer 2 is now active (index preserved from Step 4) |

**Acceptance Criteria**:
- ✅ Layer cycling works forward (Up + Crank) and backward (Down + Crank)
- ✅ Layer index wraps around (Layer 3 → Layer 1)
- ✅ Layer cycling does not interfere with frame cycling (Crank alone)
- ✅ Layer index preserved when switching frames (Frame 1 Layer 2 → Frame 2 Frame 1 → back to Frame 1 Layer 2)

---

## Test Scenario 2: Pixel Transparency (US2)

**Goal**: Verify that transparent pixels can be placed, stored, and rendered distinctly.

**Setup**:
1. Open Test Scenario 1 image (Frame 1 ready)
2. Enter Pixel View
3. Current layer should be "Layer 1 (Background)"

**Test Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Position cursor at pixel (5, 5) in Pixel View | Cursor visible in 16×16 grid |
| 2 | Press A-button | Black opaque pixel placed at (5, 5) |
| 3 | Move cursor to (6, 5), press B-button | Pixel at (6, 5) appears with checkerboard pattern (transparent) |
| 4 | Move cursor to (7, 5), press Y-button (delete) | Pixel at (7, 5) becomes empty (white/undrawn) |
| 5 | Verify visual distinction: opaque (black) vs. transparent (checkerboard) vs. empty (white) | All three states clearly different |
| 6 | Save image (trigger save flow) | Save completes, buildNumber incremented |
| 7 | Close and reload image | Transparency states preserved: (5,5) opaque, (6,5) transparent, (7,5) empty |
| 8 | Verify Pixel View shows same pattern as Step 5 | Transparency states persist through save/reload |

**Acceptance Criteria**:
- ✅ A-press places opaque pixels
- ✅ B-press places transparent pixels
- ✅ Transparent pixels render with checkerboard (visual feedback)
- ✅ Transparent pixels persist through save/reload
- ✅ Backward compatibility: old image (v1.0) loads with all pixels as opaque

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

## Test Scenario 4: Layer Management View (US4)

**Goal**: Verify that the dedicated Management View allows layer deletion and frame-level organization.

**Setup**:
1. Create new image with 2 frames
2. Frame 1: 4 layers (Background, Character, Effects, UI)
3. Frame 2: 2 layers (Background, Character)
4. Save image

**Test Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | In Tile View (Frame 1), hold B and rotate Crank counterclockwise | Layer View appears, showing 4 layer entries (Background, Character, Effects, UI) |
| 2 | Navigate down through layer entries using D-Pad | Cursor moves through all 4 layer entries |
| 3 | Select "Effects" layer (A-press) | Layer is highlighted |
| 4 | Press B to delete "Effects" layer | Layer View updates, now shows 3 entries (Background, Character, UI) |
| 5 | Verify Tile View reflects layer deletion | Return to Tile View (release B), only 3 layers visible when cycling (Up + Crank) |
| 6 | Re-enter Layer View (B + Crank backward), continue to Animation Layer View (B + Crank backward again) | Animation Layer View appears, showing 2 frame entries (Frame 1, Frame 2) |
| 7 | Select Frame 1 entry, press A | Submenu shows 3 layers (Background, Character, UI) |
| 8 | Delete "UI" layer from submenu | Layer removed from Frame 1 |
| 9 | Return to Tile View, verify Frame 1 now has only 2 layers (Background, Character) | Cycling through layers shows only 2 |
| 10 | Switch to Frame 2 (normal Crank), verify it still has 2 layers (Background, Character) — unaffected | Frame 2 independent |

**Acceptance Criteria**:
- ✅ Layer View accessible via B + Crank backward in Tile View
- ✅ Layers can be deleted via Layer View
- ✅ Animation Layer View accessible via B + Crank backward from Layer View
- ✅ Frame-level management allows per-frame layer deletion
- ✅ Deletions persist through save/reload

---

## Test Scenario 5: Backward Compatibility (v1.0 Images)

**Goal**: Verify that images created under Spec 009 load correctly without errors.

**Setup**:
1. Have a valid Spec 009 image file (v1.0 JSON + PDI) ready
2. Attempt to load in Hans-Dither

**Test Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Load Spec 009 image in Tile View | Image loads without error, displays as single layer |
| 2 | Enter Layer View (B + Crank backward) | Shows 1 layer (auto-created "Layer 1") |
| 3 | Enter Pixel View, check transparency states | All pixels appear opaque (no transparent pixels, no checkerboard) |
| 4 | Save image | File is saved in v1.1 format with transparency array (all zeros) |
| 5 | Reload image | Loads and renders identically to Step 1 |
| 6 | Verify JSON version updated | JSON file now has "version": "1.1" |

**Acceptance Criteria**:
- ✅ Spec 009 images load without conversion dialog or error
- ✅ Auto-upgrade to v1.1 (single opaque layer)
- ✅ All pixels treated as opaque after upgrade
- ✅ Save updates file version to v1.1
- ✅ User sees no disruption (seamless upgrade)

---

## Test Scenario 6: Multi-Layer Compositing (Visual)

**Goal**: Verify that multiple layers render correctly in Tile View with proper stacking order.

**Setup**:
1. Create 3-layer frame
2. Layer 1: Draw background pattern (opaque)
3. Layer 2: Draw character sprite (with some transparent pixels)
4. Layer 3: Draw effect overlay (transparent)

**Test Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View Tile View with all layers visible | All 3 layers composited, stacked correctly (Layer 1 bottom, Layer 3 top) |
| 2 | Verify transparent pixels allow seeing layers below | Where Layer 2/3 have transparent pixels, Layer 1 shows through |
| 3 | Cycle to Layer 1 as active (Up + Crank) | Layer 1 highlighted in indicator, still composited with others |
| 4 | Draw in Zoom/Pixel View on Layer 1 | Only Layer 1 content changes; Layers 2 & 3 unchanged |
| 5 | Cycle to Layer 2 as active | Indicator updates, Layer 2 highlighted |
| 6 | Draw in Zoom/Pixel View on Layer 2 | Only Layer 2 content changes; Layers 1 & 3 unchanged |

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
- [ ] **US2 (Transparency)**: Test Scenario 2 passes — transparent pixels placed/stored/rendered/persisted
- [ ] **US3 (Layer Cycling)**: Test Scenario 1 passes — Crank cycling works, doesn't interfere with frames
- [ ] **US4 (Management View)**: Test Scenario 4 passes — layer deletion, frame-level management
- [ ] **Backward Compat**: Test Scenario 5 passes — v1.0 images load and auto-upgrade
- [ ] **Compositing**: Test Scenario 6 passes — layers render correctly, editing isolated
- [ ] **Gate 1 (Tests)**: `lua tests/headless_tests.lua` passes with "ALLE TESTS BESTANDEN"
- [ ] **Gate 2 (Build)**: `pdc Source "Hans Dither.pdx"` succeeds, buildNumber incremented
- [ ] **Round-Trip**: Save/reload tested in all scenarios — data persists exactly

---

## Troubleshooting

| Issue | Diagnosis | Resolution |
|-------|-----------|-----------|
| Layer View doesn't appear | B + Crank might not be bound correctly | Check Tile View key binding implementation |
| Transparent pixels render as opaque | Transparency array not being read | Verify JSON load sets transparency state |
| Pixel shift causes visual corruption | Tile recalculation incomplete | Debug tile pruning logic (Spec 009) |
| Old images don't load | v1.0 → v1.1 auto-upgrade missing | Verify upgrade logic in Image:loadJSON() |
| buildNumber not incremented | Manual step forgotten | Increment before each test run |

---

**Status**: ✅ Quickstart scenarios complete — Ready for implementation tasks
