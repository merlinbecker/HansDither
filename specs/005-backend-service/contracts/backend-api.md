# Contract: Backend API — Endpunkte, Authentifizierung und Datenflüsse

**Feature**: 005-backend-service | **Date**: 2026-07-12

Definiert die API-Schnittstellen des Backend-Service für Hans Dither Sync. Alle Endpunkte basieren auf HTTP/HTTPS und nutzen standardmäßige Formular- oder Multipart-Formular-Daten.

---

## 1. Authentifizierungs-Contract

### Grundprinzipien
- **Keine Cookies**: Authentifizierung erfolgt pro Request via Session-Token oder PIN
- **UID-basiert**: Alle Zugriffe sind auf die UID des authentifizierten Nutzers beschränkt
- **Rate Limiting**: 3 Fehlversuche → 5 Minuten Sperre pro UID

### Session-Verwaltung
- Nach erfolgreicher PIN-Eingabe wird ein **Session-Token** generiert (UUID, 30 Minuten Gültigkeit)
- Token wird in der MySQL-Datenbank gespeichert: `sessions(token VARCHAR PRIMARY KEY, uid VARCHAR, expires_at DATETIME)`
- Token muss bei geschützten Endpunkten im Request Header oder als Query-Parameter mitgesendet werden: `X-Session-Token: {token}`

---

## 2. Endpunkt-Spezifikationen

### E-01: GET `/` — Startseite

**Zweck**: UID-Eingabemaske anzeigen

**Request**:
- Methode: GET
- Parameter: Keine
- Header: Keine

**Response (200 OK)**:
```html
<!-- HTML-Seite mit:
  - Erklärungstext
  - UID-Eingabefeld (input type="text" name="uid")
  - Submit-Button ("Weiter")
  - Link zu dieser Spec
-->
```

**Fehler**: Keine (immer erfolgreich)

---

### E-02: POST `/pair` — Neue Verknüpfung herstellen

**Zweck**: UID mit PIN verknüpfen (erster Zugriff)

**Request**:
- Methode: POST
- Content-Type: `application/x-www-form-urlencoded`
- Parameter:
  - `uid` (required): Playdate-Geräte-ID (String, z. B. "pd-abc123def456")
  - `pin` (required): 4-stellige PIN (String, nur Ziffern 0-9)

**Validierung**:
1. `uid` darf nicht leer sein
2. `uid` darf nicht bereits existieren (DOUBLE CHECK gegen Race Conditions)
3. `pin` muss genau 4 numerische Ziffern enthalten

**Response (201 Created)**:
```json
{
  "status": "success",
  "message": "Verknüpfung erfolgreich hergestellt",
  "uid": "{uid}"
}
```

**Fehler**:
- 400 Bad Request: `{"error": "UID darf nicht leer sein"}` oder `{"error": "PIN muss genau 4 Ziffern enthalten"}`
- 409 Conflict: `{"error": "UID bereits verknüpft"}`

---

### E-03: POST `/login` — Bestehende Verknüpfung nutzen

**Zweck**: PIN für bekannte UID prüfen und Session erstellen

**Request**:
- Methode: POST
- Content-Type: `application/x-www-form-urlencoded`
- Parameter:
  - `uid` (required): Playdate-Geräte-ID
  - `pin` (required): 4-stellige PIN

**Validierung**:
1. `uid` muss existieren
2. Account darf nicht gesperrt sein (`locked_until < NOW()`)
3. `pin` muss mit gespeichertem `pin_hash` übereinstimmen (`password_verify()`)

**Response (200 OK)**:
```json
{
  "status": "success",
  "session_token": "{uuid}",
  "expires_at": "{ISO-8601-Timestamp}",
  "uid": "{uid}"
}
```

**Fehler**:
- 400 Bad Request: `{"error": "UID oder PIN ungültig"}` (generische Fehlermeldung)
- 429 Too Many Requests: `{"error": "Zu viele Fehlversuche. Bitte in 5 Minuten erneut versuchen"}` (nach 3 Fehlversuchen)
- 404 Not Found: `{"error": "UID nicht gefunden"}`

---

### E-04: POST `/upload` — Image hochladen

**Zweck**: PDI- und JSON-Datei für eine UID hochladen

**Request**:
- Methode: POST
- Content-Type: `multipart/form-data`
- Parameter:
  - `pdi` (required): PDI-Binärdatei (Datei-Upload)
  - `json` (required): frames.json-Datei (Datei-Upload)
- Header:
  - `X-Session-Token: {token}` (required) oder `X-UID: {uid}` + `X-PIN: {pin}` (alternativ)

**Validierung**:
1. Session-Token oder UID+PIN muss gültig sein
2. Dateien müssen `.pdi` und `.json` Endung haben
3. **JSON**: `json_decode()` muss erfolgreich sein und ein Objekt/Array zurückgeben
4. **PDI**: Erste 4 Bytes müssen `PDI\0` (Magic Bytes) sein
5. Dateigrößen: Max. 10MB pro Datei

**Verarbeitung**:
1. Generiere UUID für Image
2. Speichere Dateien unter `uploads/{uid}/{uuid}.pdi` und `uploads/{uid}/{uuid}.json`
3. DB-Eintrag erstellen (images-Tabelle)
4. Asynchron: PNG-Rendering starten

