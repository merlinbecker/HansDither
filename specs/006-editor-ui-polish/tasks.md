# Tasks: Editor-UI-Verbesserungen — Bauchbinde, Frame-Navigation, Titel- und Zoom-Darstellung

**Input**: Design documents from `/specs/006-editor-ui-polish/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/editor-room-ui-polish.md, quickstart.md (alle vorhanden); baut auf Spec 001 (ImageStore/ImageStoreCodec), Spec 002 (SelectionRoom), Spec 003 (EditorRoom/ZoomRoom/PixelRoom) auf — alle bereits implementiert

**Tests**: Headless-Tests (`lua tests/headless_tests.lua`) als Constitution V Gate 1 (MUSS mit "ALLE TESTS BESTANDEN" enden), Gate 2 (`pdc Source "Hans Dither.pdx"`) MUSS fehlerfrei durchlaufen — beide nach JEDER Implementierungs-Task. Wer einen Bug/eine Verhaltensänderung umsetzt, ergänzt im selben Zug einen Testfall (Constitution V). Manuelle Simulator-/Hardware-Szenarien aus quickstart.md als Ergänzung für rein visuelle/zeitbasierte Anteile.

**Organization**: Phasen nach User-Story-Priorität aus spec.md: US1 (P1, Zoom-Pixel) → US2 (P1, Crank-Volldrehung) → US3 (P2, Bauchbinde) → US4 (P2, Reset Frame) → US5 (P3, Pause-Ansicht) → US6 (P3, Titelscreen-Animation).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelisierbar (andere Dateien, keine offenen Abhängigkeiten)
- **[Story]**: US1 (Zoom-Pixel), US2 (Crank-Volldrehung), US3 (Bauchbinde), US4 (Reset Frame), US5 (Pause-Ansicht), US6 (Titelscreen-Animation)

## Path Conventions

Single project (Playdate-Lua): Quellcode unter `Source/`, Tests unter `tests/headless_tests.lua`, Architektur-Doku unter `arc42/`, Feature-Doku unter `specs/006-editor-ui-polish/`.

---

## Phase 1: Setup

**N/A** — keine dedizierte Setup-Phase nötig. Alle sechs User Stories sind Verhaltensänderungen an bereits bestehenden, funktionsfähigen Räumen (`EditorRoom`, `ZoomRoom`, `SelectionRoom`); es entstehen keine neuen Dateien, kein neues Room-Gerüst, keine neue Build-/Test-Infrastruktur (Begründung: plan.md "Structure Decision").

---

## Phase 2: Foundational (Blocking Prerequisites)

**N/A** — keine gemeinsame Blocker-Infrastruktur nötig. Jede Story ändert unabhängige Funktionen/Codeabschnitte innerhalb bereits geladener Module (`imageData`, `RoomOperation`, `Bauchbinde` als Zeichen-Helfer bleiben unverändert wiederverwendbar). Einzige geteilte Datei mit mehreren Story-Berührungen ist `Source/EditorRoom.lua` (US2/US3/US4/US5) — die betroffenen Funktionen sind aber disjunkt (`handleCrank`, Bauchbinde-Draw, `buildSystemMenu`, `buildPauseMenuImage`), daher kein echter Blocker, nur sequenzielle Bearbeitung derselben Datei (siehe Dependencies unten).

---

## Phase 3: User Story 1 — Zoom-View zeigt den Bildhintergrund pixelgenau (Priority: P1) 🎯 MVP

**Goal**: Unbearbeitete Zoom-Zellen zeigen die vier echten 2×2-Quellpixel statt einer einzelnen Stichprobe (research.md R2, Contract CR-04)

**Independent Test**: quickstart.md Szenario 1 (Schachbrett-Tile im ZoomRoom, Vier-Quadranten-Darstellung vor jeder Bearbeitung)

### Implementation for User Story 1

- [X] T001 [US1] `Source/ZoomRoom.lua`: `drawGrid()` um Subpixel-Rendering erweitern — für Zellen mit `gridState[r][c] == baselineGrid[r][c]` vier Einzelpixel aus `slot.editedImage or slot.originalImage` sampeln und als vier 5×5-Quadranten der 10×10-Zelle zeichnen; bearbeitete Zellen (Wert weicht ab) bleiben flächig wie bisher (data-model.md Abschnitt 3, Contract CR-04); Editier-/Commit-Logik (`beginStroke`, `paintCurrentCell`, `collectEdits`) bleibt unverändert (FR-008)
- [X] T002 [US1] `tests/headless_tests.lua`: Testfall ergänzen — Slot mit gemischtem 2×2-Quellmuster (z. B. 2 schwarz/2 weiß) vor Bearbeitung zeigt beim Rendern vier unterschiedliche Subpixel-Werte; nach einem simulierten Malstrich auf derselben Zelle ist sie einfarbig (Constitution V)
- [ ] T003 [US1] Validierung durchführen und protokollieren: quickstart.md Szenario 1 im Simulator; Befund im Abschnitt "Status" von `specs/006-editor-ui-polish/quickstart.md` notieren

**Checkpoint**: SC-003 — Zoom-View zeigt für jede Zelle alle vier Quellpixel, bis sie bearbeitet wird

---

## Phase 4: User Story 2 — Frame-Wechsel erfordert eine volle Crank-Umdrehung (Priority: P1)

**Goal**: Frame-Navigation wechselt von `getCrankTicks(4)` (90°-Rasterung) auf einen signierten `getCrankChange()`-Gradakkumulator, der erst bei ±360° netto auslöst (research.md R1, Contract CR-01)

**Independent Test**: quickstart.md Szenario 2 (270° kein Wechsel, 360° genau ein Wechsel, Richtungswechsel vor 360° kein Wechsel, Einklappen mitten in Drehung ohne Wirkung)

### Implementation for User Story 2

- [X] T004 [US2] `Source/EditorRoom.lua`: neues Feld `crankAccumDegrees` (data-model.md Abschnitt 1); `handleCrank()` umbauen — bei NICHT gehaltenem B `playdate.getCrankChange()` lesen und aufsummieren, bei `>=360`/`<=-360` `tickForward()`/`tickBackward()` auslösen und um 360 korrigieren (kein Reset auf 0); bei gehaltenem B bleibt `crankAccumDegrees` unverändert und die bestehende `getCrankTicks(4)`-Zoomkette läuft exakt wie zuvor weiter (Contract CR-01 — pro `update()` wird GENAU EINE der beiden Crank-Lese-APIs aufgerufen, niemals beide) (FR-004/005/006)
- [X] T005 [US2] `tests/headless_tests.lua`: Testfälle ergänzen — 270°+90° (mockbares `getCrankChange` mit mehreren Aufrufen) löst genau einen `tickForward`-Aufruf aus; 270° gefolgt von -90° (netto 180°) löst KEINEN Wechsel aus; wiederholte kleine Deltas unter 360° ändern `currentFrame` nicht; B-gehalten-Pfad (`getCrankTicks(4)`-Zoomkette) bleibt unverändert grün (Regressionsschutz, Constitution V)
- [ ] T006 [US2] Validierung durchführen und protokollieren: quickstart.md Szenario 2 im Simulator UND auf Hardware (Crank-Gefühl), inkl. expliziter Regressionsprüfung der B+Crank-Zoomkette im selben Testlauf; Befund in `specs/006-editor-ui-polish/quickstart.md` notieren

**Checkpoint**: SC-001 — kein ungewollter Frame-Wechsel durch Teildrehungen, Zoomkette weiterhin unverändert funktionsfähig

---

## Phase 5: User Story 3 — Bauchbinde blendet sich automatisch aus und weicht dem Cursor aus (Priority: P2)

**Goal**: Frame-Positions-Bauchbinde blendet nach 5s Inaktivität aus und erscheint cursor-abgewandt (research.md R3, Contract CR-02/CR-03)

**Independent Test**: quickstart.md Szenario 3 (Ausblenden nach 5s, sofortiges Wiedereinblenden bei Eingabe, Seiten-Logik)

### Implementation for User Story 3

- [X] T007 [US3] `Source/EditorRoom.lua`: neues Feld `lastActivityMs` (data-model.md Abschnitt 2), initialisiert in `entered()`; in `moveCursor()`, `beginStroke()`, `pipette()`, sowie an beiden Crank-Lesepunkten aus T004 (`change ~= 0` bzw. `crankTicks ~= 0`) `lastActivityMs = playdate.getCurrentTimeMilliseconds()` setzen (FR-002)
- [X] T008 [US3] `Source/EditorRoom.lua`: `draw()` anpassen — Frame-Positions-Bauchbinde (`bauchbinde:drawBottom("Frame n/m", ...)`) nur zeichnen, wenn `(nowMs - lastActivityMs) < 5000` (FR-001); Seite dynamisch `cursor.x <= 12 and "right" or "left"` statt fest "right" (FR-003); Status-Bauchbinde (`statusMessage`, immer "left") bleibt unverändert unabhängig davon
- [X] T009 [US3] `tests/headless_tests.lua`: Testfälle ergänzen — Bauchbinde unsichtbar nach mockbarer Zeit ≥5000ms seit letzter Eingabe; sofort wieder sichtbar nach simulierter Eingabe; Seite `"right"` bei `cursor.x <= 12`, `"left"` bei `cursor.x > 12` (Constitution V)
- [ ] T010 [US3] Validierung durchführen und protokollieren: quickstart.md Szenario 3 im Simulator; Befund notieren

**Checkpoint**: SC-002 — Bauchbinde blendet zuverlässig aus und positioniert sich cursor-abgewandt

---

## Phase 6: User Story 4 — Frame per "Reset Frame" auf den Vorgänger zurücksetzen (Priority: P2)

**Goal**: Neuer Menüpunkt "reset frame" kopiert den Vorgänger-Frame elementweise; ersetzt "delete frame" im Systemmenü (research.md R7, AD-032, Contract CR-08)

**Independent Test**: quickstart.md Szenario 4 (Frame 2 = Frame 1 nach Reset, no-op auf Frame 1, "delete frame" nicht mehr im Menü)

### Implementation for User Story 4

- [X] T011 [US4] `Source/EditorRoom.lua`: neue Funktion `resetCurrentFrameToPrevious()` — no-op bei `currentFrame == 1` (FR-015); sonst `imageData.frames[currentFrame][i] = imageData.frames[currentFrame - 1][i]` für alle 375 Indizes, gefolgt von `updateTilemapFrame()` + `needsRedraw = true` (FR-014)
- [X] T012 [US4] `Source/EditorRoom.lua`: `buildSystemMenu()` umbauen — Menüpunkt `"delete frame"` durch `"reset frame"` ersetzen (ruft `resetCurrentFrameToPrevious()` auf); `"save + exit"` und `"show grid"` unverändert; `deleteCurrentFrame()` bleibt als Funktion im Code bestehen, verliert aber ihren einzigen Aufrufer (AD-032, Contract CR-08 — bewusste, dokumentierte Konsequenz)
- [X] T013 [US4] `tests/headless_tests.lua`: Testfälle ergänzen — `resetCurrentFrameToPrevious()` kopiert Frame-Inhalt exakt vom Vorgänger; no-op auf Frame 1 (Inhalt unverändert); Menü enthält `"reset frame"` und NICHT mehr `"delete frame"` (Constitution V)
- [ ] T014 [US4] Validierung durchführen und protokollieren: quickstart.md Szenario 4 im Simulator, inkl. Prüfung, dass "delete frame" nicht mehr erscheint; Befund notieren

**Checkpoint**: SC-006 — Frame-Reset in unter 3 Sekunden ohne manuelles Neuzeichnen; Menü zeigt "reset frame" statt "delete frame"

---

## Phase 7: User Story 5 — Erweiterte Kontext-/Pause-Ansicht mit Tile-Übersicht (Priority: P3)

**Goal**: `playdate.setMenuImage()` + `playdate.gameWillPause()` zeigen beim Pausieren ein 12×10-Tile-Raster, Gesamtzahl und Frame-Anzahl im linken 200px-Bereich (research.md R4, AD-031, Contract CR-05..CR-07)

**Independent Test**: quickstart.md Szenario 5 (30 Tiles/4 Frames korrekt angezeigt; >120 Tiles korrekt trunkiert)

### Implementation for User Story 5

- [X] T015 [US5] `Source/EditorRoom.lua`: neue Funktion `EditorRoom:buildPauseMenuImage() -> playdate.graphics.image | nil` — 400×240-Bild, Inhalt ausschließlich in `x ∈ [0,200)` (Contract CR-05); Layout gemäß data-model.md Abschnitt 4 (Titelzeile, 12×10-Tile-Raster ab `x=8,y=26`, Zellgröße 14×14, Gesamtzahl bei `y=172`, Frame-Anzahl bei `y=188`); `totalDistinctTileCount` durch Iteration über alle `imageData.frames[*]`-Einträge berechnen (Set unterschiedlicher Tile-Indizes, NICHT `imagetable:getLength()`, Contract CR-06); bei >120 nur die ersten 120 (aufsteigender Index) als Vorschau zeichnen, Gesamtzahl bleibt vollständig (Contract CR-07, FR-013); `nil`, wenn kein `imageData` geladen ist
- [X] T016 [US5] `Source/main.lua`: neuer Hook `playdate.gameWillPause()` — ruft `EditorRoom:buildPauseMenuImage()` und `playdate.setMenuImage(img)` auf, wenn `currentRoom` `EditorRoom`, `ZoomRoom` oder `PixelRoom` ist; sonst `playdate.setMenuImage(nil)` (Contract Abschnitt 4)
- [X] T017 [US5] `tests/headless_tests.lua`: Testfälle ergänzen — `totalDistinctTileCount` zählt nur tatsächlich in `frames[*]` referenzierte Indizes (nicht ungenutzte Imagetable-Einträge); Truncation bei >120 unterschiedlichen Tiles liefert weiterhin die korrekte Gesamtzahl; `buildPauseMenuImage()` liefert `nil` ohne geladenes Bild (Constitution V)
- [ ] T018 [US5] Validierung durchführen und protokollieren: quickstart.md Szenario 5 im Simulator (30-Tile-Bild + >120-Tile-Bild), inkl. Performance-Prüfung ("Pause-Bild wird nicht jeden Frame neu berechnet"); Befund notieren

**Checkpoint**: SC-005 — Pause-Ansicht zeigt korrekte Gesamtzahl + Frame-Anzahl unabhängig von der Bildgröße

---

## Phase 8: User Story 6 — Titelscreen zeigt animierten Hintergrund mit VHS-Effekt (Priority: P3)

**Goal**: Vollflächige Animation des selektierten Eintrags via Lazy-Load + VHS-Dither-Störeffekt; alle anderen Einträge bleiben statische Kreise (research.md R5/R6, Contract CR-09..CR-11)

**Independent Test**: quickstart.md Szenario 6 (3-Frame-Bild animiert vollflächig mit VHS-Effekt; andere Einträge bleiben Kreise; 1-Frame-Bild als Standbild mit Effekt)

### Implementation for User Story 6

- [X] T019 [US6] `Source/SelectionRoom.lua`: neue Felder `fullImageData`/`fullImageLoadOperation`/`fullImageForId` (data-model.md Abschnitt 6); bei Selektionswechsel laufenden Ladevorgang für den verlassenen Eintrag verwerfen, neuen `RoomOperation`-Ladevorgang über `ImageStoreCodec.newLoadOperation(id)` für den neu selektierten Eintrag starten (Contract CR-09); solange `fullImageData == nil` bleibt das bestehende statische Kreis-Rendering für diesen Eintrag sichtbar (kein Leerbild/Sprung)
- [X] T020 [US6] `Source/SelectionRoom.lua`: Vollbild-Rendering für den selektierten Eintrag nach erfolgreichem Laden — `titleAnimFrame`/`titleAnimTimerMs` (data-model.md Abschnitt 6), Frames in derselben Reihenfolge wie im Editor durchlaufen, 400×240 vollflächig gezeichnet; bei genau 1 Frame kein Timer-Wechsel, `titleAnimFrame` bleibt `1` (Contract CR-11, FR-016); alle anderen Einträge unverändert über den bestehenden `drawImageThumbnail`/`createCircularThumbnail`-Pfad (Contract CR-10, FR-018)
- [X] T021 [US6] `Source/SelectionRoom.lua`: VHS-Störeffekt über dem Vollbild-Hintergrund via `gfx.setPattern(pattern, xPhase, yPhase)` mit zeitlich wechselnder Phase (research.md R5 — **während der Implementierung korrigiert**: `gfx.setDitherPattern` hat laut SDK-Doku KEINEN Phasen-Offset, `setPattern` ist die reale Funktion dafür; data-model.md Abschnitt 5); konkrete Parameter (`VHS_PATTERN`, `VHS_PHASE_INTERVAL_MS = 80`) als Konstanten in `SelectionRoom.lua` festgelegt, finale visuelle Kalibrierung bleibt offen (FR-017)
- [X] T022 [US6] `tests/headless_tests.lua`: Testfall ergänzt — 1-Frame-Fall löst keinen Frame-Wechsel-Timer aus (`titleAnimFrame` bleibt `1`, auch nach weit verstrichener Zeit); Selektionswechsel VOR Abschluss verwirft den alten Ladevorgang, nur der neue Eintrag wird tatsächlich geladen (Constitution V; rein visuelle Aspekte wie der Muster-Effekt selbst bleiben manuell in quickstart.md)
- [ ] T023 [US6] Validierung durchführen und protokollieren: quickstart.md Szenario 6 im Simulator (inkl. schnelles Selektions-Durchschalten, 1-Frame-Fall, VHS-Kalibrierung "sichtbar aber nicht aufdringlich"); Befund notieren

**Checkpoint**: SC-004 — vollständiger animierter Bildinhalt des selektierten Eintrags ohne Editor-Aufruf erkennbar; alle sechs User Stories jetzt unabhängig funktionsfähig

---

## Phase 9: Polish & Cross-Cutting Concerns (iSAQB-Preset)

**Purpose**: Architektur-Evidenz, ADR-Dokumentation, Risiko-Review, Architektur-Review (Constitution III / iSAQB-Preset)

- [X] T024 [P] arc42-Ist-Kapitel aktualisieren: `arc42/05-bausteinsicht.md` (EditorRoom/ZoomRoom/SelectionRoom-Änderungen, neuer `main.lua`-Hook), `arc42/06-laufzeitsicht.md` (neue Laufzeitszenarien: Crank-Volldrehungs-Akkumulation, Pause-Bild-Aufbau bei `gameWillPause`, Titelscreen-Lazy-Load-Animation), `arc42/12-glossar.md` ("Kontext-/Pause-Ansicht" neu, "Bauchbinde"-Eintrag um Sichtbarkeitslogik präzisieren) — Evidenz: Feature-Branch-Diff (Constitution III)
- [X] T025 [P] `arc42/adr/ADR-031-Pause-Ansicht-setMenuImage.md` neu anlegen: Entscheidung "Kontext-/Pause-Ansicht via `playdate.setMenuImage()` + `playdate.gameWillPause()` statt eigenem Pause-Screen", Hintergrund (3-Slot-Limit, natives Menü ohne Grafikfähigkeit), verworfene Alternativen (eigener Room, Menü-Konsolidierung) — Inhalt aus research.md R4/plan.md AD-031 übernehmen
- [X] T026 [P] `arc42/adr/ADR-032-Reset-Frame-statt-Delete-Frame-im-Menue.md` neu anlegen: Entscheidung "delete frame" → "reset frame" im Systemmenü (Projektinhaber-Vorgabe), Hintergrund (kein freier Slot, keine kollisionsfreie Chord), Konsequenz (`deleteCurrentFrame()` ohne Menü-Aufrufer) — Inhalt aus research.md R7/plan.md AD-032 übernehmen
- [X] T027 `arc42/09-architekturentscheidungen.md` pflegen: AD-031/AD-032 als Referenz auf die neuen ADR-Dateien (T025/T026) eintragen
- [X] T028 `arc42/11-risiken-und-technische-schulden.md` pflegen: neues Risiko "Titelscreen-Lazy-Load-Überlappung bei schnellem Selektionswechsel" (Mitigation: T019, verworfener Ladevorgang) sowie "Crank-Dual-Path-Regression (`getCrankChange`/`getCrankTicks` im selben `update()`)" (Mitigation: T004/T005) eintragen, mit Verweis auf die jeweilige Mitigations-Task
- [X] T029 Architektur-Review-Durchlauf: Umsetzung gegen `contracts/editor-room-ui-polish.md` (CR-01 bis CR-11) und den Constitution Check aus `specs/006-editor-ui-polish/plan.md` prüfen; Abweichungen im Constitution-Check-Abschnitt von `plan.md` notieren; Secure-Architecture: N/A bestätigen (rein lokale UI-Änderungen, keine Netzwerk-/Auth-/Datenspeicherungs-Berührung, bereits in plan.md begründet)

---

## Dependencies

```text
Spec 001/002/003 (bereits implementiert) ─┐
Phase 1/2 (N/A) → US1 (P1) ┐
                  US2 (P1) ┤─ unabhängig voneinander, gemeinsame Datei EditorRoom.lua nur bei US2/US3/US4/US5
                  US3 (P2) ┤  (disjunkte Funktionen, sequenziell statt blockierend)
                  US4 (P2) ┤
                  US5 (P3) ┤
                  US6 (P3) ┘  (nur SelectionRoom.lua, komplett unabhängig)
