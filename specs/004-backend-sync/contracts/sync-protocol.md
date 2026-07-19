# Contract: Playdate-Sync-Protokoll

**Feature**: 004-backend-sync | **Date**: 2026-07-18

Definiert, wie `Source/SyncService.lua` mit dem bestehenden Backend (Spec 005, `backend/public/index.php` + `backend/public/upload.php`) kommuniziert, und den Crank-Gesten-Kontrakt gegenüber `SelectionRoom.lua`. Die serverseitigen Endpunkt-Details (Felder, Statuscodes, Fehlerformate) sind bereits verbindlich in `specs/005-backend-service/contracts/backend-api.md` spezifiziert; dieses Dokument beschreibt nur die **Playdate-seitige Nutzung** dieser Endpunkte inkl. der in research.md R5 dokumentierten Korrektur gegenüber der dortigen Contract-Doku.

---

## 1. UI-Kontrakt: Crank-Sync-Geste (SelectionRoom → SyncService)

| Ereignis | Auslöser | Wirkung |
|---|---|---|
| `syncGestureTriggered(imageId)` | `accumulatedDegrees >= 720` bei selektiertem Bild | `SyncService:startSync(imageId)` |
| Hinweisanzeige | Bild selektiert, egal ob Kurbel bewegt wird | `SelectionRoom` zeichnet `playdate.ui.crankIndicator` + Text "crank to sync"; zusätzlich System-Crank-Alert falls `playdate.isCrankDocked()` |

**Hinweis**: Ein Reset-Gegenstück (Gegen-Uhrzeigersinn-Geste) ist für dieses Release nicht spezifiziert (FR-013 Out of Scope, YAGNI).

`SyncService` exponiert ausschließlich diese beiden Einstiegspunkte; die Rotationsmessung (Akkumulator, Richtungs-Toleranz, Reset bei Selektionswechsel) verbleibt in `SelectionRoom` analog zum bestehenden `update()`-Polling-Stil der Rooms.

---

## 2. HTTP-Kontrakt: SyncService → Backend

Alle Requests laufen innerhalb einer Coroutine (siehe research.md R4), gestartet aus `playdate.update()`. Seit dem Redesign in research.md R13 laufen Schritt A (Login) und Schritt A' (autonomes Pairing bei Bedarf) und Schritt B (Upload) als EINE zusammenhängende Kette pro Crank-Geste, ohne auf eine externe Website-Bestätigung zu warten.

### Schritt A — Login (Session-Token erhalten)

Erster Schritt jeder Crank-Sync-Geste (FR-006a). Im Normalfall (Gerät bereits verknüpft) der EINZIGE Request vor dem Upload.

```
POST https://www.hans-dither.de/login
Content-Type: application/x-www-form-urlencoded
Body: uid={uid}&pin={pin}
```

**Antwort-Interpretation** (siehe `specs/005-backend-service/contracts/backend-api.md` E-03, verifiziert gegen `backend/includes/auth.php:62-127`):

| HTTP-Status | Bedeutung | SyncService-Reaktion |
|---|---|---|
| `200` | Erfolgreich, Body enthält `session_token` | `paired = true` speichern; automatisch mit Schritt B fortfahren (FR-006b) — kein zweiter Crank nötig |
| `404` | UID unbekannt | Automatisch Schritt A' (Pairing) auslösen, danach Schritt A genau einmal wiederholen (FR-004b) |
| `400` | PIN falsch (z. B. Altlast aus einer alten, abgeschafften Web-Pairing-Ära) | Automatisch Schritt A' (Pairing, Self-Heal) auslösen, danach Schritt A genau einmal wiederholen (FR-004b, research.md R12/R13) |
| `429` | Gesperrt (Rate Limit) | KEIN automatischer Pairing-Versuch (würde die Sperre nicht aufheben) — sofort Fehlermeldung "too many attempts" |

### Schritt A' — Pairing (autonom, nur nach `404`/`400` in Schritt A)

Ruft denselben Endpunkt auf, den bisher nur das Web-Formular ansprach — für einen Nicht-Formular-POST (ohne `web=1`-Feld) liefert `backend/public/index.php::handlePairRequest()` bereits JSON statt eines Redirects, keine Backend-Änderung nötig (research.md R13).

```
POST https://www.hans-dither.de/pair
Content-Type: application/x-www-form-urlencoded
Body: uid={uid}&pin={pin}
```

**Antwort-Interpretation** (verifiziert gegen `backend/includes/auth.php::Auth::pair()`):

| HTTP-Status | Bedeutung | SyncService-Reaktion |
|---|---|---|
| `201` | Erfolgreich registriert (neu ODER unbestätigte UID überschrieben, research.md R12) | Schritt A (Login) genau einmal wiederholen |
| `409` | UID bereits bestätigt verknüpft, gehört einem anderen Gerät | Kette abbrechen, Fehlermeldung "device ID conflict" (praktisch unerreichbar bei 2^64 zufälligen UIDs, research.md R10) |
| `400` | UID/PIN-Format ungültig | Sollte bei geräteseitig generierten Werten nie auftreten — Kette abbricht mit generischer Fehlermeldung |

### Schritt B — Upload (nach erfolgreichem Schritt A)

