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
- **Advisor-Fix** (Radierer auf oberen Ebenen → „absent“) ✅ — buildNumber 18 → 19.
- **Third Round** (Klarstellung durch alle Artefakte + Code) ✅ — feste 3 Ebenen, ebenenabhängiger „Nicht-Tinte“-Zustand, buildNumber 19 → 20.
- **Phase 6** (T033–T043, US4 Frame Management View) ✅ — buildNumber 20 → 21.
- **FMV-Sackgassen-Fix** (B-Timing beim Eintritt) ✅ — buildNumber 22 → 23.
- **Fourth Round — Tile-View-Steuerungs-Redesign** (aus dem Hardware-Test) ✅ — **B + Hoch/Runter = Ebene**, **B + Links/Rechts = Frame**, **freie Kurbel = Tile-Picker** (über die referenzierten Kacheln, ~30°/Kachel, Wrap, Auto-Ausblenden), Pipette meldet „Tile N picked“. B + Crank (Zoom / Frame-Verwaltung) unverändert. `layerAccumDegrees` entfernt, `crankAccumDegrees` als Picker-Akkumulator umgewidmet, `bNavConsumed` trennt B+D-Pad von der Pipette. Durch spec/research (R10)/quickstart (Szenario 7) + arc42 Ch.4/5/8/9 + **ADR-042** gezogen. buildNumber 23 → 24.
  - **Nacharbeit (Advisor + Konsolidierung):** `referencedTileIndices()` scannt jetzt die **Ebenen-Positionen** statt des Composite-Cache (verdeckte Kacheln bleiben wählbar) und ist die **gemeinsame faktische Quelle** mit `buildPauseMenuImage` (das die verdeckten Kacheln vorher in „Tiles: N“ unterzählte). `pickerList()` cacht das Ergebnis für den Picker (Invalidierung bei Tile-Mutation) und hängt den Abwahl-Slot (Index 1) an — nur dort, damit die Pause-Anzahl faktisch bleibt. Bugfix `stepTilePicker`: `(picked == 1) and nil or picked` ergibt in Lua immer `picked` → Kurbeln auf Kachel 1 setzte `activeTile = 1` statt `nil`. Alle Assertions grün, buildNumber → 27.
- **Fifth Round — PixelRoom: B malt nicht mehr** (aus dem Hardware-Test) ✅ — gemalt wird ausschließlich mit **A** (A-Druck auf Tinte radiert je aktiver Ebene nach weiß bzw. transparent — der ebenenabhängige „Nicht-Tinte“-Zustand war schon korrekt verdrahtet). `BButtonDown/Up` sind No-ops; **B + Kurbel zurück** (Zoom-Out, Contract PR-01) bleibt der einzige B-Pfad. Beseitigt zugleich den „stray“ transparenten Pixel, den die B-Halten-Zoom-Out-Geste beim Loslassen im Tile hinterließ. `beginStroke()` ohne `button`-Parameter, `strokeButton` entfernt. **FR-007** von „B setzt den Nicht-Tinte-Zustand“ auf „B malt nicht in Pixel View“ umformuliert. Durch spec (Clarifications 5. Runde, FR-007/008, US2, Edge Cases, Status)/research (R2, R8/R9)/quickstart (Szenario 2 + Checkliste)/data-model/contracts + arc42 Ch.5/9 + **ADR-040-Nachtrag** gezogen. Tests: „B-Tipp folgenlos“ statt „B malt transparent“ (obere + Basisebene), Radier-Strich startet via A auf Tinte; B+Crank-Zoom-Out-Regression um die BButtonDown-Geste erweitert (kein stray Pixel). 371 Assertions grün, buildNumber 27 → 28.
- **US1-Rework — Pixel-Verschiebung wirkt nur auf die Cursor-Zelle (aus dem Hardware-Test)** ✅ — zwei Rückmeldungen: (1) "das Verschieben ist zu inperformant" — Standalone-Messung: die Ganz-Ebenen-Verschiebung kostete ~192.000 `image:sample()`-Aufrufe + 375 `image.new()` PRO Tastendruck. (2) "es sollte nur der Tile verschoben werden, auf dem man sich befindet ... man kann ein Tile in ein benachbartes schieben, dort vorhandene Pixel werden ersetzt" — der Nutzer wählte beim Nachfragen "Inhalt wandert in den Nachbarn und bleibt". Neu `LayerModel.shiftTileContent(entry, active1, cellIdx, dir, getTile, registerTile)`: Ausgangszelle + der eine Nachbar in Schieberichtung bilden einen 2-Tile-Streifen, als Ganzes um 1px geschoben (abgewandte Nachbar-Kante fällt weg, KEIN Wrap; am Rasterrand nur die Zelle; obere Ebene komplett transparent → `absent`). `LayerModel.shiftLayerContent` + `decodeLayerGrid`/`materializeShiftedGrid`/`imageFromGrid` **entfernt**; die aufgeschobene Materialisierung (erster ADR-043-Entwurf: `pendingShift`/`flushLayerShift`/`buildZoomContext`-Synthese/`BButtonUp`/6 Flush-Aufrufstellen) **entfällt komplett** — eine 2-Tile-Operation (~2500 Ops) läuft synchron. `EditorRoom:shiftActiveLayer(direction, cellIdx)`, `recompositeCell` für die 1-2 Zellen. `ZoomRoom.shiftActiveLayerContent` reicht `slots[<Cursor-Slot>].frameIndexPos` durch, Zoom-Cursor bleibt stehen. Durch spec (US1-Narrativ + AS + FR-001/002/005, Edge Case, Architecture Governance, Risk Record, Status, SC-001)/research (R6-Nachtrag komplett neu)/quickstart (Szenario 3 neu + 3 Troubleshooting-Zeilen)/contracts + arc42 Ch.4/5/9 + **ADR-043** (umbenannt: `ADR-043-Pixel-Verschiebung-pro-Tile.md`, Historie-Abschnitt) gezogen. 5 Deferral-/Ganz-Screen-Testabschnitte durch per-Tile-Tests ersetzt. 394 Assertions grün, buildNumber 29 → 30, pdc sauber.
- **Phase 7** (T044–T059): Gates grün (T044–T048) ✅; arc42 Ch.4/Ch.5/Ch.8/Ch.9 + ADR-039..043 (T049–T052) ✅; T054 (Shift-Performance) durch die Umfangs-Einschränkung erledigt (~2500 Ops/Tastendruck statt ~192k), Geräte-Messung weiterhin offen; Simulator-Integrationstests (T053, T055–T059) **offen** (Gerät/Simulator).
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
- **Phase 4**: US2 (Transparency) — Pixel View per-layer non-ink state (A-press eraser; Fifth Round: B no longer paints)
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

