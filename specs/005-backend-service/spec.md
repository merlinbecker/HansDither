# Feature Specification: Backend-Service für Hans Dither Sync

**Feature Branch**: `feature/0.3`

**Created**: 2026-07-12

**Status**: Complete

**Input**: User description: "Backend-Service auf PHP/MySQL-Basis für all-inkl.com Hosting. Nutzer besucht www.hans-dither.de, gibt Playdate-UID ein, vergibt oder bestätigt 4-stellige PIN, und erhält Zugriff auf seine hochgeladenen Images (PDI/JSON/PNG). Architektur: Minimalistisch (<15 Dateien, keine externen Frameworks, reine PHP-Standardbibliothek) mit HTML/CSS/JS Frontend, PHP für PIN-Verwaltung und Dateispeicherung, MySQL für UID→PIN-Mapping."

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Backend-Verknüpfung herstellen (Priority: P1)

Als Nutzer möchte ich mein Playdate-Gerät mit dem Backend verknüpfen, um später meine Zeichnungen hochladen zu können. Ich besuche www.hans-dither.de, gebe meine Playdate-UID ein. Da noch keine PIN für diese UID existiert, werde ich zur PIN-Vergabe aufgefordert. Ich gebe eine 4-stellige PIN ein und bestätige. Das Backend speichert die Verknüpfung UID ↔ PIN-Hash.

**Why this priority**: Ohne Verknüpfung kann kein Playdate Uploads durchführen. Dies ist die Grundlage für den Sync-Workflow.

**Independent Test**: Benötigt nur Browser und Internetzugang. Kann mit manueller UID-Eingabe getestet werden.

**Acceptance Scenarios**:

1. **Given** Nutzer besucht www.hans-dither.de, **When** Seite lädt, **Then** wird eine Startseite mit Erklärung und UID-Eingabefeld angezeigt.
2. **Given** Nutzer gibt unbekannte UID ein, **When** Formular abgeschickt wird, **Then** wird zur PIN-Vergabe aufgefordert.
3. **Given** Nutzer gibt 4-stellige PIN ein (z. B. "1234"), **When** Bestätigung, **Then** wird die PIN als PIN-Hash und mit der UID in der Datenbank gespeichert.
4. **Given** Verknüpfung erfolgreich, **When** Nutzer die Seite neu lädt, **Then** wird "Verknüpfung erfolgreich" angezeigt.

---

### User Story 2 - Mit bestehender Verknüpfung zugreifen (Priority: P1)

Als Nutzer möchte ich auf meine bereits verknüpften Images zugreifen. Ich besuche www.hans-dither.de, gebe meine UID ein und werde zur PIN-Eingabe aufgefordert. Nach korrekter PIN-Eingabe sehe ich meine hochgeladenen Images.

**Why this priority**: Ohne Zugriff können Nutzer ihre Daten nicht verwalten.

**Independent Test**: Setzt US1 voraus (UID muss verknüpft sein).

**Acceptance Scenarios**:

1. **Given** Nutzer gibt bekannte UID ein, **When** Formular abgeschickt wird, **Then** wird zur PIN-Eingabe aufgefordert.
2. **Given** Nutzer gibt korrekte PIN ein, **When** Bestätigung, **Then** wird die Images-Liste für diese UID angezeigt.
3. **Given** Nutzer gibt falsche PIN ein (3 Versuche), **When** 4. Versuch, **Then** wird "Zu viele Fehlversuche — bitte in 5 Minuten erneut versuchen" angezeigt.

---

### User Story 3 - Images anzeigen und herunterladen (Priority: P2)

Als Nutzer möchte ich meine hochgeladenen Images in einer Liste sehen und als PDI, JSON oder PNG herunterladen. Nach erfolgreichem Login (UID + PIN) sehe ich alle zu meiner UID gehörenden Images mit Vorschaubildern. Ich kann einzelne Dateien oder das gerenderte PNG herunterladen.

**Why this priority**: Der Hauptnutzen des Backends — ohne Anzeige/Download hat der Upload keinen Wert.

**Independent Test**: Backend-UI kann unabhängig vom Playdate getestet werden (manuelle Dateien hochladen).

**Acceptance Scenarios**:

1. **Given** Nutzer erfolgreich eingeloggt, **When** Seite lädt, **Then** werden alle Images dieser UID als Liste mit Vorschaubild (PNG) angezeigt.
2. **Given** Image in Liste ausgewählt, **When** Nutzer "PDI herunterladen" klickt, **Then** wird die PDI-Datei zum Download angeboten.
3. **Given** Image in Liste ausgewählt, **When** Nutzer "JSON herunterladen" klickt, **Then** wird die frames.json-Datei zum Download angeboten.
4. **Given** Image in Liste ausgewählt, **When** Nutzer "PNG herunterladen" klickt, **Then** wird das PNG (400×240) zum Download angeboten.
5. **Given** Keine Images für UID vorhanden, **When** Seite lädt, **Then** wird "Keine Images hochgeladen" angezeigt.

---

### Edge Cases

