# 5. Bausteinsicht

## 5.1 Whitebox Gesamtsystem

Das Gesamtsystem besteht aus einer Room-Orchestrierung und funktionsspezifischen Rooms fuer Auswahl, Laden und Editieren.

### Enthaltene Bausteine

| Baustein | Verantwortung |
|---|---|
| main.lua | Initialisierung, Room-Verdrahtung, zentrales playdate.update, Terminate-Hook. |
| TitleRoom | Einfacher Einstieg/Startbildschirm. |
| GameRoom | Auswahl/Anlage/Loeschen von Games inklusive Vorschauen. |
| LoadRoom | Auswahl/Anlage/Loeschen von Rooms innerhalb eines Games. |
| TileRoom | Haupteditor fuer Room-Tiles, Picker, Save + Back, Grid-Logik. |
| ZoomRoom | Zwischeneditor fuer 3x3 Tilekontext als 24x24 Pixelgrid inkl. Batch-Rueckgabe. |
| PixelRoom | Detaileditor fuer einzelne 8x8-Tiles auf Pixel-Ebene. |
| loadingBar | Einheitliches Overlay fuer Lade-/Speicherfortschritt. |
| RoomOperation | Gemeinsame Coroutine-Orchestrierung fuer room-lokale Langlaeufer. |
| LoadRoomGrid | UI-/Navigationshelfer fuer LoadRoom-Grid und Vorschauen. |
| TileRoomPersistence | Persistenz- und Datenmodelllogik fuer TileRoom. |
| TileRoomEditor | Interaktions- und Zeichnungslogik fuer TileRoom. |
| PulpGameIO (Facade) | Oeffentliche API fuer Save/Load und Mapping. |
| PulpGameIOShared | Gemeinsame Hilfslogik fuer Template, Normalisierung und Dokumentaufbau. |
| PulpGameIOSave | Save-seitiger Dokumentaufbau. |
| PulpGameIOLoad | Load-seitige Vorbereitung und Mapping. |
| Tools/Importer (index.html, app.js) | Lokales Browser-Tool fuer PNG-Import in Pulp-JSON inkl. Dedupe und Export. |

### Wichtige Schnittstellen

- switchRoom(newRoom): room-uebergreifende Navigation inklusive Input-Handler-Wechsel.
- TileRoom:setGame(name, data, pulpState): Kontextuebergabe vor Room-Editing.
- TileRoom:getTileContext3x3()/applyTileEditsBatch(edits): Kontextbereitstellung und Ruecknahme geaenderter Zoom-Slots.
- ZoomRoom:setFromTileContext(context): Uebernahme des 3x3-Umfelds inkl. showGrid-Synchronisierung.
- TileRoom:saveToFile(afterSave): asynchroner Persistenz-Trigger inkl. Callback fuer Folgeaktion.
- RoomOperation:start()/resume(): generischer Ablauf fuer Coroutine + loadingBar-Lifecycle.
- PulpGameIO.prepareLoadedGame()/buildSaveDocument(): Konvertierung zwischen Datenformen.

## 5.2 Ebene 2

### 5.2.1 Whitebox main.lua

Verantwortung:
- Imports aller Rooms und CoreLibs
- Verkabelung der Room-Abhaengigkeiten
- Lebenszyklusverwaltung

Interne Logik:
- currentRoom als Single-Point-of-Truth fuer Update und Input.
- Beim Raumwechsel werden Input-Handler ausgetauscht, danach entered() aufgerufen.

### 5.2.2 Whitebox Navigationsrooms (TitleRoom, GameRoom, LoadRoom)

Gemeinsame Eigenschaften:
- UI-Rendering mit gridview und Statuszeile.
- pending-Mechanismus fuer verzögerte Uebergaenge nach Keyboard/Animation.
- Systemmenue-Eintraege fuer Kontextaktionen (Zurueck, Loeschen).

Spezifische Verantwortung:
- GameRoom verwaltet Games und Indexdatei.
- LoadRoom verwaltet Rooms eines gewaehlten Games.

### 5.2.3 Whitebox TileRoom

Verantwortung:
- Haupt-Arbeitsflaeche fuer Tiles im Room.
- Cursor, Hintergrundmodus (Show Grid), Tile Picker per Crank.
- Tile-Komprimierung und Persistenz-Aufbereitung.

