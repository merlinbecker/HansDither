# Tasks: Layer Management, Precise Pixel Shifting & Transparency Support

**Input**: Implementation plan from `/specs/010-layer-management-with-transparency/plan.md`

---

## Implementation Notes (Übernahme durch Claude Code, 2026-08-31)

Der vorherige Agent (GitHub Copilot) hat Phase 2 mitten im Umbau abgebrochen
(`Source/LayerUtils.lua` + `Source/PixelTransparency.lua` neu, `ImageStoreCodec.lua`
halb migriert → 6 vorher grüne Tests rot). Zustand zurückgesetzt auf HEAD, dann
sauber neu aufgebaut. Wesentliche **Abweichungen von plan.md/tasks.md/contracts**
(Plan/Contracts wurden vor Kenntnis der echten Dateien geschrieben):

- **Kein `Source/Models/`- oder `Source/Rooms/`-Verzeichnis.** Reale Dateien flach
  in `Source/`. Zuordnung: „Tile View“ = `EditorRoom.lua`, „Zoom View“ =
  `ZoomRoom.lua`, „Pixel View“ = `PixelRoom.lua`.
- **Layer-Datenmodell** als reine Lua-Tabellen-Helfer in `Source/LayerModel.lua`
  (global `LayerModel`) statt Klassen mit Gettern/Settern. Frame-Layer-Entry:
  `{duration, layers = {{layerIndex, name, positions[375], visible}, ...}}`.
  Laufzeit-Indizierung 1-basiert (`layers[1..3]`), `layerIndex`-Feld 0-basiert
  (Contract). Aktive Ebene = reiner Editor-Sitzungszustand (`imageData.activeLayer`,
  1-basiert), **nicht** persistiert.
- **Transparenz pro Pixel, nicht pro Zelle** (Nutzer-Klarstellung: wird nur im
  PixelRoom gesetzt). Es gibt **kein** 375er `transparency`-Array je Layer wie in
  data-model.md/contracts/save-format.md skizziert. Transparente Pixel leben als
  `gfx.kColorClear` direkt im 16×16-Tile und werden über einen **3-Zustands-
  `hashTile()`** (schwarz/weiß/transparent) getrennt dedupliziert — genau das,
  was spec.md Edge Case Zeile 104 fordert. → data-model.md + contracts sind
  entsprechend zu aktualisieren (Phase 7, T049–T052-Umfeld).
- **`ImageStoreCodec.newSaveOperation` / `newLoadOperation`** sind „Image:saveJSON /
  loadJSON“ (T007/T008) — Coroutine-basiert über `playdate.datastore`.
- **`pruneUnusedTilesLayered`** (T009) bereinigt **global über alle Ebenen aller
  Frames**, nicht per `layerIndex` — per-Ebene-Prune wäre gegen die gemeinsame
  Imagetable unsound. Flaches `pruneUnusedTiles` bleibt für die Spec-009-Tests.
- **Doppelte Task-IDs T025–T032** (Zeilen ~163–181 *und* ~185–203, unterschiedlicher
  Inhalt) — beim Abhaken wird die jeweils gemeinte Zeile mitgenannt.

**Gates je abgeschlossener Phase**: `lua tests/headless_tests.lua` → „ALLE TESTS
BESTANDEN“ + `buildNumber` +1 + `pdc Source "Hans Dither.pdx"` grün + Commit.

**Fortschritt:**
- **Phase 2** (T001–T009, Datenmodell + Speicherformat v1.1) ✅ — buildNumber 13 → 14, commit `64434ea`.
- **Phase 2b/3-Vorarbeit** (EditorRoom-Ebenen-Verdrahtung) ✅ — buildNumber 14 → 15.
  Nicht als nummerierte Task in tasks.md, aber Voraussetzung für US1/US3: alle
  Editier-Pfade des EditorRoom (`setCell`, `beginStroke`, `applyTileEdits`,
  `tickForward`/`tickBackward`, `clearCurrentFrame`, `buildZoomContext`) wirken
  jetzt auf `imageData.frameLayers[currentFrame].layers[activeLayer]`;
  `imageData.frames` ist ein nach jeder Mutation neu kompositierter flacher
  Cache. `tickForward` nutzt `LayerModel.cloneFrameLayers` (tiefe Kopie aller
  Ebenen). „clear screen“ leert nur die aktive Ebene. Test: 2-Ebenen-Frame →
  Edit auf Ebene 2 → Save → Reload → Edit auf Ebene 2, Ebene 1 unberührt.
