# Data Model: Backend-Synchronisation (Playdate-Seite)

**Feature**: 004-backend-sync | **Date**: 2026-07-18

Playdate-seitiges Datenmodell für den Sync-Zustand. Das serverseitige Datenmodell (User/Image-Tabellen) ist bereits in `specs/005-backend-service/data-model.md` definiert und wird hier nicht dupliziert — Spec 004 fügt keine neuen Backend-Entitäten hinzu.

---

## Lokale Persistenz: `sync/state` (via `playdate.datastore`)

### Entität: SyncState

| Feld | Typ | Regeln | Beschreibung |
|---|---|---|---|
| `uid` | string | lokal generiert (16 Hex-Zeichen, Präfix `pd-`), nicht vom SDK bereitgestellt (research.md R10); unveränderlich über die Lebensdauer der App-Installation | Playdate-Geräte-UID |
| `pin` | string | genau 4 Ziffern, vom Gerät zufällig generiert (R7) | Lokal gecachte PIN zur Autorisierung |
| `paired` | boolean | `false` bis Backend-Login mit `uid`+`pin` erstmals `200` liefert | Verknüpfungsstatus |
| `pendingUpload` | table \| nil | `{imageId=string, attemptedAt=number}` oder `nil` | Zustand eines unterbrochenen Uploads (R8) |

**Invarianten:**
- `pin` existiert nur lokal und im Backend-Hash; wird nie im Klartext übertragen außer beim Anzeigen auf dem Playdate-Display (Ergebnisscreen) und bei `/pair`/`/login`/`/upload`-Requests über HTTPS.
- `pin` wird EXAKT EINMAL generiert und danach für die gesamte Lebensdauer der App-Installation unverändert wiederverwendet — auch nach einem `400`/`404` bei `/login` wird KEINE neue PIN generiert, sondern automatisch per `/pair` mit der bestehenden PIN self-healed (research.md R12/R13).
- `paired` ist ein lokaler Cache/Optimierungs-Hinweis (spart den `/pair`-Aufruf im Normalfall), NICHT die autoritative Quelle — jede Crank-Sync-Geste beginnt trotzdem mit einem `/login`-Versuch; das Backend entscheidet, ob (Re-)Pairing nötig ist (research.md R13).
- `pendingUpload` wird nach erfolgreichem Upload-Abschluss auf `nil` gesetzt.

**Lebenszyklus:**
1. **Kein Zustand vorhanden** (Datei `sync/state` existiert nicht) → erste Crank-Sync-Geste generiert `uid`+`pin` lokal, startet direkt die Pairing+Login+Upload-Kette (Schritt 2), OHNE auf eine externe Bestätigung zu warten (research.md R13).
2. **Pairing+Login+Upload-Kette** (eine einzige `RoomOperation`, `SyncService:startSync()` → `startUpload()`): `POST /login` → bei `404`/`400` automatisch `POST /pair` (self-heal, sicher solange `confirmed_at IS NULL`, research.md R12) → `/login`-Retry → bei Erfolg Multipart-`POST /upload`. Bei `429` (gesperrt) sofortiger Abbruch ohne Pairing-Versuch. Erfolgreicher Abschluss setzt `paired = true` und zeigt den Vollbild-Ergebnisscreen (FR-007a).
3. **Verknüpft, Upload effizient**: jede weitere Crank-Sync-Geste auf einem selektierten Bild durchläuft dieselbe Kette, benötigt im Normalfall aber nur den ersten `/login`-Aufruf (kein `/pair`-Overhead, da die UID bereits bekannt ist).

**Hinweis**: Ein Zurücksetzen der Verknüpfung (FR-013) ist in diesem Release nicht vorgesehen (YAGNI) — `sync/state` ist daher für die Laufzeit dieses Features append-only bezüglich `paired`/`pin` (kein Reset-Pfad).

---

## Laufzeit-Entität: CrankGesture (nicht persistiert)

| Feld | Typ | Beschreibung |
|---|---|---|
| `accumulatedDegrees` | number | Kumulierte Rotation seit letztem Reset (kann negativ sein) |
| `selectedImageId` | string \| nil | ID des aktuell selektierten Bildes in der SelectionRoom-Gridview |