Besonders relevante interne Teile:
- TileRoomEditor kapselt Cursor, Picker, Richtungshalten und Eingabelogik.
- TileRoomPersistence kapselt Deduplizierung, Kompaktierung, Preview-Render und Room-Sync.
- Save + Back nutzt RoomOperation + loadingBar fuer phasenweises Speichern.

### 5.2.4 Whitebox ZoomRoom

Verantwortung:
- 3x3-Tilekontext aus TileRoom als 24x24 Pixelarbeitsflaeche darstellen.
- Slot-Mapping (3x3) inkl. out-of-bounds Behandlung verwalten.
- Aenderungen nur bei Differenz als Batch an TileRoom zurueckgeben.
- showGrid-Status aus TileRoom uebernehmen und inter-tile Rasterlinien entsprechend ein-/ausblenden.

Interne Logik:
- gridState als boolesches 24x24 Raster.
- tileSlots mit originalTileIndex/originalTileImage fuer Aenderungsvergleich.
- commitAndReturnToTileRoom() erzeugt nur geaenderte Edits und nutzt Neu/Dedupe-Pfad in TileRoom.

### 5.2.5 Whitebox PixelRoom

Verantwortung:
- 8x8-Pixelbearbeitung eines ausgewaehlten Tiles.
- Rueckgabe entweder als neues Tile oder in-place-Aenderung (All Similar).

Interne Logik:
- gridState als boolesches Pixelraster.
- Menueaktionen: All Similar, Invert.
- B+Crank-Pattern fuer Ruecksprung und Uebergabe.

### 5.2.6 Whitebox PulpGameIO

Verantwortung:
- Fassade fuer Save-/Load-Operationen und Mapping.
- Aufteilung in Shared-/Save-/Load-Teile mit klaren Verantwortlichkeiten.

Interne Logik:
- prepareLoadedGame() normalisiert eingehende Daten in mehreren Fortschrittsphasen.
- buildSaveDocument() erzeugt konsistentes Ausgabedokument in schrittweisen Phasen.
- remapTileMappings() passt Mapping nach Tile-Kompaktierung an.

### 5.2.7 Whitebox LoadRoom

Verantwortung:
- Orchestriert Laden eines Spiels nach Room-Eintritt statt synchron beim Setzen des Kontexts.
- Delegiert Grid-/Previewdarstellung an LoadRoomGrid.
- Nutzt RoomOperation + loadingBar fuer sichtbaren Ladefortschritt.

Interne Logik:
- setGame() setzt nur Kontext und markiert, ob ein Load beim Eintritt noetig ist.
- entered() startet fuer bestehende Spiele die Ladeoperation.
- update() resume't laufende Operationen und blockiert konkurrierende Navigation.

### 5.2.8 Whitebox Tools/Importer

Verantwortung:
- Laedt Pulp-JSON und PNG lokal im Browser.
- Rendert Rooms und Tile-Palette zur Sichtpruefung.
- Fuehrt PNG->Tile-Pipeline durch (200x120 Normalisierung, 25x15 x 8x8-Slicing, FNV-1a-Dedupe).
- Erzeugt neuen Room sowie ggf. neue tiles/frames und bietet Export als neue JSON-Datei an.

Interne Logik:
- app.js validiert die Kernstruktur (rooms/tiles/frames) defensiv.
- Hash-Cache wird aus vorhandenen Tiles aufgebaut; neue Tiles werden nur bei Hash-Miss angelegt.
- editor.sortedTiles wird robust behandelt und neue Tile-IDs werden in Gruppe 4 ergänzt.
- Das Tool schreibt nie in bestehende Dateien, sondern nur ueber Download der Exportdatei.

## 5.3 Ebene 3 (fokussiert)

### 5.3.1 Persistenz-Substruktur in TileRoom
- Input: aktueller Room-State + gameData + pulpState
- Verarbeitung: sync -> compact (inkrementell) -> rebuild tiles/frames -> buildSaveDocument (inkrementell)
- Output: datastore-JSON + Room-/Game-Previewbilder

### 5.3.2 Mapping-Substruktur in PulpGameIO
- Input: internes Arbeitsmodell (0-basiert kompakt)
- Verarbeitung: stabile oder neu vergebene externe IDs
- Output: Pulp-Dokument mit erhaltenen Metafeldern und aktualisierten Kerninhalten
