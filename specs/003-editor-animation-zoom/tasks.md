# Tasks: Editor-Umbau — 16×16-Tiles, Animation und Zoomstufen

**Input**: Design documents from `/specs/003-editor-animation-zoom/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/editor-room.md, quickstart.md; **Spec 001** (ImageStore/ImageStoreCodec vollständig) und **Spec 002** (SelectionRoom mit Editor-Stub) müssen implementiert sein

**Tests**: Kein automatisiertes Test-Setup (arc42 R-05); Verifikation über die Simulator-/Hardware-Szenarien aus quickstart.md — jede Story schließt mit einer protokollierten Validierung ab.

**Organization**: Phasen nach User-Story-Priorität aus spec.md: US1 (P1, Malen) → US4 (P1, Autosave) → US2 (P2, Frames) → US3 (P2, Zoomstufen).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelisierbar (andere Dateien, keine offenen Abhängigkeiten)
- **[Story]**: US1 (tileweise malen), US2 (Frames per Crank), US3 (drei Zoomstufen), US4 (Autosave beim Verlassen)

## Path Conventions

Single project (Playdate-Lua): Quellcode unter `Source/`, Architektur-Doku unter `arc42/`, Feature-Doku unter `specs/003-editor-animation-zoom/`.

---

## Phase 1: Setup

**Purpose**: Room-Gerüst, ohne bestehende Pfade zu brechen

- [X] T001 Room-Gerüst `Source/EditorRoom.lua` anlegen: Room-Muster (`init(switchRoom, zoomRoom, selectionRoom)`, `setImage(id)`, `entered`, `update` mit needsRedraw, `inputHandler`, `getImageData()`), Zustandsfelder gemäß data-model.md "EditorRoom-Zustand" als Stubs (contracts/editor-room.md Abschnitt 1)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Bild laden, Tilemap rendern, Verdrahtung — Voraussetzung für alle Stories

**⚠️ CRITICAL**: Erst abschließen, dann Story-Phasen beginnen

- [X] T002 Load-Ablauf in `Source/EditorRoom.lua`: `entered()` startet `ImageStoreCodec.newLoadOperation(id)` als RoomOperation mit loadingBar; Erfolg → `imageData` setzen, `tilemap` aufbauen (`gfx.tilemap.new()`, `setImageTable(imageData.imagetable)`, `setSize(25,15)`, `setTiles(frames[1], 25)`), `currentFrame = 1`; Fehler → Fehlerstatus + Rückkehr zum SelectionRoom (Contract E-01, research.md R1)
- [X] T003 Rendering-Grundgerüst in `Source/EditorRoom.lua`: `update()` zeichnet Tilemap bei (0,0) auf 400×240, PencilCursor-Overlay an Cursorposition (16-px-Zellen), needsRedraw-Muster; kein Offscreen-Buffer (AD-016, research.md R1)
- [X] T004 Verdrahtung in `Source/main.lua`: Import `EditorRoom`; `SelectionRoom:init(switchRoom, EditorRoom, TitleRoom)` (ersetzt den Stub aus Spec 002 T005), `EditorRoom:init(switchRoom, ZoomRoom, SelectionRoom)`; alte TileRoom-/LoadRoom-Verdrahtung noch nicht entfernen (Entfernung in Phase 7, App bleibt jederzeit lauffähig)

**Checkpoint**: Bildauswahl öffnet den EditorRoom mit gerendertem Frame 1 und sichtbarem Cursor

---

## Phase 3: User Story 1 — Direkt im Editor tileweise malen (Priority: P1) 🎯 MVP

**Goal**: D-Pad-Cursor, A = Zeichnen/Toggle, B = Pipette (inkl. Abwahl auf Weiß); kein Tile-Picker, Crank ohne B löst keine Tile-Auswahl aus

**Independent Test**: quickstart.md Szenario 1 (Toggle, Pipette, Zeichnen, ≤ 2 Eingaben bis zum ersten Tile)

### Implementation for User Story 1

- [X] T005 [US1] Cursorbewegung in `Source/EditorRoom.lua`: D-Pad bewegt tileweise (1..25 / 1..15, Stopp am Rand); Richtungs-Halten wiederholt (Timer-Muster aus `Source/TileRoomEditor.lua` übernehmen) (FR-002)
- [X] T006 [US1] Mal-Semantik in `Source/EditorRoom.lua`: `set(idx)` = `frames[currentFrame][cell] = idx` + `tilemap:setTiles(frames[currentFrame], 25)` + needsRedraw; A-Logik gemäß data-model.md "Mal-Operationen" (mit activeTile: setzen/auf Weiß zurück; ohne: Toggle 1↔2) (FR-004, Contract C-03 aus Spec 001)
- [X] T007 [US1] Pipette in `Source/EditorRoom.lua`: B (kurz) setzt `activeTile = frames[currentFrame][cell]`; Index 1 (Weiß) → `activeTile = nil` (Abwahl); kein B-Long-Press-Verhalten mehr (FR-003/FR-005, research.md R4)
- [ ] T008 [US1] Validierung durchführen und protokollieren: quickstart.md Szenario 1 im Simulator; Befund als Abschnitt "Validierung" in `specs/003-editor-animation-zoom/quickstart.md` notieren

**Checkpoint**: Malen im Editor voll funktionsfähig auf Frame 1; MVP erlebbar

---

## Phase 4: User Story 4 — Automatisch speichern beim Verlassen (Priority: P1)

**Goal**: "save + exit" im Systemmenü speichert über den Spec-001-Codec und kehrt zum Auswahlscreen zurück; Terminate-Hook speichert ebenfalls

**Independent Test**: quickstart.md Szenario 4 (Save/Reload-Zyklus + Exit Game)

### Implementation for User Story 4

- [X] T009 [US4] Systemmenü-Grundgerüst in `Source/EditorRoom.lua` bei `entered()`: `removeAllMenuItems()` + Eintrag "save + exit" → RoomOperation mit `ImageStoreCodec.newSaveOperation(imageData)`, Eingaben während des Laufs blockiert, Erfolg → `switchRoom(selectionRoom)`; Fehler → Fehlerstatus, Editor bleibt bedienbar (FR-014, research.md R6/R7, Contract E-02; Einträge "delete frame"/"show grid" folgen in US2/US3)
- [X] T010 [US4] Terminate-Hook in `Source/main.lua` finalisieren: `gameWillTerminate()` speichert via `EditorRoom:getImageData()`, wenn EditorRoom oder eine Zoomstufe aktiv ist; Zoomstufen committen zuvor ihren Slot-Zustand (Contract E-03; ersetzt die Übergangslösung aus Spec 001 T010)
- [ ] T011 [US4] Validierung durchführen und protokollieren: quickstart.md Szenario 4 im Simulator (beide Pfade: Menü + Exit Game); Befund in `specs/003-editor-animation-zoom/quickstart.md` notieren

**Checkpoint**: Malen → Verlassen → Wieder öffnen ohne Datenverlust; SelectionRoom zeigt frisches Thumbnail

---

## Phase 5: User Story 2 — Animationsframes per Crank verwalten (Priority: P2)

**Goal**: Crank (ohne B) wechselt Frames mit Kopie-Semantik, 12er-Grenze mit beidseitiger Rotation, Frame-Anzeige, Frame löschen per Menü

**Independent Test**: quickstart.md Szenario 2 (Kopie, Rotation beidseitig, schnelles Drehen, Löschen inkl. Sperre)

### Implementation for User Story 2

- [X] T012 [US2] Frame-Operationen in `Source/EditorRoom.lua`: `tickForward()`/`tickBackward()` gemäß data-model.md "Frame-Operationen" (flache 375er-Array-Kopie beim Anlegen, Rotation 12→1 und 1→letzter); nach jeder Operation `tilemap:setTiles(frames[currentFrame], 25)` (FR-006/FR-007, research.md R3)
- [X] T013 [US2] Crank-Anbindung in `Source/EditorRoom.lua`: `playdate.getCrankTicks(4)` einmal pro `update()` lesen (stateful!); ohne gehaltenes B: Ticks sequenziell auf tickForward/tickBackward anwenden (mehrere Ticks pro Update = mehrere Einzelschritte, Edge Case schnelles Drehen); `activeTile` bleibt bei Frame-Wechsel erhalten (research.md R2, Spec-Edge-Cases)
- [X] T014 [P] [US2] Frame-Anzeige über `Source/Bauchbinde.lua` einbinden: "Frame n/m" bei jedem Frame-Wechsel im EditorRoom anzeigen (FR-008; Bauchbinde-API unverändert wiederverwenden)
- [X] T015 [US2] Menüeintrag "delete frame" in `Source/EditorRoom.lua`: `table.remove(frames, currentFrame)`, Nachrücker aktiv (`currentFrame = min(currentFrame, #frames)`); bei `#frames == 1` wirkungslos; Bauchbinde aktualisieren (FR-008a, Clarification)
- [ ] T016 [US2] Validierung durchführen und protokollieren: quickstart.md Szenario 2 im Simulator; Befund in `specs/003-editor-animation-zoom/quickstart.md` notieren

**Checkpoint**: SC-002 — 12-Frame-Animation vollständig per Crank erstell- und durchlaufbar

---

## Phase 6: User Story 3 — Drei Zoomstufen (Priority: P2)

**Goal**: B+Crank wechselt Editor ↔ Zoom Room (24×24, 2×2-Malstrich) ↔ Pixel Room (16×16, 1×1); Commit über den Dedup-Pfad, nur aktiver Frame; Bestandsfunktionen (Grid-Sync, Invert, All Similar) erhalten

**Independent Test**: quickstart.md Szenario 3 (Zoomkette, Koordinatentreue über Save/Load, Frame-Bezug, Out-of-bounds)

### Implementation for User Story 3

- [X] T017 [US3] B+Crank-Zoomtrigger in `Source/EditorRoom.lua`: Tick-Akkumulation bei gehaltenem B (Muster aus `Source/TileRoom.lua` Zeilen um 599–630 übernehmen, `zoomTickAccu`); vorwärts → Kontext bauen + `switchRoom(ZoomRoom)`; kein Long-Press-Konflikt mehr (FR-009, research.md R5)
- [X] T018 [US3] Kontextübergabe Editor → Zoom in `Source/EditorRoom.lua`: 3×3-Slot-Struktur um den Cursor (`{tileX, tileY, frameIndexPos, originalIndex, originalImage}`, out-of-bounds markiert) + 24×24-`gridState` aus dem 48×48-Pixelkontext (2×2-Blockauslese) + `showGrid` (data-model.md "Zoomkontexte", Contract Abschnitt 3)
- [X] T019 [US3] `Source/ZoomRoom.lua` umbauen: `setFromEditorContext(ctx)` statt TileRoom-Kopplung; Malstrich schreibt 2×2 native Pixel (Z-01); Anzeige-Zellgröße 10 px (240×240 zentriert); B+Crank vor → PixelRoom mit selektiertem Slot, zurück → Commit + Rückkehr (research.md R5)
- [X] T020 [US3] `Source/PixelRoom.lua` umbauen: 16×16-Raster statt 8×8 (Anzeige ~14 px/Zelle, zentriert); Invert und "All Similar" auf 16×16 weiterführen; Rückgabe an ZoomRoom unverändert (FR-011/FR-015)
- [X] T021 [US3] Commit-Pfad `EditorRoom:applyTileEdits(edits)` in `Source/EditorRoom.lua`: nur geänderte Slots (Pixelvergleich, Bestandsmuster); je Edit `hashTile` → `hashIndex`-Treffer (+ Pixelvergleich) oder `imagetable:setImage(#imagetable+1, ...)` + `hashIndex` nachführen; schreibt ausschließlich `frames[currentFrame]` (FR-012/FR-013, Z-03; hashTile aus `Source/ImageStoreCodec.lua` wiederverwenden)
- [X] T022 [US3] Menüeintrag "show grid" (Checkmark) in `Source/EditorRoom.lua`: Grid-Overlay im Editor an/aus, Status in den Zoomkontext durchreichen (FR-015; Bestandsverhalten QS-07)
- [ ] T023 [US3] Validierung durchführen und protokollieren: quickstart.md Szenario 3 im Simulator (inkl. Frame-Bezug und Out-of-bounds-Ecken); Befund in `specs/003-editor-animation-zoom/quickstart.md` notieren

**Checkpoint**: SC-003 — pixelgenaue Änderungen über alle drei Stufen und über Save/Load

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Altmodule entfernen, Messungen, Hardware-Check, Architektur-Evidenz (Constitution III / iSAQB)

- [ ] T024 Altmodule entfernen und Verdrahtung bereinigen: `Source/TileRoom.lua`, `Source/TileRoomEditor.lua`, `Source/TileRoomPersistence.lua`, `Source/LoadRoom.lua`, `Source/LoadRoomGrid.lua`, `Source/PulpGameIO.lua`, `Source/PulpGameIOShared.lua`, `Source/PulpGameIOSave.lua`, `Source/PulpGameIOLoad.lua` löschen; Imports/Init-Aufrufe in `Source/main.lua` entfernen; Build (`pdc Source`) muss fehlerfrei durchlaufen — schließt den Open-Punkt aus Spec 002 (LoadRoom-Entfernung) und löst die Deprecation aus Spec 001 T026 ein
- [ ] T025 Performance-/Speichermessung: quickstart.md Szenario 5 (12 Frames, intensives Detail-Malen; sheet.pdi/frames.json-Größen notieren); Befund in `specs/003-editor-animation-zoom/quickstart.md`; bei auffälligem Imagetable-Wachstum Vermerk an R-13 in `arc42/11-risiken-und-technische-schulden.md`
- [ ] T026 Hardware-Check Crank (Open-Punkt aus plan.md): quickstart.md Szenario 6 auf dem Gerät (90°-Rastung, Zoomtrigger); Befund in `specs/003-editor-animation-zoom/quickstart.md`; bei Justierung neuen Tick-Wert in `Source/EditorRoom.lua` als Konstante dokumentieren und in `arc42/09-architekturentscheidungen.md` AD-019 nachtragen (Owner: Projektinhaber, Re-Evaluation: vor Release 0.3.0)
- [X] T027 [P] arc42-Ist-Kapitel aktualisieren: `arc42/05-bausteinsicht.md` (EditorRoom + umgebaute Zoomräume, entfallene Module austragen), `arc42/06-laufzeitsicht.md` (Szenarien 6.2–6.4 neu: Malen, Frame-Wechsel, Zoomkette, Autosave), `arc42/08-querschnittliche-konzepte.md` (8.1 Input-Semantik neu; 8.2.1 duales Auflösungskonzept entfernen; 8.4 Tile-Lifecycle auf imageData), `arc42/10-qualitaetsanforderungen.md` (QS-03a/QS-12 austragen, Frame-Integritätsszenario ergänzen), `arc42/12-glossar.md` (Ist-Begriffe: Bild/Frame/Zoomräume 16×16, Pulp-Begriffe als historisch markieren) — Evidenz: Feature-Branch-Diff (Constitution III)
- [X] T028 [P] `arc42/09-architekturentscheidungen.md` und `arc42/11-risiken-und-technische-schulden.md` pflegen: AD-016/AD-019 → "Status: umgesetzt"; AD-014/AD-015 → "Status: abgelöst durch AD-019/AD-016"; AD-002-Konsequenz (Tile-Picker) aktualisieren; R-11 und T-09 als erledigt austragen, Priorisierung in 11.4 anpassen
- [ ] T029 Lernbarkeitstest: quickstart.md Szenario 7 (SC-005, 5-Minuten-Test mit v0.2.0-kundigem Nutzer); Befund in `specs/003-editor-animation-zoom/quickstart.md`
- [X] T030 Architektur-Review-Durchlauf: Umsetzung gegen contracts/editor-room.md (E-01–E-03, Eingabetabelle, Z-01–Z-03, Abschnitt 4 "Entfallende Schnittstellen") und den Constitution Check aus plan.md prüfen; Abweichungen im Abschnitt Constitution Check von `specs/003-editor-animation-zoom/plan.md` notieren; Secure-Architecture: N/A (lokale Editorfunktion, Begründung in plan.md)

---

## Dependencies

```text
Spec 001 (Codec/hashIndex) + Spec 002 (SelectionRoom-Stub) ─┐
Phase 1 → Phase 2 → US1 (P1) → US4 (P1) → US2 (P2) → US3 (P2) → Phase 7
```

- US1 → braucht T002–T004 (Load, Rendering, Verdrahtung)
- US4 → braucht US1 (es muss etwas zu speichern geben); T010 ersetzt die Spec-001-Übergangslösung
- US2 → braucht US1 (Malen zum Verifizieren der Kopie-Semantik); unabhängig von US4
- US3 → braucht US1 (Mal-Semantik) und US2 (T021 schreibt in den aktiven Frame; Frame-Bezug testbar); T019/T020 (Zoomräume) sind ab T018 parallel zu US2 vorziehbar
- T024 (Entfernung) zwingend erst nach US4 (neuer Save-Pfad aktiv) und US3 (Zoomräume entkoppelt)

## Parallel Execution Examples

- **US2**: T014 (Bauchbinde-Anbindung) parallel zu T012/T013 (Kern-Logik)
- **US3**: T019 (ZoomRoom) ∥ T020 (PixelRoom) — verschiedene Dateien, gemeinsame Basis T018
- **Nach T018**: US3-Zoomraum-Umbauten parallel zu US2 (T012–T016) als zwei Stränge
- **Phase 7**: T027 ∥ T028 (arc42) parallel zu T025/T026 (Messung/Hardware)

## Implementation Strategy

1. **MVP = Phase 1 + 2 + US1**: Bild öffnen und tileweise malen auf Frame 1 — der Kern-Editor läuft nativ auf 16×16/400×240.
2. **Inkrement 2 = US4**: Autosave schließt den Rundlauf Auswahl → Malen → Speichern → Auswahl (ersetzt den Spec-002-Stub vollständig).
3. **Inkrement 3 = US2**: Animation (Crank, 12 Frames, Löschen).
4. **Inkrement 4 = US3**: Zoomkette mit Dedup-Commit.
5. **Abschluss = Phase 7**: Altmodule löschen (App enthält keinen Pulp-Code mehr), Messungen, Hardware-Check, arc42-Evidenz.
6. Jedes Inkrement wird über die zugehörigen quickstart-Szenarien abgenommen; hardware-nahe Punkte (Crank) zusätzlich am Gerät (Constitution: Verifikation).

## Audit-Evidenz-Checkpoints (iSAQB-Preset)

- [X] Architektur-Sichten aktualisiert: T027 (arc42 Kap. 5/6/8/10/12) — Evidenz: Feature-Branch-Diff
- [X] ADRs gepflegt: T028 (AD-016/AD-019 umgesetzt; AD-014/AD-015 abgelöst) — Evidenz: `arc42/09-architekturentscheidungen.md`
- [ ] Risiko-/Schulden-Review: T025 (Imagetable-Wachstum → R-13) und T028 (R-11/T-09 austragen) — Evidenz: `arc42/11-risiken-und-technische-schulden.md` + Messbefund in quickstart.md
- [ ] Offener Punkt (Open): Crank-Rastung auf Hardware — T026; Owner: Projektinhaber, Follow-up: quickstart.md Szenario 6, Re-Evaluation: vor Release 0.3.0
- [X] Architektur-Review: T030 — Evidenz: Notiz im plan.md Constitution Check
- [X] Secure-Architecture: N/A — lokale Editorfunktion ohne Netzwerk/schutzbedürftige Daten (Begründung in plan.md, Architecture Governance)

---

## Phase 8: Convergence

- [X] T031 CRITICAL: Load-Abschluss in `Source/EditorRoom.lua` reparieren: `onComplete` resumed die bereits tote Load-Coroutine erneut, wodurch jeder Load im Fehlerpfad endet und `imageData` nie übernommen wird; Ergebnis der Coroutine beim letzten Resume übernehmen (Anpassung in `Source/RoomOperation.lua` oder Ergebnisübergabe im Codec), Phasen-Yields an `loadingBar:setDetail` durchreichen, Fehlerpfad mit `onError` anbinden (Rückkehr zum SelectionRoom, `loadingOperation` zurücksetzen) per Contract E-01/FR-001/US1-AC1 (partial)
- [X] T032 Richtungs-Halten in `Source/EditorRoom.lua` reparieren: einmalige Timer bewaffnen sich nicht neu, Wiederholung stoppt nach dem ersten Intervall-Tick; auf SDK-`playdate.timer.keyRepeatTimerWithDelay` umstellen (Constitution I: SDK-first) per FR-002 (partial)
- [X] T033 Crank-Gating in `Source/EditorRoom.lua` auf tatsächlichen B-Button-Zustand (`playdate.buttonIsPressed`) umstellen: `zoomBHeld` wird erst nach 300-ms-Timer wahr, sodass B+Crank innerhalb der ersten 300 ms Frames wechselt/anlegt statt zu zoomen; `zoomTickAccu` gemäß data-model.md verwenden (Vorarbeit zu T017) per FR-009/FR-006 (contradicts)
- [X] T034 Save-Fehlerpfad in `Source/EditorRoom.lua` anbinden: `savingOperation:resume()` mit `onError`-Callback aufrufen und `savingOperation` bei Fehler zurücksetzen, damit der Editor bedienbar bleibt (Overlay zeigt Fehlerstatus) per Contract E-02 (partial)
- [X] T035 Terminate-Hook in `Source/main.lua` für Zoomstufen vervollständigen: ZoomRoom-Zweig ist TODO-Stub, PixelRoom fehlt — Zoomstufen committen vor dem Save ihren Slot-Zustand in den EditorRoom (nach T019/T020 umsetzbar) per Contract E-03 (partial)
- [X] T036 Menü-Callbacks in `Source/EditorRoom.lua` gegen laufende Operationen sperren: `handleDeleteFrame` und `handleSaveAndExit` prüfen `savingOperation`/`loadingOperation` nicht, Menüaktionen können während Save/Load Frames mutieren bzw. einen Doppel-Save starten per Spec Edge Case "Konkurrierende Eingaben werden blockiert" (partial)
- [X] T037 Debug-Funktion `testImageStore()` in `Source/main.lua` prüfen und entfernen oder begründen: 68 Zeilen Testcode im Produktionspfad, von keinem Artefakt gefordert per plan: Project Structure (unrequested)

---

## Phase 9: Convergence (2. Durchlauf)

- [X] T038 Crank-Tick-Backlog in `Source/ZoomRoom.lua` und `Source/PixelRoom.lua` beheben: `playdate.getCrankTicks(4)` in jedem `update()` lesen und ohne gehaltenes B verwerfen (statt nur bei gehaltenem B zu lesen) — sonst entlädt sich ohne B aufgestauter Zähler beim ersten B-Frame in den Zoom-Akkumulator und der Trigger feuert verfrüht; Muster wie in `Source/EditorRoom.lua` per Contract Eingabetabelle/FR-009 (partial)
- [X] T039 `Source/GameRoom.lua` entfernen und Schuld T-10 in `arc42/11-risiken-und-technische-schulden.md` austragen: einziges nicht importiertes Modul im Quellbaum, durch SelectionRoom ersetzt (AD-018), von keinem Artefakt gefordert per arc42 T-10 (unrequested)
