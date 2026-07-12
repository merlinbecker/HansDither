# Implementation Plan: Backend-Service für Hans Dither Sync

**Branch**: `feature/0.4-backend` | **Date**: 2026-07-12 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/005-backend-service/spec.md`

---

## Summary

Ein minimalistisches PHP/MySQL-Backend auf all-inkl.com Hosting, das Nutzer über eine Playdate-UID und 4-stellige PIN authentifiziert. Nutzer können ihre Hans-Dither-Projekte (PDI + frames.json) hochladen, im Web-UI anzeigen lassen und als PDI, JSON oder serverseitig gerendertes PNG herunterladen. Das Backend validiert hochgeladene Dateien via Dateiendung + Inhaltsprüfung (JSON: `json_decode()`, PDI: Magic Bytes `PDI\0` + Header) um Missbrauch zu verhindern.

---

## Technical Context

**Language/Version**: PHP 8.x

**Primary Dependencies**: MySQL 8.x, all-inkl.com Hosting-Infrastruktur, Playdate PDI-Format (Spec 001)

**Storage**: MySQL-Datenbank für UID → PIN-Hash Mapping; Dateisystem für PDI/JSON-Dateien unter `/{UID}/`

**Testing**: Headless-Tests für Backend-Logik (PHPUnit), manuelle Browser-Tests für UI

**Target Platform**: Web (all-inkl.com Shared Hosting)

**Project Type**: Web application (Frontend: HTML/CSS/JS, Backend: PHP)

**Performance Goals**: Upload und Anzeige innerhalb von 5 Sekunden (SC-002); Verknüpfung in unter 30 Sekunden (SC-001)

**Constraints**: all-inkl.com Performance-Limits (Shared Hosting), max. 1000 Images pro UID, 4-stellige PIN (10.000 Kombinationen)

**Scale/Scope**: 1 Backend-Service, 1 MySQL-Tabelle, ~1000 Images pro UID, einfache Web-UI

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Prinzip | Prüfung | Status |
|---|---|---|
| I. SDK-First | Nicht anwendbar — Backend läuft nicht auf Playdate, sondern auf all-inkl.com Server. PHP/MySQL ist die native Technologie für Web-Hosting. | PASS (N/A) |
| II. Native Formate & PDI | Backend verarbeitet native PDI-Dateien (Spec 001) und frames.json. Keine eigenen Formate eingeführt. | PASS |
| III. arc42-Pflege | Umsetzung aktualisiert arc42 Kap. 5 (Bausteine: Backend-Service, MySQL-DB), Kap. 6 (Laufzeitszenarien: UID→PIN→Images), Kap. 8 (Querschnitt: Authentifizierung, Dateispeicherung), Kap. 10 (Qualitätsanforderungen: Performance, Sicherheit). Als Tasks einzuplanen. | PASS (geplant) |
| IV. Einfachheit | Minimalistische Architektur: PHP/MySQL ohne Frameworks, all-inkl.com als einfaches Hosting. Keine unnötige Komplexität. | PASS |
| V. Testpflicht | N/A — Prinzip V gilt für `Source/*.lua` (Playdate-Code). Backend-Tests sind jedoch als Best Practice empfohlen (PHPUnit für Logik). | PASS (N/A) |

**Post-Design Re-Check (nach Phase 1)**: PASS — Datenfluss basiert auf Spec 001 Contract; keine neuen Abstraktionsschichten.

**Architektur-Review nach Implementierung**: Geprüft gegen Constitution. Abweichungen: Keine. Security-Relevant: Ja (PIN-Authentifizierung, Dateivalidierung) — Sicherheits-Review vor Deployment erforderlich.

---

## Project Structure

### Documentation (this feature)

```text
specs/005-backend-service/
├── plan.md              # Diese Datei
├── research.md          # Phase 0: PHP/MySQL-Best-Practices, PDI-Format-Validierung, PNG-Rendering
├── data-model.md        # Phase 1: Backend-Datenmodell, Dateistruktur
├── quickstart.md        # Phase 1: Validierungsszenarien (Browser + Upload-Tests)
├── contracts/           # Phase 1: API-Endpunkte, Upload-Contract
│   └── backend-api.md   # Backend-API-Spezifikation
└── tasks.md             # Phase 2 (/speckit-tasks — nicht Teil dieses Laufs)
```

### Source Code (all-inkl.com Hosting)

```text
/
├── index.php            # Einstiegspunkt: UID-Eingabe, PIN-Verwaltung, Images-Liste
├── upload.php           # Upload-Handler: Dateivalidierung + Speicherung
├── render.php           # PNG-Renderer: PDI + JSON → PNG
├── config.php           # Konfiguration (DB-Zugang, Pfade)
├── includes/
│   ├── database.php     # DB-Verbindung + PIN-Hashing
│   ├── validation.php   # Dateivalidierung (JSON, PDI)
│   └── auth.php         # PIN-Authentifizierung + Rate Limiting
├── assets/
│   ├── css/
│   │   └── style.css    # Minimal CSS für UI
│   └── js/
│       └── app.js       # Vanilla JS für Interaktion
└── uploads/
    └── {UID}/
        ├── {image-id}.pdi
        └── {image-id}.json
```

**Structure Decision**: Single-project Web-Application auf all-inkl.com. Keine Frameworks (Reine PHP/HTML/JS für maximale Kompatibilität mit Shared Hosting). Dateien organisiert nach UID für Isolation und einfache Berechtigungsprüfung.

---

## Complexity Tracking

Keine Constitution-Verstöße — Tabelle entfällt.

---

## Architecture Governance (iSAQB-Preset)

- **Architektur-Arbeitsprodukte**: arc42 Kap. 5 (Bausteinsicht: Backend-Service, MySQL-DB, Dateisystem-Storage, Web-Frontend), Kap. 6 (Laufzeitszenarien: UID-Eingabe → PIN-Verifikation → Images-Liste → Download), Kap. 8 (Querschnittskonzepte: 8.1 Authentifizierung via PIN, 8.2 Dateispeicherung, 8.4 Security), Kap. 10 (Qualitätsanforderungen: Performance SC-001/SC-002, Sicherheit), Kap. 11 (Risiken: Brute-Force, Speicherwachstum, Hosting-Limits) — Evidenz: Feature-Branch-Diff
- **ADRs**: AD-025 (PHP/MySQL auf all-inkl.com), AD-026 (PIN-Hashing-Strategie mit `password_hash()`), AD-027 (Dateivalidierung: Endung + Inhaltsprüfung), AD-028 (PNG-Rendering aus PDI + JSON) — Status: zu erstellen in Phase 1
- **Risiko-/Schulden-Review**: Mit Umsetzung entfallen keine Schulden; neu zu beobachten: Brute-Force-Risiko bei 4-stelliger PIN (R-14), Speicherwachstum bei vielen PDI-Dateien (R-15), all-inkl.com Performance-Limits (R-16) — in `arc42/11-risiken-und-technische-schulden.md` austragen
- **Offen (Open)**: PDI-Format-Parser für serverseitiges Rendern (Owner: Projektinhaber, Follow-up: research.md, Re-Evaluation: vor Deployment)
- **Sicherheitsrelevante Architektur**: Ja — PIN-Authentifizierung, Dateivalidierung, Dateizugriffs-isolation. Security-Review vor Deployment: Sicherstellen, dass keine Dateitypen außer .pdi/.json akzeptiert werden und kein Code Execution möglich ist. Evidenz: Security-Review-Dokument + Penetrationstests.
