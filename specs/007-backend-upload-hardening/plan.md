# Implementation Plan: Absicherung des Backends gegen unbegrenzte/missbräuchliche Uploads

**Branch**: `feature/0.3` | **Date**: 2026-07-19 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/007-backend-upload-hardening/spec.md`

## Summary

Vier Härtungsmaßnahmen für den bestehenden `/upload`-Endpunkt (Spec 005),
größtenteils serverseitig in `backend/includes/`, plus eine kleine, gezielte
Ergänzung in `Source/SyncService.lua` (research.md R6): ohne diese Ergänzung
würde die neue 403-Antwort auf dem Gerät als generisches "Upload failed"
statt als erkennbare Limit-Meldung erscheinen — FR-002/SC-005 verlangen
ausdrücklich eine für den Nutzer UNTERSCHEIDBARE Meldung, nicht nur eine
korrekte Backend-Ablehnung. (1) eine pro-UID-Obergrenze von
12 unterschiedlichen Bildern, race-condition-sicher über eine
Datenbank-Transaktion mit Row-Lock auf den bereits vorhandenen
`users`-Datensatz der UID (kein Schema-Wechsel, kein neuer Zähler-Slot,
research.md R1). (2) Eine gegenüber dem Status quo verschärfte
Dateigrößen-Grenze von 300 KB je Einzeldatei statt der aktuellen 10 MB
(research.md R2). (3) Die bereits vorhandene, vollständige
PDI-Format-Validierung (`PdiParser`: Magic-Bytes + vollständiges Parsing
inkl. zlib/Cell-Header/Alpha-Maske) wurde gegen FR-004/FR-005 geprüft und
erfüllt beide Anforderungen bereits — hier ist KEINE Neu-Implementierung
nötig, nur eine dokumentierte Verifikation (research.md R3). (4) Eine neue
Schema-Validierung für die JSON-Positionsdatei gegen die bereits in Spec
001 definierte Struktur (`version`, `name`, `gridWidth=25`,
`gridHeight=15`, `tileCount`, `frames[1..12]` à exakt 375 Tile-Indizes im
gültigen Bereich) — bisher wurde nur generische JSON-Gültigkeit geprüft,
keine Struktur (research.md R4).

## Technical Context

**Language/Version**: PHP (Backend, wie in Spec 005 etabliert — kein
Framework, reines PHP mit MySQLi), ergänzt um EINE kleine, gezielte
Lua-Änderung: `Source/SyncService.lua` muss den neuen `403`-Statuscode als
eigenen `reason` durchreichen, sonst kollabiert er clientseitig auf die
generische `else`-Fehlermeldung und FR-002/SC-005 ("eindeutige Meldung
beim Nutzer") wären trotz korrektem Backend-Verhalten nicht erfüllt
(research.md R6 — Lücke erst beim Nachverfolgen des Response-Pfads bis zum
UI-Aufruf gefunden, nicht beim reinen Backend-Review)

**Primary Dependencies**: Bestehende Backend-Bausteine aus Spec 005:
`Validation` (`backend/includes/validation.php`), `PdiParser`
(`backend/includes/pdi_parser.php`), `UploadHandler`
(`backend/includes/upload_handler.php`), `Database`
(`backend/includes/database.php`, MySQLi-Wrapper), `Auth`
(`backend/includes/auth.php`); keine neuen externen Bibliotheken (research.md
R4 — Schema-Prüfung als reine PHP-Funktion statt JSON-Schema-Library,
Constitution IV). Playdate-seitig: `Source/SyncService.lua` (bestehende
`attemptUpload()`/`startUpload()`-Statuscode-Zuordnung, research.md R6)

**Storage**: MySQL (bestehendes Schema aus `backend/sql/migrations/
001_create_tables.sql`/`002_sync_extensions.sql`) — `images`-Tabelle hat
bereits einen Index auf `uid` (`idx_uid`) und eine Unique-Constraint
`(uid, client_image_id)`; kein neues Feld/keine neue Migration nötig für
die Zähl-Logik (research.md R1)

**Testing**: Manuelle `curl`-basierte End-to-End-Szenarien nach
etabliertem Muster aus `backend/TESTING.md` (inkl. bereits vorhandenem
Negativ-Fixture-Muster `fake.pdi`) — kein PHPUnit/Test-Framework im
Projekt etabliert, Constitution V gilt ausschließlich für `Source/*.lua`
und ist hier N/A; quickstart.md erweitert TESTING.md um die neuen
Negativ-Szenarien dieser Spec

**Target Platform**: all-inkl.com Shared Hosting (PHP/MySQL), wie in Spec
005 etabliert

**Project Type**: Backend-Erweiterung (kein neues Projekt, kein neuer
Endpunkt — bestehender `/upload`-Endpunkt wird um Prüfungen ergänzt)

**Performance Goals**: Die zusätzliche `COUNT(*)`-Abfrage und der Row-Lock
laufen innerhalb derselben Transaktion wie der bestehende Upload-Schreib-
vorgang — kein zusätzlicher Roundtrip; Dateigrößen-Prüfung erfolgt vor
`move_uploaded_file()` (bereits bestehendes Muster, nur Schwellwert
geändert), kein Performance-Einfluss auf akzeptierte Uploads

**Constraints**: Constitution-Randbedingung "Netzwerk (Sync-Ausnahme)" —
diese Spec ändert nichts an der Optionalität/Netzwerk-Policy der
Playdate-Seite, reine Backend-Härtung; bestehende Sicherheitsmaßnahmen aus
Spec 005 (PIN-Hashing, Login-Rate-Limiting, HTTPS) bleiben unverändert

**Scale/Scope**: 3 geänderte Backend-Dateien (`validation.php`,
`upload_handler.php`, `database.php`) + 2 geänderte Dateien auf der
Playdate-Seite (`Source/SyncService.lua`, `tests/headless_tests.lua`,
research.md R6), 0 neue Dateien, 0 neue Datenbank-Migrationen; betrifft
ausschließlich den `/upload`-Endpunkt (E-04 aus
`specs/005-backend-service/contracts/backend-api.md`) und dessen
Fehler-Anzeige auf dem Gerät

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Prinzip | Prüfung | Status |
|---|---|---|
| I. SDK-First | Backend-Teil nicht anwendbar (läuft nicht auf dem Playdate SDK, identisch zur Begründung in Spec 005). Der kleine `SyncService.lua`-Teil (research.md R6) nutzt AUSSCHLIESSLICH bereits vorhandene SDK-Mechanismen weiter (bestehendes `httpPostAndWait`-Ergebnis, bestehendes `showStatus()`-Muster) — kein neuer SDK-Aufruf, keine neue API-Fläche. | PASS |
| II. Native Formate & PDI | Verschärft nur die bestehende Prüfung nativer PDI-/JSON-Dateien (Spec 001); keine neuen Formate, kein Format-Wechsel. Die bereits vorhandene vollständige PDI-Parser-Validierung wird weiterverwendet statt dupliziert (research.md R3). | PASS |
| III. arc42-Pflege | Umsetzungsschnitt aktualisiert `arc42/05-bausteinsicht.md` (Backend-Baustein: Validierungs-/Zähl-Erweiterung; SyncService: neuer `limit_reached`-Fehlerpfad), `arc42/06-laufzeitsicht.md` (neues Laufzeitszenario: Upload-Limit-Prüfung mit Row-Lock, End-zu-Ende bis zur Geräte-Anzeige), `docs/architecture/security-review-backend.md` (S-04 verifiziert, neue Einträge S-09..S-11) — als Tasks einzuplanen. | PASS (geplant) |
| IV. Einfachheit | Kein neues Datenbankfeld/keine neue Migration für den Zähl-Check (Wiederverwendung des bestehenden `users`-Datensatzes als Lock-Ziel statt eines neuen Zähler-Slots); Schema-Validierung als schlanke PHP-Funktion statt externer JSON-Schema-Bibliothek; PDI-Validierung wird NICHT dupliziert, da bereits vollständig vorhanden (research.md R3); Client-Fix ist eine einzelne neue `elseif`-Verzweigung je Funktion, kein neuer Abstraktionslayer (research.md R6). | PASS |
| V. Testpflicht | Gilt für den `SyncService.lua`-Teil dieser Spec (research.md R6) — bereits ausgeführt: `lua tests/headless_tests.lua` (neuer Testfall "Upload-Limit erreicht (403)...") endet mit "ALLE TESTS BESTANDEN", `pdc Source ...pdx` baut ohne Fehler. Für den reinen Backend-Teil N/A (Prinzip V gilt nur für `Source/*.lua`), Verifikation dort über `curl`-Szenarien in quickstart.md/TESTING.md. | PASS |

**Post-Design Re-Check (nach Phase 1)**: PASS — `data-model.md` und
`contracts/upload-hardening.md` führen keine neue Abstraktionsschicht ein;
die Transaktions-/Lock-Logik ist eine lokale Erweiterung von
`UploadHandler::handleUpload()`, keine neue Schicht. Die
`SyncService.lua`-Änderung (research.md R6) ist bereits umgesetzt und
gegen beide Constitution-V-Gates verifiziert. Complexity Tracking bleibt
leer.

## Project Structure

### Documentation (this feature)

```text
specs/007-backend-upload-hardening/
├── plan.md                        # Diese Datei
├── research.md                    # Phase 0: R1-R6, Ist-Zustand-Verifikation + Entscheidungen
├── data-model.md                  # Phase 1: Zähl-Logik, Schema-Definition für frames.json
├── quickstart.md                  # Phase 1: curl-Szenarien (Erweiterung von backend/TESTING.md)
├── contracts/
│   └── upload-hardening.md        # Phase 1: Amendment zu specs/005-backend-service/contracts/backend-api.md E-04
├── checklists/
│   └── requirements.md            # bereits vorhanden (aus /speckit-specify)
└── tasks.md                       # Phase 2 (/speckit-tasks — nicht Teil dieses Laufs)
```

### Source Code (repository root)

```text
backend/
├── includes/
│   ├── validation.php       # GEÄNDERT: maxFileSize 10MB -> 300KB; neue Methode
│   │                         #   validateFramesJsonSchema() (research.md R4)
│   ├── upload_handler.php   # GEÄNDERT: handleUpload() um Transaktion + Row-Lock +
│   │                         #   Zähl-Check vor Neuanlage erweitert (research.md R1);
│   │                         #   Update-in-place-Pfad (bekannte client_image_id)
│   │                         #   bleibt vom Zähl-Check unberührt (FR-003)
│   ├── database.php         # GEÄNDERT: neue schlanke Methoden beginTransaction()/
│   │                         #   commit()/rollback() (Pass-through auf mysqli), NUR
│   │                         #   für den Upload-Zähl-Check genutzt
│   ├── pdi_parser.php       # UNVERÄNDERT: bereits vollständige Validierung (research.md R3)
│   └── auth.php             # UNVERÄNDERT
└── TESTING.md                # GEÄNDERT: neue Negativ-Szenarien ergänzt (Referenz aus quickstart.md)

Source/
└── SyncService.lua          # GEÄNDERT: neuer 403-Statuscode-Zweig in
                              #   attemptUpload() (reason="limit_reached") + eigene
                              #   showStatus()-Meldung in startUpload() statt Kollaps
                              #   auf den generischen else-Zweig (research.md R6,
                              #   bereits umgesetzt + Constitution-V-Gates bestanden)

tests/
└── headless_tests.lua       # GEÄNDERT: neuer Testfall fuer den 403-Fehlerpfad
                              #   (research.md R6, bereits umgesetzt)
```

**Structure Decision**: Keine neuen Dateien, kein neuer Endpunkt — die
Backend-Maßnahmen sind Erweiterungen des bestehenden `/upload`-
Validierungs-/Speicherpfads aus Spec 005; die einzige Playdate-seitige
Änderung ist ein zusätzlicher Fehlerzweig in einer bereits bestehenden
Funktion (kein neuer Screen, kein neues Widget). `database.php` erhält
minimale Transaktions-Hilfsmethoden, weil `UploadHandler` für den
race-safe Zähl-Check erstmals eine explizite Transaktionsgrenze braucht
(bisher nutzt das Backend nur Einzel-Queries ohne Transaktionsklammer).

## Complexity Tracking

Keine Constitution-Verstöße — Tabelle entfällt.

## Architecture Governance (iSAQB-Preset)

- **Architektur-Arbeitsprodukte**: arc42 Kap. 5 (Bausteinsicht:
  `UploadHandler`/`Validation`/`Database`-Erweiterungen), Kap. 6
  (Laufzeitszenario: Upload mit Zähl-Check + Row-Lock), `docs/architecture/
  security-review-backend.md` (S-04 "PDI-Format-Validierung" von "geprüft"
  auf "verifiziert vollständig (Magic + strukturelles Parsing)" präzisiert;
  neue Einträge S-09 "Upload-Obergrenze pro Gerät", S-10 "Dateigröße 300 KB",
  S-11 "JSON-Schema-Validierung") — als Tasks in Phase 2 einzuplanen. Owner:
  Entwickler; Evidenz: Feature-Branch-Diff.
- **ADRs**:
  - **AD-033** (NEU): "Race-Condition-sicherer Upload-Zähl-Check via
    Transaktion + Row-Lock auf den bestehenden `users`-Datensatz statt
    eines neuen Zähler-Felds/Slot-Systems" — Hintergrund: `images`-Tabelle
    hat bereits einen `idx_uid`-Index; ein zusätzliches Zähler-Feld müsste
    bei jedem Upload/jeder Löschung synchron gehalten werden (Fehlerquelle),
    während `COUNT(*) WHERE uid = ?` innerhalb einer durch Row-Lock auf den
    UID-eigenen `users`-Datensatz serialisierten Transaktion sowohl korrekt
    als auch minimal-invasiv ist (kein Schema-Wechsel). Status: entschieden,
    zu dokumentieren in `arc42/adr/ADR-033-Upload-Limit-Row-Lock.md` vor
    Implementierungs-Abschluss.
  - **AD-034** (NEU): "JSON-Schema-Validierung als schlanke PHP-Funktion
    statt externer JSON-Schema-Bibliothek" — Hintergrund: Die Struktur ist
    fest und klein (6 Felder, eine Array-Dimension mit fester Länge 375);
    eine generische JSON-Schema-Bibliothek (z. B. `justinrainbow/json-
    schema`) wäre für dieses eine, stabile Format unverhältnismäßig
    (Constitution IV). Status: entschieden, zu dokumentieren in
    `arc42/adr/ADR-034-JSON-Schema-ohne-Library.md`.
- **Risiko-/Schulden-Review**: Neu zu beobachten — (1) Multi-Geräte-/
  Sybil-Umgehung des Pro-Gerät-Limits (aus spec.md Assumptions übernommen,
  bewusst nicht Teil des Scopes) — in `arc42/11-risiken-und-technische-
  schulden.md` als neues, bewusst akzeptiertes Risiko eintragen. (2) Die
  neue Transaktionsklammer in `UploadHandler::handleUpload()` verlängert
  die Zeit, in der der `users`-Datensatz der UID gesperrt ist, geringfügig
  um die Dauer des Datei-Schreibvorgangs (`move_uploaded_file()`) — bei
  MEHREREN GLEICHZEITIGEN Uploads DERSELBEN UID (untypischer Fall, ein
  Gerät lädt normalerweise sequenziell hoch) könnte das zu kurzen
  Wartezeiten führen; unkritisch bei der erwarteten Nutzungsfrequenz, aber
  als Beobachtungspunkt vermerkt.
- **Sicherheitsrelevante Architektur**: Ja — direkte Erweiterung von
  `docs/architecture/security-review-backend.md` (Spec 005). Kein separates
  Secure-Architecture-Preset im Projekt installiert (verifiziert: nur das
  allgemeine iSAQB-Architecture-Governance-Preset ist vorhanden); die
  Sicherheitsbewertung erfolgt daher inline über die bestehende Evidenz-
  Datei, wie bereits in spec.md Architecture Governance festgehalten.
- **Offen (Open)**: Keine — beide ADR-Kandidaten (AD-033/AD-034) sind mit
  dieser Planung entschieden, kein Blocker für `/speckit-tasks`.