- **Phase 3** (T010–T015, US1 Pixel-Shift in ZoomRoom) — offen.
- **Phase 4** (T016–T024, US2 Transparenz in PixelRoom) — offen.
- **Phase 5** (T025–T032, US3 Layer-Cycling in EditorRoom) — offen.
- **Phase 6** (T033–T043, US4 Management-Views) — offen.
- **Phase 7** (T044–T059, Polish/Gates/arc42) — offen.

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Headless tests in `tests/headless_tests.lua` + Constitution V build gate (mandatory, non-negotiable)

**Organization**: Tasks grouped by user story (US1–US4, P1–P2) with parallel execution opportunities marked. Each story is independently testable and deployable.

---

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Parallelizable (different files, no blocking dependencies within same story)
- **[Story]**: User story label (US1–US4) — setup/foundational phases have NO story label
- **File paths**: Absolute paths to files being created/modified
- **Checklist**: Every task is an item in markdown checkbox list

---

## Implementation Strategy

**MVP Scope** (Minimum Viable Product):
- US1 (P1): Pixel Shifting → Small feature, high value, enables advanced editing
- US2 (P1): Transparency → Small feature, high value, enables modern pixel art
- US3 (P1): Layer Cycling → Core feature, essential for workflow
- **US4 (P2)**: Deferred to post-MVP (management view adds complexity, lower immediate value)

**Phasing**:
- **Phase 1**: Setup — project initialization, no code changes yet
- **Phase 2**: Foundational — data model + storage format (blocks all stories)
- **Phase 3**: US1 (Pixel Shifting) — Zoom View control + tile recalculation
- **Phase 4**: US2 (Transparency) — Pixel View B-press + transparency state
- **Phase 5**: US3 (Layer Cycling) — Crank control + layer indicator
- **Phase 6**: US4 (Management View) — Layer/Frame management UI
- **Phase 7**: Polish — tests, documentation, arc42 updates, build gates

**Dependencies**: Phase 2 (Foundational) must complete before any user story. US1, US2, US3 are largely independent (can parallelize within Phase 3+). US4 depends on US3 concepts but can start after US3 UI hooks are defined.

---

## Phase 1: Setup

**Goal**: Establish project structure and framework for all phases

**No tasks in Phase 1**: No new structure needed (existing Room architecture, no new directories)

**Rationale** (Constitution IV, Simplicity): Reuse existing patterns (TileView, ZoomView, PixelView, ImageStore). No Setup tasks required.

---

## Phase 2: Foundational (Data Model & Storage)

**Goal**: Implement core data structures and storage layer (blocks all user stories)

**Key Constraint**: **3-layer maximum per frame (hard limit)** — Layer 1 mandatory, Layers 2–3 optional

**Independent Test**: Save image with 2–3 layers + transparency → close app → reopen → verify all layer/transparency data intact + layer count never exceeds 3

### Data Model Implementation (3-Layer Architecture)

- [X] T001 ~~Create Layer model in `Source/Models/Layer.lua`~~ → **`Source/LayerModel.lua`** (global `LayerModel`, flat-table helpers). `newLayer(index0,name)`, `newFrameLayersFromFlat`, `cloneFrameLayers`, `validate` (layerIndex 0..2, 375 positions), `compositeToFlat`/`compositeAt`. Kein `transparency`-Array (Transparenz pro Pixel im Tile). `setPosition` entfällt — Positionen werden direkt in `layer.positions[cell]` geschrieben (wie im übrigen Code).

- [X] T002 [P] ~~Extend Frame model in `Source/Models/ImageStore.lua`~~ → Frame-Layer-Methoden in **`Source/LayerModel.lua`**: `addLayer(entry,name)` (≤3, sonst `max-layers-reached`), `deleteLayer(entry,active1)` (Ebene 1 geschützt, reindiziert), `layerCount`, `getLayer`, `clampActive`, `cycleActive`. `ImageStore.createImage` (`Source/ImageStore.lua`) setzt jetzt `frameLayers` + `activeLayer`. Rückwärtskompatibel: `newLoadOperation` upgradet flache Frames zu 1-Ebenen-Frames.

