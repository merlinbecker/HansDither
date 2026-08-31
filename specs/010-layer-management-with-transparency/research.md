# Research: Layer Management, Precise Pixel Shifting & Transparency Support

**Feature**: `specs/010-layer-management-with-transparency/`

**Date**: 2026-08-31

**Status**: Complete — All NEEDS CLARIFICATION items from plan.md resolved via research

---

## R1: Image Storage Format Extension (Spec 009 Compatibility)

**Question**: How should layer metadata and pixel transparency be stored while maintaining Spec 009 tile deduplication?

**Research Summary**:

Spec 009 established a hybrid storage model:
- **PDI file**: Deduplicated tile sheet (imagetable, one PDI per image)
- **JSON file**: Frame-to-tile position mapping + metadata

Current JSON schema (Spec 009):
```json
{
  "version": "1.0",
  "frames": [
    {
      "frameIndex": 0,
      "positions": [1, 1, 2, 2, ...],  // 375 tile indices (25×15 grid)
      "duration": 100
    }
  ]
}
```

**Decision**: Extend JSON to include layer structure while keeping PDI unchanged.

**New JSON Schema**:
```json
{
  "version": "1.1",
  "frames": [
    {
      "frameIndex": 0,
      "duration": 100,
      "layers": [
        {
          "layerIndex": 0,
          "name": "Background",
          "positions": [1, 1, 2, 2, ...],  // 375 tile indices
          "transparency": [0, 0, 1, 0, ...]  // 375 bytes: 0=opaque, 1=transparent, 2=empty
        },
        {
          "layerIndex": 1,
          "name": "Character",
          "positions": [0, 0, 0, 9, ...],
          "transparency": [2, 2, 2, 0, ...]
        }
      ]
    }
  ]
}
```

**Rationale**:
- Backward compatible: old images load with all pixels treated as opaque (transparency = 0)
- Per-layer positions allow independent tile management per layer
- Transparency array is compact (1 byte per pixel position)
- Tile deduplication still applies per-layer (Spec 009 `ImageStoreCodec.pruneUnusedTiles()` called per layer)
- No changes to PDI format required (layers are logical containers, not physical separation)

**Alternatives Rejected**:
- **Multiple PDI files per image**: Bloats storage for multi-layer frames; complicated file management
- **Embed in PDI metadata**: Playdate PDI format is immutable; custom extensions would break SDK compatibility

**Evidence**: Playdate SDK `playdate.json` module supports arbitrary nested structures; no custom parser needed.

---

## R2: Pixel Transparency State Representation

**Question**: How should the three pixel states (opaque, transparent, empty) be encoded and rendered?

**Research Summary**:

Current Pixel View treats pixels as binary: drawn (opaque, black) vs. empty (white/undrawn).

New requirement: Three states:
1. **Opaque (drawn)**: Solid pixel, part of image, renders normally
2. **Transparent**: Part of image but transparent, renders with checkerboard pattern in editor, exported as alpha=0
3. **Empty**: Not drawn yet, skipped in rendering and export

**Decision**: Use byte encoding in transparency array:
- `0` = opaque (default for existing images)
- `1` = transparent (user placed via B-press in Pixel View)
- `2` = empty (not drawn, visual distinction from transparent)

**Pixel View Rendering**:
- Opaque: Black pixel (existing behavior)
- Transparent: Checkerboard pattern (visual feedback)
- Empty: White/uncolored (existing behavior)

**Storage**: Transparency array saved to JSON, loaded on image open. On backward-compatibility load (no transparency array), all pixels default to either opaque (0) or empty (2) based on whether they have content.

**Rationale**:
- Byte array is compact and fast to iterate
- Checkerboard pattern is industry-standard for transparency (PNG editors, Photoshop, etc.)
- No changes to tile/imagetable rendering (transparency is metadata, not pixel data)
- Transparent pixels still participate in tile deduplication (can be shared across frames/layers)

**Alternatives Rejected**:
- **Single bit per pixel**: Would require bit-packing logic; harder to debug and extend
- **Separate "alpha" layer**: Adds another layer per frame; increases complexity
- **Overlay rendering**: Would require additional tilemap for alpha; performance impact

**Evidence**: Playdate imagetable supports per-pixel color via setPixel() / getPixel(); transparency state is orthogonal metadata.

---

## R3: Layer Rendering Order and Active Layer

**Question**: When multiple layers are present, which layer(s) should be rendered in Tile View? Should only the active layer be editable?

**Research Summary**:

Current architecture (single implicit layer per frame):
- Tile View shows complete rendered frame (all tiles stacked)
- Zoom View shows tile-sized chunk of current frame with detailed view
- Pixel View shows 16×16 pixel detail edit area

