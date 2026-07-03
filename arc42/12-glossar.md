# 12. Glossar

| Begriff | Definition |
|---|---|
| Room | Funktionsmodul mit eigener Update-/Input-Logik (z. B. GameRoom, TileRoom). |
| Tile | 8x8-Bildbaustein, der in Rooms an Rasterpositionen verwendet wird. |
| Imagetable | Playdate-Struktur fuer eine Indexliste von Bildern (Tiles). |
| Tilemap | Rasterstruktur, die Tile-Indizes auf Positionen abbildet und zeichnet. |
| ZoomRoom | Zwischenraum zwischen TileRoom und PixelRoom, der einen 3x3 Tilebereich als 24x24 Pixelraster bearbeitbar macht. |
| GridView | UI-Komponente fuer Rasternavigation und Zellrendering. |
| Pulp-Dokument | Vollstaendige JSON-Struktur fuer Pulp-kompatible Spielinhalte. |
| Pulp-Arbeitsraum | Interne fachliche Arbeitsaufloesung des Editors: 25x15 Tiles bzw. 200x120 Pixel auf Room-Ebene. |
| Native Anzeigeebene | Physische Runtime-Aufloesung 400x240 bei `playdate.display.setScale(1)`. |
| gameData | Interne, kompakte Arbeitsdarstellung des Editors (rooms/tiles/frames). |
| pulpState | Persistente Mapping- und Dokumentdaten fuer kompatibles Speichern. |
| Offscreen-Buffer | Zwischengerendertes Bild, das TileRoom in 200x120 zeichnet und anschliessend 2x skaliert auf dem Display ausgibt. |
| Kompaktierung | Entfernen ungenutzter Tiles und Neuabbildung der Referenzen. |
| Preview | Gespeichertes Vorschaubild eines Games oder Rooms im Datastore. |
| Save + Back | Systemmenue-Aktion: Speichern des aktuellen Zustands und Rueckkehr zu LoadRoom. |
| Slot (ZoomRoom) | Einer der 9 Teilbereiche (3x3), die jeweils einem 8x8 Tile im Zoom-Kontext entsprechen. |
| All Similar | PixelRoom-Option: Bearbeitet ein bestehendes Tile in-place statt neues Tile zu erzeugen. |

## Begriffe des v0.3.0-Planungsschnitts

| Begriff | Definition |
|---|---|
| Bild | Flache Speichereinheit in v0.3.0 (ersetzt Game/Room): 400x240 Pixel, 25x15-Raster aus 16x16-Tiles, 1-12 Frames. |
| Frame | Eine von maximal 12 Animationsstufen eines Bildes; neue Frames entstehen als Kopie des Vorgaengers. |
| PDI | Natives Playdate-Bildformat; ab v0.3.0 Ablageformat der deduplizierten Tile-Sammlung. |
| Positions-JSON | JSON-Datei, die je Frame die Tile-Referenzen des 25x15-Rasters beschreibt. |
| Aktives Zeichen-Tile | Per Pipette (B) gewaehltes Tile, das A an der Cursor-Position zeichnet; ohne Auswahl toggelt A Schwarz/Weiss. |
| Zoom Room (v0.3.0) | Mittlere Zoomstufe: 24x24-Malraster ueber dem 3x3-Tile-Kontext; ein Malstrich setzt 2x2 native Pixel. |
| Pixel Room (v0.3.0) | Tiefste Zoomstufe: ein Tile mit echten 16x16 Pixeln; ein Malstrich setzt 1 Pixel. |
