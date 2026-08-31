# Data Model: Layer Management, Precise Pixel Shifting & Transparency Support

**Feature**: `specs/010-layer-management-with-transparency/`

**Date**: 2026-08-31

**Status**: Complete — Based on research.md decisions

---

## Overview

This data model extends Spec 009's storage format to include per-frame layers and pixel transparency metadata. All entities are stored in JSON (frame-level metadata) + PDI (deduplicated tile sheet, unchanged).

---

## Entity: Layer

**What it represents**: A drawable canvas within a frame, containing pixel positions and transparency states.

**Attributes**:
- `layerIndex` (number): Zero-based layer position within frame (0 = bottom, N-1 = top)
- `name` (string): User-friendly layer name (e.g., "Background", "Character", "Effects")
- `positions` (array<number>): 375 integers representing tile indices at each frame position (25×15 grid)
  - Range: `0` = empty position, `1..N` = tile index in imagetable
  - Invariant: Must have exactly 375 entries (no exceptions)
  - Relationship: Each position references a tile from the shared PDI imagetable
- `transparency` (array<number>): 375 bytes representing per-position transparency state
  - `0` = opaque (drawn, opaque pixel)
  - `1` = transparent (drawn, transparent pixel)
  - `2` = empty (not drawn, reserved/unset)
  - Invariant: Must have exactly 375 entries matching `positions` array length
  - Relationship: Controls rendering alpha for corresponding position; metadata only (not part of tile data)
- `visible` (boolean, optional): Whether layer is rendered. Default: `true`. Used by management view.

**Relationships**:
- **Frame**: Layer belongs to exactly one Frame (parent-child)
- **ImageTable (PDI)**: Layer's positions reference tiles from shared imagetable (N-to-1 relationship)

**Validation Rules**:
- Layer name must be non-empty string, max 32 characters
- `layerIndex` must be unique within frame (0 ≤ index < frame.layer_count)
- `positions` and `transparency` arrays must be exactly 375 elements
- Transparency value must be in range [0, 1, 2]
- Position value must be in range [0, tile_count] where tile_count is max index in imagetable

**State Transitions**:
- **Created**: Layer initialized with empty positions (all 0) and empty transparency (all 2)
- **Edited**: User draws in Pixel View or shifts content in Zoom View → positions and transparency updated
- **Active**: When user holds Up/Down + Crank to cycle → this layer is highlighted in Tile View, editable in Zoom/Pixel
- **Deleted**: User confirms delete in Management View → layer removed from frame, layer indices below adjusted

---

## Entity: Pixel

**What it represents**: A single drawable unit in Pixel View (16×16 grid of pixels per tile).

**Attributes**:
- `x` (number): Horizontal position within 16×16 pixel grid (0–15)
- `y` (number): Vertical position within 16×16 pixel grid (0–15)
- `color` (number): Playdate color (0 = black, 1 = white, from SDK)
- `transparency` (number): State of this pixel
  - `0` = opaque (user drew with A-press)
  - `1` = transparent (user drew with B-press)
  - `2` = empty (not drawn)

**Relationships**:
- **Tile**: Collection of 256 pixels (16×16) forms one Tile
- **Layer**: Pixels belong to one layer (via parent tile)

**Validation Rules**:
- `x` and `y` must be in range [0, 15]
- `color` must be 0 or 1 (Playdate native colors)
- `transparency` must be in range [0, 1, 2]

**State Transitions**:
- **Empty** (transparency = 2): Initial state, not drawn
- **Opaque** (transparency = 0): User presses A in Pixel View → becomes opaque, color set to black
- **Transparent** (transparency = 1): User presses B in Pixel View → becomes transparent, color irrelevant
- **Erased**: User presses Y/delete in Pixel View → returns to Empty (transparency = 2)

---

## Entity: Frame

**What it represents**: A single animation frame, containing one or more layers.

**Attributes**:
- `frameIndex` (number): Zero-based frame position in animation (0 ≤ index < 12)
- `duration` (number): Display duration in milliseconds (default: 100 ms)
- `layers` (array<Layer>): All layers in this frame, ordered by layerIndex (0 = bottom, N-1 = top)

**Relationships**:
- **Image**: Frame belongs to exactly one Image (N-to-1 relationship)
- **Layer**: Frame contains 1..N layers (1-to-N relationship)
- **ActiveLayer**: Reference to the currently editable Layer (always exists, stored in EditorState)

