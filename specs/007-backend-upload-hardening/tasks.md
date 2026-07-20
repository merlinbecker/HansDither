# Tasks: Absicherung des Backends gegen unbegrenzte/missbräuchliche Uploads

**Input**: Design documents from `/specs/007-backend-upload-hardening/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/upload-hardening.md](contracts/upload-hardening.md), [quickstart.md](quickstart.md)

**Tests**: Kein PHPUnit/Test-Framework im Projekt etabliert (Constitution V gilt
ausschließlich für `Source/*.lua`) — Backend-Verifikation erfolgt je Story über
`quickstart.md`-Szenarien gegen die deployte Umgebung, nicht über
automatisierte Testtasks. Der einzige `Source/*.lua`-Teil dieser Spec
(Client-Anzeige, US1) hat bereits einen automatisierten Testfall in
`tests/headless_tests.lua` — als `[X]`-Task unten dokumentiert, da während
der Planungsphase umgesetzt (research.md R6).

**Organization**: Tasks sind nach User Story gruppiert (spec.md-Prioritäten:
US1/US2 = P1, US3/US4 = P2), damit jede Story unabhängig implementiert und
gegen `quickstart.md` verifiziert werden kann.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Kann parallel laufen (unterschiedliche Dateien, keine Abhängigkeiten)
- **[Story]**: Zugehörige User Story (US1-US4)
- **[X]**: Bereits umgesetzt (während der Planungsphase, mit Nachweis)

## Path Conventions

Backend: `backend/includes/*.php` (kein Framework, reines PHP/MySQLi, wie in
Spec 005 etabliert). Playdate-Client: `Source/SyncService.lua` +
`tests/headless_tests.lua` (nur der US1-Anteil, research.md R6).

---

## Phase 1: Setup

**N/A** — keine neue Projekt-Struktur, kein neuer Endpunkt. Alle vier
Maßnahmen erweitern den bestehenden `/upload`-Endpunkt aus Spec 005
(plan.md "Structure Decision"). Kein Setup-Task erforderlich.

---

## Phase 2: Foundational

**N/A** — keine Infrastruktur, die MEHRERE Stories gemeinsam blockiert. Jede
Story erweitert die bestehende Validierungs-Pipeline additiv an einer
eigenen, in `contracts/upload-hardening.md` ("Prüfreihenfolge") definierten
Stelle. Die einzige neue Infrastruktur (Transaktions-Hilfsmethoden in
`database.php`) wird ausschließlich von US1 benötigt und ist daher dort
eingeordnet (T001), nicht als eigene Foundational-Phase.

---

## Phase 3: User Story 1 - Obergrenze für Uploads pro Gerät (Priority: P1) 🎯 MVP

**Goal**: Kein Gerät (UID) kann mehr als 12 unterschiedliche Bilder
gleichzeitig gespeichert haben; das 13. NEUE Bild wird mit einer
eindeutigen, race-sicheren Ablehnung blockiert; Re-Sync bekannter Bilder
bleibt bei erreichtem Limit möglich.

**Independent Test** (aus spec.md): Ein Testgerät lädt nacheinander 12
unterschiedliche Bilder hoch (alle erfolgreich), versucht danach ein 13.
hochzuladen und erhält eine klare Ablehnung statt eines Erfolgs oder eines
unklaren Serverfehlers.

- [X] T001 [US1] `backend/includes/database.php`: neue Methoden
  `beginTransaction()`, `commit()`, `rollback()` hinzufügen (dünne
  Pass-through-Wrapper auf `$this->connection->begin_transaction()` /
  `->commit()` / `->rollback()`, analog zu den bestehenden `query()`/
  `execute()`-Wrappern der Klasse) (AD-033, research.md R1)

- [X] T002 [US1] `backend/includes/upload_handler.php::handleUpload()`:
  direkt vor dem bestehenden Kommentar "4a. Update-in-place" (aktuell Zeile
  52) `db()->beginTransaction()` einfügen, danach
  `db()->query('SELECT uid FROM users WHERE uid = ? FOR UPDATE', $uid)` als
  Row-Lock ausführen. Der bestehende `Auth::uidExists($uid)`-Aufruf in
  Schritt 1 (Zeile 28) bleibt UNVERÄNDERT und außerhalb der Transaktion (er
  ist bereits ein schneller Fail-Fast-Check für unbekannte UIDs, der Lock
  dient ausschließlich der Serialisierung des nachfolgenden Zähl-Checks)
  (research.md R1)

- [X] T003 [US1] `backend/includes/upload_handler.php::handleUpload()`:
  direkt NACH der bestehenden Ermittlung von `$existing_image_id` (Zeilen
  53-62), NUR wenn `$existing_image_id === null` (Neuanlage, FR-003 bleibt
  dadurch strukturell unberührt): `$count =
  db()->queryScalar('SELECT COUNT(*) FROM images WHERE uid = ?', $uid)`
  abfragen; bei `$count >= 12` `db()->rollback()` aufrufen und SOFORT
  `['status' => 'error', 'error' => 'Upload-Limit erreicht (maximal 12
  Bilder pro Gerät)', 'http_code' => 403]` zurückgeben, OHNE dass
  `move_uploaded_file()` erreicht wird (FR-001/FR-002, research.md R1/R5,
  contracts/upload-hardening.md)

- [X] T004 [US1] `backend/includes/upload_handler.php::handleUpload()`: alle
  bestehenden Fehler-Returns INNERHALB der neuen Transaktion (Zeilen 71-101:
  `move_uploaded_file()`-Fehlschläge, DB-Schreibfehler bei INSERT/UPDATE) um
  ein vorangestelltes `db()->rollback()` ergänzen; den finalen Erfolgs-Return
  (Zeile 106-111) um ein vorangestelltes `db()->commit()` ergänzen —
  verhindert einen hängenden Row-Lock bei jedem Fehlerpfad nach T002
  (Transaktionskorrektheit, kein neuer Layer)

- [X] T005 [US1] `Source/SyncService.lua`: neuer `403`-Statuscode-Zweig in
  `attemptUpload()` (`reason = "limit_reached"`) + eigene
  `showStatus("Upload limit reached (12 images)", 5000)`-Meldung in
  `startUpload()`s Ergebnis-Callback statt Kollaps auf den generischen
  `else`-Zweig — **bereits umgesetzt während der Planungsphase**
  (research.md R6), da ohne diese Ergänzung FR-002/SC-005 clientseitig
  nicht erfüllt gewesen wären

- [X] T006 [US1] `tests/headless_tests.lua`: neuer Testfall "Upload-Limit
  erreicht (403) zeigt eindeutige Meldung..." — **bereits umgesetzt**
  (research.md R6). Beide Constitution-V-Gates bestanden:
  `lua tests/headless_tests.lua` → "ALLE TESTS BESTANDEN",
  `pdc Source "Hans Dither.pdx"` → Build sauber

- [X] T007 [US1] Validierung gegen die deployte Umgebung: `quickstart.md`
  Szenario 1 durchführen (12 Bilder hochladen, 13. wird mit 403
  abgelehnt, 5 gleichzeitige Requests um den letzten Slot ergeben genau
  EINEN Erfolg), Checkliste in `quickstart.md` abhaken — **durchgeführt
  gegen https://www.hans-dither.de**: img-01..12 = 201, img-13 = 403
  ("Upload-Limit erreicht (maximal 12 Bilder pro Gerät)"); Race-Stichprobe
  mit 5 parallelen Requests um den letzten freien Slot: genau 1× 201,
  4× 403 (FR-011 race-sicher bestätigt)

**Checkpoint**: US1 ist nach T001-T007 vollständig funktionsfähig und
unabhängig testbar (Backend UND Geräte-Anzeige).

---

## Phase 4: User Story 2 - Strengere Dateigrößenbegrenzung (Priority: P1)

**Goal**: Jede hochgeladene PDI- oder JSON-Datei wird einzeln auf maximal
300 KB begrenzt (vorher 10 MB); Dateien darüber werden vor dem Speichern
abgelehnt.

**Independent Test** (aus spec.md): Ein Testgerät lädt eine Datei mit exakt
300 KB hoch (wird angenommen) und danach eine Datei mit 301 KB (wird
abgelehnt).

- [X] T008 [US2] `backend/includes/validation.php` Zeile 26: `private static
  $maxFileSize = 10 * 1024 * 1024;` → `private static $maxFileSize = 300 *
  1024;` ändern; Kommentar Zeile 24 von "Maximale Dateigröße (10MB)" auf
  "Maximale Dateigröße (300 KB)" anpassen (research.md R2)

- [X] T009 [US2] `backend/includes/validation.php` Zeile 63: Fehlertext
  `'Datei zu groß (max. 10MB)'` → `'Datei zu groß (max. 300KB)'` anpassen
  (bestehender `http_code => 413`-Pfad bleibt unverändert) (research.md R2,
  contracts/upload-hardening.md)

- [X] T010 [P] [US2] `backend/TESTING.md` Abschnitt 4 (Zeilen 174-179,
  "Datei > 10MB → 413"-Beispiel): Fixture-Erzeugung und Kommentar auf die
  neue 300-KB-Grenze aktualisieren, damit das bestehende Testdokument nicht
  mehr den alten Schwellwert suggeriert

- [X] T011 [US2] Validierung gegen die deployte Umgebung: `quickstart.md`
  Szenario 2 durchführen (exakt 300 KB = 201, 300 KB + 1 Byte = 413),
  Checkliste abhaken — **durchgeführt**: exactly_300kb.pdi = 201,
  over_300kb.pdi (300 KB + 1 Byte) = 413 ("Datei zu groß (max. 300KB)")

**Checkpoint**: US1 UND US2 funktionieren nach T008-T011 beide unabhängig.

---

## Phase 5: User Story 3 - Verlässliche Dateiformat-Validierung (Priority: P2)

**Goal**: Jede als Bilddatei hochgeladene Datei wird anhand ihres
TATSÄCHLICHEN Inhalts (nicht nur Endung) als gültiges Playdate-PDI-Format
verifiziert.

**Independent Test** (aus spec.md): Ein Testgerät lädt eine Datei mit
`.pdi`-Endung hoch, deren Inhalt kein gültiges Playdate-PDI-Format ist — der
Upload wird anhand des tatsächlichen Inhalts abgelehnt, nicht anhand der
Dateiendung akzeptiert.

**Hinweis**: research.md R3 stellt fest, dass FR-004/FR-005 durch
`PdiParser::hasValidMagic()`/`parseFile()` (Magic-Bytes + vollständiges
Parsing inkl. zlib/Cell-Header/Alpha-Maske) bereits VOLLSTÄNDIG erfüllt
sind. Diese Phase enthält daher bewusst KEINEN Implementierungs-Task, nur
Verifikation + Dokumentation (Constitution IV — keine Doppel-Implementierung).

- [X] T012 [US3] Verifikations-Durchgang: `backend/includes/pdi_parser.php`
  (`hasValidMagic()`, `parseFile()`, `parse()`, `parseCell()`) UND
  `backend/includes/validation.php::validatePdiFile()` (Zeilen 112-136)
  gegen FR-004/FR-005 gegenlesen (kein Code-Fund = kein Gap); danach
  `docs/architecture/security-review-backend.md` Eintrag S-04 von "geprüft"
  auf die präzisere Formulierung aktualisieren, die explizit die
  STRUKTURELLE (nicht nur Magic-)Prüftiefe benennt (research.md R3) — reine
  Dokumentationsänderung

- [X] T013 [US3] Validierung gegen die deployte Umgebung: `quickstart.md`
  Szenario 3 durchführen (falsches Magic = 400 UND korrektes Magic mit
  strukturell kaputtem Rest = 400 — das zweite Fixture beweist, dass die
  Prüfung über die Magic-Bytes hinausgeht), Checkliste abhaken —
  **durchgeführt**: fake.pdi = 400 ("Kein Playdate-Bildformat"),
  corrupt_magic_ok.pdi (korrektes Magic, kaputter Rest) = 400
  ("Beschädigte Bilddaten") — unterschiedliche Fehlertexte bestätigen die
  strukturelle Prüftiefe empirisch

**Checkpoint**: US1, US2 UND US3 funktionieren nach T012-T013 alle
unabhängig.

---

## Phase 6: User Story 4 - JSON-Schema-Validierung der Positionsdaten (Priority: P2)

**Goal**: Die hochgeladene Positionsdatei (`frames.json`) wird zusätzlich
zur bestehenden JSON-Syntax-Prüfung gegen das in Spec 001 definierte
Struktur-Schema validiert.

**Independent Test** (aus spec.md): Ein Testgerät lädt eine syntaktisch
ungültige JSON-Datei hoch (wird abgelehnt) sowie eine syntaktisch gültige,
aber dem Schema widersprechende JSON-Datei hoch (wird ebenfalls abgelehnt).

- [X] T014 [US4] `backend/includes/validation.php`: neue Methode
  `public static function validateFramesJsonSchema(array $data): array`
  hinzufügen — prüft in dieser Reihenfolge (bricht bei erster Verletzung ab,
  data-model.md Abschnitt 3): `version` (vorhanden, `>= 1`), `name`
  (vorhanden, Länge > 0), `gridWidth` (exakt `25`), `gridHeight` (exakt
  `15`), `tileCount` (`>= 1`), `frames` (Array, 1 bis 12 Einträge),
  `frames[f]` (Array, exakt `gridWidth × gridHeight` = 375 Zahlen),
  `frames[f][i]` (Zahl, `1 <= x <= tileCount`); liefert bei Verletzung
  `['valid' => false, 'error' => 'JSON-Struktur ungültig: {konkretes
  Feld}']`, sonst `['valid' => true, 'error' => null]` (research.md R4)

- [X] T015 [US4] `backend/includes/validation.php::validateJsonFile()`:
  nach dem bestehenden Objekt/Array-Check (Zeilen 156-159), VOR der
  Größenprüfung, einen Aufruf `$schemaResult =
  self::validateFramesJsonSchema((array) $data)` ergänzen; bei
  `!$schemaResult['valid']` dessen Fehler durchreichen (FR-007/FR-008/
  FR-009) — Reihenfolge in `validateJsonFile()` bleibt sonst unverändert

- [X] T016 [US4] Validierung gegen die deployte Umgebung: `quickstart.md`
  Szenario 4 durchführen (5 Schema-Verletzungen: falsches `gridWidth`, zu
  kurzes Frame, Tile-Index außerhalb des Bereichs, zu viele Frames,
  falscher Wurzeltyp — alle 400 mit feldspezifischer Meldung), Checkliste
  abhaken — **durchgeführt**: alle 5 Fixtures = 400, jeweils mit
  feldspezifischer Meldung ("gridWidth muss 25 sein", "frames[0] hat 370
  statt 375 Werte", "frames[0][374] = 99 liegt außerhalb von 1..3",
  "frames hat 13 Einträge, erlaubt sind 1 bis 12", "version fehlt oder
  ist ungültig")

**Checkpoint**: Alle vier User Stories (US1-US4) funktionieren nach
T014-T016 unabhängig UND zusammen.

---

## Phase 7: Polish & Cross-Cutting Concerns (Architecture Governance, iSAQB-Preset)

**Purpose**: Architektur-Evidenz, ADR-Dateien und risikobezogene
Dokumentation, die alle vier Stories gemeinsam betreffen (plan.md
"Architecture Governance").

- [X] T017 [P] `arc42/05-bausteinsicht.md` aktualisieren: Backend-Baustein
  um die `UploadHandler`/`Validation`/`Database`-Erweiterungen aus T001-T004
  und T014 ergänzen; `Source/SyncService.lua`-Baustein um den neuen
  `limit_reached`-Fehlerpfad (T005) ergänzen

- [X] T018 [P] `arc42/06-laufzeitsicht.md` aktualisieren: neues
  Laufzeitszenario "Upload mit Zähl-Check + Row-Lock" ergänzen, das den
  vollständigen Pfad von der Transaktion (T002-T004) bis zur
  Geräte-Anzeige (T005) zeigt — Ende-zu-Ende, nicht nur Backend-intern

- [X] T019 [P] `docs/architecture/security-review-backend.md`: S-04
  präzisieren (siehe T012) und drei neue Einträge ergänzen: S-09
  "Upload-Obergrenze pro Gerät" (T001-T004), S-10 "Dateigröße 300 KB"
  (T008-T009), S-11 "JSON-Schema-Validierung" (T014-T015)

- [X] T020 `arc42/adr/ADR-033-Upload-Limit-Row-Lock.md` anlegen — Inhalt aus
  plan.md AD-033 (Transaktion + Row-Lock auf `users` statt neuem
  Zähler-Feld, mit den drei in research.md R1 dokumentierten verworfenen
  Alternativen)

- [X] T021 `arc42/adr/ADR-034-JSON-Schema-ohne-Library.md` anlegen — Inhalt
  aus plan.md AD-034 (schlanke PHP-Funktion statt externer
  JSON-Schema-Bibliothek, Constitution IV)

- [X] T022 [P] `arc42/11-risiken-und-technische-schulden.md`: zwei neue
  Einträge ergänzen — (1) Multi-Geräte-/Sybil-Umgehung des Pro-Gerät-Limits
  (aus spec.md Assumptions, bewusst akzeptiertes Restrisiko, NICHT Teil
  dieser Spec), (2) verlängerte Row-Lock-Dauer bei mehreren gleichzeitigen
  Uploads DERSELBEN UID durch die neue Transaktionsklammer (aus plan.md
  Risiko-Review, unkritisch bei erwarteter Nutzungsfrequenz)

- [X] T023 Integrations-Verifikation der Prüfreihenfolge (nicht durch
  einzelne Story-Szenarien abgedeckt): eine Datei erzeugen, die
  GLEICHZEITIG zu groß (> 300 KB) UND schema-ungültig ist, hochladen und
  bestätigen, dass die Antwort `413` ist (Größenprüfung greift VOR der
  Schema-Prüfung, siehe `contracts/upload-hardening.md`
  "Prüfreihenfolge") — bestätigt, dass T008-T009 (US2) und T014-T015 (US4)
  korrekt zusammenspielen, ohne dass eine Story die andere maskiert.
  Code-Inspektion während der Implementierung: `UploadHandler::handleUpload()`
  ruft `Validation::validateUploadedFile()` für die JSON-Datei auf, deren
  äußere Größenprüfung VOR der Aufruf-Kette zu `validateJsonFile()` →
  `validateFramesJsonSchema()` liegt. **Empirisch bestätigt**: JSON-Datei
  gleichzeitig > 300 KB und schema-ungültig (falsches `gridWidth`)
  hochgeladen → `413` ("Datei zu groß (max. 300KB)"), Schema-Prüfung
  wurde nie erreicht — Prüfreihenfolge in Produktion verifiziert

- [X] T024 Abschließender Architektur-Review-Durchgang: `plan.md`
  "Post-Design Re-Check" gegen den tatsächlich umgesetzten Code (T001-T016)
  bestätigt — keine neue Abstraktionsschicht, Transaktionslogik ist eine
  lokale Erweiterung von `handleUpload()`. **Eine Diskrepanz gefunden und
  korrigiert:** `contracts/upload-hardening.md`s "Prüfreihenfolge" nannte
  Dateiendung VOR Dateigröße — der tatsächliche Code in
  `Validation::validateUploadedFile()` prüft (bereits seit vor Spec 007)
  Größe VOR Endung. Dokumentation korrigiert, keine Code-Änderung nötig
  (T023s Kernaussage — Größe schlägt Schema — bleibt davon unberührt).
  `checklists/requirements.md` bleibt vollständig (bereits seit
  `/speckit-specify` alle Punkte `[X]`). Audit-Evidenz-Checkpoints unten
  aktualisiert. Owner: Entwickler; Evidenz: dieser Task-Abschluss +
  Korrektur in `contracts/upload-hardening.md`

**Checkpoint**: Feature vollständig, alle Architektur-Evidenz-Artefakte
aktuell, bereit für `/speckit-implement` oder direkten Merge.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: N/A — kein Blocker
- **Foundational (Phase 2)**: N/A — kein Blocker für andere Phasen
- **User Stories (Phase 3-6)**: Alle können nach Phase 1/2 (die es nicht
  gibt) sofort beginnen. US1 (T001-T007) und US3 (T012-T013) sind
  dateidisjunkt zu allen anderen Stories und können vollständig parallel
  bearbeitet werden. US2 (T008-T011) und US4 (T014-T016) teilen sich
  `backend/includes/validation.php`, berühren dort aber unterschiedliche,
  nicht überlappende Stellen (US2: Zeilen 24-26/63; US4: neue Methode +
  `validateJsonFile()`-Aufrufstelle) — bei paralleler Bearbeitung durch
  zwei Personen ist ein einfacher Merge nötig, kein inhaltlicher Konflikt.
- **Polish (Phase 7)**: Hängt von allen vier User Stories ab (T017-T024
  dokumentieren den tatsächlich umgesetzten Zustand)

### User Story Dependencies

- **US1 (P1)**: Keine Abhängigkeit von anderen Stories. T001→T002→T003→T004
  sequenziell (dieselbe Transaktion in derselben Funktion). T005/T006
  bereits abgeschlossen. T007 hängt von T001-T004 ab.
- **US2 (P1)**: Keine Abhängigkeit von anderen Stories. T008→T009
  sequenziell (dieselbe Datei), T010 parallel dazu möglich, T011 hängt von
  T008-T009 ab.
- **US3 (P2)**: Keine Abhängigkeit von anderen Stories, kein Code-Task.
  T012 vor T013.
- **US4 (P2)**: Keine Abhängigkeit von anderen Stories. T014→T015
  sequenziell (T015 ruft die in T014 neu geschaffene Methode auf), T016
  hängt von T014-T015 ab.
- **T023 (Polish)**: Einzige ECHTE Cross-Story-Abhängigkeit — benötigt US2
  (T008-T009) UND US4 (T014-T015) abgeschlossen.

### Within Each User Story

- Keine Tests-vor-Implementierung-Reihenfolge (kein TDD angefordert,
  Backend-Verifikation ist grundsätzlich nach Implementierung via
  `quickstart.md`)
- Datenbank-/Validierungs-Bausteine vor dem jeweiligen Aufruf-Punkt
- `quickstart.md`-Validierung immer als letzter Task je Story

---

## Parallel Execution Examples

```bash
# US1 und US3 sind vollstaendig dateidisjunkt -> parallel bearbeitbar:
Task: "T001-T004 backend/includes/database.php + upload_handler.php (US1)"
Task: "T012 backend/includes/pdi_parser.php-Review + docs (US3)"

# Innerhalb von US2, T010 ist unabhaengig von T008/T009 parallelisierbar:
Task: "T008+T009 backend/includes/validation.php (US2, sequenziell)"
Task: "T010 backend/TESTING.md (US2, parallel zu T008/T009)"

# Polish-Phase: T017/T018/T019/T022 sind vier unterschiedliche Dateien:
Task: "T017 arc42/05-bausteinsicht.md"
Task: "T018 arc42/06-laufzeitsicht.md"
Task: "T019 docs/architecture/security-review-backend.md"
Task: "T022 arc42/11-risiken-und-technische-schulden.md"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1/2 entfallen (N/A)
2. T001-T004 umsetzen (Backend-Zähl-Check)
3. T005/T006 sind bereits umgesetzt — nur noch T007 (Validierung) offen
4. **STOP and VALIDATE**: `quickstart.md` Szenario 1 vollständig durchlaufen
5. Das eigentliche, im Feature-Wunsch benannte Kernrisiko ("unbegrenzt
   hochladen") ist an diesem Punkt bereits geschlossen — US2-US4 sind
   zusätzliche Härtung, kein Blocker für den MVP-Nutzen von US1

### Incremental Delivery

1. US1 (T001-T007) → Kernrisiko "unbegrenztes Hochladen" geschlossen (MVP)
2. US2 (T008-T011) → Ressourcen-Erschöpfung durch übergroße Einzeldateien
   geschlossen
3. US3 (T012-T013) → Format-Validierung verifiziert (kein neuer Code)
4. US4 (T014-T016) → Struktur-Validierung der Positionsdaten geschlossen
5. Polish (T017-T024) → Architektur-Evidenz vollständig, Cross-Story-Prüfung
   (T023) bestätigt korrektes Zusammenspiel

### Parallel Team Strategy

Mit zwei Personen: eine übernimmt US1+US3 (T001-T004, T012-T013, beide
dateidisjunkt zueinander UND zu US2/US4), die andere US2+US4 (T008-T009,
T014-T015, beide in `validation.php`, aber an nicht überlappenden Stellen).
T023 (Polish) erst nach Zusammenführung beider Zweige.

---

## Audit-Evidenz-Checkpoints (iSAQB-Preset)

| Checkpoint | Status | Evidenz | Owner |
|---|---|---|---|
| Architektur-Arbeitsprodukte (arc42 Kap. 5/6) | Applicable | T017/T018 umgesetzt: `arc42/05-bausteinsicht.md` (Baustein-Tabelle + Upload-Fluss) und `arc42/06-laufzeitsicht.md` (neuer Abschnitt 6.9, Ende-zu-Ende bis zur Geräte-Anzeige) aktualisiert | Entwickler |
| Sicherheits-Evidenz (`docs/architecture/security-review-backend.md`) | Applicable | T012/T019 umgesetzt: S-04 präzisiert, neue Einträge S-09/S-10/S-11 ergänzt | Entwickler |
| ADR-033 (Row-Lock-Zähl-Check) | Applicable | `arc42/adr/ADR-033-Upload-Limit-Row-Lock.md` angelegt (T020) | Entwickler |
| ADR-034 (JSON-Schema ohne Library) | Applicable | `arc42/adr/ADR-034-JSON-Schema-ohne-Library.md` angelegt (T021) | Entwickler |
| Risiko-/Schulden-Review (`arc42/11-...md`) | Applicable | T022 umgesetzt: R-19 (Sybil-Restrisiko, akzeptiert) und R-20 (Row-Lock-Dauer, Beobachtung) ergänzt, R-15 auf den neuen 300-KB/12-Bilder-Stand präzisiert | Entwickler |
| Constitution-V-Gates für `Source/SyncService.lua` (US1-Anteil) | Applicable | `lua tests/headless_tests.lua` → "ALLE TESTS BESTANDEN", `pdc`-Build sauber — bereits während der Planungsphase verifiziert (T005/T006, research.md R6) | Entwickler |
| PDI-Format-Validierung (FR-004/FR-005) | Applicable | Vollständig vorhanden, gegen den echten Code verifiziert (research.md R3) UND jetzt empirisch gegen die Produktion bestätigt (T013: fake.pdi + korrektes-Magic-kaputter-Rest beide 400 mit unterschiedlichem Fehlertext) | Entwickler |
| SC-005 Vier-Kategorien-Unterscheidbarkeit | Applicable | Auf API-Ebene durch das Contract-Design (403/413/400×2) sichergestellt UND empirisch bestätigt (T007/T011/T013/T016 lieferten in Produktion vier unterschiedliche Status-/Fehlertext-Kombinationen); Geräte-UI-Ebene bewusst auf Limit+Größe begrenzt (research.md R6-Ergänzung) | Entwickler |
| Empirische Produktions-Validierung (T007/T011/T013/T016/T023/T025) | Applicable | Am 2026-07-20 gegen https://www.hans-dither.de durchgeführt (nach Deployment) — alle sechs Quickstart-Szenarien bestanden, siehe `quickstart.md` Checkliste. Test-Daten (`test-limit-*`/`test-race-*`/`test-size-*`) per SSH aus DB und Dateisystem entfernt und verifiziert (0 verbleibende Einträge) | Entwickler |
| Multi-Geräte-/Sybil-Restrisiko | Open | Bewusst akzeptiert, nicht Teil des Scopes; Trigger zur Neubewertung: falls künftig eine serverseitige Lösch-Funktion entsteht (spec.md Edge Cases) oder Missbrauch beobachtet wird | Entwickler (spec.md Owner) |

---

## Phase 8: Convergence

- [X] T025 Add SC-006/FR-003 verification to the task list and run it: execute `quickstart.md` Szenario 6 (update-in-place/Re-Sync of an already-uploaded image continues to succeed once a device has reached its 12-image limit) against the deployed backend and check its box — no existing task references this scenario (T007 covers only Szenario 1) per FR-003 (missing). **Durchgeführt**: Re-Upload von img-01 (bekanntes Bild, UID bereits bei 12 Bildern) → 201 "Aktualisierung erfolgreich" (nicht 403); Bildanzahl danach weiterhin 12, nicht 13
