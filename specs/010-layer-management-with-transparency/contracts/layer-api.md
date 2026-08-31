# Contract: Layer API

**Feature**: `specs/010-layer-management-with-transparency/`

**Defines**: Public API surface for Layer entity and layer management operations

---

## Layer API

### Layer.new(layerIndex, name, positions, transparency)

**Signature**: `(number, string, array, array) → Layer`

**Input**:
- `layerIndex` (number): Zero-based position in frame
- `name` (string): User-facing layer name
- `positions` (array<number>): 375 tile indices
- `transparency` (array<number>): 375 transparency states (0/1/2)

**Output**: Layer object with getters/setters

**Preconditions**:
- `layerIndex >= 0`
- `name` is non-empty, max 32 characters
- `#positions == 375`, `#transparency == 375`
- All transparency values in [0, 1, 2]

**Postconditions**: Layer ready for use (not yet assigned to Frame)

---

### Layer:getPositions() → array<number>

**Output**: Copy of positions array (375 entries)

**Contract**: Read-only access to tile indices

---

### Layer:setPosition(index, tileIndex, transparency)

**Input**:
- `index` (number): 0–374
- `tileIndex` (number): Tile index (0 = empty, 1..N = tile)
- `transparency` (number): 0/1/2

**Effect**: Position updated, layer marked dirty

---

### Layer:getTransparencyAt(index) → number

**Output**: Transparency state at position (0/1/2)

---

### Layer:shift(direction) → void

**Input**: `direction` (string): "up" | "down" | "left" | "right"

**Effect**: Shift all pixels in layer by 1 pixel; recalculate tiles (US1 feature)

---

## Frame API Extensions

### Frame:addLayer(layerName) → Layer

**Input**: `layerName` (string, max 32 chars)

**Output**: New empty Layer

**Effect**: Appends layer to frame's layer list

---

### Frame:deleteLayer(layerIndex) → void

**Precondition**: Frame has > 1 layer

**Effect**: Remove layer, re-index layers, adjust active layer if needed

---

### Frame:getLayerCount() → number

---

### Frame:getLayer(layerIndex) → Layer

---

### Frame:setActiveLayer(layerIndex) → void

---

### Frame:getActiveLayer() → Layer

---

## Transparency Helpers

### Transparency.encode(state) → number
**Input**: "opaque" | "transparent" | "empty"  
**Output**: 0 | 1 | 2

### Transparency.decode(byte) → string
**Input**: 0 | 1 | 2  
**Output**: "opaque" | "transparent" | "empty"

### Transparency.isTransparent(byte) → boolean
**Output**: True if byte == 1

---

## Image Load/Save

### Image:loadJSON(filePath) → Image

**Effect**: 
- Reads JSON (v1.0 or v1.1)
- Auto-upgrades v1.0 to v1.1 (single opaque layer)
- Returns Image with frames + layers

**Contract**: Spec 010 backward compatibility

---

### Image:saveJSON(filePath) → void

**Effect**: Write frames + layers to JSON v1.1

---

## Management Views

### LayerView.new(frame, callback) → LayerView

**Output**: Room-like object with `draw()`, `update()` methods

---

### LayerView:getSelectedLayer() → Layer

---

### LayerView:deleteSelectedLayer() → void

---

## Test Validation

**Headless Tests** (Constitution V):

```lua
test("Layer API: create and access", function()
  local layer = Layer.new(0, "Test", positions, transparency)
  assert(#layer:getPositions() == 375)
end)

test("Frame API: manage layers", function()
  local frame = Frame.new(0, 100)
  frame:addLayer("Layer 2")
  assert(frame:getLayerCount() == 2)
  frame:deleteLayer(1)
  assert(frame:getLayerCount() == 1)
end)
```

---

**Status**: ✅ Layer API contract defined