- [X] T012 [US1] ~~`Layer:shift` in `Source/Models/Layer.lua`~~ → ~~`LayerModel.shiftLayerContent` (Ganz-Ebenen-Verschiebung, Wrap-Around)~~ **→ `LayerModel.shiftTileContent(entry, active1, cellIdx, direction, getTile, registerTile)`** (US1-Rework, siehe Fortschritt): verschiebt nur Zelle `cellIdx` + den einen Nachbarn in Schieberichtung als 2-Tile-Streifen, KEIN Wrap. `EditorRoom:shiftActiveLayer(direction, cellIdx)` ist der Einstieg. File: `Source/LayerModel.lua` + `Source/EditorRoom.lua`

- [X] T013 [US1] Edge Cases in `shiftTileContent` (US1-Rework — Wrap entfällt): (a) Rasterrand ohne Nachbar → nur die Ausgangszelle ändert sich, austretender Streifen fällt weg (KEIN Wrap), (b) In-Zell-Verschiebung: ein nicht an der Kante liegendes Pixel wandert 1px und bleibt in der Zelle, (c) Nachbar-Zelle wird dedupliziert neu registriert, (d) obere Ebene komplett transparent verschoben → `ABSENT` (0). File: `Source/LayerModel.lua`

### Persistence & Verification

- [X] T014 [P] [US1] `tests/headless_tests.lua` — nach dem US1-Rework: „LayerModel: shiftTileContent verschiebt nur die Cursor-Zelle; Inhalt wandert in den Nachbarn und bleibt“ (2-Tile-Streifen, Akkumulation, alle 4 Richtungen, Rasterrand ohne Nachbar, obere Ebene → `absent`), „EditorRoom: shiftActiveLayer(dir, cellIdx) verschiebt genau diese Zelle + Nachbar, Rest unberührt“ (Basisebene + Frame 2 unverändert, FR-004), „ZoomRoom: B + Pfeil verschiebt die Zelle unter dem Zoom-Cursor“ (+ Integration mit echtem EditorRoom).

- [X] T015 [P] [US1] `tests/headless_tests.lua`: Save+Reload nach Shift — Ebenenstruktur (2 Ebenen, 375 Positionen, Basisebene unverändert) bleibt erhalten. **Pixel-genaue** Shift-Persistenz über den PDI-Sheet ist im Headless-Mock nicht prüfbar (`image:draw` ist überall No-op — gilt für alle Tests dieser Datei) → Simulator T058.

**Checkpoint**: US1 ✅ — headless-Tests grün; buildNumber 17 → 18; pdc grün. Commit folgt.

---

## Phase 4: User Story 2 - Transparency Support (Priority: P1)

**Goal**: Implement per-layer transparency in Pixel View with persistence. *(Fifth Round, 2026-09-01: painting is A only — B no longer places pixels; see Fortschritt.)*

**Independent Test** (from quickstart.md): Pixel View on Layer 2 → place opaque (A), erase to transparent (A again), place another opaque, save/reload → transparency states persist, visually distinct (checkerboard); a B-tap does nothing

### Transparency Placement (Pixel View)

- [X] T016 [US2] `PixelRoom:inputHandler` — **~~`BButtonDown`/`BButtonUp` → `beginStroke("B")`~~ (Fifth Round: zurückgenommen, B malt nicht mehr).** Der ebenenabhängige „Nicht-Tinte“-Zustand wird jetzt allein über den A-Radierer erreicht (`beginStroke()` ohne `button`, `strokeValue = OPAQUE-Zelle ? offState : OPAQUE`). Transparenz lebt pro Pixel im 16×16-Tile (`kColorClear`), nicht in einem 375er-Array. `BButtonDown/Up` sind No-ops; B + Kurbel zurück bleibt der Zoom-Out. File path: `Source/PixelRoom.lua`

- [X] T017 [US2] `gridView:drawCell` rendert TRANSPARENT-Zellen mit Schachbrett-`setPattern` (sichtbar verschieden von opak-schwarz und leer-weiß, FR-011). File path: `Source/PixelRoom.lua`

- [X] T018 [US2] ~~Y-Druck~~ → **Playdate-Hardware hat keine Y-Taste** (Plan-Artefakt-Fehler). A toggelt opak↔„Nicht-Tinte“ (Radierer, Spec 008): auf der Basisebene ↔weiß, auf Ebenen 2–3 ↔`kColorClear`. ~~B setzt transparent~~ (Fifth Round: B malt nicht mehr). `buildTileImage`: OPAQUE→schwarz, TRANSPARENT→`kColorClear`, EMPTY→weiß. "Invert" tauscht nur opak↔„Nicht-Tinte“. File path: `Source/PixelRoom.lua`

### Transparency State Encoding

- [X] T019 [P] [US2] `Source/PixelTransparency.lua` — `fromColor`/`toColor`/`sampleState` bilden Zustand↔`gfx.kColor*` ab (Phase 2). Kein `Layer:setPosition`.

- [X] T020 [P] [US2] ~~`Layer:getTransparencyAt` / atomares position+transparency-Update~~ → **N/A**: kein per-Zelle-Transparenz-Array. Transparenz ist Teil des Tile-Bitmaps und damit per Definition atomar mit dem Tile.

### Backward Compatibility

- [X] T021 [US2] Erledigt in Phase 2: `newLoadOperation` — v1.0-Bilder (flache Frames, keine Transparenz) laden als eine Basisebene, alle Pixel opak (schwarz/weiß). Test „v1.0-Bild lädt als einzelne opake Ebene“.

- [X] T022 [US2] Erledigt in Phase 2: Test „v1.0-Bild lädt … Re-Save schreibt v1.1“.

### Persistence & Verification

