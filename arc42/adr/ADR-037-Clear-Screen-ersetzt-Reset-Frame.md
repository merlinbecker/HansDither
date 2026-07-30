# ADR-037: "Clear Screen" ersetzt "Reset Frame" vollständig im Systemmenü

## Status
✅ **Umgesetzt** (Projektinhaber-Vorgabe) – `EditorRoom:buildSystemMenu()`

## Kontext
Spec 006/AD-032 führte "reset frame" ein (kopiert den Vorgänger-Frame
elementweise in den aktiven Frame) als Ersatz für "delete frame". Der
Projektinhaber lässt nun die ursprüngliche Idee, was bei versehentlich
bemalten Frames passieren soll, bewusst fallen (spec.md Assumptions) und
verlangt stattdessen einen einfachen Befehl "Clear Screen", der den
Inhalt des aktuell aktiven Frames vollständig nullt (Voll-Weiß).

Im Unterschied zu AD-032 — wo `deleteCurrentFrame()` bewusst als toter
Code im Projekt verblieb, falls später ein anderer Zugriffsweg gewünscht
wird — fordert FR-011 dieser Spec ausdrücklich die VOLLSTÄNDIGE Entfernung
der Funktion "Reset Frame", nicht nur ihres Menü-Zugriffs.

## Entscheidungs-Treiber
- **Projektinhaber-Vorgabe**: explizite Anweisung, "Reset Frame" komplett
  zu entfernen und durch "Clear Screen" zu ersetzen (spec.md Input).
- **Bestehende Menü-Struktur**: 3-Slot-System-Menü bereits vollständig
  belegt (`save + exit`, `reset frame`, `show grid`) — kein neuer Slot
  nötig, reiner Eintrags-Tausch wie schon bei AD-032.
- **Constitution IV (Einfachheit)**: keine Ansammlung toten Codes ohne
  begründeten Zukunftsnutzen — FR-011 fordert vollständige Entfernung.
- **Bestehende Basistile-Invariante** (`ImageStoreCodec`: Index 1 =
  Voll-Weiß) ermöglicht eine triviale, bereits an anderer Stelle
  verifizierte Implementierung.

## Optionen

| Option | Vorteile | Nachteile |
|--------|----------|-----------|
| **A: "reset frame" durch "clear screen" ersetzen, `resetCurrentFrameToPrevious()` vollständig entfernen** | Kein neuer Slot nötig, sofortige Verfügbarkeit, entspricht FR-011 wörtlich, kein toter Code | Frame-Vorgänger-Kopierfunktion ("reset frame") steht künftig nicht mehr zur Verfügung |
| B: "clear screen" ergänzen, `resetCurrentFrameToPrevious()` als toten Code belassen (wie `deleteCurrentFrame()` seit AD-032) | Funktion bliebe für einen möglichen Folge-Zugriffsweg erhalten | Widerspricht FR-011 ("vollständig entfernen"); unnötig angesammelter toter Code ohne konkreten Folgenutzen |
| C: Bestätigungsdialog vor "Clear Screen" ergänzen | Schutz vor versehentlichem Datenverlust | Kein bestehender Menüpunkt im Projekt hat eine Bestätigung; Projektinhaber lässt die Schutzidee bewusst fallen (spec.md) |

## Entscheidung
**Option A**: Der dritte Menü-Slot wechselt von `"reset frame"` auf
`"clear screen"` (`clearCurrentFrame()`, setzt alle 375 Tile-Indizes des
aktiven Frames auf Basis-Index 1); `"save + exit"` und `"show grid"`
bleiben unverändert. `resetCurrentFrameToPrevious()` wird vollständig aus
`Source/EditorRoom.lua` entfernt.

### Begründung
1. **Wörtliche Spec-Erfüllung**: FR-011 verlangt vollständige Entfernung
   von "Reset Frame" — anders als bei AD-032 gibt es hier keinen
   dokumentierten Grund, die Funktion als toten Code zu erhalten.
2. **Trivialer, bereits verifizierter Mechanismus**: `clearCurrentFrame()`
   ist strukturell identisch zu `resetCurrentFrameToPrevious()`, nur mit
   der konstanten Quelle `1` statt dem Vorgänger-Frame-Array.
3. **Kein neuer Eingabeweg**: Der dritte Menü-Slot behält seine Position,
   wechselt nur die Funktion.

### Konsequenzen
- **Positiv**: "Clear Screen" ist ab sofort ohne neue Eingabe-
  Infrastruktur verfügbar; kein zusätzlicher toter Code.
- **Negativ**: Die bisherige "reset frame"-Funktionalität (Vorgänger-
  Frame elementweise übernehmen) ist unwiederbringlich entfernt — ein
  künftiger Bedarf müsste als neue Funktion re-implementiert werden.
- Bewusst akzeptiertes Restrisiko: kein Schutz mehr gegen versehentliches
  Bemalen eines Frames (spec.md Assumptions, Projektinhaber-Entscheidung).

## Alternativen Considered
Siehe Options-Tabelle oben — vollständige Herleitung in
`specs/008-zoom-rotation-clearscreen/research.md` R4.

## Related
- [ADR-032: Reset Frame statt Delete Frame im Menü](ADR-032-Reset-Frame-statt-Delete-Frame-im-Menue.md)
- [specs/008-zoom-rotation-clearscreen/research.md: R4](../../specs/008-zoom-rotation-clearscreen/research.md)
- [specs/008-zoom-rotation-clearscreen/contracts/zoom-pixel-editor-updates.md: EM-01..03](../../specs/008-zoom-rotation-clearscreen/contracts/zoom-pixel-editor-updates.md)
