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
     * PDI Magic Bytes (erste 4 Bytes: "PDI\0")
     */
    private static $pdiMagicBytes = "PDI\x00";
    
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
        if ($file['size'] <= 0 || $file['size'] > self::$maxFileSize) {
            return ['valid' => false, 'error' => 'Datei zu groß (max. 10MB) oder ungültige Größe'];
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
        // Datei öffnen
        $handle = fopen($filePath, 'rb');
        if (!$handle) {
            return ['valid' => false, 'error' => 'Konnte PDI-Datei nicht öffnen'];
        }
        
        // 1. Magic Bytes prüfen (erste 4 Bytes)
        $header = fread($handle, 4);
        if ($header !== self::$pdiMagicBytes) {
            fclose($handle);
            return ['valid' => false, 'error' => 'Ungültige PDI-Datei: Magic Bytes fehlen'];
        }
        
        // 2. Dateigröße prüfen (PDI muss mindestens Header + Daten haben)
        $fileSize = filesize($filePath);
        if ($fileSize < 16) {
            fclose($handle);
            return ['valid' => false, 'error' => 'PDI-Datei zu klein'];
        }
        
        // 3. PDI-Header parsen (nach Spec 001)
        // Format: PDI\0 + 4 Bytes Version + 2 Bytes Width + 2 Bytes Height + 2 Bytes Flags
        $version = fread($handle, 4);
        $width = fread($handle, 2);
        $height = fread($handle, 2);
        $flags = fread($handle, 2);
        
        // Width und Height als Little-Endian lesen
        $width_value = unpack('v', $width)[1];
        $height_value = unpack('v', $height)[1];
        
        // Plausibilität prüfen
        if ($width_value <= 0 || $height_value <= 0) {
            fclose($handle);
            return ['valid' => false, 'error' => 'Ungültige PDI-Abmessungen'];
        }
        
        // Playdate Display ist 400x240
        if ($width_value > 1000 || $height_value > 1000) {
            fclose($handle);
            return ['valid' => false, 'error' => 'PDI-Abmessungen zu groß'];
        }
        
        fclose($handle);
        return ['valid' => true, 'error' => null, 'width' => $width_value, 'height' => $height_value];
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
