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
| `LayerModel.shiftLayerContent(entry, active1, dir, getTile, registerTile)` | Shifts the layer's 400×240 pixel content by 1px (wrap), rebuilds all 375 tiles; upper-layer all-clear tiles collapse to `0`. Returns `true` on success. Synchronous single-step wrapper (ADR-043) around `shiftDelta`/`decodeLayerGrid`/`materializeShiftedGrid` below — unchanged signature/behaviour for existing callers/tests. |
| `LayerModel.shiftDelta(dir)` | `"up"/"down"/"left"/"right"` → `dx, dy` for a 1px step, or `nil` for an invalid direction (ADR-043). |
| `LayerModel.decodeLayerGrid(layer, getTile)` | Decodes the layer's full 400×240 pixel content into a 3-state grid (`grid[gy][gx]`); pure read, no mutation (ADR-043). |
| `LayerModel.materializeShiftedGrid(layer, grid, offX, offY, registerTile)` | Rebuilds all 375 tiles of `layer`, reading `grid` through a wrap offset `(offX,offY)`; writes `layer.positions`. The actual "shift" is just the read offset — no second 96,000-cell copy (ADR-043). |
| `LayerModel.imageFromGrid(grid, offX, offY, tileCol0, tileRow0)` | Synthesizes ONE 16×16 tile image from `grid` at 0-based tile position `(tileCol0,tileRow0)`, through the same wrap offset — for a live preview while a shift session is still open, without rebuilding all 375 tiles (ADR-043). |

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

**PixelRoom input (Fifth Round, 2026-09-01):**

| Input | Effect |
|-------|--------|
| A-press / A-drag | The only paint action. First cell decides the stroke value: A on ink → the layer's off state (`EMPTY`/white on Layer 1, `TRANSPARENT`/`kColorClear` on Layers 2–3); A on non-ink → `OPAQUE`. |
| B-tap | **No effect** — `BButtonDown/Up` are no-ops (supersedes FR-007's B-paint). No stray pixel is left when releasing the zoom-out gesture. |
| B held + Crank backward | Zoom-out (leaves PixelRoom); unchanged, Contract PR-01 (one crank-read API per `update()`). |
| `setCurrentTile(tile, index, offStateCode)` | `offStateCode == TRANSPARENT` → upper-layer eraser; anything else → `EMPTY`. Passed by `ZoomRoom:zoomIntoPixelRoom` from `activeLayerIsBase`. |

---

## EditorRoom (Tile View)

| Method | Contract |
|--------|----------|
| `EditorRoom:getImageData()` | `{id, name, imagetable, frames (flat composite cache), frameLayers (3 layers/frame), activeLayer (1..3), hashIndex}`. |
| `EditorRoom:getActiveLayerInfo()` | `{index, count=3, name}` for the HUD indicator (FR-015). |
| `EditorRoom:shiftActiveLayer(dir)` | US1 entry point. **ADR-043 (perf review):** does NOT re-composite immediately — decodes the active layer once per shift *session* and accumulates further calls as an O(1) wrap offset (`pendingShift`); returns `true` on success (session opened/extended, not yet materialized). |
| `EditorRoom:flushLayerShift()` | Materializes an open shift session (rebuilds the 375 tiles + re-composites); idempotent, returns `true` if something was pending, else `false`. MUST run before any code path reads/writes canonical tiles/positions (ADR-043 lists the call sites: `applyTileEdits`, ZoomRoom `zoomIntoPixelRoom`/`commitAndReturnToEditor`/`commitForTerminate`, `BButtonUp`, `entered()`, `buildPauseMenuImage()`). |
| `EditorRoom:currentZoomContext()` | Fresh 3×3 context at the cursor (for ZoomRoom after a shift). While a shift session is open, the 3 slot images are synthesized straight from the buffered pixel grid (`LayerModel.imageFromGrid`) instead of the (not yet rebuilt) real tiles — no flush needed just to preview. |
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
