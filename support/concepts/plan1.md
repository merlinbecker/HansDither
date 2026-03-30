# Plan für das Grid- und Cursor-Feature (mit SDK-Referenzen)

## Ziel
- 200x120 Canvas (Pulp-Auflösung) durch Skalierungsfaktor 2 (playdate.display.setScale(2))
- Bildschirm in ein 25x15-Grid (jede Zelle 8x8 Pixel)
- Cursor (4x4 Kreis, blinkend, invertiert auf schwarzer Zelle, steuerbar mit D-Pad)
- A-Button toggelt Zellenfarbe (schwarz/weiß)


## 1. Skalierung & Canvas
- Nutze `playdate.display.setScale(2)` ([7.16 Display.md]), damit das Spielfeld 200x120 Pixel groß ist, aber auf dem 400x240-Display korrekt angezeigt wird.

## 2. Grid-Logik mit GridView
- Verwende `playdate.ui.gridview` ([7.32 UI Components.md]) für das Grid (25x15 Zellen, je 8x8 Pixel).
- Die Navigation (Cursor) und Auswahl übernimmt das GridView (`selectNextRow`, `selectNextColumn` etc.).
- Die Methode `drawCell` wird überschrieben, um die Zellen individuell zu zeichnen (z.B. schwarz/weiß, invertierter Cursor).
- Die Cursor-Position ist direkt über `getSelection`/`setSelection` steuerbar.
- Die Zellenzustände (schwarz/weiß) werden in einem Array gespeichert (manuelle Implementierung, keine direkte SDK-Unterstützung für Zellzustände).

## 3. Cursor
- Cursor-Position wird über die GridView-Auswahl verwaltet (initial in der Mitte, siehe GridView-API [7.32 UI Components.md]).
- Cursor-Grafik: 4x4 Pixel Kreis (`playdate.graphics.fillCircleAtPoint()`, [7.20.6 Drawing.md]), in `drawCell` zeichnen, wenn `selected==true`.
- Blinken: Mit `playdate.graphics.animation.blinker` ([7.20.9 Animation.md]) realisieren, statt manuellem Timer. In `drawCell` prüfen, ob `blinker.on` true ist, dann Cursor zeichnen.
- Cursor invertiert: In `drawCell` prüfen, ob Zelle schwarz ist, dann `playdate.graphics.setImageDrawMode(playdate.graphics.kDrawModeInverted)` ([7.20.6 Drawing.md]) für den Cursor setzen.

## 4. Steuerung
- D-Pad: Über GridView-Methoden (`selectNextRow`, `selectNextColumn` etc., [7.32 UI Components.md]) Cursor im Grid bewegen, Grenzen werden automatisch beachtet.
- A-Button: Wenn Zelle leer (weiß), setze auf schwarz (Array und Zeichnung), sonst auf weiß. (Manuelle Implementierung: Zellenzustand im Array toggeln, keine direkte SDK-Unterstützung.)

## 5. Zeichenlogik
- Im `playdate.update()` ([7.4 Game lifecycle.md]):
  - `GridView:drawInRect()` aufrufen, `needsDisplay` beachten ([7.32 UI Components.md])
  - `playdate.graphics.animation.blinker.updateAll()` ([7.20.9 Animation.md]) aufrufen
  - `playdate.timer.updateTimers()` ([7.32 UI Components.md]) aufrufen

## 6. Best Practices
- `CoreLibs/graphics`, `CoreLibs/ui`, `CoreLibs/animation` und `CoreLibs/timer` importieren ([SDK-Doku, jeweils im Kopf der Module]).
- Lokale Variablen für Performance ([5.3 Lua Tips.md]).
- Zeichenoperationen möglichst effizient halten (nur Änderungen neu zeichnen, falls möglich, siehe `needsDisplay` [7.32 UI Components.md]).

## Verwendete Playdate-APIs (mit Referenz)
- `playdate.display.setScale` ([7.16 Display.md])
- `playdate.ui.gridview` und zugehörige Methoden (`drawCell`, `setSelection`, `selectNextRow`, `selectNextColumn`, `needsDisplay`, etc.) ([7.32 UI Components.md])
- `playdate.graphics.fillRect`, `fillCircleAtPoint`, `setImageDrawMode` ([7.20.6 Drawing.md])
- `playdate.graphics.animation.blinker` ([7.20.9 Animation.md])
- `playdate.timer.new`, `timer.updateTimers` ([7.32 UI Components.md])
- `playdate.inputHandlers` oder `playdate.[direction]ButtonDown`/`AButtonDown` ([7.11 Input Handlers.md])
