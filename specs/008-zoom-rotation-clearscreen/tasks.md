# Tasks: Zoom-Room-Performance, Pixel-Rotation und vereinfachte Frame-Verwaltung

**Input**: Design documents from `/specs/008-zoom-rotation-clearscreen/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/zoom-pixel-editor-updates.md, quickstart.md (alle vorhanden); baut auf Spec 003 (EditorRoom/ZoomRoom/PixelRoom) und Spec 006 (Crank-Volldrehungs-Muster, Reset Frame/AD-032) auf — beide bereits implementiert

**Tests**: Headless-Tests (`lua tests/headless_tests.lua`) als Constitution V Gate 1 (MUSS mit "ALLE TESTS BESTANDEN" enden), Gate 2 (`pdc Source "Hans Dither.pdx"`) MUSS fehlerfrei durchlaufen — beide nach JEDER Implementierungs-Task. Wer einen Bug/eine Verhaltensänderung umsetzt, ergänzt im selben Zug einen Testfall (Constitution V). Manuelle Simulator-/Hardware-Szenarien aus quickstart.md als Ergänzung für Performance- und Crank-Gefühl-Aspekte.

**Organization**: Phasen nach User-Story-Priorität aus spec.md: US1 (P1, Zoom-Room-Performance) → US2 (P2, Pixel-Rotation) → US3 (P3, Clear Screen).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelisierbar (andere Dateien, keine offenen Abhängigkeiten)
- **[Story]**: US1 (Zoom-Room-Performance), US2 (Pixel-Rotation), US3 (Clear Screen)

## Path Conventions

Single project (Playdate-Lua): Quellcode unter `Source/`, Tests unter `tests/headless_tests.lua`, Architektur-Doku unter `arc42/` (bereits in der Planungsphase aktualisiert, siehe plan.md), Feature-Doku unter `specs/008-zoom-rotation-clearscreen/`.

---

## Phase 1: Setup

**N/A** — keine dedizierte Setup-Phase nötig. Alle drei User Stories sind Verhaltensänderungen an bereits bestehenden, funktionsfähigen Räumen (`ZoomRoom`, `PixelRoom`, `EditorRoom`); es entstehen keine neuen Dateien, kein neues Room-Gerüst, keine neue Build-/Test-Infrastruktur (Begründung: plan.md "Structure Decision").

---

## Phase 2: Foundational (Blocking Prerequisites)

**N/A** — keine gemeinsame Blocker-Infrastruktur nötig. Jede Story ändert eine EIGENE, von den anderen beiden Stories vollständig unberührte Datei (`ZoomRoom.lua` / `PixelRoom.lua` / `EditorRoom.lua`) — im Unterschied zu Spec 006 gibt es hier keine geteilte Datei mit mehreren Story-Berührungen. Alle drei Stories können daher vollständig unabhängig und parallel begonnen werden (siehe Dependencies unten).

---

## Phase 3: User Story 1 — Zoom Room ohne Ruckeln und Blockaden (Priority: P1) 🎯 MVP

**Goal**: `ZoomRoom:drawGrid()` ersetzt die Vollbild-Neuberechnung pro Interaktion durch einen einmalig aufgebauten Hintergrund-Cache plus ein kleines Änderungs-Set (research.md R1, AD-035, Contract ZR-01..03)

**Independent Test**: quickstart.md Szenario 1 (5s gehaltene Richtungstaste + Malstriche ohne wahrnehmbare Verzögerung, objektiver `getStats()`/Sampler-Nachweis)

### Implementation for User Story 1

- [X] T001 [US1] `Source/ZoomRoom.lua`: neue Modul-State-Felder `cachedBackground` (Image, initial `nil`), `changedCells` (Liste, initial `{}`), `backgroundDirty` (bool, initial `true`) (data-model.md Abschnitt 1); `backgroundDirty = true` setzen in `ZoomRoom:entered()`, `setFromEditorContext()`, `setNewTile()`, `updateExistingTile()` (Contract ZR-02)
- [X] T002 [US1] `Source/ZoomRoom.lua`: `paintCurrentCell()` erweitern — trägt die betroffene Zelle `{row, col}` in `changedCells` ein, falls noch nicht enthalten (keine Duplikate), via neue Hilfsfunktion `markCellChanged()` (data-model.md Abschnitt 1)
- [X] T003 [US1] `Source/ZoomRoom.lua`: `drawGrid()` umgebaut (depends on T001, T002) — neue Hilfsfunktion `drawCell(r,c)` (der bisherige Pro-Zelle-Zeichencode), `buildBackgroundCache()` ruft `drawCell()` für alle 576 Zellen einmalig per `gfx.pushContext(cachedBackground)`/`gfx.popContext()` auf (**korrigiert bei der Implementierung**: `cachedBackground` ist 400×240 inkl. Checkerboard-Seiten statt der ursprünglich geplanten 240×240-Variante, siehe data-model.md/ADR-035), danach `changedCells = {}`, `backgroundDirty = false`; `drawGrid()` zeichnet `cachedBackground:draw(0, 0)`, übermalt nur die Zellen aus `changedCells` via `drawCell()`, zeichnet zuletzt den Cursor (research.md R1, Contract ZR-01); Editier-/Commit-Logik (`beginStroke`, `collectEdits`, Dedup-Pfad) unverändert (Contract ZR-03). **Nutzer-gemeldeter Bug, nach initialem Abschluss gefunden und behoben**: `drawGrid()` leerte `changedCells` fälschlich nach JEDEM Redraw (nicht nur beim Cache-Aufbau) — der Cache selbst kennt die Änderung aber nie, daher fiel eine gemalte Zelle beim nächsten Redraw (z. B. reine Cursorbewegung) wieder auf den alten Cache-Stand zurück und war erst nach Verlassen/Wiederbetreten des Zoom Room sichtbar. `data-model.md`/`ADR-035` beschrieben das Verhalten bereits korrekt ("wird beim Cache-Aufbau geleert") — nur die Implementierung wich davon ab; behoben durch Entfernen des überzähligen `changedCells = {}` am Ende von `drawGrid()`.
- [X] T004 [US1] `tests/headless_tests.lua`: Testfälle ergänzt — reine Cursorbewegung ohne Bearbeitung löst 0 Fill-Aufrufe aus; ein Malstrich löst genau 1 Fill-Aufruf aus (Overlay statt Vollbild); **neuer Regressionstest** für den oben genannten Bug: ein WEITERER Redraw nach einem Malstrich, ohne erneutes Malen (z. B. reine Cursorbewegung), MUSS die bereits gemalte Zelle weiterhin korrekt zeigen statt auf den Cache-Stand zurückzufallen; `setNewTile()` invalidiert den Cache und erzwingt >100 Fill-Aufrufe beim nächsten Redraw (vollständiger Neuaufbau) — beide Gates grün (`lua tests/headless_tests.lua` → ALLE TESTS BESTANDEN, `pdc` fehlerfrei)
- [ ] T005 [US1] Validierung durchführen und protokollieren: quickstart.md Szenario 1 auf ECHTER HARDWARE (5s gehaltene Richtungstaste + Malstriche), inkl. `playdate.getStats()`/Sampler-Vergleich vor/nach dem Fix als objektiven Nachweis des CPU-Last-Rückgangs (research.md R1); Befund im Abschnitt "Status" von `specs/008-zoom-rotation-clearscreen/quickstart.md` notieren; Ergebnis fließt in die Risiko-Bewertung R-23 zurück (siehe T019)

**Checkpoint**: SC-001/SC-002 — Zoom Room reagiert ohne wahrnehmbare Verzögerung und ohne Navigationsblockade, objektiv nachgewiesen

---

## Phase 4: User Story 2 — Pixelbild per Crank-Volldrehung rotieren (Priority: P2)

**Goal**: Crank ohne gehaltene B-Taste im Pixel Room (bislang wirkungslos) akkumuliert `getCrankChange()` und rotiert `gridState` bei ±360° netto per exaktem 16×16-Index-Remap um 90° (research.md R2/R3, AD-036, Contract PR-01..04)

**Independent Test**: quickstart.md Szenario 2 (270° kein Effekt, 360° genau eine Rotation im Uhrzeigersinn, vier Rotationen ergeben wieder das Ausgangsbild, Rückwärtsdrehung gegen den Uhrzeigersinn, B+Crank-Zoomkette unverändert)

### Implementation for User Story 2

- [X] T006 [US2] `Source/PixelRoom.lua`: neues Feld `rotationAccumDegrees` (number, signiert, initial `0`), zurückgesetzt in `PixelRoom:setCurrentTile()` und defensiv in `PixelRoom:entered()` (data-model.md Abschnitt 2)
- [X] T007 [US2] `Source/PixelRoom.lua`: Funktionen `rotateGridClockwise()`/`rotateGridCounterClockwise()` implementiert — exakter Index-Remap auf `gridState` (16×16, 1-indiziert): `new[r][c] = old[17 - c][r]` (vorwärts) bzw. `new[r][c] = old[c][17 - r]` (rückwärts); neue temporäre Tabelle aufgebaut und `gridState` ersetzt, danach `needsRedraw = true` (data-model.md Abschnitt 3, research.md R3 — bewusst KEIN `image:rotatedImage()`/`drawRotated()`)
- [X] T008 [US2] `Source/PixelRoom.lua`: `update()` umgebaut (depends on T006, T007) — bei NICHT gehaltener B-Taste `playdate.getCrankChange()` gelesen und signiert in `rotationAccumDegrees` aufsummiert; bei `>= 360`/`<= -360` `rotateGridClockwise()`/`rotateGridCounterClockwise()` aufgerufen und Akkumulator um 360 korrigiert; bei gehaltener B-Taste bleibt der bestehende `getCrankTicks(4)`-Zoomkettenpfad UNVERÄNDERT — pro `update()` wird GENAU EINE der beiden Crank-Lese-APIs aufgerufen (Contract PR-01)
- [X] T009 [US2] `tests/headless_tests.lua`: Testfälle ergänzt — 270° löst keine Rotation aus; 360° dreht ein Eck-Testpixel exakt von oben-links nach oben-rechts; vier volle Umdrehungen ergeben wieder das Ausgangsbild; volle Rückwärtsdrehung dreht nach unten-links (CCW); B+Crank-Zoomkette (`getCrankTicks(4)`) bleibt unverändert grün (Regressionsschutz) — beide Gates grün
- [ ] T010 [US2] Validierung durchführen und protokollieren: quickstart.md Szenario 2 im Simulator UND auf Hardware (Crank-Gefühl kann vom Simulator-Slider abweichen), inkl. expliziter Regressionsprüfung der B+Crank-Zoomkette im selben Testlauf; Befund notieren

**Checkpoint**: SC-003/SC-004/SC-005 — volle Umdrehung dreht exakt 90°, Rundlauf über vier Rotationen bestätigt, keine Regression der Zoomkette

---

## Phase 5: User Story 3 — Aktiven Frame per "Clear Screen" leeren (Priority: P3)

**Goal**: "Clear Screen" ersetzt "Reset Frame" vollständig im Systemmenü; setzt alle 375 Tile-Indizes des aktiven Frames auf den Voll-Weiß-Basisindex (research.md R4, AD-037, Contract EM-01..03)

**Independent Test**: quickstart.md Szenario 3 (aktiver Frame vollständig weiß nach "clear screen", andere Frames unverändert, "reset frame" an keiner Stelle mehr auffindbar, idempotent auf bereits leerem Frame)

### Implementation for User Story 3

- [X] T011 [US3] `Source/EditorRoom.lua`: Funktion `resetCurrentFrameToPrevious()` VOLLSTÄNDIG entfernt (FR-011, AD-037 — im Unterschied zu `deleteCurrentFrame()`/AD-032 KEIN toter Code)
- [X] T012 [US3] `Source/EditorRoom.lua`: neue Funktion `clearCurrentFrame()` — setzt jeden der 375 Tile-Indizes von `imageData.frames[currentFrame]` auf den Basis-Index `1` (Voll-Weiß, `ImageStoreCodec`-Invariante), gefolgt von `updateTilemapFrame()` + `needsRedraw = true` (data-model.md Abschnitt 4)
- [X] T013 [US3] `Source/EditorRoom.lua`: `buildSystemMenu()` umgebaut (depends on T011, T012) — Menüpunkt `"reset frame"` durch `"clear screen"` ersetzt (ruft `clearCurrentFrame()` auf); `"save + exit"` und `"show grid"` unverändert (Contract EM-01)
- [X] T014 [US3] `tests/headless_tests.lua`: Testfälle ersetzt — altes "Reset Frame"-Testszenario vollständig durch neues "Clear Screen"-Szenario ausgetauscht: alle 375 Indizes auf `1` gesetzt, anderer Frame unverändert, Menü enthält `"clear screen"` und NICHT mehr `"reset frame"`, idempotent auf bereits leerem Frame — beide Gates grün
- [ ] T015 [US3] Validierung durchführen und protokollieren: quickstart.md Szenario 3 im Simulator, inkl. Prüfung, dass `"reset frame"` an keiner Stelle der Oberfläche mehr erscheint; Befund notieren

**Checkpoint**: SC-006/SC-007 — Frame in einer Aktion vollständig leerbar, andere Frames unberührt, "Reset Frame" vollständig entfernt

---

## Phase 6: Polish & Cross-Cutting Concerns (iSAQB-Preset)

**Purpose**: Architektur-Konsistenzprüfung, Audit-Evidenz, Risiko-Review-Abschluss, finaler Architektur-Review (Constitution III / iSAQB-Preset). Die arc42-Kapitel-Updates und die drei ADRs (ADR-035/036/037) wurden bereits WÄHREND der Planungsphase geschrieben (`/speckit-plan`, auf explizite Anforderung) — diese Phase prüft nur noch die Konsistenz zwischen Doku und tatsächlicher Implementierung, sie erzeugt keine neue arc42-Prosa.

- [X] T016 [P] Architektur-Konsistenz-Prüfung: durchgeführt — drei Abweichungen zwischen Planung und tatsächlicher Implementierung gefunden und korrigiert: (1) `cachedBackground` ist 400×240 inkl. Checkerboard-Seiten statt der geplanten 240×240-Variante (`data-model.md`, `ADR-035`, `arc42/05-bausteinsicht.md`, `arc42/06-laufzeitsicht.md`, `quickstart.md`, `contracts/zoom-pixel-editor-updates.md` korrigiert), (2) es gibt keinen separaten `showGridLines`-Live-Toggle innerhalb einer laufenden Zoom-Room-Sitzung (nur über `setFromEditorContext()`) — an denselben Stellen korrigiert, (3) neue Hilfsfunktionen `drawCell()`/`buildBackgroundCache()`/`markCellChanged()` in `arc42/05-bausteinsicht.md` ergänzt. Alle übrigen arc42-Kapitel (09, 10, 11, 12) stimmten bereits mit der Implementierung überein (Constitution III)
- [X] T017 `docs/architecture/`-Audit-Evidenz: **N/A bestätigt** — dieser Pfad wird im Projekt ausschließlich für das Backend-Sicherheitsreview genutzt (Spec 005/007, `docs/architecture/security-review-backend.md`); Spec 008 ist rein clientseitig ohne Backend-/Netzwerk-Berührung (bereits in spec.md und plan.md Architecture Governance begründet); keine weitere Aktion nötig. Re-Evaluierungs-Trigger: falls künftig doch Backend-/Netzwerk-Berührungspunkte entstehen (aktuell nicht erwartet)
- [X] T018 Architektur-Review-Durchlauf: durchgeführt — alle zehn Contract-Klauseln (`ZR-01..03`, `PR-01..04`, `EM-01..03`) einzeln gegen die Implementierung geprüft, ZR-02 dabei um die unter T016 gefundene `showGridLines`-Korrektur präzisiert; Constitution Check aus `plan.md` bestätigt PASS für alle 5 Prinzipien, keine neuen Abweichungen; Secure-Architecture: N/A erneut bestätigt (rein lokale Rendering-/Editier-/Menü-Änderungen, keine Netzwerk-/Auth-/Persistenzformat-Berührung)
- [ ] T019 [P] Risiko-Review abschließen: **noch nicht final abschließbar** — der objektive Hardware-Nachweis aus T005 (`getStats()`/Sampler) steht noch aus (erfordert echtes Playdate-Gerät, außerhalb der Möglichkeiten dieses Implementierungslaufs); `arc42/11-risiken-und-technische-schulden.md` R-23 daher ehrlich auf **"Offen"** gesetzt (nicht vorschnell "mitigiert" behauptet) — Owner: Entwickler, Re-Evaluierungs-Trigger: Abschluss von T005 auf echter Hardware

**Checkpoint**: Alle drei Stories unabhängig funktionsfähig und headless-testverifiziert (`lua tests/headless_tests.lua` → ALLE TESTS BESTANDEN, `pdc` fehlerfrei); arc42/ADR-Dokumentation deckt sich nach T016-Korrekturen mit dem Implementierungsstand; Audit-Evidenz-Checkpoints entschieden bis auf den ehrlich offen ausgewiesenen Hardware-Nachweis (R-23/T005/T019)

---

## Dependencies

```text
Spec 003/006 (bereits implementiert) ─┐
Phase 1/2 (N/A) → US1 (P1, ZoomRoom.lua)   ┐
                  US2 (P2, PixelRoom.lua)   ┤─ vollstaendig unabhaengig, KEINE geteilte Datei
                  US3 (P3, EditorRoom.lua)  ┘  (im Unterschied zu Spec 006)
