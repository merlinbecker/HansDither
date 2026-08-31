# Implementation Plan: Layer Management, Precise Pixel Shifting & Transparency Support

**Branch**: `feature/0.3-addons` | **Date**: 2026-08-31 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/010-layer-management-with-transparency/spec.md`

---

## Summary

Hans-Dither gains three complementary editing capabilities:

1. **Precise Pixel Shifting (US1, P1)**: Hold B + arrow keys to shift drawn content pixel-by-pixel in Zoom View, with automatic tile recalculation
2. **Transparency Support (US2, P1)**: Place transparent pixels in Pixel View via B-press, stored with full alpha channel support
3. **Layer Management (US3/US4, P1/P2)**: Per-frame layers with Crank cycling, plus dedicated management view for organizing and deleting layers

All features leverage existing Playdate SDK capabilities (SDK-First, Constitution I) and extend the proven Room-based navigation and PDI-based storage model (Constitutions II–IV).

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
- **Max layers per frame**: FIXED at 3 layers (Layer 1 mandatory + optional Layer 2–3) per frame — hard architectural limit for backward compatibility and performance predictability
- Max frames: already capped at 12 (Constitution IV, YAGNI)
- Image resolution: 400×240 pixels (standard), 25×15 tiles = 375 positions per frame
- **Backward Compatibility**: Legacy 1-layer images auto-upgrade to Layer 1 on load (no data loss)

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ Principle I: SDK-First

**Status**: PASS

- Layer cycling uses Crank API (built-in, no custom rotation handler needed)
- Pixel shifting relies on existing graphics API for tile rendering
- Transparency is managed via imagetable pixel states (native SDK)
- View navigation uses existing Room pattern (switchRoom API)
- No custom image decompression or rendering engine required

---

### ⚠️ Principle II: Native Formats & PDI

**Status**: Requires Clarification → Resolved

**Decision**: Extend JSON metadata to include `layers` array per frame + add transparency state to pixel representation. PDI format remains unchanged (layers are logical, not physical separation). Spec 009 tile deduplication still applies per-layer.

**Rationale**: Maintains compatibility with Spec 009, uses native SDK JSON serialization, requires no custom parsers.

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
- Layers stored per-frame (not globally), simplifying state management
- No undo/redo system (out of scope)
- No layer blend modes, opacity gradients, or advanced effects
- Management view mirrors existing SelectionRoom pattern (no new UI paradigm)
- Pixel shifting is single-direction (no rotation/flip)

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
Source/
├── Rooms/
│   ├── TileView.lua          # MODIFY: add layer cycling Crank handler
│   ├── ZoomView.lua          # MODIFY: add pixel shifting (B + arrows)
│   ├── PixelView.lua         # MODIFY: add transparency (B-press)
│   ├── LayerView.lua         # NEW: layer management view
│   └── AnimationLayerView.lua # NEW: frame-level layer management
├── Models/
│   ├── ImageStore.lua        # MODIFY: add layer support
│   ├── Layer.lua             # NEW: layer data structure
│   └── PixelTransparency.lua # NEW: transparency state encoding
├── ImageStoreCodec.lua       # MODIFY: extend for transparency + layers
└── [existing modules]

tests/
├── headless_tests.lua        # MODIFY: add layer + transparency tests
└── layer_tests.lua           # NEW (optional): focused layer unit tests
```

**Structure Decision**: Single Playdate Lua project. Existing Room architecture extended; new dedicated Rooms added for management. Tests integrated into existing headless suite.

---

## Complexity Tracking

| Design Point | Rationale | Alternative Rejected |
|--------------|-----------|----------------------|
| Per-frame layers | Each frame may have different layer count | Global layers require frame ID mapping; more state |
| Transparency as pixel state | Binary transparent/opaque sufficient for pixel art | Blend modes add complexity without user request |
| Dedicated Management View | 10+ layers in Crank UI ergonomically poor | Inline control inadequate for reordering/deletion |
| Layer index preservation | Reduces re-selection; consistent with animation UI | Resetting to Layer 1 disrupts workflow |
| Management View submenu | Mirrors SelectionRoom navigation; proven pattern | Inline reordering adds interaction complexity |

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
