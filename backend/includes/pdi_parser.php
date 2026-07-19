<?php
/**
 * Hans Dither Backend - Playdate PDI-Parser
 *
 * Parst das echte Playdate-SDK-Bildformat (.pdi), wie es
 * playdate.datastore.writeImage() schreibt (Spec 001).
 *
 * Format (siehe https://github.com/jaames/playdate-reverse-engineering/blob/main/formats/pdi.md):
 *   - 12 Bytes Magic: "Playdate IMG"
 *   - uint32 LE Flags: Bit 0x80000000 = zlib-komprimiert
 *   - falls komprimiert: uint32 LE ×4 (decompressed_size, width, height, reserved),
 *     danach zlib-Stream mit den Cell-Daten
 *   - Cell-Daten: 8×uint16 LE (clip_width, clip_height, stride, clip_left,
 *     clip_right, clip_top, clip_bottom, flags); flags & 0x3 = Alpha-Maske vorhanden.
 *     Danach Farb-Bitmap (stride × clip_height Bytes, 1 Bit/Pixel, MSB zuerst,
 *     1 = weiß, 0 = schwarz), optional gefolgt von gleich großer Alpha-Bitmap
 *     (1 = opak, 0 = transparent).
 */

class PdiParser {

    const MAGIC = 'Playdate IMG';
    const FLAG_COMPRESSED = 0x80000000;

    /**
     * Prüft, ob eine Datei das PDI-Magic trägt (leichtgewichtig, für Upload-Validierung)
     */
    public static function hasValidMagic(string $file_path): bool {
        $handle = fopen($file_path, 'rb');
        if (!$handle) {
            return false;
        }
        $magic = fread($handle, 12);
        fclose($handle);
        return $magic === self::MAGIC;
    }

    /**
     * Parst eine PDI-Datei vollständig
     *
     * @param string $file_path Pfad zur .pdi-Datei
     * @return array|false ['width', 'height', 'rows'] oder false.
     *         rows: Array von Strings (ein Zeichen pro Pixel, '1' = weiß, '0' = schwarz);
     *         transparente Pixel (Alpha-Maske) werden als weiß ('1') geliefert.
     */
    public static function parseFile(string $file_path) {
        $data = file_get_contents($file_path);
        if ($data === false) {
            return false;
        }
        return self::parse($data);
    }

    /**
     * Parst PDI-Binärdaten
     *
     * @param string $data Roh-Inhalt der .pdi-Datei
     * @return array|false siehe parseFile()
     */
    public static function parse(string $data) {
        if (strlen($data) < 16 || substr($data, 0, 12) !== self::MAGIC) {
            return false;
        }

        $flags = unpack('V', substr($data, 12, 4))[1];
        $offset = 16;

        if ($flags & self::FLAG_COMPRESSED) {
            if (strlen($data) < 32) {
                return false;
            }
            // Prä-Header: decompressed_size, width, height, reserved (je uint32 LE)
            $offset += 16;
            $cell_data = @gzuncompress(substr($data, $offset));
            if ($cell_data === false) {
                return false;
            }
        } else {
            $cell_data = substr($data, $offset);
        }

        return self::parseCell($cell_data);
    }

    /**
     * Parst die Cell-Daten (unkomprimiert) zu Pixel-Zeilen
     */
    private static function parseCell(string $cell) {
        if (strlen($cell) < 16) {
            return false;
        }

        $h = unpack('v8', substr($cell, 0, 16));
        $clip_width  = $h[1];
        $clip_height = $h[2];
        $stride      = $h[3];
        $clip_left   = $h[4];
        $clip_right  = $h[5];
        $clip_top    = $h[6];
        $clip_bottom = $h[7];
        $flags       = $h[8];

        $has_alpha = ($flags & 0x3) > 0;
        $color_size = $stride * $clip_height;

        $needed = 16 + $color_size * ($has_alpha ? 2 : 1);
        if (strlen($cell) < $needed) {
            return false;
        }

        $color_data = substr($cell, 16, $color_size);
        $alpha_data = $has_alpha ? substr($cell, 16 + $color_size, $color_size) : null;

        $full_width  = $clip_left + $clip_width + $clip_right;
        $full_height = $clip_top + $clip_height + $clip_bottom;

        if ($full_width <= 0 || $full_height <= 0) {
            return false;
        }

        $rows = [];
        for ($y = 0; $y < $full_height; $y++) {
            $row = str_repeat('1', $full_width); // Default: weiß (wie Referenz-Konverter)

            $cy = $y - $clip_top;
            if ($cy >= 0 && $cy < $clip_height) {
                $row_offset = $cy * $stride;
                for ($x = 0; $x < $clip_width; $x++) {
                    $byte = ord($color_data[$row_offset + intdiv($x, 8)]);
                    $bit = ($byte >> (7 - ($x % 8))) & 1;

                    if ($alpha_data !== null) {
                        $abyte = ord($alpha_data[$row_offset + intdiv($x, 8)]);
                        $abit = ($abyte >> (7 - ($x % 8))) & 1;
                        if ($abit === 0) {
                            continue; // transparent → weiß lassen
                        }
                    }

                    $row[$clip_left + $x] = $bit === 1 ? '1' : '0';
                }
            }

            $rows[] = $row;
        }

        return [
            'width' => $full_width,
            'height' => $full_height,
            'rows' => $rows,
        ];
    }
}
