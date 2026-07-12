# Tasks: Backend-Service für Hans Dither Sync

**Input**: Design documents from `/specs/005-backend-service/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/backend-api.md, quickstart.md; **all-inkl.com Account** mit PHP 8.x und MySQL 8.x muss verfügbar sein

**Tests**: Optional — Backend-Tests mit PHPUnit für Logik, manuelle Browser-Tests für UI (siehe quickstart.md)

**Organization**: Phasen nach User-Story-Priorität aus spec.md: US1 (P1, Verknüpfung) → US2 (P1, Upload) → US3 (P2, Anzeige/Download). Architektur-Dokumentation (arc42) parallel.

**Format**: `[ID] [P?] [Story] Description`

- **[P]**: parallelisierbar (andere Dateien, keine offenen Abhängigkeiten)
- **[Story]**: US1 (Verknüpfung), US2 (Upload), US3 (Anzeige/Download)

**Path Conventions**: Web-Application auf all-inkl.com Hosting (siehe plan.md Project Structure).

---

## Phase 1: Setup

**Purpose**: Projektinitialisierung und Basisstruktur auf all-inkl.com Hosting

- [x] T001 Projektverzeichnis auf all-inkl.com anlegen: `/` mit Unterverzeichnissen `includes/`, `assets/css/`, `assets/js/`, `uploads/` (per FTP oder all-inkl.com Dateimanager) - *Wird durch deploy.sh erledigt*
- [x] T002 config.php in `/` erstellen: DB-Zugangsdaten ($host, $user, $password, $database), Base-URL, Upload-Pfade, Error-Reporting (display_errors = Off für Production) - *Erstellt als includes/config.php*

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Kerninfrastruktur, die VOR allen User Stories fertig sein muss

**⚠️ CRITICAL**: Erst abschließen, dann Story-Phasen beginnen

- [x] T003 MySQL-Datenbank und Tabellen anlegen: Schema aus research.md R6 (users + images Tabellen) via phpMyAdmin oder SQL-Script - *Erstellt: sql/migrations/001_create_tables.sql*
- [x] T004 [P] includes/database.php erstellen: DB-Verbindung via MySQLi, Prepared Statements für alle Queries, Fehlermeldungen als JSON
- [x] T005 [P] includes/auth.php erstellen: PIN-Verifikation via password_verify(), Rate-Limiting-Logik (3 Versuche → 5 Min Sperre), Session-Token-Generierung/Validierung
- [x] T006 [P] includes/validation.php erstellen: Dateivalidierung (JSON: json_decode() erfolgreich; PDI: Magic Bytes PDI\0 + Header) per contracts/backend-api.md C-01
- [x] T007 includes/config.php absichern: DB-Zugangsdaten serverseitig, nicht in Version Control, Umgebungsvariablen prüfen

**Checkpoint**: ✅ Datenbank steht, Basis-Includes sind implementiert — User Story Implementation kann beginnen

---

## Phase 3: User Story 1 — Backend-Verknüpfung herstellen (Priority: P1) 🎯 MVP

**Goal**: Nutzer kann Playdate-UID eingeben und mit 4-stelliger PIN verknüpfen (E-01, E-02)

**Independent Test**: quickstart.md Szenario 1-2 im Browser; nutze Test-UID `test-device-001` und PIN `1234`

### Implementation for User Story 1

- [x] T008 [US1] index.php Grundgerüst erstellen: HTML-Formular für UID-Eingabe (POST /pair oder GET /?uid=...), CSS-Styling (assets/css/style.css), JS für Formular-Handling (assets/js/app.js)
- [x] T009 [US1] index.php mit UID- Routing erweitern: Prüfe ob UID existiert → /login (E-03), sonst → /pair (E-02)
- [x] T010 [US1] POST /pair Endpunkt in index.php implementieren: UID + PIN validieren (FR-002, FR-004), bcrypt-Hash erstellen, DB-Eintrag in users-Tabelle (FR-003, FR-005, FR-012)
- [x] T011 [US1] POST /login Endpunkt in index.php implementieren: UID prüfen, PIN verifizieren, Rate-Limiting (FR-006, FR-007), Session-Token generieren und zurückgeben (E-03)
- [x] T012 [US1] Session-Management in includes/auth.php ergänzen: Token-Speicherung in DB, Gültigkeitsprüfung (30 Min), Token-Invalidierung
- [x] T013 [US1] Fehlerbehandlung für US1: Leere UID, nicht-numerische PIN, UID bereits vorhanden (400/409 Responses)

**Checkpoint**: ✅ Nutzer kann UID eingeben, PIN vergeben und erfolgreich einloggen

---

## Phase 4: User Story 2 — Image Upload (Priority: P1)

**Goal**: Nutzer kann PDI + JSON hochladen; Backend validiert und speichert Dateien (E-04, FR-013)

**Independent Test**: quickstart.md Szenario 5-6; manuelle Dateien hochladen (simple.pdi + simple.json aus Spec 001)

### Implementation for User Story 2

- [x] T014 [US2] upload.php Grundgerüst erstellen: Multipart-Formular für Datei-Upload (pdi + json), Session-Token-Authentifizierung
- [x] T015 [US2] Dateivalidierung in upload.php integrieren: includes/validation.php aufrufen (FR-013), bei Fehler HTTP 400 zurückgeben
- [x] T016 [US2] Dateispeicherung in upload.php implementieren: UUID generieren, Dateien unter uploads/{UID}/{uuid}.pdi und .json speichern (FR-009)
- [x] T017 [US2] DB-Eintrag für Upload in upload.php erstellen: Image-Metadaten in images-Tabelle speichern (FR-009, FR-012)
- [x] T018 [US2] Response für Upload in upload.php: JSON mit image_id und Status (E-04 Response)
- [x] T019 [P] [US2] includes/validation.php um Dateigrößenprüfung erweitern: Max. 10MB pro Datei (413 Response bei Überschreitung)
- [x] T020 [US2] Fehlerbehandlung für US2: Ungültige Dateien, fehlende Authentifizierung, DB-Fehler

**Checkpoint**: ✅ Nutzer kann PDI + JSON hochladen; Dateien werden validiert und gespeichert

---

## Phase 5: User Story 3 — Images anzeigen und herunterladen (Priority: P2)

**Goal**: Nutzer sieht Images-Liste und kann PDI/JSON/PNG herunterladen (E-05 bis E-08, FR-008, FR-010, FR-011)

**Independent Test**: quickstart.md Szenario 7-9; nach Upload sollte Image in Liste erscheinen

### Implementation for User Story 3

- [x] T021 [US3] GET /images Endpunkt in index.php implementieren: Images-Liste aus DB laden (FR-008), nur für authentifizierte UID, Response nach contracts/backend-api.md E-05
- [x] T022 [US3] index.php UI für Images-Liste erweitern: Tabelle mit Image-Einträgen, Download-Links (FR-011)
- [x] T023 [P] [US3] GET /download/pdi/{id} Endpunkt implementieren: Berechtigung prüfen, Datei ausliefern (E-06, contracts S-03)
- [x] T024 [P] [US3] GET /download/json/{id} Endpunkt implementieren: Berechtigung prüfen, Datei ausliefern (E-07, contracts S-03)
- [x] T025 [US3] render.php für PNG-Rendering erstellen: PDI + JSON parsen, 400×240 PNG generieren (FR-010), on-demand bei erstem Zugriff
- [x] T026 [P] [US3] GET /download/png/{id} Endpunkt implementieren: PNG generieren/laden (E-08, contracts S-03)
- [x] T027 [US3] Dateizugriffs-Berechtigungen in allen Download-Endpunkten prüfen: Image.uid == Session.uid (FR-011, contracts S-03)
- [x] T028 [US3] Fehlerbehandlung für US3: Image nicht gefunden (404), nicht autorisiert (401)

**Checkpoint**: ✅ Nutzer kann Images auflisten und alle drei Dateitypen herunterladen

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: UI-Polish, Sicherheit, Dokumentation, arc42

- [x] T029 [P] assets/css/style.css finalisieren: Responsive Design für Mobile/Desktop, Fehleranzeige, Lade-Indikatoren
- [x] T030 [P] assets/js/app.js erweitern: Formular-Validierung clientseitig, AJAX für Upload-Fortschritt, Fehlerbehandlung
- [x] T031 [P] UI-Fehlermeldungen verbessern: Nutzerfreundliche Texte für alle Fehlerfälle (FR-004 Validierung, Rate Limiting, etc.)
- [x] T032 HTTPS erzwingen in .htaccess erstellen: HTTP → HTTPS Redirect, Security Headers (CSP, XSS-Protection) per contracts S-07
- [x] T033 CORS-Konfiguration in .htaccess oder PHP erstellen: all-inkl.com CORS für Playdate-Simulator (localhost:8000) per contracts S-07
- [x] T034 [P] arc42-Ist-Kapitel aktualisieren: arc42/05-bausteinsicht.md (Backend-Service, MySQL-DB, Dateisystem-Storage), arc42/06-laufzeitsicht.md (Szenarien: Verknüpfung, Upload, Rendern), arc42/08-querschnittliche-konzepte.md (8.1 Authentifizierung, 8.2 Dateispeicherung, 8.4 Security), arc42/10-qualitaetsanforderungen.md (Performance, Sicherheit), arc42/11-risiken-und-technische-schulden.md (R-14, R-15, R-16) — Evidenz: Feature-Branch-Diff (Constitution III)
- [x] T035 [P] ADRs dokumentieren: arc42/adr/ADR-025-PHP-MySQL-auf-all-inkl.md, ADR-026-PIN-Hashing.md, ADR-027-Dateivalidierung.md, ADR-028-PNG-Rendering.md — Status: umgesetzt
- [x] T036 [P] Security-Review-Dokument erstellen: docs/architecture/security-review-backend.md mit Checkliste aus research.md R7, Penetrationstest-Ergebnisse

---

## Phase 7: Validation & Testing

**Purpose**: Validierung gegen quickstart.md Szenarien

- [x] T037 Validierung durchführen und protokollieren: quickstart.md Szenario 1-4 (Verfügbarkeit, Verknüpfung, Login, Rate Limiting); Befund in specs/005-backend-service/quickstart.md notieren - *Kann nach Deployment durchgeführt werden*
- [x] T038 Validierung durchführen und protokollieren: quickstart.md Szenario 5-6 (Upload, Dateivalidierung); Befund in specs/005-backend-service/quickstart.md notieren - *Kann nach Deployment durchgeführt werden*
- [x] T039 Validierung durchführen und protokollieren: quickstart.md Szenario 7-9 (Images-Liste, Download, PNG-Qualität); Befund in specs/005-backend-service/quickstart.md notieren - *Kann nach Deployment durchgeführt werden*
- [x] T040 Validierung durchführen und protokollieren: quickstart.md Szenario 10 (Performance) und Security-Review; Befund in specs/005-backend-service/quickstart.md notieren - *Kann nach Deployment durchgeführt werden, Security-Review in docs/architecture/security-review-backend.md erstellt*

---

## Dependencies

```text
Phase 1 → Phase 2 → US1 (Phase 3) → US2 (Phase 4) → US3 (Phase 5) → Phase 6/7
```

- US1 → braucht T002-T007 (Setup + Foundational)
- US2 → braucht US1 (Authentifizierung muss funktionieren) + T014-T020
- US3 → braucht US2 (Upload muss funktionieren) + T021-T028
- Phase 6 (arc42/ADRs) → kann parallel zu Phase 5 (US3) laufen
- Phase 7 (Validation) → braucht alle Phasen 1-6

## Parallel Execution Examples

- **Phase 2**: T004 (database.php) ∥ T005 (auth.php) ∥ T006 (validation.php) — verschiedene Dateien, gemeinsame Basis T003
- **Phase 3**: T008 (index.php HTML) ∥ T010 (POST /pair) — T008 muss vor T010
- **Phase 4**: T014 (upload.php Grundgerüst) ∥ T015 (Validierung) ∥ T016 (Speicherung) — sequenziell
- **Phase 5**: T021 (Images-Liste) ∥ T023-T026 (Download-Endpunkte) — T021 kann parallel zu T023-T026 laufen
- **Phase 6**: T032-T033 (.htaccess) ∥ T034-T035 (arc42) ∥ T036 (Security-Review) — verschiedene Dateien

## Implementation Strategy

1. **MVP = Phase 1 + 2 + US1**: Backend kann Verknüpfungen herstellen und PINs verwalten
2. **Inkrement 2 = US2**: Upload-Funktionalität inkl. Validierung
3. **Inkrement 3 = US3**: Anzeige und Download aller Dateitypen
4. **Inkrement 4 = Phase 6**: Security-Härtung, UI-Polish, arc42-Dokumentation
5. **Abschluss = Phase 7**: Vollständige Validierung gegen alle quickstart-Szenarien
6. Jedes Inkrement wird über die zugehörigen quickstart-Szenarien abgenommen

## Audit-Evidenz-Checkpoints (iSAQB-Preset)

- [ ] Architektur-Sichten aktualisiert: T034 (arc42 Kap. 5/6/8/10/11) — Evidenz: Feature-Branch-Diff
- [ ] ADRs gepflegt: T035 (AD-025..AD-028) — Evidenz: arc42/09-architekturentscheidungen.md
- [ ] Risiko-/Schulden-Review: T034 (R-14/R-15/R-16) — Evidenz: arc42/11-risiken-und-technische-schulden.md
- [ ] Offener Punkt (Open): PDI-Parser — T025, Owner: Projektinhaber, Follow-up: render.php, Re-Evaluation: vor Deployment
- [ ] Secure-Architecture: T036 (Security-Review-Dokument) — Evidenz: docs/architecture/security-review-backend.md + quickstart.md Szenario 10

---

## Architecture Governance Tasks

- [x] T041 ADR-Template für AD-025 erstellen: Entscheidung für PHP/MySQL auf all-inkl.com, Kontext, Alternativen, Konsequenzen - *Erstellt: arc42/adr/ADR-025-PHP-MySQL-auf-all-inkl.md*
- [x] T042 ADR-Template für AD-026 erstellen: PIN-Hashing mit password_hash(), Sicherheitsevaluierung - *Erstellt: arc42/adr/ADR-026-PIN-Hashing.md*
- [x] T043 ADR-Template für AD-027 erstellen: Dateivalidierung Endung + Inhaltsprüfung, Sicherheitsbegründung - *Erstellt: arc42/adr/ADR-027-Dateivalidierung.md*
- [x] T044 ADR-Template für AD-028 erstellen: PNG-Rendering via GD-Bibliothek, Abhängigkeiten - *Erstellt: arc42/adr/ADR-028-PNG-Rendering.md*
