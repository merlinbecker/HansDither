# Implementation Plan: Layer Management, Precise Pixel Shifting & Transparency Support

**Branch**: `feature/0.3-addons` | **Date**: 2026-08-31 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/010-layer-management-with-transparency/spec.md`

---

## Summary

Hans-Dither gains four editing capabilities:

1. **Precise Pixel Shifting (US1, P1)**: hold B + arrow keys in Zoom View to shift the active layer's content 1 pixel at a time, with automatic tile recalculation.
2. **Transparency Support (US2, P1)**: per-pixel transparency stored as `kColorClear` in the tile bitmap. The non-ink pixel state is **white on Layer 1**, **transparent on Layers 2–3**.
3. **Layer & Frame Switching (US3, P1)**: every frame has a **fixed structure of exactly 3 layers** (no add/delete, like the 12-frame cap). **B + Up/Down** cycles the active layer; **B + Left/Right** steps frames (B + Right on the last frame appends one). *(Fourth Round, from hardware testing — supersedes "Up/Down + Crank".)*
4. **Frame Management View (US4, P2)**: hold B + Crank backward in Tile View to open a list of all frames; reorder frames and delete frames (min. 1). No Layer View — layers are fixed.
5. **Tile Picker & Eyedropper Toast (US5, Fourth Round)**: turning the Crank (no B) in Tile View opens a filmstrip picker over the *referenced* tiles (~30°/tile, wraparound, auto-hide); the eyedropper (short B-tap) shows "Tile N picked" briefly.

All features reuse existing SDK capabilities (SDK-First, Constitution I) and the proven Room-based navigation and PDI storage model (Constitutions II–IV).

> **Third-Round clarification (2026-08-31)** replaced the earlier "1–3 optional layers with add/delete" model. Layers are now a constant of 3; empty upper layers are omitted on disk; US4 manages frames, not layers.

---

## Technical Context

**Language/Version**: Lua 5.3 via Playdate SDK (latest)

**Primary Dependencies**: 
- Playdate SDK (graphics, imagetable, tilemap, datastore, json, crank, input)
- Existing ImageStoreCodec module (Spec 009) for tile management
- Existing Room-based UI architecture (TileView, ZoomView, PixelView)

**Storage**: PDI-format image tables + JSON metadata (frame/layer structure). Extends Spec 009 file format.

**Testing**: `lua tests/headless_tests.lua` (Constitution V, mandatory gate)

**Target Platform**: Playdate handheld device + simulator

**Project Type**: Pixel art editor (Lua desktop/handheld application)

**Performance Goals**: 
- 60 FPS rendering in all views (Playdate native frame rate)
- Pixel shifts must recalculate tiles without perceptible lag
- Layer switching must be instantaneous (< 1 frame delay)
- Management view scrolling must be smooth (similar to existing SelectionRoom)

**Constraints**: 
- Playdate hardware: ~64 MB RAM, single-core CPU, 320x240 minimum display
- Input limited to D-Pad, A/B buttons, Crank (no keyboard/mouse)
- File I/O must remain responsive (Spec 009 coroutine pattern for long saves)
- Backward compatibility: existing images (pre-transparency) must load without errors

**Scale/Scope**: 
- **Layers per frame**: FIXED at **exactly 3, always** — a constant, not a maximum. No add/delete. Empty upper layers are omitted on disk and rebuilt on load.
- Max frames: capped at 12 (Constitution IV, YAGNI); reorderable + deletable via US4 (min. 1)
- Image resolution: 400×240 pixels, 25×15 tiles = 375 tile positions per layer per frame
- **Backward Compatibility**: legacy flat images load as Layer 1 + two empty upper layers (no data loss)

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ Principle I: SDK-First

**Status**: PASS

- Layer/frame switching uses B + D-Pad (single press = single step); the Crank drives the tile picker via `getCrankChange()` + a sub-360° accumulator (Fourth Round)
- Pixel shifting relies on existing graphics API for tile rendering
- Transparency is managed via imagetable pixel states (native SDK)
- View navigation uses existing Room pattern (switchRoom API)
- No custom image decompression or rendering engine required

---

### ⚠️ Principle II: Native Formats & PDI

**Status**: Resolved

**Decision**: JSON metadata carries `frames[].layers[]` (1–3 on disk, 3 in memory). Transparency is **not** metadata — it is a `kColorClear` pixel inside the PDI tile, deduplicated by a 3-class tile hash (black/white/clear). PDI structure is unchanged; the sheet-compose/slice pipeline already preserves `kColorClear`.

**Rationale**: no custom parser, no side arrays; transparency rides the native 1-bit mask; Spec 009 dedup + pruning still apply (globally across all layers).

---

### ✅ Principle III: Architekturdokumentation in arc42

**Status**: PASS (planned)

**Required Updates** (Phase 2):
- arc42 Chapter 4 (Solution Strategy): Layer/transparency architecture section
- arc42 Chapter 9 (Architecture Decisions): ADR for layer rendering, pixel state model

**Gate**: Plan includes explicit arc42 update tasks in Phase 2 (tasks.md).

---

### ✅ Principle IV: Simplicity before Expansion

**Status**: PASS

**Justification**:
- Layers are a fixed structure of 3 (like the 12-frame cap) — no add/delete state machine, no Layer View
- Layers stored per-frame; frame switching never changes the layer count
- No undo/redo, no blend modes / opacity gradients
- Frame Management View mirrors the SelectionRoom list pattern (no new UI paradigm)
- Pixel shifting is single-direction, 1px per press (no rotation/flip)

---

### ✅ Principle V: Testpflicht (NICHT VERHANDELBAR)

**Status**: PASS (gates enforced)

**Mandatory Test Gates**:
1. `lua tests/headless_tests.lua` — must pass with "ALLE TESTS BESTANDEN"
2. `buildNumber` increment + `pdc Source "Hans Dither.pdx"` — required for every code change

**New Test Coverage**:
- Layer creation, switching, transparency state round-trip
- Pixel shifting + tile recalculation
- Management view navigation

---

## Project Structure

### Documentation (this feature)

```text
specs/010-layer-management-with-transparency/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output (pending)
├── data-model.md        # Phase 1 output (pending)
├── quickstart.md        # Phase 1 output (pending)
├── contracts/           # Phase 1 output (pending)
└── tasks.md             # Phase 2 output (pending)
```

### Source Code (Playdate Lua project)

```text
Source/                          # flat — there is NO Rooms/ or Models/ dir
├── EditorRoom.lua               # "Tile View": B+D-Pad layer/frame switch, Crank tile picker, composite cache, shift entry, B+Crank-back → US4
├── ZoomRoom.lua                 # "Zoom View": B + arrows → shift active layer
├── PixelRoom.lua                # "Pixel View": 3-state grid, layer-dependent off-state, B = transparent
├── FrameManagementView.lua      # NEW (US4): list/reorder/delete frames
├── LayerModel.lua               # NEW: plain-table frame-layer model (always 3), compositing, shift
├── PixelTransparency.lua        # NEW: 3-code pixel state ↔ gfx colours
├── ImageStore.lua               # MODIFY: createImage emits 3-layer frameLayers
├── ImageStoreCodec.lua          # MODIFY: v1.1 save/load, pad-to-3, 3-class hash, layered prune
└── main.lua                     # MODIFY: import + wire FrameManagementView