- [X] T023 [P] [US2] `tests/headless_tests.lua` „PixelRoom: transparenter Strich + Ruecklesen aus dem Tile“: ein A-Strich, der auf einer Tinte-Zelle startet (Fifth Round — vorher B-Strich), → `buildTileImage` erzeugt `kColorClear`-Pixel; `setCurrentTile` liest sie als TRANSPARENT zurück; 3-Zustands-`hashTile` dedupliziert opak vs. transparent getrennt. Voller PixelRoom→ZoomRoom→EditorRoom→Save→Reload-Bilddurchlauf für einen Einzelpixel: Simulator (T057).

- [X] T024 [P] [US2] `tests/headless_tests.lua` „obere Ebene: A auf leerem Pixel → Tinte → A → transparent“ + „Basisebene: A auf weiß → Tinte → A → weiß“ + „B-Tipp folgenlos“ (Fifth Round — vorher „leer → A → opak → B → transparent“).

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

**Checkpoint**: US3 ✅ — headless-Tests grün; buildNumber 16 → 17; pdc grün. 60-FPS-Compositing-Profiling → T053 (Simulator/Gerät).

---

## Phase 6: User Story 4 - Frame Management View (Priority: P2)

> **Neu ausgerichtet (Third Round):** Ebenen sind fix 3 pro Frame — **keine Layer View**. US4 ist eine **Frame-Verwaltung**: Frames anordnen + löschen (min. 1). Alle „TileView“ = `Source/EditorRoom.lua`; neue Datei `Source/FrameManagementView.lua`.

**Independent Test** (quickstart Szenario 4): Tile View → B halten + Kurbel rückwärts → Frame-Liste; Frame markieren (A) + Links → Reihenfolge ändert sich; A erneut auf dem markierten Frame → gelöscht; letzter Frame nicht löschbar; B loslassen → zurück.

### Frame Management View

- [X] T033 (US4) `Source/FrameManagementView.lua` (neuer Room) — Liste aller Frames; D-Pad hoch/runter bewegt den Cursor (hebt Markierung auf).

- [X] T034 (US4) `FrameManagementView:draw()` — Frame-Einträge „Frame i / n“ mit Cursor-Highlight + `[*]`-Markierung; Hinweis „last frame cannot be deleted“ bei 1 Frame.

- [X] T035 (US4) `A` markiert den Frame unter dem Cursor. `A erneut` auf dem markierten Frame **löscht** ihn (Zwei-Schritt-Bestätigung; B ist durch die Halte-Geste belegt → A statt B). Löschen bei nur 1 Frame wird abgelehnt (FR-020). `table.remove` aus `frameLayers` **und** dem flachen `frames`-Cache.

- [X] T036 (US4) `Links`/`Rechts` auf dem markierten Frame verschieben ihn eine Position (an den Enden geklemmt); `swapFrames` tauscht `frameLayers[a]↔[b]` und `frames[a]↔[b]` im Gleichschritt; Cursor + Markierung folgen.

### View-Navigation

- [X] T037 (US4) `EditorRoom.handleCrank`: der B + Kurbel-rückwärts-Zweig (`zoomTickAccu <= -ZOOM_TICK_THRESHOLD`, früher No-op) → `openFrameManagementView()` → `frameManagementView:setImageData(imageData, currentFrame)` + `switchRoom`. File: `Source/EditorRoom.lua`

- [X] T038 (US4) `FrameManagementView:update()` erkennt **B loslassen** (nach der Eintritts-Halte-Geste) → `switchRoom(editorRoom)`, setzt `imageData.returnFrame`. `EditorRoom:entered()` liest `returnFrame`, klemmt `currentFrame` + `activeLayer` in die evtl. kürzere Sequenz, `updateTilemapFrame()`.

### ~~Animation Layer View~~ (entfällt)

- [X] T039–T041 ~~AnimationLayerView / Frame-Layer-Submenu~~ → **entfallen** (keine Ebenen-Verwaltung; die Frame-Verwaltung *ist* die frühere „Animation Layer View“, nur ohne Ebenen-Bezug). `main.lua`: `import "FrameManagementView"` + Verdrahtung `EditorRoom ⇄ FrameManagementView`.

### Verification & Testing

- [X] T042 (US4) `tests/headless_tests.lua` „FrameManagementView: Navigation, Markieren, Verschieben, Loeschen“: Reorder tauscht beide Arrays im Gleichschritt, zweiter A-Druck löscht, letzter Frame geschützt, B-Release → `switchRoom`.

- [X] T043 (US4) `tests/headless_tests.lua` „EditorRoom: B + Kurbel rueckwaerts oeffnet die Frame Management View“ + Rückkehr mit `returnFrame`-Klemmung.

**Checkpoint**: US4 ✅ — headless-Tests grün; buildNumber 20 → 21; pdc grün.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Goal**: Testing, documentation, performance tuning, Constitution V gates

### Headless Test Suite (Constitution V Gate 1)

- [X] T044 `lua tests/headless_tests.lua` → „ALLE TESTS BESTANDEN“ (nach jeder Phase, siehe Fortschritt).

- [X] T045 Spec-010-Testsektionen ergänzt: PixelTransparency, LayerModel (Konstruktion/`padTo3`/`validate`/`cycleActive`/Compositing), 3-Zustands-`hashTile`, `createFramesTableV11` (leere obere Ebenen weglassen), `pruneUnusedTilesLayered`, v1.1-Round-Trip, v1.0→v1.1-Upgrade, 3-Layer-Cap; EditorRoom (aktive Ebene / Composite-Cache / Radierer / `tickForward`-Deep-Copy / „clear screen“ / Up-Down-Crank-Cyclen / Frame-Wechsel); PixelRoom (ebenenabhängiger Off-State / Strich); ZoomRoom (B+Pfeil-Shift-Dispatch); FrameManagementView (Navigation/Markieren/Verschieben/Löschen) + EditorRoom-Einstiegsgeste. ~180 Assertions.

- [X] T046 Jede Implementierungs-Task hat headless-Abdeckung; pixel-genaue PDI-Sheet-Roundtrips sind im Mock nicht prüfbar (`image:draw` No-op, gilt für die ganze Datei) → Simulator T056–T059.

### Build Gate (Constitution V Gate 2)

- [X] T047 `buildNumber` je `pdc`-Lauf um 1 erhöht: 13 → 21 über die Phasen.

- [X] T048 `pdc Source "Hans Dither.pdx"` läuft nach jeder Phase fehlerfrei durch (`main.pdz` erzeugt). Simulator-Launch → T056.

### arc42 Documentation Updates

