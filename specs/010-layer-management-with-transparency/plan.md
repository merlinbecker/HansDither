# Implementation Plan: Layer Management, Precise Pixel Shifting & Transparency Support

**Branch**: `feature/0.3-addons` | **Date**: 2026-08-31 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/010-layer-management-with-transparency/spec.md`

---

## Summary

Hans-Dither gains four editing capabilities:

1. **Precise Pixel Shifting (US1, P1)**: hold B + arrow keys in Zoom View to shift the content of **the tile under the cursor** 1 pixel at a time; the strip that crosses the boundary moves into the neighbour tile in that direction (2-tile strip, no wrap). *(Revised 2026-09-01, from hardware testing — was "the active layer's content"; see ADR-043.)*
2. **Transparency Support (US2, P1)**: per-pixel transparency stored as `kColorClear` in the tile bitmap. Layer 1 stays 2-state (ink/white); Layers 2–3 have 3 reachable paint states (ink/white/transparent) and default to transparent (never white) wherever no tile is placed yet. Painting in Pixel View is **A only** — on Layer 1 it toggles ink/white; on Layers 2–3 it cycles ink → white → transparent → ink; B does not paint. *(Sixth Round, from a debugging session — supersedes the Fifth Round's Layers 2–3 ink/transparent-only toggle.)*
3. **Layer & Frame Switching (US3, P1)**: every frame has a **fixed structure of exactly 3 layers** (no add/delete, like the 12-frame cap). **B + Up/Down** cycles the active layer; **B + Left/Right** steps frames (B + Right on the last frame appends one). *(Fourth Round, from hardware testing — supersedes "Up/Down + Crank".)*
4. **Frame Management View (US4, P2)**: hold B + Crank backward in Tile View to open a list of all frames; reorder frames and delete frames (min. 1). No Layer View — layers are fixed.
5. **Tile Picker & Eyedropper Toast (US5, Fourth Round; activation revised Tenth Round)**: a **full crank revolution** (no B) in Tile View opens a filmstrip picker over the *referenced* tiles (jiggle/partial turn does not); once open, ~30°/tile stepping, wraparound, auto-hide; the eyedropper (short B-tap) shows "Tile N picked" briefly.

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

- Layer/frame switching uses B + D-Pad (single press = single step); the Crank drives the tile picker via `getCrankChange()` — a signed `pickerArmDegrees` (≥ 360°, either direction) opens it (Tenth Round), then a signed 30°/tile `crankAccumDegrees` steps it (Fourth Round)
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
├── EditorRoom.lua               # "Tile View": B+D-Pad layer/frame switch, Crank tile picker, composite cache (pixel-perfect via LayerModel.compositeCellTile/compositeToTiles, T053), shift entry, B+Crank-back → US4
├── ZoomRoom.lua                 # "Zoom View": B + arrows → shift the cursor's tile into its neighbour (ADR-043); onion-skin backdrop (LayerModel.compositeBelow) shows layers below the active one through absent/transparent pixels while editing (Seventh Round)
├── PixelRoom.lua                # "Pixel View": layer-dependent paint cycle (Layer 1: 2-state ink/white; Layers 2-3: 3-state ink/white/transparent), A-only paint (B does not paint — Fifth/Sixth Round)
├── FrameManagementView.lua      # NEW (US4): list/reorder/delete frames
├── LayerModel.lua               # NEW: plain-table frame-layer model (always 3), compositing (compositeAt/compositeToFlat = cheap cell-level pick; compositeCellTile/compositeToTiles = pixel-perfect merge, wired into the render path Seventh Round; compositeBelow = onion-skin backdrop), shiftTileContent
├── PixelTransparency.lua        # NEW: 3-code pixel state ↔ gfx colours
├── ImageStore.lua               # MODIFY: createImage emits 3-layer frameLayers
├── ImageStoreCodec.lua          # MODIFY: v1.1 save/load (load path now pixel-perfect via compositeToTiles, Seventh Round), pad-to-3, 3-class hash, layered prune
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

---

## Eighth-Round Update (2026-09-06) — Frame Room & Overlay Consolidation

**Trigger**: hardware testing of the shipped Spec 010 / Spec 011 build (see `spec.md` → Clarifications, Eighth Round). Two defects:

1. The tile-picker overlay (`EditorRoom.drawTilePickerOverlay`, `px=(400-panelW)//2`, `py=(240-panelH)//2`) draws dead-centre over the artwork and the cursor. The frame/layer label, "Tile N picked" toast, status line and (Spec 011) `UndoPrompt` are four separately-placed pieces of chrome with no layout contract.
2. The Frame Management View is a hold-B modal list — B must stay held the whole time, and it is left by *releasing* B. That B-timing is fragile (`c2cbb6f fix(spec 010): FrameManagementView-Sackgasse beim B-Timing verhindern`) and awkward for real reordering work.

