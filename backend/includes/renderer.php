<?php
/**
 * Hans Dither Backend - Renderer
 *
 * Rekonstruiert die Tilemap aus sheet.pdi (Playdate-SDK-Format, Spec 001) +
 * frames.json und rendert:
 *   - PNG (400×240, 1-Bit-Look): Frame 1 — via GD
 *   - animiertes GIF: alle Frames, je Tilemap-Frame ein GIF-Frame — via GifEncoder
 *
 * Spec 001 Datenmodell:
 *   - sheet.pdi: ein 1-Bit-Image; 25 Tiles pro Zeile, Zellgröße 16×16 px.
 *     Tile n (1-basiert) liegt bei Zelle ((n-1) % 25, ⌊(n-1) / 25⌋).
 *   - frames.json: gridWidth=25, gridHeight=15, tileCount, frames[f] =
 *     375 1-basierte Tile-Indizes (links→rechts, oben→unten).
 *   - Ungültige Indizes → Fallback auf Tile 1 (Voll-Weiß).
 */

require_once __DIR__ . '/database.php';
require_once __DIR__ . '/upload_handler.php';
require_once __DIR__ . '/pdi_parser.php';
require_once __DIR__ . '/gif_encoder.php';

class Renderer {

    /** Playdate-Display (Spec 001 / FR-010) */
    private static $canvasWidth = 400;
    private static $canvasHeight = 240;

    /** Spec 001: Tile-Raster */
    private static $tileSize = 16;
    private static $tilesPerRow = 25;

    /**
     * Rendert Frame 1 eines Images zu PNG (on-demand)
     *
     * @param string $image_id Image-UUID
     * @param string $uid UID des Nutzers (für Berechtigungsprüfung)
     * @return string|false Pfad zur generierten PNG oder false bei Fehler
     */
    public static function renderToPng(string $image_id, string $uid) {
        $image = UploadHandler::getImage($image_id, $uid);
        if (!$image) {
            return false;
        }

        if ($image['png_path'] && file_exists($image['png_path'])) {
            return $image['png_path'];
        }

        $assets = self::loadAssets($image);
        if (!$assets) {
            return false;
        }

        $rows = self::composeFrame($assets, 0);
        if (!$rows) {
            return false;
        }

        $png_path = $image['pdi_path'] . '.png';
        if (!self::writePng($rows, $png_path)) {
            return false;
        }

        UploadHandler::savePngPath($image_id, $png_path);
        return $png_path;
    }

    /**
     * Rendert alle Frames eines Images zu einem animierten GIF (on-demand)
     *
     * @param string $image_id Image-UUID
     * @param string $uid UID des Nutzers
     * @return string|false Pfad zum generierten GIF oder false bei Fehler
     */
    public static function renderToGif(string $image_id, string $uid) {
        $image = UploadHandler::getImage($image_id, $uid);
        if (!$image) {
            return false;
        }

        if (!empty($image['gif_path']) && file_exists($image['gif_path'])) {
            return $image['gif_path'];
        }

        $assets = self::loadAssets($image);
        if (!$assets) {
            return false;
        }

        $frames = [];
        $frame_count = count($assets['frames']);
        for ($f = 0; $f < $frame_count; $f++) {
            $rows = self::composeFrame($assets, $f);
            if (!$rows) {
                return false;
            }
            $frames[] = $rows;
        }

        $delay_ms = defined('GIF_FRAME_DELAY_MS') ? GIF_FRAME_DELAY_MS : 200;
        $gif_path = $image['pdi_path'] . '.gif';

        if (!GifEncoder::encodeToFile($gif_path, self::$canvasWidth, self::$canvasHeight, $frames, $delay_ms)) {
            return false;
        }

        UploadHandler::saveGifPath($image_id, $gif_path);
        return $gif_path;
    }

