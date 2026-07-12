# Research: Backend-Service für Hans Dither Sync

**Feature**: 005-backend-service | **Date**: 2026-07-12

Alle Unbekannten auf Basis der Spec und Constitution gelöst. Fokus auf PHP/MySQL-Best-Practices für all-inkl.com Hosting, PDI-Format-Validierung und sicheres PNG-Rendering.

---

## R1: PHP/MySQL-Best-Practices für all-inkl.com

- **Decision**: Verwendung von PHP 8.x Native Funktionen ohne externe Frameworks (Composer nicht verfügbar auf Shared Hosting).
- **Rationale**: all-inkl.com unterstützt PHP 8.x nativ; externe Abhängigkeiten wären komplex zu deployen. Reine PHP-Standardbibliothek reicht für die Anforderungen (Datei-Handling, JSON, MySQLi).
- **Alternatives considered**:
  - Laravel/Symfony (verworfen: erfordert Composer, zu schwer für Shared Hosting)
  - WordPress-Plugin (verworfen: Overhead, unnötige Komplexität)
  - Node.js (verworfen: all-inkl.com unterstützt Node.js nicht auf Shared Hosting)
- **Evidenz**: all-inkl.com Dokumentation bestätigt PHP 8.x und MySQL 8.x Unterstützung.

---

## R2: Dateivalidierung — Nur .pdi und .json erlauben

- **Decision**: Zwei-Stufen-Validierung: 1) Dateiendung (`.pdi`, `.json`) + 2) Inhaltsprüfung via Magic Bytes + Strukturprüfung.
- **Rationale**: Dateiendung allein ist unsicher (Angreifer kann Schadcode als `.pdi` hochladen). Inhaltsprüfung blockiert die meisten Missbrauchsfälle.
- **Implementierung**:
  - **JSON**: `json_decode($content)` muss erfolgreich sein und ein Objekt/Array zurückgeben
  - **PDI**: Erste 4 Bytes müssen `PDI\0` (Magic Bytes) sein; zusätzlich Header-Struktur prüfen (Version, Tile-Größe)
  - **Reject**: Alle anderen Dateitypen werden mit HTTP 400 abgelehnt
- **Alternatives considered**:
  - Nur Dateiendung (verworfen: unsicher)
  - MIME-Type prüfen (verworfen: kann vom Client gefälscht werden)
  - Datei in Sandbox ausführen (verworfen: nicht auf Shared Hosting möglich)
- **Sicherheitshinweis**: Auch validierte Dateien werden unter UID-spezifischen Pfaden gespeichert, um Zugriff durch andere Nutzer zu verhindern.

---

## R3: PNG-Rendering aus PDI + frames.json

- **Decision**: Serverseitiges Rendern via PHP GD-Bibliothek oder Imagick-Erweiterung.
- **Rationale**: PDI ist ein Playdate-spezifisches Binärformat; es gibt keine native PHP-Unterstützung. Zwei Optionen:
  - **Option A: GD-Bibliothek** (empfohlen): Standardmäßig auf all-inkl.com verfügbar. PDI muss manuell geparsed werden (Tile-IDs → Pixel-Daten), dann mit `imagecreate()` ein 400×240 1-Bit Bild erzeugen.
  - **Option B: Imagick** (alternativ): Bietet mehr Bildformate, aber möglicherweise nicht auf allen Shared-Hosting-Paketen verfügbar.
- **PDI-Format** (aus Spec 001):
  - Header: Magic Bytes `PDI\0`, Version (4 Bytes), Tile-Größe (z. B. 16×16), Anzahl Tiles
  - Tile-Daten: Sequenz von RGBA8888-Pixels pro Tile
  - Imagetable: Referenziert Tiles via Index
- **Rendering-Algorithmus**:
  1. PDI-Header parsen (Version, Tile-Größe)
  2. Tile-Daten extrahieren
  3. frames.json laden (25×15 Grid mit Tile-Indizes)
  4. Für jeden Grid-Eintrag: corresponding Tile-Pixel in 400×240 Bild setzen
  5. Als PNG exportieren (1-Bit Farbtiefe für Authentizität)
- **Alternatives considered**:
  - Client-seitiges Rendern (verworfen: Nutzer möchte serverseitiges PNG)
  - Externer Rendering-Service (verworfen: zusätzliche Komplexität und Kosten)
- **Evidenz**: GD-Bibliothek ist auf all-inkl.com PHP 8.x standardmäßig aktiviert.

---

## R4: PIN-Authentifizierung und Rate Limiting

- **Decision**: 4-stellige PIN mit bcrypt-Hashing + 5-Minuten-Sperre nach 3 Fehlversuchen pro UID.
- **Rationale**: 
  - bcrypt ist in PHP 8.x nativ verfügbar (`password_hash()`, `password_verify()`)
  - 5-Minuten-Sperre reduziert Brute-Force-Risiko ohne Nutzer zu blockieren
  - PIN wird NUR gehasht gespeichert (nie Klartext)
