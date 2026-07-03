# Tasks: Start- und Auswahlscreen

**Input**: Design documents from `/specs/002-start-selection-screen/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/selection-ui.md, quickstart.md; **Spec 001 (ImageStore-API)** muss mindestens bis US3 (T017–T020 dort) implementiert sein

**Tests**: Kein automatisiertes Test-Setup (arc42 R-05); Verifikation über die Simulator-Szenarien aus quickstart.md — jede Story schließt mit einer protokollierten Validierung ab.

**Organization**: Phasen nach User-Story-Priorität aus spec.md: US1 (P1) → US3 (P2) → US4 (P2) → US2 (P3).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelisierbar (andere Dateien, keine offenen Abhängigkeiten)
- **[Story]**: US1 (Start→Auswahl→Editor), US2 (letztes Bild als Hintergrund), US3 (3×3-Kreisraster/Scrollen), US4 (Neu/Kopieren/Löschen)

## Path Conventions

Single project (Playdate-Lua): Quellcode unter `Source/`, Architektur-Doku unter `arc42/`, Feature-Doku unter `specs/002-start-selection-screen/`.

---

## Phase 1: Setup

**Purpose**: Gerüst und Metadaten, ohne bestehende Pfade zu brechen

- [X] T001 Room-Gerüst `Source/SelectionRoom.lua` anlegen: Room-Muster wie bestehende Rooms (`init(switchRoom, editorRoom, titleRoom)`, `entered`, `update` mit needsRedraw, `inputHandler`), noch ohne Raster-Logik (contracts/selection-ui.md Abschnitt 1)
- [X] T002 [P] `Source/pdxinfo` auf `version=0.3.0` heben und `buildNumber` inkrementieren (FR-001 zeigt die Metadaten-Version auf dem Startscreen)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Datenliste, Raster-Grundgerüst und Verdrahtung — Voraussetzung für alle Stories

**⚠️ CRITICAL**: Erst abschließen, dann Story-Phasen beginnen

- [X] T003 Eintragsliste in `Source/SelectionRoom.lua` implementieren: `reloadEntries()` = `ImageStore.listImages()` (Sortierung kommt fertig, Contract D-02) plus virtueller Abschlusseintrag `{kind="new"}`; Index↔(row,col)-Mapping gemäß data-model.md ("Eintragstypen", `selectedIndex`)
- [X] T004 gridview-Grundgerüst in `Source/SelectionRoom.lua`: `playdate.ui.gridview.new(133, 80)`, `setNumberOfColumns(3)`, Zeilen aus `⌈#entries/3⌉`, `changeRowOnColumnWrap = false`; leeres `drawCell`-Override (research.md R1)
- [X] T005 Room-Verdrahtung in `Source/main.lua`: Import `SelectionRoom`, `TitleRoom:init(switchRoom, SelectionRoom)`, `SelectionRoom:init(switchRoom, <EditorStub>, TitleRoom)`; Übergangsstub für den Editor (Log + Verbleib im SelectionRoom), bis Spec 003 den neuen Editor liefert (plan.md "Structure Decision", Contract Abschnitt 1)

**Checkpoint**: App startet, SelectionRoom erreichbar, Einträge geladen (Rendering noch minimal)

---

## Phase 3: User Story 1 — Vom Start direkt ins Bild (Priority: P1) 🎯 MVP

**Goal**: Startscreen-Texte gemäß v0.3.0, A führt zum Auswahlscreen, Bildauswahl öffnet direkt den Editor (bzw. Stub) — keine Rooms-Zwischenebene

**Independent Test**: quickstart.md Szenario 3 (max. 3 Eingaben bis in den Editor) + Textprüfung aus Szenario 1 Schritt 2

### Implementation for User Story 1

