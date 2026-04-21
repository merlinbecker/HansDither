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
| PixelRoom | Detaileditor fuer einzelne 8x8-Tiles auf Pixel-Ebene. |
| PulpGameIO | Normalisierung und Merge zwischen Arbeitsdaten und Pulp-Dokument. |

### Wichtige Schnittstellen

- switchRoom(newRoom): room-uebergreifende Navigation inklusive Input-Handler-Wechsel.
- TileRoom:setGame(name, data, pulpState): Kontextuebergabe vor Room-Editing.
- TileRoom:saveToFile(): Persistenz-Pipeline inkl. Kompaktierung, Mapping und Preview.
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
- imageHash + findOrAppendImage zur Deduplizierung.
- compactTileState() fuer remapping und Entfernen ungenutzter Tiles.
- syncCurrentRoomToGameData() als Bruecke UI -> Datenmodell.

### 5.2.4 Whitebox PixelRoom

Verantwortung:
- 8x8-Pixelbearbeitung eines ausgewaehlten Tiles.
- Rueckgabe entweder als neues Tile oder in-place-Aenderung (All Similar).

Interne Logik:
- gridState als boolesches Pixelraster.
- Menueaktionen: All Similar, Invert.
- B+Crank-Pattern fuer Ruecksprung und Uebergabe.

### 5.2.5 Whitebox PulpGameIO

Verantwortung:
- Laden und Mergerhaltung des Pulp-Dokuments.
- Mapping interner kompakter IDs auf externe sparse IDs.
- Auffuellen fehlender Pflichtbereiche aus Template.

Interne Logik:
- prepareLoadedGame() normalisiert eingehende Daten.
- buildSaveDocument() erzeugt konsistentes Ausgabedokument.
- remapTileMappings() passt Mapping nach Tile-Kompaktierung an.

## 5.3 Ebene 3 (fokussiert)

### 5.3.1 Persistenz-Substruktur in TileRoom
- Input: aktueller Room-State + gameData + pulpState
- Verarbeitung: sync -> compact -> rebuild tiles/frames -> buildSaveDocument
- Output: datastore-JSON + Room-/Game-Previewbilder

### 5.3.2 Mapping-Substruktur in PulpGameIO
- Input: internes Arbeitsmodell (0-basiert kompakt)
- Verarbeitung: stabile oder neu vergebene externe IDs
- Output: Pulp-Dokument mit erhaltenen Metafeldern und aktualisierten Kerninhalten