- [X] T003 [P] Create PixelTransparency utility module in `Source/PixelTransparency.lua`. `encode(state)→0|1|2`, `decode(byte)→"opaque"|"transparent"|"empty"`, `isTransparent/isOpaque/isEmpty`, `sanitize` (klemmt auf [0,1,2], sonst opaque). Zusätzlich Pixel↔Farbe-Brücke: `fromColor`/`toColor`/`sampleState` (opaque=black, transparent=clear, empty=white).

- [X] T004 [P] ~~Create PixelState model in `Source/Models/PixelState.lua`~~ → gefaltet in **`Source/PixelTransparency.lua`** (`fromColor`/`toColor`/`sampleState` bilden die Zustandsübergänge Empty↔Opaque↔Transparent auf gfx-Farben ab). Ein separates PixelState-Modul wäre ein dünner Wrapper (kein `Models/`-Verzeichnis). Die eigentlichen A-/B-/Y-Übergänge im PixelRoom → Phase 4.

### Storage Format Extension (JSON v1.1, 3-Layer Bounded)

- [X] T005 `ImageStoreCodec.createFramesTableV11(name, frameLayers, tileCount)` + `newSaveOperation`-Umbau: schreibt v1.1-Schema `{version="1.1", frames[].{ frameIndex, duration, layers[].{layerIndex, name, positions, visible} }}`. Validierung: 375-Positions-Invariante + Ebenenzahl 1–3, ungültige Frames verworfen. **Kein** per-Zelle `transparency`-Array (Transparenz pro Pixel im Tile, 3-Zustands-`hashTile`). File path: `Source/ImageStoreCodec.lua`

- [X] T006 `ImageStoreCodec.newLoadOperation`: erkennt v1.1 (verschachtelt) vs. v1.0 (flach) an der **Struktur des ersten Frames**, nicht am version-Feld (robuster, FR-010). v1.0→v1.1-Auto-Upgrade (eine Basisebene „Layer 1“, alle Pixel opak). Ebenenzahl beim Laden auf 3 begrenzt. Liefert `imageData.frameLayers` + `imageData.frames` (kompositiert) + `activeLayer=1`. File path: `Source/ImageStoreCodec.lua`

- [X] T007 [P] ~~ImageStore:loadJSON~~ → **ist** `ImageStoreCodec.newLoadOperation` (Coroutine über `playdate.datastore`). Schema-Validierung + Fehlerbehandlung für kaputtes JSON (Fallback: 1 weißer Frame) + `#layers > 3` wird abgeschnitten. Getestet: `headless_tests.lua` „v1.1 Round-Trip“, „v1.0-Bild lädt als einzelne opake Ebene“, „Laden erzwingt das 3-Layer-Limit“.

- [X] T008 [P] ~~ImageStore:saveJSON~~ → **ist** `ImageStoreCodec.newSaveOperation`. Atomizität über `playdate.datastore.write` (SDK). Pre-Save-Invarianten in `createFramesTableV11` (375, Ebenenzahl) + `pruneUnusedTilesLayered`. Getestet über den v1.1-Round-Trip.

### Tile Recalculation (Spec 009 Integration)

- [X] T009 ~~`pruneUnusedTiles()` um `layerIndex` erweitern, per-Ebene prunen~~ → **`pruneUnusedTilesLayered(imagetable, frameLayers, tileCount)`**: prunt **global über alle Ebenen aller Frames** (per-Ebene wäre gegen die geteilte Imagetable unsound). Remappt jede `layer.positions` (0 „absent“ bleibt 0), liefert `(newImagetable, newFrameLayers, newTileCount)`. Flaches `pruneUnusedTiles` bleibt unverändert für die Spec-009-Tests. File path: `Source/ImageStoreCodec.lua`

**Checkpoint**: Phase 2 complete when images can be saved/loaded with 1–3 layers + transparency, v1.0 images auto-upgrade to Layer 1, and layer count validation prevents > 3 layers

---

## Phase 3: User Story 1 - Precise Pixel Shifting (Priority: P1)

**Goal**: Implement B + arrow key pixel shifting in Zoom View with automatic tile recalculation

**Independent Test** (from quickstart.md): Load image → Zoom View → hold B + Up arrow → content shifts up 1px, tiles recalculated → save/reload → shift persists

### Control Binding (Zoom View)

