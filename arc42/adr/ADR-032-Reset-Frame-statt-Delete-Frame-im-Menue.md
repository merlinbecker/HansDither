# ADR-032: "Reset Frame" ersetzt "Delete Frame" im Systemmenü

## Status
✅ **Umgesetzt** (Projektinhaber-Vorgabe) – `EditorRoom:buildSystemMenu()`

## Kontext
Spec 006 (US4) fordert eine neue Aktion "Reset Frame", die den Inhalt des
vorherigen Frames vollständig in den aktuell aktiven Frame kopiert. Das
System-Menü des Editors nutzt bereits alle 3 verfügbaren Slots
(`save + exit`, `delete frame`, `show grid`, research.md R4) — es gibt
keinen vierten freien Slot. Eine Prüfung aller bestehenden
D-Pad/A/B/Crank-Kombinationen (research.md R7) zeigt zudem: es existiert
AKTUELL kein wirklich freier Chord — A löst `beginStroke()` bedingungslos
aus (auch während B gehalten wird), D-Pad-Bewegung ist nicht an den
B-Zustand gekoppelt; jede neue Chord-Belegung würde eine bestehende
Eingabe-Kombination überschreiben.

## Entscheidungs-Treiber
- **Kein freier Menü-Slot** (3/3 belegt) und **kein kollisionsfreier
  Chord** identifiziert.
- **Einfachheit (Constitution IV):** keine neue Eingabe-Infrastruktur
  (z. B. Halte-Geste, Doppel-Tap-Erkennung) für einen einzelnen neuen
  Menüpunkt einführen.
- **Projektinhaber-Entscheidung:** explizite Vorgabe im Rahmen der
  Planungsphase dieser Spec.

## Optionen

| Option | Vorteile | Nachteile |
|--------|----------|-----------|
| **A: "delete frame" durch "reset frame" ersetzen** | Kein neuer Slot nötig, sofortige Verfügbarkeit, "reset frame" adressiert denselben Fehlerkorrektur-Anwendungsfall wie "delete frame" | `deleteCurrentFrame()` verliert ihren Menü-Aufrufer |
| B: Neue D-Pad/A/B/Crank-Chord-Kombination einführen | "delete frame" bleibt erhalten | Keine kollisionsfreie Kombination identifiziert (research.md R7); würde bestehende Eingabe überschreiben |
| C: "show grid" statt "delete frame" ersetzen | "delete frame" bleibt erhalten | Nicht vom Projektinhaber gewählt; "show grid" hat keinen thematischen Bezug zu Frame-Fehlerkorrektur |

## Entscheidung
**Option A: Menüpunkt "delete frame" wird durch "reset frame" ersetzt**
(Projektinhaber-Vorgabe, explizit im Gespräch bestätigt: "ersetzte 'delete
frame' durch 'reset frame'"). "show grid" bleibt unverändert. Neuer
Menü-Aufbau: `"save + exit"`, `"reset frame"`, `"show grid"`.

### Begründung
1. **Gleicher Anwendungsfall, andere Lösung:** Sowohl "delete frame"
   (Frame entfernen, Nachrücker aktiv) als auch "reset frame"
   (Vorgänger-Inhalt übernehmen) adressieren denselben
   Fehlerkorrektur-Workflow — der Nutzer ist mit einem Frame unzufrieden.
   "reset frame" verliert dabei jedoch keine Frame-Anzahl/
   Positionsstruktur, was aus Editor-Workflow-Sicht sogar vorteilhaft ist.
2. **Kein neuer Eingabeweg:** Der dritte Menü-Slot behält seine Position,
   wechselt nur die Funktion — keine neue Infrastruktur.

### Konsequenzen
- **Positiv:** "Reset Frame" ist ab sofort ohne neue Eingabe-Infrastruktur
  verfügbar.
- **Negativ:** Die bisherige "delete frame"-Aktion (FR-008a aus Spec 003:
  aktiven Frame entfernen, Nachrücker aktiv) ist NICHT mehr über das Menü
  erreichbar. Die Implementierungsfunktion `deleteCurrentFrame()` bleibt
  im Code bestehen (kein toter Code, falls später ein anderer Zugriffsweg
  gewünscht wird), verliert aber ihren einzigen Aufrufer. Sollte "delete
  frame" künftig wieder gebraucht werden, ist ein Folge-Slot/-Zugriffsweg
  außerhalb dieser Spec zu klären.

## Alternativen Considered
Siehe Options-Tabelle oben — vollständige Herleitung in
`specs/006-editor-ui-polish/research.md` R7.

## Related
- [ADR-031: Pause-Ansicht via setMenuImage](ADR-031-Pause-Ansicht-setMenuImage.md)
- [specs/006-editor-ui-polish/research.md: R7](../../specs/006-editor-ui-polish/research.md)
- [specs/006-editor-ui-polish/contracts/editor-room-ui-polish.md: CR-08](../../specs/006-editor-ui-polish/contracts/editor-room-ui-polish.md)
