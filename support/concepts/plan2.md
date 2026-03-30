# Plan 2: Zellen-Malen mit Tilemap

## Ziel
Das bisherige Zeichnen der Zellen (weiß/schwarz) per fillRect wird durch eine Tilemap ersetzt. Jede Zelle ist ein Tile. Es gibt zwei Tiles in der Datei `images/cellbg-table-8-8.png`. Zusätzlich wird ein komplett schwarzes Tile (8x8) hinzugefügt. Die erste Tile der Map ist der Standard-Background. Mit A wird zwischen Hintergrund und schwarzem Tile gewechselt.

---

## Umsetzungsschritte

### 1. Imagetable und Tilemap vorbereiten
- **Imagetable laden:**
  - Lade `images/cellbg-table-8-8.png` als Matrix-Imagetable (2 Tiles, 8x8).
- **Schwarzes Tile hinzufügen:**
  - Erzeuge ein neues 8x8-Image (voll schwarz) und füge es als drittes Tile zur Imagetable hinzu.
- **Tilemap erzeugen:**
  - Erzeuge ein `playdate.graphics.tilemap`-Objekt.
  - Weise die Imagetable zu.
  - Initialisiere die Tilemap mit der Größe des Grids (25x15).
  - Setze alle Tiles auf Index 1 (Standard-Background).

### 2. Grid-State anpassen
- **Grid-State:**
  - Statt `true/false` für schwarz/weiß, speichere den aktuellen Tile-Index pro Zelle (1 = Hintergrund, 3 = schwarz).

### 3. Zeichnen der Zellen
- **drawCell anpassen:**
  - Zeichne keine Rechtecke mehr, sondern lasse die Tilemap das Grid zeichnen.
  - Cursor weiterhin als Overlay zeichnen.

### 4. Zellen toggeln
- **A-Button:**
  - Hole aktuelle Cursor-Position.
  - Wenn dort Tile 3 (schwarz) liegt, setze auf 1 (Hintergrund), sonst auf 3 (schwarz).
  - Aktualisiere die Tilemap an dieser Position.

### 5. Redraw-Handling
- **Redraw:**
  - Bei Änderungen (A-Button, Cursor-Blink) muss das Grid neu gezeichnet werden.

### 6. Test und Feinschliff
- **Test:**
  - Prüfe, ob das Umschalten und Zeichnen wie erwartet funktioniert.
  - Prüfe, ob die Tilemap korrekt geladen und erweitert wird.

---

## Hinweise
- Die Imagetable ist 1-basiert (Lua-Konvention).
- Die Tilemap-API (`setTileAtPosition`, `getTileAtPosition`) nutzt 1-basierte Koordinaten.
- Die Cursor-Logik bleibt erhalten, wird aber über der Tilemap gezeichnet.
- Die Datei `images/cellbg-table-8-8.png` muss im Projekt vorhanden sein.
- Das schwarze Tile wird zur Laufzeit erzeugt und an die Imagetable angehängt.
- Man sollte der Tilemap zu Beginn eine feste Größe geben (25x15), damit sie die Grid-Struktur abbildet. mit setSize().

---

## ToDo
- [ ] Imagetable laden und erweitern
- [ ] Tilemap initialisieren
- [ ] Grid-State anpassen
- [ ] drawCell/Rendering anpassen
- [ ] Toggle-Logik anpassen
- [ ] Testen