- [X] T006 [P] [US1] TitleRoom-Texte in `Source/TitleRoom.lua` anpassen: Titelzeile "Hans Dither, 1 bit Pixel 'n Tile Editor", Fußzeile "Version <metadata.version> - still under development - Press A" (FR-001; Versionsquelle bleibt `playdate.metadata` via getMetadataRows)
- [X] T007 [US1] Eingabe-Handling in `Source/SelectionRoom.lua`: D-Pad bewegt `selectedIndex` (Zeilenanfang/-ende: Stopp; Interaktions-Contract Abschnitt 3), B → `switchRoom(TitleRoom)`, A auf Bildeintrag → Editor-Übergabe; Eingaben blockiert bei `pendingAction`/`confirmingDelete` (data-model.md Zustandsübergänge)
- [X] T008 [US1] Editor-Übergabe gemäß Contract S-01 in `Source/SelectionRoom.lua`: `editorRoom:setImage(id)` setzen, dann `switchRoom(editorRoom)`; im Stub-Fall Log-Ausgabe der id (contracts/selection-ui.md Abschnitt 2)
- [X] T009 [US1] Minimales `drawCell` in `Source/SelectionRoom.lua`: leerer Kreis (`drawCircleInRect`) pro Eintrag, Selektionsring (+3 px) für die selektierte Zelle (SDK-Beispielmuster aus research.md R2; volle Thumbnails folgen in US3)
- [ ] T010 [US1] Validierung durchführen und protokollieren: quickstart.md Szenario 3 + Textprüfung (Szenario 1 Schritt 2) im Simulator; Befund als Abschnitt "Validierung" in `specs/002-start-selection-screen/quickstart.md` notieren

**Checkpoint**: Start → Auswahl → Editor(-Stub) in ≤ 3 Eingaben; MVP-Navigationsgerüst steht

---

## Phase 4: User Story 3 — Unendlich viele Bilder im 3×3-Kreisraster durchblättern (Priority: P2)

**Goal**: Maskierte, unskalierte Thumbnails in Kreisen, zeilenweises Scrollen ohne Obergrenze, Neu-Eintrag am Listenende

**Independent Test**: quickstart.md Szenario 2 (12+ Bilder, Scrollen, Maskierung, Sortierung)

### Implementation for User Story 3

- [X] T011 [P] [US3] Thumbnail-Erzeugung in `Source/SelectionRoom.lua`: Kreis-Maskenbild (weiße Scheibe ⌀ ≈ 72 auf schwarzem Grund) einmalig erzeugen; `buildThumb(id)` zeichnet `ImageStore.getPreviewImage(id)` unskaliert mit Bildmitte auf Zellmitte in ein Kreis-Image (`pushContext`) und setzt `setMaskImage` (research.md R2, Clarification "Ausschnitt")
- [X] T012 [US3] `thumbCache` in `Source/SelectionRoom.lua`: lazy Befüllung in drawCell, Platzhalter-Kreis (Dither + "?") bei `getPreviewImage == nil` (FR-011), Invalidierung bei `entered()` (research.md R3, data-model.md)
- [X] T013 [US3] Vollständiges `drawCell`: gecachtes Thumbnail zeichnen, Kreisrand + Selektionsring darüber; Neu-Eintrag als leerer Kreis mit "+" (data-model.md "Eintragstypen", Contract D-01)
- [X] T014 [US3] Scroll-Anbindung: bei Selektionswechsel `gridview:scrollToCell(1, row, col)` (vertikal über Fensterrand → zeilenweises Nachscrollen, FR-006); Navigation stoppt am Listenanfang, letztes Element ist der Neu-Eintrag (Edge Case Ränder)
- [X] T015 [US3] Keyboard-Namensflow für den Neu-Eintrag in `Source/SelectionRoom.lua`: A auf Neu-Eintrag öffnet `playdate.keyboard` (pending-Muster aus `Source/GameRoom.lua` übernehmen); Bestätigung → `ImageStore.createImage(name)`; `"name-taken"` → Hinweis + Tastatur mit Suffix-Vorschlag; Abbruch → keine Anlage (research.md R6, US3-Szenario 4, Spec-Clarification Name)
- [ ] T016 [US3] Validierung durchführen und protokollieren: quickstart.md Szenario 2 im Simulator (12+ Bilder); Befund in `specs/002-start-selection-screen/quickstart.md` notieren

**Checkpoint**: SC-002/SC-003 — alle Bilder erreichbar, jede Zelle zeigt definierten Inhalt

---

## Phase 5: User Story 4 — Bilder verwalten: Neu, Kopieren, Löschen (Priority: P2)

**Goal**: Systemmenü mit exakt drei Aktionen; Löschen mit Bestätigungsdialog; Raster aktualisiert sich ohne Neustart

**Independent Test**: quickstart.md Szenario 4 (Anlage inkl. Abbruch/Kollision, unabhängige Kopie, Löschen mit beiden Dialog-Ausgängen)

### Implementation for User Story 4