- [ ] T010 [US1] Modify ZoomView.update() to detect B-press + arrow key combination. When B held and directional key pressed (Up/Down/Left/Right), call Layer:shift(direction). File path: `Source/Rooms/ZoomView.lua`

- [ ] T011 [US1] Implement visual feedback during shift: display indicator "Shifting..." or highlight active layer in HUD. Maintain framerate (60 FPS). File path: `Source/Rooms/ZoomView.lua`

### Pixel Shifting Algorithm

- [ ] T012 [US1] Implement Layer:shift(direction) method in `Source/Models/Layer.lua`. Algorithm: (1) Extract all pixels from current layer positions + transparency, (2) Shift pixel buffer by 1 pixel in direction (wrap or clamp at boundaries per spec), (3) Re-tile via ImageStoreCodec.pruneUnusedTiles(layerIndex), (4) Update layer.positions + layer.transparency with new tile indices + transparency states. File path: `Source/Models/Layer.lua`

- [ ] T013 [US1] Handle shift edge cases in Layer:shift(): (a) Wraparound behavior at tile boundaries, (b) Clamping to prevent out-of-bounds, (c) Preserve tile references when content shifts within a single tile, (d) Degenerate case: empty layer (no shift needed, return unchanged). File path: `Source/Models/Layer.lua`

### Persistence & Verification

- [ ] T014 [P] [US1] Add test case to `tests/headless_tests.lua` section "ImageStoreCodec: Pixel Shifting (Spec 010, US1)": Create 3-layer frame, draw content in Layer 1, call Layer:shift("up"), verify all pixels moved up 1px, verify tiles recalculated, verify other layers unchanged. Test both directions (up, down, left, right)

- [ ] T015 [P] [US1] Add round-trip test: shift content → save image → reload → verify shift persists, pixel positions identical to pre-save state. Test via ImageStore:saveJSON() + loadJSON()

**Checkpoint**: US1 complete when all tests pass + pdc build succeeds + buildNumber incremented

---

## Phase 4: User Story 2 - Transparency Support (Priority: P1)

**Goal**: Implement B-press transparency placement in Pixel View with persistence

**Independent Test** (from quickstart.md): Pixel View → place opaque (A) + transparent (B) + empty pixels → save/reload → transparency states persist, visually distinct (checkerboard)

### Transparency Placement (Pixel View)

- [ ] T016 [US2] Modify PixelView.update() to detect B-press (in addition to existing A-press for opaque). When B pressed at cursor position, call Layer:setPosition(pos, tileIndex, 1) [transparency=1 for transparent]. File path: `Source/Rooms/PixelView.lua`

- [ ] T017 [US2] Implement visual feedback in Pixel View: render transparent pixels with checkerboard pattern (distinct from opaque black or empty white). Update PixelView.draw() to check transparency state before rendering. File path: `Source/Rooms/PixelView.lua`

- [ ] T018 [US2] Extend PixelView delete action (Y-press) to set transparency = 2 (empty state). Add three-state cycle: A-press (opaque=0) → overwrite → B-press (transparent=1) → overwrite → Y-press (empty=2). File path: `Source/Rooms/PixelView.lua`

### Transparency State Encoding

- [ ] T019 [P] [US2] Update PixelTransparency module to correctly encode/decode transparency in Layer:setPosition(). When transparency=1, mark pixel as see-through (no blending needed, just metadata). File path: `Source/PixelTransparency.lua`

- [ ] T020 [P] [US2] Modify Layer:getTransparencyAt(index) to return correct state. Update Layer:setPosition() to atomically update both position AND transparency array (guarantee 1-to-1 mapping). File path: `Source/Models/Layer.lua`

### Backward Compatibility

- [ ] T021 [US2] Test v1.0 image load: old images (no transparency array) should load with all pixels as opaque (transparency=0). Verify ImageStoreCodec:load() sets transparency array to all zeros if missing. File path: `Source/ImageStoreCodec.lua`

- [ ] T022 [US2] Add test case to `tests/headless_tests.lua`: "Transparency: backward compatibility (v1.0 → v1.1 auto-upgrade)". Load v1.0 JSON, verify all pixels opaque, save, verify v1.1 format written. File path: `tests/headless_tests.lua`

### Persistence & Verification

