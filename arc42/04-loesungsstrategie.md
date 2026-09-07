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

| Qualitaetsziel (Kap. 1.2) | Strategiebeitrag |
|---|---|
| Verlustfreie Persistenz | Coroutine-Save-Pipeline in fachlichen Phasen; Tile-Deduplizierung (FNV-1a) + Bereinigung ungenutzter Tiles vor dem Speichern (Spec 009, AD-005); Round-Trip-Tests ueber die echte Save/Load-Coroutine. |
| Direkte Bedienbarkeit | Konsistente Grid-Navigation in Selection-/Editor-/Zoom-/Pixel-View; „ein Druck = ein Schritt" fuer Ebene/Frame (AD-042); gleiche Mal-Semantik ueber alle drei Zoomstufen. |
| Native Datenintegritaet | Reiner PDI-/Positions-JSON-Pfad ohne Fremdformat-Merge (AD-017); `frames.json` v1.1 mit strukturbasierter v1.0-Migration. |
| Wartbarkeit | Ein Modul je Verantwortungsbereich, wenig globale Quervernetzung; Room-Abhaengigkeiten per Injection in `main.lua`. |
| Performantes Redraw | needsRedraw-Ansatz, limitierte Rastergroessen, Zoom-View-Hintergrund-Cache (AD-035), kooperative Save/Load-Phasen. |
| SDK-Konformitaet | SDK-Bausteine zuerst (tilemap/imagetable, gridview, keyboard, datastore, QR-Code); begruendete Eigenlogik nur wo noetig (AD-036 Rotation, AD-043 Pixel-Verschiebung, AD-044 Schuettel-Erkennung). |

## 4.4 Nicht-Ziele der aktuellen Version

- Kein Cloud-Sync oder externer Datenaustausch.
- Kein allgemeiner Undo/Redo-Stack. *(Seit Spec 011 gibt es ein bewusst eng begrenztes Schuettel-Undo: nur die letzten 3 riskanten Operationen, kein Redo, keine Persistenz — siehe 4.7.)*
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
Leitentscheidungen (Details in Kapitel 9, AD-039..AD-043):

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
   ebenenabhaengig: weiss auf Ebene 1, transparent auf Ebenen 2–3. Im
   PixelRoom malt **nur A** (A auf Tinte radiert je Ebene nach weiss bzw.
   transparent); B malt nicht (AD-040 Nachtrag, 5. Runde).
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
6. **Pixel-Verschiebung wirkt nur auf die Cursor-Zelle (AD-043, aus dem
   Hardware-Test).** B + Pfeiltaste verschiebt nicht mehr den ganzen Screen /
   die ganze Ebene, sondern nur die Zelle unter dem Cursor plus deren einen
   Nachbarn in Schieberichtung (2-Tile-Streifen, als Ganzes um 1px
   geschoben; die abgewandte Kante des Nachbarn faellt weg, KEIN Wrap). Der
   Inhalt wandert so in den Nachbarn und bleibt dort. `LayerModel.shiftTileContent`
   ersetzt die Ganz-Ebenen-Verschiebung; die Operation (~2500 Ops) laeuft
   synchron je Tastendruck (das gemessene Ganz-Ebenen-Problem —
   ~192.000 `image:sample()` je Druck — und die dafuer erwogene aufgeschobene
   Materialisierung entfallen damit).

Speicherformat `frames.json` steigt auf Version `"1.1"`
(`frames[].layers[].{layerIndex, name, positions[375], visible}`); v1.0
wird strukturbasiert erkannt und automatisch migriert. Spezifikation:
`specs/010-layer-management-with-transparency/`.

## 4.7 Schuettel-Undo fuer riskante Operationen (Spec 011)

Der Editor erhaelt ein bewusst eng begrenztes Undo. Leitentscheidungen
(Details in Kapitel 9, AD-044..AD-046):