- [X] T049 arc42 Kapitel 4: neuer Abschnitt **4.6 „Ebenen & Pixel-Transparenz (Spec 010)“** — feste 3-Ebenen-Struktur, flacher Composite-Cache, Transparenz als `kColorClear` im Tile, ebenenabhängiger Off-State, US4 = Frame-Verwaltung. File: `arc42/04-loesungsstrategie.md`

- [X] T050 arc42 Kapitel 9: **AD-041** (9.29) + [ADR-041](../../arc42/adr/ADR-041-Compositing-Cache-und-Frame-Verwaltung.md) — Compositing als flacher Cache (oberste nicht-leere Zelle gewinnt; Multi-Tilemap verworfen) + US4 = Frame-Verwaltung.

- [X] T051 arc42 Kapitel 9: **AD-040** (9.28) + [ADR-040](../../arc42/adr/ADR-040-Pixel-Transparenz-im-Tile.md) — `kColorClear` im Tile + 3-Klassen-`hashTile` (per-Zelle-0/1/2-Array verworfen) + ebenenabhängiger Off-State.

- [X] T052 arc42 Kapitel 9: **AD-039** (9.27) + [ADR-039](../../arc42/adr/ADR-039-Feste-3-Ebenen-Struktur.md) — feste 3-Ebenen-Struktur ohne Add/Delete, leere obere Ebenen auf Platte weggelassen. arc42 Kapitel 5 (Bausteinsicht) mitgezogen (neue Bausteine LayerModel/PixelTransparency/FrameManagementView + Spec-010-Klauseln an EditorRoom/ZoomRoom/PixelRoom/ImageStoreCodec). **Kapitel 6/7 (Laufzeit-/Verteilungssicht): Spec-010-Sequenzen als Folgeaufgabe offen.**

### Performance Tuning (Simulator/Gerät)

- [ ] T053 Tile-View-Compositing (`LayerModel.compositeToFlat` je Edit + voller Frame bei Wechsel) auf 60 FPS profilen. `compositeToTiles` (pixel-genaue Ebenen-Überblendung) ist implementiert, aber noch **nicht im Renderpfad verdrahtet** — für die aktuelle „oberste Ebene je Zelle gewinnt“-Darstellung nicht nötig; Verdrahtung + Profiling hier.

- [X]/[ ] T054 **Durch die Umfangs-Einschränkung erledigt (ADR-043), Geräte-Messung offen.** `LayerModel.shiftLayerContent` baute je Tastendruck alle 375 Tiles der Ebene neu (Standalone-Messung: ~192k `image:sample()`-Aufrufe, laptop-seitig 212 ms — auf Hardware als "zu inperformant" gemeldet). Nach dem US1-Rework verschiebt B + Pfeil nur noch die Cursor-Zelle + einen Nachbarn: `LayerModel.shiftTileContent` berührt ≤ 2 Tiles (~2500 Ops), läuft synchron je Tastendruck. Sollte klar unter 16 ms liegen — am Gerät gegenprüfen (Playdate-Simulator/Hardware).

- [ ] T055 Speicher-Audit: 12 Frames × 3 Ebenen × 375 Tile-Indizes ≈ 13,5 K Ganzzahlen — unkritisch. Prüfen, dass `compositeToFlat`/Recomposite keine Tabellen-Leaks erzeugen.

### Integration & End-to-End Testing (Simulator)

- [ ] T056 quickstart Szenario 1: 3 Ebenen cyclen (Up/Down + Crank), Frame-Cyclen unbeeinflusst, aktiver Index bleibt über Frame-Wechsel.

- [ ] T057 quickstart Szenario 2: PixelRoom — B auf Ebene 2/3 malt transparent (Schachbrett), A radiert nach transparent; auf Ebene 1 malt B weiß. Tile View: untere Ebene scheint durch. Save/Reload.

- [ ] T058 quickstart Szenario 3: ZoomRoom — B + Pfeiltasten schieben den Ebeneninhalt pixelweise, Tiles neu berechnet. Save/Reload.

- [ ] T059 quickstart Szenario 4 + 5: Frame Management View (B + Kurbel rückwärts) — anordnen/löschen/min. 1; v1.0-Bild lädt als Ebene 1 + 2 leere obere.

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

# Eighth + Ninth Round (2026-09-06) — Frame Room & Overlay Consolidation

**Source**: `spec.md` Clarifications (Eighth Round, from hardware testing; Ninth Round, from `/speckit-clarify`) · `plan.md` "Eighth-Round Update" section + Ninth-Round callout · `research.md` R11–R13 · `data-model.md` "Eighth-Round Additions" · `contracts/frame-room-and-overlay.md`.

**Scope**: (A) one consolidated cursor-opposite overlay bar in the Tile View — the tile picker no longer draws screen-centred (`FR-028`, `SC-008`; `FR-015`/`025`/`027` revised); (B) the Frame Management View becomes a **persistent room** with a `playdate.ui.gridview` thumbnail grid, controls mirroring `SelectionRoom`, A as a plain mark/unmark toggle, **delete + duplicate on the system menu** with an A/B confirm dialog, and a **B-release-armed** "B + Crank forward" exit (`FR-018`–`FR-022` revised, `SC-004` revised); (C) arc42 Kap. 4/5/6/8/9/10/11 + **ADR-047**, **ADR-048**, plus the Spec-010 Kap. 6 runtime-view backfill (`tasks.md` T052).

**Not in scope**: storage/codec (frame order + count persist via v1.1 unchanged), the entry gesture (`EditorRoom.handleCrank` B + Crank-backward → `openFrameManagementView` is unchanged), `main.lua` room wiring (the room is already wired).

**Numbering**: continues from T059. **Start `buildNumber` = 37.**

**Gate per phase with a code change** (Constitution V, blocking): `lua tests/headless_tests.lua` → "ALLE TESTS BESTANDEN" **+** `Source/pdxinfo` `buildNumber` +1 **+** `pdc Source "Hans Dither.pdx"` clean **+** commit.

**Headless mock**: no new mock work — `tests/headless_tests.lua` already mocks `playdate.ui.gridview` (`newGridview`), `playdate.getSystemMenu()` (observable `mockMenuItemLabels` / `mockMenuItemCallbacks`), `playdate.getCrankTicks`, `buttonIsPressed`. T090 verifies.

---

