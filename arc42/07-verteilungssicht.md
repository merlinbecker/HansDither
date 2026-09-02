# 7. Verteilungssicht

## 7.1 Infrastruktur Ebene 1

Hans Dither besteht aus zwei unabhaengig deploybaren Teilen: dem
**Playdate-Client** (Kern, laeuft vollstaendig offline) und einem
**optionalen Sync-Backend** (PHP/MySQL), das nur beim Bild-Upload
kontaktiert wird.

| Infrastrukturelement | Rolle |
|---|---|
| Playdate Device / Simulator | Ausfuehrung des Lua-Codes, Rendering nativ 400x240, Input, Menues |
| `.pdx` Bundle | Lua-Quellen (`Source/`), Bildassets (`images/`), `pdxinfo` |
| Lokaler Datastore | Persistente Bilder + Previews unter `saves/` |
| Sync-Backend (`www.hans-dither.de`) | Shared Hosting (all-inkl.com): PHP + MySQL; nimmt Pairing/Login/Upload entgegen, rendert PNG/GIF on-demand, liefert eine Ansichts-Webseite je UID |
| Lokaler Browser (Importer, eingefroren) | Offline-PNG-Importtool unter `Tools/Importer/` — kein Laufzeitbezug, historisch (Kap. 11, R-14) |

### Verbindungskanaele
- Client <-> Display/Input/Sensor: Playdate SDK API
- Client <-> Datastore/Dateisystem: `playdate.datastore` und `playdate.file`
- Client <-> Sync-Backend: HTTPS (`playdate.network.http`, Port 443) — nur bei der Kurbel-Sync-Geste
- Browser-Importer <-> lokale Dateien: File-Upload/Download (PNG rein, JSON raus)

## 7.2 Umgebungen

| Umgebung | Zweck |
|---|---|
| Entwicklungsumgebung (VS Code + Playdate SDK) | Codierung, `pdc`-Build, `lua tests/headless_tests.lua` |
| Playdate Simulator | Schneller Funktions- und UI-Test ohne Hardwaretransfer |
| Physische Playdate | Zielplattform fuer reale Bedienung mit Crank, Buttons und Schuettelgeste |
| Backend: lokal / Staging | PHP-Built-in-Server bzw. Test-Vhost (siehe `backend/TESTING.md`) |
| Backend: Produktion | all-inkl.com Webroot der Domain `hans-dither.de` |

## 7.3 Zuordnung von Bausteinen

| Baustein | Infrastrukturzuordnung |
|---|---|
| `main.lua` + Rooms (`Source/*.lua`) | Laufzeit im Lua-Kontext auf Playdate |
| `ImageStore` / `ImageStoreCodec` | Laufzeit-Client; Save/Load-Coroutinen gegen den Datastore |
| `SyncService` | Laufzeit-Client; HTTPS-Aufrufe an das Sync-Backend |
| `images/*` | Bundle-Asset, zur Laufzeit als imagetable/image geladen |
| `saves/*` | Laufzeitpersistenz im Datastore |
| `backend/` (index.php, `includes/`, `public/`, `sql/migrations/`) | PHP-Anwendung auf dem Shared Hosting; Schema-Migrationen unter `backend/sql/migrations/` |
| `backend/deploy.sh` (+ `.deploy.env`, nicht im Repo) | SFTP-Deployment des Backends nach all-inkl.com; Secrets ausschliesslich lokal (`.deploy.env.example` als Vorlage) |
| `Tools/Importer/*` | Separates lokales Browser-Werkzeug, ausserhalb beider Deployments |

## 7.4 Qualitaets-/Leistungsmerkmale der Verteilung

- **Offline-Kern:** der gesamte Editier-/Speicher-Flow braucht keine Netzverbindung; nur die explizite Sync-Geste kontaktiert das Backend.
- **Eine Koordinatenebene:** Client-Anzeige und Persistenz arbeiten beide nativ auf 400x240 mit 16x16-Tiles (AD-016) — keine getrennten Darstellungsebenen mehr.
- **Backend bewusst schlank:** kein Framework, PNG/GIF on-demand statt bei jedem Upload, Rate-Limiting und feste Groessenlimits (Spec 007) fuer den Shared-Hosting-Betrieb.
- **Secrets-Trennung:** Deployment-Zugangsdaten liegen nur in der nicht versionierten `backend/.deploy.env`; das Repo enthaelt nur das `*.example`.
- Hardwaregrenzen des Clients (CPU/RAM) erzwingen einfache Datenstrukturen und gezielte Redraw-Strategien.