- Was passiert, wenn die UID nicht existiert? → "UID nicht gefunden. Möchten Sie eine neue Verknüpfung herstellen?"
- Was passiert bei leerer UID-Eingabe? → Fehlermeldung "UID darf nicht leer sein"
- Was passiert bei nicht-numerischer PIN (z. B. "abcd")? → Fehlermeldung "PIN muss 4 Ziffern enthalten"
- Was passiert bei PIN mit weniger/mehr als 4 Ziffern? → Fehlermeldung "PIN muss genau 4 Ziffern haben"
- Was passiert, wenn die Datenbank nicht erreichbar ist? → "Datenbankfehler — bitte später erneut versuchen"
- Was passiert, wenn der Nutzer die PIN vergessen hat? → Nutzer kann eine komplett neue Verknüpfung vornehmen (neue UID-Eingabe → neue PIN vergeben; alte Daten bleiben erhalten, sind aber ohne die PIN unzugänglich).
- Was passiert, wenn eine ungültige Datei hochgeladen wird (z. B. .exe, .php, oder beschädigte PDI/JSON)? → Backend lehnt Upload ab mit Fehler "Ungültiger Dateityp" und speichert die Datei nicht.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Das Backend MUSS unter `www.hans-dither.de` erreichbar sein.
- **FR-002**: Die Startseite MUSS ein Eingabefeld für die Playdate-UID enthalten.
- **FR-003**: Bei unbekannter UID MUSS das Backend zur PIN-Vergabe auffordern.
- **FR-004**: Die PIN MUSS genau 4 numerische Ziffern (0000-9999) sein.
- **FR-005**: Die PIN MUSS serverseitig als **PIN-Hash** (nicht Klartext) in der Datenbank gespeichert werden.
- **FR-006**: Bei bekannter UID MUSS das Backend zur PIN-Eingabe auffordern.
- **FR-007**: Nach 3 falschen PIN-Versuchen MUSS der Zugriff für diese UID für 5 Minuten gesperrt werden.
- **FR-008**: Nach erfolgreicher PIN-Eingabe MUSS das Backend die Images-Liste für diese UID anzeigen.
- **FR-009**: Das Backend MUSS hochgeladene PDI- und JSON-Dateien unter `/{UID}/` speichern.
- **FR-010**: Das Backend MUSS in der Lage sein, aus PDI + frames.json ein PNG (400×240, 1-Bit, Frame 1) zu rendern (Implementierungsdetails siehe research.md R3).
- **FR-011**: Das Backend-UI MUSS für jedes Image separate Download-Links für PDI, JSON, PNG und GIF anbieten.
- **FR-012**: Das Backend MUSS die UID → PIN-Hash Zuordnung in einer MySQL-Datenbank speichern.
- **FR-013**: Das Backend MUSS hochgeladene Dateien validieren: Dateiendung (`.pdi`, `.json`) + Inhaltsprüfung (JSON: `json_decode()` erfolgreich; PDI: Magic `Playdate IMG` + parsebare Bilddaten im Playdate-SDK-Format gemäß Spec 001, wie von `playdate.datastore.writeImage()` geschrieben). Ungültige Dateien MÜSSEN abgelehnt werden.
- **FR-014**: Das Backend MUSS aus PDI + frames.json ein animiertes GIF (400×240, Endlos-Loop) rendern können, bei dem jeder Tilemap-Frame als eigener GIF-Frame erscheint.

### Key Entities

- **Playdate UID**: Eindeutige Geräte-Kennung (String, z. B. "pd-abc123def456"). Wird vom Playdate SDK generiert.
- **PIN**: 4-stellige numerische Authentifizierung (0000-9999). Wird als PIN-Hash (bcrypt) gespeichert.
- **Image**: Hans Dither Projekt, bestehend aus PDI-Datei (Imagetable) + frames.json (Frame-Daten).
- **Rendered PNG**: Serverseitig generiertes Bild (400×240 Pixel, 1-Bit, Frame 1) aus PDI + frames.json.
- **Rendered GIF**: Serverseitig generiertes animiertes GIF (400×240 Pixel, Endlos-Loop); jeder Tilemap-Frame aus frames.json wird ein GIF-Frame.
- **Backend Database**: MySQL-Tabelle mit Spalten: `uid` (VARCHAR, PRIMARY KEY), `pin_hash` (VARCHAR), `created_at` (DATETIME).
- **File Storage**: Dateisystem-Speicher für PDI- und JSON-Dateien, organisiert nach `/{UID}/[image-id].pdi` und `/{UID}/[image-id].json`.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Die Verknüpfung (UID + PIN) kann in unter 30 Sekunden abgeschlossen werden.
- **SC-002**: Hochgeladene Images sind innerhalb von 5 Sekunden in der Liste sichtbar.
- **SC-003**: Das gerenderte PNG ist pixelgenau identisch mit der Playdate-Darstellung (400×240, 1-Bit) – 0 Pixel Abweichung, verifiziert durch MD5-Hash-Vergleich.
- **SC-004**: 100% aller erfolgreich hochgeladenen Images sind im Backend-UI abrufbar und herunterladbar.
- **SC-005**: Die PIN-Eingabe lehnt 100% aller nicht-numerischen oder nicht-4-stelligen Eingaben ab.