- [ ] T023 [P] [US2] Add test case to `tests/headless_tests.lua`: "Transparency: place transparent pixel, save, reload, verify transparent state persists". Test round-trip: Pixel View B-press → save → close → reopen → checkerboard still visible. File path: `tests/headless_tests.lua`

- [ ] T024 [P] [US2] Add test case: "Transparency: three-state cycle (opaque → transparent → empty)". Place opaque, verify black. Press B, verify checkerboard. Press Y, verify empty (white). Repeat 3x, verify correct transitions. File path: `tests/headless_tests.lua`

**Checkpoint**: US2 complete when all tests pass + pdc build succeeds + buildNumber incremented

---

## Phase 5: User Story 3 - Layer Cycling with Crank Control (Priority: P1)

**Goal**: Implement Up/Down + Crank layer cycling in Tile View (max 3 layers per frame), preserving existing frame cycling

**3-Layer Constraint**: Layer cycling guaranteed to be bounded (Layer 1 → 2 → 3 → wrap back to 1). No dynamic max needed.

**Independent Test** (from quickstart.md): Frame with 3 layers → Tile View → hold Up + Crank forward → Layer 1→2→3→1 (max 3), release Up → Crank cycles frames instead

### Layer Cycling Implementation (Bounded to 3 Layers)

- [ ] T025 [US3] Modify TileView.update() to detect Up-press + Crank rotation combination. When Up held and Crank rotated clockwise, call Frame:setActiveLayer(activeLayerIndex + 1 % 3) [wraparound max 3]. File path: `Source/Rooms/TileView.lua`

- [ ] T026 [US3] Implement Down-press + Crank backward: When Down held and Crank rotated counterclockwise, call Frame:setActiveLayer((activeLayerIndex - 1 + 3) % 3) [wraparound max 3]. File path: `Source/Rooms/TileView.lua`

- [ ] T027 [US3] Implement visual layer indicator in Tile View HUD: display current layer index (e.g., "Layer 1/3") and layer name. Update only when activeLayerIndex changes. File path: `Source/Rooms/TileView.lua`

- [ ] T028 [P] [US3] Implement layer compositing in Tile View rendering: composite all visible layers (1–3 per frame) in index order (Layer 1 bottom → Layer 3 top). Use transparency info from each layer for alpha blending. Performance target: 60 FPS. File path: `Source/Rooms/TileView.lua`

### Layer State Management (3-Layer Frame Model)

- [ ] T029 [P] [US3] Implement Frame:setActiveLayer(index) validation: ensure index ∈ {0, 1, 2} for current frame layer count. **Prevent out-of-bounds access**. If index ≥ current layer count, wrap to 0 (per research.md R4). File path: `Source/Models/ImageStore.lua`

- [ ] T030 [P] [US3] Implement frame switching with layer index preservation: when switching frames, preserve activeLayerIndex. If new frame has fewer layers than activeLayerIndex, wrap to 0. Example: Frame 1 has 3 layers, Frame 2 has 1 layer, user was on Layer 2 → switch to Layer 0 (wrap). File path: `Source/Rooms/TileView.lua`

### Layer Indicator & Persistence

- [ ] T031 [US3] Implement layer persistence across frame switches: save activeLayerIndex in Frame model, restore on frame reload. Verify activeLayerIndex is part of Frame JSON serialization. File path: `Source/Models/ImageStore.lua` + `Source/ImageStoreCodec.lua`

- [ ] T032 [P] [US3] Add test cases to `tests/headless_tests.lua`: (1) Layer cycling forward/backward (max 3), (2) Frame switching with layer wrap-around, (3) Layer persistence on save/reload. Test via Frame:setActiveLayer() and Crank simulation. File path: `tests/headless_tests.lua`

**Checkpoint**: US3 complete when all tests pass + layer compositing renders correctly at 60 FPS + pdc build succeeds + buildNumber incremented

- [ ] T025 [US3] Modify TileView.update() Crank handler: detect held keys (playdate.buttonIsPressed). If Up held, layer forward (activeLayerIndex = (activeLayerIndex + 1) % frame:getLayerCount()). If Down held, layer backward with modulo. If neither, use existing frame cycling. File path: `Source/Rooms/TileView.lua`

- [ ] T026 [US3] Implement layer indicator in TileView.draw(): display current active layer (e.g., "Layer 2 / 3" or "Background"). Update indicator every frame to reflect activeLayerIndex. File path: `Source/Rooms/TileView.lua`

