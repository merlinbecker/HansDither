<?php
/**
 * Hans Dither Backend - Konfiguration
 * 
 * Lädt Umgebungsvariablen und definiert globale Konstanten.
 * WIRD NICHT IN GIT EINGECHECKT - Enthält sensible Zugangsdaten!
 */

// ===========================================
// Fehlerbehandlung
// ===========================================
error_reporting(E_ALL);
ini_set('display_errors', '0');  // Keine Fehler im Browser anzeigen (Production)
ini_set('log_errors', '1');
ini_set('error_log', __DIR__ . '/../logs/php_error.log');

// ===========================================
// Umgebungsvariablen laden
// ===========================================
$env_file = __DIR__ . '/../.env';

if (!file_exists($env_file)) {
    // Versuche es mit scripts/deploy/.env für Deployment
    $deploy_env = __DIR__ . '/../../scripts/deploy/.env';
    if (file_exists($deploy_env)) {
        $env_file = $deploy_env;
    } else {
        die('FEHLER: .env Datei nicht gefunden! Bitte kopiere .env.template nach .env und trage deine Daten ein.');
    }
}

$lines = file($env_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
foreach ($lines as $line) {
    // Überspringe Kommentare
    if (strpos(trim($line), '#') === 0) {
        continue;
    }
    
    // Parse KEY=VALUE
    $pos = strpos($line, '=');
    if ($pos !== false) {
        $key = trim(substr($line, 0, $pos));
        $value = trim(substr($line, $pos + 1));
        
        // Entferne Anführungszeichen
        if (preg_match('/^(["\'])(.*)\1$/', $value, $matches)) {
            $value = $matches[2];
        }
        
        putenv("$key=$value");
        $_ENV[$key] = $value;
        $_SERVER[$key] = $value;
    }
}

// ===========================================
// Datenbank-Konfiguration
// ===========================================
define('DB_HOST', getenv('DB_HOST') ?: die('DB_HOST nicht in .env gesetzt'));
define('DB_NAME', getenv('DB_NAME') ?: die('DB_NAME nicht in .env gesetzt'));
define('DB_USER', getenv('DB_USER') ?: die('DB_USER nicht in .env gesetzt'));
define('DB_PASS', getenv('DB_PASS') ?: die('DB_PASS nicht in .env gesetzt'));
define('DB_PORT', getenv('DB_PORT') ?: '3306');

// ===========================================
// Dateisystem-Pfade
// ===========================================
define('UPLOADS_DIR', __DIR__ . '/../uploads');
define('MAX_UPLOAD_SIZE', 10 * 1024 * 1024); // 10MB

// ===========================================
// Backend-URL
// ===========================================
define('BACKEND_URL', getenv('BACKEND_URL') ?: 'https://www.hans-dither.de');

// ===========================================
// Session-Einstellungen
// ===========================================
define('SESSION_TIMEOUT', 1800); // 30 Minuten in Sekunden
define('MAX_FAILED_ATTEMPTS', 3);
define('LOCKOUT_DURATION', 300); // 5 Minuten in Sekunden

// ===========================================
// PIN-Einstellungen
// ===========================================
define('PIN_LENGTH', 4);
define('PIN_REGEX', '/^\d{' . PIN_LENGTH . '}$/');

// ===========================================
// Sicherheits-Header
// ===========================================
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('X-XSS-Protection: 1; mode=block');
header('Content-Security-Policy: default-src \'self\'; script-src \'self\' \'unsafe-inline\'; style-src \'self\' \'unsafe-inline\'');

// ===========================================
// Autoload für Includes
// ===========================================
spl_autoload_register(function ($class) {
    $file = __DIR__ . '/' . $class . '.php';
    if (file_exists($file)) {
        require $file;
    }
});
