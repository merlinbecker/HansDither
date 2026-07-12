#!/bin/bash

# ===========================================
# Hans Dither Backend - Deployment Skript
# ===========================================
# Nutzung:
#   ./deploy.sh --dry-run    # Simulation (kein Upload)
#   ./deploy.sh --test       # Lokale Tests
#   ./deploy.sh --full       # Vollständiges Deployment
#   ./deploy.sh --upload     # Nur Dateien hochladen
#   ./deploy.sh --migrate    # Nur DB-Migrationen ausführen
# ===========================================

set -euo pipefail

# --- Konfiguration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEPLOY_DIR="$PROJECT_ROOT/scripts/deploy"

# --- Farben für Ausgabe ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- .env Datei laden ---
load_env() {
    if [ ! -f "$DEPLOY_DIR/.env" ]; then
        echo -e "${RED}❌ FEHLER: .env Datei nicht gefunden!${NC}"
        echo "   Kopiere .env.template nach .env und trage deine Daten ein."
        exit 1
    fi
    
    # Lade Umgebungsvariablen
    set -o allexport
    source "$DEPLOY_DIR/.env"
    set +o allexport
    
    # Pflichtfelder prüfen
    local required_vars=("SFTP_HOST" "SFTP_USER" "SFTP_PASS" "SFTP_PATH" "DB_HOST" "DB_USER" "DB_PASS" "DB_NAME")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo -e "${RED}❌ FEHLER: Folgende Variablen fehlen in .env:${NC}"
        for var in "${missing_vars[@]}"; do
            echo "   - $var"
        done
        exit 1
    fi
}

# --- Dateien, die deployed werden ---
get_deploy_files() {
    # Basisverzeichnisse
    local base_files=(
        "public/index.php"
        "public/.htaccess"
        "public/style.css"
        "public/upload.php"
        "public/download.php"
        "public/projects.php"
        "public/pair.php"
        "includes/config.php"
        "includes/database.php"
        "includes/auth.php"
        "includes/upload_handler.php"
        "includes/renderer.php"
        "includes/logger.php"
        "sql/migrations/001_create_tables.sql"
    )
    
    # Prüfe, welche Dateien existieren
    local files_to_deploy=()
    for file in "${base_files[@]}"; do
        if [ -f "$PROJECT_ROOT/$file" ]; then
            files_to_deploy+=("$file")
        fi
    done
    
    echo "${files_to_deploy[@]}"
}

# --- Dry Run: Zeigt was passieren würde ---
dry_run() {
    echo -e "${BLUE}🔍 [DRY RUN] Folgende Aktionen würden ausgeführt:${NC}\n"
    
    echo -e "${YELLOW}1. 📤 Upload der folgenden Dateien:${NC}"
    local files=($(get_deploy_files))
    for file in "${files[@]}"; do
        echo "   → $PROJECT_ROOT/$file → $SFTP_PATH$file"
    done
    
    echo -e "\n${YELLOW}2. 🗃️  Datenbank-Migrationen:${NC}"
    echo "   → CREATE TABLE users (...)"
    echo "   → CREATE TABLE projects (...)"
    echo "   → CREATE TABLE files (...)"
    
    echo -e "\n${GREEN}✅ Keine Änderungen wurden vorgenommen.${NC}"
}

