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
- **Phase 4** (T016–T024, US2 Transparenz in PixelRoom) ✅ — buildNumber 15 → 16.
- **Phase 5** (T025–T032, US3 Layer-Cycling in EditorRoom) ✅ — buildNumber 16 → 17.
- **Phase 3** (T010–T015, US1 Pixel-Shift in ZoomRoom) ✅ — buildNumber 17 → 18.
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

- [X] T010 [US1] `ZoomRoom:inputHandler` — Pfeil-`*ButtonDown` prüft `playdate.buttonIsPressed(kButtonB)`: mit B → `shiftActiveLayerContent(direction)` (statt Cursorbewegung), ohne B → `startDirectionHold` (unverändert). Ein Shift je Tastendruck (kein Auto-Repeat). File: `Source/ZoomRoom.lua`

- [X] T011 [US1] Visuelles Feedback: nach dem Shift `needsRedraw`/`backgroundDirty` → das Zoomraster wird sofort mit dem verschobenen Inhalt neu gezeichnet (frischer Kontext via `EditorRoom:currentZoomContext()`). Der Ebenen-Indikator (FR-015, Phase 5) zeigt weiterhin die aktive Ebene. Ein dedizierter „Shifting…“-Text wäre bei einer 1-Frame-Operation nicht sichtbar — weggelassen. 60-FPS-Profiling → T054.

### Pixel Shifting Algorithm

- [X] T012 [US1] ~~`Layer:shift` in `Source/Models/Layer.lua`~~ → **`LayerModel.shiftLayerContent(entry, active1, direction, getTile, registerTile)`**. Algorithmus: (1) 400×240-Pixelraster der Ebene aus den 375 Tiles als 3-Zustands-Codes dekodieren, (2) um 1 Pixel verschieben (**Wrap-Around** — nur so kein Datenverlust, spec.md Edge Case), (3) alle 375 Tiles neu bauen, (4) `layer.positions` neu setzen (Dedup über den vom EditorRoom injizierten `registerTile`). `EditorRoom:shiftActiveLayer` ist der Einstieg (kennt `imageData`/`activeLayer`/`imagetable`/`hashIndex`). File: `Source/LayerModel.lua` + `Source/EditorRoom.lua`

- [X] T013 [US1] Edge Cases in `shiftLayerContent`: (a) Wrap an Tile-Grenzen (Pixel wandern zwischen Zellen), (b) Modulo `% width`/`% height` verhindert Out-of-bounds, (c) In-Zell-Verschiebung erzeugt ein neues, dedupliziertes Tile, (d) leere/„absent“ obere Ebene: komplett transparent verschoben → Tiles fallen wieder auf `ABSENT` (0) zurück. File: `Source/LayerModel.lua`

### Persistence & Verification

- [X] T014 [P] [US1] `tests/headless_tests.lua` „LayerModel: shiftLayerContent verschiebt den Pixelinhalt um 1 Pixel“ (right/left/down + Wrap vom rechten Rand) und „EditorRoom: shiftActiveLayer wirkt nur auf die aktive Ebene + aktuellen Frame“ (Basisebene + Frame 2 unverändert, FR-004) + „ZoomRoom: B + Pfeiltaste löst den Shift aus“.

- [X] T015 [P] [US1] `tests/headless_tests.lua`: Save+Reload nach Shift — Ebenenstruktur (2 Ebenen, 375 Positionen, Basisebene unverändert) bleibt erhalten. **Pixel-genaue** Shift-Persistenz über den PDI-Sheet ist im Headless-Mock nicht prüfbar (`image:draw` ist überall No-op — gilt für alle Tests dieser Datei) → Simulator T058.

**Checkpoint**: US1 ✅ — headless-Tests grün; buildNumber 17 → 18; pdc grün. Commit folgt.

---

## Phase 4: User Story 2 - Transparency Support (Priority: P1)

**Goal**: Implement B-press transparency placement in Pixel View with persistence

**Independent Test** (from quickstart.md): Pixel View → place opaque (A) + transparent (B) + empty pixels → save/reload → transparency states persist, visually distinct (checkerboard)