- [ ] T027 [US3] Handle layer persistence across frame switches: when user switches to new frame (Crank without Up/Down), preserve activeLayerIndex if it exists. If new frame has fewer layers, wrap to Layer 1 (per research.md R4). File path: `Source/Rooms/TileView.lua`

### Tile View Multi-Layer Rendering

- [ ] T028 [US3] Modify TileView.draw() to render all layers composited (Layer 0 bottom, Layer N-1 top) instead of single layer. Iterate frame:getLayerCount(), draw each layer's tiles via SDK imagetable:drawTile(). Render transparent pixels with alpha blending (see-through). File path: `Source/Rooms/TileView.lua`

- [ ] T029 [US3] Ensure only active layer is editable: when user enters Zoom/Pixel View, only activeLayer's content is editable. Other layers render as read-only background. File path: `Source/Rooms/TileView.lua`

### Verification & Testing

- [ ] T030 [P] [US3] Add test case to `tests/headless_tests.lua`: "Layer Cycling: forward + backward". Create frame with 3 layers, verify cycling forward (Layer 1→2→3→1) and backward (Layer 1→3→2→1). File path: `tests/headless_tests.lua`

- [ ] T031 [P] [US3] Add test case: "Layer Cycling: preserve index on frame switch". Frame 1 (3 layers) Layer 2 → Frame 2 (2 layers) → verify active Layer 2. Frame 2 (2 layers) Layer 2 → Frame 3 (1 layer) → verify active Layer 1 (wrap). File path: `tests/headless_tests.lua`

- [ ] T032 [P] [US3] Add test case: "Layer Cycling: frame cycling unchanged". Verify Crank alone (without Up/Down) still cycles frames (existing behavior preserved). File path: `tests/headless_tests.lua`

**Checkpoint**: US3 complete when all tests pass + pdc build succeeds + buildNumber incremented

---

## Phase 6: User Story 4 - Layer & Frame Management View (Priority: P2)

**Goal**: Implement dedicated Layer View + Animation Layer View for managing layers and frames

**3-Layer Constraint Context**: Layer deletion respects bounds (Layer 1 cannot be deleted, max 3 layers enforced)

**Independent Test** (from quickstart.md): Tile View → B + Crank backward → Layer View shows 3 layer entries (max 3) → try delete Layer 1 (rejected) → delete Layer 3 → Layer View shows 2 → B + Crank backward again → Animation Layer View shows frames

### Layer View Implementation (3-Layer Aware)

- [ ] T033 [US4] Create LayerView Room in `Source/Rooms/LayerView.lua`. Display all layers in current frame (1–3 entries) as entry list (similar to SelectionRoom pattern). Use D-Pad to navigate, A-press to select layer, B-press (on selected) to delete. File path: `Source/Rooms/LayerView.lua`

- [ ] T034 [US4] Implement LayerView.draw(): render layer entries with cursor highlight. Display layer name + index + layer count (e.g., "1: Background (1/3)"). File path: `Source/Rooms/LayerView.lua`

- [ ] T035 [US4] Implement LayerView.update(): handle D-Pad navigation through layers, A-press select, B-press delete. Call Frame:deleteLayer(selectedLayerIndex) when deleting. **Validation: prevent deletion of Layer 1 (mandatory base layer)**. Refresh view after deletion. File path: `Source/Rooms/LayerView.lua`

- [ ] T036 [US4] Implement layer deletion logic: when layer deleted, adjust activeLayerIndex if needed (if deleted layer was active, switch to previous layer or Layer 0). Verify remaining layer count never drops below 1 (Layer 1 mandatory). Invalidate tile cache. File path: `Source/Rooms/LayerView.lua`

### View Hierarchy Navigation

- [ ] T037 [US4] Modify TileView.update() to detect B-press + Crank backward combination. When detected, switchRoom(LayerView) with reference to current frame. File path: `Source/Rooms/TileView.lua`

- [ ] T038 [US4] Implement LayerView back navigation: when user releases B, switchRoom(TileView). Persist any layer deletions to frame. Verify frame now has 1–3 layers (never 0, never > 3). File path: `Source/Rooms/LayerView.lua`

### Animation Layer View (Frame-Level Management)

