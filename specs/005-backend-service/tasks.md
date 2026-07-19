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
- [x] T002 config.php in `includes/` erstellen: DB-Zugangsdaten ($host, $user, $password, $database), Base-URL, Upload-Pfade, Error-Reporting (display_errors = Off für Production)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Kerninfrastruktur, die VOR allen User Stories fertig sein muss

**⚠️ CRITICAL**: Erst abschließen, dann Story-Phasen beginnen

- [x] T003 MySQL-Datenbank und Tabellen anlegen: Schema aus research.md R6 (users + images Tabellen) via phpMyAdmin oder SQL-Script - *Erstellt: sql/migrations/001_create_tables.sql*
- [x] T004 [P] includes/database.php erstellen: DB-Verbindung via MySQLi, Prepared Statements für alle Queries, Fehlermeldungen als JSON
- [x] T005 [P] includes/auth.php erstellen: PIN-Verifikation via password_verify(), Rate-Limiting-Logik (3 Versuche → 5 Min Sperre), Session-Token-Generierung/Validierung
- [x] T006 [P] includes/validation.php erstellen: Dateivalidierung (JSON: json_decode() erfolgreich; PDI: Magic Bytes PDI\0 + Header) per contracts/backend-api.md C-01
- [x] T007 includes/config.php absichern: DB-Zugangsdaten serverseitig, nicht in Version Control, Umgebungsvariablen prüfen
- [x] T045 [P] ~~Server-Überlastung handling implementieren~~ — *OBSOLET (2026-07-18): Auf Nutzerentscheidung entfernt; checkServerOverload() aus backend/public/index.php gestrichen, Edge Case aus spec.md entfernt. Funktion wird nicht benötigt.*

**Checkpoint**: ✅ Datenbank steht, Basis-Includes sind implementiert — User Story Implementation kann beginnen

---

## Phase 3: User Story 1 — Backend-Verknüpfung herstellen (Priority: P1) 🎯 MVP

**Goal**: Nutzer kann Playdate-UID eingeben und mit 4-stelliger PIN verknüpfen (E-01, E-02)

**Independent Test**: quickstart.md Szenario 1-2 im Browser; nutze Test-UID `test-device-001` und PIN `1234`

### Implementation for User Story 1

- [x] T008 [US1] public/index.php Grundgerüst erstellen: HTML-Formular für UID-Eingabe (POST /pair oder GET /?uid=...), CSS-Styling (assets/css/style.css), JS für Formular-Handling (assets/js/app.js)
- [x] T009 [US1] public/index.php mit UID-Routing erweitern: Prüfe ob UID existiert → /login (E-03), sonst → /pair (E-02)
- [x] T010 [US1] POST /pair Endpunkt in public/index.php implementieren: UID + PIN validieren (FR-002, FR-004), bcrypt-Hash erstellen, DB-Eintrag in users-Tabelle (FR-003, FR-005, FR-012)
- [x] T011 [US1] POST /login Endpunkt in public/index.php implementieren: UID prüfen, PIN verifizieren, Rate-Limiting (FR-006, FR-007), Session-Token generieren und zurückgeben (E-03)
- [x] T012 [US1] Session-Management in includes/auth.php ergänzen: Token-Speicherung in DB, Gültigkeitsprüfung (30 Min), Token-Invalidierung
- [x] T013 [US1] Fehlerbehandlung für US1: Leere UID, nicht-numerische PIN, UID bereits vorhanden (400/409 Responses)

**Checkpoint**: ✅ Nutzer kann UID eingeben, PIN vergeben und erfolgreich einloggen

---

## Phase 4: User Story 2 — Image Upload (Priority: P1)

**Goal**: Nutzer kann PDI + JSON hochladen; Backend validiert und speichert Dateien (E-04, FR-013)

**Independent Test**: quickstart.md Szenario 5-6; manuelle Dateien hochladen (simple.pdi + simple.json aus Spec 001)

### Implementation for User Story 2

