<?php
/**
 * Hans Dither Backend - Animierter GIF-Encoder (GIF89a)
 *
 * Reines PHP ohne Imagick (Shared-Hosting-sicher; GD kann keine animierten GIFs).
 * Auf 2-Farben-Frames (1-Bit) spezialisiert: Palette Index 0 = weiß, 1 = schwarz.
 * Endlos-Loop via NETSCAPE2.0-Extension, Frame-Delay pro Aufruf konfigurierbar.
 */

class GifEncoder {

    /**
     * Baut ein animiertes GIF aus 1-Bit-Frames
     *
     * @param int $width Bildbreite
     * @param int $height Bildhöhe
     * @param array $frames Array von Frames; jeder Frame ist ein Array von Zeilen-Strings
     *                      ('1' = weiß, '0' = schwarz) — Format von PdiParser/Renderer
     * @param int $delay_ms Anzeigedauer pro Frame in Millisekunden
     * @return string|false GIF-Binärdaten oder false
     */
    public static function encode(int $width, int $height, array $frames, int $delay_ms = 200) {
        if ($width <= 0 || $height <= 0 || empty($frames)) {
            return false;
        }

        $delay_cs = max(2, (int)round($delay_ms / 10)); // GIF-Delay in 1/100s, min. 2

        $gif = 'GIF89a';

        // Logical Screen Descriptor: globale Farbtabelle, 2 Einträge
        $gif .= pack('v', $width) . pack('v', $height);
        $gif .= chr(0xF0);        // GCT vorhanden, Farbauflösung 8 Bit, GCT-Größe 2^(0+1)=2
        $gif .= chr(0) . chr(0);  // Hintergrund-Index, Pixel-Aspect

        // Globale Farbtabelle: 0 = weiß, 1 = schwarz
        $gif .= "\xFF\xFF\xFF" . "\x00\x00\x00";

        // NETSCAPE2.0: Endlos-Loop (nur bei Animation nötig, schadet bei 1 Frame nicht)
        if (count($frames) > 1) {
            $gif .= "\x21\xFF\x0BNETSCAPE2.0\x03\x01\x00\x00\x00";
        }

        foreach ($frames as $rows) {
            if (count($rows) !== $height) {
                return false;
            }

            // Graphic Control Extension: Delay, keine Transparenz, disposal "do not dispose"
            $gif .= "\x21\xF9\x04" . chr(0x04) . pack('v', $delay_cs) . "\x00\x00";

            // Image Descriptor: volle Fläche, keine lokale Farbtabelle
            $gif .= "\x2C" . pack('v', 0) . pack('v', 0) . pack('v', $width) . pack('v', $height) . "\x00";

            // Pixel-Indizes: '1' (weiß) → 0, '0' (schwarz) → 1
            $indices = '';
            foreach ($rows as $row) {
                // strtr auf dem Zeilen-String ist deutlich schneller als Zeichen-Schleife
                $indices .= strtr(substr($row, 0, $width), ['1' => "\x00", '0' => "\x01"]);
            }

            $gif .= self::lzwEncode($indices, 2);
        }

        $gif .= "\x3B"; // Trailer

        return $gif;
    }

    /**
     * Schreibt das GIF direkt in eine Datei
     */
    public static function encodeToFile(string $path, int $width, int $height, array $frames, int $delay_ms = 200): bool {
        $data = self::encode($width, $height, $frames, $delay_ms);
        if ($data === false) {
            return false;
        }
        return file_put_contents($path, $data) !== false;
    }

    /**
     * GIF-LZW-Kodierung (Standard-Algorithmus, variable Codebreite, max. 12 Bit)
     *
     * @param string $indices Ein Byte pro Pixel (Palettenindex)
     * @param int $min_code_size Mindest-Codegröße (2 für 2-Farben-Palette)
     * @return string min_code_size-Byte + Daten-Subblöcke + Block-Terminator
     */
    private static function lzwEncode(string $indices, int $min_code_size): string {
        $clear_code = 1 << $min_code_size;       // 4
        $eoi_code = $clear_code + 1;             // 5
        $next_code = $eoi_code + 1;              // 6
        $code_size = $min_code_size + 1;         // 3 Bit

        $dict = [];
        $bitbuf = 0;
        $bitcount = 0;
        $out = '';

        $emit = function (int $code) use (&$bitbuf, &$bitcount, &$out, &$code_size) {
            $bitbuf |= $code << $bitcount;
            $bitcount += $code_size;
            while ($bitcount >= 8) {
                $out .= chr($bitbuf & 0xFF);
                $bitbuf >>= 8;
                $bitcount -= 8;
            }
        };

        $emit($clear_code);

        $len = strlen($indices);
        $prefix = $indices[0];

        for ($i = 1; $i < $len; $i++) {
            $ch = $indices[$i];
            $candidate = $prefix . $ch;

            if (isset($dict[$candidate])) {
                $prefix = $candidate;
                continue;
            }

            // Prefix-Code ausgeben (Einzelzeichen = Palettenindex selbst)
            $emit(strlen($prefix) === 1 ? ord($prefix) : $dict[$prefix]);

            $dict[$candidate] = $next_code++;

            // Codebreite wächst, wenn der nächste Code sie überschreiten würde
            if ($next_code > (1 << $code_size) && $code_size < 12) {
                $code_size++;
            }

            // Wörterbuch voll → Clear und neu beginnen
            if ($next_code >= 4096) {
                $emit($clear_code);
                $dict = [];
                $next_code = $eoi_code + 1;
                $code_size = $min_code_size + 1;
            }

            $prefix = $ch;
        }

        $emit(strlen($prefix) === 1 ? ord($prefix) : $dict[$prefix]);
        $emit($eoi_code);

        // Restbits flushen
        if ($bitcount > 0) {
            $out .= chr($bitbuf & 0xFF);
        }

        // In 255-Byte-Subblöcke verpacken
        $packed = chr($min_code_size);
        foreach (str_split($out, 255) as $chunk) {
            $packed .= chr(strlen($chunk)) . $chunk;
        }
        $packed .= "\x00";

        return $packed;
    }
}
