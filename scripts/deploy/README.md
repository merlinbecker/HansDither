# Hans Dither Backend - Deployment

Dieses Verzeichnis enthält die Skripte und Konfigurationen für das Deployment des Hans Dither Backends auf all-inkl.com.

---

## 📁 Struktur

```
scripts/deploy/
├── deploy.sh          # Haupt-Deployment-Skript
├── .env.template      # Vorlage für Umgebungsvariablen
└── README.md          # Diese Datei
```

---

## ⚙️ Vorbereitung

### 1. `.env` Datei erstellen

1. Kopiere die Vorlage:
   ```bash
   cp .env.template .env
   ```

2. bearbeite `.env` mit deinen all-inkl.com Zugangsdaten:
   ```bash
   nano .env  # oder mit deinem bevorzugten Editor
   ```

3. Trage alle benötigten Werte ein (siehe `.env.template` für Erklärungen)

### 2. Skript ausführbar machen

```bash
chmod +x deploy.sh
```

---

## 🚀 Deployment Befehle

| Befehl | Beschreibung |
|--------|--------------|
| `./deploy.sh --dry-run` | **Simulation**: Zeigt was passieren würde, ohne etwas hochzuladen |
| `./deploy.sh --test` | **Lokale Tests**: Prüft PHP, MySQL, GD-Bibliothek, SFTP |
| `./deploy.sh --full` | **Vollständiges Deployment**: Upload + DB-Migration |
| `./deploy.sh --upload` | **Nur Upload**: Lädt Dateien hoch (ohne DB-Änderungen) |
| `./deploy.sh --migrate` | **Nur Migration**: Führt nur DB-Migrationen aus |

---

## 📋 Schritt-für-Schritt Anleitung

### 1. Erstes Deployment (all-inkl.com)

```bash
# 1. In das Verzeichnis wechseln
cd scripts/deploy

# 2. .env Datei erstellen und ausfüllen (siehe oben)
cp .env.template .env
nano .env

# 3. Dry-Run durchführen (SIMULATION - kein Upload!)
./deploy.sh --dry-run

# 4. Lokale Tests durchführen
./deploy.sh --test

# 5. Vollständiges Deployment (Upload + DB)
./deploy.sh --full
```

### 2. Nur Dateien aktualisieren (nach Code-Änderungen)

```bash
./deploy.sh --upload
```

### 3. Nur Datenbank migrieren (nach Schema-Änderungen)

```bash
./deploy.sh --migrate
```

---

## 📝 Was wird deployed?

Das Skript lädt folgende Verzeichnisse und Dateien hoch:

- `public/` - Alle öffentlichen Dateien (index.php, upload.php, etc.)
- `includes/` - PHP-Includes (config.php, database.php, etc.)
- `sql/migrations/` - Datenbank-Migrationen

---

## 🔒 Sicherheitshinweise

1. **`.env` NICHT einchecken!**
   - Die Datei `.env` enthält sensible Zugangsdaten
   - Sie steht in `.gitignore` und wird nicht versioniert
   - Nur `.env.template` wird im Repository gespeichert

2. **SFTP statt FTP**
   - Das Skript verwendet SFTP (Port 22) für sichere Übertragung
   - Falls dein Hosting nur FTP unterstützt, ändere in `.env`:
     ```
     SFTP_PORT=21
     ```

3. **Datenbank-Backup**
   - Führe vor dem Deployment ein Backup deiner Datenbank durch
   - all-inkl.com bietet phpMyAdmin für Backups an

---

## 🐛 Fehlerbehebung

### Häufige Probleme

#### 1. `❌ FEHLER: .env Datei nicht gefunden!`
**Lösung:** Erstelle die Datei wie in Schritt 1 beschrieben:
```bash
cp .env.template .env
```

#### 2. `❌ FEHLER: Folgende Variablen fehlen in .env: SFTP_HOST, SFTP_USER, ...`
**Lösung:** Öffne `.env` und trage alle Pflichtfelder ein. Keine Zeile sollte leer sein.

#### 3. `❌ PHP GD-Bibliothek: Nicht installiert`
**Lösung:** Installiere die GD-Bibliothek:
- **macOS (Homebrew):** `brew install php` (GD ist standardmäßig dabei)
- **Ubuntu/Debian:** `sudo apt-get install php-gd`
- **all-inkl.com:** GD ist standardmäßig aktiviert

#### 4. `❌ MySQL Verbindung: Verbindung fehlgeschlagen`
**Lösung:** Prüfe deine Datenbank-Zugangsdaten in `.env`:
- Hostname (z.B. `mysql123.all-inkl.com`)
- Benutzername (z.B. `u123456_1`)
- Passwort
- Port (standardmäßig `3306`)

#### 5. `❌ SFTP Client: Nicht installiert`
**Lösung:** Installiere OpenSSH:
- **macOS:** Vorinstalliert
- **Ubuntu/Debian:** `sudo apt-get install openssh-client`
- **Windows:** Verwende WSL oder Git Bash

---

## 📞 Support

Falls Probleme auftreten:

1. Prüfe die Ausgaben des Skripts genau
2. Führe zuerst `--dry-run` und `--test` aus
3. Vergleiche deine `.env` mit `.env.template`
4. Stelle sicher, dass alle Dateien in `public/`, `includes/` und `sql/migrations/` existieren

---

## 📄 Lizenz

Dieses Skript ist Teil des Hans Dither Projekts und unterliegt der gleichen Lizenz.