**Two work streams**, sequenced low-risk-first:

- **Phase A — Consolidated overlay bar** (`FR-028`, `SC-008`; revises `FR-015`/`025`/`027`): one bar on the screen edge *opposite* the tile cursor (`cursor.y <= GRID_ROWS/2` → bar bottom, else top; tie → bottom), carrying the frame/layer label, the tile-picker filmstrip, the "Tile N picked" toast and status messages, laid out so none overdraws another and none covers the cursor's tile. `UndoPrompt` (Spec 011) stays a separate layer above the bar, placement coordinated. Pure `EditorRoom.draw` + `Bauchbinde` change; the anchor rule is a pure function → headless-testable.
- **Phase B — Frame Management Room** (rewrites US4; revises `FR-018`–`FR-022`, `SC-004`/`007`): `FrameManagementView` becomes a persistent room — entered with **B + Crank backward** (unchanged gesture), left with **B + Crank forward**; the B-release exit is removed. Frames shown as a **thumbnail grid** built with `playdate.ui.gridview` (the same SDK primitive `SelectionRoom` and `PixelRoom` already use). Reorder: A marks, then the D-Pad moves the marked frame in the animation sequence.

- **Phase C — Architecture evidence** (Constitution III + iSAQB): arc42 Kap. 4/5/6/8/9/10/11 + **ADR-048**, **ADR-049**; plus the **Spec-010 Kap. 6 runtime-view backfill** that `tasks.md` T052 still lists as open.

### Technical Context (delta)

**Primary Dependencies (new use)**:
- `playdate.ui.gridview` (`CoreLibs/ui`, already imported in `main.lua`) — layout + scroll for the frame thumbnail grid, exactly as `SelectionRoom:buildGridview()` uses it (`gridview.new(w,h)`, `setNumberOfColumns/Rows`, `changeRowOnColumnWrap=false`, `drawCell` callback, `drawInRect`). Grid **navigation** stays manual index math (as `SelectionRoom` does) so it is headless-testable.
- `playdate.graphics.image` + `image:scaledImage()` for frame thumbnails, built from `imageData.frames[f]` (the flat 375-entry composite cache) + `imageData.imagetable` **inside `FrameManagementView`** — it does not `import "EditorRoom"` (keeps the no-cyclic-import rule from `main.lua`).

