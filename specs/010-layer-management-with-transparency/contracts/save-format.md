# Contract: JSON Storage Format (v1.1)

**Feature**: `specs/010-layer-management-with-transparency/`

**Updated**: 2026-08-31 (Third Round — fixed 3 layers; no per-cell transparency array)

**File**: `saves/<id>/frames` (datastore appends `.json`). Tile pixels live in `saves/<id>/sheet.pdi` (unchanged).

---

## Root

```json
{
  "version": "1.1",
  "name": "my-image",
  "gridWidth": 25,
  "gridHeight": 15,
  "tileCount": 24,
  "frames": [ ...Frame... ]
}
```

- `version`: string `"1.1"`. The loader also accepts number `1`, `"1.0"`, or a missing field → treated as v1.0 (flat) and upgraded.
- `frames`: 1–12, **in animation order** (the array index is the play order; reordering the array reorders the animation).

---

## Frame

```json
{ "frameIndex": 0, "duration": 100, "layers": [ ...Layer... ] }
```

- `frameIndex` (int): 0-based position; rewritten to match array order on save.
- `duration` (int > 0): ms.
- `layers`: **1–3 entries on disk**. A fully-empty Layer 2 or 3 (every position `0`) is omitted. The loader pads every frame back to **exactly 3** layers in memory.

---

## Layer

```json
{ "layerIndex": 0, "name": "Layer 1", "positions": [1, 1, 2, 2, ...], "visible": true }
```

- `layerIndex` (int): 0 = bottom/base, 1–2 = above. Matches the entry's position in `layers`.
- `name` (string): non-empty.
- `positions` (array<int>): exactly 375. Values:
  - `0` = **absent** (Layers 2–3 only — lower layers show through).
  - `1` = the white base tile.
  - `1..tileCount` = tile in the PDI sheet. That tile may contain `kColorClear` pixels (per-pixel transparency).
  - **Layer 1 has no `0`** — its non-ink cells are `1` (white).
- `visible` (bool, optional, default `true`).

**No `transparency` field.** Two tiles with the same ink pattern but different backgrounds (white vs. `kColorClear`) are stored as **separate tiles** — `hashTile` classifies each pixel as black / white / clear.

---

## Backward Compatibility (v1.0 → v1.1)

Old format: `frames` is an array of flat 375-int arrays (or of `{frameIndex, positions, duration}`). Detected by `frames[0]` **not** having a `.layers` table.

On load:
```
for each flat frame F:
  layer1 = { layerIndex 0, name "Layer 1", positions = validate375(F), visible true }
  frame  = { duration = F.duration or 100, layers = [ layer1 ] }
  padTo3(frame)   -- add empty Layer 2 + Layer 3 (positions all 0)
```

Next save writes v1.1 (one layer entry on disk for legacy art). Legacy tiles are black/white only, so the 3-class hash behaves identically to the old 2-class one.

---

## Validation on Load

- [ ] `version` is `"1.1"` / `1` / `"1.0"` / absent
- [ ] 1–12 frames
- [ ] each frame: after padding, exactly 3 layers with `layerIndex` 0, 1, 2
- [ ] each layer: `positions` exactly 375, values `0 .. tileCount` (Layer 1: `1 .. tileCount`)
- [ ] malformed frame → skipped; all frames malformed → one white fallback frame

---

## Example (2 layers on disk, 3 in memory)

```json
{
  "version": "1.1", "name": "hero", "tileCount": 12,
  "frames": [
    {
      "frameIndex": 0, "duration": 100,
      "layers": [
        { "layerIndex": 0, "name": "Layer 1", "positions": [1,1,2,2, ...], "visible": true },
        { "layerIndex": 1, "name": "Layer 2", "positions": [0,0,5,6, ...], "visible": true }
      ]
    }
  ]
}
```
Loads as Frame 0 with Layers 1, 2 as given plus an empty Layer 3.

---

**Status**: ✅ Updated for Third-Round clarification.
