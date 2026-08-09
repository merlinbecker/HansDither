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
     * Rendert einen einzelnen Frame eines Images zu PNG (on-demand)
     *
     * Spec 009 FR-010: nicht mehr auf Frame 0 beschränkt. Frame-Index ist
     * 0-basiert (spec.md Clarifications). Dateiname folgt der in
     * data-model.md Abschnitt 2 definierten Konvention: `{base}.png` für
     * Frame 0 (unverändert, weiterhin über die png_path-Spalte gecacht),
     * `{base}-frame-{N}.png` für Frame N >= 1 (rein dateisystembasiert,
     * keine DB-Spalte — data-model.md Abschnitt 3, research.md R5).
     *
     * @param string $image_id Image-UUID
     * @param string $uid UID des Nutzers (für Berechtigungsprüfung)
     * @param int $frameIndex 0-basierter Frame-Index
     * @return string|false Pfad zur generierten PNG oder false bei Fehler
     */
    public static function renderFrameToPng(string $image_id, string $uid, int $frameIndex = 0) {
        $image = UploadHandler::getImage($image_id, $uid);
        if (!$image) {
            return false;
        }

        $base = basename($image['pdi_path'], '.pdi');
        $upload_dir = dirname($image['pdi_path']);
        $png_path = $frameIndex === 0
            ? $upload_dir . '/' . $base . '.png'
            : $upload_dir . '/' . $base . '-frame-' . $frameIndex . '.png';

        if ($frameIndex === 0) {
            if ($image['png_path'] && file_exists($image['png_path'])) {
                return $image['png_path'];
            }
        } elseif (file_exists($png_path)) {
            return $png_path;
        }

        $assets = self::loadAssets($image);
        if (!$assets) {
            return false;
        }

        $rows = self::composeFrame($assets, $frameIndex);
        if (!$rows) {
            return false;
        }

        if (!self::writePng($rows, $png_path)) {
            return false;
        }

        if ($frameIndex === 0) {
            UploadHandler::savePngPath($image_id, $png_path);
        }

        return $png_path;
    }

    /**
     * Rendert die Tile-Sammlung (Tilemap/Imagetable) eines Images zu PNG,
     * in der Playdate-SDK-Namenskonvention für Matrix-Imagetables
     * (Spec 009 FR-011, research.md R6). Schreibt die aus sheet.pdi
     * geparsten Roh-Pixelzeilen 1:1 als PNG — kein Tile-Slicing nötig, die
     * Tilemap-PNG hat exakt dieselben Abmessungen wie das Sheet.
     *
     * @param string $image_id Image-UUID
     * @param string $uid UID des Nutzers (für Berechtigungsprüfung)
     * @return string|false Pfad zur generierten PNG oder false bei Fehler
     */
    public static function renderTilemapToPng(string $image_id, string $uid) {
        $image = UploadHandler::getImage($image_id, $uid);
        if (!$image) {
            return false;
        }

        $base = basename($image['pdi_path'], '.pdi');
        $upload_dir = dirname($image['pdi_path']);
        $tilemap_path = $upload_dir . '/' . $base . '-table-16-16.png';

        if (file_exists($tilemap_path)) {
            return $tilemap_path;
        }

        $sheet = PdiParser::parseFile($image['pdi_path']);
        if (!$sheet) {
            return false;
        }

        if (!self::writePng($sheet['rows'], $tilemap_path)) {
            return false;
        }

        return $tilemap_path;
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
        // Spec 009 research.md R5: Bestandsfehler behoben — vorher wurde die
        // Endung direkt an pdi_path angehängt ({basis}.pdi.gif), jetzt an die
        // gemeinsame Basis ({basis}.gif, data-model.md Abschnitt 2).
        $base = basename($image['pdi_path'], '.pdi');
        $upload_dir = dirname($image['pdi_path']);
        $gif_path = $upload_dir . '/' . $base . '.gif';

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
     *
     * Spec 009 research.md R6: Breite/Höhe werden aus den übergebenen
     * $rows abgeleitet statt fest auf den 400×240-Canvas verdrahtet zu
     * sein — Voraussetzung für die Tilemap-PNG (renderTilemapToPng()),
     * deren Abmessungen von der Sheet-Größe abhängen, nicht vom Canvas.
     */
    private static function writePng(array $rows, string $output_path): bool {
        if (!function_exists('imagecreate')) {
            return false;
        }
        if (empty($rows)) {
            return false;
        }

        $height = count($rows);
        $width = strlen($rows[0]);

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
