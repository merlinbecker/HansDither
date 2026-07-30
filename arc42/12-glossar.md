# 12. Glossar

## Begriffe des Ist-Zustands (v0.3.0)

| Begriff | Definition |
|---|---|
| Room | Funktionsmodul mit eigener Update-/Input-Logik (z. B. SelectionRoom, EditorRoom). |
| Bild | Flache Speichereinheit (ersetzt Game/Room aus v0.2): 400x240 Pixel, 25x15-Raster aus 16x16-Tiles, 1-12 Frames. |
| Tile | 16x16-Bildbaustein, der im 25x15-Raster an Positionen referenziert wird; dedupliziert in der Imagetable. |
| Frame | Eine von maximal 12 Animationsstufen eines Bildes; neue Frames entstehen als Kopie des direkten Vorgaengers. |
| Imagetable | Playdate-Struktur fuer die Indexliste der deduplizierten Tiles; waechst beim Malen dynamisch. |
| Tilemap | SDK-Rasterstruktur, die Tile-Indizes auf Positionen abbildet und den aktiven Frame zeichnet. |
| imageData | Laufzeitrepraesentation eines Bildes: {id, name, imagetable, frames, hashIndex}. |
| hashIndex | Abbildung FNV-1a-Hash -> Tile-Index; Grundlage der Deduplizierung in Codec und Zoom-Commit. |
| PDI | Natives Playdate-Bildformat; Ablageformat der deduplizierten Tile-Sammlung (sheet.pdi) und der Previews. |
| Positions-JSON | frames.json: je Frame 375 Tile-Indizes des 25x15-Rasters. |
| Aktives Zeichen-Tile | Per Pipette (B) gewaehltes Tile, das A an der Cursor-Position zeichnet; ohne Auswahl toggelt A Schwarz/Weiss. |
| Pipette | Kurzes B im Editor: uebernimmt das Tile unter dem Cursor als aktives Zeichen-Tile; auf Weiss = Abwahl. |
| Zoom Room | Mittlere Zoomstufe: 24x24-Malraster ueber dem 3x3-Tile-Kontext; ein Malstrich setzt 2x2 native Pixel. |
| Pixel Room | Tiefste Zoomstufe: ein Tile mit echten 16x16 Pixeln; ein Malstrich setzt 1 Pixel. |
| Slot (Zoomkontext) | Einer der 9 Teilbereiche (3x3) im Zoom Room, die je einem 16x16-Tile entsprechen; Randslots sind out-of-bounds. |
| All Similar | PixelRoom-Option: bearbeitet ein bestehendes Tile in-place in der Imagetable und wirkt damit auf alle Verwendungen ueber alle Frames (dokumentierte FR-013-Ausnahme). |
| Bauchbinde | Wiederverwendbares, zustandsloses Zeichen-Helferlein fuer Hinweisbaender, u. a. fuer die Frame-Anzeige "Frame n/m". Die Frame-Positions-Bauchbinde im EditorRoom blendet seit Spec 006 nach 5s Inaktivitaet aus und positioniert sich auf der dem Cursor gegenueberliegenden Bildschirmhaelfte (Timer-/Seitenlogik lebt im EditorRoom, nicht im Modul selbst); die separate Status-Bauchbinde (Fehlertexte) ist davon unberuehrt. |
| GridView | UI-Komponente fuer Rasternavigation und Zellrendering (SelectionRoom, PixelRoom). |
| RoomOperation | Coroutine-Orchestrierung fuer room-lokale Langlaeufer inkl. loadingBar-Lifecycle. |
| save + exit | Systemmenue-Aktion des Editors: automatisches Speichern und Rueckkehr zum SelectionRoom (Verlassen ohne Speichern existiert nicht). |
| clear screen | Systemmenue-Aktion des Editors (Spec 008, AD-037, ersetzt "reset frame" vollstaendig): setzt alle 375 Tile-Indizes des aktiven Frames auf den Voll-Weiss-Basisindex; andere Frames bleiben unveraendert. |
| Kontext-/Pause-Ansicht | Erweiterung des nativen System-Pause-Menues (Spec 006, AD-031): ein via `playdate.setMenuImage()`/`gameWillPause()` erzeugtes Bild zeigt zusaetzlich zu Volume/Home/Screenshot eine Tile-Uebersicht (bis zu 120 Vorschauen im 12x10-Raster) sowie Gesamt-Tile-Anzahl und Frame-Anzahl des aktuell geoeffneten Bildes. |
| Zoom-Room-Hintergrund-Cache | Einmalig aufgebautes Offscreen-Bild (Spec 008, AD-035) mit dem statischen Anteil des Zoom-Room-Rasters (Checkerboard, unbearbeitete Zellen, Gitterlinien); ersetzt die vorherige Vollbild-Neuzeichnung pro Interaktion durch einen Blit plus wenige geaenderte Zellen. |
| Pixel-Rotation | Funktion des Pixel Room (Spec 008, AD-036): eine volle Kurbelumdrehung ohne gehaltene B-Taste dreht das aktuelle 16x16-Tile per exaktem Index-Remap um 90 Grad (vorwaerts im Uhrzeigersinn, rueckwaerts gegen den Uhrzeigersinn). |
| Preview | Gespeichertes Vorschaubild eines Bildes (preview.pdi), gerendert aus Frame 1. |

## Historische Begriffe (Pulp-Aera, bis v0.2)

| Begriff | Definition |
|---|---|
| Pulp-Dokument | Vollstaendige JSON-Struktur fuer Pulp-kompatible Spielinhalte; ab v0.3.0 nicht mehr gelesen oder geschrieben. |
| Pulp-Arbeitsraum | Fruehere Datenaufloesung des Editors: 25x15 Tiles à 8x8 Pixel bzw. 200x120 pro Room; entfallen mit AD-016. |
| Offscreen-Buffer | Zwischenbild (200x120), das der fruehere TileRoom 2x skaliert ausgab; entfallen mit AD-016. |
| gameData / pulpState | Fruehere interne Arbeits- und Mapping-Datenstrukturen des Pulp-Pfads; ersetzt durch imageData. |
| Kompaktierung | Entfernen ungenutzter Tiles vor dem Pulp-Save; im v0.3.0-Pfad derzeit nicht vorhanden (siehe R-13). |
| Save + Back | Fruehere Systemmenue-Aktion des TileRoom; ersetzt durch "save + exit". |
| Game / Room (Pulp) | Fruehere zweistufige Inhaltshierarchie; ersetzt durch flache Bilder (AD-018). |