- [ ] T039 [US4] Create AnimationLayerView Room in `Source/Rooms/AnimationLayerView.lua`. Display all frames as entries (Frame 1, Frame 2, ..., Frame 12). Use D-Pad to navigate, A-press to drill down into Frame submenu. File path: `Source/Rooms/AnimationLayerView.lua`

- [ ] T040 [US4] Implement submenu for AnimationLayerView: when A-press on frame entry, show all layers in that frame (1–3 entries). Allow delete operations (subject to Layer 1 protection). File path: `Source/Rooms/AnimationLayerView.lua`

- [ ] T041 [US4] Modify LayerView to support progression to AnimationLayerView: when B + Crank backward from LayerView, switchRoom(AnimationLayerView). File path: `Source/Rooms/LayerView.lua`

### Verification & Testing (3-Layer Invariant)

- [ ] T042 [P] [US4] Add test case to `tests/headless_tests.lua`: "Layer Management: create + delete layers (bounded 1–3)". Add 3 layers to frame, delete Layer 2, verify frame:getLayerCount() == 2, verify remaining layers re-indexed, verify cannot exceed 3. File path: `tests/headless_tests.lua`

- [ ] T043 [P] [US4] Add test case: "Layer Management: Layer 1 cannot be deleted". Frame has 1–3 layers, attempt Frame:deleteLayer(0) → rejected. Verify frame:getLayerCount() unchanged. File path: `tests/headless_tests.lua`

**Checkpoint**: US4 complete when all tests pass + layer management respects 3-layer bounds + pdc build succeeds + buildNumber incremented

---

## Phase 7: Polish & Cross-Cutting Concerns

**Goal**: Testing, documentation, performance tuning, Constitution V gates

### Headless Test Suite (Constitution V Gate 1)

- [ ] T044 Run full test suite: `lua tests/headless_tests.lua`. All tests must pass. Output: "ALLE TESTS BESTANDEN". File path: `tests/headless_tests.lua`

- [ ] T045 Add comprehensive test section "Layer Management & Transparency (Spec 010, US1-US4)" to headless test suite. Include at least 15 test cases covering: pixel shifting (4 cases), transparency (4 cases), layer cycling (4 cases), management (3 cases). File path: `tests/headless_tests.lua`

- [ ] T046 Verify Constitution V Testpflicht compliance: every implementation task (T001–T043) has corresponding test coverage. No task without test. File path: `tests/headless_tests.lua`

### Build Gate (Constitution V Gate 2)

- [ ] T047 Increment buildNumber in `Source/pdxinfo` by 1 before each test run. Verify build: `pdc Source "Hans Dither.pdx"`. No errors. Repeat for every test cycle. File path: `Source/pdxinfo`

- [ ] T048 Final build gate: `pdc Source "Hans Dither.pdx"` must succeed, binary `Hans Dither.pdx` created, simulator can launch without crashes. File path: `Source/pdxinfo`

### arc42 Documentation Updates

- [ ] T049 Update arc42 Chapter 4 (Solution Strategy): add section "Layer Architecture & Pixel Transparency". Describe: per-frame layers, compositing strategy, transparency state model. File path: `arc42/01_introduction_and_goals.md` (or relevant chapter file)

- [ ] T050 Update arc42 Chapter 9 (Architecture Decisions): add ADR "Layer Rendering Order: Composite All Layers vs. Single Active Layer". Decision rationale: composite all layers (WYSIWYG), considered single-layer (simpler state). Include performance analysis. File path: `arc42/09_architecture_decisions.md`

- [ ] T051 Add ADR "Pixel Transparency Encoding: 3-State Model (opaque/transparent/empty)". Alternatives: single bit, separate alpha layer, blend modes. Chosen: 3-byte model for simplicity + SDK compatibility. File path: `arc42/09_architecture_decisions.md`

- [ ] T052 Add ADR "Layer Persistence on Frame Switch: Index Preservation + Wrap-Around". Decision: preserve activeLayerIndex, wrap if frame has fewer layers. Alternatives: reset to Layer 1, preserve by name. File path: `arc42/09_architecture_decisions.md`

### Performance Tuning

- [ ] T053 Profile Tile View rendering with 10+ layers: verify 60 FPS maintained. Measure frame time during compositing. Optimize if > 16ms per frame (60 FPS target). File path: `Source/Rooms/TileView.lua`