## Phase 8: Setup (Eighth + Ninth Round)

- [X] T060 `Source/pdxinfo` — bump `buildNumber` 37 → 38 (first test build of this round; +1 per subsequent phase with a code change).

**Checkpoint**: `pdc` still builds; baseline headless green.

---

## Phase 9: Consolidated Overlay Bar (US5 — plan Phase A) 🎯 lowest-risk increment

**Goal**: one bar on the screen edge opposite the tile cursor carries the frame/layer label (`FR-015`), the tile-picker filmstrip (`FR-025`), the "Tile N picked" toast (`FR-027`) and status messages; it never covers the cursor's tile and its elements never overdraw each other (`FR-028`/`SC-008`). The `UndoPrompt` (Spec 011) stays a separate coordinated layer.

**Independent Test**: `quickstart.md` Test Scenario 8 — move the cursor into the top half → bar at the bottom; bottom half → bar at the top; open the picker with the cursor in the bottom half → filmstrip in the top bar, not screen-centre; status text shares the bar without overdraw.

- [X] T061 [P] [US5] `Source/Bauchbinde.lua` — add `Bauchbinde:draw(lines, hSide, vAnchor, screenW, screenH)`: `vAnchor` `"top"|"bottom"` → `bandY = margin` or `screenH - bandH - margin`; `lines` a string or array (multi-line grows `bandH`); `hSide` unchanged. Keep `Bauchbinde:drawBottom(text, side, screenW, screenH)` **with its exact current signature** as a wrapper `self:draw(text, side, "bottom", screenW, screenH)` so `SelectionRoom.lua:456` is unaffected. Per `contracts/frame-room-and-overlay.md` → Bauchbinde table.
- [X] T062 [US5] `Source/EditorRoom.lua` — add module-local pure helpers `overlayAnchor(cursorY, rows)` (`"bottom"` if `cursorY <= rows/2` else `"top"`), `overlayRegionRect(anchor, contentH, screenH)`, `cursorCellRect(cx, cy)` (`{(cx-1)*16, (cy-1)*16, 16, 16}`). No behaviour change yet — helpers only.
- [X] T063 [US5] `Source/EditorRoom.lua` — `draw()`: compute `vAnchor = overlayAnchor(cursor.y, GRID_ROWS)`; compose **one** content block — line 1 = `pickMessageVisible and pickMessage` or the `"Frame x/y  L#/# name"` label, line 2 = `statusMessage` (if set) **in the same band**; draw via `bauchbinde:draw(lines, hSide, vAnchor, 400, 240)`. **Remove** the separate `bauchbinde:drawBottom(statusMessage, "left", 400, 240)` call (fixes the pre-existing bottom-left collision). `UndoPrompt.draw()` stays last.
- [X] T064 [US5] `Source/EditorRoom.lua` — `drawTilePickerOverlay()`: keep horizontal centring; make `py` `vAnchor`-relative (`"top"` → `margin`; `"bottom"` → `240 - panelH - margin - labelH`) so the filmstrip renders inside the anchored region, never screen-centre (`FR-025` revised).
- [X] T065 [P] [US5] `tests/headless_tests.lua` — new section "Spec 010 Eighth Round: overlay anchor (SC-008)": `overlayAnchor(y, 15)` = `"bottom"` for `y ≤ 7`, `"top"` for `y ≥ 8`; for every `y ∈ [1,15]`, `overlayRegionRect(overlayAnchor(y,15), h, 240)` ∩ `cursorCellRect(cx, y)` = ∅; with the picker visible, label / filmstrip / status sub-rects are pairwise disjoint; `Bauchbinde:drawBottom` is still callable with the old 4-arg signature.

**Checkpoint**: overlay bar dodges the cursor for every row; picker no longer screen-centred; status folded into the band. `lua tests/headless_tests.lua` green, `buildNumber` 38 → 39, `pdc` clean, commit.

---

## Phase 10: Frame Management Room (US4 — plan Phase B)

**Goal**: `FrameManagementView` is a persistent room. Enter with B + Crank backward (unchanged), leave with **B + Crank forward, armed only after one B-release**. Frames shown as a `playdate.ui.gridview` thumbnail grid; controls mirror `SelectionRoom` — D-Pad navigates, **A marks/unmarks (plain toggle, never deletes)**, B is back/cancel. D-Pad while a frame is marked moves it in the sequence. **"delete frame"** (system menu → A/B confirm dialog, acts on the cursor frame, rejected at 1 frame) and **"duplicate frame"** (system menu → deep-copy after cursor, rejected at 12) are the destructive/creational actions.

**Independent Test**: `quickstart.md` Test Scenario 4 — enter, stay after release, navigate, A-toggle mark, D-Pad reorder (mark follows, not cleared), system-menu "delete frame" → confirm → shrink, "duplicate frame" → grow, delete rejected at 1 frame, armed exit (crank residual on entry does nothing), save/reload persists.

### Spec 011 undo-history integration

- [X] T066 [US4] `Source/UndoHistory.lua` — `remapFrames(op)`: add the `{ inserted = i }` case — every entry with `frameIndex >= i` shifts **up** by one (the mirror of the existing `{ removed = i }` down-shift). `{ swapped }` / `{ removed }` unchanged. Per `contracts/frame-room-and-overlay.md` → Spec 011 compatibility table.
- [X] T067 [US4] `Source/EditorRoom.lua` — `onFramesReindexed(op)`: accept `{ inserted = i }` and forward to `undoHistory:remapFrames(op)` (already a pass-through; just widen the doc comment `op = { swapped } | { removed } | { inserted }`).

### FrameManagementView rewrite (`Source/FrameManagementView.lua`)

