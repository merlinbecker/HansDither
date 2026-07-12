# Data Model: Backend-Service für Hans Dither Sync

**Feature**: 005-backend-service | **Date**: 2026-07-12

Backend-spezifisches Datenmodell für UID-PIN-Authentifizierung, Image-Speicherung und Dateivalidierung.

---

## Backend-Datenbank (MySQL)

### Entität: User (Nutzer/Verknüpfung)

| Feld | Typ | Regeln | Beschreibung |
|---|---|---|---|
| `uid` | VARCHAR(64) | PRIMARY KEY, NOT NULL | Eindeutige Playdate-Geräte-ID |
| `pin_hash` | VARCHAR(255) | NOT NULL | bcrypt-Hash der 4-stelligen PIN |
| `failed_attempts` | INT | DEFAULT 0 | Zähler für Fehlversuche |
| `locked_until` | DATETIME | NULL | Zeitstempel, bis wann Account gesperrt ist |
| `created_at` | DATETIME | DEFAULT CURRENT_TIMESTAMP | Erstellungszeitpunkt |

**Invarianten:**
- `uid` entspricht dem Format des Playdate SDK (z. B. "pd-abc123def456")
- `pin_hash` wird NIE im Klartext gespeichert
- `failed_attempts` wird nach erfolgreicher Authentifizierung zurückgesetzt
- `locked_until` wird nach 5 Minuten automatisch freigegeben

**Lebenszyklus:**
1. **Erstellung**: Nutzer gibt UID + PIN ein → `uid` + `pin_hash` werden gespeichert
2. **Authentifizierung**: PIN-Eingabe → `password_verify($input, pin_hash)`
3. **Sperrung**: 3 Fehlversuche → `locked_until = NOW() + INTERVAL 5 MINUTE`
4. **Freigabe**: `locked_until < NOW()` → Nutzer kann erneut versuchen

---

### Entität: Image (Hochgeladenes Projekt)

| Feld | Typ | Regeln | Beschreibung |
|---|---|---|---|
| `id` | VARCHAR(36) | PRIMARY KEY, NOT NULL | UUID für eindeutige Identifikation |
| `uid` | VARCHAR(64) | NOT NULL, FOREIGN KEY | Verknüpfte Nutzer-UID |
| `pdi_path` | VARCHAR(255) | NOT NULL | Pfad zur PDI-Datei (z. B. `uploads/{uid}/{id}.pdi`) |
| `json_path` | VARCHAR(255) | NOT NULL | Pfad zur frames.json (z. B. `uploads/{uid}/{id}.json`) |
| `png_path` | VARCHAR(255) | NULL | Pfad zum gerenderten PNG (NULL wenn noch nicht generiert) |
| `uploaded_at` | DATETIME | DEFAULT CURRENT_TIMESTAMP | Upload-Zeitpunkt |

**Invarianten:**
- `uid` muss in der `users` Tabelle existieren
- `pdi_path` und `json_path` müssen auf existierende Dateien zeigen
- `id` wird serverseitig als UUIDv4 generiert
- Dateien werden unter `uploads/{uid}/` gespeichert

**Lebenszyklus:**
1. **Upload**: Nutzer lädt PDI + JSON hoch → `id`, `uid`, `pdi_path`, `json_path` werden gespeichert
2. **Rendering**: Backend generiert PNG → `png_path` wird gesetzt
3. **Download**: Nutzer lädt PDI/JSON/PNG herunter
4. **Löschung**: CASCADE bei User-Löschung

---

## Dateisystem-Struktur

```text
/
└── uploads/
    └── {UID}/
        ├── {image-id}.pdi      # PDI-Binärdatei (Playdate Image)
        └── {image-id}.json     # Frame-Daten (Spec 001 Contract)
```

**Validierungsregeln für Uploads:**
1. **Dateiendung**: MUSS `.pdi` oder `.json` sein
2. **JSON-Validierung**: `json_decode($content)` muss erfolgreich sein und ein Objekt/Array zurückgeben
3. **PDI-Validierung**:
   - Erste 4 Bytes müssen `PDI\0` (Magic Bytes) sein
   - Header muss valide sein (Version, Tile-Größe)
   - Dateigröße muss plausibel sein (>0, <10MB)
4. **Sicherheit**: Keine Dateitypen, die Code enthalten könnten (.php, .exe, .sh, etc.)

**Fehlerbehandlung:**
- Ungültige Dateien → HTTP 400 "Ungültiger Dateityp"
- Dateien werden NUR gespeichert, wenn alle Validierungen bestehen
- Validierungs-Logs für Security-Audit

---

## API-Endpunkte (Übersicht)

| Endpunkt | Methode | Beschreibung | Auth |
|---|---|---|---|
| `/` | GET | Startseite mit UID-Eingabe | Nein |
| `/pair` | POST | UID + PIN verknüpfen | Nein |
| `/login` | POST | PIN für bestehende UID prüfen | Nein |
| `/upload` | POST | PDI + JSON hochladen | Ja (PIN) |
| `/images` | GET | Images-Liste für UID anzeigen | Ja (PIN) |
| `/download/pdi/{id}` | GET | PDI-Datei herunterladen | Ja (PIN) |
| `/download/json/{id}` | GET | JSON-Datei herunterladen | Ja (PIN) |
| `/download/png/{id}` | GET | PNG-Datei herunterladen | Ja (PIN) |

---

## Authentifizierungs-Flow

```
1. Nutzer gibt UID ein
2. Backend prüft: Existiert UID in DB?
   ├── Nein: → PIN-Vergabe (POST /pair)
   │   └── Speichere: uid, password_hash(pin)
   └── Ja: → PIN-Eingabe (POST /login)
       ├── PIN korrekt: → Session/Token
       ├── 3 Fehlversuche: → 5 Min Sperre
       └── PIN falsch: → Fehler + VersuchsZähler++
3. Bei geschützten Endpunkten: Prüfe Session/Token + UID-Berechtigung
```

---

## Upload-Flow mit Validierung

```
1. Nutzer sendet POST /upload mit:
   - UID (aus Session)
   - Datei 1 (PDI)
   - Datei 2 (JSON)
2. Backend validiert JEDE Datei:
   ├── Dateiendung == .pdi oder .json?
   ├── JSON: json_decode() erfolgreich?
   └── PDI: Magic Bytes PDI\0 + Header valide?
3. Bei Validierungsfehler: → HTTP 400, Datei wird NICHT gespeichert
4. Alle Validierungen OK:
   ├── Generiere UUID für Image
   ├── Speichere PDI unter uploads/{UID}/{uuid}.pdi
   ├── Speichere JSON unter uploads/{UID}/{uuid}.json
   ├── DB-Eintrag: id, uid, pdi_path, json_path
   └── Starte asynchrones PNG-Rendering
5. Rückgabe: Erfolg + Image-ID
```

---

## dependencies auf andere Specs

- **Spec 001 (PDI Storage Format)**: PDI- und JSON-Format, das validiert und gerendert werden muss
- **Spec 004 (Backend-Sync)**: Definiert Upload-Format und UID-Struktur vom Playdate
