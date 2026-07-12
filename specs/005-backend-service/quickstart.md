# Quickstart: Validierung Backend-Service

**Feature**: 005-backend-service | **Purpose**: End-to-End-Validierung des Backend-Service für Hans Dither Sync

---

## Vorbereitung

### Voraussetzungen
- [ ] all-inkl.com Account mit PHP 8.x und MySQL 8.x
- [ ] Domain www.hans-dither.de auf Account konfiguriert
- [ ] MySQL-Datenbank angelegt (Benutzer + Passwort)
- [ ] PHP GD-Bibliothek aktiviert (für PNG-Rendering)

### Deployment
1. Alle PHP-Dateien (`index.php`, `upload.php`, `render.php`, `config.php`, `includes/*`) auf all-inkl.com hochladen
2. CSS/JS-Dateien (`assets/*`) hochladen
3. MySQL-Schema aus research.md R6 erstellen
4. `config.php` mit DB-Zugangsdaten konfigurieren
5. CORS-Header für Playdate-Simulator konfigurieren

### Testdaten
- Test-PDI-Dateien aus Spec 001 (z. B. `tests/fixtures/simple.pdi`)
- Test-JSON-Dateien (z. B. `tests/fixtures/simple.json`)
- Test-UID: `test-device-001`
- Test-PIN: `1234`

---

## Validierungsszenarien

### Szenario 1: Backend-Verfügbarkeit (P0)
**Ziel**: Backend ist erreichbar und reagiert

**Schritte**:
1. Browser öffnen
2. `https://www.hans-dither.de/` aufrufen
3. Startseite mit UID-Eingabefeld wird angezeigt

**Erwartet**: HTTP 200, HTML-Seite mit Formular

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 2: Neue Verknüpfung herstellen (US1)
**Ziel**: UID mit PIN verknüpfen

**Schritte**:
1. Startseite aufrufen
2. UID eingeben: `test-device-001`
3. Auf "Weiter" klicken
4. PIN eingeben: `1234`
5. Auf "Bestätigen" klicken

**Erwartet**: Erfolgsmeldung "Verknüpfung erfolgreich hergestellt"

**Prüfungen**:
- [ ] UID in DB gespeichert
- [ ] PIN als Hash (nicht Klartext) gespeichert
- [ ] Session-Token generiert

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 3: Login mit bestehender Verknüpfung (US2)
**Ziel**: Mit UID + PIN einloggen

**Voraussetzung**: Szenario 2 erfolgreich

**Schritte**:
1. Startseite aufrufen
2. UID eingeben: `test-device-001`
3. Auf "Weiter" klicken
4. PIN eingeben: `1234`
5. Auf "Login" klicken

**Erwartet**: Images-Liste wird angezeigt (leer, da keine Images hochgeladen)

**Prüfungen**:
- [ ] Session-Token erhalten
- [ ] Token in DB gespeichert

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 4: Falsche PIN (US2 Edge Case)
**Ziel**: Rate Limiting funktioniert

**Voraussetzung**: Szenario 2 erfolgreich

**Schritte**:
1. Startseite aufrufen
2. UID eingeben: `test-device-001`
3. PIN eingeben: `0000` (falsch)
4. Auf "Login" klicken
5. Schritte 3-4 wiederholen mit `1111`, `2222`
6. PIN eingeben: `3333` (4. Versuch)

**Erwartet**: Nach 3 Fehlversuchen: "Zu viele Fehlversuche. Bitte in 5 Minuten erneut versuchen"

**Prüfungen**:
- [ ] `failed_attempts = 3` in DB
- [ ] `locked_until` gesetzt (5 Minuten in Zukunft)

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 5: Image Upload (US2 + FR-013)
**Ziel**: PDI + JSON hochladen und validieren

**Voraussetzung**: Szenario 3 erfolgreich ( eingeloggt)

**Schritte**:
1. Test-PDI-Datei (`simple.pdi`) auswählen
2. Test-JSON-Datei (`simple.json`) auswählen
3. Upload-Formular absenden

**Erwartet**: Erfolgsmeldung "Upload erfolgreich. PNG wird generiert."

**Prüfungen**:
- [ ] Dateien unter `uploads/test-device-001/{uuid}.pdi` gespeichert
- [ ] Dateien unter `uploads/test-device-001/{uuid}.json` gespeichert
- [ ] DB-Eintrag in `images` Tabelle
- [ ] Dateivalidierung: PDI Magic Bytes + JSON json_decode() erfolgreich

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 6: Ungültige Datei Upload (FR-013)
**Ziel**: Schadcode/ungültige Dateien werden abgelehnt

