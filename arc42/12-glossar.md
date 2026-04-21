# 12. Glossar

| Begriff | Definition |
|---|---|
| Room | Funktionsmodul mit eigener Update-/Input-Logik (z. B. GameRoom, TileRoom). |
| Tile | 8x8-Bildbaustein, der in Rooms an Rasterpositionen verwendet wird. |
| Imagetable | Playdate-Struktur fuer eine Indexliste von Bildern (Tiles). |
| Tilemap | Rasterstruktur, die Tile-Indizes auf Positionen abbildet und zeichnet. |
| GridView | UI-Komponente fuer Rasternavigation und Zellrendering. |
| Pulp-Dokument | Vollstaendige JSON-Struktur fuer Pulp-kompatible Spielinhalte. |
| gameData | Interne, kompakte Arbeitsdarstellung des Editors (rooms/tiles/frames). |
| pulpState | Persistente Mapping- und Dokumentdaten fuer kompatibles Speichern. |
| Kompaktierung | Entfernen ungenutzter Tiles und Neuabbildung der Referenzen. |
| Preview | Gespeichertes Vorschaubild eines Games oder Rooms im Datastore. |
| Save + Back | Systemmenue-Aktion: Speichern des aktuellen Zustands und Rueckkehr zu LoadRoom. |
| All Similar | PixelRoom-Option: Bearbeitet ein bestehendes Tile in-place statt neues Tile zu erzeugen. |
