# Implementation Plan: Backend-Synchronisation für Hans Dither (Playdate-Seite)

**Branch**: `feature/0.3` | **Date**: 2026-07-18 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/004-backend-sync/spec.md`

---

## Summary

Playdate-seitige Gegenstelle zum bereits implementierten Backend (Spec 005): Ein neues Modul `Source/SyncService.lua` verknüpft das Playdate per QR-Code + geräteseitig generierter 4-stelliger PIN mit dem Backend und lädt einzelne Hans-Dither-Bilder (PDI + frames.json) hoch. Da das Playdate-SDK maximal drei System-Menü-Einträge erlaubt und SelectionRoom/EditorRoom diese bereits vollständig nutzen (research.md R1), wird der Sync-Einstiegspunkt über eine bislang ungenutzte Crank-Geste in der SelectionRoom realisiert (zwei volle Umdrehungen im Uhrzeigersinn = Sync) statt über einen Menüeintrag. Der Upload erfolgt dadurch pro Einzelbild statt als Sammel-Upload, mit Update-in-place bei wiederholtem Sync desselben Bildes (FR-007b) — dafür erhält das bestehende Backend eine kleine, additive Erweiterung (siehe research.md R9). Ein Zurücksetzen der Verknüpfung ist in diesem Release nicht vorgesehen (FR-013, YAGNI).

---

## Technical Context

**Language/Version**: Lua (Playdate-Runtime), SDK v3.0.6 (verifiziert lokal, `~/Developer/PlaydateSDK`)

**Primary Dependencies**: Playdate CoreLibs `qrcode` (`generateQRCodeSync`), `playdate.network.http` (HTTP-Client, ab Playdate OS 2.7), `playdate.ui.crankIndicator`, `playdate.datastore`/`playdate.file` (lokale Persistenz) — alle gegen die installierte SDK-Version verifiziert (research.md R1–R7). Backend: überwiegend bereits implementiert (`backend/`, Spec 005); kleine additive Erweiterung für Update-in-place-Semantik nötig (research.md R9, `client_image_id`-Spalte + Upload-Handler-Logik).

**Storage**: `playdate.datastore` unter `sync/state` (UID, selbstgenerierte PIN, Pairing-Status, ausstehender Upload) — lokal auf dem Gerät. Kein neuer Server-seitiger Speicher.

**Testing**: `lua tests/headless_tests.lua` (Constitution Prinzip V, strikte SDK-Mocks für `playdate.network.http`, `playdate.datastore`, `playdate.graphics.generateQRCodeSync`, Crank-APIs) + `pdc Source "Hans Dither.pdx"` Build-Gate + manuelle Simulator-Validierung gegen echtes/lokales Backend (quickstart.md).

**Target Platform**: Playdate (Device + Simulator), Gegenstelle: bestehendes PHP/MySQL-Backend (Spec 005, all-inkl.com)

**Project Type**: Erweiterung einer bestehenden Single-Codebase (Lua/Playdate) um ein neues Service-Modul; kein neues Backend-Projekt

**Performance Goals**: Vollständiger Sync-Workflow (Pairing + 1 Bild-Upload) < 2 Minuten (SC-001); Upload blockiert die Bedienung nicht (SC-006, Coroutine-basiert)

**Constraints**: Max. 3 System-Menü-Einträge (SDK-Hardlimit, bereits ausgeschöpft, siehe R1); kein Multipart-Encoder im SDK (manueller Body-Bau, research.md R4); Netzwerkzugriff nur aus `playdate.update()`-Kontext (Coroutine-Zwang); Kern-Editor MUSS ohne Netzwerkverbindung voll funktionsfähig bleiben (Constitution v1.2.0, Netzwerk-Sync-Ausnahme)

**Scale/Scope**: 1 neues Lua-Modul (`SyncService.lua`) + gezielte Erweiterungen an `SelectionRoom.lua` (Crank-Handling, Hinweis-Anzeige) + kleine, additive Erweiterung an `backend/includes/upload_handler.php`, `backend/public/upload.php` und eine neue SQL-Migration (`client_image_id`-Spalte)

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Prinzip | Prüfung | Status |
|---|---|---|
| I. SDK-First | QR-Code (`generateQRCodeSync`), HTTP (`playdate.network.http`), Crank-Messung (`getCrankChange`, `isCrankDocked`, `crankIndicator`) und Persistenz (`playdate.datastore`) sind alles native SDK-Funktionen, gegen installiertes SDK v3.0.6 verifiziert (research.md R1–R7). Kein Custom-Code außerhalb des SDK für diese Kernfunktionen; einzige Eigenimplementierung ist der Multipart-Body-Bau als String-Konkatenation, da das SDK keinen Encoder bietet (begründete Abweichung, siehe R4). | PASS |
| II. Native Formate & PDI | Es werden keine neuen Datenformate eingeführt; PDI + frames.json aus Spec 001 werden unverändert 1:1 übertragen. | PASS |
| III. arc42-Pflege | Umsetzung aktualisiert arc42 Kap. 4 (Nicht-Ziele "kein Cloud-Sync" entfällt, siehe Constitution-Sync-Impact-Report-TODO), Kap. 5 (Baustein SyncService), Kap. 6 (Laufzeitszenarien Pairing/Upload), Kap. 8 (Querschnitt: Netzwerk, Authentifizierung), Kap. 10 (Qualität: Performance/Sicherheit), Kap. 11 (Risiken: Offline, PIN-Caching). Als Tasks einzuplanen (Phase 2). | PASS (geplant) |
| IV. Einfachheit vor Ausbau | Einzelbild-Sync statt Sammel-Upload reduziert Komplexität gegenüber dem ursprünglichen Spec-Entwurf (kein Multi-Bild-Queue-Management, siehe R8). Crank-Geste nutzt ein bestehendes, in SelectionRoom bislang ungenutztes Eingabemittel statt neuer UI-Elemente. Bestehende Muster (Coroutine-Langläufer + `loadingBar`, `update()`-Polling-Stil) werden wiederverwendet. Verknüpfung-zurücksetzen (ursprünglich FR-013) wurde als YAGNI gestrichen. Die Backend-Erweiterung (R9) ist bewusst minimal: eine nullable Spalte + ein zusätzlicher optionaler Parameter, kein neuer Endpunkt. | PASS |
| V. Testpflicht | Gilt für `Source/*.lua` — `SyncService.lua` und die SelectionRoom-Erweiterung MÜSSEN headless-testbar sein: SDK-Zugriffe (`playdate.network.http`, `playdate.datastore`, `generateQRCodeSync`) über mockbare Aufrufe, Logik (Crank-Akkumulator, Multipart-Body-Bau, Statusauswertung) von SDK-Calls getrennt. Beide Gates (`headless_tests.lua`, `pdc`-Build) sind Abschlussbedingung für jede Task. | PASS (verpflichtend für Phase 2/Implementierung) |

**Netzwerk-Ausnahme (Constitution v1.2.0)**: Dieses Feature ist die explizit vorgesehene Ausnahme vom Netzwerkverbot der Kern-Persistenz. Bedingung erfüllt: Kern-Editor-Funktionen (Zeichnen, Speichern, Laden) bleiben vollständig offline nutzbar; Sync ist rein additiv über die Crank-Geste.

**Post-Design Re-Check (nach Phase 1)**: PASS — data-model.md führt nur lokale, geräteseitige Zustände ein; keine neuen Serverstrukturen. contracts/sync-protocol.md nutzt ausschließlich bereits im Backend-Code verifizierte Endpunkte (`/login`, `/upload`), keine Backend-Änderung nötig.

**Architektur-Review nach Implementierung** *(auszufüllen bei Task-Abschluss)*: Open — Owner: Projektinhaber, Follow-up: Security-Review vor erstem produktivem Sync (PIN-Caching-Risiko, siehe Risiken unten), Re-Evaluation-Trigger: Abschluss der Implementierungs-Tasks (Phase 4/5 in tasks.md).

---

## Project Structure

### Documentation (this feature)

```text
specs/004-backend-sync/
├── plan.md              # Diese Datei
├── research.md          # Phase 0: SDK-Verifikation (QR/HTTP/Crank/Menü-Limit), Backend-Contract-Abgleich
├── data-model.md         # Phase 1: Lokaler Sync-Zustand (SyncState, CrankGesture)
├── quickstart.md         # Phase 1: Validierungsszenarien (Simulator + Backend)
├── contracts/
│   └── sync-protocol.md  # Phase 1: Crank-Gesten-Kontrakt + HTTP-Kontrakt SyncService ↔ Backend
└── tasks.md              # Phase 2 (/speckit-tasks — nicht Teil dieses Laufs)
```

### Source Code (Repo: `Source/`, Playdate-Lua)

```text
Source/
├── main.lua                # ERWEITERT: import "SyncService"
├── SelectionRoom.lua        # ERWEITERT: Crank-Akkumulator in update(), Hinweisanzeige bei
│                            # Bildauswahl, Aufruf von SyncService:startSync(imageId)
├── SyncService.lua           # NEU: Sync-Zustand (sync/state via datastore), QR-Anzeige,
│                            # PIN-Generierung, HTTP-Login/Upload-Coroutine, Multipart-Body-Bau
├── loadingBar.lua            # WIEDERVERWENDET: Fortschrittsanzeige während Upload-Coroutine
└── ...                      # unverändert (EditorRoom.lua, ImageStore*.lua, etc.)

tests/
└── headless_tests.lua        # ERWEITERT: Mocks für playdate.network.http, playdate.datastore
                             # (sync/state), generateQRCodeSync, getCrankChange/isCrankDocked;
                             # neue Testfälle für Crank-Akkumulator, Statusauswertung, Multipart-Bau

backend/                              # ÜBERWIEGEND UNVERÄNDERT (Spec 005), kleine additive Erweiterung:
├── includes/upload_handler.php       # ERWEITERT: optionales image_id-Param, Update-in-place-Logik (R9)
├── public/upload.php                 # ERWEITERT: image_id aus Multipart-Body an Handler durchreichen
└── sql/migrations/
    └── 002_add_client_image_id.sql   # NEU: client_image_id-Spalte + UNIQUE(uid, client_image_id)
```

**Structure Decision**: Erweiterung der bestehenden Single-Codebase unter `Source/` um ein neues, klar abgegrenztes Modul `SyncService.lua` (analog zu bestehenden Service-/Store-Dateien wie `ImageStore.lua`). Kein neues Top-Level-Projekt. Am Backend (`backend/`, Spec 005) wird gezielt nur die für Update-in-place-Semantik (FR-007b) nötige, additive und rückwärtskompatible Erweiterung vorgenommen — Spec 004 bleibt überwiegend Konsument des in Spec 005 bereits definierten und implementierten Backend-Contracts.

---

## Complexity Tracking

Keine Constitution-Verstöße nach Amendment (v1.2.0) — Tabelle entfällt. Die nennenswerten Abweichungen vom ursprünglichen Spec-Entwurf (Crank-Geste statt System-Menü, Einzelbild- statt Sammel-Upload, Update-in-place statt Duplikat, kein Reset-Mechanismus) sind keine Constitution-Verletzungen, sondern in research.md R1/R9 begründete SDK-Limitierungen bzw. Advisor-Review-Ergebnisse; dokumentiert als Clarifications in spec.md und als AD-029/AD-030 (siehe unten).

---

## Architecture Governance (iSAQB-Preset)

- **Architektur-Arbeitsprodukte**: arc42 Kap. 4 (4.4 "Nicht-Ziele" — Zeilen zu "Kein Cloud-Sync"/"Keine Netzwerkfunktionen" entfernen/historisieren), Kap. 5 (Bausteinsicht: neuer Baustein `SyncService`, Beziehung zu `SelectionRoom` und Backend), Kap. 6 (Laufzeitszenarien: Pairing-Sequenz, Einzelbild-Upload-Sequenz, Status-Poll), Kap. 8 (Querschnittskonzepte: 8.x Authentifizierung via gerätegenerierter PIN, 8.x Netzwerkkommunikation/Coroutine-Pflicht), Kap. 10 (Qualitätsanforderungen: SC-001–SC-006), Kap. 11 (Risiken: PIN-Caching, Offline-Queue, Multipart-Boundary-Kollision) — Evidenz: Feature-Branch-Diff, als Tasks in tasks.md einzuplanen (Phase 2).
- **ADRs**: AD-021 (QR-basiertes Pairing), AD-022 (geräteseitig generierte PIN mit lokalem Caching statt Nutzer-PIN), AD-023 (Backend-Integration — überwiegende Wiederverwendung von Spec 005), AD-024 (Offline-Queue, vereinfacht auf Einzelbild-Zustand), AD-029 (Crank-Geste statt System-Menü-Eintrag wegen 3-Slot-SDK-Limit), AD-030 (Update-in-place bei Re-Sync via client-seitiger Bild-ID, kleine additive Backend-Erweiterung statt Duplikat-Verhalten) — AD-025–028 bereits durch Spec 005 belegt. Status: **Open**, zu erstellen in `arc42/adr/` vor Implementierungs-Abschluss (Owner: Projektinhaber, Follow-up: Phase 2/tasks.md, Re-Evaluation-Trigger: vor erstem Merge nach main).
- **Risiko-/Schulden-Review**: Neu zu beobachten — R-17 lokal gecachte PIN bei Geräteverlust (kein zusätzlicher Schutz über 4-stellige PIN hinaus, akzeptiert gemäß spec.md Assumptions), R-18 Multipart-Boundary-Kollision bei PDI-Binärdaten (theoretisch möglich, da kein Multipart-Encoder im SDK; Mitigation: hinreichend zufälliger Boundary-String, kein Test auf Kollision in v1), R-19 Discrepancy zwischen Spec-005-Contract-Doku und tatsächlichem `upload.php`-Code (X-UID/X-PIN-Alternative existiert nicht, siehe research.md R5 — Follow-up außerhalb dieses Features: Contract-Doku korrigieren), R-20 Migration `002_add_client_image_id.sql` auf produktiver all-inkl.com-DB (additiv/rückwärtskompatibel, aber MUSS vor Deployment der neuen `upload.php`-Version ausgeführt werden — Reihenfolge-Abhängigkeit im Deploy-Prozess, `backend/deploy.sh` beachten) — in `arc42/11-risiken-und-technische-schulden.md` auszutragen (Phase 2 Task).
- **Sicherheitsrelevante Architektur**: Ja — PIN-Generierung und lokales Caching auf dem Gerät (R-17), Netzwerkübertragung (HTTPS, bereits durch Spec 005 erzwungen), Autorisierung pro Request (Session-Token aus `/login`). Security-Review vor erstem produktivem Sync erforderlich (Constitution: Sicherheitsrelevante Architektur-Vorgabe). **Owner**: Projektinhaber. **Trigger**: vor Merge nach `main`.
- **Offen (Open)**:
  - Multipart-Boundary-Kollisionsschutz — Owner: Projektinhaber, Follow-up: Tasks-Phase (ggf. Boundary-Escaping oder Prüfung), Re-Evaluation: vor erstem produktivem Upload großer PDI-Dateien.
  - Contract-Doku-Korrektur in Spec 005 (X-UID/X-PIN-Alternative) — Owner: Projektinhaber, Follow-up: separates Ticket/Spec-Update außerhalb 004, Re-Evaluation: nächste Backend-Iteration.
- **N/A-Einträge**: Verteilungssicht (arc42 Kap. 7) — N/A, keine neue Deployment-Einheit; dieses Feature deployt sich als Teil der bestehenden `.pdx`-Build-Pipeline, keine separate Infrastruktur.
