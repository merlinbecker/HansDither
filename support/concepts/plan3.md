
# Plan 3: Pixel-Zoom und Editieren einzelner Tile-Pixel


## Ziel
Durch die Tastenkombination "D-Pad Up + Crank-Vorwärtsdrehung (1 Umdrehung)" wird das Grid auf die aktuelle Cursorzelle gezoomt. Die 8x8 Pixel der Zelle werden zu einem neuen Grid (14x8), wobei jedes Pixel eine eigene editierbare Zelle (15x15 Pixel groß) ist. Der Cursor bleibt mittig. Einzelne Pixel können nun gesetzt werden.

**Kontext-Grid:**
Beim Zoom-In wird nicht nur das aktuelle Tile, sondern ein größeres Kontext-Grid angezeigt (z.B. 14x8 Zellen), sodass angrenzende Tiles sichtbar und editierbar sind. In der Mitte befindet sich das aktuelle Tile, drumherum die Nachbartiles.

Mit "D-Pad Up + Crank-Rückdrehung (1 Umdrehung)" wird zurückgezoomt, und alle bearbeiteten Tiles werden als neue Tiles in die Imagetable übernommen und im Grid verwendet.

---

---

## Umsetzungsschritte


### 1. Zoom-Trigger erkennen
- **Input-Handling:**
  - Erkenne gleichzeitiges Drücken von D-Pad Up und eine komplette Crank-Drehung (z.B. mit [`playdate.getCrankTicks`](../../inside_playdate/7.10%20Crank.md#getcrankticks) und Flag für Up-Button).[1]
  - Unterscheide Vorwärts- (Zoom-In) und Rückwärtsdrehung (Zoom-Out).
  - Nutze die Input-Handler-Architektur ([`playdate.inputHandlers.push`](../../inside_playdate/7.11%20Input%20Handlers.md#inputhandlers)) für Moduswechsel und saubere Steuerungslogik.[2]



### 2. Zoom-In: Kontext-Pixel-Grid erzeugen
- **Altes Grid sichern:**
  - Speichere die aktuelle Grid- und Cursor-Position.
- **Kontext-Grid aufbauen:**
  - Ermittle die Nachbartiles um das aktuelle Tile (z.B. 14x8 Tiles, mittig das selektierte Tile).
  - Für jedes Tile im Kontextbereich:
    - Hole das aktuelle Tile-Image und dessen Pixelzustand ([`tilemap:getTileAtPosition`](../../inside_playdate/7.20.13%20Tilemap.md#gettileatposition)).[3]
    - Erzeuge ein Arbeits-Image (8x8) für jedes Tile, falls noch nicht vorhanden.
  - Setze die Ansicht so, dass jede Zelle 15x15 Pixel groß ist und der Cursor mittig bleibt.
  - Der Cursor kann sich im gesamten Kontext-Grid bewegen (auch über Tile-Grenzen hinweg).
  - Nutze für die Darstellung des Kontext-Grids ein separates [`playdate.ui.gridview`](../../inside_playdate/7.32%20UI%20Components.md#grid-view)-Objekt, das dynamisch erzeugt und konfiguriert wird.[4]


### 3. Pixel-Editing & Scrollen
- **Pixel setzen/löschen:**
  - Mit A-Button einzelne Pixel im Kontext-Grid setzen/löschen (toggle).
  - Das Programm berechnet für jede Cursorposition, zu welchem Tile und zu welchem Pixel im Tile die Zelle gehört.
  - Zeichne das jeweilige Arbeits-Tile-Image nach jedem Edit neu (mit [`lockFocus`](../../inside_playdate/7.20.8%20Offscreen%20Drawing.md)).[5]
  - Optional: Zeige das Tile-Image als Vorschau.
- **Scrollen im Kontext-Grid:**
  - Mit "D-Pad Right + Crank vor/zurück" kann das Kontext-Grid horizontal gescrollt werden.
  - Mit "D-Pad Down + Crank vor/zurück" kann das Kontext-Grid vertikal gescrollt werden ([Crank als Input](../../inside_playdate/7.10%20Crank.md)).[1]
  - So kann der Nutzer beliebig im Grid navigieren und mehrere Tiles bearbeiten.
  - Nutze die [`gridview`-Scrollfunktionen](../../inside_playdate/7.32%20UI%20Components.md#scrolling) (`scrollToCell`, `setScrollPosition`) für sanftes und performantes Scrollen.[4]


### 4. Zoom-Out: Tiles übernehmen & Deduplizierung
- **Zurückzoomen:**
  - Bei Rückdrehung (und Up gehalten):
    - Übernehme alle bearbeiteten Arbeits-Tile-Images als neue Tiles in die Imagetable (`imagetable:setImage`).
    - Für jedes bearbeitete Tile prüfe per Hash (z.B. Bitstring, CRC32), ob es bereits ein identisches Tile gibt:
      - Falls ja, verwende dessen Index im Grid.
      - Falls nein, füge das neue Tile hinzu und verwende dessen Index.
    - Setze im Hauptgrid an allen bearbeiteten Positionen die neuen Tile-Indizes ([`tilemap:setTileAtPosition`](../../inside_playdate/7.20.13%20Tilemap.md#settileatposition)).[3]
    - Stelle das alte Grid und die Cursor-Position wieder her.
  - **Wichtig:** Imagetable und Tilemap sind 1-basiert (Lua-Konvention).[3]


### 5. Rendering
- **Im Kontext-Pixel-Grid:**
  - Zeichne jede Zelle als Pixel (schwarz/weiß) entsprechend dem aktuellen Arbeits-Tile-Image.
  - Zeige angrenzende Tiles im Kontext an.
  - Nutze [`gridview:drawCell`](../../inside_playdate/7.32%20UI%20Components.md#drawcell) für die Zellen-Darstellung.[4]
- **Im Hauptgrid:**
  - Zeichne wie in Plan 2, aber mit den neuen/angepassten Tiles.
  - Nutze `gridview.needsDisplay` für performantes Redraw-Handling.[4]


### 6. Performance und Showstopper
- **Performance:**
  - Das Zeichnen einzelner Pixel und das Erzeugen neuer Tiles ist mit [`lockFocus`](../../inside_playdate/7.20.8%20Offscreen%20Drawing.md) und `image.new(8,8)` performant möglich.[5]
  - Die Imagetable kann zur Laufzeit erweitert werden (`setImage`).
  - Die Tilemap kann dynamisch aktualisiert werden.
  - Hashing und Vergleich von 8x8-Bitmaps ist sehr schnell und speicherschonend.
  - Nutze `gridview.needsDisplay` und gezieltes Redraw für bessere Performance.[4]
- **Showstopper:**
  - Die maximale Anzahl an Tiles in einer Imagetable ist nicht explizit limitiert, aber der Speicher ist begrenzt. Viele individuelle Tiles können Speicherprobleme verursachen.
  - Die API unterstützt keine "Undo"-Funktion für Tiles, das müsste selbst implementiert werden.
  - Die Tilemap-API ist 1-basiert, Koordinaten müssen angepasst werden.[3]
  - Die Scroll- und Mapping-Logik muss sauber und performant umgesetzt werden.

---


## Hinweise & Verbesserungen aus der Doku

- **Input-Handling:**
  - Nutze konsequent die Input-Handler-Architektur für Moduswechsel ([`playdate.inputHandlers.push`](../../inside_playdate/7.11%20Input%20Handlers.md)).[2]
- **UI-Komponenten:**
  - Für Hinweise auf die Crank-Nutzung kann [`playdate.ui.crankIndicator`](../../inside_playdate/7.32%20UI%20Components.md#crank-indicator) eingeblendet werden, wenn die Crank eingeklappt ist.[4]
- **Gridview:**
  - [`playdate.ui.gridview`](../../inside_playdate/7.32%20UI%20Components.md) ist ideal für die Darstellung und Navigation im Pixel- und Tile-Grid.[4]
  - Beachte, dass `playdate.timer.updateTimers()` im Haupt-Update-Loop aufgerufen werden muss, wenn gridview verwendet wird.[4]
- **Offscreen Drawing:**
  - Nutze [`lockFocus`](../../inside_playdate/7.20.8%20Offscreen%20Drawing.md) für performantes Pixel-Editing.[5]
- **1-basierte Indizes:**
  - Imagetable und Tilemap sind 1-basiert, nicht 0-basiert ([`tilemap:getTileAtPosition`](../../inside_playdate/7.20.13%20Tilemap.md#gettileatposition)).[3]
- **Performance:**
  - Nutze `gridview.needsDisplay` und gezieltes Redraw für bessere Performance.[4]

---


## ToDo
- [ ] Input-Handling für Zoom-In/Out
- [ ] Kontext-Pixel-Grid erzeugen und anzeigen
- [ ] Einzelpixel setzen/löschen (inkl. Mapping auf Tile/Pixel)
- [ ] Scrollen im Kontext-Grid (DPAD+Crank)
- [ ] Deduplizierung und neues Tile erzeugen/übernehmen
- [ ] Rückkehr ins Hauptgrid
- [ ] Performance testen

---

## Quellen

1. [7.10 Crank.md](../../inside_playdate/7.10%20Crank.md)
2. [7.11 Input Handlers.md](../../inside_playdate/7.11%20Input%20Handlers.md)
3. [7.20.13 Tilemap.md](../../inside_playdate/7.20.13%20Tilemap.md)
4. [7.32 UI Components.md](../../inside_playdate/7.32%20UI%20Components.md)
5. [7.20.8 Offscreen Drawing.md](../../inside_playdate/7.20.8%20Offscreen%20Drawing.md)
