# ADR-033: Race-Condition-sicherer Upload-Zähl-Check via Transaktion + Row-Lock

## Status
✅ **Umgesetzt** – `UploadHandler::handleUpload()` sperrt den `users`-Datensatz der UID vor dem Zähl-Check

## Kontext
Spec 007 verlangt eine harte Obergrenze von 12 unterschiedlichen Bildern pro
Gerät (UID) sowie explizit, dass gleichzeitige (parallele) Upload-Anfragen
derselben UID diese Grenze nicht überschreiten dürfen (FR-001, FR-011). Ein
einfacher `COUNT(*)`-Check gefolgt von einem separaten `INSERT` ist NICHT
race-sicher: zwei nahezu gleichzeitige Requests könnten beide denselben
Zählerstand (z. B. 11) lesen und beide erfolgreich einfügen, wodurch 13
Bilder entstünden.

## Entscheidungs-Treiber
- **Korrektheit unter Nebenläufigkeit:** Das Limit muss auch bei parallelen
  Requests derselben UID exakt eingehalten werden (FR-011).
- **Einfachheit (Constitution IV):** Keine neue Tabelle, kein neues Feld,
  keine externe Locking-Bibliothek.
- **Shared-Hosting-Realität:** all-inkl.com betreibt PHP potenziell über
  mehrere Worker-Prozesse — anwendungsseitiges Locking (z. B. `flock()`)
  funktioniert dort nicht zuverlässig über Prozessgrenzen hinweg.

## Optionen

| Option | Vorteile | Nachteile |
|--------|----------|-----------|
| **A: Transaktion + `SELECT ... FOR UPDATE` auf `users`** | Korrekt über Prozessgrenzen hinweg (MySQL-Row-Lock), kein Schema-Wechsel, nutzt einen ohnehin garantiert existierenden Datensatz | Verlängert die Sperrzeit des `users`-Datensatzes geringfügig |
| B: Neues `image_count`-Zählerfeld in `users` | Schneller Lesezugriff | Muss bei jedem künftigen Lösch-/Bereinigungspfad synchron gehalten werden — zusätzliche Fehlerquelle, aktuell existiert noch keine Löschfunktion |
| C: Anwendungsseitiges Locking (PHP `flock()`) | Kein DB-Feature nötig | Auf Shared Hosting mit mehreren PHP-Worker-Prozessen unzuverlässig |
| D: `SELECT ... FOR UPDATE` gegen `images` (Dummy-Zeile) | Naheliegend, da `images` die gezählte Tabelle ist | Kein Zeilenziel für UIDs ohne bisherige Uploads (0 Zeilen) |

## Entscheidung
**Option A: Transaktion + `SELECT uid FROM users WHERE uid = ? FOR UPDATE`**

### Begründung
1. **Natürlicher Mutex:** Der `users`-Datensatz existiert für jede gepairte
   UID bereits (angelegt beim Pairing, Spec 005) und wird sonst nirgends
   exklusiv gesperrt — er dient hier ausschließlich als Sperr-Ziel, ohne
   dass sein Inhalt verändert wird.
2. **Serialisierung statt Locking-Bibliothek:** MySQL serialisiert
   konkurrierende Transaktionen auf denselben gesperrten Datensatz über
   Prozess-/Worker-Grenzen hinweg korrekt — kein zusätzliches System nötig.
3. **Kein Synchronisationsrisiko:** `COUNT(*) FROM images WHERE uid = ?`
   innerhalb der Transaktion ist immer exakt korrekt, im Gegensatz zu einem
   separat gepflegten Zählerfeld.

### Ablauf (`UploadHandler::handleUpload()`)
```sql
START TRANSACTION;
SELECT uid FROM users WHERE uid = ? FOR UPDATE;   -- Lock, Ergebnis ungenutzt
-- nur falls Neuanlage (client_image_id unbekannt):
SELECT COUNT(*) FROM images WHERE uid = ?;
-- >= 12 -> ROLLBACK, 403 Forbidden
-- < 12  -> Datei-Schreibvorgänge + INSERT/UPDATE wie bisher, dann COMMIT
```

Validierung (PDI-/JSON-Struktur, Dateigröße) und Verzeichnis-Anlage laufen
bewusst VOR der Transaktion, damit der Row-Lock nicht länger als nötig
gehalten wird — nur der eigentliche Zähl-Check und die Datei-/DB-Schreib-
vorgänge liegen innerhalb der Sperre.

### Konsequenzen
- **Positiv:**
  - Limit ist unter Nebenläufigkeit garantiert korrekt (FR-011).
  - Kein neues Schema-Element, kein Synchronisationsrisiko.
  - `Database` erhält drei generische, wiederverwendbare Methoden
    (`beginTransaction()`/`commit()`/`rollback()`).
- **Negativ:**
  - Der `users`-Datensatz der UID ist während `move_uploaded_file()` +
    DB-Schreibvorgang kurzzeitig gesperrt — bei mehreren GLEICHZEITIGEN
    Uploads DERSELBEN UID (untypisch, ein Gerät lädt normalerweise
    sequenziell hoch) kann das zu kurzen Wartezeiten führen. Als
    Beobachtungspunkt in `arc42/11-risiken-und-technische-schulden.md`
    vermerkt, unkritisch bei erwarteter Nutzungsfrequenz.

## Alternativen Considered
Siehe Options-Tabelle oben (B/C/D) — vollständige Herleitung in
`specs/007-backend-upload-hardening/research.md` R1.

## Related
- [ADR-027: Dateivalidierung](ADR-027-Dateivalidierung.md)
- [specs/007-backend-upload-hardening/research.md: R1](../../specs/007-backend-upload-hardening/research.md)
- [specs/007-backend-upload-hardening/data-model.md: Abschnitt 1](../../specs/007-backend-upload-hardening/data-model.md)
- [specs/007-backend-upload-hardening/contracts/upload-hardening.md](../../specs/007-backend-upload-hardening/contracts/upload-hardening.md)
