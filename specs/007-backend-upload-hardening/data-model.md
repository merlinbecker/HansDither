# Phase 1 Data Model: Absicherung des Backends gegen unbegrenzte/missbräuchliche Uploads

**Feature**: 007-backend-upload-hardening

Diese Spec führt **keine neue Datenbank-Tabelle und keine neue Spalte**
ein (Constitution IV, research.md R1). Die drei betroffenen "Entitäten"
sind: eine Zähl-/Sperrlogik auf bestehenden Tabellen, eine geänderte
Konstante, und eine neue, rein strukturelle Validierungsregel für ein
bereits existierendes JSON-Format.

---

## 1. Upload-Zähl-Check (kein neues Feld — Query + Transaktionsgrenze)

**Beteiligte Tabellen** (beide bereits vorhanden, unverändert im Schema):

| Tabelle | Verwendung hier | Bestehender Index genutzt |
|---|---|---|
| `users` | Row-Lock-Ziel (`SELECT ... FOR UPDATE`) — dient als Mutex pro UID, Inhalt bleibt unverändert | Primary Key `uid` |
| `images` | `COUNT(*) WHERE uid = ?` zur Ermittlung des aktuellen Bildbestands | `idx_uid` (`001_create_tables.sql`), Unique `(uid, client_image_id)` (`002_sync_extensions.sql`) |

**Transaktionsgrenze** (neu, in `UploadHandler::handleUpload()`, siehe
research.md R1 für die vollständige Herleitung):

```
START TRANSACTION
  SELECT uid FROM users WHERE uid = ? FOR UPDATE
  IF client_image_id bereits bekannt (Update-in-place):
    -- Zähl-Check entfällt, FR-003
    UPDATE images SET ... WHERE uid = ? AND client_image_id = ?
  ELSE:
    SELECT COUNT(*) FROM images WHERE uid = ?
    IF count >= 12: ROLLBACK -> 403
    ELSE: INSERT INTO images (...)
COMMIT
```

**Zustandsübergang**: Kein neuer State — der "Zählerstand" ist zu jedem
Zeitpunkt exakt `COUNT(*) FROM images WHERE uid = ?`, niemals redundant
gespeichert. Das schließt Drift zwischen einem separaten Zählerfeld und
der tatsächlichen Zeilenzahl kategorisch aus (Rejected Alternative in
research.md R1).

**Validierungsregel**: `count < 12` für Neuanlage; kein Limit für
Update-in-place (bekannte `client_image_id`).

---

## 2. Dateigrößen-Konstante

| Feld | Vorher | Nachher |
|---|---|---|
| `Validation::$maxFileSize` | `10 * 1024 * 1024` (10 MB) | `300 * 1024` (300 KB) |

Gilt unverändert für PDI- UND JSON-Datei je einzeln (kein summiertes
Limit, research.md R2/spec.md Assumptions). Kein neues Feld — bestehende
Klassenkonstante wird geändert.

---

## 3. `frames.json`-Schema (neue Validierungsregel, kein neues Format)

Referenz: bereits definiert in
`specs/001-pdi-storage-format/data-model.md` ("Bild / Frames"); hier zum
ersten Mal als PRÜFBARE Regelmenge kodifiziert (`Validation::
validateFramesJsonSchema()`, research.md R4). Das Format selbst ist NICHT
neu — nur die serverseitige Durchsetzung ist neu.

| Feld | Typ | Regel | Fehlerverhalten bei Verletzung |
|---|---|---|---|
| `version` | number | vorhanden, `>= 1` | 400, Feld benannt |
| `name` | string | vorhanden, Länge > 0 | 400, Feld benannt |
| `gridWidth` | number | exakt `25` | 400, Feld benannt |
| `gridHeight` | number | exakt `15` | 400, Feld benannt |
| `tileCount` | number | `>= 1` | 400, Feld benannt |
| `frames` | array | 1 bis 12 Einträge | 400, Feld benannt |
| `frames[f]` | array | exakt `gridWidth × gridHeight` = 375 Zahlen | 400, Index + Ist-Länge benannt |
| `frames[f][i]` | number | `1 <= x <= tileCount` | 400, Index + Wert benannt |

Prüfreihenfolge: Reihenfolge der obigen Tabelle (erste Verletzung
beendet die Prüfung und wird gemeldet — kein Sammeln aller Fehler,
konsistent mit dem bestehenden `Validation`-Muster in dieser Datei, das
ebenfalls beim ersten Fehler abbricht).

**Zustandsübergang**: Keiner — reine zustandslose Struktur-Prüfung einer
eingehenden Datei, kein persistenter Effekt bei Ablehnung.

---

## 4. Client-seitiges Ergebnis (`Source/SyncService.lua`, research.md R6)

Kein neues Datenmodell auf der Playdate-Seite (kein neues gespeichertes
Feld in `sync/state.json`) — lediglich der bestehende, rein
prozess-interne `reason`-String von `attemptUpload()` bekommt einen
zusätzlichen möglichen Wert:

| `reason`-Wert | Neu in dieser Spec? |
|---|---|
| `"limit_reached"` | **Ja** — HTTP 403 (siehe `contracts/upload-hardening.md` für die vollständige Statuscode→Text-Zuordnungstabelle) |
| alle anderen (`token_expired`, `too_large`, `local_read_error`, `network`, `upload_failed`, …) | Nein, unverändert |

Der Wert existiert nur für die Dauer eines einzelnen Upload-Versuchs
(lokale Variable, kein `datastore`-Feld) — kein Migrations- oder
Persistenz-Aspekt.