→ Phase 9 (Polish/Evidenz, nach allen gewünschten Stories)
```

- US1 → keine Abhängigkeiten zu anderen Stories (nur `ZoomRoom.lua`)
- US2 → keine Abhängigkeiten zu anderen Stories; ändert `EditorRoom:handleCrank()`, MUSS die bestehende B+Crank-Zoomkette regressionsfrei erhalten (T005/T006)
- US3 → keine Abhängigkeiten zu anderen Stories; ändert `EditorRoom:draw()`/Eingabe-Handler, überschneidet sich in derselben Datei mit US2/US4/US5, aber disjunkte Funktionen — sequenzielle statt blockierende Bearbeitung empfohlen, wenn eine Person umsetzt
- US4 → keine funktionalen Abhängigkeiten; T012 setzt AD-032-Entscheidung voraus (bereits getroffen, siehe plan.md)
- US5 → keine Abhängigkeiten zu anderen Stories; T016 (`main.lua`) hängt von T015 (`buildPauseMenuImage()` muss existieren) ab
- US6 → keine Abhängigkeiten zu anderen Stories; T020/T021 hängen von T019 (Lazy-Load-Grundgerüst) ab
- Phase 9 → nach Abschluss aller umgesetzten Stories (ADRs/arc42 referenzieren finale Implementierungsdetails, insb. T021s Dither-Kalibrierung)

## Parallel Execution Examples

- **Cross-Story**: US1 (`ZoomRoom.lua`), US6 (`SelectionRoom.lua`) und die ersten Schritte von US2/US3/US4/US5 (`EditorRoom.lua`, aber unterschiedliche Funktionen) können von unterschiedlichen Personen parallel begonnen werden — einzige echte Datei-Kollisionsgefahr ist `Source/EditorRoom.lua` bei gleichzeitiger Bearbeitung von US2/US3/US4/US5 UND `tests/headless_tests.lua` bei jeder Story (sequenziell mergen)
- **Phase 9**: T024 ∥ T025 ∥ T026 (unterschiedliche Dateien: drei arc42-Kapitel bzw. zwei neue ADR-Dateien), danach T027/T028 (referenzieren die neuen ADR-Dateien)

## Implementation Strategy

### MVP First (User Story 1 + 2, beide P1)

1. Phase 1/2 entfallen (N/A)
2. Phase 3 (US1): Zoom-Pixel-Korrektheit
3. Phase 4 (US2): Crank-Volldrehung
4. **STOP and VALIDATE**: quickstart.md Szenario 1 + 2, inkl. Zoomketten-Regressionsprüfung
5. Beide P1-Korrekturen sind unabhängig voneinander lieferbar — Reihenfolge zwischen US1/US2 beliebig vertauschbar

### Incremental Delivery

1. US1 + US2 (P1) → Test unabhängig → MVP-Korrekturen ausgeliefert
2. US3 + US4 (P2) → Test unabhängig → Bedienkomfort-Verbesserungen
3. US5 + US6 (P3) → Test unabhängig → Zusatz-Ansichten
4. Phase 9 (Polish/Evidenz) → arc42/ADR-Dokumentation, Architektur-Review

### Parallel Team Strategy

Mit mehreren Entwicklern: Team A übernimmt US1 (`ZoomRoom.lua`) + US6 (`SelectionRoom.lua`, komplett kollisionsfrei), Team B übernimmt US2/US3/US4/US5 sequenziell (alle in `EditorRoom.lua`, disjunkte Funktionen aber dieselbe Datei — Merge-Koordination nötig). Solo-Entwicklung (aktueller Projektstand): Reihenfolge wie oben, ein Story-Durchlauf nach dem anderen.

## Audit-Evidenz-Checkpoints (iSAQB-Preset)

- [X] Architektur-Sichten aktualisiert: T024 — `arc42/05-bausteinsicht.md` (Baustein-Tabelle + 5.2.1-5.2.4 Interne Logik), `arc42/06-laufzeitsicht.md` (6.3 aktualisiert, neue Abschnitte 6.10-6.12), `arc42/08-querschnittliche-konzepte.md` (Konzept "zeitbasierte Sichtbarkeits-Übergänge" ergänzt, löst das "ggf." aus der Planungsphase auf), `arc42/12-glossar.md` ("Kontext-/Pause-Ansicht"/"reset frame" neu, "Bauchbinde" präzisiert) — Evidenz: Feature-Branch-Diff
- [X] ADRs erstellt: T025 (ADR-031), T026 (ADR-032), referenziert in Kap. 9 via T027 (Abschnitte 9.21/9.22) — Evidenz: `arc42/adr/ADR-031-Pause-Ansicht-setMenuImage.md`, `arc42/adr/ADR-032-Reset-Frame-statt-Delete-Frame-im-Menue.md`
- [X] Risiko-/Schulden-Review: T028 — R-21 (Titelscreen-Lazy-Load-Überlappung, mitigiert) und R-22 (Crank-Dual-Path-Regression, mitigiert) in `arc42/11-risiken-und-technische-schulden.md` Abschnitt 11.1/11.4 eingetragen
- [X] Offener Punkt zum Zeitpunkt der Tasks-Erstellung AUFGELÖST: VHS-Muster-Parameter (`VHS_PATTERN`, `VHS_PHASE_INTERVAL_MS = 80`) in T021 als Konstanten in `SelectionRoom.lua` festgelegt (research.md R5 zusätzlich korrigiert — `gfx.setDitherPattern` hatte keinen Phasen-Offset, reale Funktion ist `gfx.setPattern`). Finale VISUELLE Kalibrierung bleibt ein separater, expliziter Folgepunkt: Owner Entwickler, Re-Evaluierungs-Trigger erster Simulator-Test in T023 (offen, siehe unten)
- [X] Architektur-Review: T029 — Evidenz: Abschnitt "Architektur-Review-Durchlauf" im Constitution-Check von `specs/006-editor-ui-polish/plan.md`; alle 11 Contract-Klauseln (CR-01..CR-11) geprüft, zwei während der Implementierung gefundene Abweichungen (VHS-API-Signatur, CR-02-Aktivitäts-Lücke bei B-Druck) behoben und regressionsgetestet
- [X] Secure-Architecture: N/A bestätigt — reine lokale UI-/Eingabe-Änderungen; einziger Persistenz-Zugriff (Titelscreen-Lazy-Load) liest ausschließlich bereits vorhandene lokale Save-Daten über den etablierten `ImageStoreCodec`-Pfad, keine Netzwerk-/Auth-/Datenspeicherungs-Berührung (plan.md Architecture Governance)
- [ ] Verbleibend offen: T003/T006/T010/T014/T018/T023 (manuelle Simulator-/Hardware-Validierung je Story) — erfordern interaktiven Zugriff auf den Playdate Simulator bzw. echte Hardware, außerhalb der Möglichkeiten dieses Implementierungslaufs
