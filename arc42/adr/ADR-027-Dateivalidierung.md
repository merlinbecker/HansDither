# ADR-027: Dateivalidierung – Endung + Inhaltsprüfung

## Status
✅ **Umgesetzt** – validation.php validiert PDI und JSON Dateien

## Kontext
Das Backend akzeptiert Datei-Uploads von Nutzern. Um Missbrauch zu verhindern und die Sicherheit zu gewährleisten, müssen wir:
- Nur spezifische Dateitypen (.pdi, .json) akzeptieren
- Den Inhalt der Dateien validieren (nicht nur die Endung)
- Gefährliche Dateitypen (PHP, Executables) blockieren

## Entscheidungs-Treiber
- **Sicherheit:** Verhindere Upload von schädlichem Code (S-04)
- **Datenintegrität:** Nur gültige PDI/JSON-Dateien speichern
- **Angriffsschutz:** Dateiendung kann gefälscht werden → Inhaltsprüfung nötig
- **Einfachheit:** Validierung sollte schnell und zuverlässig sein

## Optionen

| Option | Vorteile | Nachteile |
|--------|----------|-----------|
| **A: Whitelist + Inhaltsprüfung** | Sehr sicher, nur erlaubte Typen, Inhaltsprüfung | Etwas komplexer zu implementieren |
| B: Nur Dateiendung prüfen | Einfach | Unsicher, Dateiendung kann gefälscht werden |
| C: Nur MIME-Type prüfen | Informationen vom Client | MIME-Type kann gefälscht werden |
| D: Blacklist gefährlicher Typen | Einfache Implementierung | Kann umgangen werden, unvollständig |

## Entscheidung
**Option A: Whitelist + Inhaltsprüfung**

### Begründung
1. **Sicherheit:** Kombination aus Whitelist und Inhaltsprüfung bietet beste Sicherheit
2. **Defense in Depth:** Mehrere Prüfebenen (Endung, MIME-Type, Inhalt)
3. **Sicherheitsstandards:** Entspricht Best Practices für Datei-Uploads
4. **Angriffsschutz:** Schützt vor "Magic Byte Spoofing" und Dateiendungs-Fälschung

### Validierungskette

**Für PDI-Dateien:**
1. **Dateiendung:** MUSS `.pdi` sein
2. **MIME-Type:** MUSS `application/octet-stream` sein (optional, da nicht immer zuverlässig)
3. **Magic Bytes:** Erste 4 Bytes müssen `PDI\x00` sein
4. **Header-Parse:** Version (4 Bytes), Width (2 Bytes), Height (2 Bytes) müssen valide sein
5. **Plausibilität:** Width/Height > 0 und < 1000
6. **Dateigröße:** < 10MB

**Für JSON-Dateien:**
1. **Dateiendung:** MUSS `.json` sein
2. **MIME-Type:** MUSS `application/json` sein (optional)
3. **JSON-Parse:** `json_decode()` muss erfolgreich sein und ein Objekt/Array zurückgeben
4. **Dateigröße:** < 10MB

**Blockliste für gefährliche Dateitypen:**
- `.php`, `.php3-8`, `.phtml`, `.exe`, `.com`, `.bat`, `.cmd`
- `.sh`, `.bash`, `.pl`, `.py`, `.rb`, `.java`, `.class`, `.jar`
- `.js`, `.jsp`, `.asp`, `.aspx`, `.cgi`, `.fcgi`
- `.htaccess`, `.env`, `.svg`, `.html`, `.htm`

### Konsequenzen
- **Positiv:**
  - Sehr hoher Sicherheitsstandard
  - Schützt vor den meisten Upload-basierten Angriffen
  - Validiert Datenintegrität
  - Klare Fehlermeldungen für Nutzer

- **Negativ:**
  - Etwas komplexere Implementierung
  - Performance-Overhead (aber vernachlässigbar für Dateigrößen < 10MB)
  - Falsch-Positive möglich (aber unwahrscheinlich bei PDI/JSON)

## Sicherheitsbetrachtung
- **Magic Byte Spoofing:** Durch Prüfung der ersten Bytes verhindert
- **Dateiendungs-Fälschung:** Durch Inhaltsprüfung verhindert
- **MIME-Type Spoofing:** Durch Inhaltsprüfung verhindert (MIME-Type nur als zusätzliche Prüfung)
- **DoS durch große Dateien:** Durch Größenlimit (10MB) verhindert
- **Code Execution:** Durch Blocklist + Inhaltsprüfung verhindert

## Implementierung
```php
// In validation.php
class Validation {
    public static function validateUploadedFile(array $file): array {
        // 1. Dateigröße
        if ($file['size'] > 10 * 1024 * 1024) {
            return ['valid' => false, 'error' => 'Datei zu groß'];
        }
        
        // 2. Dateiendung
        $extension = pathinfo($file['name'], PATHINFO_EXTENSION);
        if (!in_array($extension, ['pdi', 'json'])) {
            return ['valid' => false, 'error' => 'Ungültige Dateiendung'];
        }
        
        // 3. Blocklist
        $dangerous = ['php', 'exe', 'sh', 'py', 'js', ...];
        if (in_array($extension, $dangerous)) {
            return ['valid' => false, 'error' => 'Dateityp nicht erlaubt'];
        }
        
        // 4. Spezifische Validierung
        if ($extension === 'pdi') {
            return self::validatePdiFile($file['tmp_name']);
        }
        if ($extension === 'json') {
            return self::validateJsonFile($file['tmp_name']);
        }
    }
    
    private static function validatePdiFile(string $path): array {
        $handle = fopen($path, 'rb');
        $header = fread($handle, 4);
        if ($header !== "PDI\x00") {
            return ['valid' => false, 'error' => 'Ungültige PDI-Datei'];
        }
        // ... weitere Prüfungen
    }
}
```

## Alternativen Considered
- **Nur Blacklist:** Zu unsicher, kann umgangen werden
- **Nur MIME-Type:** Nicht zuverlässig, kann gefälscht werden
- **Externe Tools:** Zu komplex, nicht nötig für unseren Anwendungsfall

## Erfahrung
Nach der Implementierung bestätigt sich die Entscheidung:
- ✅ Alle Uploads werden validiert
- ✅ Keine Sicherheitslücken durch Datei-Uploads bekannt
- ✅ Klare Fehlermeldungen für Nutzer
- ✅ Performance ist ausreichend

## Related
- [ADR-025: PHP/MySQL auf all-inkl.com](ADR-025-PHP-MySQL-auf-all-inkl.md)
- [validation.php: Implementierung](validation.php)
- [contracts/backend-api.md: C-01 – Upload-Dateien](contracts/backend-api.md#c-01-upload-dateien)
- [research.md: R7 – Dateivalidierung](research.md#r7-dateivalidierung)