    /**
     * Lädt sheet.pdi + frames.json und schneidet die Tiles zurecht
     *
     * @param array $image Image-Datensatz (pdi_path, json_path)
     * @return array|false ['tiles' => [tileIndex1based => rows[16] à 16 Zeichen], 'frames' => array, 'tileCount' => int]
     */
    private static function loadAssets(array $image) {
        $sheet = PdiParser::parseFile($image['pdi_path']);
        if (!$sheet) {
            return false;
        }

        $json_raw = file_get_contents($image['json_path']);
        if ($json_raw === false) {
            return false;
        }
        $meta = json_decode($json_raw, true);
        if (!is_array($meta) || !isset($meta['frames']) || !is_array($meta['frames']) || empty($meta['frames'])) {
            return false;
        }

        $grid_w = (int)($meta['gridWidth'] ?? self::$tilesPerRow);
        $grid_h = (int)($meta['gridHeight'] ?? 15);
        $tile_count = (int)($meta['tileCount'] ?? 0);

        if ($grid_w <= 0 || $grid_h <= 0) {
            return false;
        }

        // Tiles aus dem Sheet slicen (Spec 001: 25 Tiles/Zeile, 16×16)
        $ts = self::$tileSize;
        $sheet_tiles_per_row = max(1, intdiv($sheet['width'], $ts));
        $max_tiles = $sheet_tiles_per_row * intdiv($sheet['height'], $ts);
        if ($tile_count <= 0 || $tile_count > $max_tiles) {
            $tile_count = $max_tiles;
        }

        $tiles = [];
        for ($n = 1; $n <= $tile_count; $n++) {
            $cell_x = (($n - 1) % $sheet_tiles_per_row) * $ts;
            $cell_y = intdiv($n - 1, $sheet_tiles_per_row) * $ts;

            $tile_rows = [];
            for ($y = 0; $y < $ts; $y++) {
                $tile_rows[] = substr($sheet['rows'][$cell_y + $y], $cell_x, $ts);
            }
            $tiles[$n] = $tile_rows;
        }

        return [
            'tiles' => $tiles,
            'frames' => array_values($meta['frames']),
            'tileCount' => $tile_count,
            'gridWidth' => $grid_w,
            'gridHeight' => $grid_h,
        ];
    }

    /**
     * Setzt einen Frame aus Tiles zum 400×240-Canvas zusammen
     *
     * @param array $assets Ergebnis von loadAssets()
     * @param int $frame_index 0-basierter Frame-Index
     * @return array|false Zeilen-Strings ('1' = weiß, '0' = schwarz) oder false
     */
    private static function composeFrame(array $assets, int $frame_index) {
        if (!isset($assets['frames'][$frame_index]) || !is_array($assets['frames'][$frame_index])) {
            return false;
        }

        $indices = array_values($assets['frames'][$frame_index]);
        $grid_w = $assets['gridWidth'];
        $grid_h = $assets['gridHeight'];
        $ts = self::$tileSize;
        $white_tile = array_fill(0, $ts, str_repeat('1', $ts));

        // Canvas mit Weiß initialisieren
        $rows = array_fill(0, self::$canvasHeight, str_repeat('1', self::$canvasWidth));

        for ($gy = 0; $gy < $grid_h; $gy++) {
            for ($gx = 0; $gx < $grid_w; $gx++) {
                $idx = $indices[$gy * $grid_w + $gx] ?? 1;

                // Spec 001: ungültiger Index → Fallback Tile 1 (Weiß)
                $tile = $assets['tiles'][$idx] ?? $white_tile;

                $px = $gx * $ts;
                $py = $gy * $ts;
                if ($px + $ts > self::$canvasWidth || $py + $ts > self::$canvasHeight) {
                    continue;
                }

                for ($y = 0; $y < $ts; $y++) {
                    $rows[$py + $y] = substr_replace($rows[$py + $y], $tile[$y], $px, $ts);
                }
            }
        }

        return $rows;
    }

    /**
     * Schreibt Pixel-Zeilen als PNG (via GD)
     */
    private static function writePng(array $rows, string $output_path): bool {
        if (!function_exists('imagecreate')) {
            return false;
        }

        $width = self::$canvasWidth;
        $height = self::$canvasHeight;

        $image = imagecreate($width, $height);
        if (!$image) {
            return false;
        }

        $white = imagecolorallocate($image, 255, 255, 255);
        $black = imagecolorallocate($image, 0, 0, 0);
        imagefill($image, 0, 0, $white);

        for ($y = 0; $y < $height; $y++) {
            $row = $rows[$y];
            for ($x = 0; $x < $width; $x++) {
                if ($row[$x] === '0') {
                    imagesetpixel($image, $x, $y, $black);
                }
            }
        }

        $success = imagepng($image, $output_path);
        imagedestroy($image);

        return $success;
    }

    /**
     * Prüft ob GD-Bibliothek verfügbar ist
     */
    public static function isGdAvailable(): bool {
        return function_exists('imagecreate') && function_exists('imagepng');
    }
}
