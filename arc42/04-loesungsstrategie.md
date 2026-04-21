# 4. Loesungsstrategie

## 4.1 Strategische Leitentscheidungen

1. Room-basierte Architektur statt monolithischer Spielschleife.
2. Tile-zentrierte Darstellung fuer effizientes Zeichnen und Speichern.
3. Trennung zwischen interner Arbeitsstruktur und externem Pulp-Dokument.
4. Schrittweise Feature-Erweiterung ueber klar begrenzte Konzepte (Grid, Tilemap, Picker, Save/Load, Rooms).

## 4.2 Begruendung

- Die Room-Trennung reduziert Kopplung: Auswahl, Laden, Editieren und Pixel-Detailbearbeitung bleiben isoliert.
- Tilemap/Imagetable reduziert Zeichenaufwand und passt zur Pulp-Denkweise.
- Das PulpGameIO-Modul adressiert das zentrale Risiko der Formatinkompatibilitaet durch normalisieren, mappen und merge-basiertes Speichern.
- Konzeptplaene in plans/ und support/concepts zeigen die iterative Umsetzung und begruenden die aktuelle Architektur evolutionaer.

## 4.3 Qualitaetszielbezug

| Qualitaetsziel | Strategiebeitrag |
|---|---|
| Zuverlaessige Persistenz | Versionierte Save-Pipeline, Kompaktierung + stabile ID-Mappings, Preview-Erzeugung. |
| Bedienbarkeit | Konsistente Grid-Navigation in GameRoom/LoadRoom/TileRoom/PixelRoom. |
| Pulp-Kompatibilitaet | Build/Prepare-Workflow in PulpGameIO mit Feld-Erhalt und Defaults. |
| Wartbarkeit | Module pro Verantwortungsbereich, wenig globale Quervernetzung. |
| Performance | needsRedraw-Ansatz, einfache 8x8-Tiles, limitierte Grid-Groessen. |

## 4.4 Nicht-Ziele der aktuellen Version

- Kein Cloud-Sync oder externer Datenaustausch.
- Kein Undo/Redo-Stack.
- Keine komplexen Multi-Frame-Animationstools im Editor-UI.
- Keine Netzwerk- oder Mehrbenutzerfunktionen.
