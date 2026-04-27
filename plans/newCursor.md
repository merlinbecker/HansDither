# Refactoring-Plan: Globaler Pencil-Cursor

## Ziel
Ein einheitlicher Cursor (Pinsel) soll global in einer eigenen Datei definiert werden und in allen Editier-Raeumen ueber eine zentrale Draw-Methode gerendert werden.

Vorgaben:
- kein Blinken mehr
- in jedem Raum in Zellgroesse zeichnen
- Dither-Pattern aus Schwarz/Weiss
- Mitte transparent (Inhalt darunter sichtbar)

## Analyse des Ist-Zustands
Aktuell existieren drei unterschiedliche Cursor-Implementierungen:
1. `Source/TileRoomEditor.lua`
- Cursor als kleiner Kreis
- blinkt ueber `cfg.cursorBlinker.on`
2. `Source/PixelRoom.lua`
- Cursor als kleiner Kreis
- blinkt ueber `cursorBlinker.on`
3. `Source/ZoomRoom.lua`
- Cursor als invertiertes Rechteck
- blinkt ueber `cursorBlinker.on`

Gemeinsamkeit:
- alle drei Loesungen sind lokal implementiert
- alle drei nutzen Blinker-Animationen

## Zielarchitektur
Neue zentrale Datei:
- `Source/PencilCursor.lua`

Public API:
- `PencilCursor.draw(x, y, width, height)`

Verhalten der Methode:
- zeichnet nur einen dithernden Rahmen (Schachbrett aus Schwarz/Weiss)
- Rahmenbreite skaliert mit Zellgroesse
- Innenflaeche bleibt unangetastet (transparent)

## Geplante Code-Aenderungen
1. Neue Komponente erstellen
- `Source/PencilCursor.lua` mit zentraler Zeichenlogik.

2. TileRoom-Flow anpassen
- `Source/TileRoomEditor.lua`
  - Import der neuen Komponente
  - Ersetzen der lokalen Cursor-Zeichnung durch `PencilCursor.draw(...)`
  - Entfernen der Blinker-Abhaengigkeit
- `Source/TileRoom.lua`
  - Entfernen von Blinker-Erzeugung/Update-Logik
  - Entfernen von `cursorBlinker` aus `TileRoomEditor`-Config

3. PixelRoom anpassen
- `Source/PixelRoom.lua`
  - Import der neuen Komponente
  - Ersetzen der Blinker-basierten Cursor-Zeichnung durch `PencilCursor.draw(...)`
  - Entfernen von Blinker-State und Update-Logik

4. ZoomRoom anpassen
- `Source/ZoomRoom.lua`
  - Import der neuen Komponente
  - Ersetzen der Cursor-Blink-Logik durch immer sichtbare `PencilCursor.draw(...)`
  - Entfernen von Blinker-State und Update-Logik

5. Konsistenzpruefung
- Suche nach verbleibenden Blinker-Cursor-Referenzen
- Pruefen, dass Cursor in allen drei Editier-Raeumen einheitlich wirkt
- statische Fehlerpruefung auf geaenderten Dateien

## Nicht-Ziel (bewusst ausgenommen)
- Selektionsdarstellungen in Listen-/Menue-Raeumen (`GameRoom`, `LoadRoom`) bleiben unveraendert, da sie keine Pinsel-Cursor fuer das Tile/Pixel-Editing sind.

## Risiken und Mitigation
1. Performance durch Pixel-fuer-Pixel-Rahmenzeichnung
- Mitigation: nur beim Redraw zeichnen; Zellgroessen sind klein bis moderat.

2. Sichtbarkeit auf extremen Mustern
- Mitigation: alternierender Schwarz/Weiss-Rahmen fuer maximalen Kontrast auf hellen und dunklen Hintergruenden.

3. Randfaelle bei kleinen Zellgroessen
- Mitigation: Mindest-Rahmenbreite 1 Pixel, obere Begrenzung relativ zur Zellgroesse.