### Transparency Placement (Pixel View)

- [X] T016 [US2] `PixelRoom:inputHandler` erhält `BButtonDown`/`BButtonUp` → `beginStroke("B")`. Malt `gridState[cell] = TRANSPARENT`. Kein `Layer:setPosition` — Transparenz lebt pro Pixel im 16×16-Tile (`kColorClear`), nicht in einem 375er-Array. File path: `Source/PixelRoom.lua`

- [X] T017 [US2] `gridView:drawCell` rendert TRANSPARENT-Zellen mit Schachbrett-`setPattern` (sichtbar verschieden von opak-schwarz und leer-weiß, FR-011). File path: `Source/PixelRoom.lua`

- [X] T018 [US2] ~~Y-Druck~~ → **Playdate-Hardware hat keine Y-Taste** (Plan-Artefakt-Fehler). A toggelt opak↔leer (Radierer, Spec 008), B setzt transparent. transparent→leer = A (→opak) + A (→leer). `buildTileImage`: OPAQUE→schwarz, TRANSPARENT→`kColorClear`, EMPTY→weiß. "Invert" tauscht nur opak↔leer. File path: `Source/PixelRoom.lua`

### Transparency State Encoding

- [X] T019 [P] [US2] `Source/PixelTransparency.lua` — `fromColor`/`toColor`/`sampleState` bilden Zustand↔`gfx.kColor*` ab (Phase 2). Kein `Layer:setPosition`.

- [X] T020 [P] [US2] ~~`Layer:getTransparencyAt` / atomares position+transparency-Update~~ → **N/A**: kein per-Zelle-Transparenz-Array. Transparenz ist Teil des Tile-Bitmaps und damit per Definition atomar mit dem Tile.

### Backward Compatibility

- [X] T021 [US2] Erledigt in Phase 2: `newLoadOperation` — v1.0-Bilder (flache Frames, keine Transparenz) laden als eine Basisebene, alle Pixel opak (schwarz/weiß). Test „v1.0-Bild lädt als einzelne opake Ebene“.

- [X] T022 [US2] Erledigt in Phase 2: Test „v1.0-Bild lädt … Re-Save schreibt v1.1“.

### Persistence & Verification

- [X] T023 [P] [US2] `tests/headless_tests.lua` „PixelRoom: transparenter Strich + Ruecklesen aus dem Tile“: B-Strich → `buildTileImage` erzeugt `kColorClear`-Pixel; `setCurrentTile` liest sie als TRANSPARENT zurück; 3-Zustands-`hashTile` dedupliziert opak vs. transparent getrennt. Voller PixelRoom→ZoomRoom→EditorRoom→Save→Reload-Bilddurchlauf für einen Einzelpixel: Simulator (T057).

- [X] T024 [P] [US2] `tests/headless_tests.lua` „leer -> A -> opak -> B -> transparent (Zyklus)“ + A-auf-opak→leer + A-auf-transparent→opak.

**Checkpoint**: US2 ✅ — headless-Tests grün; buildNumber 15 → 16; pdc grün. Commit folgt.

---

## Phase 5: User Story 3 - Layer Cycling with Crank Control (Priority: P1)

**Goal**: Implement Up/Down + Crank layer cycling in Tile View (max 3 layers per frame), preserving existing frame cycling

**3-Layer Constraint**: Layer cycling guaranteed to be bounded (Layer 1 → 2 → 3 → wrap back to 1). No dynamic max needed.

**Independent Test** (from quickstart.md): Frame with 3 layers → Tile View → hold Up + Crank forward → Layer 1→2→3→1 (max 3), release Up → Crank cycles frames instead

> **Hinweis Doppel-IDs**: T025–T032 stehen zweimal in dieser Datei (zwei
> unterschiedliche Formulierungen). Beide Blöcke beschreiben dasselbe US3-
> Feature und sind mit einer gemeinsamen Umsetzung erledigt. Alle „TileView“ =
> `Source/EditorRoom.lua`. „Frame:setActiveLayer“ = `imageData.activeLayer`
> (1-basierter Sitzungsindex) + `LayerModel.cycleActive/clampActive`.