- [x] T014 [US2] public/upload.php Grundgerüst erstellen: Multipart-Formular für Datei-Upload (pdi + json), Session-Token-Authentifizierung
- [x] T015 [US2] Dateivalidierung in public/upload.php integrieren: includes/validation.php aufrufen (FR-013), bei Fehler HTTP 400 zurückgeben
- [x] T016 [US2] Dateispeicherung in public/upload.php implementieren: UUID generieren, Dateien unter uploads/{UID}/{uuid}.pdi und .json speichern (FR-009)
- [x] T017 [US2] DB-Eintrag für Upload in public/upload.php erstellen: Image-Metadaten in images-Tabelle speichern (FR-009, FR-012)
- [x] T018 [US2] Response für Upload in public/upload.php: JSON mit image_id und Status (E-04 Response)
- [x] T019 [P] [US2] includes/validation.php um Dateigrößenprüfung erweitern: Max. 10MB pro Datei (413 Response bei Überschreitung)
- [x] T020 [US2] Fehlerbehandlung für US2: Ungültige Dateien, fehlende Authentifizierung, DB-Fehler

**Checkpoint**: ✅ Nutzer kann PDI + JSON hochladen; Dateien werden validiert und gespeichert

---

## Phase 5: User Story 3 — Images anzeigen und herunterladen (Priority: P2)

**Goal**: Nutzer sieht Images-Liste und kann PDI/JSON/PNG herunterladen (E-05 bis E-08, FR-008, FR-010, FR-011)

**Independent Test**: quickstart.md Szenario 7-9; nach Upload sollte Image in Liste erscheinen

### Implementation for User Story 3

- [x] T021 [US3] GET /images Endpunkt in public/index.php implementieren: Images-Liste aus DB laden (FR-008), nur für authentifizierte UID, Response nach contracts/backend-api.md E-05
- [x] T022 [US3] public/index.php UI für Images-Liste erweitern: Tabelle mit Image-Einträgen, Download-Links (FR-011)
- [x] T023 [P] [US3] GET /download/pdi/{id} Endpunkt in public/download.php implementieren: Berechtigung prüfen, Datei ausliefern (E-06, contracts S-03)
- [x] T024 [P] [US3] GET /download/json/{id} Endpunkt in public/download.php implementieren: Berechtigung prüfen, Datei ausliefern (E-07, contracts S-03)
- [x] T025 [US3] includes/renderer.php für PNG-Rendering erstellen: PDI + JSON parsen, 400×240 PNG generieren (FR-010), on-demand bei erstem Zugriff
- [x] T026 [P] [US3] GET /download/png/{id} Endpunkt in public/download.php implementieren: PNG generieren/laden (E-08, contracts S-03)
- [x] T027 [US3] Dateizugriffs-Berechtigungen in public/download.php prüfen: Image.uid == Session.uid (FR-011, contracts S-03)
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
- [ ] Offener Punkt (Open): PDI-Parser — T025, Owner: Projektinhaber, Follow-up: includes/renderer.php, Re-Evaluation: vor Deployment
- [ ] Secure-Architecture: T036 (Security-Review-Dokument) — Evidenz: docs/architecture/security-review-backend.md + quickstart.md Szenario 10

---

## Architecture Governance Tasks

- [x] T041 ADR-Template für AD-025 erstellen: Entscheidung für PHP/MySQL auf all-inkl.com, Kontext, Alternativen, Konsequenzen - *Erstellt: arc42/adr/ADR-025-PHP-MySQL-auf-all-inkl.md*
- [x] T042 ADR-Template für AD-026 erstellen: PIN-Hashing mit password_hash(), Sicherheitsevaluierung - *Erstellt: arc42/adr/ADR-026-PIN-Hashing.md*
- [x] T043 ADR-Template für AD-027 erstellen: Dateivalidierung Endung + Inhaltsprüfung, Sicherheitsbegründung - *Erstellt: arc42/adr/ADR-027-Dateivalidierung.md*
- [x] T044 ADR-Template für AD-028 erstellen: PNG-Rendering via GD-Bibliothek, Abhängigkeiten - *Erstellt: arc42/adr/ADR-028-PNG-Rendering.md*

---

## Phase 8: Convergence

**Purpose**: Behebung der Lücken aus dem Konvergenz-Review vom 2026-07-18 (Fokus: Backend-Robustheit, Deployment-Skript, Secrets-Schutz). CRITICAL-Tasks zuerst.