- **Implementierung**:
  - MySQL-Tabelle: `users(uid VARCHAR PRIMARY KEY, pin_hash VARCHAR, failed_attempts INT, locked_until DATETIME)`
  - Bei Fehlversuch: `failed_attempts++`; bei 3: `locked_until = NOW() + INTERVAL 5 MINUTE`
  - Bei Login: Prüfe `locked_until < NOW()` und `password_verify($input, $pin_hash)`
- **Alternatives considered**:
  - 6-stellige PIN (verworfen: NutzerUsability leidet)
  - IP-basiertes Rate Limiting (verworfen: Shared Hosting, Nutzer hinter NAT teilen IP)
  - 2FA (verworfen: zu komplex für Use Case)
- **Sicherheitsbewertung**: 10.000 Kombinationen pro UID; mit 5-Min-Sperre sind ~166 Versuche/Stunde möglich. Für private Nutzung akzeptabel.

---

## R5: Dateisystem-Organisation und Berechtigungen

- **Decision**: Hierarchische Struktur `uploads/{UID}/{image-id}.pdi` + `{image-id}.json`.
- **Rationale**:
  - UID als oberstes Verzeichnis ermöglicht einfache Berechtigungsprüfung (Nutzer darf nur auf eigenes UID-Verzeichnis zugreifen)
  - Keine zusätzlichen Berechtigungsbits nötig (all-inkl.com Shared Hosting hat keine Unix-Berechtigungen)
  - Image-ID als UUID oder timestamp-basierter Hash für eindeutige Dateinamen
- **Sicherheitsmaßnahmen**:
  - Alle Uploads werden via PHP-Code durchgeführt (nie direkter Dateizugriff)
  - Dateinamen werden serverseitig generiert (kein Nutzer-Input)
  - Dateityp-Validierung vor dem Speichern (siehe R2)
- **Alternatives considered**:
  - Flache Struktur mit UID-Präfix (verworfen: schwerer zu verwalten)
  - Datenbank-BLOB-Speicherung (verworfen: Performance-Nachteile für große PDI-Dateien)

---

## R6: MySQL-Schema-Design

- **Decision**: Minimales Schema mit einer Tabelle für Nutzer und einer für Images.
- **Rationale**: Einfache Struktur, performant für die erwartete Last (max. 1000 Images/UID).
- **Tabellen**:
  ```sql
  CREATE TABLE users (
      uid VARCHAR(64) PRIMARY KEY,
      pin_hash VARCHAR(255) NOT NULL,
      failed_attempts INT DEFAULT 0,
      locked_until DATETIME NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );
  
  CREATE TABLE images (
      id VARCHAR(36) PRIMARY KEY,  -- UUID
      uid VARCHAR(64) NOT NULL,
      pdi_path VARCHAR(255) NOT NULL,
      json_path VARCHAR(255) NOT NULL,
      png_path VARCHAR(255) NULL,   -- NULL wenn noch nicht gerendert
      uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (uid) REFERENCES users(uid) ON DELETE CASCADE
  );
  ```
- **Alternatives considered**:
  - Single Table (verworfen: Normalformverletzung)
  - NoSQL (verworfen: MySQL ist auf all-inkl.com verfügbar und ausreichend)

---

## R7: Security-Review-Checkliste

Vor Deployment müssen folgende Punkte verifiziert werden:
- [ ] Nur `.pdi` und `.json` Dateien werden akzeptiert
- [ ] Datei-Inhaltsvalidierung ist aktiv (JSON: json_decode, PDI: Magic Bytes)
- [ ] Keine PHP/EXE/Script-Dateien können hochgeladen werden
- [ ] Dateizugriff ist auf UID beschränkt (Nutzer A kann nicht auf Dateien von Nutzer B zugreifen)
- [ ] PIN wird als bcrypt-Hash gespeichert
- [ ] Rate Limiting (3 Versuche + 5 Min Sperre) ist implementiert
- [ ] SQL Injection Schutz: Prepared Statements für alle DB-Abfragen
- [ ] XSS Schutz: HTML-Escape für alle Nutzer-Eingaben (UID, Fehlermeldungen)
- [ ] CORS ist korrekt konfiguriert für Playdate-Simulator
- [ ] HTTPS ist erzwungen (all-inkl.com SSL-Zertifikat)

---

## Offene Punkte

- **PDI-Parser**: Serverseitige Implementierung des PDI-Formats (Spec 001) für PNG-Rendering. Owner: Projektinhaber. Follow-up: research.md R3. Re-Evaluation: vor Deployment mit Test-PDI-Dateien.
- **PNG-Rendering-Qualität**: Verifizieren, dass gerenderte PNGs pixelgenau mit Playdate-Darstellung übereinstimmen (400×240, 1-Bit). Owner: Projektinhaber. Follow-up: quickstart.md Szenario.
