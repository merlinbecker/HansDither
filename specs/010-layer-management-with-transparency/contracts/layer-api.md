# Contract: Layer & Frame API

**Feature**: `specs/010-layer-management-with-transparency/`

**Updated**: 2026-08-31 (Third Round — fixed 3 layers, no add/delete; US4 = Frame Management View)

Adapted to the real (flat) codebase: there is no `Source/Models/`. Helpers live in `Source/LayerModel.lua` (global `LayerModel`, plain-table model) and `Source/PixelTransparency.lua`. Rooms are `EditorRoom` (Tile View), `ZoomRoom` (Zoom View), `PixelRoom` (Pixel View), plus the new `FrameManagementView`.

---

## Data shape

```lua
-- frame-layer entry (runtime, 1-indexed layers[1..3])
entry = {
  duration = 100,
  layers = {
    [1] = { layerIndex = 0, name = "Layer 1", positions = {375 ints, all >= 1}, visible = true },
    [2] = { layerIndex = 1, name = "Layer 2", positions = {375 ints, 0 = absent},  visible = true },
    [3] = { layerIndex = 2, name = "Layer 3", positions = {375 ints, 0 = absent},  visible = true },
  }
}
```

No `transparency` array. Transparent pixels are `kColorClear` inside the tiles referenced by `positions`.

---

## LayerModel

| Function | Contract |
|----------|----------|
| `LayerModel.LAYER_COUNT` | `3` (constant). |
| `LayerModel.newLayer(index0, name)` | Layer 1 → positions all `1`; Layers 2–3 → all `0`. |
| `LayerModel.newFrameLayersFromFlat(flat, duration)` | Wraps a flat 375-array as Layer 1, pads Layers 2–3 empty → entry with **exactly 3** layers. |
| `LayerModel.cloneFrameLayers(entry)` | Deep copy (all 3 layers). |
| `LayerModel.padTo3(entry)` | Ensures exactly 3 layers (adds empty upper layers, trims/renumbers). |
| `LayerModel.validate(entry)` | `true` iff exactly 3 layers, `layerIndex` 0..2, each `positions` has 375 non-negative ints, Layer 1 has no `0`. |
| `LayerModel.compositeToFlat(entry)` | 375-array; per cell the topmost layer with `positions[c] ~= 0` wins, else `1`. |
| `LayerModel.compositeToTiles(entry, getTile, registerTile)` | Like `compositeToFlat` but merges per-pixel where >1 layer contributes at a cell (registers merged tiles). |
| `LayerModel.clampActive(entry, i)` | Returns `i` if `1 <= i <= 3`, else `1`. |
| `LayerModel.cycleActive(entry, i, delta)` | Wraps in `1..3`. |
| `LayerModel.shiftLayerContent(entry, active1, dir, getTile, registerTile)` | Shifts the layer's 400×240 pixel content by 1px (wrap), rebuilds all 375 tiles; upper-layer all-clear tiles collapse to `0`. Returns `true` on success. |

**Removed**: `addLayer`, `deleteLayer` (layers are a fixed structure).

---

## PixelTransparency

| Function | Contract |
|----------|----------|
| `OPAQUE=0`, `TRANSPARENT=1`, `EMPTY=2` | Internal 3-code pixel state. |
| `encode(state) / decode(byte)` | `"opaque"/"transparent"/"empty"` ↔ `0/1/2`. |
| `isTransparent / isOpaque / isEmpty / sanitize` | Predicates; `sanitize` clamps to `{0,1,2}` (fallback opaque). |
| `fromColor(c) / toColor(b)` | `black↔OPAQUE`, `clear↔TRANSPARENT`, `white↔EMPTY`. |
| `sampleState(image, x, y)` | 3-code state of a tile pixel. |

Per-layer **off state**: Layer 1 → `EMPTY` (renders white); Layers 2–3 → `TRANSPARENT` (renders `kColorClear`). The Pixel/Zoom/Tile edit paths pass this to the room.