- [X] T017 [US4] Systemmenü in `Source/SelectionRoom.lua` bei `entered()` aufbauen: `removeAllMenuItems()` + "new image" (→ Keyboard-Flow aus T015), "copy image", "delete image"; copy/delete nur auf Bildeinträgen wirksam (research.md R4, FR-009; SDK-Limit 3 Slots)
- [X] T018 [US4] `copyImage`-Aktion: `ImageStore.copyImage(id)`, `reloadEntries()`, Cache-Invalidierung für neue id, Kopie selektieren (FR-010, Contract D-04)
- [X] T019 [US4] Bestätigungsdialog in `Source/SelectionRoom.lua`: Zustand `confirmingDelete = {id, name}`; Overlay (Dither-Abdunklung, Panel mit Name, "(A) delete / (B) cancel") im update() zeichnen; Eingaben außer A/B blockiert (research.md R5, Clarification Lösch-Dialog, Edge Case konkurrierende Eingaben)
- [X] T020 [US4] Lösch-Durchführung: A → `ImageStore.deleteImage(id)`, `reloadEntries()`, Cache invalidieren, Selektionsregel aus data-model.md anwenden (gleiche Position, Ende → neuer letzter, leer → Neu-Eintrag); B → Overlay schließen ohne Aktion (FR-009/FR-010)
- [ ] T021 [US4] Validierung durchführen und protokollieren: quickstart.md Szenario 4 im Simulator; Befund in `specs/002-start-selection-screen/quickstart.md` notieren

**Checkpoint**: SC-004 — Verwaltungsaktionen konsistent ohne Neustart

---

## Phase 6: User Story 2 — Letztes Bild als Startscreen-Hintergrund (Priority: P3)

**Goal**: Startscreen zeigt das zuletzt bearbeitete Bild; Dither-Fallback bei leerem Bestand

**Independent Test**: quickstart.md Szenario 1 (frische Installation vs. nach Bearbeitung)

### Implementation for User Story 2

- [X] T022 [US2] Hintergrund in `Source/TitleRoom.lua`: bei `entered()` `ImageStore.getLastEditedPreview()` laden; vorhandenes Bild vollflächig zeichnen, sonst bestehender Bayer-Dither-Fallback; Panels/Texte immer darüber (FR-002, Contract D-03, research.md R7)
- [ ] T023 [US2] Validierung durchführen und protokollieren: quickstart.md Szenario 1 komplett (inkl. Neustart-Pfad); Befund in `specs/002-start-selection-screen/quickstart.md` notieren

**Checkpoint**: Alle vier Stories erlebbar

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Grenzfälle, Altlasten-Entfernung, Performance-Beobachtung, Architektur-Evidenz (Constitution III / iSAQB)

- [ ] T024 Leerzustand und Defekt-Grenzfälle härten und verifizieren: quickstart.md Szenario 5 (nur Neu-Eintrag nach Komplett-Löschung; Platzhalter bei gelöschtem preview.pdi; Dialog blockiert alle Fremdeingaben inkl. Crank); Befund in `specs/002-start-selection-screen/quickstart.md` notieren (Datei: `Source/SelectionRoom.lua`)
- [ ] T025 `Source/GameRoom.lua` entfernen: Datei löschen, Import und Verdrahtung in `Source/main.lua` bereinigen; LoadRoom/LoadRoomGrid bewusst NICHT anfassen (Open-Punkt aus plan.md: Entfernung erst mit Spec 003 — Vermerk in `specs/003-editor-animation-zoom/spec.md`-Tasks fällig)
- [ ] T026 R-13-Beobachtung durchführen: quickstart.md Szenario 6 (30 Bilder, Scroll-Performance mit Thumbnail-Cache); Messbefund in `specs/002-start-selection-screen/quickstart.md`; bei Auffälligkeit Eintrag in `arc42/11-risiken-und-technische-schulden.md` unter R-13 aktualisieren (Owner: Projektinhaber, Re-Evaluation: vor Release 0.3.0)
- [ ] T027 [P] arc42-Ist-Kapitel aktualisieren: `arc42/05-bausteinsicht.md` (SelectionRoom aufnehmen, GameRoom entfernen, LoadRoom/LoadRoomGrid als "entfällt mit Spec 003" markieren), `arc42/06-laufzeitsicht.md` (Szenario 6.1 = Title→Selection→Editor), `arc42/08-querschnittliche-konzepte.md` (8.1 Navigation ohne Rooms-Ebene, B = zurück) — Evidenz: Feature-Branch-Diff (Constitution III)
- [ ] T028 [P] `arc42/09-architekturentscheidungen.md`: AD-018 auf "Status: umgesetzt" setzen; AD-020-Konsequenz um konkrete SDK-Einsätze ergänzen (gridview, Image-Maske für Kreis-Thumbnails, Keyboard, Menü-Limit → B als Rückweg)
- [ ] T029 Architektur-Review-Durchlauf: Umsetzung gegen contracts/selection-ui.md (S-01/S-02, D-01–D-04, Interaktionstabelle) und den Constitution Check aus plan.md prüfen; Abweichungen im Abschnitt Constitution Check von `specs/002-start-selection-screen/plan.md` notieren; Secure-Architecture: N/A (lokale UI, Begründung in plan.md)

