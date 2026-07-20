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
     * Maximale Dateigröße (300 KB, Spec 007 R2 — PDI/JSON sind typischerweise
     * klein, ein deutlich niedrigerer Schwellwert als die vorherigen 10 MB
     * begrenzt die Ressourcen-Belastung durch überdimensionierte Uploads)
     */
    private static $maxFileSize = 300 * 1024;
    
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
            return ['valid' => false, 'error' => 'Datei zu groß (max. 300KB)', 'http_code' => 413];
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
     * Validiert die Struktur einer dekodierten frames.json gegen das in
     * Spec 001 definierte Schema (Spec 007, R4). Prüft in fester Reihenfolge
     * und bricht bei der ersten Verletzung ab; die Meldung benennt immer das
     * konkret verletzte Feld statt eines generischen Fehlers (FR-008/FR-009).
     *
     * @param array $data Dekodierte JSON-Daten (Objekt-Root als Array gecastet)
     * @return array Ergebnis mit Status und Fehlermeldung
     */
    public static function validateFramesJsonSchema(array $data): array {
        if (!isset($data['version']) || !is_numeric($data['version']) || $data['version'] < 1) {
            return ['valid' => false, 'error' => 'JSON-Struktur ungültig: version fehlt oder ist ungültig'];
        }

        if (!isset($data['name']) || !is_string($data['name']) || strlen($data['name']) === 0) {
            return ['valid' => false, 'error' => 'JSON-Struktur ungültig: name fehlt oder ist leer'];
        }

        if (!isset($data['gridWidth']) || !is_numeric($data['gridWidth']) || (int) $data['gridWidth'] !== 25) {
            return ['valid' => false, 'error' => 'JSON-Struktur ungültig: gridWidth muss 25 sein'];
        }

        if (!isset($data['gridHeight']) || !is_numeric($data['gridHeight']) || (int) $data['gridHeight'] !== 15) {
            return ['valid' => false, 'error' => 'JSON-Struktur ungültig: gridHeight muss 15 sein'];
        }

        if (!isset($data['tileCount']) || !is_numeric($data['tileCount']) || $data['tileCount'] < 1) {
            return ['valid' => false, 'error' => 'JSON-Struktur ungültig: tileCount fehlt oder ist ungültig'];
        }
        $tileCount = (int) $data['tileCount'];

        if (!isset($data['frames']) || !is_array($data['frames'])) {
            return ['valid' => false, 'error' => 'JSON-Struktur ungültig: frames fehlt oder ist kein Array'];
        }
        $frameCount = count($data['frames']);
        if ($frameCount < 1 || $frameCount > 12) {
            return ['valid' => false, 'error' => "JSON-Struktur ungültig: frames hat $frameCount Einträge, erlaubt sind 1 bis 12"];
        }

        $expectedTiles = 25 * 15; // gridWidth x gridHeight, oben bereits exakt geprüft
        foreach ($data['frames'] as $f => $frame) {
            if (!is_array($frame)) {
                return ['valid' => false, 'error' => "JSON-Struktur ungültig: frames[$f] ist kein Array"];
            }
            $actual = count($frame);
            if ($actual !== $expectedTiles) {
                return ['valid' => false, 'error' => "JSON-Struktur ungültig: frames[$f] hat $actual statt $expectedTiles Werte"];
            }
            foreach ($frame as $i => $tile) {
                if (!is_numeric($tile) || (int) $tile < 1 || (int) $tile > $tileCount) {
                    return ['valid' => false, 'error' => "JSON-Struktur ungültig: frames[$f][$i] = $tile liegt außerhalb von 1..$tileCount"];
                }
            }
        }

        return ['valid' => true, 'error' => null];
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

        // Struktur-Schema prüfen (Spec 007, FR-007/FR-008/FR-009, R4)
        $schemaResult = self::validateFramesJsonSchema((array) $data);
        if (!$schemaResult['valid']) {
            return $schemaResult;
        }

        // Dateigröße prüfen (300 KB)
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