### Layer Cycling Implementation (Bounded to 3 Layers) — erledigt

- [X] T025 (beide Fassungen) [US3] `EditorRoom.handleCrank`: bei gehaltener **Up**-Taste zyklt die volle 360°-Umdrehung die aktive Ebene vorwärts (`cycleActiveLayer(+1)`), bei **Down** rückwärts (`cycleActiveLayer(-1)`); die Kurbelrichtung ist dabei egal (Taste bestimmt die Richtung). Ohne Up/Down bleibt es beim Frame-Cyclen (FR-016). Eigener `layerAccumDegrees`-Akkumulator; der Frame-Akku läuft dann nicht mit. File: `Source/EditorRoom.lua`

- [X] T026 (beide Fassungen) [US3] Down + Crank rückwärts: siehe T025 (`downHeld` → `delta = -1`). Wrap in beide Richtungen über `LayerModel.cycleActive` (Modulo 1..count, FR-017). File: `Source/EditorRoom.lua`

- [X] T027 (beide Fassungen) [US3] Ebenen-Indikator: `EditorRoom:getActiveLayerInfo()` → `{index, count, name}`; `draw()` hängt bei `count > 1` `„ L<idx>/<count> <name>“` an die Frame-Bauchbinde (FR-015). Bei Ein-Ebenen-Bildern unverändert nur „Frame x/y“. File: `Source/EditorRoom.lua`

- [X] T028 (beide Fassungen) [P] [US3] Compositing: bereits durch die EditorRoom-Verdrahtung — `imageData.frames[f]` ist das per `LayerModel.compositeToFlat` gestapelte flache Array (oberste beitragende Ebene je Zelle gewinnt), das die Tilemap zeichnet. Pixelgenaue Überblendung mehrerer Ebenen in EINER Zelle: `LayerModel.compositeToTiles` steht bereit (noch nicht im Renderpfad verdrahtet — Polish/T053; für die aktuelle „oberste Ebene gewinnt je Zelle“-Darstellung nicht nötig).

### Layer State Management — erledigt

- [X] T029 (beide Fassungen) [P] [US3] `LayerModel.clampActive(entry, i)` erzwingt `i ∈ 1..count`, sonst Wrap auf 1 (R4). `LayerModel.cycleActive` verhindert Out-of-bounds. Nur die aktive Ebene ist editierbar (`buildZoomContext`/`applyTileEdits` in der Verdrahtung). File: `Source/LayerModel.lua`, `Source/EditorRoom.lua`

- [X] T030 (beide Fassungen) [US3] Frame-Wechsel (`tickForward`/`tickBackward`/`deleteCurrentFrame`) klemmt `imageData.activeLayer` per `LayerModel.clampActive` gegen die Ebenenzahl des Ziel-Frames — hat Frame 2 weniger Ebenen als der aktive Index, Wrap auf 1 (AS3). File: `Source/EditorRoom.lua`

- [X] T031 (beide Fassungen) [US3] `activeLayer` ist **bewusst Sitzungszustand, nicht persistiert** (Abweichung von der Task-Formulierung — siehe Implementation Notes / contracts kennen kein `activeLayerIndex`). Beim Laden immer `activeLayer = 1`. Der Ebenen-INHALT (positions je Ebene) persistiert vollständig über v1.1 (Phase 2, Test „v1.1 Round-Trip“).

- [X] T032 (beide Fassungen) [P] [US3] `tests/headless_tests.lua`: „Up/Down + Crank zyklt die aktive Ebene mit Wrap“, „Crank ohne Up/Down zyklt weiterhin Frames“, „aktiver Ebenenindex überlebt Frame-Wechsel mit Wrap“.

**Checkpoint**: US3 ✅ — headless-Tests grün; buildNumber 16 → 17; pdc grün. 60-FPS-Compositing-Profiling → T053 (Simulator/Gerät). Commit folgt.

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