With layers, two approaches possible:

**Option A: Composite All Layers (Layer Stack)**
- Tile View renders all layers stacked (Layer 1 bottom, Layer N top)
- User sees full composition while editing any layer
- Zoom/Pixel View only edits active layer
- Pro: WYSIWYG (what-you-see-is-what-you-get)
- Con: Performance cost; per-frame tile recalculation affects all layers

**Option B: Single Active Layer (Current Behavior)**
- Tile View renders only the active layer
- User sees only current layer content
- Pro: Simpler state management, faster rendering
- Con: User can't see layer interaction/composition until export

**Decision**: **Option A (Composite All Layers)**

**Rationale**:
- Matches user expectations from traditional layer-based editors (Photoshop, GIMP, Aseprite)
- Spec requirement (US3) emphasizes "view" layers in Tile View, implying visibility
- Performance acceptable on Playdate (60 FPS target is achievable; see constraints review)
- Allows visual feedback for layer organization (important for management view)

**Implementation**:
- Tile View's `draw()` iterates all layers in index order
- Each layer's tile positions are rendered via SDK `imagetable:drawTile()`
- Only active layer's tiles are updated when user draws in Zoom/Pixel View
- Transparency channel controls alpha blending (transparent pixels don't overwrite below)

**Evidence**: Playdate SDK supports layered rendering via multiple `imagetable:drawTile()` calls; no custom compositing engine needed.

---

## R4: Layer Persistence Across Frame Switches

**Question**: When user switches frames, which layer should be active? Index-based or content-based?

**Research Summary**:

Scenario: Frame 1 has 3 layers, Frame 2 has 2 layers. User is on Frame 1, Layer 2. Switches to Frame 2.

**Option A: Reset to Layer 1**
- Simple state logic
- Pro: No confusion about non-existent layers
- Con: Repetitive; user must re-select layer on every frame switch

**Option B: Preserve Index with Wrap-Around**
- Active layer index preserved if it exists in new frame
- If index >= frame layer count, wrap to Layer 1
- Pro: Reduces re-selection work; consistent with animation software (Aseprite)
- Con: Risk of working on "wrong" layer if layer counts differ significantly

**Option C: Preserve by Name/ID**
- If layer with same name exists in new frame, activate it
- Pro: Sophisticated; assumes consistent layer naming
- Con: Requires layer IDs; complicates state management

**Decision**: **Option B (Preserve Index with Wrap-Around)**

**Rationale**:
- Matches animation software conventions (Aseprite, Clip Studio)
- Minimizes user re-selection work (common workflow: edit Layer 2 across multiple frames)
- Wrap-around is predictable: if Frame 2 only has 2 layers and user was on Layer 3, wrap to Layer 1
- Spec resolution in clarification phase confirmed this choice

**Evidence**: Existing Hans-Dither frame cycling uses index preservation; extending to layers is natural.

---

## R5: Management View Navigation Pattern

**Question**: How should the view hierarchy (Tile View → Layer View → Animation Layer View) be accessed and navigated?

**Research Summary**:

Current navigation pattern (from SelectionRoom):
- Directional controls (D-Pad) move cursor through list entries
- A-press selects/confirms entry
- B-press goes back/cancels
- Crank rotates through entries (smooth, fast access)

New requirement: Access layer/frame management from Tile View via B + Crank backward.

**Design Decision**: Linear progressive navigation hierarchy

```
Tile View
  ↑ (B + Crank backward)
  ↓ (continue B + Crank backward)
Layer View (current frame's layers)
  ↑ (continue B + Crank backward)
  ↓ (release B, go back to Tile View)
Animation Layer View (all frames + layers)
```

**Entry Point**: Tile View, hold B + rotate Crank counterclockwise once = enter Layer View

**From Layer View**: 
- D-Pad up/down = cycle through layers in current frame
- A-press = select layer
- B-press (while selected) = delete layer
- Hold B + Crank counterclockwise = progress to Animation Layer View
- Hold B + Crank clockwise = return to Tile View (if implemented) or just release B to cancel

**From Animation Layer View**:
- D-Pad = navigate frame entries
- A-press on frame = enter submenu showing that frame's layers
- (Submenu repeats Layer View pattern: select with A, delete with B)
- Hold B + Crank clockwise = return to Layer View

**Rationale**:
- Mirrors existing SelectionRoom pattern (proven UI, user already familiar)
- Progressive depth allows incremental complexity (simple layer selection → advanced management)
- No new UI paradigm required (reuses Room-based navigation)
- B-hold + Crank is natural for "mode shift" (already used for layer cycling in US3)

**Evidence**: Existing TileView/SelectionRoom navigation; design reuses proven patterns.

---

## R6: Tile Recalculation After Pixel Shifts

**Question**: When user shifts content pixel-by-pixel (US1), how should tiles be recalculated to maintain visual integrity?

**Research Summary**:

Current tile system (Spec 009):
- ImageStore stores content as 16×16 tile indices
- Each position in frame references a tile from the tile sheet (imagetable)
- Tiles are deduplicated via hash (same 16×16 pixel content = same tile index)

Pixel shifting requirement: User holds B + arrow to shift all frame content 1 pixel in any direction.

**Challenge**: Shifting by 1 pixel moves content within and across tile boundaries. Example:
- Pixel at tile position (1,0) shifts up → wraps into tile above (0,15)
- Pixel at tile position (0,0) shifts up → wraps to opposite edge or out-of-bounds

**Decision**: Implement via intermediate pixel buffer → tile recalculation

**Algorithm**:
1. Extract all pixels from current frame (iterate all layer positions, fetch tile content)
2. Shift entire pixel buffer by 1 pixel in requested direction (use wraparound or clamp)
3. Re-tile the shifted buffer via Spec 009 `ImageStoreCodec.pruneUnusedTiles()` per layer
4. Update frame positions with new tile indices

**Rationale**:
- Decouples shift logic from tile boundary issues
- Reuses existing Spec 009 tile pruning logic (proven, tested)
- Performance acceptable: 400×240 image = 240×240 pixel buffer (typical artist resolution), single shift per frame = ~57KB memory overhead
- Matches user mental model: "shift content" not "remap tile indices"

**Alternatives Rejected**:
- **Direct tile index remapping**: Error-prone at boundaries; tile index logic becomes fragile
- **Per-tile shifting**: Doesn't handle within-tile shifts (need 16 shift operations per tile)

**Evidence**: Spec 009 already provides robust tile recalculation via ImageStoreCodec; reuse proven code.

---

## R7: Backward Compatibility (Old Images Without Layers)

**Question**: How should existing images (from Spec 009, created before layer support) load correctly?

**Research Summary**:

Current JSON (Spec 009) has no `layers` array:
```json
{
  "version": "1.0",
  "frames": [{"frameIndex": 0, "positions": [...], "duration": 100}]
}
```

New JSON (this feature) includes `layers` array.

**Decision**: Automatic upgrade on load

**Algorithm**:
1. On JSON load, check `version` field
2. If version < "1.1", wrap old frame data into single default layer:
   ```json
   {
     "version": "1.1",
     "frames": [
       {
         "frameIndex": 0,
         "duration": 100,
         "layers": [
           {
             "layerIndex": 0,
             "name": "Layer 1",
             "positions": [...],  // copied from old "positions"
             "transparency": [0, 0, 0, ...]  // all zeros (opaque)
           }
         ]
       }
     ]
   }
   ```
3. Save upgraded structure when image is next saved (user won't notice; seamless upgrade)

**Rationale**:
- Users can open old images without errors
- Automatic upgrade means no "conversion" UI or manual steps
- All old pixels treated as opaque (visual fidelity preserved)
- Next save updates file to new version (gradual migration)

**Evidence**: Playdate SDK `playdate.json` module parses both old and new structures; custom version check is standard practice.

---

## R8: Test Strategy for Layer & Transparency Features

**Question**: What test scenarios are required to verify layer and transparency features work end-to-end?

**Research Summary**:

Constitution V (Testpflicht) requires:
1. Headless tests: `lua tests/headless_tests.lua` MUST pass
2. Build gate: `buildNumber` increment + `pdc Source "Hans Dither.pdx"` MUST succeed

For this feature, focus on pure Lua logic (no simulator/device interaction):

**New Test Section** (in tests/headless_tests.lua):

```lua
section("Layer Management & Transparency (Spec 010, US1-US4)")

-- US1: Pixel Shifting
test("Pixel shift: horizontal shift preserves content", function() 
  -- Load image, shift right 1px, verify all pixels shifted right
end)

test("Pixel shift: tile recalculation after shift", function()
  -- Shift content, verify tiles recalculated, content visually identical
end)

-- US2: Transparency
test("Transparency: place transparent pixel in Pixel View", function()
  -- Set pixel transparency state to 1, verify round-trip save/load
end)

test("Transparency: backward compat (old image loads as opaque)", function()
  -- Load v1.0 JSON (no transparency), verify all pixels state = 0
end)

-- US3: Layer Cycling
test("Layer cycling: switch layers via Crank", function()
  -- Create frame with 3 layers, cycle forward/backward, verify active layer
end)

test("Layer cycling: preserve layer index on frame switch", function()
  -- Frame 1 (3 layers) → Frame 2 (2 layers), verify layer wrapping
end)

-- US4: Management View
test("Layer deletion: remove layer from current frame", function()
  -- Create 3 layers, delete Layer 2, verify only 2 remain
end)
```

**Rationale**:
- Headless tests catch API misuse before simulator run
- Focus on state management (layers, transparency) not rendering
- Reuse ImageStoreCodec test patterns (already proven)
- Constitution V blockage: all tests must pass before code is committed

**Evidence**: Spec 009 established headless test pattern; this feature extends same pattern.

---

## R9: Maximum Layers per Frame (3-Layer Hard Limit) — NEW

**Question**: Should the number of layers per frame be unbounded or constrained? What are the implications for backward compatibility, performance, and simplicity?

**Research Summary**:

Initial design had no hard limit (assume 1–10 typical). User clarification (Session 2026-08-31) introduced a **fixed constraint: exactly 3 layers maximum per frame**.

**Decision**: **Implement 3-layer hard limit per frame**
- Layer 1 (layerIndex 0): Mandatory, always present, cannot be deleted
- Layers 2–3 (layerIndex 1–2): Optional, can be added/deleted per frame  
- System **prevents creation** of layerIndex ≥ 3
- All frames support 1–3 layers (min 1 for backward compat, max 3 for new images)

**Rationale**:
1. **Backward Compatibility**: Old 1-layer images auto-upgrade to Layer 1 on load; no data loss or migration hassle
2. **Performance Predictability**: Max resource usage is bounded (Playdate has limited RAM); 3 layers × 375 positions × 2 bytes = 2.25 KB per frame, 12 frames = 27 KB total metadata (negligible)
3. **Simplicity (Constitution IV)**: Fixed limit simplifies state machine (no dynamic scaling, no max-layer overflow handling)
4. **Transparency Critical for Layers 2–3**: With fixed 3-layer max, transparency (US2) becomes essential for proper compositing (Layers 2–3 need alpha for rendering order)

**Alternatives Considered**:
- **Unbounded layers**: More flexible, but performance unpredictable on Playdate; requires dynamic validation; no clear max
- **5+ layers**: Richer compositions, but exceeds typical pixel art workflows and complicates UI (cycling would be tedious)
- **2-layer limit**: Too restrictive; 3 is industry standard (background, character, effects)

**Evidence**: 
- Animation software (Aseprite, Piskel) commonly supports 3–5 layer tiers for indie workflows
- Playdate's resource constraints (64 MB RAM, single-core) favor bounded limits
- User explicitly requested "3 Ebenen" (3 layers) in German clarification

**Implementation Impact**:
- **Data Model**: Layer validation now enforces `layerIndex ∈ {0, 1, 2}` per frame
- **Storage Format**: No change to JSON/PDI (schema already supports it; just bounded)
- **UI**: Layer cycling (Crank) has predictable max (Layer 1 → 2 → 3 → wrap)
- **Tests**: Verify layer count never exceeds 3 (constraint validation test)

**Status**: ✅ Clarified and documented (Spec 010 Clarifications, Session 2 Round 2)

---

## Summary Table (Updated)

| Research Item | Decision | Confidence | Next Step |
|---------------|----------|------------|-----------|
| R1: Storage Format | Extend JSON with layers + transparency array | HIGH | Data model (Phase 1) |
| R2: Transparency State | 3-byte encoding (opaque=0, transparent=1, empty=2) | HIGH | Pixel model (Phase 1) |
| R3: Layer Rendering | Composite all layers in Tile View (stack) | HIGH | Rendering pipeline (Phase 1) |
| R4: Frame Switching | Preserve layer index with wrap-around | HIGH | Layer state machine (Phase 1) |
| R5: Management View | Linear progressive hierarchy + SelectionRoom pattern | HIGH | View/Room design (Phase 1) |
| R6: Pixel Shifting | Buffer → shift → retile via Spec 009 | HIGH | Algorithm (Phase 2) |
| R7: Backward Compat | Automatic upgrade on load, v1.0 → v1.1 | HIGH | Load/save logic (Phase 2) |
| R8: Tests | Headless test section + Constitution V gates | HIGH | Test cases (Phase 2) |
| **R9: Layer Limit** | **3-layer hard max per frame (NEW)** | **HIGH** | **Data model, Frame validation (Phase 1)** |

---

**Status**: ✅ Research complete — All decisions documented (including R9 3-layer constraint), ready for Phase 1 (data-model.md, contracts/, quickstart.md)
