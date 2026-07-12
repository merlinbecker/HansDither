# ADR-026: PIN-Hashing mit bcrypt

## Status
✅ **Umgesetzt** – PINs werden mit `password_hash()` (bcrypt) gehasht

## Kontext
Das Backend benötigt eine sichere Methode, um die 4-stelligen PINs der Nutzer zu speichern. Da es sich um eine einfache, aber sicherheitsrelevante Anwendung handelt, müssen wir:
- PINs NIEMALS im Klartext speichern
- Ein robustes Hashing-Verfahren verwenden
- Brute-Force-Angriffe erschweren

## Entscheidungs-Treiber
- **Sicherheit:** PINs sind Authentifizierungsmerkmale und müssen geschützt werden
- **Einfachheit:** PHP bietet eingebaute Hashing-Funktionen
- **Kompatibilität:** bcrypt ist in PHP 8.x standardmäßig verfügbar
- **Performance:** bcrypt ist für Passwörter optimiert (langsamere Hashing für Brute-Force-Schutz)

## Optionen

| Option | Vorteile | Nachteile |
|--------|----------|-----------|
| **A: bcrypt (PASSWORD_BCRYPT)** | Standard für Passwörter, salten Hash, langsamer (Brute-Force-Schutz), in PHP eingebaut | Etwas langsamer als andere Methoden |
| B: SHA-256/SHA-512 | Schnell, kryptographisch sicher | Nicht für Passwörter optimiert, kein Salt, anfällig für Rainbow Tables |
| C: md5 + Salt | Einfach | md5 gilt als unsicher, nicht für Passwörter empfohlen |
| D: argon2 | Modernster Algorithmus, Speicher-hungrig (DoS-Schutz) | Nicht bei allen PHP-Installationen verfügbar (benötigt PHP 7.2+) |

## Entscheidung
**Option A: bcrypt mit PASSWORD_BCRYPT**

### Begründung
1. **PHP-Standard:** `password_hash()` und `password_verify()` sind Kernfunktionen von PHP
2. **Sicher:** bcrypt verwendet automatisches Salt und ist gegen Brute-Force resistent
3. **Allgemein akzeptiert:** bcrypt ist der De-facto-Standard für Passwort-Hashing
4. **Einfach:** Einzeilige Implementierung: `password_hash($pin, PASSWORD_BCRYPT)`

### Implementierung
```php
// Pairing: PIN hashen
$pin_hash = password_hash($pin, PASSWORD_BCRYPT);

// Login: PIN prüfen
if (password_verify($input_pin, $stored_hash)) {
    // Erfolg
}
```

### Konsequenzen
- **Positiv:**
  - Sehr sichere Speicherung der PINs
  - Einfache Implementierung
  - zukunftssicher (bcrypt bleibt State-of-the-Art)
  - Keine externen Abhängigkeiten

- **Negativ:**
  - Etwas langsamer als SHA-256 (aber für 4-stellige PINs vernachlässigbar)
  - Cost-Faktor standardmäßig auf 10 (kann bei Bedarf angepasst werden)

## Sicherheitsbetrachtung
- **Brute-Force-Schutz:** bcrypt ist bewusst langsam (ca. 0.1s pro Hash), was Angriffe erschwert
- **4-stellige PIN:** 10.000 Kombinationen → mit Rate-Limiting (3 Versuche/5 Min) effektiv geschützt
- **Salting:** Automatisch durch bcrypt, jeder Hash ist einzigartig
- **Rainbow Tables:** bcrypt ist resistent gegen Rainbow-Tables

## Alternativen Considered
- **argon2:** Noch sicherer, aber nicht bei allen Shared-Hosting-Anbietern verfügbar
- **SHA-256:** Zu schnell für Passwörter, anfällig für Brute-Force
- **md5:** Unsicher, nicht empfohlen

## Erfahrung
Nach der Implementierung bestätigt sich die Entscheidung:
- ✅ Einfache Integration in PHP
- ✅ Sichere Speicherung der PINs
- ✅ Keine Probleme mit all-inkl.com Hosting
- ✅ Kompatibel mit bestehenden PHP-Installationen

## Related
- [ADR-025: PHP/MySQL auf all-inkl.com](ADR-025-PHP-MySQL-auf-all-inkl.md)
- [auth.php: Implementierung](auth.php)
- [research.md: R6 – PIN-Hashing](research.md#r6-pin-hashing-strategie)