- [X] T068 [US4] `Source/FrameManagementView.lua` — replace the session state: `cursor` (1-based grid index), `marked` (number | nil), `bReleasedSinceEnter` (bool), `confirmingDelete` (bool | nil), `crankAccu` (int), `thumbCache` (`{ [pos] = image }`), `gridview`. **Remove** `bWasHeld`, `movedSinceMark`, and the list renderer (`ROW_H` / `LIST_X` / `LIST_Y` / the `draw()` row loop). Keep `switchRoomFunction` / `editorRoom` / `imageData` / `setImageData` / `returnToEditor`.
- [X] T069 [US4] `Source/FrameManagementView.lua` — `entered()`: reset `marked=nil`, `confirmingDelete=nil`, `bReleasedSinceEnter=false`, `crankAccu=0`; build `thumbCache[1..n]` — for each frame render `imageData.frames[f]` through a `playdate.graphics.tilemap` (`setTiles(imageData.frames[f], 25)`) into a 400×240 image, then `image:scaledImage(cellW/400)`; build `gridview = playdate.ui.gridview.new(CELL_W, CELL_H)` with `setNumberOfColumns(3)`, `setNumberOfRows(ceil(n/3))`, `changeRowOnColumnWrap = false`, `drawCell` → `FrameManagementView:drawCell(...)`.
- [X] T070 [US4] `Source/FrameManagementView.lua` — `entered()` (cont.): `getSystemMenu():removeAllMenuItems()` then register **"delete frame"** → `onMenuDelete()` and **"duplicate frame"** → `onMenuDuplicate()` (mirrors `SelectionRoom:buildSystemMenu`; `EditorRoom:entered()` already rebuilds its own menu on return).
- [X] T071 [US4] `Source/FrameManagementView.lua` — `update()`: read `playdate.getCrankTicks(4)` **once** → add to `crankAccu`; `if not playdate.buttonIsPressed(playdate.kButtonB) then bReleasedSinceEnter = true end`; `if playdate.buttonIsPressed(playdate.kButtonB) and bReleasedSinceEnter and crankAccu >= ZOOM_TICK_THRESHOLD then returnToEditor() end`. **Delete the B-held→released exit and `bWasHeld`.** Never call `getCrankChange()` here (CR-01). Redraw on `needsRedraw`.
- [X] T072 [US4] `Source/FrameManagementView.lua` — `inputHandler()`: while `confirmingDelete` → `AButtonDown` = `confirmDelete()`, `BButtonDown` = `cancelDelete()`, all else inert. Otherwise `up/down/left/rightButtonDown` → `marked` set ? `moveMarked(dx,dy)` : `moveCursor(dx,dy)`; `AButtonDown` → `pressA()`.
- [X] T073 [US4] `Source/FrameManagementView.lua` — `pressA()` = plain toggle: `marked = (marked == cursor) and nil or cursor`. `moveCursor(dx,dy)`: 3-column grid math (left/right = `cursor ± 1` within the row, up/down = `cursor ± 3`), clamp `[1, frameCount()]`, on change `marked = nil`.
- [X] T074 [US4] `Source/FrameManagementView.lua` — `moveMarked(dx,dy)`: `steps = (dx ~= 0) and 1 or 3`; `sign = ((dx ~= 0) and dx or dy) > 0 and 1 or -1`; loop up to `steps` times: `t = marked + sign`; **stop** if `t < 1` or `t > frameCount()`; `swapFrames(marked, t)`; swap `thumbCache[marked]` / `thumbCache[t]`; `editorRoom:onFramesReindexed({ swapped = { marked, t } })`; `marked = t`; `cursor = t`. Does **not** clear `marked`. (`swapFrames` unchanged.)
- [X] T075 [US4] `Source/FrameManagementView.lua` — `onMenuDelete()`: no-op if `frameCount() <= 1`, else `confirmingDelete = true`. `confirmDelete()`: `i = cursor`; `layersCopy = LayerModel.cloneFrameLayers(imageData.frameLayers[i])`, `flatCopy = LayerModel.copyArray(imageData.frames[i])`; `table.remove` from `frameLayers` / `frames` / `thumbCache`; `editorRoom:onFramesReindexed({ removed = i })`; `editorRoom:recordDeleteFrame(i, layersCopy, flatCopy)`; `marked = nil`; `cursor = clamp(cursor, 1, frameCount())`; `confirmingDelete = nil`. `cancelDelete()`: `confirmingDelete = nil`.
- [X] T076 [US4] `Source/FrameManagementView.lua` — `onMenuDuplicate()`: no-op if `frameCount() >= 12`, else `i = cursor`; `layersCopy = LayerModel.cloneFrameLayers(imageData.frameLayers[i])`, `flatCopy = LayerModel.copyArray(imageData.frames[i])`; `table.insert(imageData.frameLayers, i+1, layersCopy)`, `table.insert(imageData.frames, i+1, flatCopy)`, insert a fresh thumbnail at `thumbCache[i+1]`; `editorRoom:onFramesReindexed({ inserted = i+1 })`; `cursor = i+1`.
- [X] T077 [US4] `Source/FrameManagementView.lua` — `draw()`: `gridview:drawInRect(0, 0, 400, 240)`; `drawCell(section, row, col, selected, x, y, w, h)` → `index = (row-1)*3 + col`; skip if `> frameCount()`; draw `thumbCache[index]` centred in the cell, marked border if `index == marked`, cursor ring if `index == cursor`, "Frame i/n" caption. If `confirmingDelete` → draw the confirm dialog last in the `SelectionRoom:drawConfirmDeleteDialog` style ("Delete Frame N?  (A) Yes  (B) No"). `returnToEditor()` unchanged (`imageData.returnFrame = cursor`; `switchRoomFunction(editorRoom)`).

### Tests for User Story 4

- [X] T078 [P] [US4] `tests/headless_tests.lua` — rewrite the "FrameManagementView" section for the grid + room model: `moveCursor` grid math (up/down ±3 clamped, left/right ±1 in row, clears `marked`); `pressA` is a mark/unmark toggle and **never** calls `recordDeleteFrame`; `moveMarked` Left/Right = 1 `swapFrames` + 1 `onFramesReindexed({swapped})`, Up/Down = ≤ 3 sequential adjacent `swapFrames` each firing `onFramesReindexed({swapped})`, `marked` follows and is not cleared; `#thumbCache == frameCount()` after every op.
- [X] T079 [P] [US4] `tests/headless_tests.lua` — "FrameManagementView: system menu + armed exit": `mockMenuItemLabels` after `entered()` = `{"delete frame", "duplicate frame"}`; invoking "delete frame" with `frameCount() > 1` sets `confirmingDelete`, then the dialog's A path calls `recordDeleteFrame` + `onFramesReindexed({removed})` + `table.remove`; "delete frame" with 1 frame is a no-op (no dialog); dialog B cancels; "duplicate frame" inserts at `cursor+1` + `onFramesReindexed({inserted})`, no-op at 12 frames; B + Crank-forward does nothing until a frame with B not pressed has been seen, then fires `returnToEditor`.
- [X] T080 [P] [US4] `tests/headless_tests.lua` — "Spec 011 regression through the room rewrite": `UndoHistory:remapFrames({ inserted = i })` shifts entries with `frameIndex >= i` up by one (mirror of `{ removed }`); the existing `deleteFrame`-undo section stays green through `confirmDelete`; an undo entry's `frameIndex` after a "duplicate frame" still resolves to the intended frame.

