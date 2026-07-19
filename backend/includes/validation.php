<?php
/**
 * Hans Dither Backend - Dateivalidierung
 * 
 * Validiert PDI- und JSON-Dateien vor dem Upload.
 */

class Validation {
    
    /**
     * Erlaubte Dateitypen
     */
    private static $allowedExtensions = ['pdi', 'json'];
    
    /**
     * Erlaubte MIME-Typen
     */
    private static $allowedMimeTypes = [
        'application/octet-stream',  // PDI
        'application/json',         // JSON
    ];
    
    /**
     * Maximale Dateigröße (10MB)
     */
    private static $maxFileSize = 10 * 1024 * 1024;
    
    /**
     * Maximale Abmessungen des dekodierten Sheets
     * (Spec 001: Breite = max. 25 Tiles × 16 px = 400; Höhe wächst mit tileCount)
     */
    private static $maxPdiWidth = 400;
    private static $maxPdiHeight = 4096;
    
    /**
     * Gefährliche Dateitypen (niemals erlauben!)
     */
    private static $dangerousExtensions = [
        'php', 'php3', 'php4', 'php5', 'php7', 'php8', 'phtml',
        'exe', 'com', 'bat', 'cmd', 'sh', 'bash', 'pl', 'py',
        'rb', 'java', 'class', 'jar', 'js', 'jsp', 'asp', 'aspx',
        'cgi', 'fcgi', 'htaccess', 'htaccess', 'svg', 'html', 'htm'
    ];
    
    /**
     * Validiert eine hochgeladene Datei
     * 
     * @param array $file $_FILES-Array
     * @return array Ergebnis mit Status und Fehlermeldung
     */
    public static function validateUploadedFile(array $file): array {
        // 1. Prüfen ob Datei hochgeladen wurde
        if (!isset($file['tmp_name']) || !is_uploaded_file($file['tmp_name'])) {
            return ['valid' => false, 'error' => 'Keine Datei hochgeladen'];
        }
        
        // 2. Dateigröße prüfen
        if ($file['size'] <= 0) {
            return ['valid' => false, 'error' => 'Ungültige Dateigröße'];
        }
        if ($file['size'] > self::$maxFileSize) {
            // contracts E-04: 413 Payload Too Large
            return ['valid' => false, 'error' => 'Datei zu groß (max. 10MB)', 'http_code' => 413];
        }
        
        // 3. Dateiendung prüfen
        $extension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
        if (!in_array($extension, self::$allowedExtensions)) {
            return ['valid' => false, 'error' => 'Ungültige Dateiendung. Nur .pdi und .json erlaubt.'];
        }
        
        // 4. Gefährliche Endungen blockieren
        if (in_array($extension, self::$dangerousExtensions)) {
            return ['valid' => false, 'error' => 'Dateityp nicht erlaubt'];
        }
        
        // 5. MIME-Type prüfen (falls verfügbar)
        if (isset($file['type'])) {
            $mimeType = strtolower($file['type']);
            if (!in_array($mimeType, self::$allowedMimeTypes) && $mimeType !== '') {
                // Leerer MIME-Type ist okay (manche Server setzen ihn nicht)
                // Aber wenn gesetzt, muss er erlaubt sein
                return ['valid' => false, 'error' => 'Ungültiger Dateityp'];
            }
        }
        
        // 6. Speziell für PDI-Dateien
        if ($extension === 'pdi') {
            $result = self::validatePdiFile($file['tmp_name']);
            if (!$result['valid']) {
                return $result;
            }
        }
        
        // 7. Speziell für JSON-Dateien
        if ($extension === 'json') {
            $result = self::validateJsonFile($file['tmp_name']);
            if (!$result['valid']) {
                return $result;
            }
        }
        
        return ['valid' => true, 'error' => null];
    }
    
    /**
     * Validiert eine PDI-Datei
     * 
     * @param string $filePath Pfad zur Datei
     * @return array Ergebnis
     */
    public static function validatePdiFile(string $filePath): array {
        require_once __DIR__ . '/pdi_parser.php';

        // 1. Magic prüfen: echtes Playdate-SDK-Format "Playdate IMG"
        //    (Spec 001: sheet.pdi wird via playdate.datastore.writeImage() geschrieben)
        if (!PdiParser::hasValidMagic($filePath)) {
            return ['valid' => false, 'error' => 'Ungültige PDI-Datei: Kein Playdate-Bildformat'];
        }

        // 2. Vollständig parsen (deckt beschädigte Header/zlib-Streams ab)
        $parsed = PdiParser::parseFile($filePath);
        if ($parsed === false) {
            return ['valid' => false, 'error' => 'Ungültige PDI-Datei: Beschädigte Bilddaten'];
        }

        // 3. Plausibilität der Abmessungen
        if ($parsed['width'] <= 0 || $parsed['height'] <= 0) {
            return ['valid' => false, 'error' => 'Ungültige PDI-Abmessungen'];
        }
        if ($parsed['width'] > self::$maxPdiWidth || $parsed['height'] > self::$maxPdiHeight) {
            return ['valid' => false, 'error' => 'PDI-Abmessungen zu groß'];
        }

        return ['valid' => true, 'error' => null, 'width' => $parsed['width'], 'height' => $parsed['height']];
    }
    
    /**
     * Validiert eine JSON-Datei
     * 
     * @param string $filePath Pfad zur Datei
     * @return array Ergebnis
     */
    public static function validateJsonFile(string $filePath): array {
        $content = file_get_contents($filePath);
        if ($content === false) {
            return ['valid' => false, 'error' => 'Konnte JSON-Datei nicht lesen'];
        }
        
        // JSON parsen
        $data = json_decode($content);
        if ($data === null) {
            return ['valid' => false, 'error' => 'Ungültiges JSON-Format: ' . json_last_error_msg()];
        }
        
        // Prüfen ob es ein Objekt oder Array ist
        if (!is_object($data) && !is_array($data)) {
            return ['valid' => false, 'error' => 'JSON muss ein Objekt oder Array sein'];
        }
        
        // Dateigröße prüfen (10MB)
        if (strlen($content) > self::$maxFileSize) {
            return ['valid' => false, 'error' => 'JSON-Datei zu groß'];
        }
        
        return ['valid' => true, 'error' => null, 'data' => $data];
    }
    
    /**
     * Validiert eine Datei nach Inhalt (ohne Upload-Kontext)
     * 
     * @param string $filePath Pfad zur Datei
     * @return array Ergebnis
     */
    public static function validateFileContent(string $filePath): array {
        $extension = strtolower(pathinfo($filePath, PATHINFO_EXTENSION));
        
        switch ($extension) {
            case 'pdi':
                return self::validatePdiFile($filePath);
            case 'json':
                return self::validateJsonFile($filePath);
            default:
                return ['valid' => false, 'error' => 'Unbekannter Dateityp'];
        }
    }
    
    /**
     * Prüft ob eine Dateiendung erlaubt ist
     * 
     * @param string $extension Dateiendung
     * @return bool
     */
    public static function isAllowedExtension(string $extension): bool {
        return in_array(strtolower($extension), self::$allowedExtensions);
    }
    
    /**
     * Prüft ob eine Dateiendung gefährlich ist
     * 
     * @param string $extension Dateiendung
     * @return bool
     */
    public static function isDangerousExtension(string $extension): bool {
        return in_array(strtolower($extension), self::$dangerousExtensions);
    }
}
