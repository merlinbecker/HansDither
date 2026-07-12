# ADR-025: PHP/MySQL auf all-inkl.com Hosting

## Status
✅ **Umgesetzt** – Backend läuft auf PHP 8.x + MySQL 8.x bei all-inkl.com

## Kontext
Wir benötigen ein Backend für die Synchronisation von Hans-Dither-Projekten zwischen Playdate-Geräten und einer Web-UI. Das Backend muss:
- Einfache Datei-Uploads (PDI + JSON) verarbeiten
- Authentifizierung via UID + PIN bereitstellen
- PNG-Rendering serverseitig durchführen
- Auf Shared Hosting (all-inkl.com) laufen

## Entscheidungs-Treiber
- **Kosten:** all-inkl.com bietet günstiges Shared Hosting mit PHP/MySQL
- **Einfachheit:** Keine Frameworks → maximale Kompatibilität mit Shared Hosting
- **Verfügbarkeit:** PHP und MySQL sind standardmäßig bei all-inkl.com verfügbar
- **Wartbarkeit:** PHP ist weit verbreitet, viele Entwickler kennen es

## Optionen

| Option | Vorteile | Nachteile |
|--------|----------|-----------|
| **A: PHP/MySQL ohne Framework** | Einfach, schnell umsetzbar, keine Abhängigkeiten, all-inkl.com-kompatibel | Kein MVC, manuelle Request-Handling, weniger "modern" |
| B: PHP mit Laravel | Strukturiert, viele Features (Auth, Routing), gute Dokumentation | Heavy für Shared Hosting, Composer nötig, all-inkl.com-Support unklar |
| C: Node.js + Express | Modern, JavaScript-Ökosystem, gut für APIs | Nicht standardmäßig bei all-inkl.com, Node.js-Versionen begrenzt |
| D: Python + Flask | Einfach, gut für Prototypen | Nicht bei all-inkl.com verfügbar |
| E: Ruby on Rails | Konvention über Konfiguration, schnelle Entwicklung | Overkill für einfaches Backend, Hosting komplex |

## Entscheidung
**Option A: PHP/MySQL ohne Framework**

### Begründung
1. **all-inkl.com Kompatibilität:** PHP 8.x und MySQL 8.x sind garantiert verfügbar
2. **Keine Abhängigkeiten:** Kein Composer, kein npm, keine komplexen Build-Prozesse
3. **Einfaches Deployment:** Dateien per SFTP hochladen, fertig
4. **Performance:** Für die erwartete Last (max. 1000 Images pro UID) völlig ausreichend
5. **Wartung:** Einfacher Code, der von jedem PHP-Entwickler verstanden werden kann

### Konsequenzen
- **Positiv:**
  - Schnelle Implementierung möglich
  - Geringe Server-Anforderungen
  - Volle Kontrolle über den Code
  - Keine Framework-Updates nötig

- **Negativ:**
  - Kein eingebautes Routing → manuelles Request-Handling in index.php
  - Kein ORM → manuelle SQL-Queries mit Prepared Statements
  - Kein eingebautes Session-Management → eigene Implementierung
  - Weniger "moderne" Architektur

## Alternativen Considered
- Laravel: Zu heavy für Shared Hosting, unnötige Komplexität für einfaches Backend
- Node.js: Nicht nativ unterstützt bei all-inkl.com
- Python/Ruby: Nicht verfügbar bei all-inkl.com

## Erfahrung
Nach der Implementierung bestätigt sich die Entscheidung:
- ✅ Deployment via SFTP funktioniert problemlos
- ✅ Performance ist ausreichend für die Anforderungen
- ✅ Code ist einfach zu verstehen und zu erweitern
- ⚠️ Manuelles Request-Routing erfordert etwas mehr Code

## Related
- [ADR-026: PIN-Hashing-Strategie](ADR-026-PIN-Hashing.md)
- [ADR-027: Dateivalidierung](ADR-027-Dateivalidierung.md)
- [ADR-028: PNG-Rendering](ADR-028-PNG-Rendering.md)
- [plan.md: Technical Context](plan.md#technical-context)