**Response (201 Created)**:
```json
{
  "status": "success",
  "image_id": "{uuid}",
  "message": "Upload erfolgreich. PNG wird generiert."
}
```

**Fehler**:
- 401 Unauthorized: `{"error": "Nicht autorisiert"}` (ungültiges Token/UID/PIN)
- 400 Bad Request: `{"error": "Ungültiger Dateityp"}` (Validierung fehlgeschlagen)
- 413 Payload Too Large: `{"error": "Datei zu groß (max. 10MB)"}`
- 429 Too Many Requests: `{"error": "Zu viele Requests"}` (Rate Limiting)

---

### E-05: GET `/images` — Images-Liste abrufen

**Zweck**: Alle Images für eine UID auflisten

**Request**:
- Methode: GET
- Header: `X-Session-Token: {token}` (required)

**Response (200 OK)**:
```json
{
  "status": "success",
  "uid": "{uid}",
  "images": [
    {
      "id": "{uuid}",
      "uploaded_at": "{ISO-8601-Timestamp}",
      "has_png": true/false,
      "pdi_url": "/download/pdi/{uuid}",
      "json_url": "/download/json/{uuid}",
      "png_url": "/download/png/{uuid}"
    },
    ...
  ]
}
```

**Fehler**:
- 401 Unauthorized: `{"error": "Nicht autorisiert"}`

---

### E-06: GET `/download/pdi/{id}` — PDI-Datei herunterladen

**Zweck**: PDI-Binärdatei herunterladen

**Request**:
- Methode: GET
- Header: `X-Session-Token: {token}` (required)
- Parameter: `id` (URL-Path): Image-UUID

**Validierung**:
1. Session-Token muss gültig sein
2. Image `id` muss existieren
3. Image `uid` muss mit Session-UID übereinstimmen

**Response (200 OK)**:
- Content-Type: `application/octet-stream`
- Content-Disposition: `attachment; filename="{id}.pdi"`
- Body: PDI-Binärdaten

**Fehler**:
- 401 Unauthorized: `{"error": "Nicht autorisiert"}`
- 404 Not Found: `{"error": "Image nicht gefunden"}`

---

### E-07: GET `/download/json/{id}` — JSON-Datei herunterladen

**Zweck**: frames.json-Datei herunterladen

**Request/Validierung/Response**: Analog zu E-06, aber:
- Content-Type: `application/json`
- Content-Disposition: `attachment; filename="{id}.json"`

---

### E-08: GET `/download/png/{id}` — PNG-Datei herunterladen

**Zweck**: Gerendertes PNG herunterladen

**Request/Validierung**: Analog zu E-06

**Response (200 OK)**:
- Content-Type: `image/png`
- Content-Disposition: `attachment; filename="{id}.png"`
- Body: PNG-Binärdaten (400×240, 1-Bit)

**Hinweis**: Falls PNG noch nicht generiert wurde, wird es on-demand erstellt (kann Verzögerung verursachen).

---

## 3. Datei-Format-Contracts

### C-01: Upload-Dateien

| Dateityp | Endung | MIME-Type | Validierung |
|---|---|---|---|
| PDI | `.pdi` | `application/octet-stream` | Magic Bytes `PDI\0` + Header |
| JSON | `.json` | `application/json` | `json_decode()` erfolgreich |

**Abgelehnt**: Alle anderen Dateitypen (insbesondere `.php`, `.exe`, `.sh`, `.js`, `.html`)

---

## 4. Sicherheits-Contracts

- **S-01**: Alle Nutzer-Eingaben (UID, PIN) werden vor der Verarbeitung validiert
- **S-02**: PIN wird NIE im Klartext gespeichert (nur bcrypt-Hash)
- **S-03**: Datei-Uploads werden in UID-spezifischen Verzeichnissen gespeichert
- **S-04**: Dateityp-Validierung erfolgt BEVOR Dateien gespeichert werden
- **S-05**: SQL-Abfragen nutzen Prepared Statements (kein String-Konkatenation)
- **S-06**: HTML-Ausgaben werden escaped (`htmlspecialchars()`)
- **S-07**: CORS-Header sind korrekt konfiguriert für Playdate-Simulator
- **S-08**: HTTPS ist erzwungen (HTTP → HTTPS Redirect)

---

## 5. Fehlerbehandlung

### Standard-Fehlerformat
```json
{
  "error": "{menschliche Fehlermeldung}"
}
```

### HTTP-Status-Codes
| Code | Bedeutung | Nutzung |
|---|---|---|
| 200 | OK | Erfolgreiche GET-Requests |
| 201 | Created | Erfolgreiche POST-Requests (Erstellung) |
| 400 | Bad Request | Validierungsfehler |
| 401 | Unauthorized | Authentifizierungsfehler |
| 403 | Forbidden | Berechtigungsfehler |
| 404 | Not Found | Ressource nicht gefunden |
| 409 | Conflict | Ressource existiert bereits |
| 413 | Payload Too Large | Datei zu groß |
| 429 | Too Many Requests | Rate Limiting aktiv |
| 500 | Internal Server Error | Server-Fehler |

---

## 6. Abhängigkeiten

- **Spec 001**: PDI- und JSON-Format-Definition
- **Spec 004**: Upload-Workflow und UID-Struktur vom Playdate
- **all-inkl.com**: PHP 8.x + MySQL 8.x Hosting
