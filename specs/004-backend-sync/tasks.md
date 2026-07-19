# Tasks: Backend-Synchronisation für Hans Dither (Playdate-Seite)

**Input**: Design documents from `/specs/004-backend-sync/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/sync-protocol.md, quickstart.md; **Spec 005** (Backend-Service) muss deployt/deploybar sein (`backend/`, siehe `backend/TESTING.md` für lokale Testinstanz)

**Tests**: Headless-Tests (`lua tests/headless_tests.lua`) als Constitution Prinzip V Gate 1 (MUSS mit "ALLE TESTS BESTANDEN" enden) — gilt für alle `Source/*.lua`-Änderungen. Gate 2 (`pdc Source "Hans Dither.pdx"`) MUSS fehlerfrei durchlaufen. Backend-PHP-Änderungen (US2, Update-in-place) sind nicht durch Prinzip V erfasst; manuelle Validierung über quickstart.md.

**Organization**: Phasen nach User-Story-Priorität aus spec.md: US1 (P1, Verknüpfung) → US2 (P1, Einzelbild-Upload inkl. kleiner Backend-Erweiterung) → US3 (P2, Anzeige/Download — bereits durch Spec 005 abgedeckt).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelisierbar (andere Dateien, keine offenen Abhängigkeiten)
- **[Story]**: US1 (Verknüpfung), US2 (Einzelbild-Upload), US3 (Anzeige/Download)

## Path Conventions

Single project (Playdate-Lua) + kleine additive Erweiterung des bestehenden Backends: Quellcode unter `Source/`, Tests unter `tests/`, Backend unter `backend/` (Spec 005), Architektur-Doku unter `arc42/`, Feature-Doku unter `specs/004-backend-sync/`.

---

## Phase 1: Setup

**Purpose**: Modul-Gerüst anlegen, ohne bestehende Pfade zu brechen

- [X] T001 `Source/SyncService.lua` Grundgerüst anlegen: Modultabelle `SyncService = {}`, Konstanten (`BACKEND_URL`, `SYNC_GESTURE_THRESHOLD_DEGREES = 720`), Funktions-Stubs `SyncService:startSync(imageId)`, `SyncService:getState()`, `SyncService:saveState(state)` (contracts/sync-protocol.md Abschnitt 1) — *Erledigt: vollständige Datei angelegt (nicht nur Stubs, siehe Foundational/US1 unten)*
- [X] T002 ~~`Source/main.lua` erweitern~~ — *Abweichung von der Task-Beschreibung: `import "SyncService"` wurde stattdessen in `Source/SelectionRoom.lua` ergänzt, konsistent mit dem tatsächlichen Projekt-Konvention (RoomOperation/loadingBar werden ebenfalls vom jeweils konsumierenden Room importiert, nicht zentral in main.lua — siehe EditorRoom.lua). main.lua bleibt unverändert.*

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Gemeinsame Infrastruktur, die sowohl US1 (Pairing) als auch US2 (Upload) benötigen — MUSS vor beiden Story-Phasen abgeschlossen sein

**⚠️ CRITICAL**: Erst abschließen, dann Story-Phasen beginnen

- [X] T003 [P] Strikte Mocks in `tests/headless_tests.lua` ergänzt: `playdate.network.http.new` (Connection-Mock mit `:post`, `:setHeadersReadCallback`, `:setRequestCallback`, `:setRequestCompleteCallback`, `:setConnectionClosedCallback`, `:getResponseStatus`, `:getBytesAvailable`, `:read`, `:getError`), `playdate.datastore.write`/`.read`, `playdate.graphics.generateQRCodeSync`, `playdate.getCrankChange`/`isCrankDocked`, `playdate.ui.crankIndicator`, `playdate.json.encode`/`decode`, `kTextAlignment`, `dofile` für `RoomOperation.lua`/`loadingBar.lua` — *`playdate.file.open`/`:read` bewusst auf die US2-Runde verschoben (noch nicht exerciert, siehe T017)*
- [X] T004 [P] PIN-/UID-Generierung + lokale Persistenz in `Source/SyncService.lua`: `SyncService:generatePin()`, `SyncService:generateUid()`/`getOrCreateUid()`, `getState()`/`saveState()` über `playdate.datastore.write/read("sync/state")` — *Erweitert um UID-Generierung: das SDK bietet keine Geräte-Seriennummer (research.md R10, spec.md FR-001 entsprechend korrigiert)*
- [X] T005 Crank-Akkumulator in `Source/SelectionRoom.lua` `update()`/`handleCrank()`: kumulierte Rotation via `playdate.getCrankChange()` (jeden Frame gedraint, auch außerhalb des Akkumulierens — verhindert Nachhol-Spikes), Reset bei Selektionswechsel/Richtungswechsel (Clamp auf 0), Trigger von `SyncService:startSync(imageId)` bei ≥720°
- [X] T006 [P] Crank-Hinweisanzeige in `Source/SelectionRoom.lua`: Text "crank to sync"/"unfold crank to sync" (je nach `isCrankDocked()`) + `playdate.ui.crankIndicator:draw()` bei selektiertem Bild — *crankIndicator übernimmt laut SDK-Doku selbst die Doppelrolle "Crank drehen"/"Crank ausklappen", kein separates Widget nötig. Korrektur nach Nutzer-Feedback (Simulator-Test): Hinweistext + Statuszeile ursprünglich oben positioniert, jetzt unten rechts direkt oberhalb des SDK-Crank-Indicators (der sich selbst unten rechts platziert), über `playdate.ui.crankIndicator:getBounds()` dynamisch berechnet — bleibt so unabhängig von Position/Breite der Bauchbinde (unten links).*
- [X] T007 Authentifizierter Login-Request in `Source/SyncService.lua`: `login()` als Coroutine (`httpPostAndWait`), callback-getrieben (niemals blockierendes `read()`), Auswertung 200/404/400/429 gemäß contracts/sync-protocol.md
- [X] T008 [P] QR-Code-Anzeige in `Source/SyncService.lua`: `SyncService:getQrImage(uid)`, gecacht pro UID, gezeichnet im Pairing-Prompt-Overlay — *Korrektur nach Simulator-Test: `generateQRCodeSync` ist in SDK v3.0.6 wegen eines Scoping-Bugs in `CoreLibs/qrcode.lua` defekt (crasht immer mit "global 'generateQRCodeImage' is not callable" — kein Mock-Fall, echter Implementierungsfehler im CoreLibs-Code). Umgestellt auf die asynchrone `generateQRCode`-Variante; dafür `playdate.timer.updateTimers()` neu in `main.lua:playdate.update()` ergänzt. Siehe research.md R3-Korrektur.*

**Checkpoint**: SyncService-Grundgerüst, Crank-Erkennung, Login-Request und QR-Anzeige stehen — beide Story-Phasen können beginnen. **Verifiziert**: Headless-Tests (Gate 1) + `pdc`-Build (Gate 2) grün. **NICHT verifiziert**: tatsächliches Netzwerk-Handshake, Crank-Gefühl und QR-Scanbarkeit auf echter Hardware/Simulator (siehe T013).

---

## Phase 3: User Story 1 — Playdate mit Backend verknüpfen (Priority: P1) 🎯 MVP

**Goal**: Playdate generiert PIN + QR-Code bei erster Crank-Sync-Geste, Nutzer bestätigt im Browser, Playdate erkennt die Verknüpfung bei der nächsten Crank-Geste (FR-002–FR-006a, FR-012)

**Independent Test**: quickstart.md Szenario 1–4 (Crank-Hinweis, PIN+QR-Generierung, Browser-Pairing, Statuserkennung)

### Implementation for User Story 1

- [X] T009 [US1] Pairing-Einstieg in `Source/SyncService.lua`: `startSync(imageId)` verzweigt bei `paired == false` in `startPairingCheck()` — PIN wird bei Bedarf generiert und gespeichert, Pairing-Prompt (QR+PIN) erscheint bei `404`-Antwort (FR-003, FR-004)
- [X] T010 [US1] Statuscheck-Integration in `Source/SyncService.lua`: `startPairingCheck()` ruft `login()` mit UID+PIN auf; `404` → Pairing-Prompt zeigen; `200` → `paired = true`, `sync/state` aktualisieren, Prompt schließen (FR-006a) — *Korrektur nach zweitem Simulator-Test (Nutzer-Feedback)*: läuft NICHT mehr nur bei expliziter Crank-Geste, sondern zusätzlich automatisch periodisch (`SyncService:tick()`, alle 3s, 5-Min.-Budget), solange der Prompt sichtbar ist — sicher, da `404` die Backend-Sperre nie auslöst (research.md R11, ersetzt die vorherige FR-006a-Fassung). `200` kettet zusätzlich automatisch in `startUpload(imageId)` (FR-006b), sodass ein einziger Crank bis zum tatsächlichen Upload durchläuft.
- [X] T011 [US1] Verknüpfungsstatus-Anzeige in `Source/SelectionRoom.lua`: `drawSyncStatus()` zeigt "verknüpft mit www.hans-dither.de" / "nicht verknüpft" — *Position nach Nutzer-Feedback von oben rechts auf unten rechts korrigiert (siehe T006-Notiz)* (FR-012)
- [X] T012 [US1] Fehlerbehandlung für US1 in `Source/SyncService.lua`: `429` → Statusmeldung "Zu viele Fehlversuche", Auto-Polling stoppt; Netzwerkfehler → Fehlermeldung, `isBusy()` wird in JEDEM Fall (auch bei Coroutine-Fehler) zuverlässig zurückgesetzt — *Korrektur nach zweitem Simulator-Test*: `400` (PIN abgelehnt) generiert NICHT mehr automatisch eine neue PIN (das behebt einen bereits im Backend falsch fixierten Hash nicht und würde durch Auto-Polling die Sperre selbst auslösen, siehe research.md R12) — PIN bleibt unverändert, Auto-Polling stoppt sofort, Nutzer wird auf erneutes Website-Pairing verwiesen (jetzt möglich, siehe T039).
- [X] T013 [US1] Validierung durchführen und protokollieren: quickstart.md Szenario 1–4 und 7 im Simulator/auf Hardware — **durchgeführt (zweiter Simulator-Lauf)**: Nutzer testete den vollständigen Pairing-Flow real (QR anzeigen, Website öffnen, PIN eingeben) und meldete zwei konkrete Befunde zurück, die zu dieser Korrekturrunde führten — (1) keine Verknüpfung/kein Upload trotz PIN-Eingabe (Root Cause: irreführender Website-Formulartext, siehe research.md R12/T039, NICHT ein Playdate-seitiger Bug), (2) der Ablauf "PIN eingeben, zurück zum Gerät, erneut cranken" wirkte unnötig umständlich (→ Auto-Polling, research.md R11). Beide Punkte behoben und erneut gegen beide Gates verifiziert (Headless-Tests grün inkl. neuer Polling-/Upload-Ketten-Tests, `pdc`-Build fehlerfrei). **Weiterhin NICHT erneut auf echtem Gerät/Simulator verifiziert**: der komplette End-to-End-Ablauf nach dieser Korrekturrunde (insbesondere Auto-Polling-Gefühl/Timing, Website-Formular-Wortlaut in der Praxis), das verschachtelte-Coroutine-Verhalten des Netzwerk-Permission-Dialogs, `Content-Length`-Verhalten von `post()`. **Owner**: Projektinhaber, **Re-Evaluation-Trigger**: nächster Simulator-/Hardware-Lauf, Ergebnis hier eintragen.

**Checkpoint**: Erstverknüpfung per QR-Code inkl. Auto-Polling und Auto-Chaining zum Upload ist headless-logisch vollständig und durch alle Headless-Tests + `pdc`-Build abgesichert — **End-to-End-Ablauf nach dieser Korrekturrunde auf dem Gerät/Simulator noch nicht erneut getestet** (T013 offen)

---

## Phase 4: User Story 2 — Einzelbild zum Backend hochladen (Priority: P1)

**Goal**: Verknüpftes Playdate lädt per Crank-Geste genau ein selektiertes Bild hoch, ohne erneute PIN-Eingabe; wiederholter Sync desselben Bildes aktualisiert den bestehenden Backend-Eintrag statt ein Duplikat anzulegen (FR-006, FR-007, FR-007a, FR-007b, FR-014, FR-015)

**Independent Test**: quickstart.md Szenario 5, 6, 10, 11 (Einzelbild-Upload, Sichtbarkeit im Backend, Netzwerkfehler, zurückgesetzte Verknüpfung)

### Backend-Erweiterung (klein, additiv, rückwärtskompatibel — Voraussetzung für Update-in-place)

- [X] T014 [P] [US2] SQL-Migration `backend/sql/migrations/002_sync_extensions.sql` angelegt: `ALTER TABLE images ADD COLUMN client_image_id ...` + `UNIQUE KEY uniq_uid_client_image_id (uid, client_image_id)` (data-model.md "Backend-Erweiterung", research.md R9) — *erweitert um `ALTER TABLE users ADD COLUMN confirmed_at ...` im selben Migrationsfile, da beide additiven Änderungen in derselben Runde nötig wurden (research.md R12, siehe T039)*
- [X] T015 [US2] `backend/includes/upload_handler.php` erweitert: `handleUpload()` um optionalen Parameter `$client_image_id` ergänzt; falls gesetzt und `(uid, client_image_id)` bereits vorhanden → bestehende Dateien überschreiben, `png_path`/`gif_path` auf `NULL` setzen, `uploaded_at` aktualisieren (UPDATE statt INSERT); sonst wie bisher neuen Eintrag mit `client_image_id` anlegen (FR-007b, research.md R9). `php -l` fehlerfrei.
- [X] T016 [US2] `backend/public/upload.php` erweitert: `$_POST['image_id']` ausgelesen (Format `[a-z0-9-]+` defensiv validiert, ungültige Werte auf `null` gesetzt) und an `UploadHandler::handleUpload()` durchgereicht (contracts/sync-protocol.md Abschnitt 2 Schritt B). `php -l` fehlerfrei.

### Implementation for User Story 2 (Playdate-Seite)

- [X] T017 [P] [US2] Rohes Datei-Lesen in `Source/SyncService.lua`: `SyncService:readFileBytes(path)` über `playdate.file.open(path, playdate.file.kFileRead)` + `playdate.file.getSize(path)` für `saves/{imageId}/sheet.pdi` und `saves/{imageId}/frames.json` (data-model.md, NICHT über `playdate.datastore.read()`). Neuer strikter `playdate.file`-Mock in `tests/headless_tests.lua` (separates Backing Store von `playdate.datastore`, testet rohe Byte-Strings statt Lua-Tabellen).
- [X] T018 [US2] Multipart-Body-Builder in `Source/SyncService.lua`: `SyncService:buildMultipartBody(boundary, uid, token, imageId, pdiBytes, jsonBytes)` mit zufälligem Boundary-String (`generateBoundary()`), Parts `uid`/`token`/`image_id`/`pdi`/`json` exakt gemäß contracts/sync-protocol.md Abschnitt 2 — *Abweichung von der Task-Signatur: `boundary` als expliziter Parameter statt intern generiert, damit der Builder isoliert testbar ist (Constitution Prinzip V)*
- [X] T019 [US2] Upload-Coroutine in `Source/SyncService.lua`: `attemptUpload(imageId)` — Schritt A: `login()` (T007) für `session_token` (gecachte PIN, keine erneute Eingabe); Schritt B: `POST /upload` mit Multipart-Body (T018); Fortschrittsanzeige über bestehendes `loadingBar`-Muster via `RoomOperation` (FR-015, SC-006)
- [X] T020 [US2] Upload-Einstieg in `Source/SyncService.lua`: `SyncService:startSync(imageId)` verzweigt bei `paired == true` in `startUpload(imageId)` statt Pairing-Pfad (FR-006, FR-007) — *erweitert um FR-006b: `startPairingCheck`s Erfolgsfall (`200`) ruft `startUpload(imageId)` ebenfalls auf, verkettet Pairing automatisch mit dem ursprünglich gecrankten Upload (Nutzer-Feedback, research.md R11)*
- [X] T021 [US2] Post-Upload-QR-Anzeige in `Source/SyncService.lua`: nach erfolgreichem Upload (`201`) `resultQrActive = true` (FR-007a) — *eigener Zustand statt Wiederverwendung von `pairingPromptActive`, da der Post-Upload-Prompt kein PIN-Feld zeigen darf (Gerät ist bereits verknüpft); `SyncService:isShowingQrOverlay()`/`dismissQrOverlay()` decken beide Overlay-Arten für SelectionRoom ab*
- [X] T022 [US2] Fehlerbehandlung für US2 in `Source/SyncService.lua`: Verbindungsabbruch während Upload → `pendingUpload` in `sync/state` gesetzt (research.md R8); `401` bei Upload → `uploadWithRetry()` versucht `login()`+Upload genau einmal erneut; lokal gespeicherte PIN von `/login` abgelehnt (`not_paired`/`unauthorized`/`token_expired` nach Retry) → Fehler "Nicht autorisiert – bitte erneut verknüpfen", Rücksprung zu US1-Pairing-Pfad; `413` → Fehlermeldung "Datei zu groß für Upload" (Edge Cases in spec.md)
- [ ] T023 [US2] Validierung durchführen und protokollieren: quickstart.md Szenario 5, 6, 10, 11 im Simulator gegen lokale/echte Backend-Instanz — **NICHT durchgeführt** (kein Simulator-/Geräte-Zugriff in dieser Session). Headless verifiziert: vollständige Pairing→Auto-Chain→Upload-Kette (5 aufeinanderfolgende Coroutine-Yields über 2 simulierte Logins + 1 simulierten Upload), 401-Retry-Pfad, Netzwerkfehler→`pendingUpload`. **Owner**: Projektinhaber, **Re-Evaluation-Trigger**: nächster Simulator-/Hardware-Lauf (gemeinsam mit T013).

**Checkpoint**: Einzelbild-Upload inkl. Update-in-place bei Re-Sync und automatischer Verkettung ans Pairing ist headless-logisch vollständig und durch alle Headless-Tests + `pdc`-Build abgesichert — **auf dem Gerät/Simulator noch nicht getestet** (T023 offen, siehe T013)

---

## Phase 5: User Story 3 — Projekte im Backend anzeigen und herunterladen (Priority: P2)

**Goal**: Hochgeladene Bilder in der Backend-Bilderliste ansehen/herunterladen (FR-008–FR-011)

**Independent Test**: quickstart.md Szenario 6 (Post-Upload-QR → Backend-Login → Bilderliste)

- [ ] T024 [US3] Regressionscheck: Bereits vollständig durch Spec 005 (US1–US3, `backend/public/index.php` + `download.php`) implementiert — **keine neue Implementierung nötig**. Einzige Prüfung: Nach Update-in-place (T015) muss das aktualisierte Bild mit neu generierter PNG/GIF-Vorschau in der Liste erscheinen (nicht die alte, gecachte Vorschau) — manuell verifizieren, dass `png_path`/`gif_path = NULL` nach Update tatsächlich Neu-Rendering beim nächsten Abruf auslöst (`backend/includes/renderer.php`, on-demand-Pfad aus Spec 005)

**Checkpoint**: Alle drei User Stories unabhängig funktionsfähig

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Architektur-Dokumentation, Sicherheits-Review, offene Risiken

- [ ] T025 [P] arc42-Ist-Kapitel aktualisieren: `arc42/04-loesungsstrategie.md` (Abschnitt 4.4 "Nicht-Ziele" — Zeilen "Kein Cloud-Sync"/"Keine Netzwerk-... funktionen" entfernen/historisieren, siehe Constitution v1.2.0 Sync Impact Report), `arc42/05-bausteinsicht.md` (neuer Baustein `SyncService`), `arc42/06-laufzeitsicht.md` (Laufzeitszenarien Pairing/Upload/Statuscheck), `arc42/08-querschnittliche-konzepte.md` (Authentifizierung via gerätegenerierter PIN, Netzwerkkommunikation/Coroutine-Pflicht), `arc42/10-qualitaetsanforderungen.md` (SC-001–SC-006), `arc42/11-risiken-und-technische-schulden.md` (R-17 PIN-Caching, R-18 Multipart-Boundary, R-19 Contract-Doku-Diskrepanz, R-20 Migrationsreihenfolge) — Evidenz: Feature-Branch-Diff (Constitution III)
- [ ] T026 [P] ADRs dokumentieren in `arc42/adr/`: `ADR-021-QR-basiertes-Pairing.md`, `ADR-022-Geraeteseitige-PIN.md`, `ADR-023-Backend-Integration.md`, `ADR-024-Offline-Queue.md`, `ADR-029-Crank-Geste-statt-System-Menue.md`, `ADR-030-Update-in-place-Re-Sync.md` — Status: umgesetzt
- [ ] T027 [P] Security-Review-Dokument erstellen: `docs/architecture/security-review-sync.md` mit Checkliste: PIN-Generierung/Caching-Risiko (R-17), HTTPS-Erzwingung (bereits Spec 005), Autorisierung pro Request, Multipart-Boundary-Kollisionsrisiko (R-18)
- [ ] T028 Multipart-Boundary-Kollisionsschutz in `Source/SyncService.lua`: entweder hinreichend zufälligen/langen Boundary-String sicherstellen und bewusst als akzeptiertes Restrisiko in `docs/architecture/security-review-sync.md` dokumentieren, oder Escaping/Prüfung ergänzen (Open-Punkt aus plan.md, Owner: Projektinhaber)
- [ ] T029 [P] Follow-up-Notiz in `specs/005-backend-service/contracts/backend-api.md`: Hinweis ergänzen, dass die dort beschriebene X-UID/X-PIN-Header-Alternative für `/upload` (E-04) im tatsächlichen Code nicht existiert (research.md R5) — kein Code-Fix, nur Dokumentationskorrektur außerhalb des 004-Scopes

---

## Phase 7: Validation & Testing

**Purpose**: Abschließende Verifikation gegen Constitution-Gates und quickstart.md

- [ ] T030 Constitution-Gate 1: `lua tests/headless_tests.lua` ausführen — MUSS mit "ALLE TESTS BESTANDEN" enden (inkl. neuer Mocks/Tests aus T003 und Testabdeckung für Crank-Akkumulator, Multipart-Body-Bau, Statuscode-Auswertung)
- [ ] T031 Constitution-Gate 2: `pdc Source "Hans Dither.pdx"` — MUSS fehlerfrei durchlaufen
- [ ] T032 quickstart.md vollständig im Simulator durchlaufen (alle 11 Szenarien) inkl. Performance-Messung (SC-001 < 2 Min, SC-005 < 5 Min); Befunde protokollieren

---

## Dependencies

```text
Phase 1 (Setup) → Phase 2 (Foundational) → US1 (Phase 3) ─┬→ US2 (Phase 4) → US3 (Phase 5, Regressionscheck)
                                                            └→ (US2 kann erst nach US1 sinnvoll getestet werden,
                                                               da Upload eine bestehende Verknüpfung voraussetzt)
Phase 6 (Polish) → kann parallel zu Phase 5 laufen
Phase 7 (Validation) → braucht alle vorherigen Phasen
```

- US1 → braucht T001–T008 (Setup + Foundational)
- US2 → braucht US1 (Verknüpfung muss funktionieren, `paired == true`) + T014–T022; Backend-Erweiterung (T014–T016) kann parallel zur Playdate-seitigen Implementierung (T017–T022) laufen
- US3 → braucht US2 (mind. ein erfolgreicher Upload zum Verifizieren); ansonsten keine neue Implementierung (Spec 005)
- Phase 6 (arc42/ADRs/Security) → kann parallel zu Phase 4/5 laufen
- Phase 7 (Validation) → braucht alle Phasen 1–6

## Parallel Execution Examples

- **Phase 2**: T003 (Mocks) ∥ T004 (PIN/State) ∥ T006 (Hinweisanzeige) ∥ T008 (QR-Anzeige) — verschiedene Bereiche; T005 und T007 haben Abhängigkeiten (T005 → T001, T007 → T004)
- **Phase 4**: T014 (Migration) ∥ T017 (Datei-Lesen) — unabhängige Dateien; T015 → T014, T016 → T015, T018 → T017, T019 → T007+T018
- **Phase 6**: T025 (arc42) ∥ T026 (ADRs) ∥ T027 (Security-Review) ∥ T029 (Contract-Doku-Notiz) — verschiedene Dateien

## Implementation Strategy

1. **MVP = Phase 1 + 2 + US1**: Playdate kann sich per QR-Code + geräteseitiger PIN mit dem Backend verknüpfen
2. **Inkrement 2 = US2**: Einzelbild-Upload inkl. kleiner Backend-Erweiterung für Update-in-place
3. **Inkrement 3 = US3**: Regressionscheck (keine neue Implementierung, nutzt Spec 005 vollständig)
4. **Inkrement 4 = Phase 6**: arc42-Dokumentation, ADRs, Security-Review
5. **Abschluss = Phase 7**: Vollständige Validierung gegen beide Constitution-Gates und alle quickstart-Szenarien
6. Jedes Inkrement wird über die zugehörigen quickstart-Szenarien abgenommen

## Audit-Evidenz-Checkpoints (iSAQB-Preset)

- [ ] Architektur-Sichten aktualisiert: T025 (arc42 Kap. 4/5/6/8/10/11) — Evidenz: Feature-Branch-Diff
- [ ] ADRs gepflegt: T026 (AD-021, AD-022, AD-023, AD-024, AD-029, AD-030) — Evidenz: `arc42/adr/`
- [ ] Risiko-/Schulden-Review: T025 (R-17 PIN-Caching, R-18 Multipart-Boundary, R-19 Contract-Doku-Diskrepanz, R-20 Migrationsreihenfolge) — Evidenz: `arc42/11-risiken-und-technische-schulden.md`
- [ ] Secure-Architecture: T027 (Security-Review-Dokument) — Evidenz: `docs/architecture/security-review-sync.md` + quickstart.md Validierungsprotokoll
- [ ] Offener Punkt (Open): Multipart-Boundary-Kollisionsschutz — T028, Owner: Projektinhaber, Follow-up: `Source/SyncService.lua` Boundary-Generierung, Re-Evaluation: vor erstem produktivem Upload großer PDI-Dateien
- [ ] Offener Punkt (Open): Contract-Doku-Korrektur Spec 005 (X-UID/X-PIN) — T029, Owner: Projektinhaber, Follow-up: separates Ticket außerhalb 004, Re-Evaluation: nächste Backend-Iteration
- [ ] Offener Punkt (Open): Security-Review + ADR für T040 (Re-Pairing unbestätigter UIDs, `users.confirmed_at`) — Auth-Semantik-Änderung an Spec 005, noch nicht durch T027/T033–T038 abgedeckt, Owner: Projektinhaber, Re-Evaluation: vor Abschluss von Phase 6
- [ ] N/A: Verteilungssicht (arc42 Kap. 7) — keine neue Deployment-Einheit, dieses Feature ist Teil der bestehenden `.pdx`-Build-Pipeline plus additiver Erweiterung der bereits deployten Backend-Einheit (Spec 005)

---

## Architecture Governance Tasks

- [ ] T033 [P] ADR-Template für AD-021 erstellen: Entscheidung für QR-basiertes Pairing, Kontext (Playdate ohne Tastatur), Alternativen (manuelle UID-Eingabe wie Spec 005), Konsequenzen — in `arc42/adr/ADR-021-QR-basiertes-Pairing.md`
- [ ] T034 [P] ADR-Template für AD-022 erstellen: Geräteseitig generierte PIN statt Nutzer-PIN, Begründung (kein Tastatur-Input nötig, lokales Caching) — in `arc42/adr/ADR-022-Geraeteseitige-PIN.md`
- [ ] T035 [P] ADR-Template für AD-023 erstellen: Backend-Integration — überwiegende Wiederverwendung von Spec 005, Grenzen der additiven Erweiterung — in `arc42/adr/ADR-023-Backend-Integration.md`
- [ ] T036 [P] ADR-Template für AD-024 erstellen: Offline-Queue vereinfacht auf Einzelbild-Zustand (`pendingUpload`) — in `arc42/adr/ADR-024-Offline-Queue.md`
- [ ] T037 [P] ADR-Template für AD-029 erstellen: Crank-Geste statt System-Menü-Eintrag, SDK-3-Slot-Limit als Auslöser, verworfene Alternativen (Menüpunkt ersetzen, Options-Menu-Item) — in `arc42/adr/ADR-029-Crank-Geste-statt-System-Menue.md`
- [ ] T038 [P] ADR-Template für AD-030 erstellen: Update-in-place bei Re-Sync via client-seitiger Bild-ID, Advisor-Review als Auslöser, verworfene Alternative (Duplikat-Verhalten) — in `arc42/adr/ADR-030-Update-in-place-Re-Sync.md`

---

## Nachtrag: Pairing-Konsistenz-Fixes nach zweitem Simulator-Test (Nutzer-Feedback, außerhalb des ursprünglichen Taskplans)

**Kontext**: Nach Abschluss von T001–T022 führte der Projektinhaber einen zweiten realen Simulator-Test durch (Pairing über QR-Code, Website, PIN-Eingabe) und meldete zurück, dass keine Verknüpfung und kein Upload erfolgten. Die Analyse (siehe research.md R11/R12) ergab zwei unabhängige Korrekturen, die nicht im ursprünglichen 38-Task-Plan enthalten waren, aber notwendig sind, damit der Ablauf tatsächlich funktioniert:

- [X] T039 [US1] Backend-Formulartext korrigiert (`backend/public/index.php::showPairForm()`): weist jetzt explizit auf die auf dem Playdate angezeigte PIN hin statt eine frei erfundene PIN nahezulegen — Root Cause des gemeldeten Fehlers (research.md R12, FR-004a-Korrektur). `php -l` fehlerfrei.
- [X] T040 [US1] [Sicherheitsrelevant] Re-Pairing für unbestätigte UIDs in `backend/includes/auth.php` (`Auth::pair()`, `Auth::login()`, neue `Auth::isConfirmed()`) + `backend/public/index.php`-Routing (`showUidForm`, `showPairForm` nutzen `isConfirmed()` statt `uidExists()`) — verhindert, dass eine versehentlich falsch übertragene PIN die UID dauerhaft blockiert (FR-004b, research.md R12). Nutzt die neue `users.confirmed_at`-Spalte aus T014s erweiterter Migration. **Offen**: Security-Review-Nachtrag (T027) und ADR (analog T033–T038) für diese Auth-Semantik-Änderung stehen noch aus — Owner: Projektinhaber, Re-Evaluation-Trigger: vor Abschluss von Phase 6.
- [X] T041 [US2] `backend/deploy.sh` um idempotente `client_image_id`/`confirmed_at`-Spaltenchecks ergänzt (exakt gleiches Muster wie der bestehende `gif_path`-Check) — **kritischer Fund bei der Vor-Deploy-Prüfung**: `deploy.sh` spielt automatisch NUR `sql/migrations/001_create_tables.sql` ein; `002_sync_extensions.sql` (T014) wäre ohne diesen Nachtrag beim nächsten Deploy NIE angewendet worden. Ohne die Spalten würde `Auth::isConfirmed()` (von `index.php` bei JEDEM QR-Scan aufgerufen) mit einem SQL-Fehler abbrechen — die Website wäre nach einem PHP-Deploy ohne DB-Migration komplett down, nicht nur der Sync. `bash -n deploy.sh` fehlerfrei. **Wichtig für den nächsten Deploy**: Migration wird beim SSH-Deploy-Pfad automatisch mitgezogen; beim reinen rsync-Pfad (kein SSH) MUSS `002_sync_extensions.sql` weiterhin manuell gegen die DB ausgeführt werden.
- [X] T042 [US1] Zwei Advisor-Review-Funde behoben, ohne die eigentliche Logik zu ändern: (1) Race Condition — B-Taste während eines in Flug befindlichen Auto-Polls konnte den bereits geschlossenen Prompt Sekundenbruchteile später wieder aufreißen, da das Poll-Ergebnis blind `pairingPromptActive = true` gesetzt hat; behoben über einen `syncGeneration`-Zähler (`dismissQrOverlay()` erhöht ihn, `handlePairingResult()` verwirft veraltete Ergebnisse). (2) loadingBar-Overlay wäre bei jedem automatischen Poll-Zyklus (alle 3s) kurz über dem QR-Code aufgeblitzt; automatische Polls laufen jetzt über eine eigene, overlay-freie Coroutine (`pollCo` in `SyncService:tick()`) statt über `RoomOperation`+`loadingBar` — Letzteres bleibt reserviert für den initialen, nutzerausgelösten Check und Uploads. Neuer Regressionstest in `tests/headless_tests.lua` ("B-Taste waehrend laufendem Auto-Poll..."). Beide Gates erneut grün.

---

## Nachtrag: Autonomes Pairing-Redesign nach drittem Simulator-Test (Screenshot-Feedback, außerhalb des ursprünglichen Taskplans)

**Kontext**: Trotz T039–T042 meldete der Projektinhaber per Screenshot erneut, dass der Ablauf für ihn nicht nachvollziehbar sei, und stellte die zugrunde liegende Prämisse selbst infrage — wozu muss das Gerät auf eine Website-Bestätigung warten, wenn es uid UND PIN ohnehin beide selbst erzeugt? Advisor-Review bestätigte: kein Sicherheitsgewinn durch das Gate, nur zusätzliche Fehlerfälle. Ergebnis (research.md R13–R15, siehe auch spec.md Clarifications):

- [X] T043 [US1] [US2] `Source/SyncService.lua` grundlegend umgebaut: `POST /pair` wird jetzt direkt vom Gerät aufgerufen (`ensurePairedAndLoggedIn()`), ausgelöst automatisch, sobald `/login` mit `not_paired`(404)/`unauthorized`(400) fehlschlägt, gefolgt von genau einem Login-Retry — kein Website-Bestätigungsschritt mehr vor dem Upload nötig (FR-004, FR-004a, FR-004b, FR-006a, FR-006b neu gefasst). `429` (gesperrt) löst bewusst KEINEN automatischen Pairing-Versuch aus. Backend-seitig keine Änderung nötig: `POST /pair` liefert für Nicht-Formular-Aufrufe bereits JSON (verifiziert in `backend/public/index.php::handlePairRequest()`), **kein Redeploy erforderlich**.
- [X] T044 [US1] [US2] Gesamtes Auto-Polling-Subsystem aus T042 ersatzlos entfernt (`pollCo`, `pollingActive`, `nextPollAtMs`, `pollDeadlineAtMs`, `POLL_INTERVAL_MS`, `POLL_TIMEOUT_MS`, `pairingSubStatus`, `syncGeneration`-Race-Guard) — ohne mehrsekündiges Hintergrund-Polling entfällt die Race-Bedingung, die dieser Mechanismus ursprünglich absicherte. `pairingPromptActive`/`resultQrActive` zu einem einzigen `resultModalActive` zusammengeführt, das erst NACH erfolgreichem Upload gesetzt wird.
- [X] T045 [US1] [US2] Vollbild-Ergebnis-Overlay (`SyncService:drawResultModal()`, 400×240 opak) ersetzt die vorherige kleine, zentrierte Box — behebt das vom Nutzer gemeldete "durchscheinende Kreisraster hinter der Box"; Statuszeile und Crank-Hinweis in `SelectionRoom.lua` werden zusätzlich explizit unterdrückt, solange das Overlay sichtbar ist. QR-Code-Generierung wird bereits bei `startSync()` angestoßen (parallel zum Netzwerk-Roundtrip, research.md R15) statt erst beim ersten Zeichnen des Ergebnisscreens — reduziert die vom Nutzer bemängelte wahrgenommene Wartezeit.
- [X] T046 [US1] [US2] Alle Sync-UI-Strings in `Source/SyncService.lua` (Statuszeile, Fehlermeldungen, `loadingBar`-Detailtexte, Ergebnisscreen) auf Englisch/ASCII-only umgestellt — behebt die vom Nutzer per Screenshot gemeldete "�"-Darstellung von Umlauten/Halbgeviertstrich (Playdate-System-Font deckt diese Zeichen nicht ab, research.md R14). Repo-weiter Grep bestätigte: nur `SyncService.lua` betroffen, restliche App-UI war bereits durchgehend Englisch/ASCII.
- [X] T047 [US1] [US2] `tests/headless_tests.lua` vollständig auf die neue Kette umgeschrieben (Login→Self-Heal-Pair→Upload statt Statuscheck+Polling+verkettetem Upload) — neue Fälle: autonomes Erst-Pairing nach `404`, PIN-Self-Heal nach `400`, `429` löst kein Pairing aus, `/pair`-`409`-Konflikt bricht klar ab statt zu retryen. Alle bestehenden Fälle (401-Retry, Netzwerkfehler→`pendingUpload`, Crank-Hinweis-Permanenz) unverändert grün. Beide Constitution-Gates (`lua tests/headless_tests.lua`, `pdc Source "Hans Dither.pdx"`) grün.

---

## Nachtrag: Log-Instrumentierung + Simulator-Dev-Testtrigger (Entwicklerwerkzeug-Feedback, außerhalb des ursprünglichen Taskplans)

**Kontext**: Nutzer bat um Log-Meldungen für den gesamten Login/Pairing/Upload-Ablauf (bessere Nachvollziehbarkeit im Simulator) sowie um Möglichkeiten, den Roundtrip modular gegen das echte Backend zu testen, ohne jedes Mal eine Crank-Geste zu benötigen. Reines Entwicklungswerkzeug, keine FR-Änderung (research.md R16).

- [X] T048 [US1] [US2] `Source/SyncService.lua`: einheitliches `logSync(...)`-Logging (`"[Sync] ..."`-Präfix) inkl. Laufzeitmessung für jeden HTTP-Request, die QR-Generierung und die Gesamtkette, ergänzt in `httpPostAndWait`, `pair`, `login`, `ensurePairedAndLoggedIn`, `attemptUpload`, `uploadWithRetry`, `getQrImage`, `startSync`, dem Kettenabschluss-Callback und `tick`. Fünf Dev-Testtrigger (Login/Pair/voller Roundtrip/State-Dump/Pairing-Reset) über `playdate.keyPressed` (Tasten `0`–`4`, laut SDK simulator-only, kein Zusatz-Gate nötig) — Login-/Pair-Test rufen dieselben internen Funktionen wie die Hauptkette auf, kein Duplikat-Code; ein neues gemeinsames `runOperation(...)`-Gerüst ersetzt den vorher inline in `startUpload` liegenden `RoomOperation`-Boilerplate. Beide Constitution-Gates (`lua tests/headless_tests.lua`, `pdc Source "Hans Dither.pdx"`) grün.
- [X] T049 [US1] [Sicherheitsrelevant für Ablauf-Korrektheit, kein Security-Bug] Ein erster echter Simulator-Testlauf mit dem neuen Logging (T048) deckte sofort einen Bug auf: `httpPostAndWait` behandelte `status == 0` (keine echte Server-Antwort, z. B. Verbindungsfehler) wie einen validen HTTP-Status, wodurch `login()` das fälschlich als `"unauthorized"` einstufte und automatisch einen (ebenfalls scheiternden) Auto-Pair-Versuch auslöste (research.md R17). Backend selbst per `curl` gegen `/login` und `/pair` verifiziert gesund (korrekte 404/201, gültige TLS-Kette über HTTP/1.1 und HTTP/2) — **kein Redeploy nötig**, reiner Client-seitiger Logik-Fix. `httpPostAndWait` behandelt `status == nil` und `status == 0` jetzt einheitlich als Netzwerkfehler und loggt `connection:getError()` im Klartext. Beide Constitution-Gates grün.
- [X] T050 [US1] Nutzer-Rückfrage nachrecherchiert, ob ein fehlender expliziter `playdate.network.http.requestAccess()`-Aufruf die Ursache ist (research.md R18). Gegen SDK-Doku und offizielles Lua-Beispiel (`Examples/Networking/.../main.lua`) verifiziert: nicht nötig, `new()` fragt automatisch, das offizielle Beispiel nutzt `requestAccess()` ebenfalls nicht. Direkt auf der Festplatte verifiziert, dass die Berechtigung für `de.merlinbecker.hansdither` in der tatsächlich genutzten Simulator-Instanz bereits erteilt war (`Disk/Data/de.merlinbecker.hansdither/Permissions` enthielt `net+`). `connection:setConnectTimeout(8)` ergänzt (fehlte bisher, offizielles Beispiel setzt es explizit) — erklärt die auffällig konstante ~3.2s-Fehlerdauer als vermutlich SDK-Default statt Zufall, behebt aber nicht die zugrunde liegende Verbindungsstörung selbst. Auf Nutzerwunsch `sync/state.json` UND `Permissions` in beiden lokalen Simulator-Datenverzeichnissen zurückgesetzt (Crank-Hinweis erscheint wieder; Berechtigungsdialog wird beim nächsten Versuch nachweislich neu gezeigt, `saves/` unangetastet). Test-Mock in `tests/headless_tests.lua` um `setConnectTimeout` ergänzt. Beide Constitution-Gates grün.

---

## Nachtrag: `NO RESPONSE` bleibt nach R18 bestehen — Root-Cause-Sonde statt weiterer Fix-Vermutung (außerhalb des ursprünglichen Taskplans)

**Kontext**: Nach dem T050-Reset weiterhin `NO RESPONSE after 3409ms (connection error: unknown)` bei `POST /login`, obwohl `www.hans-dither.de` im Browser sofort erreichbar ist. Statt einer weiteren ungeprüften Fix-Vermutung wurde systematisch Root-Cause-Analyse betrieben (research.md R19).

- [X] T051 [US1] DNS (kein AAAA-Record → IPv6-Hänger ausgeschlossen), SNI/Virtual-Hosting (Server liefert mit korrektem SNI die valide `hans-dither.de`-Kette) und rohe TCP-Erreichbarkeit (Python-Socket verbindet in 0,05s) einzeln geprüft und als Ursache ausgeschlossen. `otool`/`strings` auf das Simulator-Binary zeigten den entscheidenden Unterschied: der Simulator bringt sein eigenes statisch gelinktes `libcurl 8.20.0`+`OpenSSL` mit, komplett unabhängig vom Shell-`curl` und vom System-Trust-Store — ein Prozess- oder TLS-Stack-spezifischer Unterschied bleibt die einzig evidenzbasierte Erklärung (Hypothese, nicht bewiesen). `Source/SyncService.lua`: `httpPostAndWait` zu `httpAndWait(host, path, headers, body, phaseLabel, method)` verallgemeinert (Host/Methode als Parameter statt fest verdrahtet auf `BACKEND_HOST`/POST); neuer sechster Dev-Testtrigger `SyncService:devTestNetworkProbe()` (Taste `5`) fährt denselben Verbindungscode gegen `example.com` — das Ergebnis dieser einen Taste entscheidet beweisbar zwischen "Simulator erreicht generell kein HTTPS" (Problem liegt am Netzwerkpfad/Prozessfilterung, nicht am Backend) und "nur unser Host betroffen" (weitere Untersuchung dort nötig). Beide Constitution-Gates (`lua tests/headless_tests.lua`, `pdc Source "Hans Dither.pdx"`) grün.

- [X] T052 [US1] Live-Socket-Aufzeichnung (`lsof -i -p <simulator-pid>` alle 0,25-0,3s während eines echten Tastendruck-Tests) deckte den bisher wahrscheinlichsten Root Cause auf: der Simulator-Prozess verband sich mindestens einmal auf Port 80 (Klartext) statt 443, obwohl `usessl=true` gesetzt ist — das offizielle SDK-Beispiel übergibt immer einen expliziten Port, nie `nil`+`usessl=true` (research.md R20). `Source/SyncService.lua`: `playdate.network.http.new(host, nil, true, ...)` → `playdate.network.http.new(host, 443, true, ...)`, eine gezielte Zeile statt eines größeren Umbaus. Beide Constitution-Gates grün. Noch nicht final durch einen erneuten Simulator-Testlauf verifiziert.
- [X] T053 [US1] Der R20-Portfix griff — Roundtrip verband und bekam `POST /login -> 200` zurück, stürzte danach aber sofort ab (`SyncService.lua:370: attempt to index a nil value (field 'json')`) und das Ergebnis-Overlay blieb aus. Root Cause (research.md R21): `playdate.json` existiert nicht — der echte SDK-Name ist der globale `json` (`json.decode`/`json.encode`, kein `playdate.*`-Feld, kein CoreLibs-Import, verifiziert gegen `Examples/Level 1-1/Source/levelLoader.lua`). Ein erster Versuch, stattdessen `import "CoreLibs/json"` zu ergänzen, scheiterte sofort am `pdc`-Build ("No such file") und wurde verworfen. `Source/SyncService.lua`: `playdate.json.decode` → `json.decode`. `tests/headless_tests.lua`: Mock von `playdate.json` auf globales `json` korrigiert (derselbe falsche Name war auch im Mock erfunden worden, weshalb kein Test dies auffing — dieselbe Fehlerklasse wie der dokumentierte `generateQRCodeSync`-Bug). Erklärt zugleich das gemeldete "UI aktualisiert nicht": `resultModalActive` wird erst nach erfolgreichem Kettendurchlauf gesetzt, ein Coroutine-Absturz verhindert das — kein separater UI-Bug. Beide Constitution-Gates grün. Noch nicht final durch einen erneuten Simulator-Testlauf verifiziert.
- [X] T054 [US1] Nach dem R21-Fix scheiterte der Roundtrip beim Upload selbst (`local_read_error (pdi=false json=true)`). Root Cause (research.md R22): `SyncService:attemptUpload` suchte `saves/<id>/sheet.pdi`, die reale Datei heißt aber `saves/<id>/sheet` (keine Endung) — `playdate.datastore.writeImage()` hängt anders als `datastore.write()` keine Endung automatisch an (SDK-Doku verifiziert). `ImageStoreCodec.lua` schrieb/las bereits korrekt ohne Endung; nur `SyncService.lua`s Lesepfad war falsch. Test-Mock (`tests/headless_tests.lua`) hatte denselben falschen Namen erfunden, daher unsichtbar für die Suite — korrigiert. Beide Constitution-Gates grün.
- [X] T055 [US1] [US2] Nutzer-Feedback: Fortschrittsbalken im Sync-/Save-Overlay füllte sich nie sichtbar. Root Cause (research.md R23): kein einziger Aufrufer (SyncService, EditorRoom, RoomOperation) übergibt je einen echten Fortschrittsanteil, nur Phasen-Text — der Balken war in der gesamten Codebasis nie funktional befüllt. SDK hat kein natives Spinner-Widget (verifiziert). `Source/loadingBar.lua` umgebaut: Fortschrittsbalken-Logik entfernt, ersetzt durch einen Text-Spinner (`| / - \`, zeitgesteuert), betrifft Save/Load UND Sync gemeinsam (eine Komponente, ein Fix). Beide Constitution-Gates grün.

---

## Notes

- [P] Tasks = unterschiedliche Dateien, keine Abhängigkeiten
- [Story]-Label ordnet jede Task einer User Story zu (Traceability)
- Jede Story ist unabhängig abschließbar und testbar, außer US2 setzt eine funktionierende US1-Verknüpfung voraus (inhärente Abhängigkeit, kein Design-Fehler)
- Nach jeder Task (bzw. logischer Gruppe) committen
- An jedem Checkpoint anhalten und die Story unabhängig validieren