1. **Schuettel-Geste statt Menue/Taste.** Einmaliges Links-Rechts-Schuetteln
   oeffnet den Undo-Dialog. Das SDK hat kein Shake-Ereignis; `ShakeDetector`
   ist Eigenlogik auf `playdate.readAccelerometer` (X-Achsen-Zustandsautomat
   `±T`-Peaks / `W`-Fenster / `R`-Refraktaerzeit) — begruendete SDK-Abweichung
   nach Constitution I (AD-044). Der Sensor ist eine **neue Plattformfaehigkeit**
   (arc42 Kap. 2) und laeuft nur in den drei Editier-Views.
2. **Nur die letzten 3 riskanten Operationen, sitzungslokal.** `UndoHistory`
   ist ein Ringpuffer (`MAX = 3`, FIFO) fuer genau vier Operationstypen:
   Clear Screen, Frame loeschen, 90°-Rotation, Pixel-Verschiebung.
   Feingranulares Malen zaehlt nicht (2 Clarifications). Kein Redo, keine
   Persistenz — das Speicherformat bleibt unberuehrt (AD-045).
3. **Voll-Snapshot des Pre-Zustands, keine inversen Deltas.** Jeder Eintrag
   sichert je betroffener Zelle den vorherigen Tile-Index **und** das
   vorherige 16×16-Bild (Frame loeschen = tiefe Kopie). Zwei `apply`-Pfade,
   Anwendung nur in `EditorRoom`. Robust gegen Tile-Sharing/Umnummerierung
   → FR-008 („Speichern leert den Verlauf nicht") bleibt widerspruchsfrei
   (AD-045).
4. **Voll-modaler Dialog, ein Modul.** `UndoPrompt` bildet das bewaehrte
   `SelectionRoom`-Bestaetigungsmuster nach und schluckt bei offenem Dialog
   A/B/D-Pad/Crank in allen drei Views (FR-013). `undoRequest` committet
   offene Zoom-/Pixel-Edits **vor** der Label-Wahl, damit Dialogtext und
   „(A) Ja"-Wirkung zusammenpassen; der Dialog erscheint dann im Tile View
   (AD-046).

Spezifikation: `specs/011-shake-to-undo/`.

## Spec 010 — 8./9. Runde: Frame-Room & Overlay-Konsolidierung (aus dem Hardware-Test)

Zwei Leitentscheidungen (Details: AD-048, AD-049):

1. **Frame-Verwaltung als dauerhafter Room.** Der „B halten"-Modal-View wird
   ein regulaerer Room im `switchRoom`-Rotationsschema. Eintritt unveraendert
   (B + Kurbel rueckwaerts aus dem Tile View), **Verlassen mit B + Kurbel
   vorwaerts** — ausgewertet erst, nachdem B seit `entered()` einmal
   losgelassen wurde (`bReleasedSinceEnter`). Das ersetzt die fragile
   B-Loslassen-Erkennung (Commit `c2cbb6f`) durch eine symmetrische Geste mit
   Arming-Bedingung. Frames als `playdate.ui.gridview`-Thumbnail-Raster wie im
   `SelectionRoom`; A ist ein Markieren/Aufheben-Umschalter, Loeschen +
   Duplizieren liegen im System-Menue (A/B-Bestaetigungsdialog fuer „delete
   frame", wiederverwendet aus `SelectionRoom.confirmingDelete`).

2. **Eine konsolidierte Overlay-Leiste im Tile View.** Frame/Ebenen-Label
   (FR-015), Tile-Picker-Filmstreifen (FR-025), „Tile N picked"-Toast (FR-027)
   und Statusmeldungen teilen sich EINE `Bauchbinde:draw`-Leiste auf der dem
   Tile-Cursor abgewandten Bildschirmzone (`overlayAnchor(cursor.y,
   GRID_ROWS)` → oben/unten). Die Anker-Logik sind reine Funktionen
   (`overlayAnchor`/`overlayRegionRect`/`cursorCellRect`), gegen SC-008
   headless geprueft. Der Undo-Dialog (Spec 011) bleibt eine eigene,
   koordinierte Schicht (Spec 011 FR-013 verlangt volle Modalitaet).

Spezifikation: `specs/010-layer-management-with-transparency/` (Clarifications
8./9. Runde; `spec.md` FR-018..FR-022, FR-028, SC-004, SC-008).
