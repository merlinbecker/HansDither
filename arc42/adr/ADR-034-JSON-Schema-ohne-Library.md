# ADR-034: JSON-Schema-Validierung als schlanke PHP-Funktion statt externer Bibliothek

## Status
✅ **Umgesetzt** – `Validation::validateFramesJsonSchema()`

## Kontext
Spec 007 verlangt, dass die hochgeladene `frames.json` nicht nur syntaktisch
gültiges JSON ist, sondern auch dem in Spec 001 definierten Struktur-Schema
entspricht (`version`, `name`, `gridWidth=25`, `gridHeight=15`, `tileCount`,
`frames[1..12]` à exakt 375 Tile-Indizes im gültigen Bereich). Bisher prüfte
`Validation::validateJsonFile()` nur, dass `json_decode()` erfolgreich ist
und ein Objekt/Array liefert — keine Struktur.

## Entscheidungs-Treiber
- **Einfachheit (Constitution IV):** Spec 005 etabliert bewusst
  "PHP/MySQL ohne Frameworks" für dieses Backend; keine Composer-
  Abhängigkeiten.
- **Stabilität des Formats:** Das Schema ist seit Spec 001 fix (sechs
  Felder, eine Array-Dimension mit fester Länge 375) — kein sich wandelndes
  oder generisches Schema-Problem.
- **Shared Hosting:** all-inkl.com ohne etablierten Composer-Workflow für
  dieses Projekt.

## Optionen

| Option | Vorteile | Nachteile |
|--------|----------|-----------|
| **A: Schlanke PHP-Funktion mit festen Feldprüfungen** | Keine neue Abhängigkeit, ca. 40 Zeilen, exakt auf das eine Format zugeschnitten | Nicht wiederverwendbar für andere Schemata |
| B: Externe JSON-Schema-Bibliothek (z. B. `justinrainbow/json-schema`) | Generisch, deklaratives Schema-Dokument | Neue Composer-Abhängigkeit auf Shared Hosting, Overhead für ein einziges stabiles Format |
| C: Schema-Prüfung im Frontend/Client statt Backend | Kein Backend-Code | Löst NICHT das eigentliche Problem — ein manipulierter Client könnte das Backend weiterhin direkt angreifen (genau das im Feature-Wunsch benannte Risiko) |

## Entscheidung
**Option A: Schlanke PHP-Funktion `Validation::validateFramesJsonSchema()`**

### Begründung
1. Sechs feste Felder, eine Array-Dimension mit fester Länge — eine
   generische Schema-Engine wäre für diesen einen, stabilen Anwendungsfall
   unverhältnismäßig (Constitution IV).
2. Prüft in fester Reihenfolge und bricht bei der ERSTEN Verletzung ab,
   liefert dabei immer das konkret verletzte Feld in der Fehlermeldung
   (FR-008/FR-009), statt eines generischen "JSON ungültig".
3. Konsistent mit dem bestehenden `Validation`-Muster der Klasse
   (`validatePdiFile()`/`validateJsonFile()` folgen demselben
   Früh-Abbruch-Stil).

### Konsequenzen
- **Positiv:** Keine neue Abhängigkeit, keine Composer-Einrichtung auf
  Shared Hosting nötig, Verhalten leicht nachvollziehbar und testbar
  (elf Smoke-Test-Fälle während der Implementierung verifiziert, u. a.
  beide Grenzfälle: exakt 12 Frames und Tile-Index exakt bei `tileCount`).
- **Negativ:** Bei einer künftigen Erweiterung um weitere, komplexere
  Schemata (z. B. optionale Felder, verschachtelte Objekte) müsste erneut
  bewertet werden, ob eine generische Lösung sinnvoller wird — für das
  aktuelle, seit Spec 001 stabile Format ist das kein Thema.

## Alternativen Considered
Siehe Options-Tabelle oben — vollständige Herleitung in
`specs/007-backend-upload-hardening/research.md` R4.

## Related
- [ADR-027: Dateivalidierung](ADR-027-Dateivalidierung.md)
- [specs/007-backend-upload-hardening/research.md: R4](../../specs/007-backend-upload-hardening/research.md)
- [specs/007-backend-upload-hardening/data-model.md: Abschnitt 3](../../specs/007-backend-upload-hardening/data-model.md)
- [specs/001-pdi-storage-format/data-model.md: Bild / Frames](../../specs/001-pdi-storage-format/data-model.md)