---

## Dependencies

```text
Spec 001 (ImageStore inkl. US3-API) ─┐
Phase 1 (Setup) → Phase 2 (Foundational) → US1 (P1) → US3 (P2) → US4 (P2) → US2 (P3) → Phase 7
```

- US1 → braucht T003–T005 (Einträge, gridview, Verdrahtung)
- US3 → braucht US1 (T007 Navigation, T009 drawCell-Gerüst); T015 braucht `ImageStore.createImage`
- US4 → braucht US3 (T015 Keyboard-Flow wird von "new image" wiederverwendet; Thumbnail-Refresh aus T012)
- US2 → nur T005-Verdrahtung + `ImageStore.getLastEditedPreview` (unabhängig von US3/US4 — kann bei Bedarf vorgezogen werden)
- T025 erst nach US1 (SelectionRoom ersetzt GameRoom vollständig)

## Parallel Execution Examples

- **Phase 1**: T001 ∥ T002 (verschiedene Dateien)
- **US1**: T006 (TitleRoom) ∥ T007–T009 (SelectionRoom)
- **US3**: T011 ∥ T012 vorbereitbar, T013/T014 danach sequenziell (gleiche Datei, aufeinander aufbauend)
- **US2**: T022 parallel zu US4-Tasks (verschiedene Dateien) — wenn zwei Stränge gewünscht
- **Phase 7**: T027 ∥ T028 (arc42) parallel zu T024/T026 (Code/Beobachtung)

## Implementation Strategy

1. **MVP = Phase 1 + 2 + US1**: Navigationskette Title→Selection→Editor(-Stub) mit korrekten Texten — sofort erlebbarer Kern-Workflow von v0.3.0.
2. **Inkrement 2 = US3**: Kreis-Thumbnails, Scrollen, Neu-Anlage — der Auswahlscreen wird voll nutzbar.
3. **Inkrement 3 = US4**: Verwaltung inkl. Bestätigungsdialog.
4. **Inkrement 4 = US2**: Startscreen-Hintergrund (kleinster Umfang, bewusst zuletzt — P3).
5. **Abschluss = Phase 7**: GameRoom-Entfernung, Grenzfälle, R-13-Beobachtung, arc42-Evidenz.
6. Jedes Inkrement wird über die zugehörigen quickstart-Szenarien im Simulator abgenommen (Constitution: Verifikation im Simulator); Editor-Anbindung ersetzt den Stub in Spec 003.

## Audit-Evidenz-Checkpoints (iSAQB-Preset)

- [ ] Architektur-Sichten aktualisiert: T027 (arc42 Kap. 5/6/8) — Evidenz: Feature-Branch-Diff
- [ ] ADR gepflegt: T028 (AD-018 umgesetzt, AD-020-Konsequenzen) — Evidenz: `arc42/09-architekturentscheidungen.md`
- [ ] Risiko-Review: T026 (R-13-Beobachtung) — Evidenz: Messbefund in quickstart.md; bei Auffälligkeit arc42 Kap. 11 (Owner: Projektinhaber, Re-Evaluation: vor Release 0.3.0)
- [ ] Architektur-Review: T029 — Evidenz: Notiz im plan.md Constitution Check
- [ ] Offener Punkt (Open): Entfernung LoadRoom/LoadRoomGrid — Owner: Projektinhaber, Follow-up: tasks.md von Spec 003, Re-Evaluation: bei Editor-Anbindung (T025 verweist darauf)
- [ ] Secure-Architecture: N/A — lokale UI-Navigation ohne Netzwerk/schutzbedürftige Daten (Begründung in plan.md, Architecture Governance)
