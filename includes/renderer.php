<?php
/**
 * Hans Dither Backend - PNG-Renderer
 * 
 * Rendert PDI + JSON zu einem PNG-Bild (400x240, 1-Bit).
 * Nutzt die GD-Bibliothek von PHP.
 */

require_once __DIR__ . '/database.php';
require_once __DIR__ . '/upload_handler.php';

class Renderer {
    
    /**
     * Standard-PNG-Größe (Playdate Display)
     */
    private static $defaultWidth = 400;
    private static $defaultHeight = 240;
    
    /**
     * Rendert ein Image zu PNG (on-demand)
     * 
     * @param string $image_id Image-UUID
     * @param string $uid UID des Nutzers (für Berechtigungsprüfung)
     * @return string|false Pfad zur generierten PNG oder false bei Fehler
     */
    public static function renderToPng(string $image_id, string $uid) {
        // Image-Daten abrufen
        $image = UploadHandler::getImage($image_id, $uid);
        if (!$image) {
            return false;
        }
        
        // Prüfen ob PNG bereits existiert
        if ($image['png_path'] && file_exists($image['png_path'])) {
            return $image['png_path'];
        }
        
        // PDI und JSON laden
        $pdi_data = self::loadPdiFile($image['pdi_path']);
        if (!$pdi_data) {
            return false;
        }
        
        $json_data = self::loadJsonFile($image['json_path']);
        if (!$json_data) {
            return false;
        }
        
        // PNG generieren
        $png_path = $image['pdi_path'] . '.png';
        $success = self::generatePng($pdi_data, $json_data, $png_path);
        
        if ($success) {
            // Pfad in DB speichern
            UploadHandler::savePngPath($image_id, $png_path);
            return $png_path;
        }
        
        return false;
    }
    
    /**
     * Lädt und parst eine PDI-Datei
     * 
     * @param string $file_path Pfad zur PDI-Datei
     * @return array|false PDI-Daten oder false
     */
    private static function loadPdiFile(string $file_path) {
        if (!file_exists($file_path)) {
            return false;
        }
        
        $handle = fopen($file_path, 'rb');
        if (!$handle) {
            return false;
        }
        
        // Magic Bytes prüfen
        $header = fread($handle, 4);
        if ($header !== "PDI\x00") {
            fclose($handle);
            return false;
        }
        
        // Version lesen (4 Bytes)
        $version = fread($handle, 4);
        
        // Width und Height lesen (jeweils 2 Bytes, Little-Endian)
        $width = unpack('v', fread($handle, 2))[1];
        $height = unpack('v', fread($handle, 2))[1];
        
        // Flags lesen (2 Bytes)
        $flags = unpack('v', fread($handle, 2))[1];
        
        // Pixel-Daten lesen (1-Bit pro Pixel, zeilenweise)
        $pixel_data = '';
        $remaining = $width * $height / 8; // 1 Bit pro Pixel = 8 Pixel pro Byte
        while ($remaining > 0) {
            $chunk = fread($handle, min($remaining, 4096));
            if ($chunk === false) {
                fclose($handle);
                return false;
            }
            $pixel_data .= $chunk;
            $remaining -= strlen($chunk);
        }
        
        fclose($handle);
        
        return [
            'width' => $width,
            'height' => $height,
            'version' => $version,
            'flags' => $flags,
            'pixel_data' => $pixel_data
        ];
    }
    
    /**
     * Lädt und parst eine JSON-Datei (Tilemap-Daten)
     * 
     * @param string $file_path Pfad zur JSON-Datei
     * @return array|false JSON-Daten oder false
     */
    private static function loadJsonFile(string $file_path) {
        if (!file_exists($file_path)) {
            return false;
        }
        
        $content = file_get_contents($file_path);
        if ($content === false) {
            return false;
        }
        
        $data = json_decode($content, true);
        if ($data === null) {
            return false;
        }
        
        // Prüfen ob es sich um eine Tilemap handelt
        if (!isset($data['frames']) || !isset($data['tileSize'])) {
            // Vielleicht direkt die Frames?
            if (isset($data[0]) && is_array($data[0])) {
                return ['frames' => $data, 'tileSize' => 1];
            }
            return false;
        }
        
        return $data;
    }
    