---

## EditorRoom (Tile View)

| Method | Contract |
|--------|----------|
| `EditorRoom:getImageData()` | `{id, name, imagetable, frames (flat composite cache), frameLayers (3 layers/frame), activeLayer (1..3), hashIndex}`. |
| `EditorRoom:getActiveLayerInfo()` | `{index, count=3, name}` for the HUD indicator (FR-015). |
| `EditorRoom:shiftActiveLayer(dir)` | US1 entry point; shifts + re-composites; returns `true` on success. |
| `EditorRoom:currentZoomContext()` | Fresh 3×3 context at the cursor (for ZoomRoom after a shift). |
| **B held + Up / Down** | Cycles `activeLayer` +1 / -1 with wrap (FR-013/014/017). Single press = single step. |
| **B held + Left / Right** | Steps the animation frame prev / next (FR-016); **B + Right on the last frame** appends a new frame (deep copy). |
| **Crank, no B** | Opens the tile picker: `referencedTileIndices()` scans the **layer positions** (`frameLayers[*].layers[*].positions`, skipping `0`) — not the composite cache, so covered-layer tiles stay reachable — stepped ~1 per 30° with wraparound; sets `activeTile` (index 1 → `nil`); overlay auto-hides ~1.5 s after the last turn (FR-025/026). |
| Short **B-tap** | Eyedropper; `pipette()` sets `activeTile` and shows "Tile N picked" in the Bauchbinde for ~1.5 s (FR-027). Suppressed if B was used for zoom (`bUsedForZoom`) or B + D-Pad nav (`bNavConsumed`). |
| B held + Crank **backward** | Opens the Frame Management View (FR-018) — unchanged by the Fourth-Round redesign. |

Edits (`setCell`, `applyTileEdits`) route through `writeActiveLayerPosition`: on Layers 2–3 a write of the white tile `1` becomes `0` (absent), so the eraser stays a see-through eraser.

---

## FrameManagementView (US4)

| Method / Input | Contract |
|----------------|----------|
| `FrameManagementView:init(switchRoom, editorRoom)` | Wiring. |
| `FrameManagementView:setImageData(imageData)` | Receives the live `imageData` from EditorRoom on entry. |
| D-Pad Up/Down | Move the list cursor over frame entries (clears any mark). |
| A | Mark the frame under the cursor. |
| A again (marked frame) | Delete the marked frame (two-step confirmation); **rejected if only 1 frame remains**. |
| Left / Right (frame marked) | Move the marked frame one slot earlier / later; clamped at the ends; `frameLayers` and the `frames` cache move together; the mark follows. |
| B released | `switchRoom(editorRoom)`; sets `imageData.returnFrame`; `currentFrame` clamped into the new sequence. |

No Layer View, no per-frame layer submenu (FR-023).

---

## Storage (ImageStoreCodec)

| Function | Contract |
|----------|----------|
| `newSaveOperation(imageData)` | Prefers `imageData.frameLayers`; writes v1.1 via `createFramesTableV11`. Empty Layers 2–3 omitted. Preview + frame count from the flat composite. |
| `newLoadOperation(id)` | Structure-detects v1.0/v1.1; upgrades flat → Layer 1; **pads every frame to 3 layers**; returns `frames` (composite) + `frameLayers` + `activeLayer=1`. |
| `createFramesTableV11(name, frameLayers, tileCount)` | v1.1 JSON; each frame `{frameIndex, duration, layers[1..3, empty upper omitted]}`. |
| `pruneUnusedTilesLayered(imagetable, frameLayers, tileCount)` | Global prune across all layers of all frames; `(newImagetable, newFrameLayers, newCount)`. |
| `hashTile` / `imagesVisiblyEqual` | 3-class (black / white / clear). |

---

**Status**: ✅ Updated for Third-Round clarification.