**Regeln** (siehe research.md R2):
- Reset auf `0`, wenn `selectedImageId` wechselt oder die Kurbel signifikant (> kleine Toleranzschwelle) die Richtung wechselt.
- `accumulatedDegrees >= 720` → Sync/Upload-Trigger für `selectedImageId`.
- Gegen-Uhrzeigersinn-Rotation hat in diesem Release keine Wirkung (kein Reset-Mechanismus, FR-013 Out of Scope, YAGNI).

---

## Backend-Erweiterung: `images.client_image_id` (kleine, additive Migration)

| Feld | Typ | Regeln | Beschreibung |
|---|---|---|---|
| `client_image_id` | VARCHAR(64) | NULL, Format `[a-z0-9-]+` wenn gesetzt | Lokale, stabile Bild-ID vom Playdate (`ImageStore.sanitizeName`-Format) |

**Zusätzliche Regel**: `UNIQUE(uid, client_image_id)` — verhindert Kollisionen zwischen Geräten derselben UID (theoretisch, da eine UID einem Gerät entspricht) und erlaubt den Lookup "existiert bereits ein Eintrag für dieses (uid, lokale Bild-ID)-Paar?" beim Upload.

**Verhalten** (Erweiterung von `UploadHandler::handleUpload`, additiv, rückwärtskompatibel):
- `image_id`-Feld im Upload-Request vorhanden UND `(uid, image_id)` bereits in DB → bestehenden Eintrag aktualisieren: Dateien unter derselben Server-UUID ersetzen, `png_path`/`gif_path` auf `NULL` setzen (Neu-Rendering beim nächsten Abruf), `uploaded_at` aktualisieren.
- `image_id`-Feld vorhanden, aber `(uid, image_id)` unbekannt → neuen Eintrag wie bisher anlegen, zusätzlich `client_image_id` speichern.
- `image_id`-Feld fehlt (z. B. manuelle Test-Uploads ohne Playdate) → Verhalten unverändert wie in Spec 005 (immer neuer Eintrag, `client_image_id = NULL`).

Details siehe research.md R9 und contracts/sync-protocol.md.

---

## Backend-Erweiterung: `users.confirmed_at` (kleine, additive Migration, research.md R12)

| Feld | Typ | Regeln | Beschreibung |
|---|---|---|---|
| `confirmed_at` | DATETIME | NULL bis zum ersten erfolgreichen `Auth::login()` | Markiert eine Verknüpfung als bestätigt (Gerät und Website nutzen nachweislich dieselbe PIN) |

**Zusätzliche Regel**: `Auth::pair()` überschreibt den `pin_hash` einer bestehenden UID, solange `confirmed_at IS NULL` — verhindert, dass eine versehentlich falsch übertragene PIN die Verknüpfung permanent blockiert (kein Reset-Mechanismus in diesem Release, siehe FR-013). Ist `confirmed_at` gesetzt, bleibt der bisherige Schutz (`409 Conflict` bei erneutem `/pair`) bestehen — eine aktiv genutzte Verknüpfung kann nicht überschrieben werden.

Details siehe research.md R12 und contracts/sync-protocol.md.

---

## Referenz: Bereits bestehende Entitäten (Spec 001 / Spec 005, unverändert)

- **Image (PDI + frames.json)**: Struktur exakt gemäß `specs/001-pdi-storage-format/contracts/storage-format.md`. Lokal auf dem Gerät abgelegt unter `saves/{imageId}/sheet.pdi` (via `playdate.datastore.writeImage`, PDI-Format) und `saves/{imageId}/frames.json` (via `playdate.datastore.write`, echtes JSON auf Disk — siehe `ImageStoreCodec.lua:62-79`). SyncService liest beide Dateien **roh** über `playdate.file.open(path, playdate.file.kFileRead)` (nicht über `datastore.read()`, da das die JSON-Datei zu einer Lua-Tabelle deserialisieren würde statt die Rohbytes für den Multipart-Body zu liefern) und sendet sie unverändert als Multipart-Teile `pdi`/`json`.
- **Backend User/Image-Tabellen**: siehe `specs/005-backend-service/data-model.md` — unverändert durch dieses Feature.