→ Phase 6 (Polish/Konsistenzpruefung, nach allen gewuenschten Stories)
```

- US1 → keine Abhängigkeiten zu anderen Stories (nur `ZoomRoom.lua`); T003 hängt von T001/T002 ab
- US2 → keine Abhängigkeiten zu anderen Stories (nur `PixelRoom.lua`); T008 hängt von T006/T007 ab; MUSS die bestehende B+Crank-Zoomkette regressionsfrei erhalten (T009/T010)
- US3 → keine Abhängigkeiten zu anderen Stories (nur `EditorRoom.lua`); T013 hängt von T011/T012 ab
- Phase 6 → nach Abschluss aller umgesetzten Stories (T019 hängt inhaltlich von T005 ab — Risiko-Review benötigt das Hardware-Messergebnis)

## Parallel Execution Examples

- **Cross-Story**: US1 (`ZoomRoom.lua`), US2 (`PixelRoom.lua`) und US3 (`EditorRoom.lua`) können von unterschiedlichen Personen VOLLSTÄNDIG parallel begonnen werden — keine Datei-Kollisionsgefahr zwischen den drei Stories; einzige gemeinsame Datei ist `tests/headless_tests.lua` (T004/T009/T014, sequenziell mergen, daher bewusst ohne [P]-Markierung)
- **Innerhalb der Stories**: T001–T003 (US1), T006–T008 (US2) und T011–T013 (US3) ändern jeweils dieselbe Datei ihrer Story und sind daher sequenziell statt parallel auszuführen (keine [P]-Markierung); echte Parallelität besteht nur ZWISCHEN den drei Stories
- **Phase 6**: T016 ∥ T019 (unterschiedliche Kapitel/Zweck), T017/T018 können parallel zu beiden laufen

## Implementation Strategy

### MVP First (User Story 1 allein, P1)

1. Phase 1/2 entfallen (N/A)
2. Phase 3 (US1): Zoom-Room-Redraw-Cache
3. **STOP and VALIDATE**: quickstart.md Szenario 1 auf echter Hardware, inkl. `getStats()`/Sampler-Nachweis
4. Das dringendste, vom Projektinhaber als "muss unbedingt verbessert werden" markierte Problem ist damit bereits behoben und unabhängig auslieferbar

### Incremental Delivery

1. US1 (P1) → Test unabhängig → Zoom-Room-Performance-Fix ausgeliefert (MVP!)
2. US2 (P2) → Test unabhängig → Pixel-Rotation ausgeliefert
3. US3 (P3) → Test unabhängig → Clear Screen ausgeliefert
4. Phase 6 (Polish/Konsistenzprüfung) → arc42/ADR-Konsistenz, Architektur-Review, Risiko-Review-Abschluss

### Parallel Team Strategy

Mit mehreren Entwicklern: Team A übernimmt US1 (`ZoomRoom.lua`), Team B übernimmt US2 (`PixelRoom.lua`), Team C übernimmt US3 (`EditorRoom.lua`) — alle drei Dateien sind vollständig unabhängig, keine Merge-Koordination zwischen den Stories nötig (nur `tests/headless_tests.lua` sequenziell mergen). Solo-Entwicklung (aktueller Projektstand): Reihenfolge P1 → P2 → P3 wie oben.

## Audit-Evidenz-Checkpoints (iSAQB-Preset)

- [X] Architektur-Sichten aktualisiert UND gegen die Implementierung verifiziert (T016): `arc42/05-bausteinsicht.md`, `arc42/06-laufzeitsicht.md` (6.13–6.15), `arc42/09-architekturentscheidungen.md` (9.23–9.25), `arc42/10-qualitaetsanforderungen.md` (QS-19/20), `arc42/11-risiken-und-technische-schulden.md` (R-23/R-24), `arc42/12-glossar.md` — drei Abweichungen gefunden und korrigiert (Cache-Größe 400×240 statt 240×240, kein separater `showGridLines`-Live-Toggle, neue Hilfsfunktionsnamen ergänzt). Evidenz: Feature-Branch-Diff.
- [X] ADRs erstellt (Planungsphase) und in T018 gegen die Implementierung geprüft: `arc42/adr/ADR-035-Zoom-Room-Redraw-Cache.md`, `arc42/adr/ADR-036-Pixel-Rotation-Index-Remap.md`, `arc42/adr/ADR-037-Clear-Screen-ersetzt-Reset-Frame.md`, referenziert in Kap. 9 (9.23–9.25). Evidenz: die drei genannten Dateien.
- [X] `docs/architecture/`-Checkpoint: **N/A bestätigt** (T017) — dieser Pfad wird ausschließlich für das Backend-Sicherheitsreview genutzt (Spec 005/007); Spec 008 hat keinen Backend-/Netzwerk-Bezug.
- [ ] Risiko-/Schulden-Review: R-24 (Wegfall der Frame-Schutzfunktion) ist **Akzeptiert**, keine weitere Aktion. R-23 (Zoom-Room-Ursachenbefund) bleibt ehrlich **Offen** — Implementierung und Headless-Tests sind grün, aber der objektive Hardware-Nachweis (`getStats()`/Sampler) steht noch aus. Owner: Entwickler; Re-Evaluierungs-Trigger: Abschluss von T005 auf echter Hardware.
- [X] Architektur-Review durchgeführt (T018): alle 10 Contract-Klauseln (`ZR-01..03`, `PR-01..04`, `EM-01..03`) einzeln gegen die Implementierung geprüft, Constitution Check bestätigt PASS für alle 5 Prinzipien.
- [X] Secure-Architecture: N/A bestätigt (T018) — rein lokale Rendering-/Editier-/Menü-Änderungen, keine Netzwerk-/Auth-/Datenspeicherungs-Berührung.
- [ ] Verbleibend offen: T005/T010/T015 (manuelle Simulator-/Hardware-Validierung je Story) sowie T019 (finale Risiko-Bewertung R-23) — erfordern interaktiven Zugriff auf den Playdate Simulator bzw. echte Hardware, außerhalb der Möglichkeiten dieser Implementierungssitzung. Code, Tests (headless) und Build sind vollständig und grün; nur die hardware-nahe Validierung steht aus.