---

## Clarifications

### Session 2026-07-12

- Q: Reicht eine 4-stellige PIN mit 5-Minuten-Sperre als Schutz aus, oder sind zusätzliche Maßnahmen nötig? → A: 4-stellige PIN mit 5-Minuten-Sperre nach 3 Fehlversuchen reicht als Schutz aus. Bei vergessener PIN kann der Nutzer einfach eine komplett neue Verknüpfung vornehmen.
- Q: Wie soll das Backend sicherstellen, dass nur gültige PDI- und JSON-Dateien hochgeladen werden? → A: Dateiendung + Inhaltsprüfung: JSON muss mit `json_decode()` valide sein, PDI muss ein gültiges Playdate-SDK-Image sein (Magic + parsebare Bilddaten).

### Session 2026-07-18

- Q: Welches PDI-Format lädt das Playdate hoch? → A: Das echte SDK-Format (`playdate.datastore.writeImage()`, Magic `Playdate IMG`, optional zlib-komprimiert) gemäß Spec 001 — nicht das ursprünglich spezifizierte `PDI\0`-Kunstformat. FR-013 entsprechend korrigiert; Referenz: cranksters/playdate-reverse-engineering `pdi2png.py`.
- Q: Braucht es neben PNG weitere Render-Ausgaben? → A: Ja, ein animiertes GIF: jeder Tilemap-Frame aus frames.json wird als GIF-Frame gerendert (FR-014). PNG bleibt Frame-1-Standbild.
- Q: Wird die Server-Überlast-Prüfung benötigt? → A: Nein, entfernt (siehe T045).
- Q: Wie wird deployt und die DB provisioniert? → A: Vollautomatisch via SSH (rsync-Upload + mysql auf dem Server, all-inkl.com-Tarif mit SSH vorhanden); FTPS/lftp nur als Fallback ohne SSH.

## Assumptions

- **Hosting**: all-inkl.com Account mit PHP 8.x und MySQL 8.x Unterstützung.
- **Domain**: www.hans-dither.de ist verfügbar und auf den all-inkl.com Account konfiguriert.
- **Technologie-Stack**: Frontend = HTML5 + CSS3 + Vanilla JavaScript (keine Frameworks). Backend = PHP 8.x. Datenbank = MySQL.
- **PIN-Speicherung**: PIN wird mit `password_hash()` (PHP) gehasht und als bcrypt-Hash gespeichert.
- **Dateisystem**: all-inkl.com erlaubt Datei-Uploads und Verzeichnisstruktur unter `/{UID}/`.
- **HTTPS**: all-inkl.com stellt SSL-Zertifikat für www.hans-dither.de bereit.
- **CORS**: CORS ist für Anfragen vom Playdate-Simulator (lokal: `http://localhost:8000` etc.) konfiguriert.
- **Fehlerbehandlung**: Alle Datenbank- und Dateisystem-Fehler werden nutzerfreundlich angezeigt.
- **Sicherheit**: 4-stellige PIN mit 5-Minuten-Sperre nach 3 Fehlversuchen reicht als Schutz aus. Bei vergessener PIN kann der Nutzer einfach eine komplett neue Verknüpfung vornehmen. Sicherheits-Review-Checkliste siehe research.md R7.
- **Dateivalidierung**: Hochgeladene Dateien werden via Dateiendung + Inhaltsprüfung validiert (JSON: `json_decode()`; PDI: Playdate-SDK-Format mit Magic `Playdate IMG` + parsebaren Bilddaten). Ungültige Dateien werden abgelehnt und nicht gespeichert.

---

## Dependencies

- **all-inkl.com Account**: PHP/MySQL Hosting mit ausreichend Speicherplatz für PDI/JSON-Dateien.
- **Domain www.hans-dither.de**: Muss auf den all-inkl.com Account zeigen.
- **Playdate Sync Spec (004)**: Definiert das Upload-Format (PDI + frames.json) und die UID-Struktur.
- **Spec 001 (PDI Storage Format)**: PDI- und JSON-Format, das vom Backend verarbeitet werden muss.

---

## Architecture Governance (iSAQB-Preset)

- **Betroffene Architekturaspekte**: Bausteinsicht (PHP-Backend, MySQL-DB, Dateisystem-Storage, Web-Frontend), Laufzeitsicht (Request-Flow: UID→PIN→Images), Querschnittskonzepte (Authentifizierung via PIN, Dateispeicherung).
- **Erwartete Evidenz**: Dokumentation der PHP-Struktur, MySQL-Schema, Dateisystem-Organisation.
- **ADR erforderlich**: Ja — Entscheidung für PHP/MySQL auf all-inkl.com (AD-025), PIN-Hashing-Strategie (AD-026).
- **Sicherheitsrelevante Architektur**: Ja — Authentifizierung (PIN), Datenspeicherung (Hashing), Dateizugriff (UID-basierte Isolation). Sicherheits-Review vor Deployment erforderlich.
- **Risiken**: Brute-Force-Angriffe auf 4-stellige PIN (10.000 Kombinationen), Speicherwachstum durch viele PDI-Dateien, all-inkl.com Performance-Limits.
