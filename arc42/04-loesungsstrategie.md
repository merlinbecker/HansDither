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
- Keine Netzwerk- oder Mehrbenutzerfunktionen.
- Keine direkte Runtime-Integration des Importers ins Playdate-UI (bewusst separates Offline-Werkzeug).
- Keine Migration alter Pulp-Spielstaende nach v0.3.0 (bewusst ausserhalb des Umfangs).

## 4.5 Strategische Neuausrichtung v0.3.0 (beschlossen)

Der Planungsschnitt v0.3.0 ersetzt die Leitentscheidungen 3 und 10 sowie Teile von 8:

1. SDK-first (Constitution Prinzip I): Das offizielle SDK wird maximal ausgenutzt; Eigenimplementierungen nur, wenn das SDK die Funktion nicht abdeckt. SDK-Entscheidungen werden hier und in Kapitel 9 benannt.
2. Eine einzige Aufloesungsebene: Daten und Anzeige arbeiten nativ auf 400x240 mit 16x16-Tiles (25x15-Raster). Das duale Aufloesungskonzept (Pulp-Arbeitsraum + Anzeige-Scaling) entfaellt.
3. Natives Speicherformat: PDI-Tilemap (deduplizierte Tiles) + Positions-JSON je Frame ersetzt das Pulp-JSON-Dokument samt Merge-Logik (PulpGameIO* entfaellt).
4. Verkuerzter Workflow: Startscreen -> ein Auswahlscreen (3x3-Kreisraster, endloses Scrollen, unbegrenzt viele Bilder) -> Editor. Die Rooms-Ebene und der globale Tile-Picker entfallen.
5. Animation als Kernfeature: Crank steuert Frames (max. 12, Kopie-Semantik, Rotation); B+Crank steuert die drei Zoomstufen (Malbreite 16x16-Tile / 2x2-Block / 1x1-Pixel).

Damit entfaellt das bisherige Nicht-Ziel "keine Multi-Frame-Animationstools"; die Frame-Verwaltung wird bewusst minimal gehalten (Prinzip IV der Constitution). Die Feature-Spezifikationen liegen unter `specs/001-pdi-storage-format`, `specs/002-start-selection-screen` und `specs/003-editor-animation-zoom`.

## 4.6 Ebenen & Pixel-Transparenz (Spec 010)

Der Editor erhaelt Ebenen, praezises Pixel-Verschieben und Transparenz.
Leitentscheidungen (Details in Kapitel 9, AD-039..AD-042):

1. **Feste 3-Ebenen-Struktur je Frame.** Jeder Frame hat genau 3 Ebenen,
   immer — eine harte Grenze wie MAX_FRAMES = 12. Kein Hinzufuegen/Loeschen
   von Ebenen (AD-039). Eine komplett leere obere Ebene wird auf Platte
   weggelassen und beim Laden wieder ergaenzt; Alt-Bilder (eine flache
   Ebene) laden als Ebene 1 + zwei leere obere.
2. **Transparenz pro Pixel im Tile.** Ein transparenter Pixel ist
   `gfx.kColorClear` im 16×16-Tile-Bild — kein Nebendaten-Array.
   `ImageStoreCodec.hashTile` unterscheidet drei Pixelklassen
   (schwarz/weiss/transparent), sodass Transparenz-Varianten getrennt
   dedupliziert werden (AD-040). Der „Nicht-Tinte“-Zustand ist
   ebenenabhaengig: weiss auf Ebene 1, transparent auf Ebenen 2–3.
3. **Compositing als flacher Cache.** `imageData.frameLayers` (3 Ebenen)
   ist die Wahrheit; `imageData.frames` ist ein daraus abgeleiteter
   flacher 375er-Cache (oberste nicht-leere Zelle gewinnt), den die
   bestehende Tilemap zeichnet — kein neuer Renderpfad (AD-041). Nur die
   aktive Ebene ist editierbar.
4. **US4 = Frame-Verwaltung.** Ein neuer `FrameManagementView` (Halten B +
   Kurbel rueckwaerts) laesst Frames anordnen und loeschen (min. 1). Keine
   Layer View — Ebenen sind fest (AD-041).
5. **Tile-View-Steuerung (AD-042, 4. Runde aus dem Hardware-Test):**
   **B + Hoch/Runter** waehlt die aktive Ebene, **B + Links/Rechts** den
   Frame (Rechts am Ende: neuer Frame), die **freie Kurbel** oeffnet einen
   Tile-Picker ueber die referenzierten Kacheln, die Pipette meldet kurz
   „Tile N picked“. **B + Kurbel** (Zoom / Frame-Verwaltung) bleibt
   unveraendert. Ebenen-/Frame-Wechsel liegen damit nicht mehr auf der
   Kurbel.

Speicherformat `frames.json` steigt auf Version `"1.1"`
(`frames[].layers[].{layerIndex, name, positions[375], visible}`); v1.0
wird strukturbasiert erkannt und automatisch migriert. Spezifikation:
`specs/010-layer-management-with-transparency/`.