- [ ] T054 Profile Layer:shift() operation: verify pixel buffer + retiling completes within 1 frame (16ms). Optimize hot path if needed. File path: `Source/Models/Layer.lua`

- [ ] T055 Memory audit: verify layer structures (375-entry arrays × 12 frames × 10 layers) fit within Playdate RAM budget (~27 KB for typical use). No heap explosions. File path: `Source/Models/Layer.lua`

### Integration & End-to-End Testing

- [ ] T056 Manual integration test (quickstart.md Scenario 1): Load image with 3-layer frame in Simulator → Tile View → hold Up, rotate Crank → layer cycles forward → release, rotate Crank → frame cycles → verify layer index preserved across frame switches

- [ ] T057 Manual integration test (quickstart.md Scenario 2): Pixel View → A-press (opaque) + B-press (transparent) + Y-press (empty) → verify checkerboard rendering → save → reload → verify states persist

- [ ] T058 Manual integration test (quickstart.md Scenario 3): Zoom View → hold B + arrow keys → content shifts pixel-by-pixel → tiles recalculate → save → reload → shift persists

- [ ] T059 Manual integration test (quickstart.md Scenario 5): Load v1.0 image → verify auto-upgrade to v1.1 → save → verify transparency array created (all zeros)

---

## Task Dependencies & Parallel Execution

### Dependency Graph

```
Phase 2 (Foundational)
├── T001–T009: Data Model + Storage
│   (blocks all user stories)
│
├─ Phase 3 (US1: Pixel Shifting)
│  ├── T010–T013: Control + Algorithm
│  └── T014–T015: [P] Tests (can run in parallel)
│
├─ Phase 4 (US2: Transparency)
│  ├── T016–T020: Placement + Encoding
│  └── T021–T024: [P] Backward Compat + Tests
│
├─ Phase 5 (US3: Layer Cycling)
│  ├── T025–T029: Cycling + Rendering
│  └── T030–T032: [P] Tests
│
└─ Phase 6 (US4: Management View)
   ├── T033–T041: LayerView + AnimationLayerView
   └── T042–T043: [P] Tests
```

### Parallel Opportunities

**Phase 2**: T002–T003 parallelizable (Frame extension + PixelTransparency utility independent)
**Phase 3**: T014–T015 tests can run while T012–T013 implementation continues
**Phase 4**: T019–T020 encoding parallel to T016–T018 placement
**Phase 5**: T030–T032 tests parallel to main implementation
**Phase 6**: T042–T043 tests parallel to main implementation
**Phase 7**: T044–T055 can run in parallel (different concern areas)

**MVP Execution Order** (Phases 2–5 only, skip US4):
1. Phase 2: 1–2 weeks (data model + storage)
2. Phase 3 & 4 in parallel: 1–2 weeks each (pixel shift + transparency)
3. Phase 5: 1 week (layer cycling)
4. Phase 7 (partial): Tests + build gates (1 week)
**Total**: ~4–6 weeks for MVP (US1–US3)

---

## Verification Checklist

Each task completes when:
- [ ] Code written, formatted, no syntax errors
- [ ] Changes tested via headless test suite (`lua tests/headless_tests.lua`)
- [ ] Build succeeds: `pdc Source "Hans Dither.pdx"`
- [ ] buildNumber incremented after each test run
- [ ] Behavior matches spec acceptance criteria
- [ ] No regression in existing features (Spec 009 tile cleanup still works, existing Rooms unaffected)

---

## MVP Cutoff

**Minimum Viable Product** (US1–US3):
- ✅ Pixel shifting works (T001–T015)
- ✅ Transparency works (T001–T024)
- ✅ Layer cycling works (T001–T032)
- ❌ US4 (Management View) deferred to post-MVP (T033–T043)
- ✅ Constitution V gates pass (T044–T048)
- ✅ arc42 updated (T049–T052)

**MVP Release Criteria**:
- All Phase 2 tasks complete
- All Phase 3, 4, 5 tasks complete
- All tests pass (headless + build gate)
- arc42 updated (Chapter 4, Chapter 9)
- Manual quickstart tests (Scenarios 1–3, 5) passing

**Post-MVP Phase 6** (Layer Management View):
- US4 tasks (T033–T043) scheduled for next sprint after MVP release

---

**Status**: ✅ Tasks complete — Ready for implementation via agents or manual code

