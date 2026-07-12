# ADR-028: PNG-Rendering via GD-Bibliothek

## Status
✅ **Umgesetzt** – renderer.php generiert PNGs on-demand mit GD

## Kontext
Das Backend muss hochgeladene PDI- und JSON-Dateien als PNG-Bilder ausliefern können, damit Nutzer ihre Hans-Dither-Projekte in einem Standardformat anzeigen und herunterladen können. Die Herausforderung:
- PDI-Format parsen (Magic Bytes, Header, Pixel-Daten)
- JSON-Tilemap-Daten interpretieren
- PNG mit korrekten Abmessungen (400x240) generieren
- Auf Shared Hosting (all-inkl.com) laufen

## Entscheidungs-Treiber
- **Verfügbarkeit:** GD-Bibliothek ist bei all-inkl.com standardmäßig aktiviert
- **Einfachheit:** GD ist in PHP eingebaut, keine externen Abhängigkeiten
- **Performance:** GD ist für einfache Bildbearbeitung optimiert
- **Kompatibilität:** Funktioniert mit PHP 8.x auf Shared Hosting

## Optionen

| Option | Vorteile | Nachteile |
|--------|----------|-----------|
| **A: GD-Bibliothek** | Standard in PHP, all-inkl.com-kompatibel, einfach | Etwas eingeschränkte Funktionen |
| B: Imagick | Sehr mächtig, unterstützt viele Formate | Nicht standardmäßig bei all-inkl.com, externe Bibliothek |
| C: Externer Rendering-Service | Keine Serverlast, Skalierbar | Externe Abhängigkeit, Kosten, Komplexität |
| D: Node.js mit Canvas | Moderne Lösung | Nicht PHP-basiert, Hosting-Probleme |
| E: Python mit PIL | Gut für Bildbearbeitung | Nicht bei all-inkl.com verfügbar |

## Entscheidung
**Option A: GD-Bibliothek**

### Begründung
1. **all-inkl.com Kompatibilität:** GD ist bei all-inkl.com standardmäßig installiert und aktiviert
2. **Keine Abhängigkeiten:** GD ist Teil der PHP-Kern-Erweiterungen
3. **Einfache Nutzung:** Gut dokumentiert, einfache API
4. **Ausreichende Funktionen:** Für unsere Anforderungen (1-Bit PNG, 400x240) völlig ausreichend
5. **Performance:** Schnell genug für on-demand Rendering

### Implementierung
```php
class Renderer {
    public static function renderToPng(string $image_id, string $uid) {
        // 1. Image-Daten abrufen
        $image = UploadHandler::getImage($image_id, $uid);
        
        // 2. Falls PNG bereits existiert: zurückgeben
        if ($image['png_path'] && file_exists($image['png_path'])) {
            return $image['png_path'];
        }
        
        // 3. PDI parsen
        $pdi_data = self::loadPdiFile($image['pdi_path']);
        
        // 4. JSON parsen
        $json_data = self::loadJsonFile($image['json_path']);
        
        // 5. PNG generieren
        $png_path = $image['pdi_path'] . '.png';
        self::generatePng($pdi_data, $json_data, $png_path);
        
        // 6. Pfad in DB speichern
        UploadHandler::savePngPath($image_id, $png_path);
        
        return $png_path;
    }
    
    private static function generatePng(array $pdi_data, array $json_data, string $output_path): bool {
        $width = $pdi_data['width'] ?? 400;
        $height = $pdi_data['height'] ?? 240;
        
        $image = imagecreate($width, $height);
        $white = imagecolorallocate($image, 255, 255, 255);
        $black = imagecolorallocate($image, 0, 0, 0);
        
        // Pixel aus PDI-Daten setzen
        $bytes = str_split($pdi_data['pixel_data']);
        $x = $y = 0;
        foreach ($bytes as $byte) {
            $byte_value = ord($byte);
            for ($bit = 0; $bit < 8; $bit++) {
                $pixel_value = ($byte_value >> (7 - $bit)) & 1;
                if ($pixel_value === 1) {
                    imagesetpixel($image, $x, $y, $black);
                }
                $x++;
                if ($x >= $width) {
                    $x = 0;
                    $y++;
                }
            }
        }
        
        // Tilemap-Daten anwenden (falls vorhanden)
        if (isset($json_data['frames'])) {
            self::applyTilemap($image, $json_data, $width, $height, $black, $white);
        }
        
        return imagepng($image, $output_path);
    }
}
```

### Konsequenzen
- **Positiv:**
  - Einfache, robuste Implementierung
  - Keine externen Abhängigkeiten
  - Funktioniert auf all-inkl.com
  - On-demand Rendering spart Ressourcen

- **Negativ:**
  - GD hat Einschränkungen bei komplexen Bildbearbeitungen (aber für uns irrelevant)
  - 1-Bit PNG ist nicht direkt unterstütz, aber wir können mit Schwarz-Weiß arbeiten
  - Keine Transparenz-Unterstützung (aber für Hans Dither nicht benötigt)

## PNG-Format Details
- **Abmessungen:** 400x240 Pixel (Playdate Display)
- **Farbtiefe:** 8-Bit (in GD), aber effektiv 1-Bit (nur schwarz/weiß)
- **Farben:**
  - Hintergrund: Weiß (255, 255, 255)
  - Vordergrund: Schwarz (0, 0, 0)
- **Dateigröße:** ~2-10KB (komprimiert)

## On-Demand vs. Eager Rendering

| Ansatz | Vorteile | Nachteile |
|--------|----------|-----------|
| **On-Demand (gewählt)** | Spart Server-Ressourcen, PNG nur bei Bedarf | Erster Download langsam |
| Eager (sofort) | PNG sofort verfügbar | Serverlast bei Upload, Speicherbedarf |

**Entscheidung für On-Demand:**
- Nutzer laden nicht immer alle PNGs herunter
- Speicherplatz wird gespart
- Upload bleibt schnell
- Erste Anfrage kann etwas langsamer sein (akzeptabel für unsere Use Case)

## Sicherheitsbetrachtung
- **Keine Code Execution:** GD-Bibliothek führt keinen Code aus
- **Speicher-Limits:** GD hat interne Limits, die DoS-Angriffe verhindern
- **Dateivalidierung:** Nur validierte PDI/JSON-Dateien werden verarbeitet

## Alternativen Considered
- **Imagick:** Mächtiger, aber nicht garantiert bei all-inkl.com
- **Externer Service:** Zu komplex, externe Abhängigkeit
- **Node.js/Python:** Hosting-Probleme bei all-inkl.com

## Erfahrung
Nach der Implementierung bestätigt sich die Entscheidung:
- ✅ GD ist bei all-inkl.com verfügbar
- ✅ Performance ist ausreichend (PNG-Generierung < 1 Sekunde)
- ✅ Einfache Integration in PHP
- ✅ Qualitativ hochwertige PNGs

## Related
- [ADR-025: PHP/MySQL auf all-inkl.com](ADR-025-PHP-MySQL-auf-all-inkl.md)
- [renderer.php: Implementierung](renderer.php)
- [contracts/backend-api.md: E-08 – PNG Download](contracts/backend-api.md#e-08-get-downloadpngid)
- [research.md: R3 – PNG-Rendering](research.md#r3-png-rendering)