tests/headless_tests.lua         # MODIFY: Spec 010 sections per user story
```

**Structure Decision**: single Playdate Lua project, flat `Source/`. The three editing rooms are threaded through the active layer; one new room (`FrameManagementView`) is added. The plan's earlier `Source/Rooms/` and `Source/Models/` paths do not exist — see `tasks.md` "Implementation Notes".

---

## Complexity Tracking

| Design Point | Rationale | Alternative Rejected |
|--------------|-----------|----------------------|
| Fixed 3 layers per frame | No add/delete state machine; matches 12-frame cap | 1–3 optional layers → needs Layer View + undefined "add layer" gesture |
| Transparency in the tile bitmap (`kColorClear`) | Native 1-bit mask; per-pixel; dedup separates variants | Per-cell 0/1/2 array → can't do mixed-transparency cells |
| Layer-dependent off-state (white / transparent) | User's mental model: Layer 1 has a white bg, upper layers see through | Uniform "empty" → upper layers can't see through, or Layer 1 shows app bg |
| Flat composite cache (`imageData.frames`) | Existing tilemap draws a flat 375-array; cheap | Compositing engine / multi-tilemap → complexity + perf cost |
| US4 = Frame Management View | Frames need reorder/delete for a real animation; layers don't | Layer management view → nothing to manage |

---

## Next Steps

**Phase 0** (this step): ✅ Complete — Constitution check passed, technical context finalized

**Phase 1** (pending):
- Generate `research.md` (document decisions + alternatives)
- Generate `data-model.md` (Layer entity, pixel transparency, relationships)
- Generate `contracts/` (API schemas)
- Generate `quickstart.md` (validation scenarios)
- Update `.github/copilot-instructions.md`

**Phase 2** (pending):
- Generate `tasks.md` (implementation tasks, test gates, arc42 updates)