**Validation Rules**:
- `frameIndex` must be unique within image (0 ≤ index < frame_count, max 12 per Constitution IV)
- `duration` must be positive integer (> 0)
- **`layers` array must have exactly 1–3 layers per frame** (HARD LIMIT, updated per Clarifications):
  - Layer at layerIndex 0 is MANDATORY (base layer, always exists)
  - Layers at layerIndex 1 and 2 are OPTIONAL
  - System MUST prevent creation of layerIndex ≥ 3
  - Total: min 1 layer (legacy images), max 3 layers (new images)

**State Transitions**:
- **Created**: Frame initialized with single default Layer (Layer 1)
- **Active**: When user is viewing/editing this frame (selected via Crank in Tile View)
- **Animated**: When frame cycle is running (cycling through frames via Crank without Up/Down held)

---

## Composition: Image

**Attributes**:
- `version` (string): "1.1" (tracks compatibility with Spec 009 → Spec 010 upgrade)
- `frames` (array<Frame>): All frames in image (1–12 frames, per Constitution IV)
- `tileCount` (number): Total tiles in imagetable (stored in PDI, referenced here for validation)

**Relationships**:
- **PDI File**: External imagetable file containing deduplicated tiles (referenced by all positions)
- **JSON File**: This metadata (frames, layers, transparency) stored here

**Validation Rules**:
- `version` must be "1.1" (or auto-upgraded from "1.0")
- `frames` must have 1–12 entries
- All frames must have unique, consecutive frameIndex values
- Total pixel memory: (frame_count × layer_count × 375 × 2 bytes) = manageable on Playdate (12 frames × 3 layers × 750 bytes = ~27 KB)

---

## Storage Format

### JSON Schema (Spec 009 + Layer Extension)

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
          "positions": [1, 1, 2, 2, 3, 3, ...],  // 375 entries
          "transparency": [0, 0, 0, 0, 0, 0, ...], // 375 entries
          "visible": true
        },
        {
          "layerIndex": 1,
          "name": "Character",
          "positions": [0, 0, 5, 6, 0, 0, ...],  // 375 entries
          "transparency": [2, 2, 0, 0, 2, 2, ...]  // 375 entries
        }
      ]
    },
    {
      "frameIndex": 1,
      "duration": 100,
      "layers": [
        {
          "layerIndex": 0,
          "name": "Background",
          "positions": [1, 1, 2, 2, ...],
          "transparency": [0, 0, 0, 0, ...]
        }
      ]
    }
  ]
}
```

### Backward Compatibility (v1.0 → v1.1 Upgrade)

Old format (Spec 009):
```json
{
  "version": "1.0",
  "frames": [
    {
      "frameIndex": 0,
      "positions": [1, 1, 2, 2, ...],
      "duration": 100
    }
  ]
}
```

**Automatic Upgrade on Load**:
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
          "positions": [1, 1, 2, 2, ...],  // copied from old "positions"
          "transparency": [0, 0, 0, 0, ...]  // all zeros (opaque)
        }
      ]
    }
  ]
}
```

**Rationale**: Users don't notice conversion; next save updates file version automatically.

---

## PDI Format (Unchanged from Spec 009)

**File**: `{base}.pdi` (where `base` is client_image_id or UUID per Spec 009)

**Contents**: Deduplicated tile imagetable (16×16 pixel tiles, indexed)

**Relationship to Layer Model**:
- All layers reference the same PDI imagetable
- Tile indices in `Layer.positions` point into this imagetable
- Tiles are deduplicated across all frames and layers (Spec 009 pruning applies per-layer)

**No changes** to PDI structure (layers are logical, not physical separation).

---

## State Machine: Active Layer During Editing

**Current Frame State**:
```
Frame {
  activeLayerIndex: 0,  // User is editing this layer
  layers: [
    Layer 1 (Background),
    Layer 2 (Character) <- activeLayerIndex = 1
  ]
}
```

**Transitions**:

1. **Crank + Up pressed**: `activeLayerIndex = (activeLayerIndex + 1) % layer_count`
   - Cycle forward: Layer 1 → Layer 2 → Layer 3 → Layer 1 (max 3 layers, wraparound guaranteed)

2. **Crank + Down pressed**: `activeLayerIndex = (activeLayerIndex - 1 + layer_count) % layer_count`
   - Cycle backward: Layer 1 → Layer 3 → Layer 2 → Layer 1 (max 3 layers, wraparound guaranteed)

