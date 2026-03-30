# Plan 4: Tilemap performant speichern und laden (Playdate Lua)

## Ziel
Eine im Speicher erzeugte Tilemap soll performant gespeichert und wieder geladen werden können. Die Lösung soll Playdate-Best-Practices und die Möglichkeiten der SDK-APIs nutzen.

---

## 1. Tilemap-Daten extrahieren
- Die Tilemap besteht aus einer Imagetable (Grafiken) und einer Matrix von Tile-Indizes (Leveldaten).
- Die Imagetable wird meist als Asset im Projekt gespeichert und muss nicht zur Laufzeit serialisiert werden.
- Die Leveldaten (Tile-Indizes) können mit `tilemap:getTiles()` als Array und Breite extrahiert werden.
  - **Quelle:** inside_playdate/7.20.13 Tilemap.md

## 2. Speichern der Tilemap-Daten
- Die Leveldaten (Array + Breite) werden als Lua-Tabelle gespeichert.
- Für das Speichern empfiehlt sich `playdate.datastore.write(table, filename)`:
  - Vorteil: Einfach, robust, speichert als JSON im Data-Ordner.
  - **Quelle:** inside_playdate/7.18 Files.md
- Beispiel:
  ```lua
  local data, width = tilemap:getTiles()
  playdate.datastore.write({data=data, width=width}, "tilemap_save")
  ```

## 3. Laden der Tilemap-Daten
- Die Daten werden mit `playdate.datastore.read(filename)` geladen.
- Die Matrix wird mit `tilemap:setTiles(data, width)` wiederhergestellt.
- Beispiel:
  ```lua
  local saved = playdate.datastore.read("tilemap_save")
  if saved then
    tilemap:setTiles(saved.data, saved.width)
  end
  ```
- **Quelle:** inside_playdate/7.20.13 Tilemap.md, inside_playdate/7.18 Files.md

## 4. Alternative: JSON manuell speichern
- Für komplexere Strukturen kann auch `playdate.json.encodeToFile()` verwendet werden.
- Vorteil: Mehr Kontrolle über das Format, aber weniger komfortabel als datastore.
- **Quelle:** inside_playdate/7.21 JSON.md

## 5. Bilder/Grafiken speichern
- Einzelne Images können mit `playdate.datastore.writeImage(image, path)` als PDI gespeichert werden.
- Eine Tilemap als Ganzes kann nicht direkt als PNG/PDI gespeichert werden, aber einzelne Tiles (Images) schon.
- **Quelle:** inside_playdate/7.18 Files.md

---

## Fazit
- **Empfohlener Weg:**
  - Leveldaten (Tile-Indizes) mit `tilemap:getTiles()` extrahieren und mit `playdate.datastore.write()` speichern.
  - Beim Laden mit `playdate.datastore.read()` und `tilemap:setTiles()` wiederherstellen.
- **Grafiken:** Imagetables als Assets behandeln, einzelne Images ggf. mit `writeImage()` sichern.

---

**Quellen:**
- inside_playdate/7.20.13 Tilemap.md
- inside_playdate/7.18 Files.md
- inside_playdate/7.21 JSON.md
