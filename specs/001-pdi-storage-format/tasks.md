# Tasks: Natives PDI-Speicherformat

**Input**: Design documents from `/specs/001-pdi-storage-format/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/storage-format.md, quickstart.md

**Tests**: Kein automatisiertes Test-Setup im Projekt (arc42 R-05). Verifikation erfolgt über die manuellen Simulator-Szenarien aus quickstart.md; jede Story schließt mit einer Validierungsaufgabe ab.

**Organization**: Tasks sind nach User Stories gruppiert; jede Story ist unabhängig testbar.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelisierbar (andere Dateien, keine offenen Abhängigkeiten)
- **[Story]**: US1 (verlustfrei speichern/laden), US2 (Dedup), US3 (flache Bildverwaltung)

## Path Conventions

Single project (Playdate-Lua): Quellcode unter `Source/`, Architektur-Doku unter `arc42/`, Feature-Doku unter `specs/001-pdi-storage-format/`.

---

## Phase 1: Setup

**Purpose**: Modulgerüste anlegen, ohne bestehende Pfade zu brechen

- [X] T001 Modulgerüst `Source/ImageStore.lua` anlegen (leere API-Stubs gemäß contracts/storage-format.md Abschnitt 2, noch ohne Logik; Import-Kommentarkopf im Stil der bestehenden Module)
- [X] T002 [P] Modulgerüst `Source/ImageStoreCodec.lua` anlegen (Stubs `newSaveOperation`, `newLoadOperation`; RoomOperation-kompatible Signatur wie in `Source/TileRoomPersistence.lua` verwendet)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Primitiven, die alle Stories brauchen — Index, IDs, Basistiles

**⚠️ CRITICAL**: Erst abschließen, dann Story-Phasen beginnen

- [X] T003 Index-Primitiven in `Source/ImageStore.lua` implementieren: `getIndex()` mit Lazy-Load/Cache via `playdate.datastore.read("saves/index")`, Anlage eines leeren Index `{version=1, lastEditedId=nil, images={}}` bei Erststart, internes `writeIndex()` via `playdate.datastore.write` (data-model.md "Index")
- [X] T004 [P] ID-Sanitisierung und Kollisionsprüfung in `Source/ImageStore.lua`: `sanitizeName(name)` (Kleinschreibung, a–z/0–9/`-`, Leerzeichen→`-`) und `isIdTaken(id)` gegen den Index (research.md R7, FR-013)
- [X] T005 [P] Basistile-Erzeugung in `Source/ImageStoreCodec.lua`: Funktionen für Voll-Weiß- und Voll-Schwarz-16×16-Image (`gfx.image.new(16,16,kColorWhite/kColorBlack)`) als Tiles 1 und 2 (data-model.md "Tile-Sammlung", Contract C-03)
- [X] T006 Sheet-Geometrie-Helfer in `Source/ImageStoreCodec.lua`: Zellposition `tileIndex → (x,y)` und Sheet-Abmessungen aus `tileCount` (25 Tiles/Zeile, 16 px Zellen; data-model.md), inkl. Umkehrfunktion fürs Slicing

**Checkpoint**: Index les-/schreibbar, IDs herleitbar, Basistiles erzeugbar

---

## Phase 3: User Story 1 — Bild verlustfrei speichern (Priority: P1) 🎯 MVP

**Goal**: Automatisches Speichern beim Verlassen/Terminate und verlustfreies Wiederherstellen aller Frames (PDI-Sheet + frames.json), noch ohne Dedup (jedes verwendete Tile wird als eigener Sheet-Eintrag akzeptiert)

**Independent Test**: quickstart.md Szenario 1 (Round-Trip über App-Neustart) und Szenario 6 (Terminate-Hook)

### Implementation for User Story 1

- [X] T007 [US1] Save-Coroutine in `Source/ImageStoreCodec.lua` implementieren: `newSaveOperation(imageData)` mit Phasen "Sheet" (Tiles in Sheet-Image zeichnen, Offscreen via `gfx.pushContext`) → "Frames" (`datastore.write(framesTable, "saves/<id>/frames")`) → "Bilddaten" (`datastore.writeImage(sheet, "saves/<id>/sheet")`) → "Preview" (Frame 1 als 400×240-Image rendern, `writeImage(..., "saves/<id>/preview")`) → "Index" (frameCount, lastEdited, lastEditedId aktualisieren — zwingend letzte Phase, Contract C-06); Phasen-Yields + loadingBar-Labels nach dem Muster von `Source/TileRoomPersistence.lua`
- [X] T008 [US1] Load-Coroutine in `Source/ImageStoreCodec.lua` implementieren: `newLoadOperation(id)` mit Phasen "Frames lesen" (`datastore.read("saves/<id>/frames")`) → "Bilddaten lesen" (`datastore.readImage("saves/<id>/sheet")`) → "Slicing" (Laufzeit-Imagetable via `gfx.imagetable.new(tileCount)` + `setImage(n, ...)` aus Sheet-Zellen) → "Validierung" (Frame-Anzahl 1..12, Indizes 1..tileCount mit Weiß-Fallback; Fehlersemantik laut Contract Abschnitt "Fehlersemantik")
- [X] T009 [US1] frames.json-Tabellenstruktur in `Source/ImageStoreCodec.lua` festziehen: `{version=1, name, gridWidth=25, gridHeight=15, tileCount, frames={...}}` mit 375er-Index-Arrays je Frame, direkt `tilemap:setTiles(data, 25)`-kompatibel (data-model.md "Bild / Frames", Contract C-02)
- [X] T010 [US1] Terminate-Hook in `Source/main.lua` umstellen: `playdate.gameWillTerminate()` speichert das offene Bild über den neuen Save-Pfad (synchroner Abschluss der Coroutine-Phasen im Hook, da kein weiterer Frame folgt); bestehenden TileRoom-Aufruf ersetzen (Contract Abschnitt 3 "main.lua")
- [X] T011 [US1] Temporären Debug-Einstieg für Validierung schaffen (Simulator): kleiner Testtreiber in `Source/main.lua` (auskommentierbarer Block) oder Konsolenfunktion, der ein Beispiel-imageData mit 3 Frames erzeugt, speichert und wieder lädt — bis Spec 002/003 die UI-Anbindung liefern (quickstart.md "Voraussetzungen")
- [ ] T012 [US1] Validierung durchführen und protokollieren: quickstart.md Szenario 1 + Szenario 6 im Simulator ausführen; Ergebnis (Datum, Befund) als Abschnitt "Validierung" in `specs/001-pdi-storage-format/quickstart.md` ankreuzen/notieren

**Checkpoint**: Round-Trip ohne Datenverlust; MVP lieferbar

---

## Phase 4: User Story 2 — Tiles dedupliziert ablegen (Priority: P2)

**Goal**: Inhaltsgleiche Tiles landen genau einmal im Sheet — frameübergreifend, mit Hash + Pixelvergleich

**Independent Test**: quickstart.md Szenario 2 (tileCount == Anzahl unterschiedlicher Inhalte, Sheet-Abmessung passt)

### Implementation for User Story 2

- [X] T013 [P] [US2] FNV-1a-Hash über 16×16-Tilepixel in `Source/ImageStoreCodec.lua` implementieren: `hashTile(image)` liest 256 Pixel via `image:sample(x,y)`; Referenzlogik aus `Source/TileRoomPersistence.lua` übernehmen (research.md R4)
- [ ] T014 [US2] Dedup in die Save-Phase "Sheet" integrieren: `hashIndex` (Hash→Tile-Index) aufbauen, bei Hash-Treffer Pixelvergleich zur Kollisionsabsicherung, Frames-Indizes auf deduplizierte Sheet-Indizes remappen; Basistiles 1+2 sind immer vorbelegt (Contract C-03, data-model.md Dedup-Invariante)
- [X] T015 [US2] `hashIndex`-Aufbau in die Load-Phase "Slicing" integrieren, damit geladene Bilder sofort dedup-fähig editierbar sind (Laufzeitrepräsentation in data-model.md; Konsument Spec 003)
- [ ] T016 [US2] Validierung durchführen und protokollieren: quickstart.md Szenario 2 im Simulator ausführen; Befund in `specs/001-pdi-storage-format/quickstart.md` notieren

**Checkpoint**: SC-002 erfüllt — Sheet wächst nur mit unterschiedlichen Inhalten

---

## Phase 5: User Story 3 — Unbegrenzt viele flache Bilder verwalten (Priority: P2)

**Goal**: Anlegen (mit Namensvergabe), Kopieren, Löschen und Auflisten von Bildern als eigenständige Speichereinheiten inkl. Vorschaubild-Zugriff

**Independent Test**: quickstart.md Szenario 4 (10+ Bilder, Kollision, unabhängige Kopie, sauberes Löschen)

### Implementation for User Story 3

- [X] T017 [US3] `ImageStore.createImage(name)` in `Source/ImageStore.lua` implementieren: sanitize + Kollisionsprüfung (`nil, "name-taken"`), Ordneranlage via `playdate.file.mkdir("saves/<id>")`, Initialdateien über Codec-Helfer (1 Frame, alle Indizes = 1; Sheet mit Tiles 1+2; weißes Preview), Index-Eintrag + lastEditedId (data-model.md "Neu anlegen", FR-013)
- [X] T018 [US3] `ImageStore.copyImage(id)` implementieren: Auto-Suffix für Namen/ID, `frames.json` via read/write kopieren, `sheet.pdi`/`preview.pdi` via `datastore.readImage`+`writeImage` kopieren, Index-Eintrag anlegen (FR-009, Spec-002-Annahme Auto-Suffix)
- [X] T019 [US3] `ImageStore.deleteImage(id)` implementieren: Dateien und Ordner über `playdate.file.delete` entfernen, Index-Eintrag löschen, `lastEditedId` neu bestimmen (jüngstes verbleibendes Bild oder nil; data-model.md "Löschen")
- [X] T020 [P] [US3] `ImageStore.listImages()` (absteigend nach lastEdited), `ImageStore.getPreviewImage(id)` (nil bei defekter Datei) und `ImageStore.getLastEditedPreview()` implementieren (Contract Abschnitt 2, Konsument Spec 002)
- [ ] T021 [US3] Validierung durchführen und protokollieren: quickstart.md Szenario 4 im Simulator (über den Debug-Einstieg aus T011); Befund in `specs/001-pdi-storage-format/quickstart.md` notieren

**Checkpoint**: SC-003 erfüllt — Verwaltung ohne Wechselwirkungen zwischen Bildern

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Robustheit, Lastmessung, Architektur-Evidenz (Constitution III / iSAQB)

- [ ] T022 Defensive Fehlerpfade härten gemäß Contract "Fehlersemantik" und quickstart.md Szenario 5 verifizieren: fehlendes sheet.pdi → Fehlerstatus ohne Absturz; Index 999 → Weiß-Fallback; fehlender index.json → leerer Index ohne Datenverlust; Befund in `specs/001-pdi-storage-format/quickstart.md` notieren (Dateien: `Source/ImageStore.lua`, `Source/ImageStoreCodec.lua`)
- [ ] T023 Lastmessung quickstart.md Szenario 3 durchführen (12 Frames): frames.json-Größe und gefühlte Blockierzeit messen; Messwerte in `specs/001-pdi-storage-format/quickstart.md` und in `arc42/09-architekturentscheidungen.md` unter AD-017 nachtragen (Risiko R-12-Bewertung; falls > ~25 KB oder Freeze > ~1 s: Open-Vermerk mit Re-Evaluation in `arc42/11-risiken-und-technische-schulden.md`)
- [ ] T024 [P] arc42-Ist-Kapitel im Umsetzungsschnitt aktualisieren: `arc42/03-kontextabgrenzung.md` (Pulp-Interop entfällt, neues Dateiformat), `arc42/05-bausteinsicht.md` (ImageStore/ImageStoreCodec statt PulpGameIO*-Beschreibung ergänzen), `arc42/06-laufzeitsicht.md` (Save/Load-Szenarien auf neue Phasen umschreiben), `arc42/08-querschnittliche-konzepte.md` (Persistenzkonzept 8.3 ersetzen) — Evidenz: Diff im Feature-Branch (Constitution III)
- [ ] T025 [P] `arc42/09-architekturentscheidungen.md`: AD-017 auf "Status: umgesetzt" setzen und Evaluationsergebnis aus research.md R2 (JSON via datastore, verworfene Alternativen) als Begründungsergänzung eintragen
- [ ] T026 PulpGameIO*-Module als deprecated markieren (Kommentarkopf in `Source/PulpGameIO.lua`, `Source/PulpGameIOShared.lua`, `Source/PulpGameIOSave.lua`, `Source/PulpGameIOLoad.lua`: "deprecated ab v0.3.0, Entfernung nach Abschluss Spec 002/003") — noch nicht löschen, TileRoom/LoadRoom nutzen sie bis zum Editor-Umbau
- [ ] T027 Architektur-Review-Durchlauf: Umsetzung gegen Contract C-01..C-06 und Constitution-Check aus plan.md prüfen; Abweichungen als Notiz in `specs/001-pdi-storage-format/plan.md` (Abschnitt Constitution Check) dokumentieren; Sicherheitsarchitektur: N/A (lokal, offline — Begründung bereits in plan.md)

---

## Dependencies

```text
Phase 1 (Setup) → Phase 2 (Foundational) → US1 (P1) → US2 (P2)
                                                    ↘ US3 (P2, nutzt Codec-Initialhelfer aus US1/T007)
