# 4. Loesungsstrategie

## 4.1 Strategische Leitentscheidungen

1. Room-basierte Architektur statt monolithischer Spielschleife.
2. Tile-zentrierte Darstellung fuer effizientes Zeichnen und Speichern.
3. Trennung zwischen interner Arbeitsstruktur und externem Pulp-Dokument.
4. Schrittweise Feature-Erweiterung ueber klar begrenzte Konzepte (Grid, Tilemap, Picker, Save/Load, Rooms).
5. Kooperative, frame-freundliche Save/Load-Abarbeitung per Coroutine statt monolithischer Einzelframe-Operation.
6. Einheitliches Lade-/Speicherfeedback ueber ein room-uebergreifend nutzbares loadingBar-Overlay.
7. Separates lokales Importer-Tool fuer PNG->Room-Transformation, ohne Runtime-Komplexitaet auf dem Device zu erhoehen.
8. Editiermodi im TileRoom (TilePickerMode/AnimationMode) mit klarer Input-Semantik (B kurz = Pipette, B lang = Moduswechsel, B+Crank = Zoom mit Vorrang gegenueber dem Long-Press).
9. Wiederverwendbare UI-Bauchbinde als eigenstaendiger Baustein fuer mode- und kontextbezogene Hinweise.
10. Native 400x240-Runtime bei beibehaltener Pulp-Datenaufloesung durch separates Anzeige-Scaling in den Editorrooms.

## 4.2 Begruendung

- Die Room-Trennung reduziert Kopplung: Auswahl, Laden, Editieren und Pixel-Detailbearbeitung bleiben isoliert.
- Tilemap/Imagetable reduziert Zeichenaufwand und passt zur Pulp-Denkweise.
- Das PulpGameIO-Modul adressiert das zentrale Risiko der Formatinkompatibilitaet durch normalisieren, mappen und merge-basiertes Speichern.
- JSON-lastige Save/Load-Schritte werden in fachliche Phasen zerlegt und ueber mehrere Frames verteilt; dadurch bleibt die UI waehrend der Vorbereitung reaktionsfaehig.
- Ein gemeinsames RoomOperation-Muster verhindert doppelte Async-Steuerlogik in LoadRoom und TileRoom.
- Der lokale Importer folgt derselben Tile-Dedupe-Idee (Hashvergleich) wie der Editorpfad und reduziert dadurch Inkonsistenzen zwischen Tooling und Runtime.
- Die Trennung von TilePickerMode und AnimationMode reduziert Eingabekonflikte und schafft einen erweiterbaren Pfad fuer spaetere Animationsfunktionen.
- Die Umstellung auf Display-Scale 1 trennt UI-Schaerfe von Datenkompatibilitaet: Texte und generische UI laufen nativ, waehrend Tile-Editoren ihre Pulp-Arbeitsflaeche gezielt vergroessert rendern.
- Eine zentrale Bauchbinde-Komponente verhindert UI-Duplikate und vereinheitlicht die visuelle Rueckmeldung im Editor.
- Konzeptplaene in plans/ und support/concepts zeigen die iterative Umsetzung und begruenden die aktuelle Architektur evolutionaer.

## 4.3 Qualitaetszielbezug

| Qualitaetsziel | Strategiebeitrag |
|---|---|
| Zuverlaessige Persistenz | Versionierte Save-Pipeline, Kompaktierung + stabile ID-Mappings, Preview-Erzeugung. |
| Bedienbarkeit | Konsistente Grid-Navigation in GameRoom/LoadRoom/TileRoom/ZoomRoom/PixelRoom. |
| Pulp-Kompatibilitaet | Build/Prepare-Workflow in PulpGameIO mit Feld-Erhalt und Defaults. |
| Wartbarkeit | Module pro Verantwortungsbereich, wenig globale Quervernetzung. |
| Performance | needsRedraw-Ansatz, einfache 8x8-Tiles, limitierte Grid-Groessen, kooperative Save/Load-Phasen. |
| Integritaet externer Importe | Importer validiert JSON-Struktur, erzeugt konsistente room/tile/frame-Referenzen und exportiert statt in-place zu schreiben. |
| UI-Schaerfe bei Pulp-Kompatibilitaet | Native 400x240-Ausgabe fuer Schrift/UI bei unveraenderten 8x8-/200x120-Datenstrukturen. |

## 4.4 Nicht-Ziele der aktuellen Version

- Kein Cloud-Sync oder externer Datenaustausch.
- Kein Undo/Redo-Stack.
- Keine komplexen Multi-Frame-Animationstools im Editor-UI.
- Keine Netzwerk- oder Mehrbenutzerfunktionen.
- Keine direkte Runtime-Integration des Importers ins Playdate-UI (bewusst separates Offline-Werkzeug).