3. **Frame switch** (Crank without Up/Down):
   - Preserve `activeLayerIndex` if it exists in new frame
   - If `activeLayerIndex >= newFrame.layer_count`, set to 0 (wrap-around per research.md R4, ensures max 3 is never exceeded)

4. **Layer deleted** (Management View):
   - Layer 1 cannot be deleted (error/prevent in UI)
   - If Layer 2 or 3 is deleted and is active, switch to activeLayerIndex - 1 (or Layer 1 if last remaining)
   - Adjust all remaining layers' `layerIndex` values to fill gap (0, 1, 2 remain consecutive)

---

## Key Invariants

**Must Always Hold**:

1. **Layer Completeness**: Every frame has at least 1 layer
2. **Position Array**: Every layer's `positions` array has exactly 375 entries
3. **Transparency Array**: Every layer's `transparency` array has exactly 375 entries, matching `positions` length
4. **Layer Index Uniqueness**: All layers in a frame have unique `layerIndex` values (0, 1, 2, ...)
5. **Tile Validity**: All non-zero positions in any layer reference valid tile indices in imagetable
6. **Frame Index Uniqueness**: All frames have unique `frameIndex` values (0, 1, 2, ..., up to 12)

**Verification** (Constitution III—arc42 & testing):
- Data model invariants tested in headless tests (R8)
- Load/save functions validate all invariants on round-trip
- arc42 Chapter 7 documents data structure integrity checks

---

## Example: Three-Layer Frame

**Visual**:
```
Layer 3 (Effects): Particles, overlays
  positions: [0, 0, 10, 0, 0, 0, ...]
  transparency: [2, 2, 0, 2, 2, 2, ...]
  
Layer 2 (Character): Main sprite
  positions: [0, 5, 6, 7, 0, 0, ...]
  transparency: [2, 0, 0, 0, 2, 2, ...]
  
Layer 1 (Background): Static tiles
  positions: [1, 1, 2, 2, 1, 1, ...]
  transparency: [0, 0, 0, 0, 0, 0, ...]
```

**Rendered** (Tile View, all layers composited):
- Position (0,0): Layer 1 tile 1 (opaque) — shown
- Position (0,1): Layers 1&2 → Layer 2 tile 5 (opaque) overwrites Layer 1 tile 1 — shown as Layer 2
- Position (0,2): Layers 1,2,3 → Layer 3 tile 10 (opaque) overwrites below — shown as Layer 3
- Position (0,3): Layers 1&3 → Layer 3 empty, Layer 1 tile 2 (opaque) — shown as Layer 1

**Edited** (Zoom/Pixel View, active layer only):
- If active layer = Layer 2 (Character), user only sees and edits positions where Layer 2 has content (indices 1–3 in above example)

---

## Migration Example: Spec 009 → Spec 010

**Input** (Spec 009 JSON):
```json
{
  "version": "1.0",
  "frames": [
    {
      "frameIndex": 0,
      "positions": [1, 1, 2, 2, 3, 3, ...],
      "duration": 100
    }
  ]
}
```

**Output** (after auto-upgrade on load):
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
          "positions": [1, 1, 2, 2, 3, 3, ...],
          "transparency": [0, 0, 0, 0, 0, 0, ...]
        }
      ]
    }
  ]
}
```

**Behavior**: User opens image → sees it unchanged (all opaque pixels) → can now add layers and transparency → next save updates file to v1.1

---

## Testing Validation

**Headless Tests** (Constitution V):

```lua
-- Data Model Invariants
test("Frame invariant: every frame has at least 1 layer", function()
  -- create frame, verify layer_count >= 1
end)

test("Layer invariant: positions and transparency arrays are 375 entries", function()
  -- create layer, verify #positions == 375 and #transparency == 375
end)

test("Transparency value range: [0, 1, 2]", function()
  -- iterate all transparency values, verify in valid range
end)

-- Round-Trip (Save → Load)
test("Save v1.1 and load: layer structure preserved", function()
  -- create 3-layer frame, save, load, verify all layers + transparency states intact
end)

-- Backward Compatibility
test("Load v1.0 JSON: auto-upgrade to v1.1 with opaque transparency", function()
  -- load old format, verify upgraded, all transparency = 0
end)
```

---

**Status**: ✅ Data model complete — Ready for contract definition and quickstart scenarios