**Checkpoint**: US4 complete — persistent room, thumbnail grid, `SelectionRoom`-style controls, A toggle, D-Pad reorder, menu delete (with confirm) + duplicate, armed exit; Spec 011 undo history follows every structure change. `lua tests/headless_tests.lua` green, `buildNumber` 39 → 40, `pdc` clean, commit.

---

## Phase 11: Polish — arc42 / ADR / Gates / Manual Integration (plan Phase C)

### arc42 evidence (Constitution III + iSAQB)

- [ ] T081 [P] `arc42/04-loesungsstrategie.md` — two Eighth/Ninth-Round Leitentscheidungen: persistent Frame Room (symmetric B + Crank gestures with a B-release arming condition; B-release exit removed); consolidated cursor-opposite overlay bar (picker no longer screen-centred).
- [ ] T082 [P] `arc42/05-bausteinsicht.md` — `FrameManagementView` → room with `entered()`/exit lifecycle + `playdate.ui.gridview` + a per-position `thumbCache`; `Bauchbinde` gains a vertical anchor; `EditorRoom.draw` overlay section becomes one layout unit. Add "Seit Spec 010 (Eighth/Ninth Round)" clauses.
- [ ] T083 `arc42/06-laufzeitsicht.md` — **(a) backfill** the Spec-010 sequences still missing since T052: layer cycling (B + Up/Down), tile picker (Crank, no B), Frame-Verwaltung enter/exit. **(b) new**: "Frame Room enter (B + Crank backward) → grid nav → A mark → D-Pad move (n× `swapFrames` + `onFramesReindexed`) → system menu delete (`confirmingDelete` → `confirmDelete` → `recordDeleteFrame`) / duplicate (`{inserted}`) → exit (armed; B + Crank forward) → `EditorRoom:entered()` clamps `currentFrame`"; "overlay bar: cursor zone → compose content → draw cursor-opposite".
- [ ] T084 [P] `arc42/07-verteilungssicht.md` — one line: Eighth/Ninth Round = **N/A** (no build / packaging / deployment change) — corrects the imprecise "Kapitel 6/7 offen" note from T052 (only Kap. 6 was open).
- [ ] T085 [P] `arc42/08-querschnittliche-konzepte.md` — overlay concept (one consolidated cursor-opposite bar; `UndoPrompt` a separate coordinated layer); gesture concept (symmetric B + Crank with an arming boolean); the Frame Room system menu mirrors `SelectionRoom`.
- [ ] T086 `arc42/adr/ADR-047-Frame-Verwaltung-persistenter-Room.md` (NEW) + `arc42/09-architekturentscheidungen.md` §9.35 short entry — persistent room; B + Crank in/out; B-release exit removed (retires the c2cbb6f dead-end fix); exit armed by `bReleasedSinceEnter`; reorder = sequential adjacent `swapFrames` (keeps Spec 011's `{swapped}` payload valid); thumbnail grid via `playdate.ui.gridview`; **system menu "delete frame" + "duplicate frame"**, delete reuses the `SelectionRoom` confirm-dialog pattern (Ninth Round — overturns the earlier "no room-local system menu"); A is a mark/unmark toggle; shake stays inactive (Spec 011 FR-010); consequence: new `{ inserted }` `remapFrames` payload. Include the device-tuned notes from T093.
- [ ] T087 `arc42/adr/ADR-048-Konsolidierte-Overlay-Leiste.md` (NEW) + `arc42/09-architekturentscheidungen.md` §9.36 short entry — one region on the cursor-opposite edge for label + picker filmstrip + "Tile N picked" toast + status; picker no longer screen-centred; `Bauchbinde` vertical anchor; `UndoPrompt` (Spec 011) a separate coordinated layer; anchor logic is a pure function gated by `SC-008`.
- [ ] T088 [P] `arc42/10-qualitaetsanforderungen.md` — QS: Usability (the overlay never covers the cursor's tile — `SC-008`); Performance (`thumbCache` build < 1 frame on entry, partial invalidation — R-33); Robustness (deterministic room exit via arming — R-32).
- [ ] T089 [P] `arc42/11-risiken-und-technische-schulden.md` — R-32 (crank residual on entry vs. the forward-only exit → arming boolean + single crank API + headless test), R-33 (thumbnail render cost → cache + partial invalidation + device measurement), R-34 (overlay layout bug hides content → pure anchor/region functions + `SC-008` gate).

### Architecture review & gates

- [ ] T090 Architecture review: confirm `FrameManagementView` still does not `import "EditorRoom"` (uses only the injected `editorRoom` ref for `onFramesReindexed` / `recordDeleteFrame`); `Bauchbinde:drawBottom` signature unchanged (`SelectionRoom.lua:456` caller); `playdate.ui.gridview` is the SDK primitive (no hand-rolled grid); `FrameManagementView` uses **one** crank API (`getCrankTicks(4)`, CR-01). Append a short result note to `plan.md` → "Architektur-Arbeitsprodukte".
- [ ] T091 Constitution V — Gate 1: `lua tests/headless_tests.lua` → "ALLE TESTS BESTANDEN" with the new sections (T065, T078, T079, T080). Verify no "erfundene SDK-API" failure — `playdate.ui.gridview` / `getSystemMenu` / `getCrankTicks` are already in the mock (`tests/headless_tests.lua` lines ~243 / ~283 / ~315); extend only if a new call surfaces.
- [ ] T092 Constitution V — Gate 2: record the final `Source/pdxinfo` `buildNumber`; `pdc Source "Hans Dither.pdx"` clean; note (`buildNumber`, "pdc clean") in the progress log.

### Manual simulator / hardware integration

- [ ] T093 Simulator: run `quickstart.md` Test Scenario 4 (rewritten) and Test Scenario 8 (overlay / `SC-008`) end to end; log any deviation as a bug/task.
- [ ] T094 Hardware (Playdate device): time the `thumbCache` build on `FrameManagementView:entered()` for a 12-frame image (R-33 — if > ~1 frame, fall back to lazy per-cell rendering); confirm the "B + Crank forward" exit has **no** false trigger from the entry gesture's crank follow-through (R-32); confirm the overlay bar covers the cursor's tile in **no** cursor position (`SC-008`, visual). Record the outcomes in ADR-047 / ADR-048.

### Audit evidence

- [ ] T095 Update `specs/010-layer-management-with-transparency/spec.md` (the Eighth-Round "Audit Evidence Applicability" table + the Ninth-Round refinement note) and `plan.md` (the "Audit Evidence Applicability (Eighth Round, plan level)" table): flip each arc42 row from **Open** to **Done** with the concrete file path after T081–T089; confirm arc42 Kap. 2 / 3 / 7 and the secure-architecture preset as **N/A** with the rationale from `plan.md`; add one line to `checklists/requirements.md`: "Tasks 2026-09-06 (Eighth + Ninth Round): all governance checkpoints done or owner-tracked".
- [ ] T096 Verify `.github/copilot-instructions.md` points at `specs/010-layer-management-with-transparency/plan.md` (set in `/speckit-plan` — verify only).

**Checkpoint**: all gates green; arc42 Kap. 4/5/6/7/8/9/10/11 updated; ADR-047 + ADR-048 written; audit tables consistent; manual integration done or owner-tracked.

---

## Eighth + Ninth Round — Dependencies & Parallel Execution

### Phase order

- **Phase 8 (T060)**: no prerequisite.
- **Phase 9 (T061–T065)**: after T060. **Independent of Phase 10.** Ship first — lowest risk (pure `EditorRoom.draw` + `Bauchbinde`, headless-testable anchor).
- **Phase 10 (T066–T080)**: after T060. Independent of Phase 9. Touches `switchRoom` lifecycle + Spec 011 hooks + the crank.
- **Phase 11 (T081–T096)**: after Phases 9 and 10.

### Within phases

- **Phase 9**: T061 [P] ∥ T062; then T063 → T064 (same file, sequential); T065 [P] after T062.
- **Phase 10**: T066 → T067; then T068 (state skeleton) → T069 → T070 → T071 → T072 → T073 → T074 → T075 → T076 → T077 (all one file, sequential); T078 / T079 / T080 [P] after T077.
- **Phase 11**: T081, T082, T084, T085, T088, T089 [P] (distinct arc42 files); T086 then T087 (both touch `arc42/09` — sequential); T083 after T082; T090 after Phase 10; T091 → T092 gates; T093 / T094 manual; T095 after T081–T089; T096 [P].

### Parallel example — Phase 11 arc42

```text
Task: "arc42/04-loesungsstrategie.md — 2 Leitentscheidungen (T081)"
Task: "arc42/05-bausteinsicht.md — FrameManagementView lifecycle + gridview; Bauchbinde anchor (T082)"
Task: "arc42/07-verteilungssicht.md — Eighth/Ninth Round = N/A (T084)"
Task: "arc42/08-querschnittliche-konzepte.md — overlay + gesture concepts (T085)"
Task: "arc42/10-qualitaetsanforderungen.md — SC-008 / thumbnail perf / deterministic exit (T088)"
Task: "arc42/11-risiken-und-technische-schulden.md — R-32/R-33/R-34 (T089)"
```

## Eighth + Ninth Round — Audit Evidence Applicability

| Checkpoint | Status | Evidence-producing task / rationale |
|---|---|---|
| arc42 Kap. 2 — Randbedingungen | **N/A** | No new platform capability or input primitive; gestures reuse the occupied B + Crank channel |
| arc42 Kap. 3 — Kontextabgrenzung | **N/A** | No new external interface |
| arc42 Kap. 4 — Lösungsstrategie | **T081** | 2 Leitentscheidungen |
| arc42 Kap. 5 — Bausteinsicht | **T082** | `FrameManagementView` lifecycle + `gridview`; `Bauchbinde` anchor; `EditorRoom.draw` layout unit |
| arc42 Kap. 6 — Laufzeitsicht | **T083** | Spec-010 backfill (layer cycling / tile picker / frame mgmt) + Eighth/Ninth-Round room + overlay sequences |
| arc42 Kap. 7 — Verteilungssicht | **T084 (records N/A)** | No build/packaging/deployment change |
| arc42 Kap. 8 — Querschnittliche Konzepte | **T085** | Overlay concept + arming-gesture concept + Frame Room menu |
| arc42 Kap. 9 — Architekturentscheidungen (+ `adr/`) | **T086, T087** | ADR-047, ADR-048 + §9.35 / §9.36 |
| arc42 Kap. 10 — Qualitätsanforderungen | **T088** | SC-008 / thumbnail perf / deterministic exit |
| arc42 Kap. 11 — Risiken & technische Schulden | **T089** | R-32, R-33, R-34 |
| Architecture review (module cut, no cyclic import, one crank API) | **T090** | Result note appended to `plan.md` |
| Secure-Architecture-Preset (iSAQB) | **N/A (confirmed in T095)** | Local UI/room restructuring only — no network, no secrets, no persistence change, no new attack surface. Re-eval trigger: Frame Room / overlay state persisted or externally configured |
| Constitution V — Gate 1 (headless) | **T091** | New sections T065 / T078 / T079 / T080 green; "ALLE TESTS BESTANDEN" |
| Constitution V — Gate 2 (`buildNumber` +1, `pdc`) | **T060, T066/T079-checkpoints, T092** | `buildNumber` 37 → 38 → 39 → 40; `pdc` clean |
| Manual simulator / hardware integration | **T093, T094** — **Open** until run | Owner: Merlin. quickstart Scenario 4 + 8; device thumbnail-build FPS (R-33), no false exit from crank residual (R-32), overlay never covers the cursor (SC-008). Re-eval trigger: implementation complete |
| `docs/architecture/` evidence path | **Done (convention)** | Satisfied via `arc42/` per Constitution III, as in earlier rounds |

---

**Status**: ✅ Tasks complete (T001–T059 = rounds 1–7; **T060–T096 = Eighth + Ninth Round**) — ready for `/speckit-implement`. Suggested order: Phase 8 → Phase 9 (overlay bar, lowest risk) → Phase 10 (Frame Room) → Phase 11 (arc42 / gates / manual).

