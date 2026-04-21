# 6. Laufzeitsicht

## 6.1 Szenario: Spielstart bis Editor

1. Runtime startet und importiert alle Rooms.
2. main.lua setzt TitleRoom als currentRoom und registriert Input-Handler.
3. A in TitleRoom wechselt zu GameRoom.
4. Nutzer waehlt bestehendes Game oder erstellt neues.
5. Wechsel zu LoadRoom mit gesetztem Game-Kontext.
6. Nutzer waehlt Room oder erstellt neuen Room.
7. Wechsel zu TileRoom mit geladenen gameData/pulpState.

Ergebnis: Der Editor ist mit konsistentem Spiel- und Room-Kontext aktiv.

## 6.2 Szenario: Pixel setzen im TileRoom

1. Nutzer bewegt Cursor mit D-Pad.
2. A toggelt Tile an Cursorposition zwischen Hintergrundtile und Picker-Tile.
3. Optional wird Picker per Crank angepasst (Index 3..n).
4. needsRedraw markiert, Update zeichnet Tilemap, Cursor und ggf. Pickerfenster.

Ergebnis: Der Room-Zustand ist visuell aktualisiert und intern in Tilemap vorhanden.

## 6.3 Szenario: Zoom-Bearbeitung zwischen TileRoom und PixelRoom

1. Im TileRoom wird B gehalten und Crank-Trigger erreicht.
2. TileRoom erzeugt den 3x3-Kontext um den Cursor (inkl. showGrid-Status) und uebergibt ihn an ZoomRoom.
3. ZoomRoom rendert ein 24x24 Pixelgrid, erlaubt Bearbeitung mehrerer Slots und optionalen Zoom in PixelRoom.
4. In PixelRoom wird ein einzelner 8x8-Slot detailliert geaendert und an ZoomRoom zurueckgegeben.
5. Bei Zoom-Out (ZoomRoom -> TileRoom) werden nur geaenderte Slots committed.
6. TileRoom uebernimmt diese Slots per applyTileEditsBatch ueber findOrAppendImage (Dedupe/Hashvergleich).

Ergebnis: Mehrere Tile-Aenderungen sind im Room sichtbar und dedupliziert fuer spaeteres Speichern vorbereitet.

## 6.4 Szenario: Save + Back

1. Nutzer waehlt im Systemmenue des TileRoom "Save + Back".
2. TileRoom synchronisiert aktuellen Room in gameData.
3. Kompaktierung entfernt ungenutzte Tiles und remappt Room-Indizes.
4. PulpGameIO baut aus gameData + pulpState ein vollstaendiges Speicherdokument.
5. Datastore schreibt Hauptdokument unter saves/<game>.
6. Room-Preview und Game-Preview werden erzeugt/aktualisiert.
7. Wechsel zurueck zu LoadRoom.

Ergebnis: Persistenter Zustand ist konsistent gespeichert; UIs koennen Vorschauen anzeigen.

## 6.5 Fehler-/Ausnahmeszenarien

- Fehlende Save-Datei beim Laden: Operation wird defensiv beendet (kein Absturz, kein Kontextwechsel).
- Unbekanntes Legacy-Format: Warnung, keine erzwungene Konvertierung.
- Inkonsistente Tile-Referenz nach Mapping: Fallback auf Basistile.
- Keyboard-Abbruch bei neuer Game-Erstellung: keine Neuerstellung, Grid wird sauber aktualisiert.