**Voraussetzung**: Szenario 3 erfolgreich

**Testfälle**:
| Datei | Erwartetes Ergebnis |
|---|---|
| `malicious.php` | HTTP 400 "Ungültiger Dateityp" |
| `script.exe` | HTTP 400 "Ungültiger Dateityp" |
| `test.txt` | HTTP 400 "Ungültiger Dateityp" |
| `invalid.pdi` (keine Magic Bytes) | HTTP 400 "Ungültiger Dateityp" |
| `invalid.json` (kein valides JSON) | HTTP 400 "Ungültiger Dateityp" |

**Prüfungen**:
- [ ] Keine Dateien gespeichert
- [ ] Keine DB-Einträge erstellt
- [ ] Fehlerlogs enthalten Validierungsfehler

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 7: Images-Liste anzeigen (US3)
**Ziel**: Hochgeladene Images in UI anzeigen

**Voraussetzung**: Szenario 5 erfolgreich

**Schritte**:
1. Images-Seite aufrufen (nach Login)

**Erwartet**: Liste mit 1 Image-Eintrag

**Prüfungen**:
- [ ] Image-ID angezeigt
- [ ] Upload-Zeitpunkt angezeigt
- [ ] Download-Links für PDI/JSON/PNG verfügbar

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 8: Dateien herunterladen (US3)
**Ziel**: PDI, JSON und PNG herunterladen

**Voraussetzung**: Szenario 5 + 7 erfolgreich

**Schritte für jede Datei**:
1. Download-Link für PDI klicken
2. Download-Link für JSON klicken
3. Download-Link für PNG klicken

**Erwartet**:
- PDI: Datei mit `.pdi` Endung, korrekter Inhalt
- JSON: Datei mit `.json` Endung, valides JSON
- PNG: Bild mit 400×240 Pixel, 1-Bit

**Prüfungen**:
- [ ] PDI-Datei entspricht Original
- [ ] JSON-Datei entspricht Original
- [ ] PNG ist pixelgenau mit Spec 001 Darstellung

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 9: PNG-Rendering-Qualität (SC-003)
**Ziel**: PNG ist pixelgenau mit Playdate-Darstellung

**Voraussetzung**: Szenario 8 erfolgreich

**Schritte**:
1. Heruntergeladenes PNG öffnen
2. Mit Playdate-Simulator-Vorschaubild vergleichen
3. Pixel-für-Pixel-Vergleich durchführen (Tool: `compare -metric AE` aus ImageMagick)

**Erwartet**: 0 Pixel-Differenz

**Prüfungen**:
- [ ] Auflösung: 400×240
- [ ] Farbtiefe: 1-Bit (schwarz/weiß)
- [ ] Alle Pixel exakt gleich

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 10: Performance (SC-001, SC-002)
**Ziel**: Verknüpfung und Upload in definierter Zeit

**Schritte**:
1. Szenario 2 (Verknüpfung) durchführen und Zeit messen
2. Szenario 5 (Upload) durchführen und Zeit messen
3. Szenario 7 (Images-Liste) durchführen und Zeit messen

**Erwartet**:
- Verknüpfung: < 30 Sekunden (SC-001)
- Images-Liste: < 5 Sekunden (SC-002)

**Prüfungen**:
- [ ] Messungen unter typischer Last (1 Nutzer)
- [ ] Messungen unter hoher Last (10 simultane Nutzer) — falls möglich

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

## Security-Review

### Penetrationstests
- [ ] SQL Injection Versuch: `uid = ' OR '1'='1` → muss abgelehnt werden
- [ ] XSS Versuch: `<script>alert(1)</script>` in UID → muss escaped werden
- [ ] Datei-Upload mit PHP-Code → muss abgelehnt werden
- [ ] Zugriff auf fremde UID → muss abgelehnt werden
- [ ] Session-Token-Manipulation → muss abgelehnt werden

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

## Befunde und Notes

| Datum | Szenario | Status | Befund | Owner | Follow-up |
|---|---|---|---|---|---|
| 2026-07-12 | Alle | Offene | Initialer Validierungsplan | - | - |

---

## Abhängigkeiten

- Spec 001: PDI-Format für Testdateien
- Spec 004: Upload-Workflow vom Playdate
- all-inkl.com: Hosting-Infrastruktur
