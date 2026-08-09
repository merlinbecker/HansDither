#!/bin/bash
set -euo pipefail

# =============================================================================
# Hans Dither Backend - Deployment Skript für all-inkl.com
# Wird aus backend/ Verzeichnis ausgeführt
#
# Sicherheitsgarantien:
#   - Secrets (.deploy.env*) und dieses Skript werden NIE hochgeladen
#   - Übertragung nur via FTPS (TLS erzwungen)
#   - includes/, storage/, logs/, uploads/ und Dotfiles sind per .htaccess
#     nicht öffentlich abrufbar
#   - Nach dem Upload verifiziert ein Check, dass Secret-Pfade 403/404 liefern
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Gehe ins backend-Verzeichnis (Skript liegt in backend/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${BLUE}📍 Working directory: $SCRIPT_DIR${NC}"

if [ ! -f ".deploy.env" ]; then
    echo -e "${RED}❌ FEHLER: .deploy.env nicht gefunden!${NC}"
    echo "Erstelle: cp .deploy.env.example .deploy.env"
    exit 1
fi

# Rechte der Secret-Datei absichern
chmod 600 .deploy.env

source .deploy.env

# Pflichtvariablen prüfen
for var in SFTP_HOST SFTP_USER SFTP_PASS DB_HOST DB_USER DB_PASS DB_NAME REMOTE_ROOT; do
    if [ -z "${!var:-}" ]; then
        echo -e "${RED}❌ FEHLER: $var ist in .deploy.env nicht gesetzt!${NC}"
        exit 1
    fi
done
SFTP_PORT="${SFTP_PORT:-21}"
DB_PORT="${DB_PORT:-3306}"
BASE_URL="${BASE_URL:-https://www.hans-dither.de}"

# all-inkl.com: Je nach Hosting kann der SSH-Startordner "/" sein.
# Deshalb REMOTE_ROOT idealerweise als absoluten Webroot angeben
# (z. B. /www/htdocs/w0XXXXXX/hans-dither.de).
if [ "$REMOTE_ROOT" = "/" ] || [ "$REMOTE_ROOT" = "." ]; then
    echo -e "${RED}❌ FEHLER: REMOTE_ROOT='$REMOTE_ROOT' würde ins Account-HOME (bzw. Root) deployen!${NC}"
    echo "   Der Login landet im Home-Verzeichnis — der Webroot ist der Unterordner der Domain."
    echo "   Setze in .deploy.env z. B.: REMOTE_ROOT=hans-dither.de"
    exit 1
fi

PREPARE_ONLY=false
for arg in "$@"; do
    if [ "$arg" = "--prepare-only" ]; then
        PREPARE_ONLY=true
    fi
done

echo -e "${BLUE}🔍 Prä-Deployment-Checks...${NC}"

if [ -z "${SSH_HOST:-}" ] || [ -z "${SSH_USER:-}" ]; then
    if ! command -v lftp &> /dev/null && [ "$PREPARE_ONLY" = false ]; then
        echo -e "${YELLOW}⚠️  lftp nicht gefunden! Installiere: brew install lftp${NC}"
        exit 1
    fi
fi

if [ "$PREPARE_ONLY" = false ] && [ -n "${SSH_HOST:-}" ] && [ -n "${SSH_USER:-}" ] && ! command -v rsync &> /dev/null; then
    echo -e "${YELLOW}⚠️  rsync nicht gefunden! Installiere: brew install rsync${NC}"
    exit 1
fi

if [ "$PREPARE_ONLY" = false ] && [ -n "${SSH_HOST:-}" ] && [ -n "${SSH_USER:-}" ] && ! command -v ssh &> /dev/null; then
    echo -e "${YELLOW}⚠️  ssh nicht gefunden! Bitte OpenSSH installieren.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Alle Checks bestanden!${NC}"

# =============================================================================
# Schritt 1: SQL-Schema aus kanonischer Migration generieren
# (Einzige Schema-Quelle: sql/migrations/001_create_tables.sql)
# =============================================================================
mkdir -p storage
SQL_FILE="$SCRIPT_DIR/storage/hansdither_schema.sql"
SQL_SOURCE="$SCRIPT_DIR/sql/migrations/001_create_tables.sql"

echo -e "${BLUE}\n🗃️  Schritt 1: SQL-Schema generieren...${NC}"

if [ ! -f "$SQL_SOURCE" ]; then
    echo -e "${RED}❌ FEHLER: Kanonische Migration nicht gefunden: $SQL_SOURCE${NC}"
    exit 1
fi

sed "s/hans_sync/$DB_NAME/g" "$SQL_SOURCE" > "$SQL_FILE"

echo -e "${GREEN}✅ SQL-Schema generiert: $SQL_FILE${NC}"
echo "   → Importiere in phpMyAdmin (https://kas.all-inkl.com)!"
echo ""

# =============================================================================
# Schritt 2: includes/config.php generieren (einzige Quelle: .deploy.env)
# =============================================================================
echo -e "${BLUE}📝 Schritt 2: Konfigurationsdateien erstellen...${NC}"

mkdir -p includes public assets/css assets/js uploads storage

# Fallback-Frontcontroller im Webroot, falls DirectoryIndex/Rewrite auf dem Host
# anders konfiguriert ist als erwartet.
cat > index.php <<'INDEXEOF'
<?php
require __DIR__ . '/public/index.php';
INDEXEOF

cat > includes/config.php <<CONFIGEOF
<?php
/**
 * Hans Dither Backend - Konfiguration
 * Generiert durch deploy.sh aus .deploy.env
 * WICHTIG: Diese Datei NICHT ins Git committen (via .gitignore abgesichert)!
 */

// Fehlerbehandlung
error_reporting(E_ALL);
ini_set('display_errors', '0');  // Production: Keine Fehler im Browser
ini_set('log_errors', '1');
ini_set('error_log', __DIR__ . '/../storage/php_error.log');

// Datenbank (all-inkl.com)
define('DB_HOST', '$DB_HOST');
define('DB_USER', '$DB_USER');
define('DB_PASS', '$DB_PASS');
define('DB_NAME', '$DB_NAME');
define('DB_PORT', $DB_PORT);

// Basis-URL und Pfade
define('BASE_URL', '$BASE_URL');
define('UPLOADS_DIR', __DIR__ . '/../uploads');
define('STORAGE_DIR', __DIR__ . '/../storage');

// Authentifizierung & Limits (FR-004, FR-007, contracts E-02/E-03)
define('PIN_LENGTH', 4);
define('PIN_REGEX', '/^[0-9]{4}\$/');
define('UID_REGEX', '/^[A-Za-z0-9_-]{1,64}\$/');
define('MAX_FAILED_ATTEMPTS', 3);
define('LOCKOUT_DURATION', 300);      // 5 Minuten Sperre
define('SESSION_TIMEOUT', 1800);      // 30 Minuten Session-Gültigkeit

// Rendering
define('GIF_FRAME_DELAY_MS', 200);    // Anzeigedauer je Animations-Frame im GIF-Export

// Security Headers
header("X-Content-Type-Options: nosniff");
header("X-Frame-Options: DENY");
header("X-XSS-Protection: 1; mode=block");
header("Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:");
CONFIGEOF

chmod 600 includes/config.php

# =============================================================================
# Schritt 3: .htaccess generieren
# (Quoted Heredoc: %{...} kommt UNVERÄNDERT bei Apache an — kein \%-Escaping!)
# =============================================================================
cat > .htaccess <<'HTACCESSEOF'
# Hans Dither Backend - .htaccess
# Generiert durch deploy.sh — NICHT manuell editieren

RewriteEngine On

# ===========================================
# HTTPS erzwingen (contracts S-08)
# ===========================================
RewriteCond %{HTTPS} off
RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

# ===========================================
# Zugriffsschutz (contracts S-03/S-04):
# Sensible Verzeichnisse sind nicht öffentlich abrufbar.
# Dateien werden ausschließlich über public/download.php ausgeliefert.
# ===========================================
RewriteRule ^includes/ - [F,L]
RewriteRule ^storage/ - [F,L]
RewriteRule ^logs/ - [F,L]
RewriteRule ^sql/ - [F,L]
RewriteRule ^uploads/ - [F,L]

# Dotfiles (.deploy.env, .gitignore, ...) und riskante Endungen blockieren
<FilesMatch "^\.">
    Require all denied
</FilesMatch>
<FilesMatch "\.(env|sh|sql|log|md|bak|ini)$">
    Require all denied
</FilesMatch>

# ===========================================
# CORS für Playdate-Simulator (contracts S-07)
# ===========================================
Header set Access-Control-Allow-Origin "http://localhost:8000"
Header set Access-Control-Allow-Methods "GET, POST, OPTIONS"
Header set Access-Control-Allow-Headers "Content-Type, X-Session-Token, X-UID, X-PIN"

# ===========================================
# Routing (contracts E-01..E-08, E-08b seit Spec 009): Front-Controller
# ===========================================
RewriteRule ^$ public/index.php [L]
RewriteRule ^index\.php$ public/index.php [L]
RewriteRule ^(pair|login|images|logout)$ public/index.php [L]
RewriteRule ^upload(\.php)?$ public/upload.php [L]
RewriteRule ^download/(pdi|json|png|tilemap|gif)/[A-Za-z0-9-]+$ public/download.php [L]

# ===========================================
# Sicherheit / Fehlerbehandlung
# ===========================================
Options -Indexes
ErrorDocument 404 /index.php
HTACCESSEOF

# Defense-in-Depth: Direktzugriff auf Upload-/Storage-Dateien serverseitig sperren
cat > uploads/.htaccess <<'EOF'
Require all denied
EOF
cat > storage/.htaccess <<'EOF'
Require all denied
EOF

echo -e "${GREEN}✅ Konfigurationsdateien erstellt!${NC}"
echo "   - includes/config.php (chmod 600, aus .deploy.env)"
echo "   - .htaccess (HTTPS, Routing, Zugriffsschutz)"
echo "   - uploads/.htaccess, storage/.htaccess (Require all denied)"
echo ""

# =============================================================================
# Schritt 4: Upload + DB-Provisionierung
#   Bevorzugt: SSH (rsync-Upload + mysql direkt auf dem Server — vollautomatisch)
#   Fallback:  FTPS via lftp (DB-Schema muss dann manuell importiert werden)
# =============================================================================
if [ "$PREPARE_ONLY" = false ]; then
    DB_STATUS="MANUELL (phpMyAdmin: $SQL_FILE)"

    if [ -n "${SSH_HOST:-}" ] && [ -n "${SSH_USER:-}" ]; then
        SSH_PORT="${SSH_PORT:-22}"
        SSH_TARGET="$SSH_USER@$SSH_HOST"
        SSH_CMD="ssh -p $SSH_PORT -o BatchMode=yes -o ConnectTimeout=10"
        REMOTE_TARGET="$REMOTE_ROOT"

        if [[ "$REMOTE_TARGET" != /* ]]; then
            SSH_CWD="$($SSH_CMD "$SSH_TARGET" 'pwd')"
            if [ "$SSH_CWD" = "/" ] && $SSH_CMD "$SSH_TARGET" "[ -d '/www/htdocs' ]"; then
                echo -e "${RED}❌ FEHLER: SSH startet in '/' und REMOTE_ROOT ist relativ ('$REMOTE_TARGET').${NC}"
                echo "   Dadurch landen Dateien in '/$REMOTE_TARGET' statt im Webroot."
                echo "   Setze REMOTE_ROOT absolut, z. B.: /www/htdocs/w0XXXXXX/$REMOTE_TARGET"
                exit 1
            fi
        fi

        echo -e "${BLUE}🚀 Schritt 4: Upload via rsync/SSH ($SSH_TARGET)...${NC}"
        echo "   Ziel: $REMOTE_TARGET"
        $SSH_CMD "$SSH_TARGET" "mkdir -p '$REMOTE_TARGET'"
        # KRITISCH: uploads/ MUSS von --delete ausgenommen werden — sonst
        # spiegelt rsync das lokale (bewusst .gitignore'te, praktisch leere)
        # uploads/-Verzeichnis auf den Server und LÖSCHT alle echten
        # Nutzer-Uploads bei jedem Deploy. storage/ bleibt bewusst NICHT
        # ausgeschlossen: storage/.htaccess wird lokal bei jedem Lauf frisch
        # erzeugt (Schritt 2) und muss auf einem frischen Server ankommen;
        # der einzige sonstige Inhalt (php_error.log) ist ein regenerierbares
        # Log, kein Nutzerdatenverlust. (Gefunden + korrigiert: Spec 009,
        # nachdem genau das bei einem Test-Deploy die uploads/ geleert hat.)
        rsync -az --delete \
        --exclude='.deploy.env*' \
        --exclude='deploy.sh' \
        --exclude='*.md' \
        --exclude='.git*' \
        --exclude='.DS_Store' \
        --exclude='hansdither_schema.sql' \
        --exclude='uploads/' \
        -e "ssh -p $SSH_PORT -o BatchMode=yes" \
        ./ "$SSH_TARGET:$REMOTE_TARGET/"
        echo -e "${GREEN}✅ Dateien hochgeladen (rsync)!${NC}"

        echo -e "${BLUE}🗃️  Schritt 4b: Datenbank provisionieren (mysql via SSH)...${NC}"
        # MySQL-Zugang als temporäre defaults-Datei auf dem Server ablegen —
        # so taucht das Passwort nie in der Prozessliste des Shared Hosts auf
        printf '[client]\nhost=%s\nuser=%s\npassword=%s\n' "$DB_HOST" "$DB_USER" "$DB_PASS" | \
            $SSH_CMD "$SSH_TARGET" 'umask 077; cat > "$HOME/.hd_mysql.cnf"'

        # Schema idempotent einspielen (CREATE TABLE IF NOT EXISTS)
        $SSH_CMD "$SSH_TARGET" "mysql --defaults-extra-file=\"\$HOME/.hd_mysql.cnf\" $DB_NAME" < "$SQL_FILE"

        # Bestandstabellen ohne gif_path-Spalte nachziehen
        GIF_COL=$($SSH_CMD "$SSH_TARGET" "mysql --defaults-extra-file=\"\$HOME/.hd_mysql.cnf\" -N -e \"SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$DB_NAME' AND TABLE_NAME='images' AND COLUMN_NAME='gif_path'\"")
        if [ "$GIF_COL" = "0" ]; then
            $SSH_CMD "$SSH_TARGET" "mysql --defaults-extra-file=\"\$HOME/.hd_mysql.cnf\" -e \"ALTER TABLE images ADD COLUMN gif_path VARCHAR(255) NULL AFTER png_path\" $DB_NAME"
            echo "   → Spalte images.gif_path ergänzt"
        fi

        # Migration 002 (Spec 004, Playdate-Sync): client_image_id + confirmed_at
        # nachziehen, falls noch nicht vorhanden — deploy.sh spielt NUR
        # 001_create_tables.sql automatisch ein, weitere sql/migrations/*.sql
        # müssen hier wie gif_path oben als eigener idempotenter Check ergänzt
        # werden, sonst bleibt die Datei totes Dokumentationsmaterial.
        CLIENT_IMAGE_ID_COL=$($SSH_CMD "$SSH_TARGET" "mysql --defaults-extra-file=\"\$HOME/.hd_mysql.cnf\" -N -e \"SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$DB_NAME' AND TABLE_NAME='images' AND COLUMN_NAME='client_image_id'\"")
        if [ "$CLIENT_IMAGE_ID_COL" = "0" ]; then
            $SSH_CMD "$SSH_TARGET" "mysql --defaults-extra-file=\"\$HOME/.hd_mysql.cnf\" -e \"ALTER TABLE images ADD COLUMN client_image_id VARCHAR(64) NULL AFTER uid, ADD UNIQUE KEY uniq_uid_client_image_id (uid, client_image_id)\" $DB_NAME"
            echo "   → Spalte images.client_image_id ergänzt"
        fi

        CONFIRMED_AT_COL=$($SSH_CMD "$SSH_TARGET" "mysql --defaults-extra-file=\"\$HOME/.hd_mysql.cnf\" -N -e \"SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$DB_NAME' AND TABLE_NAME='users' AND COLUMN_NAME='confirmed_at'\"")
        if [ "$CONFIRMED_AT_COL" = "0" ]; then
            $SSH_CMD "$SSH_TARGET" "mysql --defaults-extra-file=\"\$HOME/.hd_mysql.cnf\" -e \"ALTER TABLE users ADD COLUMN confirmed_at DATETIME NULL AFTER locked_until\" $DB_NAME"
            echo "   → Spalte users.confirmed_at ergänzt"
        fi

        # Verifikation: alle drei Tabellen müssen existieren
        TABLES=$($SSH_CMD "$SSH_TARGET" "mysql --defaults-extra-file=\"\$HOME/.hd_mysql.cnf\" -N -e 'SHOW TABLES' $DB_NAME")
        $SSH_CMD "$SSH_TARGET" 'rm -f "$HOME/.hd_mysql.cnf"'

        for table in users images sessions; do
            if ! echo "$TABLES" | grep -q "^${table}$"; then
                echo -e "${RED}❌ FEHLER: Tabelle '$table' fehlt nach Migration!${NC}"
                exit 1
            fi
        done
        echo -e "${GREEN}✅ Datenbank provisioniert (Tabellen: users, images, sessions)!${NC}"
        DB_STATUS="AUTOMATISCH PROVISIONIERT"
    else
        echo -e "${BLUE}🚀 Schritt 4: Dateien via FTPS hochladen (SSH nicht konfiguriert)...${NC}"
        echo "   Verbinde mit $SFTP_HOST als $SFTP_USER..."
        echo -e "${YELLOW}   💡 Tipp: SSH_HOST/SSH_USER in .deploy.env setzen für vollautomatische DB-Provisionierung${NC}"
        echo ""

        lftp -u "$SFTP_USER,$SFTP_PASS" -p "$SFTP_PORT" "$SFTP_HOST" <<EOF
set ftp:ssl-force true
set ftp:ssl-protect-data true
set ssl:verify-certificate yes
cd $REMOTE_ROOT

mirror --reverse --delete --use-cache --parallel=1 --exclude-glob .deploy.env* --exclude-glob deploy.sh --exclude-glob *.md --exclude-glob .git* --exclude-glob .DS_Store --exclude-glob hansdither_schema.sql --exclude-glob uploads/ . .

bye
EOF

        echo -e "${GREEN}✅ Dateien hochgeladen (FTPS)!${NC}"
    fi

    # =========================================================================
    # Schritt 5: Sicherheits-Verifikation — Secrets dürfen NICHT abrufbar sein
    # =========================================================================
    echo ""
    echo -e "${BLUE}🔒 Schritt 5: Verifiziere, dass Secrets nicht öffentlich sind...${NC}"
    SECURITY_FAIL=false
    for path in ".deploy.env" ".deploy.env.example" "deploy.sh" \
                "includes/config.php" "includes/database.php" \
                "storage/php_error.log" ".gitignore"; do
        code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/$path" || echo "000")
        if [ "$code" = "200" ]; then
            echo -e "${RED}❌ SICHERHEITSPROBLEM: $BASE_URL/$path ist ÖFFENTLICH abrufbar (HTTP $code)!${NC}"
            SECURITY_FAIL=true
        else
            echo -e "${GREEN}✅ $path blockiert (HTTP $code)${NC}"
        fi
    done

    if [ "$SECURITY_FAIL" = true ]; then
        echo -e "${RED}❌ DEPLOYMENT UNSICHER — bitte .htaccess/Serverkonfiguration prüfen!${NC}"
        exit 1
    fi

    DEPLOY_STATUS="VOLLSTAENDIG"
else
    echo -e "${YELLOW}⏭️ Upload übersprungen (--prepare-only)${NC}"
    echo "   Manuell hochladen nach: $REMOTE_ROOT/"
    echo "   (Dabei NIE hochladen: .deploy.env*, deploy.sh)"
    DEPLOY_STATUS="VORBEREITET"
fi

echo ""
echo -e "${BLUE}=============================================================================${NC}"
echo -e "${GREEN}🎉 DEPLOYMENT $DEPLOY_STATUS!${NC}"
echo -e "${BLUE}=============================================================================${NC}"
echo ""

echo -e "${YELLOW}📋 POST-DEPLOYMENT CHECKLISTE:${NC}"
echo "  [ ] Datenbank: ${DB_STATUS:-VORBEREITET ($SQL_FILE)}"
echo "  [ ] PHP GD-Bibliothek aktiviert (KAS → PHP-Einstellungen)"
echo "  [ ] Test: $BASE_URL/ lädt die UID-Eingabeseite"
echo "  [ ] Schnelltest: curl -I $BASE_URL/"
echo ""

echo -e "${RED}⚠️  SICHERHEIT:${NC}"
echo "  🔒 includes/config.php und .deploy.env sind via .gitignore vom Commit ausgeschlossen"
echo "  🔒 .deploy.env* und deploy.sh werden beim Upload ausgefiltert (mirror-Excludes)"
echo "  🔒 Übertragung nur via FTPS (ftp:ssl-force)"
echo ""
