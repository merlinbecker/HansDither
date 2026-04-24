# 6. Laufzeitsicht

## 6.1 Szenario: Spielstart bis Editor

1. Runtime startet und importiert alle Rooms.
2. main.lua setzt TitleRoom als currentRoom und registriert Input-Handler.
3. A in TitleRoom wechselt zu GameRoom.
4. Nutzer waehlt bestehendes Game oder erstellt neues.
5. Wechsel zu LoadRoom mit gesetztem Game-Kontext.
6. Bei bestehendem Game startet LoadRoom die Ladeoperation mit loadingBar.
7. PulpGameIO.prepareLoadedGame verarbeitet Dokument und Mapping in Fortschrittsphasen.
8. Nutzer waehlt Room oder erstellt neuen Room.
9. Wechsel zu TileRoom mit geladenen gameData/pulpState.

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
2. TileRoom startet eine RoomOperation und blendet loadingBar ein.
3. Phase "Synchronisieren": aktueller Room wird nach gameData uebernommen.
4. Phase "Kompaktieren": ungenutzte Tiles werden entfernt und Indizes remappt.
5. Phase "Dokument": PulpGameIO.buildSaveDocument erstellt das Speicherdokument in Teilschritten.
6. Phase "Finalisieren": Datastore schreibt Hauptdokument unter saves/<game>.
7. Phase "Previews": Room-Preview und Game-Preview werden erzeugt/aktualisiert.
8. Nach erfolgreichem Abschluss erfolgt der Wechsel zurueck zu LoadRoom.

Ergebnis: Persistenter Zustand ist konsistent gespeichert; UIs koennen Vorschauen anzeigen.

## 6.5 Fehler-/Ausnahmeszenarien

- Fehlende Save-Datei beim Laden: Operation wird defensiv beendet (kein Absturz, kein Kontextwechsel).
- Unbekanntes Legacy-Format: Warnung, keine erzwungene Konvertierung.
- Inkonsistente Tile-Referenz nach Mapping: Fallback auf Basistile.
- Keyboard-Abbruch bei neuer Game-Erstellung: keine Neuerstellung, Grid wird sauber aktualisiert.
- Fehler in laufender RoomOperation: Overlay zeigt Fehlerstatus; Room bleibt stabil bedienbar.

## 6.6 Szenario: Offline-Import PNG -> neuer Room (Tools/Importer)

1. Nutzer oeffnet Tools/Importer/index.html lokal im Browser.
2. Nutzer laedt eine bestehende Pulp-JSON; die Struktur wird gegen rooms/tiles/frames validiert.
3. Nutzer laedt eine PNG; das Tool normalisiert auf 200x120 mit Letterboxing/Pillarboxing.
4. Das normalisierte Bild wird in 25x15 Tiles zu je 8x8 zerlegt und binarisiert.
5. Pro Tile wird ein FNV-1a-Hash berechnet; vorhandene Tiles werden wiederverwendet, neue Tiles/Frames nur bei Hash-Miss angelegt.
6. Das Tool erzeugt einen neuen Room mit 375 Tile-Referenzen und ergaenzt neue Tile-IDs in editor.sortedTiles[4].
7. Export liefert eine neue JSON-Datei; Originaldateien bleiben unveraendert.

Ergebnis: Konsistente Erweiterung eines Pulp-Dokuments um einen importierten Room ohne direkten In-Place-Schreibzugriff.
