# Data Model: Layer Management, Precise Pixel Shifting & Transparency Support

**Feature**: `specs/010-layer-management-with-transparency/`

**Date**: 2026-08-31

**Status**: Complete — Based on research.md decisions

---

## Overview

This data model extends Spec 009's storage format with a **fixed 3-layer structure per frame**. Per-pixel transparency is **not** stored as metadata — it lives directly in the 16×16 tile bitmap as `gfx.kColorClear` and is deduplicated by a 3-class tile hash (black / white / clear). All frame/layer structure is stored in JSON; the PDI tile sheet is unchanged.

> **Third-Round clarification (2026-08-31):** every frame has **exactly 3 layers, always** — no add/delete. Layer 1's non-ink pixels are white; Layers 2–3's are transparent. There is no per-cell `transparency` array. An empty Layer 2/3 is omitted from the saved file and rebuilt on load. US4 is a Frame Management View (reorder + delete frames).

---

## Entity: Layer

**What it represents**: One of a frame's **three fixed** drawable canvases.

**Attributes**:
- `layerIndex` (number): stacking slot, `0` = bottom/base, `1`–`2` = above. Always exactly {0, 1, 2} per frame.
- `name` (string): "Layer 1" / "Layer 2" / "Layer 3" by default.
- `positions` (array<number>): 375 tile indices (25×15 grid).
  - `0` = **absent** (this layer contributes nothing at this cell — lower layers show through). Only Layers 2–3 use `0`.
  - `1` = the white base tile (Layer 1's "off" state).
  - `1..N` = a tile in the shared PDI imagetable. That tile may itself contain `kColorClear` (transparent) pixels.
  - Invariant: exactly 375 entries.
- `visible` (boolean, optional): default `true`. (Reserved; no UI toggles it in this spec.)

There is **no `transparency` array.** Per-pixel transparency is a property of the referenced tile (a `kColorClear` pixel), not of the layer.

**Relationships**:
- **Frame**: exactly one Frame has exactly three Layers.
- **ImageTable (PDI)**: non-zero positions reference shared tiles (N-to-1).

**Validation Rules**:
- `positions` is exactly 375 non-negative integers.
- Layer 1 (`layerIndex 0`): every position ≥ 1 (no `absent`).
- Layers 2–3: positions in `0 .. tile_count`.
- A frame has exactly three layers with `layerIndex` 0, 1, 2 in order.

**State Transitions**:
- **Created**: Layer 1 = all `1` (white); Layers 2–3 = all `0` (absent/empty).
- **Edited**: only the *active* layer changes. On Layer 1 the eraser writes `1` (white); on Layers 2–3 it writes `0` (absent). A pixel-level transparent write produces a tile with `kColorClear` pixels.
- **Active**: selected via **B + Up/Down** (Fourth Round); highlighted in the Tile View HUD; the only editable layer in Zoom/Pixel.
- *(No "Deleted" transition — layers cannot be deleted.)*

---

## Entity: Pixel

**What it represents**: A single pixel of a 16×16 tile, edited in Pixel View.

**Attributes**:
- `x`, `y` (number): position in the 16×16 grid (0–15)
- `state` (enum): `ink` (black), or the layer's non-ink state — `white` on Layer 1, `transparent` (`kColorClear`) on Layers 2–3

Internally the editor tracks three codes (`PixelTransparency`: `OPAQUE=0`, `TRANSPARENT=1`, `EMPTY=2`) so the same grid model serves both layer kinds; per layer only two of them are reachable.

**Relationships**:
- **Tile**: 256 pixels form one Tile; the tile bitmap *is* the storage (no side array).
- **Layer**: a tile belongs to the active layer.

**State Transitions** (Pixel View):
- **A-press**: toggles `ink` ↔ the layer's non-ink state (eraser behaviour, Spec 008). This is the **only** paint action — an A-press on ink on Layer 2/3 therefore lands directly on `transparent`
- **B-press**: no effect (Fifth Round, 2026-09-01 — supersedes the earlier "B sets the non-ink state"). B in Pixel View is reserved for the zoom-out modifier (B held + Crank backward)
- There is **no Y button** on Playdate hardware; every reachable state is covered by the A toggle alone

---

## Entity: Frame

**What it represents**: A single animation frame with exactly three layers.

**Attributes**:
- `frameIndex` (number): position in the animation sequence (0-based on disk). Reorderable / deletable via the Frame Management View.
- `duration` (number): display duration in ms (default 100).
- `layers` (array<Layer>): **exactly 3** in memory, ordered by `layerIndex` 0→2.

**Relationships**:
- **Image**: an Image has 1–12 Frames in order.
- **Layer**: a Frame has exactly 3 Layers.
- **ActiveLayer**: a session-only 1..3 index held by the editor (not persisted).

**Validation Rules**:
- `duration` > 0.
- Exactly 3 layers in memory (`layerIndex` 0, 1, 2). On disk a frame may carry **1–3** layer entries; missing upper layers are empty and are re-added on load.
- Image frame count 1–12.

**State Transitions**:
- **Created**: Layer 1 = white, Layers 2–3 = empty. A new frame is appended by **B + Right on the last frame** (deep copy of the current one) — the only frame-creation gesture.
- **Active**: selected via **B + Left/Right** in Tile View (Fourth Round).
- **Reordered / Deleted**: via the Frame Management View (min. 1 frame remains).

---

## Composition: Image

**Attributes**:
- `version` (string): "1.1" (tracks compatibility with Spec 009 → Spec 010 upgrade)
- `frames` (array<Frame>): All frames in image (1–12 frames, per Constitution IV)
- `tileCount` (number): Total tiles in imagetable (stored in PDI, referenced here for validation)

**Relationships**:
- **PDI File**: external imagetable of deduplicated 16×16 tiles (referenced by every non-zero position). Tiles carry ink/white/clear pixels.
- **JSON File**: `version`, `tileCount`, `frames[].{frameIndex, duration, layers[]}`.

**Validation Rules**:
- `version` "1.1" (or number `1` / `"1.0"` / absent → treated as v1.0 and upgraded).
- 1–12 frames, in sequence order.
- Metadata size: 12 frames × 3 layers × 375 tile indices ≈ negligible.

---

## Storage Format

### JSON Schema v1.1

```json
{
  "version": "1.1",
  "tileCount": 24,
  "frames": [
    {
      "frameIndex": 0,
      "duration": 100,
      "layers": [
        { "layerIndex": 0, "name": "Layer 1", "positions": [1, 1, 2, 2, ...], "visible": true },
        { "layerIndex": 1, "name": "Layer 2", "positions": [0, 0, 5, 6, ...], "visible": true }
      ]
    }
  ]
}
```

- `layers` carries **1–3 entries**. A fully-empty Layer 2 or 3 (all positions `0`) is **omitted**; the loader pads every frame back to exactly 3 layers.
- No `transparency` field. Transparent pixels are `kColorClear` inside the tiles referenced by `positions`.

### Backward Compatibility (v1.0 → v1.1)

Old (Spec 009): `frames` is an array of flat 375-entry arrays, or of `{frameIndex, positions, duration}`. Detected by `frames[1]` **not** having a `.layers` table.

On load: each flat frame becomes `{duration, layers:[{layerIndex:0, name:"Layer 1", positions:<copied>, visible:true}]}`, then **padded to 3 layers** (Layers 2–3 all `0`). Next save writes v1.1 (still one layer entry on disk).

---

## PDI Format (Unchanged from Spec 009)

Deduplicated 16×16 tile imagetable. **New**: tiles may contain `kColorClear` pixels; `ImageStoreCodec.hashTile` / `imagesVisiblyEqual` classify each pixel as black / white / clear so transparency-bearing tiles dedupe separately from their opaque lookalikes. The sheet-compose / slice pipeline already uses `kColorClear` backgrounds and preserves transparent pixels unchanged.

Pruning (`pruneUnusedTilesLayered`) runs **globally across all layers of all frames** — a tile referenced by any (frame, layer) is kept.

---

## State Machine: Active Layer During Editing

**Runtime state**: the editor holds a single `activeLayer` (1..3), clamped to the frame's 3 layers. It is **not** persisted.

**Transitions** *(Fourth Round — B + D-Pad, one press = one step; supersedes "Up/Down + Crank")*:

1. **B held + Up**: `activeLayer = activeLayer % 3 + 1` (forward, Layer 1→2→3→1).
2. **B held + Down**: `activeLayer = (activeLayer + 1) % 3 + 1` (backward, Layer 1→3→2→1).
3. **Frame switch** (B held + Left/Right): `activeLayer` unchanged — every frame has all 3 layers. A defensive `clampActive` to Layer 1 only fires on corrupt data.
4. **Crank (no B)**: does **not** touch `activeLayer` — it drives the tile picker (`activeTile`), a separate session value.
5. *(No "layer deleted" transition.)*

---

## Key Invariants

1. **Fixed Layer Count**: every frame in memory has exactly 3 layers, `layerIndex` 0, 1, 2.
2. **Position Array**: every layer's `positions` has exactly 375 entries.
3. **Layer 1 Opacity**: Layer 1's positions are all ≥ 1 (never `0`/absent).
4. **Tile Validity**: every non-zero position references a valid imagetable index.
5. **Frame Count**: 1–12 frames, kept in sequence order.
6. **No transparency array**: transparency is only ever a `kColorClear` pixel inside a tile.

**Verification**: headless tests + save/load round-trip; arc42 ch. 8 documents the integrity checks.

---

## Example: Three-Layer Frame

```
Layer 3: positions [0, 0, 10, 0, 0, ...]   (mostly absent)
Layer 2: positions [0, 5,  6, 7, 0, ...]
Layer 1: positions [1, 1,  2, 2, 1, ...]   (never 0)
```

**Composited (flat cache)** — per cell, the topmost layer with a non-zero position wins:
- cell 0: only Layer 1 → tile 1
- cell 1: Layer 2 → tile 5
- cell 2: Layer 3 → tile 10
- cell 3: Layer 2 → tile 7 (Layer 3 absent here)

A tile referenced by an upper layer may itself contain `kColorClear` pixels; where it does, the composited tile is a **merged** tile (upper non-clear pixels over the lower layer) with its own deduplicated index. Cells where only one layer contributes keep that layer's tile index unchanged.

**Edited** (Zoom/Pixel View): only `activeLayer`'s positions change; the flat cache is regenerated per edited cell.

---

## Migration Example: Spec 009 → Spec 010

**Input** (Spec 009, flat): `{ "version": 1, "tileCount": 3, "frames": [ [1,1,2,2,3,...] ] }`

**In memory after load**:
```
Frame 0 {
  duration 100,
  layers: [
    { layerIndex 0, "Layer 1", positions [1,1,2,2,3,...] },   // from the flat array
    { layerIndex 1, "Layer 2", positions [0,0,0,...] },        // padded, empty
    { layerIndex 2, "Layer 3", positions [0,0,0,...] },        // padded, empty
  ]
}
```

**Next save** writes v1.1 with a single layer entry (empty Layers 2–3 omitted). User sees no change.

---

## Testing Validation (headless)

- `LayerModel` always yields exactly 3 layers; `validate` rejects ≠ 3.
- Save/load round-trip: layer positions + frame order + duration preserved; empty upper layers omitted on disk and rebuilt on load.
- v1.0 flat load → 3 layers, Layer 1 from the flat array, 2–3 empty.
- 3-class `hashTile`: white-bg vs. transparent-bg tiles hash differently; legacy black/white tiles unchanged.
- Frame reorder / delete round-trips; delete rejected at 1 frame.

---

**Status**: ✅ Data model updated for the Third-Round fixed-3-layer clarification.