# --- Test: Lokale Umgebung prüfen ---
test_environment() {
    echo -e "${BLUE}🧪 [TEST] Prüfe lokale Umgebung...${NC}\n"
    
    local passed=0
    local failed=0
    
    # 1. PHP Version prüfen
    echo -n "  🔹 PHP Version (8.0+): "
    if command -v php &> /dev/null; then
        php_version=$(php -r 'echo PHP_VERSION;')
        if [[ "$php_version" =~ ^[8-9]\.|^1[0-9]\. ]]; then
            echo -e "${GREEN}✅ $php_version${NC}"
            ((passed++))
        else
            echo -e "${RED}❌ $php_version (benötigt 8.0+}${NC}"
            ((failed++))
        fi
    else
        echo -e "${RED}❌ PHP nicht installiert${NC}"
        ((failed++))
    fi
    
    # 2. PHP GD-Bibliothek prüfen
    echo -n "  🔹 PHP GD-Bibliothek: "
    if php -m | grep -q gd; then
        echo -e "${GREEN}✅ Installiert${NC}"
        ((passed++))
    else
        echo -e "${RED}❌ Nicht installiert (benötigt für PNG-Rendering)${NC}"
        ((failed++))
    fi
    
    # 3. MySQL Client prüfen
    echo -n "  🔹 MySQL Client: "
    if command -v mysql &> /dev/null; then
        echo -e "${GREEN}✅ Installiert${NC}"
        ((passed++))
        
        # Verbindung testen
        echo -n "  🔹 MySQL Verbindung: "
        if mysql --host="$DB_HOST" --user="$DB_USER" --password="$DB_PASS" --port="$DB_PORT" -e "SHOW DATABASES;" &> /dev/null; then
            echo -e "${GREEN}✅ Erfolgreich${NC}"
            ((passed++))
        else
            echo -e "${RED}❌ Verbindung fehlgeschlagen${NC}"
            ((failed++))
        fi
    else
        echo -e "${RED}❌ Nicht installiert${NC}"
        ((failed++))
    fi
    
    # 4. SFTP Client prüfen
    echo -n "  🔹 SFTP Client: "
    if command -v sftp &> /dev/null; then
        echo -e "${GREEN}✅ Installiert${NC}"
        ((passed++))
    else
        echo -e "${RED}❌ Nicht installiert${NC}"
        ((failed++))
    fi
    
    # 5. Projektabhängigkeiten prüfen
    echo -n "  🔹 Projektabhängigkeiten: "
    local missing_deps=()
    [ ! -d "$PROJECT_ROOT/public" ] && missing_deps+=("public/")
    [ ! -d "$PROJECT_ROOT/includes" ] && missing_deps+=("includes/")
    [ ! -d "$PROJECT_ROOT/sql/migrations" ] && missing_deps+=("sql/migrations/")
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ Alle Verzeichnisse vorhanden${NC}"
        ((passed++))
    else
        echo -e "${RED}❌ Fehlend: ${missing_deps[*]}${NC}"
        ((failed++))
    fi
    
    echo -e "\n${BLUE}📊 Testergebnis: ${GREEN}$passed✅${NC} / ${RED}$failed❌${NC}${NC}"
    
    if [ $failed -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Behebe die Fehler, bevor du deployst!${NC}"
        exit 1
    else
        echo -e "${GREEN}✅ Alle Tests bestanden!${NC}"
    fi
}

# --- Upload via SFTP ---
upload_files() {
    echo -e "${BLUE}📤 [UPLOAD] Lade Dateien hoch...${NC}\n"
    
    local files=($(get_deploy_files))
    local total=${#files[@]}
    local success=0
    local failed=0
    
    if [ $total -eq 0 ]; then
        echo -e "${YELLOW}⚠️  Keine Dateien zum Hochladen gefunden.${NC}"
        return 0
    fi
    
    # Erstelle temporäres SFTP-Batch-Skript
    local sftp_batch=$(mktemp)
    local sftp_log=$(mktemp)
    
    # SFTP-Befehle generieren
    {
        echo "cd $SFTP_PATH"
        echo "lmkdir -p $SFTP_PATH"
        for file in "${files[@]}"; do
            local remote_path="$(dirname "$file")"
            echo "mkdir -p $remote_path"
        done
        for file in "${files[@]}"; do
            echo "put $PROJECT_ROOT/$file $file"
        done
    } > "$sftp_batch"
    
    # SFTP ausführen
    echo -e "${YELLOW}  Verbinde mit $SFTP_USER@$SFTP_HOST...${NC}"
    if sftp -P "$SFTP_PORT" -b "$sftp_batch" "$SFTP_USER@$SFTP_HOST" > "$sftp_log" 2>&1; then
        success=$total
        echo -e "${GREEN}✅ Alle $total Dateien erfolgreich hochgeladen!${NC}"
    else
        # Zähle erfolgreiche Uploads
        success=$(grep -c "Uploading" "$sftp_log" || true)
        failed=$((total - success))
        echo -e "${RED}❌ $failed von $total Dateien fehlgeschlagen${NC}"
        echo -e "   Details in: $sftp_log"
    fi
    
    # Aufräumen
    rm -f "$sftp_batch" "$sftp_log"
    
    return $failed
}

# --- Datenbank Migrationen ---
migrate_database() {
    echo -e "${BLUE}🗃️  [MIGRATE] Führe Datenbank-Migrationen aus...${NC}\n"
    
    local migration_files=(
        "$PROJECT_ROOT/sql/migrations/001_create_tables.sql"
    )
    
    local success=0
    local failed=0
    
    for migration in "${migration_files[@]}"; do
        if [ -f "$migration" ]; then
            echo -e "  📄 Führe aus: $(basename "$migration")..."
            if mysql --host="$DB_HOST" --user="$DB_USER" --password="$DB_PASS" --port="$DB_PORT" "$DB_NAME" < "$migration" 2>/dev/null; then
                echo -e "     ${GREEN}✅ Erfolgreich${NC}"
                ((success++))
            else
                echo -e "     ${RED}❌ Fehlgeschlagen${NC}"
                ((failed++))
            fi
        else
            echo -e "  ${YELLOW}⚠️  Migration nicht gefunden: $migration${NC}"
        fi
    done
    
    if [ $failed -gt 0 ]; then
        echo -e "\n${RED}❌ $failed von $success Migrationen fehlgeschlagen${NC}"
        return 1
    else
        echo -e "\n${GREEN}✅ Alle $success Migrationen erfolgreich!${NC}"
        return 0
    fi
}

# --- Hauptlogik ---
main() {
    # Argument parsen
    case "${1:-}" in
        --dry-run)
            load_env
            dry_run
            ;;
        --test)
            load_env
            test_environment
            ;;
        --full)
            load_env
            test_environment
            upload_files
            migrate_database
            echo -e "\n${GREEN}🎉 Deployment erfolgreich!${NC}"
            echo -e "   Backend erreichbar unter: ${BACKEND_URL}"
            ;;
        --upload)
            load_env
            upload_files
            ;;
        --migrate)
            load_env
            migrate_database
            ;;
        *)
            echo -e "${RED}❌ Unbekannte Option: ${1:-Keine Option angegeben}${NC}"
            echo ""
            echo "Nutzung:"
            echo "  ./deploy.sh --dry-run    # Simulation (kein Upload)"
            echo "  ./deploy.sh --test       # Lokale Tests"
            echo "  ./deploy.sh --full       # Vollständiges Deployment"
            echo "  ./deploy.sh --upload     # Nur Dateien hochladen"
            echo "  ./deploy.sh --migrate    # Nur DB-Migrationen ausführen"
            exit 1
            ;;
    esac
}

# Skript starten
main "$@"
