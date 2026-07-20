# ADR-031: Kontext-/Pause-Ansicht via `playdate.setMenuImage()` statt eigenem Pause-Screen

## Status
✅ **Umgesetzt** – `EditorRoom:buildPauseMenuImage()` + `main.lua:playdate.gameWillPause()`

## Kontext
Spec 006 (US5) verlangt eine erweiterte Kontext-/Pause-Ansicht, die
zusätzlich zu den Standard-Pause-Funktionen (Lautstärke, Home, Screenshot)
eine Tile-Übersicht (bis zu 120 Vorschauen im 12×10-Raster), die
Gesamt-Tile-Anzahl sowie Metainformationen (mind. Frame-Anzahl) zeigt.
Zwei Randbedingungen aus Spec 004/005: das System-Menü des Editors nutzt
bereits alle 3 verfügbaren Menü-Slots (`save + exit`, `delete frame`/
`reset frame`, `show grid`), und das native System-Menü kann ohnehin keine
eigene Grafik wie ein Tile-Raster rendern (nur Text-Items + optionale
Checkmarks).

## Entscheidungs-Treiber
- **SDK-First (Constitution I):** vor jeder Eigenimplementierung prüfen,
  ob das SDK die Funktion bereits abdeckt.
- **Einfachheit (Constitution IV):** kein neuer Room, keine neue eigene
  Pause-Geste, die den bereits etablierten nativen Playdate-Pause-
  Mechanismus (Menü-Taste) verdoppeln würde.
- **Eingabe-Randbedingung:** D-Pad, A/B-Buttons und Crank sind laut
  Constitution die einzigen vom SPIEL eingeführten Eingabegeräte — die
  physische Menü-Taste ist jedoch der plattformweite, von jeder Playdate-
  App bereitgestellte OS-Pause-Mechanismus, keine neue, vom Spiel
  eingeführte Eingabe.

## Optionen

| Option | Vorteile | Nachteile |
|--------|----------|-----------|
| **A: `playdate.setMenuImage()` + `playdate.gameWillPause()`** | Kein neuer Menü-Slot nötig (separater Mechanismus), volle Grafikfähigkeit, exakt für diesen Zweck von der SDK-Doku vorgesehen | Inhalt nur im linken 200px-Bereich sichtbar (rechte Hälfte vom System-Menü überdeckt) |
| B: Eigener neuer Room ("PauseRoom"), über eine zusätzliche Crank-/Button-Geste betreten | Volle Kontrolle über Layout | Verdoppelt/verwirrt den bereits etablierten nativen Pause-Mechanismus; zusätzliche Eingabe-Geste nötig |
| C: Bestehende Menü-Items ersetzen/konsolidieren für einen 4. "virtuellen" Slot mit Grafik-Hinweis | — | Hinfällig: `setMenuImage` belegt ohnehin keinen Menü-Item-Slot, das Problem existiert gar nicht |

## Entscheidung
**Option A: `playdate.setMenuImage()` + `playdate.gameWillPause()`**

### Begründung
1. **SDK-Doku wörtlich zutreffend:** "While the game is paused it can
   optionally provide an image to be displayed alongside the System
   Menu." — `gameWillPause()` ist laut Doku-Beispiel wörtlich für genau
   diesen Anwendungsfall (Menü-Bild kurz vor dem Pausieren aktualisieren)
   vorgesehen (research.md R4).
2. **Kein Menü-Slot-Konflikt:** `setMenuImage` ist ein vom
   Menü-Item-System (`addMenuItem`/`addCheckmarkMenuItem`) komplett
   getrennter Mechanismus — die bestehende 3-Slot-Belegung bleibt
   unangetastet.
3. **Nativer Pause-Mechanismus bleibt einzige Pause-Geste:** kein
   zusätzlicher, vom Spiel eingeführter Eingabeweg nötig, der die
   Constitution-Randbedingung "D-Pad/A/B/Crank sind die einzigen
   Eingabegeräte" unnötig strapazieren würde.
4. **Aufruf nur beim tatsächlichen Pausieren:** `buildPauseMenuImage()`
   läuft ausschließlich in `gameWillPause()`, nicht pro Frame — kein
   Performance-Risiko trotz Iteration über alle `imageData.frames[*]`.

### Konsequenzen
- **Positiv:** Keine neue Room-Architektur, kein zusätzlicher Eingabeweg,
  volle Grafikfähigkeit für die Tile-Übersicht.
- **Negativ:** Layout ist auf die linken 200px beschränkt (SDK-Vorgabe,
  nicht verhandelbar) — Titelzeile, 12×10-Raster, Gesamtzahl und
  Metainformationen müssen sich diesen Platz teilen (data-model.md
  Abschnitt 4 legt das konkrete Layout fest).

## Alternativen Considered
Siehe Options-Tabelle oben — vollständige Herleitung in
`specs/006-editor-ui-polish/research.md` R4.

## Related
- [ADR-032: Reset Frame statt Delete Frame im Menü](ADR-032-Reset-Frame-statt-Delete-Frame-im-Menue.md)
- [specs/006-editor-ui-polish/research.md: R4](../../specs/006-editor-ui-polish/research.md)
- [specs/006-editor-ui-polish/data-model.md: Abschnitt 4](../../specs/006-editor-ui-polish/data-model.md)
- [specs/006-editor-ui-polish/contracts/editor-room-ui-polish.md: Abschnitt 4](../../specs/006-editor-ui-polish/contracts/editor-room-ui-polish.md)