US2 und US3 sind untereinander unabhängig (parallel möglich, nachdem US1 steht).
Phase 6 (Polish) nach Abschluss aller Stories; T024/T025 können parallel zu T022/T023 laufen.
```

- US1 → benötigt T003–T006 (Index, IDs, Basistiles, Geometrie)
- US2 → benötigt T007 (Sheet-Komposition existiert)
- US3 → benötigt T003/T004 (Index, IDs) und die Initialdatei-Helfer aus T007
- T010 (main.lua) hängt an T007; T011 an T007+T008

## Parallel Execution Examples

- **Phase 1**: T001 und T002 parallel (getrennte neue Dateien)
- **Phase 2**: T004 und T005 parallel zu T003 (T004 braucht nur die Index-Signatur; T005/T006 liegen im Codec)
- **Nach US1**: US2 (T013–T016) und US3 (T017–T021) als parallele Stränge; innerhalb US3 ist T020 parallel zu T017–T019
- **Phase 6**: T024 und T025 (arc42) parallel zur Code-Härtung T022

## Implementation Strategy

1. **MVP = Phase 1 + 2 + US1**: Ein Bild kann verlustfrei gespeichert und geladen werden (Round-Trip + Terminate-Hook). Dedup und Verwaltung folgen inkrementell.
2. **Inkrement 2 = US2**: Dedup aktivieren — Format bleibt unverändert (nur tileCount sinkt), daher kein Migrationsbedarf zwischen den Inkrementen.
3. **Inkrement 3 = US3**: Verwaltungs-API für Spec 002 bereitstellen.
4. **Abschluss = Phase 6**: Härtung, Messung (R-12), arc42-Evidenz, Deprecation-Markierung.
5. Jedes Inkrement wird über die zugehörigen quickstart-Szenarien im Simulator abgenommen, bevor das nächste beginnt (Constitution: Verifikation im Simulator).

## Audit-Evidenz-Checkpoints (iSAQB-Preset)

- [ ] Architektur-Sichten aktualisiert: T024 (arc42 Kap. 3/5/6/8) — Evidenz: Feature-Branch-Diff
- [ ] ADR gepflegt: T025 (AD-017 umgesetzt + R2-Ergebnis) — Evidenz: `arc42/09-architekturentscheidungen.md`
- [ ] Risiko-Review: T023 (R-12-Messung) — Evidenz: Messwerte in quickstart.md + AD-017; bei Grenzwertverletzung Open-Vermerk in arc42 Kap. 11 (Owner: Projektinhaber, Re-Evaluation: vor Spec-003-Implementierung)
- [ ] Architektur-Review: T027 — Evidenz: Notiz im plan.md Constitution Check
- [ ] Secure-Architecture: N/A — lokales Offline-System ohne Netzwerk, keine schutzbedürftigen Daten (Begründung in plan.md, Abschnitt Architecture Governance)