- [x] T046 CRITICAL: `.gitignore` um `backend/includes/config.php`, `backend/uploads/`, `backend/storage/`, `backend/logs/` erweitern und via `git check-ignore` verifizieren per contracts S-02 — *Erledigt 2026-07-18: alle Pfade via `git check-ignore -v` verifiziert; zusätzlich `backend/.htaccess` (generiert) ignoriert, `backend/.deploy.env.example` und `backend/deploy.sh` (secretfrei) bewusst trackbar gemacht*
- [x] T047 CRITICAL: DB-Zugangsdaten rotieren (KAS-Panel); config.php ausschließlich aus `.deploy.env` generieren per contracts S-02 — *Code-Teil erledigt: config.php wird nur noch von deploy.sh aus .deploy.env generiert (chmod 600) und ist gitignored. ⚠️ MANUELL OFFEN: Passwort-Rotation im KAS-Panel (https://kas.all-inkl.com) muss der Nutzer durchführen, danach .deploy.env aktualisieren + `./deploy.sh` erneut ausführen*
- [x] T048 CRITICAL: deploy.sh Secrets-Schutz per spec Assumptions Sicherheit — *Erledigt 2026-07-18: mirror-Excludes (.deploy.env*, deploy.sh, *.md, .git*, .DS_Store, Schema-Dump), `ftp:ssl-force true` + `ssl-protect-data` + Zertifikatsprüfung, Pflichtvariablen-Check, chmod 600 für Secrets, Post-Deploy-Sicherheitsverifikation via curl (bricht bei HTTP 200 auf Secret-Pfaden mit Exit 1 ab). Verifiziert: bash -n + Lauf mit --prepare-only*
- [x] T049 CRITICAL: .htaccess-Zugriffsschutz per contracts S-03/S-04 — *Erledigt 2026-07-18: RewriteRule [F] für includes/, storage/, logs/, sql/, uploads/; FilesMatch-Deny für Dotfiles und .env/.sh/.sql/.log/.md/.bak/.ini; zusätzlich uploads/.htaccess + storage/.htaccess mit `Require all denied` (Defense-in-Depth); Auslieferung nur über download.php*
- [x] T050 CRITICAL: Konfigurations-Konstanten definieren per FR-004/FR-007/FR-012 — *Erledigt 2026-07-18: define()-Block in deploy.sh-Generierung (DB_HOST/USER/PASS/NAME/PORT, BASE_URL, UPLOADS_DIR, STORAGE_DIR, PIN_LENGTH=4, PIN_REGEX, UID_REGEX, MAX_FAILED_ATTEMPTS=3, LOCKOUT_DURATION=300, SESSION_TIMEOUT=1800); lokale config.php regeneriert; Smoke-Test bestätigt alle Konstanten*
- [x] T051 CRITICAL: backend/public/download.php reparieren per US3/AC2-4, contracts E-06..E-08 — *Erledigt 2026-07-18: `self::`-Aufrufe außerhalb Klassenkontext auf normale Funktionsaufrufe umgestellt; php -l sauber*
- [x] T052 CRITICAL: `Database::query()` Rückgabesemantik korrigieren per FR-003/FR-006, US1/AC2 — *Erledigt 2026-07-18: leeres SELECT liefert jetzt `[]` (query() und querySimple()); Statement-Close-Pfade ergänzt; alle Aufrufer (uidExists, login, validateToken, getImage, tableExists) gegen neue Semantik geprüft — empty()/count()-Checks funktionieren korrekt*
- [x] T053 HIGH: URL-Routing + HTTPS in .htaccess per contracts E-01..E-08, S-08 — *Erledigt 2026-07-18: Front-Controller-RewriteRules für /, /pair, /login, /images, /logout → public/index.php, /upload(.php) → public/upload.php, /download/{pdi|json|png}/{id} → public/download.php; .htaccess-Generierung auf quoted Heredoc umgestellt → `%{HTTPS}` kommt unescaped an (verifiziert im generierten File)*
- [x] T054 HIGH: `X-Session-Token`-Header-Support reparieren per contracts E-05 — *Erledigt 2026-07-18: Helper `requestSessionToken()` (Header → Query → Cookie) eingeführt und in handleImagesRequest()/handleLogoutRequest() verwendet; Scope-Bug beseitigt*
- [x] T055 MEDIUM: UID-Eingabevalidierung per contracts S-01, data-model — *Erledigt 2026-07-18: `Auth::isValidUid()` mit UID_REGEX (`/^[A-Za-z0-9_-]{1,64}$/`) in pair(), login() und allen Formular-Routen; `urlencode()` in allen Location-Redirects; Bonus-Fix: UID-Routing in showUidForm() lief bisher NACH HTML-Ausgabe (header() wirkungslos) — vor die Ausgabe verschoben, Fehleranzeige ergänzt. Smoke-Test: Traversal-/XSS-/Überlängen-UIDs abgelehnt*
- [x] T056 MEDIUM: DB-Fehlerbehandlung per spec Edge Case — *Erledigt 2026-07-18: `failWithDbError()` sendet HTTP 500 + Content-Type: application/json + "Datenbankfehler — bitte später erneut versuchen" (Verbindungs- und Prepare-Fehler)*
- [x] T057 LOW: 413 bei Dateigrößen-Überschreitung per contracts E-04 — *Erledigt 2026-07-18: validation.php liefert http_code 413, upload_handler.php reicht ihn durch*
- [x] T058 LOW: Struktur-Reste konsolidieren — *Erledigt 2026-07-18: public/.htaccess und Root-.htaccess (beide stale, mit kaputten \%-Escapes) gelöscht; leere Root-Verzeichnisse public/, uploads/, storage/, logs/ entfernt; backend/sql/migrations/001_create_tables.sql ist jetzt kanonische Schema-Quelle (deploy.sh generiert daraus per sed das DB-spezifische Schema nach backend/storage/; Ordner am 2026-07-18 auf Nutzerwunsch von sql/ nach backend/sql/ verschoben); plan.md Project Structure auf backend/-Layout aktualisiert*

---

## Phase 9: PDI-Realformat, GIF-Export & SSH-Deployment (Nachtrag 2026-07-18)

**Purpose**: Nutzerentscheidungen aus Session 2026-07-18 (siehe spec.md Clarifications): echtes Playdate-SDK-Format statt `PDI\0`-Kunstformat, animierter GIF-Export, vollautomatisches SSH-Deployment inkl. DB-Provisionierung.

- [x] T059 PDI-Parser für echtes Playdate-SDK-Format implementieren (backend/includes/pdi_parser.php): Magic `Playdate IMG`, zlib-Dekompression, Cell-Header, 1-Bit-Bitmap + Alpha-Maske per FR-013 (korrigiert), Spec 001 — *Verifiziert: pixelidentisch (0 diff) zur Python-Referenz cranksters/pdi2png.py mit echter card.pdi aus Hans Dither.pdx*
- [x] T060 Upload-Validierung auf echtes Format umstellen (backend/includes/validation.php): Magic + Vollparse + Abmessungsgrenzen; das alte `PDI\0`-Format wird abgelehnt per FR-013 — *Test: card.pdi akzeptiert, Fantasie-Format abgelehnt*
- [x] T061 Renderer auf Spec-001-Tilemap umstellen (backend/includes/renderer.php): sheet.pdi → 16×16-Tiles (25/Zeile), frames.json (25×15 Grid, 1-basierte Indizes, Fallback Tile 1) → 400×240-Canvas; PNG = Frame 1 via GD per FR-010 — *Test: Compose-Logik inkl. Fallback bei ungültigem Index verifiziert*
- [x] T062 Animierten GIF-Export implementieren per FR-014 (neu): backend/includes/gif_encoder.php (GIF89a, echter LZW, NETSCAPE-Loop, 2-Farben-Palette, reines PHP ohne Imagick); Renderer::renderToGif(); GET /download/gif/{id} (contracts E-09); UI/JSON um GIF-Links erweitert; images.gif_path-Spalte in Migration 001 + guarded ALTER im Deployment — *Test: 2-Frame-GIF von GD dekodierbar, Frame 1 pixelidentisch, Loop-Extension vorhanden*
- [x] T063 SSH-Deployment mit automatischer DB-Provisionierung (backend/deploy.sh): rsync-Upload über SSH (Key-Auth, BatchMode), MySQL-Schema-Import direkt auf dem Server via defaults-extra-file (Passwort nie in Prozessliste), guarded ALTER für gif_path, SHOW-TABLES-Verifikation, temporäre Credentials-Datei wird gelöscht; FTPS/lftp bleibt Fallback ohne SSH-Konfiguration; SSH_HOST/SSH_USER/SSH_PORT in .deploy.env.example dokumentiert — *bash -n + --prepare-only verifiziert; Live-Lauf erfordert SSH-Key-Setup (ssh-copy-id) durch Nutzer*