    /**
     * Generiert ein PNG aus PDI- und JSON-Daten
     * 
     * @param array $pdi_data PDI-Daten
     * @param array $json_data JSON-Daten (Tilemap)
     * @param string $output_path Ausgabepfad
     * @return bool
     */
    private static function generatePng(array $pdi_data, array $json_data, string $output_path): bool {
        // GD-Bibliothek prüfen
        if (!function_exists('imagecreate')) {
            return false;
        }
        
        // Bildgröße bestimmen
        $width = $pdi_data['width'] ?? self::$defaultWidth;
        $height = $pdi_data['height'] ?? self::$defaultHeight;
        
        // Bild erstellen (1-Bit, schwarz-weiß)
        $image = imagecreate($width, $height);
        if (!$image) {
            return false;
        }
        
        // Farben zuweisen
        $white = imagecolorallocate($image, 255, 255, 255);
        $black = imagecolorallocate($image, 0, 0, 0);
        
        // Hintergrund weiß
        imagefill($image, 0, 0, $white);
        
        // Pixel-Daten parsen und setzen
        // PDI-Format: 1 Bit pro Pixel, zeilenweise, jedes Byte = 8 Pixel
        // Bit 0 = linkes Pixel, Bit 7 = rechtes Pixel
        $pixel_data = $pdi_data['pixel_data'];
        $bytes = str_split($pixel_data);
        
        $x = 0;
        $y = 0;
        
        foreach ($bytes as $byte) {
            // Jedes Bit im Byte
            $byte_value = ord($byte);
            
            // 8 Pixel pro Byte (von links nach rechts)
            for ($bit = 0; $bit < 8; $bit++) {
                // Prüfen ob Bit gesetzt ist (1 = schwarz, 0 = weiß)
                $pixel_value = ($byte_value >> (7 - $bit)) & 1;
                
                // Pixel setzen
                if ($pixel_value === 1) {
                    imagesetpixel($image, $x, $y, $black);
                }
                
                $x++;
                
                // Zeilenumbruch
                if ($x >= $width) {
                    $x = 0;
                    $y++;
                    
                    if ($y >= $height) {
                        break 2; // Fertig
                    }
                }
            }
        }
        
        // Falls Tilemap-Daten in JSON vorhanden sind, diese anwenden
        if (isset($json_data['frames']) && is_array($json_data['frames'])) {
            self::applyTilemap($image, $json_data, $width, $height, $black, $white);
        }
        
        // PNG speichern
        $success = imagepng($image, $output_path);
        
        // Speicher freigeben
        imagedestroy($image);
        
        return $success;
    }
    
    /**
     * Wendet Tilemap-Daten auf das Bild an
     * 
     * @param resource $image GD-Bild
     * @param array $json_data JSON-Daten
     * @param int $width Breite
     * @param int $height Höhe
     * @param int $black Schwarze Farbe
     * @param int $white Weiße Farbe
     */
    private static function applyTilemap($image, array $json_data, int $width, int $height, int $black, int $white): void {
        // Tilemap-Daten verarbeiten
        // Annahme: frames ist ein Array mit Pixel-Daten
        if (isset($json_data['frames']) && is_array($json_data['frames'])) {
            foreach ($json_data['frames'] as $frame) {
                if (isset($frame['pixels']) && is_array($frame['pixels'])) {
                    // Direkte Pixel-Daten
                    foreach ($frame['pixels'] as $pixel) {
                        if (isset($pixel['x'], $pixel['y'], $pixel['color'])) {
                            $x = (int)$pixel['x'];
                            $y = (int)$pixel['y'];
                            $color = $pixel['color'] === 1 || $pixel['color'] === 'black' ? $black : $white;
                            
                            if ($x >= 0 && $x < $width && $y >= 0 && $y < $height) {
                                imagesetpixel($image, $x, $y, $color);
                            }
                        }
                    }
                } elseif (isset($frame['x'], $frame['y'], $frame['width'], $frame['height'], $frame['data'])) {
                    // Tile-Daten mit Position und Größe
                    $tile_x = (int)$frame['x'];
                    $tile_y = (int)$frame['y'];
                    $tile_width = (int)$frame['width'];
                    $tile_height = (int)$frame['height'];
                    $tile_data = $frame['data'];
                    
                    for ($ty = 0; $ty < $tile_height; $ty++) {
                        for ($tx = 0; $tx < $tile_width; $tx++) {
                            $index = $ty * $tile_width + $tx;
                            if (isset($tile_data[$index]) && $tile_data[$index] === 1) {
                                $px = $tile_x + $tx;
                                $py = $tile_y + $ty;
                                if ($px >= 0 && $px < $width && $py >= 0 && $py < $height) {
                                    imagesetpixel($image, $px, $py, $black);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    /**
     * Prüft ob GD-Bibliothek verfügbar ist
     * 
     * @return bool
     */
    public static function isGdAvailable(): bool {
        return function_exists('imagecreate') && function_exists('imagepng');
    }
    
    /**
     * Gibt GD-Informationen zurück (für Debugging)
     * 
     * @return array
     */
    public static function getGdInfo(): array {
        if (!function_exists('gd_info')) {
            return ['available' => false, 'message' => 'GD-Bibliothek nicht verfügbar'];
        }
        
        return [
            'available' => true,
            'info' => gd_info()
        ];
    }
}
