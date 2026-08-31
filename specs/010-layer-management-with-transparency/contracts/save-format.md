# Contract: JSON Storage Format (v1.1)

**Feature**: `specs/010-layer-management-with-transparency/`

**Defines**: Schema for persistent storage of frames, layers, and transparency

---

## JSON Schema

**File**: `{base}.json` (where `base` is client_image_id or UUID)

**Root**:
```json
{
  "version": "1.1",
  "frames": [...]
}
```

---

## Frame Object

**Array Element** (each frame):
```json
{
  "frameIndex": 0,
  "duration": 100,
  "layers": [...]
}
```

**Fields**:
- `frameIndex` (integer, 0–11): Zero-based position in animation
- `duration` (integer, > 0): Milliseconds to display
- `layers` (array): At least 1 layer per frame

**Validation**: 
- Frame count 1–12 (Constitution IV)
- frameIndex unique and consecutive (0 to frame_count - 1)

---

## Layer Object

**Array Element** (each layer in frame):
```json
{
  "layerIndex": 0,
  "name": "Background",
  "positions": [1, 1, 2, 2, 3, 3, ...],
  "transparency": [0, 0, 0, 0, 0, 0, ...],
  "visible": true
}
```

**Fields**:
- `layerIndex` (integer): 0-based position in frame (0 = bottom, N-1 = top)
  - Validation: Unique within frame, consecutive from 0
  
- `name` (string, max 32 chars): User-friendly name
  - Validation: Non-empty
  - Examples: "Background", "Character", "Effects"
  
- `positions` (array<integer>): Tile indices for 25×15 grid
  - Length: Exactly 375 entries
  - Values: 0 (empty) or 1..N (tile index in PDI)
  - Validation: Non-zero values must be <= max_tile_in_pdi
  
- `transparency` (array<integer>): Transparency per position
  - Length: Exactly 375 entries (must match `positions`)
  - Values: 
    - `0` = opaque
    - `1` = transparent
    - `2` = empty
  - Validation: Each value in [0, 1, 2]
  
- `visible` (boolean, optional, default: true): Display state in editor

**Validation**:
- layerIndex matches position in frame.layers array
- Unique layerIndex per frame
- All position/transparency values valid

---

## Backward Compatibility (v1.0 → v1.1)

**Old Format** (Spec 009):
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

**Auto-Upgrade on Load**:
```lua
if root.version == "1.0" then
  for frameIndex, oldFrame in ipairs(root.frames) do
    oldFrame.layers = {
      {
        layerIndex = 0,
        name = "Layer 1",
        positions = oldFrame.positions,
        transparency = array_fill(375, 0),  -- all opaque
        visible = true
      }
    }
    oldFrame.positions = nil
  end
  root.version = "1.1"
end
```

**Result**: Single default layer, all pixels opaque. Next save updates file to v1.1.

---

## Example: Three-Layer Frame

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
          "positions": [1, 1, 2, 2, 3, 3, 1, 1, ...],
          "transparency": [0, 0, 0, 0, 0, 0, 0, 0, ...],
          "visible": true
        },
        {
          "layerIndex": 1,
          "name": "Character",
          "positions": [0, 0, 5, 6, 0, 0, 0, 0, ...],
          "transparency": [2, 2, 0, 0, 2, 2, 2, 2, ...],
          "visible": true
        },
        {
          "layerIndex": 2,
          "name": "Effects",
          "positions": [0, 0, 0, 0, 9, 0, 0, 0, ...],
          "transparency": [2, 2, 2, 2, 1, 2, 2, 2, ...],
          "visible": true
        }
      ]
    }
  ]
}
```

---

## PDI Reference

**File**: `{base}.pdi` (unchanged from Spec 009)

**Relationship**:
- All layer position entries reference tiles in this PDI
- Tiles deduplicated across all frames/layers
- Tile count stored in PDI, validated against position values

---

## File Size

**Example** (12 frames, 3 layers/frame):
- Positions: 27 KB
- Transparency: 13.5 KB
- Metadata: ~5 KB
- **Total**: ~45 KB (~8 KB gzipped)

**On Playdate**: Well within available storage

---

## Validation on Load

- [ ] version is "1.0" or "1.1"
- [ ] frames array non-empty
- [ ] Each frameIndex unique and 0..(frame_count-1)
- [ ] Frame count 1–12
- [ ] Each frame has ≥1 layer
- [ ] Each layerIndex unique within frame (0..(layer_count-1))
- [ ] Each layer: positions exactly 375 entries, values [0..tile_count]
- [ ] Each layer: transparency exactly 375 entries, values [0, 1, 2]
- [ ] Layer names non-empty, max 32 chars
- [ ] Auto-upgrade if version "1.0"

---

## Test Validation

```lua
test("JSON v1.1 load: parse all layers", function()
  local image = Image:loadJSON("test.json")
  local frame = image:getFrame(0)
  assert(frame:getLayerCount() == 3)
  assert(#frame:getLayer(0):getPositions() == 375)
end)

test("JSON v1.0 backward compat", function()
  local image = Image:loadJSON("old.json")
  local frame = image:getFrame(0)
  assert(frame:getLayerCount() == 1)
  assert(frame:getLayer(0):getName() == "Layer 1")
end)

test("JSON round-trip preservation", function()
  local img1 = Image:loadJSON("orig.json")
  img1:saveJSON("copy.json")
  local img2 = Image:loadJSON("copy.json")
  -- verify identical
end)
```

---

**Status**: ✅ Storage format contract defined
