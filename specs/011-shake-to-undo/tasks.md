---
description: "Task list — Schüttel-Undo für die letzten 3 riskanten Aktionen"
---

# Tasks: Schüttel-Undo für die letzten 3 riskanten Aktionen

**Input**: Design-Dokumente aus `/specs/011-shake-to-undo/` (plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md)

**Feature-Branch**: `feature/0.3-addons` · **Feature-Verzeichnis aktiv** laut `.specify/feature.json`

---

## Implementation Notes (Codebasis-Realität)

Reale Dateien flach in `Source/` — **kein** `Source/Rooms/` oder `Source/Models/`. Zuordnung: „Tile View" = `EditorRoom.lua`, „Zoom View" = `ZoomRoom.lua`, „Pixel View" = `PixelRoom.lua`.

- **Die vier riskanten Operationen** liegen heute an: `EditorRoom.clearCurrentFrame()` (nur **aktive Ebene**, trotz Name „Clear Screen"), `FrameManagementView.deleteMarked()` (Frame löschen — **nicht** der tote `EditorRoom.deleteCurrentFrame()` bei Zeile ~427, kein Aufrufer, **nicht anfassen**), `PixelRoom.rotateGridClockwise()/rotateGridCounterClockwise()` (Commit erst bei `commitToZoomRoom()`), `ZoomRoom.shiftActiveLayerContent()` → `EditorRoom:shiftActiveLayer()` (synchron pro Tastendruck, ADR-043).
- **Accelerometer** ist im Projekt bisher ungenutzt → im strikten Headless-Mock **muss** `playdate.startAccelerometer/stopAccelerometer/readAccelerometer` ergänzt werden, sonst schlägt schon das Laden fehl (contracts/headless-mocks.md).
- **Speichern nummeriert die Live-`imageData` nicht um** (`ImageStoreCodec.newSaveOperation` = reine Transformation, `ImageStoreCodec.lua:55-58`); die Imagetable wächst zur Laufzeit nur (`appendTileToImagetable`). ⇒ In `UndoEntry` gespeicherte Tile-Indizes + Bild-Referenzen bleiben die ganze Sitzung gültig.
- **`PixelRoom:init`** hält heute kein `editorRoom` → muss um einen Parameter erweitert werden (T014), damit Rotation-Snapshot + Schüttel-Weiterleitung ohne Umweg funktionieren.

**Gate je abgeschlossener Phase mit Code-Änderung** (Constitution V, blockierend):
`lua tests/headless_tests.lua` → „ALLE TESTS BESTANDEN" **+** `Source/pdxinfo` `buildNumber` um genau 1 erhöhen **+** `pdc Source "Hans Dither.pdx"` grün **+** Commit. Start-`buildNumber` = 30.

**Tests**: Headless-Tests in `tests/headless_tests.lua` sind Pflicht (Constitution V, Gate 1). Jede neue Modul-/Room-Logik wird dort mit den Verhaltensverträgen V1–V25 aus `contracts/undo-modules.md` abgedeckt.

---

## Phase 1: Setup

**Purpose**: Neue Module bekannt machen, Build-Zähler vorbereiten.

- [X] T001 In `Source/main.lua` die drei neuen Module importieren (`import "UndoHistory"`, `import "ShakeDetector"`, `import "UndoPrompt"` — im selben Block wie `PixelTransparency`/`LayerModel`) und die Room-Verdrahtung erweitern: `PixelRoom:init(switchRoom, ZoomRoom, EditorRoom)` (dritter Parameter neu, wird in T014 genutzt). Der dritte Parameter ist optional (Lua-`nil`) → die bestehenden `PixelRoom:init(noop, zoomMock)`-Aufrufe in `tests/headless_tests.lua` (5 Stellen) bleiben unverändert lauffähig; die Rotation-Snapshot-Tests in T022 setzen dort einen `editorRoom`-Mock ein.
- [X] T002 `Source/pdxinfo`: `buildNumber` 30 → 31 (erster Testbuild dieser Feature-Arbeit; danach je Phase mit Code-Änderung weiter +1).

**Checkpoint**: `pdc` läuft weiterhin (leere Module dürfen schon existieren), Baseline-Headless grün.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Die drei eigenständigen, SDK-freien Module + der Test-Mock. Ohne diese kann keine User Story beginnen.

**⚠️ CRITICAL**: Kein User-Story-Task startet, bevor Phase 2 vollständig grün ist.

- [X] T003 [P] `Source/UndoHistory.lua` neu — Tabellenmodul (wie `LayerModel`), `UndoHistory.new() -> hist`. Funktionen: `push(entry)` (anhängen, auf `MAX=3` vorne kürzen — FR-001), `peekValid(imageData) -> entry, reason` (jüngsten **anwendbaren** Eintrag; `content` mit fehlendem `frameIndex` verwerfen — FR-006; `deleteFrame` verwerfen, wenn `#imageData.frameLayers >= 12` — FR-007, `reason="frame-limit"` merken; sonst `reason=nil`), `pop()`, `clear()`, `isEmpty()`, `coalesceTarget(kind, frameIndex, layerArrayIndex) -> entry|nil` (jüngster Eintrag mit gleichem Ziel **und** `entry.runOpen == true`). Standard-Lua-Syntax, kein SDK-Zugriff. Verträge C-011-1, V1–V4.
- [X] T004 [P] `Source/ShakeDetector.lua` neu — `ShakeDetector.new(opts?) -> d` mit `T=0.85`, `W=500`, `R=1200` (überschreibbar). `d:feed(x, y, z, nowMs) -> bool` gemäß data-model.md §3 (Ausschlag `x > T` / `x < -T` merken; beide innerhalb `W` ms → Kante, `R` ms Refraktärsperre setzen, Merker leeren; kein Feuern während Sperre). `d:reset()`. Reine Zustandsfortschreibung, keine Allokation im Normalfall, kein SDK-Zugriff. Verträge C-011-3, V12–V16.
- [X] T005 [P] `Source/UndoPrompt.lua` neu — Singleton-Tabellenmodul nach dem Muster `SelectionRoom.drawConfirmDeleteDialog`/`confirmingDelete`. `open(label, onConfirm)` (No-op wenn schon offen — FR-015), `isOpen()`, `handleA()` (`onConfirm()` genau einmal, dann schließen), `handleB()` (schließen, `onConfirm` nicht rufen), `draw()` (zentrierte 200×80-Box: Zeile 1 `label`, Zeile 2 „(A) Ja", Zeile 3 „(B) Nein" — nur wenn `isOpen()`), `reset()`. Verträge C-011-4, V17–V19.
- [X] T006 `tests/headless_tests.lua` — `playdate`-Mock erweitern (contracts/headless-mocks.md): `startAccelerometer`/`stopAccelerometer` (setzen `accelRunning`, zählen `accelStartCount`/`accelStopCount`), `readAccelerometer` (zählt `accelReadCount`, liefert `accelXYZ` = Default `{0,0,1}`, testseitig setzbar). Im selben Block wie `buttonIsPressed`/`getCrankTicks`. Baseline muss danach unverändert „ALLE TESTS BESTANDEN".
- [X] T007 [P] `tests/headless_tests.lua` — Abschnitt „Spec 011: UndoHistory" (V1–V4): 4× `push` → `#entries == 3` + ältester weg; `peekValid` verwirft `content`-Eintrag mit gekürztem `frameLayers`; `peekValid` verwirft `deleteFrame` bei 12 Frames und liefert `reason == "frame-limit"`; `clear()` leert vollständig; `coalesceTarget` nur bei gleichem Ziel + `runOpen`.
- [X] T008 [P] `tests/headless_tests.lua` — Abschnitt „Spec 011: ShakeDetector" (V12–V16): saubere Links-Rechts-Folge feuert; 300 ruhige Samples feuern nie; Ausschläge > `W` ms auseinander feuern nie; nur positive Ausschläge feuern nie; Refraktärsperre unterdrückt das zweite Feuern innerhalb `R`.
- [X] T009 [P] `tests/headless_tests.lua` — Abschnitt „Spec 011: UndoPrompt" (V17–V19): `handleA` ruft `onConfirm` genau einmal und schließt; `handleB` schließt ohne `onConfirm`; zweites `open` ändert `label`/`onConfirm` nicht.
- [X] T010 `Source/EditorRoom.lua` — die `UndoHistory`- und `ShakeDetector`-Instanz anlegen (`local undoHistory = UndoHistory.new()`, `local shakeDetector = ShakeDetector.new()`); `EditorRoom:clearUndoHistory()` (ruft `undoHistory:clear()`) in `handleLoadSuccess` **und** überall dort aufrufen, wo zu `SelectionRoom` gewechselt wird (`handleSaveAndExit`-Callback, `handleLoadError`). Noch keine Aufzeichnung/Anwendung — nur Besitz + Lebenszyklus (FR-008).

**Checkpoint**: Die drei Module sind isoliert headless grün (V1–V4, V12–V19); `EditorRoom` besitzt einen leeren Verlauf, der bei Bild-/Editor-Wechsel geleert wird. `lua tests/headless_tests.lua` grün, `buildNumber` +1, `pdc` grün, Commit.

---

## Phase 3: User Story 1 - Versehentliche riskante Operation sofort zurücknehmen (Priority: P1) 🎯 MVP

**Goal**: Nach **jeder** der vier riskanten Operationen (Clear Screen, Frame löschen, Rotation, Pixel-Verschiebung) öffnet ein Links-Rechts-Schütteln einen Dialog; „(A) Ja" stellt den Zustand von unmittelbar davor exakt wieder her, „(B) Nein" ändert nichts. Malen erzeugt keinen Verlaufseintrag.

**Independent Test**: `quickstart.md` Szenarien A–D — je Operation ausführen, schütteln, A → Ausgangszustand zurück; B → keine Änderung; nach reinem Malen bezieht sich der Dialog auf die letzte riskante Operation davor.

### Implementation for User Story 1

- [X] T011 [US1] `Source/EditorRoom.lua` — Accelerometer-Lebenszyklus + Schüttel-Auswertung: in `EditorRoom:entered()` `playdate.startAccelerometer()` (idempotent), beim Wechsel zu `SelectionRoom` `playdate.stopAccelerometer()`. Neue Methode `EditorRoom:onShakeSample(x, y, z)` → `shakeDetector:feed(x, y, z, playdate.getCurrentTimeMilliseconds())`; bei `true` **und** `not UndoPrompt.isOpen()` → `self:undoRequest()`. In `EditorRoom:update()` einmal pro Frame `readAccelerometer()` lesen und `onShakeSample(...)` rufen (nur wenn `imageData` und keine `loadingOperation`/`savingOperation`). Verträge V21, V24.
- [X] T012 [US1] `Source/EditorRoom.lua` — `EditorRoom:undoRequest(commitAndReturn?)`: **zuerst** `if commitAndReturn then commitAndReturn() end` (aus ZoomRoom/PixelRoom: offene Edits committen + zurück in den Tile View — der Rotation-Eintrag entsteht erst dabei, also MUSS der Commit vor `peekValid` laufen, sonst zeigt der Dialog das Label des älteren Eintrags), **dann** `entry, reason = undoHistory:peekValid(imageData)`. `entry` → `UndoPrompt.open(labelFor(entry.op), function() EditorRoom:undoLast() end)` (FR-012). Kein `entry` → `showStatus(reason == "frame-limit" and "cannot undo - frame limit" or "Nothing to undo")`, **kein** Dialog (FR-007/FR-009). `labelFor` bildet `entry.op` → „Undo Clear Screen?" / „Undo Rotation?" / „Undo Pixel-Verschiebung?" / „Undo Frame loeschen?". `EditorRoom:hasUndo()` → `undoHistory:peekValid(imageData) ~= nil`. Verträge C-011-2, V22, V23, V23b.
- [X] T013 [US1] `Source/EditorRoom.lua` — Anwendung: `applyContentEntry(entry)` (je Zelle: `prevImage` vorhanden → `idx = registerTile(prevImage)`, sonst `idx = prevPosIndex`; `layer.positions[cellIdx] = idx`; danach `recompositeCell` je Zelle bzw. `recompositeCurrentFrame` bei `op=="clear"`; `updateTilemapFrame()`), `applyDeleteFrameEntry(entry)` (`i = min(index, #frameLayers+1)`; `table.insert(imageData.frameLayers, i, frameLayersEntry)`; `if imageData.frames and framesEntry then table.insert(imageData.frames, i, framesEntry) end`; `imageData.activeLayer = LayerModel.clampActive(...)`). `EditorRoom:undoLast() -> "applied"|"empty"`: `entry = undoHistory:peekValid(imageData)`; nil → `"empty"`; sonst anwenden nach `entry.kind`, `currentFrame = entry.frameIndex or i`, `updateTilemapFrame()`, `undoHistory:pop()`, `needsRedraw = true`, `"applied"`. **Keine** Ablehnung an dieser Stelle. Verträge V5–V10b.
- [X] T014 [US1] `Source/PixelRoom.lua` — `PixelRoom:init(switchRoom, nextRoomReference, editorRoomReference)`: dritten Parameter `editorRoom` aufnehmen (aus `main.lua`, T001). Rotation-Snapshot: beim **ersten** `rotateGridClockwise()`/`rotateGridCounterClockwise()` je `setCurrentTile`-Sitzung (Flag `rotationSnapshotTaken`, in `setCurrentTile` zurückgesetzt) den **aktuellen** `gridState` als 16×16-Bild sichern (`buildTileImage`-Weg) samt Zelle/Frame/Ebene. Bei `commitToZoomRoom()`, **wenn** die Zelle tatsächlich zurückgeschrieben wird, `editorRoom:recordRotation(frameIndex, layerArrayIndex, cellIdx, prevImage)`. Snapshot NICHT bei `setCurrentTile` (sonst würden vorher gemalte Pixel mit-zurückgenommen — Verstoß gegen FR-002). Verträge V6, V11.
- [X] T015 [US1] `Source/EditorRoom.lua` — `EditorRoom:recordRotation(frameIndex, layerArrayIndex, cellIdx, prevImage)`: pusht **einmal** je PixelRoom-Sitzung einen `content`-Eintrag `op="rotate"` mit genau dieser Zelle (`{prevPosIndex = layer.positions[cellIdx], prevImage = prevImage}`). Kein Coalescing über Sitzungen hinweg.
- [X] T016 [US1] `Source/EditorRoom.lua` — `clearCurrentFrame()` erweitern: **vor** dem Überschreiben von `layer.positions` `recordClear()` aufrufen → `content`-Eintrag `op="clear"` mit **allen 375** Zellen der aktiven Ebene (`{cellIdx, prevPosIndex = layer.positions[cellIdx], prevImage = imagetable:getImage(prevPosIndex) bzw. nil}`), `frameIndex = currentFrame`, `layerArrayIndex = imageData.activeLayer`. Klarstellen (Kommentar): betrifft nur die aktive Ebene. Vertrag V5.
- [X] T017 [US1] `Source/ZoomRoom.lua` — Shift-„Run" abgrenzen: `BButtonDown` markiert „Run möglich"; beim **ersten** `shiftActiveLayerContent()` danach `editorRoom:beginShiftRun(frameIndex, layerArrayIndex)` (pusht `content`/`op="shift"`, `runOpen=true`) und nach jedem `EditorRoom:shiftActiveLayer(...)` die von `LayerModel.shiftTileContent` gemeldeten ≤2 Zellen via `editorRoom:recordShiftCells(cells)` **nur ergänzen** (vorhandene `cellIdx` nicht überschreiben — Snapshot bleibt der Run-Start-Zustand). `BButtonUp`, Verlassen der `ZoomRoom` und Ziel-Zellwechsel → `editorRoom:endShiftRun()` (`runOpen=false`). Snapshot je Zelle = Bild **vor** dem ersten Shift. Verträge V7, C-011-2 (`beginShiftRun`/`recordShiftCells`/`endShiftRun`).
- [X] T018 [US1] `Source/EditorRoom.lua` — `beginShiftRun`/`recordShiftCells`/`endShiftRun` implementieren (nutzen `undoHistory:coalesceTarget("shift", frameIndex, layerArrayIndex)`; existiert ein offener Run → weiterverwenden, sonst neuen `content`-Eintrag pushen). `prevImage` je Zelle = `imagetable:getImage(layer.positions[cellIdx])` **vor** der Mutation.
- [X] T019 [US1] `Source/FrameManagementView.lua` — `deleteMarked()` erweitern: **vor** `table.remove` `editorRoom:recordDeleteFrame(marked, deepCopy(imageData.frameLayers[marked]), imageData.frames and LayerModel.copyArray(imageData.frames[marked]) or nil)`. Tiefe Kopie = `{duration, layers = {3 × {layerIndex, name, visible, positions = LayerModel.copyArray(375)}}}`. `EditorRoom:recordDeleteFrame(index, frameLayersEntryCopy, framesEntryCopy?)` pusht den `deleteFrame`-Eintrag. `editorRoom` hält `FrameManagementView` bereits über `init`. Verträge V9, V10.
- [X] T020 [US1] `Source/EditorRoom.lua` + `Source/ZoomRoom.lua` — Dialog-Anzeige + Routing im Tile/Zoom View: `EditorRoom:draw()` und `ZoomRoom:drawGrid()`/`draw()` rufen am Ende `UndoPrompt.draw()`. `ZoomRoom:update()` liest den Schüttel-Sample und ruft `editorRoom:onShakeSample(...)`; die Prompt wird aus der `ZoomRoom` mit `editorRoom:undoRequest(commitAndReturn)` geöffnet, `commitAndReturn = function() local edits = collectEdits(); if #edits > 0 then editorRoom:applyTileEdits(edits) end; switchRoomFunction(editorRoom) end` (V25 — dieselbe Kette wie `ZoomRoom:commitForTerminate`). A/B-Handler von `EditorRoom` und `ZoomRoom`: `if UndoPrompt.isOpen() then (A→UndoPrompt.handleA()) (B→UndoPrompt.handleB()) return end` **ganz oben**. Vollständiges Verschlucken von D-Pad/Crank folgt in US3 (T026).
- [X] T021 [US1] `Source/PixelRoom.lua` — Dialog-Anzeige + Routing im Pixel View: `PixelRoom`-`draw` ruft am Ende `UndoPrompt.draw()`; `PixelRoom:update()` liest den Schüttel-Sample und ruft `editorRoom:onShakeSample(...)`. Prompt aus der `PixelRoom`: `editorRoom:undoRequest(commitAndReturn)` mit `commitAndReturn = function() commitToZoomRoom(); nextRoom:commitForTerminate(); switchRoomFunction(editorRoom) end` — **die etablierte PixelRoom-Exit-Kette** aus `main.lua:82-84` (`gameWillTerminate`), NICHT direkt `switchRoom(editorRoom)` (sonst gehen offene Zoom-Raster-Edits + der Rotation-Snapshot aus T014 verloren). A/B-Handler `PixelRoom` zuerst `if UndoPrompt.isOpen() then A→handleA / B→handleB / return end`.
- [X] T022 [P] [US1] `tests/headless_tests.lua` — Abschnitt „Spec 011: Undo je Operationstyp" (V5–V9, V11): Clear Screen → `recordClear` → `clearCurrentFrame` → `undoLast()` → `layer.positions` elementweise identisch; Rotation → Commit → `undoLast()` → Zielzelle wieder Ausgangs-Tile; B-Halten + 3× Right + B los → **ein** Eintrag → `undoLast()` → Quell-/Nachbarzelle zurück; `recordDeleteFrame` + `table.remove` → `undoLast()` → `#frameLayers` zurück, Frame elementweise identisch, `currentFrame` gesetzt; „5 Pixel malen, dann rotieren, Commit" → `undoLast()` behält die 5 Pixel.
- [X] T023 [P] [US1] `tests/headless_tests.lua` — „Spec 011: Malen erzeugt keinen Eintrag" (V8): nur `beginStroke`/`setCell` → `undoHistory:isEmpty()` bleibt `true`. Und „Schütteln öffnet Dialog nur bei vorhandenem Undo" (V22/V23): `feed`→true bei leerem Verlauf → `UndoPrompt.isOpen()` bleibt `false`, `statusMessage == "Nothing to undo"`.

**Checkpoint**: US1 vollständig — jede der vier Operationen ist per Schütteln + A rückgängig; B bricht ab; Malen zählt nicht. `lua tests/headless_tests.lua` grün, `buildNumber` +1, `pdc` grün, Commit. **MVP erreicht.**

---

## Phase 4: User Story 2 - Bis zu drei riskante Operationen nacheinander zurücknehmen (Priority: P2)

**Goal**: Der Verlauf hält genau die letzten 3 riskanten Operationen; eine 4. verdrängt die älteste (FIFO). Bis zu 3 Undos hintereinander möglich; ungültig gewordene Einträge werden übersprungen.

**Independent Test**: `quickstart.md` Szenario E — 3 Operationen, 3× (Schütteln → A) → Zustand wie vor allen dreien; 4. Schütteln → „Nothing to undo"; danach 4 Operationen → nur die neuesten 3 erreichbar.

### Implementation for User Story 2

- [X] T024 [US2] `tests/headless_tests.lua` — Abschnitt „Spec 011: 3-stufiger Verlauf" (V1 integrativ + V2, deckt zugleich die einzige US2-Codeanforderung ab: kein Aufzeichnungspfad umgeht `UndoHistory:push`/`MAX`, `undoLast()` `pop()`t immer): Clear → Rotation → Shift-Run nacheinander (über die echten `record*`-Pfade aus US1) → `#entries == 3`; 4. Operation → alter Eintrag 1 nicht mehr in `entries` (FIFO); 3× `undoLast()` → jeder Schritt in umgekehrter Reihenfolge zurück, `isEmpty()` danach; ein `content`-Eintrag, dessen `frameIndex` durch ein späteres `deleteFrame`-Undo verschwindet, wird von `peekValid` übersprungen (FR-006) und der nächste gültige (oder `nil`) geliefert. Coalescing prüfen: ein offener Shift-Run zählt als **ein** Eintrag, nach `endShiftRun` beginnt ein neuer.
- [ ] T025 [US2] `quickstart.md` Szenario E im Simulator nachstellen (3 Operationen → 3× Schütteln+A → Ausgangszustand; 4. Schütteln → „Nothing to undo"; danach 4 Operationen → nur die neuesten 3 erreichbar); Ergebnis im Phasen-Checkpoint notieren.

**Checkpoint**: US1 **und** US2 funktionieren unabhängig. `lua tests/headless_tests.lua` grün, `buildNumber` +1, `pdc` grün, Commit.

---

## Phase 5: User Story 3 - Sicherer, verständlicher Undo-Dialog (Priority: P3)

**Goal**: Der Dialog benennt die betroffene Operation, ist vollständig modal (schluckt A/B/D-Pad/Crank, keine Editier-Aktion währenddessen), ein zweites Schütteln bei offenem Dialog ist wirkungslos, und ein leerer Verlauf bzw. die 12-Frame-Grenze zeigen eine kurze Meldung statt eines Dialogs.

**Independent Test**: `quickstart.md` Szenario F — bei offenem Dialog D-Pad/Crank/A/B durchprobieren: nur A/B wirken; zweites Schütteln folgenlos; Dialogtext nennt die konkrete Operation.

### Implementation for User Story 3

- [X] T026 [US3] `Source/EditorRoom.lua` / `Source/ZoomRoom.lua` / `Source/PixelRoom.lua` — **vollständige Modalität** (FR-013): in **jedem** Inputhandler-Callback (`upButtonDown`/`downButtonDown`/`leftButtonDown`/`rightButtonDown` + deren `…Up`, `AButtonDown/Up`, `BButtonDown/Up`) und in den `update()`-Crank-Blöcken (`getCrankTicks`/`getCrankChange`) zuerst `if UndoPrompt.isOpen() then …`: A → `UndoPrompt.handleA()`, B → `UndoPrompt.handleB()`, alles andere ohne Wirkung (früh-return). Beim Öffnen (`UndoPrompt.open`) die Direction-Hold-Automaten der aktiven Room leeren (`clearDirectionHold()` bzw. `clearMoveTimers()` in `EditorRoom`) und Crank-Reste verwerfen. Vertrag V20.
- [X] T027 [US3] `Source/EditorRoom.lua` — Meldungspfade schärfen: leerer Verlauf → `showStatus("Nothing to undo")`; `peekValid` liefert `reason == "frame-limit"` → `showStatus("cannot undo — frame limit")` (FR-007). Beide über den vorhandenen `statusMessage`/`statusUntilMs`-Mechanismus, kein Dialog. Zweites `feed`→true bei `UndoPrompt.isOpen()` wird ignoriert (kein erneutes `undoRequest`) — FR-015. Verträge V23, V23b.
- [X] T028 [US3] `Source/EditorRoom.lua` — `labelFor(entry)` liefert genau die vier Texte (Clear Screen / Rotation / Pixel-Verschiebung / Frame löschen); `UndoPrompt.draw()` zeigt sie in Zeile 1. Kurzer Sicht-Check im Simulator, dass die Box zentriert über allen drei Views sauber zeichnet (kein Redraw-Flackern — `needsRedraw` beim `open`/`handleA`/`handleB` setzen).
- [X] T029 [P] [US3] `tests/headless_tests.lua` — „Spec 011: Dialog ist modal" (V20, V23b): bei `UndoPrompt.isOpen()==true` lösen D-Pad/Crank/A/B in `EditorRoom`/`ZoomRoom`/`PixelRoom` **kein** `setCell`/`switchRoom`/`shiftActiveLayer`/`zoomIntoPixelRoom` aus (Mock-Beobachter); nur `handleA`/`handleB` wirken. Zweites Schütteln bei offenem Dialog → `undoRequest` wird nicht erneut ausgeführt. `deleteFrame`-Eintrag bei 12 Frames → kein Dialog, `statusMessage == "cannot undo — frame limit"`.
- [X] T030 [P] [US3] `tests/headless_tests.lua` — „Spec 011: Rückkehr in den Tile View" (V25): Dialog aus `ZoomRoom` bestätigt → `commitAndReturn` committet offene Edits + `switchRoom(EditorRoom)`; `EditorRoom:entered()` läuft **vor** `undoLast()`; nach dem Undo `currentRoom == EditorRoom` und `currentFrame` = betroffener Frame.

**Checkpoint**: Alle drei User Stories unabhängig funktionsfähig. `lua tests/headless_tests.lua` grün, `buildNumber` +1, `pdc` grün, Commit.

---

## Phase 6: Polish, Architektur-Evidenz & Cross-Cutting

**Purpose**: Constitution-V-Gates final, arc42/ADR-Evidenz (Constitution III + iSAQB-Preset), Qualitätsszenarien, Hardware-Integration.

### Constitution V — Gates (blockierend)

- [X] T031 `lua tests/headless_tests.lua` → „ALLE TESTS BESTANDEN" mit allen „Spec 011"-Abschnitten (T007–T009, T022–T024, T029–T030). Fehlklasse „erfundene SDK-API" darf nicht auftreten (Accelerometer-Mock T006 vollständig).
- [X] T032 `Source/pdxinfo` `buildNumber` finaler Stand dokumentiert; `pdc Source "Hans Dither.pdx"` fehlerfrei; Ergebnis (buildNumber, „pdc sauber") im Fortschritt notieren.

### arc42-Evidenz (Constitution III, Owner: `/speckit-implement` + Merlin)

- [X] T033 [P] `arc42/02-randbedingungen.md` — Accelerometer als **neue Eingabefähigkeit** eintragen (bisher ungenutzt); Batterie-Hinweis: Sensor nur in Tile/Zoom/Pixel-View aktiv.
- [X] T034 [P] `arc42/04-loesungsstrategie.md` — Absatz „Schüttel-Undo": Erkennung als Eigenlogik auf `playdate.readAccelerometer` (SDK ohne Shake-Event, SDK-First-Abweichung → ADR-044); Undo = Pre-State-Snapshots, sitzungslokal, kein Speicherformat betroffen (ADR-045).
- [X] T035 [P] `arc42/05-bausteinsicht.md` — neue Bausteine `UndoHistory`, `ShakeDetector`, `UndoPrompt` + Einbindepunkte (`EditorRoom` besitzt Verlauf/Detektor; `ZoomRoom`/`PixelRoom`/`FrameManagementView` melden Operationen bzw. füttern den Detektor).
- [X] T036 [P] `arc42/06-laufzeitsicht.md` — Sequenz „Schütteln → `ShakeDetector`-Kante → `undoRequest`/`peekValid` → `UndoPrompt` → (A) `commitAndReturn` + `undoLast` → `applyContentEntry`/`applyDeleteFrameEntry` + Navigation".
- [X] T037 [P] `arc42/08-querschnittliche-konzepte.md` — Eingabe-/Modalitätskonzept um den vollmodalen `UndoPrompt` (schluckt A/B/D-Pad/Crank) und den Accelerometer-Lebenszyklus (Start in `entered()` der Editier-Views, Stopp beim Rücksprung zu `SelectionRoom`) erweitern.
- [X] T038 `arc42/09-architekturentscheidungen.md` + `arc42/adr/` — **ADR-044** `ADR-044-Schuettel-Erkennung-Accelerometer.md` (SDK ohne Shake-Event; `T/W/R`-Algorithmus; Sensor nur in Editier-Views; Start-Parameter `T≈0.85 g` / `W≈500 ms` / `R≈1200 ms`, Endwerte nach Hardware-Test — Spec Open #4), **ADR-045** `ADR-045-Undo-Modell-3-Schritt-sitzungslokal.md` (fix 3 Einträge, nur 4 Operationstypen, Voll-Snapshot je Zelle Index+Bild, `deleteFrame` = tiefe Kopie, keine Persistenz, 12-Grenze in `peekValid`), **ADR-046** `ADR-046-Modaler-Undo-Dialog.md` (Wiederverwendung des `SelectionRoom`-Bestätigungsmusters; vollständige Modalität gegen belegte Eingaben). In Kapitel 9 je einen Kurzeintrag mit Link anlegen.
- [X] T039 [P] `arc42/10-qualitaetsanforderungen.md` — Qualitätsszenarien: Robustheit (Clear-Screen-Undo stellt Ebeneninhalt in < 1 s vollständig her), Performance (`ShakeDetector:feed` + `readAccelerometer` pro Frame ohne FPS-Einbruch im Zoom View), Speicher (3 Einträge, worst case ein `deleteFrame`-Snapshot, < ~100 KB).
- [X] T040 [P] `arc42/11-risiken-und-technische-schulden.md` — 5 Risikoeinträge aus `spec.md`/`plan.md` übernehmen (Fehlalarm; Accelerometer-Polling ↔ Zoom-FPS; Snapshot-Speicher; ungültige Einträge durch Struktur-Änderung; Dialog-Eingabekollision) mit Gegenmaßnahme + Status.

### Architektur-Review & Qualitätsszenario-Validierung (iSAQB-Preset)

- [X] T041 Architektur-Review: Modulschnitt `UndoHistory`/`ShakeDetector`/`UndoPrompt` gegen `contracts/undo-modules.md` prüfen — SDK-frei, keine zyklischen Importe, `EditorRoom` als einziger Anwendungs-Einstieg (`undoLast`), `undoLast` nie aus `switchRoom`/`entered()`. Ergebnis als kurze Notiz in `plan.md` (Abschnitt „Architektur-Arbeitsprodukte") anhängen.
- [ ] T042 Qualitätsszenarien aus T039 messen: Robustheit headless (Positions-Array vor/nach identisch, aus T022); Performance + Speicher **im Simulator/auf Hardware** (FPS-Anzeige Zoom View vor/nach; grobe RAM-Abschätzung dokumentieren). Ergebnisse in `quickstart.md` „Manuelle Hardware-Integration" eintragen. Hinweis: die Schwellwert-Justierung in T044 ändert `Source/ShakeDetector.lua` → eigener `buildNumber`-+1-/`pdc`-Zyklus, nicht nur ein ADR-Edit.

### Manuelle Simulator-/Hardware-Integration (separat, vor „fertig")

- [ ] T043 Simulator: `quickstart.md` Szenarien A–G vollständig durchspielen; Abweichungen als Fehler/Task erfassen.
- [ ] T044 Hardware (Playdate-Gerät): Schüttel-Erkennung in ≥ **9/10** bewussten Links-Rechts-Bewegungen (SC-006); 2 min normales Bedienen ohne Fehlalarm; Zoom-View-FPS unverändert zur Spec-008-Basislinie; `T/W/R` in `Source/ShakeDetector.lua` feinjustieren und die Endwerte in **ADR-044** nachtragen — **schließt Spec Open #4**.

### Audit-Evidenz

- [X] T045 `specs/011-shake-to-undo/spec.md` (Audit Evidence Applicability + Open) und `specs/011-shake-to-undo/plan.md` (Audit-Tabelle) aktualisieren: Spec Open #1/#2/#3 auf **Resolved** mit Verweis auf `research.md` R4 / R2-R3 / R6 (bereits im Plan gesetzt — hier Konsistenz prüfen), Spec Open #4 bleibt **Open** bis T044; jede arc42-Zeile von „Applicable/geplant" auf „Done" mit konkretem Dateipfad nach T033–T040; secure-architecture-Preset als **N/A** mit Begründung (rein lokal, kein Netzwerk, keine Secrets, keine Persistenz) bestätigen; `checklists/requirements.md` mit einer Zeile „Plan+Tasks 2026-09-02: alle Governance-Checkpoints erledigt bzw. mit Owner offen" ergänzen.
- [X] T046 `.github/copilot-instructions.md` zeigt auf `specs/011-shake-to-undo/plan.md` (in Phase 1 gesetzt — hier nur verifizieren); `MEMORY.md`/Auto-Memory nicht betroffen.

**Checkpoint**: Alle Gates grün, arc42 + 3 ADRs geschrieben, Qualitätsszenarien gemessen (headless jetzt, Hardware in T042/T044), Audit-Tabellen konsistent.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: keine Vorbedingung.
- **Foundational (Phase 2)**: nach Setup. **Blockiert alle User Stories.**
- **US1 (Phase 3)**: nach Foundational. Keine Abhängigkeit von US2/US3.
- **US2 (Phase 4)**: nach US1 (T024 fährt die echten `record*`-Pfade aus US1). Der reine Ringpuffer-Teil (FIFO/`peekValid`) ist schon in Phase 2 (T007) abgedeckt; T024 ist der integrative Nachweis über die Operationen, T025 der manuelle Durchlauf.
- **US3 (Phase 5)**: nach Foundational; härtet den in US1 (T020/T021) grob verdrahteten Dialog. T026/T029 setzen T020 + T021 voraus.
- **Polish (Phase 6)**: nach allen gewünschten User Stories.

### Innerhalb der User Stories

- US1: T011 (Lebenszyklus) → T012 (`undoRequest`) → T013 (`undoLast`/apply) sind sequenziell (dieselbe Datei `EditorRoom.lua`). T014/T015 (Rotation), T016 (Clear), T017/T018 (Shift), T019 (Delete) sind je Operation abgeschlossen; T014/T016/T017/T019 berühren verschiedene Dateien und können nach T013 parallel. T020 (Editor+Zoom) und T021 (Pixel) nach T012; T021 nach T014 (Rotation-Snapshot-Übergabe). T022/T023 (Tests) nach den jeweiligen Hooks.
- US3: T026 und T027/T028 dieselbe Datei-Gruppe → sequenziell; T029/T030 danach.

### Parallel Opportunities

- **Phase 2**: T003, T004, T005 (drei neue Dateien) parallel; danach T007/T008/T009 (Testabschnitte, verschiedene Blöcke) parallel; T006 vor T008.
- **Phase 3**: nach T013 laufen T014+T016+T017+T019 (verschiedene Dateien) parallel; Test-Tasks T022/T023 [P].
- **Phase 6**: T033–T037 + T039 + T040 sind alle verschiedene arc42-Dateien → vollständig parallel [P] (T038 berührt `arc42/09` + drei ADR-Dateien, separat).

---

## Parallel Example: Phase 2 (Foundational)

```bash
# Drei neue Module gleichzeitig anlegen:
Task: "Source/UndoHistory.lua neu — Ringpuffer, push/peekValid/pop/clear/coalesceTarget (T003)"
Task: "Source/ShakeDetector.lua neu — new/feed/reset, T/W/R (T004)"
Task: "Source/UndoPrompt.lua neu — open/isOpen/handleA/handleB/draw/reset (T005)"

# Danach die drei Modul-Testabschnitte gleichzeitig:
Task: "tests/headless_tests.lua — Abschnitt UndoHistory V1–V4 (T007)"
Task: "tests/headless_tests.lua — Abschnitt ShakeDetector V12–V16 (T008)"
Task: "tests/headless_tests.lua — Abschnitt UndoPrompt V17–V19 (T009)"
```

## Parallel Example: Phase 6 (arc42-Evidenz)

```bash
Task: "arc42/02-randbedingungen.md — Accelerometer als neue Eingabefähigkeit (T033)"
Task: "arc42/04-loesungsstrategie.md — Schüttel-Undo-Absatz (T034)"
Task: "arc42/05-bausteinsicht.md — UndoHistory/ShakeDetector/UndoPrompt (T035)"
Task: "arc42/06-laufzeitsicht.md — Sequenz Schütteln→Undo (T036)"
Task: "arc42/08-querschnittliche-konzepte.md — Modalität + Sensor-Lebenszyklus (T037)"
Task: "arc42/10-qualitaetsanforderungen.md — Robustheit/Performance/Speicher (T039)"
Task: "arc42/11-risiken-und-technische-schulden.md — 5 Risiken (T040)"
```

---

## Implementation Strategy

### MVP First (nur User Story 1)

1. Phase 1 (Setup) + Phase 2 (Foundational) — drei Module isoliert grün.
2. Phase 3 (US1) — Schütteln → Dialog → A stellt jede der vier riskanten Operationen wieder her.
3. **STOP & VALIDATE**: `quickstart.md` Szenarien A–D.
4. Gate: headless grün + `buildNumber` +1 + `pdc` grün + Commit. Demo-fähig.

### Inkrementell

- + US2 (Phase 4): 3-Schritt-Verlauf + FIFO nachweisen → Gate → Commit.
- + US3 (Phase 5): volle Modalität + Meldungen + Op-Label → Gate → Commit.
- Phase 6: arc42/ADR/Qualitätsszenarien + Hardware-Integration (SC-006, Spec Open #4).

---

## Notes

- `[P]` = andere Datei, keine offene Abhängigkeit.
- `[Story]`-Label nur in den Phasen 3–5.
- Kein Redo, keine Persistenz, genau 4 Operationstypen, harte Grenze 3 — nicht erweitern (Constitution IV).
- `EditorRoom.deleteCurrentFrame()` (toter Code) **nicht** instrumentieren — nur `FrameManagementView.deleteMarked()`.
- Nach jeder Phase mit Code-Änderung: `buildNumber` +1 **vor** dem `pdc`-Testbuild (Constitution V, Gate 2).
- Bugfix ⇒ Testfall ergänzen, der die Fehlerklasse künftig abfängt (Constitution V).