**Performance Goals (delta)**:
- Frame Room `entered()`: build ≤ 12 thumbnails once. Reorder: rebuild **only the two thumbnails a swap touches**; delete: drop one, no full rebuild. Must stay within one frame on device — **measured** (R11), not assumed (Spec 010's own R6 Nachtrag is the cautionary tale: ~192k `image:sample()` calls per keypress).
- Overlay bar: one extra layout pass per `EditorRoom.draw`, O(1).

**Constraints (delta)**:
- Crank: `FrameManagementView` reads **only** `playdate.getCrankTicks(4)` (same `tpr` as `EditorRoom`), never `getCrankChange()` in the same frame — CR-01 (research R10) forbids mixing. Its tick accumulator resets in `entered()`.
- The exit gesture is **armed only after B has been released at least once since `entered()`** (`bReleasedSinceEnter`). Without this, residual crank motion from the backward *entry* gesture feeds forward ticks straight into the only forward *exit* path — the c2cbb6f bug class on the opposite axis. See *Spec refinements surfaced during planning*.

**Scale/Scope (delta)**: 2 files rewritten (`FrameManagementView.lua`, `Bauchbinde.lua`), 1 modified (`EditorRoom.lua` — overlay draw + no code change to the entry gesture), 1 test file extended; arc42 7 chapters + 2 ADRs; `buildNumber` 37 → 38+.

### Constitution Check (Eighth Round)

*GATE: re-checked after design below. Result: PASS, no Complexity Tracking entries.*

#### ✅ Principle I: SDK-First — PASS

- Frame grid uses **`playdate.ui.gridview`** (SDK/CoreLibs), not a hand-rolled grid — the same primitive `SelectionRoom`/`PixelRoom` use. Documented in arc42 Kap. 4 + ADR-048.
- Thumbnails use `playdate.graphics.image` / `image:scaledImage()` (SDK) over the existing flat composite cache + `playdate.graphics.tilemap`.
- Room lifecycle uses the existing `switchRoom` DI pattern (`main.lua`) — `FrameManagementView` is already a wired room; only its internals change.
- Crank read via `playdate.getCrankTicks` (SDK), one API per frame (CR-01).
- Overlay bar is plain `playdate.graphics` drawing in `Bauchbinde` (already a headless-testable gfx helper with injected `gfx`). No new UI framework.

#### ✅ Principle II: Native Formats & PDI — PASS (unchanged)

- **No storage-format change.** Frame order and count already persist via JSON v1.1 (`frames[].layers[]`); the room only reorders/deletes the same `imageData.frameLayers` / `imageData.frames` arrays the list view already mutates (`swapFrames`, `table.remove`). No new field, no PDI change, no codec change.

#### ✅ Principle III: Architekturdokumentation in arc42 — PASS (planned, Phase C)

| Kapitel | Inhalt |
|---|---|
| `arc42/04-loesungsstrategie.md` | 2 Leitentscheidungen: persistenter Frame-Room (symmetrische B+Kurbel-Gesten, Arming), konsolidierte cursorabgewandte Overlay-Leiste |
| `arc42/05-bausteinsicht.md` | `FrameManagementView` → Room mit `entered()`/Exit-Lifecycle, `gridview` + Thumbnail-Cache; `Bauchbinde` vertikaler Anker; `EditorRoom.draw` Overlay-Abschnitt = eine Layout-Einheit. „Seit Spec 010 (Eighth Round)"-Klauseln |
| `arc42/06-laufzeitsicht.md` | **(a) Backfill** der seit Spec 010 fehlenden Sequenzen (Ebenen-Cyclen, Tile-Picker, Frame-Verwaltung Eintritt/Verlassen — T052). **(b) Neu**: „Frame-Room betreten → Grid navigieren → markieren → verschieben (n× `swapFrames` + `onFramesReindexed`) → löschen (`recordDeleteFrame`) → verlassen (B losgelassen ⇒ armiert; B+Kurbel vorw.) → `EditorRoom:entered()` klemmt `currentFrame`". „Overlay-Leiste: Cursor-Zone → Inhalt komponieren → cursorabgewandt zeichnen" |
| `arc42/08-querschnittliche-konzepte.md` | Overlay-Konzept: eine konsolidierte Leiste (cursorabgewandt, kollisionsfrei), Undo-Dialog als eigene Schicht. Room-Gesten-Konzept: symmetrische B+Kurbel-Gesten mit Arming-Bedingung |
| `arc42/09-architekturentscheidungen.md` + `arc42/adr/` | **ADR-048** `ADR-048-Frame-Verwaltung-persistenter-Room.md`, **ADR-049** `ADR-049-Konsolidierte-Overlay-Leiste.md` + Kurzeinträge §9.36/§9.37 |
| `arc42/10-qualitaetsanforderungen.md` | QS: Usability (Overlay verdeckt nie die Cursor-Zelle — SC-008); Performance (Thumbnail-Cache < 1 Frame beim Betreten, partielles Invalidieren); Robustheit (Room-Exit deterministisch durch Arming) |
| `arc42/11-risiken-und-technische-schulden.md` | R-32 Crank-Rückstau beim Room-Exit; R-33 Thumbnail-Render-Kosten; R-34 Overlay-Layout verdeckt Inhalt |
| `arc42/07-verteilungssicht.md` | **N/A** — keine Build-/Paketierungsänderung (Begründung dort vermerken; korrigiert die imprecise „6/7"-Notiz aus T052) |

#### ✅ Principle IV: Einfachheit vor Ausbau — PASS (net simplification)

- The persistent room **removes** the fragile B-hold + B-release lifecycle (`bWasHeld` state machine, the c2cbb6f dead-end fix). Net: less state.
- Grid **reuses** `SelectionRoom`'s `gridview` pattern verbatim — no new UI paradigm.
- Overlay consolidation **replaces** three ad-hoc placements (`drawBottom` label, centred picker panel, `drawBottom` status) + implicit `UndoPrompt` overlap with **one** anchored layout pass.
- Reorder decomposes into the adjacent `swapFrames` the code + Spec 011's `onFramesReindexed({swapped=...})` hook already handle — **no new reindex payload**.
- No thumbnail zoom/scrub. *(Ninth Round: "duplicate frame" + "delete frame" system-menu items added, mirroring `SelectionRoom`'s menu — reuse of an existing pattern, not a new paradigm.)*

#### ✅ Principle V: Testpflicht — PASS (gates enforced)

1. `lua tests/headless_tests.lua` → "ALLE TESTS BESTANDEN". New/rewritten Spec 010 "Eighth Round" coverage:
   - **Overlay anchor** (pure fn): `overlayAnchor(cursorY, GRID_ROWS)` → `"bottom"` for `y≤7`, `"top"` for `y≥8`; `overlayRegionRect(anchor, contentH)` never intersects the cursor-cell rect for any `y`; with the picker visible, label + filmstrip + status sub-rects are pairwise non-overlapping (SC-008).
   - **Frame Room grid nav**: index math for a `numColumns=3` grid (up/down = ±3 clamped, left/right = ±1 within row), mark/unmark on A, cursor move clears mark.
   - **Reorder**: A-mark + D-pad → marked frame moves; Left/Right = 1 adjacent `swapFrames` + 1 `onFramesReindexed({swapped})`; Up/Down = up to `numColumns` adjacent swaps (fewer at the ends), each firing `onFramesReindexed`.
   - **A toggle** *(Ninth Round)*: A marks / unmarks the cursor frame; never deletes.
   - **Delete semantics** *(Ninth Round)*: system-menu "delete frame" → `confirmingDelete` dialog (A = yes / B = no); on yes → `recordDeleteFrame` + `table.remove` + `onFramesReindexed({removed})`; rejected (no dialog) at 1 frame.
   - **Duplicate** *(Ninth Round)*: system-menu "duplicate frame" → deep-copy cursor frame, insert at `cursor+1`, `onFramesReindexed({inserted})`; rejected at 12 frames.
   - **Exit arming**: B+Crank-forward does nothing until B has been released once since `entered()`; then it fires `switchRoom(editorRoom)` with `imageData.returnFrame` set; `EditorRoom:entered()` clamps `currentFrame`.
   - **Spec 011 regression**: the existing `deleteFrame`-undo headless section still green through the rewritten path.
2. `Source/pdxinfo` `buildNumber` 37 → 38 before the first Phase-A `pdc`; +1 per subsequent phase with a code change; `pdc Source "Hans Dither.pdx"` clean.
- **Manual** (simulator + device): quickstart Scenario 4 (rewritten) + new Scenario 8 (overlay never covers the cursor, all cursor rows) + Scenario 9 (Frame Room enter/stay/reorder/delete/exit). Device: thumbnail-build FPS on `entered()` (R11), crank-exit has no false trigger from entry residual (R-32).

**Result**: PASS — no violations, Complexity Tracking stays empty.

### Design detail

> **Ninth-Round update (2026-09-06, from `/speckit-clarify`) — supersedes parts of this section.** The Frame Room's controls are aligned to `SelectionRoom`:
> - **A is a plain mark/unmark toggle** — it never deletes. `movedSinceMark` is **removed** (no "moved vs. not moved" branch).
> - **Delete + duplicate are system-menu items** — the "no room-local system menu" decision below is **overturned**. `entered()` registers **"delete frame"** and **"duplicate frame"** on `playdate.getSystemMenu()` (like `SelectionRoom`'s "new/copy/delete image"). "delete frame" acts on the **cursor** frame and shows the reused `SelectionRoom` confirm dialog (`confirmingDelete` / `drawConfirmDeleteDialog`, A = yes / B = no); rejected with no dialog at 1 frame. "duplicate frame" deep-copies the cursor frame, inserts at `cursor+1`, rejected at 12 frames.
> - New session state: `confirmingDelete` (bool | nil). Removed: `movedSinceMark`.
> - `inputHandler`: while `confirmingDelete` → A confirms, B cancels, all else inert (modal, mirrors `SelectionRoom`). Otherwise A = mark/unmark toggle; D-Pad = move marked frame or move cursor.
> - Duplicate needs an **`inserted` reindex payload** for Spec 011's `undoHistory:remapFrames` (mirror of the `removed` shift) — payload shape is a task-level detail.
> - `FR-021`/`FR-022` refinements below ("`numColumns` adjacent steps", arming clause) are now **in `spec.md`** (Ninth Round) — spec and plan agree; the *"Spec refinements surfaced during planning"* subsection is resolved.

**FrameManagementView (rewrite)** — session state: `cursor` (1-based grid index), `marked` (1-based | nil), `bReleasedSinceEnter` (bool), `confirmingDelete` (bool | nil), `crankAccu` (int, reset in `entered()`), `thumbCache` (`{ [pos] = scaledImage }`).
- `entered()`: `bReleasedSinceEnter=false`, `crankAccu=0`, `confirmingDelete=nil`, build `thumbCache` for all frames, build the `gridview` (`numColumns = 3`, rows = `ceil(n/3)`). `getSystemMenu():removeAllMenuItems()` then **register "delete frame" + "duplicate frame"** *(Ninth Round — mirrors `SelectionRoom:buildSystemMenu`; `EditorRoom:entered()` rebuilds its own menu on return)*.
- `update()`: read `getCrankTicks(4)` once → `crankAccu`; if `playdate.buttonIsPressed(kButtonB)` and `bReleasedSinceEnter` and `crankAccu >= ZOOM_TICK_THRESHOLD` → `returnToEditor()`. If B not pressed → `bReleasedSinceEnter=true`. Redraw on `needsRedraw`.
- `inputHandler()`: while `confirmingDelete` → `AButtonDown` confirms, `BButtonDown` cancels, all else inert (modal, mirrors `SelectionRoom`). Otherwise: `up/down/left/right ButtonDown` → if `marked` then `moveMarked(dx,dy)` else `moveCursor(dx,dy)`; `AButtonDown` → `pressA()`.
- `moveMarked(dx,dy)`: `steps = dx≠0 and 1 or numColumns`; `sign = (dx or dy) > 0 and 1 or -1`; loop `steps` times: `t = marked + sign`; break if out of `[1, frameCount()]`; `swapFrames(marked, t)`; swap `thumbCache[marked]`/`thumbCache[t]`; `editorRoom:onFramesReindexed({ swapped = { marked, t } })`; `marked = t`; `cursor = t`.
- `pressA()` *(Ninth Round)*: plain toggle — `marked ~= cursor` → `marked = cursor`; `marked == cursor` → `marked = nil`. Never deletes.
- **Menu callback `deleteFrame`** *(Ninth Round)*: guard `frameCount() > 1`; set `confirmingDelete = true` (dialog target = `cursor`). Dialog A → `recordDeleteFrame` + `table.remove` (both arrays + `thumbCache`) + `onFramesReindexed({removed})` + clear `confirmingDelete` + `marked = nil`. Dialog B → clear `confirmingDelete`.
- **Menu callback `duplicateFrame`** *(Ninth Round)*: guard `frameCount() < 12`; `layersCopy = LayerModel.cloneFrameLayers(frameLayers[cursor])`, flat-copy `frames[cursor]`; `table.insert(..., cursor+1, ...)` in both arrays + `thumbCache`; `onFramesReindexed({ inserted = cursor+1 })` (Spec 011 — new payload; see Ninth-Round callout).
- `returnToEditor()`: unchanged (`imageData.returnFrame = cursor`; `switchRoom(editorRoom)`).
- `draw()`: `gridview:drawInRect(0,0,400,240)`; `drawCell` → thumbnail from `thumbCache[index]` centred in the cell, `[*]` frame border if `index == marked`, selection ring if `index == cursor`, "Frame i/n" caption. If `confirmingDelete` → draw the confirm dialog last (reuse `SelectionRoom:drawConfirmDeleteDialog` style).
- **Entry gesture in `EditorRoom.handleCrank` is unchanged** (`zoomTickAccu <= -ZOOM_TICK_THRESHOLD` → `openFrameManagementView()`).

**Consolidated overlay bar** — `Bauchbinde` gains a vertical anchor:
- `Bauchbinde:draw(lines, hSide, vAnchor, screenW, screenH)` — `vAnchor` `"top"|"bottom"`; `bandY = vAnchor=="top" and margin or (screenH - bandH - margin)`. `drawBottom(text, side, screenW, screenH)` is **kept with its exact current signature** as a thin wrapper (`self:draw(text, side, "bottom", ...)`), so the other caller — `SelectionRoom.lua:456` `bauchbinde:drawBottom(label, "left", 400, 240)` — is unaffected. Only `EditorRoom` calls the new `draw`.
- `EditorRoom.draw`: compute `vAnchor = (cursor.y <= GRID_ROWS/2) and "bottom" or "top"`; `hSide` unchanged (`cursor.x <= GRID_COLS/2 and "right" or "left"`). Compose **one** region: line = `pickMessageVisible and pickMessage or "<frame/layer label>"`; if `statusMessage` append as a second line in the same band (not a second `drawBottom` at a fixed side — fixes the pre-existing bottom-left collision). If `pickerVisible`, the tile-picker filmstrip renders **inside the same anchored region**, stacked with the label line, never at screen-centre.
- `drawTilePickerOverlay`: `px` centred horizontally is fine; `py` becomes `vAnchor`-relative (top: `margin`; bottom: `240 - panelH - margin - labelH`).
- `UndoPrompt.draw()` stays last (own layer). Its box is centred; when the bar is at top the box already clears it, when at bottom likewise — no change needed, but ADR-049 records the coordination rule.
- Pure helpers for the headless test: `overlayAnchor(cursorY, rows)`, `overlayRegionRect(anchor, contentH, screenH)`, `cursorCellRect(cx, cy)`.

**Spec 011 shake gesture in the Frame Room** — **Resolved, no change.** Spec 011 `FR-010` already names the frame-management view in its *exclusion* list ("In Title-, Selection- und Frame-Verwaltungs-View DARF die Geste NICHT ausgewertet werden"). Spec 011 `research.md` R6 gave the *rationale* ("B is held there") which the persistent room retires — but the *requirement* stands: the Frame Room does not start the accelerometer and does not evaluate shake. `deleteFrame` undo entries are still recorded (the `recordDeleteFrame` hook is preserved) and surface when the user is back in the Tile View. Activating shake inside the Frame Room would be a **Spec 011 FR-010 change**, out of scope here. *(Recorded in ADR-048 §Konsequenzen.)*

### Architecture Governance & Technical Debt (iSAQB preset — Eighth Round)

**Applicability**: affects runtime behaviour (room joins `switchRoom` rotation with a real lifecycle; Tile View overlay layout pass), building blocks (`FrameManagementView`, `Bauchbinde`, `EditorRoom.draw`), interfaces (room `entered()`/exit; `Bauchbinde:draw` signature), quality attributes (usability, robustness of the room transition, thumbnail perf). **Not affected**: data model / storage / codec (frame order+count persist via v1.1 unchanged), context boundary (no new external interface), deployment (no build/packaging change).

**ADRs**:
- **ADR-048 — Frame-Verwaltung als persistenter Room**: enter B+Kurbel rückwärts / leave B+Kurbel vorwärts; B-release exit removed (retires the c2cbb6f dead-end fix); exit **armed** only after one B-release since `entered()`; reorder = sequential adjacent `swapFrames` (keeps Spec 011's `swapped` reindex payload valid); thumbnail grid via `playdate.ui.gridview`; controls mirror `SelectionRoom` — A is a mark/unmark toggle, **delete + duplicate are system-menu items** reusing `SelectionRoom`'s confirm-dialog pattern *(Ninth Round — overturns the earlier "no room-local system menu")*; shake stays inactive (Spec 011 FR-010).
- **ADR-049 — Konsolidierte Tile-View-Overlay-Leiste**: one region on the cursor-opposite edge for frame/layer label + tile-picker filmstrip + "Tile N picked" toast + status; picker no longer screen-centred; `Bauchbinde` gains a vertical anchor; `UndoPrompt` (Spec 011) stays a separate layer with coordinated placement; anchor logic is a pure function gated by SC-008.

**Risk & technical-debt review**:

| ID | Risk | Mitigation | Status |
|---|---|---|---|
| R-32 | Crank rückstau: entry (B+Kurbel rückwärts) residual motion feeds forward ticks into the forward-only exit → false exit (c2cbb6f class, opposite axis) | `bReleasedSinceEnter` arming boolean; `crankAccu` reset in `entered()`; single crank API (`getCrankTicks(4)`, CR-01); headless test feeds tick+B sequences | **Mitigated in design**; device confirmation → quickstart Scenario 9 |
| R-33 | Thumbnail render cost: 12 × (tilemap render + `scaledImage`) on `entered()` could blow one frame (Spec 010 R6 precedent) | Build once on `entered()`; rebuild only the 2 swapped indices per reorder, drop-one on delete; measure on device before committing to full-frame renders (R11) | **Open** — owner: Merlin (device), trigger: Phase B device test |
| R-34 | Overlay layout bug hides content or two elements collide | Pure anchor/region functions; SC-008 headless gate over all cursor rows + picker-visible case; `UndoPrompt` kept on its own layer | **Mitigated in design** |
| R-30↻ | Spec 011 undo history points at wrong frame after a multi-position reorder | Reorder is *only* adjacent swaps, each with `onFramesReindexed({swapped})`; no `remove+insert`, no new payload | **Closed by design** |

**Security-relevant architecture**: **N/A (confirmed).** Local UI/room restructuring only — no network, no secrets, no persistence change, no new attack surface. secure-architecture preset **not applied**. Re-evaluation trigger: if Frame Room or overlay state is ever persisted or configured externally.

**Architektur-Review (T089, 2026-09-06 — nach der Implementierung):** Modulschnitt geprueft. `Source/FrameManagementView.lua` importiert weiterhin **nur** `CoreLibs/graphics`, `CoreLibs/ui`, `LayerModel` — **kein** `import "EditorRoom"`; alle `EditorRoom`-Vorkommen sind Kommentare, die Kopplung laeuft ausschliesslich ueber die per `init` durchgereichte `editorRoom`-Referenz (`onFramesReindexed`, `recordDeleteFrame`). Der Room liest im `update()` **genau eine** Crank-API (`playdate.getCrankTicks(4)`), nie `getCrankChange()` — CR-01/AD-047 gewahrt. `Bauchbinde:drawBottom(text, side, screenW, screenH)` hat die unveraenderte 4-Argument-Signatur (`SelectionRoom.lua:456` unberuehrt). Das Frame-Raster nutzt die SDK-Primitive `playdate.ui.gridview` (wie `SelectionRoom`/`PixelRoom`), kein Eigenbau. `ADR-048` war bereits von Spec 011 belegt → die neuen ADRs sind **ADR-049** (Frame-Room) und **ADR-049** (Overlay-Leiste), Kap. 9 §9.37/§9.37. **Keine Contract-Verletzung.**

**Audit Evidence Applicability (Eighth Round, plan level)** — updated after `/speckit-implement` (2026-09-06):

| Checkpoint | Status | Evidence / rationale / follow-up |
|---|---|---|
| arc42 Kap. 2 — Randbedingungen | **N/A** | No new platform capability or input primitive; gestures reuse the occupied B+Crank channel |
| arc42 Kap. 3 — Kontextabgrenzung | **N/A** | No new external interface |
| arc42 Kap. 4 — Lösungsstrategie | **Done (T081)** | `arc42/04` → „Spec 010 — 8./9. Runde" (2 Leitentscheidungen) |
| arc42 Kap. 5 — Bausteinsicht | **Done (T082)** | `arc42/05` → FrameManagementView-/Bauchbinde-/EditorRoom-Zeilen aktualisiert |
| arc42 Kap. 6 — Laufzeitsicht | **Done (T083)** | `arc42/06` §6.17 + §6.18; älterer Rückstand über §6.3/§6.14/§6.15 + T-08 (Kap. 11) abgedeckt |
| arc42 Kap. 7 — Verteilungssicht | **Done (N/A dokumentiert, T084)** | `arc42/07` → „keine Änderung an dieser Sicht" |
| arc42 Kap. 8 — Querschnittliche Konzepte | **Done (T085)** | `arc42/08` → Overlay-Konzept + Arming-Gesten-Konzept |
| arc42 Kap. 9 — Architekturentscheidungen (+ `adr/`) | **Done (T086/T087)** | §9.36 AD-048 + `ADR-048-Frame-Verwaltung-persistenter-Room.md`; §9.37 AD-049 + `ADR-049-Konsolidierte-Overlay-Leiste.md` (ADR-047 war Spec 011) |
| arc42 Kap. 10 — Qualitätsanforderungen | **Done (T088)** | `arc42/10` → QS-24/QS-25/QS-26 |
| arc42 Kap. 11 — Risiken & technische Schulden | **Done (T089)** | `arc42/11` §11.8 → R-32/R-33/R-34 + T-08 |
| Secure-Architecture-Preset (iSAQB) | **N/A (confirmed, T095)** | Local UI/room only; no network/secrets/persistence/attack surface |
| Architektur-Review | **Done (T089/T090)** | Notiz oben („Architektur-Review (T089 …)"): kein `import "EditorRoom"`, eine Crank-API, `drawBottom`-Signatur, `gridview` = SDK |
| Constitution V — Gate 1 (headless) | **Done (T091)** | „ALLE TESTS BESTANDEN", 577 OK; neue Sektionen + V9/V23b/F4/V21 umgestellt |
| Constitution V — Gate 2 (`buildNumber` +1, `pdc`) | **Done (T092)** | `buildNumber` 37→38→39→40; `pdc` exit 0 je Phase |
| Manual Simulator / Hardware integration | **Open** | Owner: Merlin (T093/T094). quickstart Scenario 4 + 8; Gerät: `thumbCache`-FPS (R-33), kein Fehl-Exit (R-32), SC-008 visuell. Endwerte in ADR-048/ADR-049 |
| `docs/architecture/` evidence path | **Done (convention)** | Satisfied via `arc42/` per Constitution III |

### Spec refinements surfaced during planning — RESOLVED (Ninth Round, `/speckit-clarify` 2026-09-06)

Planning found two points the spec left implicit; both are now **in `spec.md`** (Ninth Round), so spec and plan agree:

1. **`FR-022` — exit gesture arming.** Resolution folded in: the exit is evaluated only after B has been released once since entering (`bReleasedSinceEnter`); `spec.md` FR-022 + Edge Case "Frame Room exit vs. entry residual".
2. **`FR-021` — "Up/Down by one grid row".** Resolution folded in: a row move is `numColumns` sequential adjacent moves, each firing `onFramesReindexed({swapped})`; `spec.md` FR-021 + the "Reordering at the Ends" edge case.

New from the Ninth Round (control alignment to `SelectionRoom`): delete + duplicate on the system menu with the reused confirm dialog; A is a mark/unmark toggle; `movedSinceMark` dropped; a `{ inserted }` `remapFrames` payload for duplicate is a task-level detail.

### Complexity Tracking (Eighth Round)

*No Constitution violations — table stays empty. The round is a net reduction in state (removes the B-hold/B-release lifecycle) and a reuse of existing patterns (`gridview`, `swapFrames`, `onFramesReindexed`).*

### Phase C artifacts

```text
arc42/04-loesungsstrategie.md          # MOD: 2 Leitentscheidungen
arc42/05-bausteinsicht.md              # MOD: FrameManagementView lifecycle + gridview; Bauchbinde anchor
arc42/06-laufzeitsicht.md              # MOD: Spec-010 backfill + Eighth-Round sequences
arc42/07-verteilungssicht.md           # MOD: one line — Eighth Round = N/A (no deployment change)
arc42/08-querschnittliche-konzepte.md  # MOD: overlay + gesture concepts
arc42/09-architekturentscheidungen.md  # MOD: §9.36 ADR-048, §9.37 ADR-049
arc42/10-qualitaetsanforderungen.md    # MOD: SC-008 + thumbnail perf + deterministic exit
arc42/11-risiken-und-technische-schulden.md  # MOD: R-32, R-33, R-34
arc42/adr/ADR-048-Frame-Verwaltung-persistenter-Room.md   # NEW
arc42/adr/ADR-049-Konsolidierte-Overlay-Leiste.md         # NEW
```

### Next Steps (Eighth Round)

`/speckit-tasks` (on Spec 010) → task list ordered **Phase A (overlay bar) → Phase B (Frame Room) → Phase C (arc42/ADR) → gates**, each phase ending in headless-green + `buildNumber` +1 + `pdc` + commit. Then `/speckit-implement`.

---

## Tenth-Round Update (2026-09-07) — Tile Picker: full revolution to open

**Trigger**: hardware testing of the shipped Eighth/Ninth-Round build (see `spec.md` → Clarifications, Tenth Round). The tile picker opened on the smallest crank movement (`if change ~= 0 then pickerVisible = true`), so incidental contact while docking/undocking the Crank kept popping the overlay over the artwork.

**Change** (`FR-025` / `SC-007` revised; scoped to `EditorRoom.handleCrank` no-B branch — B + Crank tick thresholds untouched):

- New signed accumulator `pickerArmDegrees`. While `not pickerVisible`, `pickerArmDegrees += getCrankChange()`; `math.abs(pickerArmDegrees) >= PICKER_ACTIVATE_DEGREES` (`360`) opens the picker (`pickerVisible = true`, both accumulators reset, `return`). Back-and-forth jiggle cancels toward 0 → never opens; a full turn in **either** direction opens (the picker has no crank indicator — unlike the direction-bound `SelectionRoom` 720° sync gesture). The opening revolution selects no tile.
- While `pickerVisible`, the unchanged `crankAccumDegrees` / `PICKER_DEGREES_PER_TILE` (`30`) stepping runs. Any `change ~= 0` refreshes `lastActivityMs` (label stays alive mid-gesture) and `pickerUntilMs`.
- `pickerArmDegrees` reset on: activation, the `pickerUntilMs` auto-hide, any `buttonIsPressed(kButtonB)` frame, `entered()`. After the auto-hide, another full revolution is needed to re-open.
- **CR-01 intact**: the no-B branch still uses only `getCrankChange()`.

**Constitution**: no violations — one added state field + one constant, reusing the `PixelRoom` rotation / `SelectionRoom` sync accumulator pattern. Principle V gates: `lua tests/headless_tests.lua` green (jiggle + partial-turn + full-turn assertions added; existing picker sections open via `openPickerWithFullTurn()`), `buildNumber` 40 → 41, `pdc` clean.

**Artifacts touched**: `Source/EditorRoom.lua`, `tests/headless_tests.lua`, `Source/pdxinfo`; `spec.md` (FR-025/SC-007/Clarifications), `research.md` (R10), `data-model.md`, `contracts/frame-room-and-overlay.md`, `quickstart.md` (Scenario 7 + Troubleshooting), `arc42/adr/ADR-042` (*Nachtrag 10. Runde*), `arc42/09-architekturentscheidungen.md` (§9.30 AD-042).

**Hardware follow-up (T094)**: a slow full turn opens reliably (no stutter from 0-degree frames); slow one-directional drift does **not** falsely open; the full crank turn triggers no false shake / undo prompt (Spec 011) while opening the picker.