```
POST https://www.hans-dither.de/upload
Content-Type: multipart/form-data; boundary={boundary}
Body (multipart parts):
  - uid       (Textfeld)
  - token     (Textfeld, = session_token aus Schritt A)
  - image_id  (Textfeld, NEU für Spec 004: lokale Bild-ID, Format [a-z0-9-]+, siehe R9) —
              Backend-Erweiterung, additiv/optional aus Sicht des bestehenden Endpunkts
  - pdi       (Dateiteil, Content-Type: application/octet-stream, Dateiname endet auf .pdi;
              Rohinhalt von saves/{imageId}/sheet.pdi, gelesen via playdate.file.open(..., kFileRead))
  - json      (Dateiteil, Content-Type: application/json, Dateiname endet auf .json;
              Rohinhalt von saves/{imageId}/frames.json, gelesen via playdate.file.open(..., kFileRead) —
              NICHT via playdate.datastore.read(), das würde zu einer Lua-Tabelle deserialisieren
              statt die rohen JSON-Bytes zu liefern)
```

**Wichtig — Diskrepanz zur Spec-005-Contract-Doku (research.md R5)**: Die dort erwähnte alternative Header-Authentifizierung (`X-UID` + `X-PIN` statt Session-Token) existiert im tatsächlichen `upload.php`-Code **nicht**. SyncService MUSS daher immer zuerst Schritt A ausführen, um einen `session_token` zu erhalten — ein direkter Upload nur mit `uid`+`pin` ist nicht möglich.

**Backend-Erweiterung für Update-in-place (FR-007b, research.md R9)**: `upload_handler.php::handleUpload()` erhält einen zusätzlichen optionalen Parameter für `image_id`. Ist `(uid, image_id)` bereits als `client_image_id` in der `images`-Tabelle bekannt, werden die vorhandenen Dateien überschrieben und `png_path`/`gif_path` zurückgesetzt statt ein neuer Eintrag angelegt (siehe data-model.md). Fehlt `image_id` im Request, bleibt das Verhalten exakt wie im bestehenden Spec-005-Code (immer neuer Eintrag) — vollständig rückwärtskompatibel.

**Antwort-Interpretation** (E-04):

| HTTP-Status | Bedeutung | SyncService-Reaktion |
|---|---|---|
| `201` | Erfolgreich (Neuanlage ODER Update in-place, siehe R9), Body enthält `image_id` (Server-UUID) | Vollbild-Ergebnisscreen mit QR-Code + PIN anzeigen (FR-007a) |
| `401` | Token ungültig/abgelaufen | Schritt A wiederholen (neuer Login), Upload erneut versuchen |
| `400` | Dateityp ungültig | Sollte bei korrektem PDI/JSON aus Spec 001 nicht auftreten — als interner Fehler loggen |
| `413` | Datei zu groß (>10MB) | Fehler anzeigen; betrifft nur Extremfälle (siehe Edge Case: sehr viele Frames) |
| Verbindungsfehler | Netzwerk unterbrochen | `pendingUpload` in `sync/state` setzen (R8), späterer Retry |

### Multipart-Body-Konstruktion

Da `playdate.network.http` keinen Multipart-Encoder mitliefert (research.md R4), baut `SyncService` den Body manuell als String zusammen:

```
--{boundary}\r\n
Content-Disposition: form-data; name="uid"\r\n\r\n
{uid}\r\n
--{boundary}\r\n
Content-Disposition: form-data; name="token"\r\n\r\n
{token}\r\n
--{boundary}\r\n
Content-Disposition: form-data; name="pdi"; filename="{imageId}.pdi"\r\n
Content-Type: application/octet-stream\r\n\r\n
{rohe PDI-Bytes}\r\n
--{boundary}\r\n
Content-Disposition: form-data; name="json"; filename="{imageId}.json"\r\n
Content-Type: application/json\r\n\r\n
{frames.json-Inhalt}\r\n
--{boundary}--\r\n
```

`Content-Type`-Header des Requests: `multipart/form-data; boundary={boundary}` (Boundary-String frei wählbar, z. B. `----HansDitherSync{zufällige Hex-Zeichen}`, darf nicht im Dateiinhalt vorkommen — PDI-Binärdaten werden nicht auf Boundary-Kollision geprüft, siehe Risiken in plan.md).

---

## 3. QR-Code-Kontrakt

Payload (angezeigt auf dem Vollbild-Ergebnisscreen NACH einem erfolgreichen Upload, siehe research.md R3/R13 — nicht mehr als Warteschritt davor):

```
https://www.hans-dither.de/?uid={uid}
```

Zielverhalten auf Backend-Seite (`backend/public/index.php`, additiv erweitert, research.md R12): Da das Gerät sich inzwischen selbst pairt (research.md R13), erreicht ein Mensch diese URL i. d. R. bereits mit einer bestätigten UID (mind. ein erfolgreicher Geräte-Login hat stattgefunden, sobald ein Upload erfolgreich war):
- UID bestätigt (`confirmed_at` gesetzt) → Redirect zu `/login?uid={uid}` (PIN-Eingabe im Browser, zeigt danach Images-Liste — reiner Ansehen-Zugang, kein Upload-Schritt mehr).
- UID unbekannt ODER unbestätigt (`confirmed_at IS NULL`) → Redirect zu `/pair?uid={uid}` (PIN-Eingabe im Browser). Praktisch nur relevant, falls der Ergebnisscreen manuell aufgerufen wird, bevor je ein Upload erfolgreich war (z. B. manuelles Testen der UID-Eingabe, siehe spec.md Clarifications) — im regulären Ablauf (US1/US2) ist die UID zum Zeitpunkt der QR-Anzeige bereits bestätigt.
