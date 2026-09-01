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

**Status**: ✅ Tasks complete — Ready for implementation via agents or manual code

