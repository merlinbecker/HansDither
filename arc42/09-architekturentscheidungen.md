# 9. Architekturentscheidungen

## 9.1 AD-001: Room-basierte Architektur

- Status: umgesetzt
- Entscheidung: Das System wird in spezialisierte Rooms aufgeteilt, statt in einem zentralen Zustandsgiganten.
- Begruendung: Trennung von Verantwortung (Navigation, Auswahl, Editieren, Persistenzfluss).
- Konsequenz: Mehr Module, aber deutlich geringere kognitive Last pro Modul.

## 9.2 AD-002: Tilemap + Imagetable als Rendering-Kern

- Status: umgesetzt
- Entscheidung: Der Editor zeichnet ueber tilemap/imagetable statt ueber reine Pixel-Flaechen fuer den Hauptmodus.
- Begruendung: Performant auf Playdate, direkt kompatibel mit tile-basiertem Datenmodell.
- Konsequenz: Zusätzliche Mappinglogik zwischen Tileindex und Pixel-Detaileditor. Der urspruenglich zugehoerige Crank-Tile-Picker ist mit v0.3.0 entfallen (AD-019); die Tile-Auswahl erfolgt per Pipette (B) direkt aus dem Raster.

## 9.3 AD-003: Zwei Datenebenen fuer Persistenz

- Status: umgesetzt
- Entscheidung: Interne Arbeitsdaten (kompakt) und externes Pulp-Dokument (vollstaendig) werden getrennt behandelt.
- Begruendung: Editorfreundliche Datenhaltung bei gleichzeitiger Formatkompatibilitaet.
- Konsequenz: Hoehere Komplexitaet im Save/Load-Pfad, dafuer robustere Interoperabilitaet.

## 9.4 AD-004: Merge-basierter Save statt Vollersetzung

- Status: umgesetzt
- Entscheidung: Nicht verwaltete Felder des Pulp-Dokuments werden erhalten.
- Begruendung: Verhindert Datenverlust in extern bearbeiteten/erwarteten Dokumentbereichen.
- Konsequenz: Build- und Mappinglogik in PulpGameIO notwendig.

## 9.5 AD-005: Tile-Kompaktierung vor Save

- Status: umgesetzt (v0.2.x, Pulp-Aera); seit dem PDI-Umstieg (AD-017,
  v0.3.0) als wirkungsloser Platzhalter im Code stehengeblieben (Kommentar
  "Phase 1: Dedup (T014 - wird spaeter in US2 implementiert...)" in
  ImageStoreCodec.lua); mit Spec 009 erneut umgesetzt, jetzt fuer das
  PDI-Format in ImageStoreCodec.pruneUnusedTiles()
- Entscheidung: Ungenutzte Tiles werden entfernt, Referenzen remapped, Basistiles immer behalten.
- Begruendung: Spart Speicher, verhindert schleichende Datenaufblaehung.
- Konsequenz: Remap-Fehler sind ein Risiko und muessen abgesichert werden
  (Spec 009: dedizierte Headless-Tests inkl. Round-Trip-Verifikation,
  siehe tests/headless_tests.lua). Invariante: die Bereinigung liefert
  immer mindestens 2 Tiles (Basistiles Weiss/Schwarz), unabhaengig davon,
  ob sie in Frames referenziert werden — verhindert einen Kollaps auf
  tileCount=1 beim ImageStore.createImage()-Neubild-Muster. Reine
  Transformation ohne Live-State-Mutation des Editors: der Editor
  verlaesst nach "save + exit" immer den Raum, ein Sync des aktiven
  Editierzustands ist dadurch nicht noetig (research.md R2, Spec 009).

## 9.6 AD-006: Evolutionaere Feature-Entwicklung

- Status: umgesetzt
- Entscheidung: Erweiterung in geordneten Schritten laut Konzeptplaenen.
- Begruendung: Kleine, kontrollierte Inkremente reduzieren Integrationsrisiko.
- Konsequenz: Historische Planartefakte muessen sauber in finale Doku ueberfuehrt werden.

## 9.7 AD-007: ZoomRoom als Zwischenstufe zwischen TileRoom und PixelRoom

- Status: umgesetzt
- Entscheidung: Zwischen TileRoom und PixelRoom existiert ein eigener ZoomRoom mit 24x24 Pixelarbeitsflaeche fuer einen 3x3 Tilekontext.
- Begruendung: Bearbeitung benachbarter Tiles in einem gemeinsamen Kontext reduziert Wechselkosten und verbessert lokale Konsistenz.
- Konsequenz: Zusaetzliche Mapping- und Commitlogik (Slot -> Tile-Koordinate, Aenderungsvergleich) ist erforderlich.

## 9.8 AD-008: Geaenderte Zoom-Slots nur ueber Dedupe-Pfad committen

- Status: umgesetzt
- Entscheidung: ZoomRoom commitet nur geaenderte Slots; TileRoom verarbeitet diese als Neu/Dedupe (findOrAppendImage + Hashvergleich).
- Begruendung: Verhindert unnoetige Tile-Neuschreibungen und haelt das Verhalten konsistent mit dem bestehenden PixelRoom-Standardpfad.
- Konsequenz: Originalbilder pro Slot muessen fuer den Vergleich im ZoomRoom vorgehalten werden.

## 9.9 AD-009: Room-lokale Coroutine-Operationen fuer Save/Load

- Status: umgesetzt
- Entscheidung: Save- und Load-Aktionen werden als room-lokale Coroutine-Operationen ausgefuehrt (RoomOperation), nicht als monolithische Einzelframe-Funktionen.
- Begruendung: CPU-lastige Vorbereitungsschritte sollen den Frame nicht dauerhaft blockieren; Fortschritt soll sichtbar sein.
- Konsequenz: Eingaben waehrend aktiver Operation muessen gezielt gesperrt werden; Fehlerpfade brauchen expliziten Abschluss.

## 9.10 AD-010: Einheitliches loadingBar-Overlay fuer Langlaeufer

- Status: umgesetzt
- Entscheidung: LoadRoom und TileRoom nutzen dieselbe loadingBar-Komponente fuer Fortschrittsdarstellung.
- Begruendung: Konsistente UX und entkoppelte UI-Komponente ohne Persistenzwissen.
- Konsequenz: Room-Rendering zeichnet Overlay zuletzt; Phasenbezeichnungen muessen pro Ablauf gepflegt werden.

## 9.11 AD-011: Modulare Aufteilung grosser Room- und IO-Dateien

- Status: umgesetzt
- Entscheidung: Aufteilung nach Verantwortungen in LoadRoomGrid, TileRoomEditor, TileRoomPersistence sowie PulpGameIOShared/PulpGameIOSave/PulpGameIOLoad.
- Begruendung: Reduzierte Dateigroesse, klarere Zustandsgrenzen, geringere Wartungskosten.
- Konsequenz: Mehr Modulgrenzen und Schnittstellen, dafuer geringere lokale Komplexitaet.

## 9.12 AD-012: PNG-Import als separates lokales Browser-Tool

- Status: umgesetzt
- Entscheidung: Der PNG->Room-Import bleibt ausserhalb der Playdate-Runtime in Tools/Importer (HTML/CSS/JS).
- Begruendung: Keine zusaetzliche Runtime-Last auf dem Device, schnellere Iteration bei Importlogik, klarer Offline-Workflow.
- Konsequenz: Architektur hat zwei Ausfuehrungskontexte (Device-Runtime und Browser-Tool); Import-/Save-Kompatibilitaet muss ueber gemeinsame Datenregeln abgesichert werden.

## 9.13 AD-013: Kein erzwungener Save beim Room-Anlegen in LoadRoom

- Status: umgesetzt
- Entscheidung: Beim Erzeugen eines neuen Rooms in LoadRoom erfolgt kein sofortiger Persistenzschritt; es wird direkt zu TileRoom gewechselt.
- Begruendung: Room-Erzeugung ist zunaechst eine in-memory Aktion; unmittelbare IO auf einem UX-kritischen Uebergang wird vermieden.
- Konsequenz: Persistenz passiert explizit spaeter ueber Save-Trigger in TileRoom; Nutzerfeedback und Datenintegritaet bleiben ueber den normalen Save-Pfad kontrollierbar.

## 9.14 AD-014: EditMode-Modell im TileRoom mit wiederverwendbarer Bauchbinde

- Status: abgeloest durch AD-019 (v0.3.0)
- Entscheidung: TileRoom verwendet zwei Modi (TilePickerMode/AnimationMode). B kurz fungiert als Pipette, B lang (>=1.5s) toggelt den Modus, B+Crank startet den Zoom und bricht dabei einen pending Long-Press ab. Die Modusrueckmeldung wird ueber die wiederverwendbare Bauchbinde-Komponente angezeigt.
- Begruendung: Entkoppelt unmittelbare Tile-Auswahl von kuenftigen Animationsfunktionen, reduziert Eingabekonflikte und schafft ein einheitliches UI-Muster fuer Hinweise.
- Konsequenz: Zusaetzlicher Zustandsautomat fuer B-Short/Long-Press, Cancel-Pfad und Mode-State notwendig; die Prioritaet zwischen Pipette, Moduswechsel und Zoom muss explizit im Update-Pfad abgesichert werden.

## 9.15 AD-015: Native Runtime-Aufloesung bei beibehaltener Pulp-Datenaufloesung

- Status: abgeloest durch AD-016 (v0.3.0)
- Entscheidung: Die Runtime arbeitet auf nativer Display-Aufloesung 400x240 (`setScale(1)`), waehrend Tile-/Frame-Daten und Room-Previews weiterhin im Pulp-Arbeitsraum (8x8 Tiles, 200x120) verbleiben.
- Begruendung: Allgemeine UI und Schrift sollen schaerfer dargestellt werden, ohne die Persistenz- und Importkompatibilitaet des Pulp-Datenmodells aufzugeben.
- Konsequenz: TileRoom benoetigt einen Offscreen-Buffer fuer skalierte Tilemap-Darstellung; ZoomRoom und PixelRoom arbeiten mit vergroesserten Zellgroessen; Dokumentation und Tests muessen zwei koordinative Ebenen auseinanderhalten.

## 9.16 AD-016: Native Datenaufloesung 400x240 mit 16x16-Tiles

- Status: umgesetzt (v0.3.0), ersetzt AD-015
- Entscheidung: Daten- und Anzeigeaufloesung fallen zusammen: 400x240 nativ, 16x16-Tiles im 25x15-Raster. Der Pulp-Arbeitsraum (8x8 Tiles, 200x120) und das duale Aufloesungskonzept entfallen.
- Begruendung: Volle native Aufloesung fuer Pixelart; wegfallende Koordinatenuebersetzung beseitigt Risiko R-11 und Schuld T-09; Konzeptentscheidung aus dem v0.3.0-Planungsmeeting. Die Zielaufloesung 400x240 ist durch die Playdate-Hardware bestaetigt (der im Meeting genannte Wert "420x240" war ein Versprecher; das Display ist 400x240).
- Konsequenz: TileRoom rendert ohne Offscreen-Skalierung; ZoomRoom (24x24-Grid ueber 3x3 Tiles, 2x2-Malbloecke) und PixelRoom (16x16 echte Pixel) werden auf die neuen Masse umgestellt.

## 9.17 AD-017: PDI-Tilemap + Positions-JSON statt Pulp-JSON

- Status: umgesetzt (v0.3.0), ersetzt AD-003 und AD-004 im Speicherpfad; mit der Entfernung der PulpGameIO*-Module abgeschlossen
- Entscheidung: Ein Bild wird als PDI-Tilemap/Imagetable (via Hashing deduplizierte 16x16-Tiles) plus einer JSON-Datei mit den Tile-Positionen je Animationsframe gespeichert. Das Pulp-JSON-Gesamtdokument und die Merge-Logik (PulpGameIO*) entfallen.
- Begruendung: Native SDK-Formate (Constitution Prinzip II); schnellere Ladezeiten ohne eigenes Dokument-Parsing; Unabhaengigkeit vom Pulp-Oekosystem.
- Konsequenz: Neuer Persistenzbaustein ersetzt PulpGameIOShared/Save/Load; keine Migration alter Saves (bewusstes Nicht-Ziel); Alternative zur JSON-Positionsablage wird in der Planungsphase evaluiert (offen, siehe R-12).

## 9.18 AD-018: Flache Bilder statt Games/Rooms-Hierarchie

- Status: umgesetzt (v0.3.0), ersetzt die LoadRoom-Ebene aus AD-001; mit der Entfernung von LoadRoom/LoadRoomGrid abgeschlossen (SelectionRoom statt GameRoom-Umbau)
- Entscheidung: Es gibt nur noch flache "Bilder" in unbegrenzter Anzahl. Ein einziger Auswahlscreen (3x3-Raster aus Kreisen mit maskierten Thumbnails, endloses Scrollen) fuehrt direkt in den Editor; der Startscreen zeigt das zuletzt bearbeitete Bild als Hintergrund. Verwaltung (Neu/Kopieren/Loeschen) laeuft ueber das Systemmenue.
- Begruendung: Die Games/Rooms-Zwischenebene erzeugte Navigationskosten ohne Mehrwert fuer einen Bild-Editor; feste 6er-Grenzen (R-04) entfallen.
- Konsequenz: LoadRoom/LoadRoomGrid entfallen; GameRoom wird zum Bild-Auswahlscreen umgebaut; Vorschaubilder und "zuletzt bearbeitet"-Markierung kommen aus dem neuen Speicherformat.

## 9.19 AD-019: Crank steuert Animationsframes, B+Crank die Zoomstufen

- Status: umgesetzt (v0.3.0); die „Crank ohne Modifier = Frames“- und (Spec 010, 3. Runde) „Hoch/Runter + Crank = Ebene“-Teile sind durch **AD-042** (4. Runde) abgeloest — siehe §9.30
- Entscheidung: ~~Crank ohne Modifier wechselt Frames~~ (abgeloest, AD-042: Frame = B + Links/Rechts, Ebene = B + Hoch/Runter, freie Kurbel = Tile-Picker). B waehlt das Tile an der Cursor-Position (Pipette), A zeichnet bzw. toggelt Schwarz/Weiss. **B+Crank zoomt durch genau drei Stufen bzw. oeffnet die Frame-Verwaltung — das bleibt unveraendert.** Der B-Long-Press-Moduswechsel entfaellt.
- Begruendung: Animation wird Kernfeature; die Crank-Rastung ist dafuer das natuerliche Eingabemuster. Wegfall des Mode-Automaten reduziert Eingabekonflikte (QS-03a wird obsolet).
- Konsequenz: TileRoomEditor wird umgebaut; Frame-Anzeige ueber Bauchbinde; Positions-JSON speichert je Frame; Kopie-Semantik beim Anlegen neuer Frames.

## 9.20 AD-020: SDK-first als Konstitutionsprinzip

- Status: beschlossen (gueltig ab sofort)
- Entscheidung: Vor jeder Eigenimplementierung wird geprueft, ob das offizielle Playdate SDK die Funktion bietet oder sie sich damit abbilden laesst; so wenig Code wie moeglich ausserhalb des SDK. Jede wesentliche SDK-Nutzung und -Entscheidung wird in diesem Kapitel bzw. Kapitel 4/8 dokumentiert.
- Begruendung: Constitution Prinzip I (`.specify/memory/constitution.md`); reduziert Wartungsaufwand und haelt das Projekt nahe an der Plattform.
- Konsequenz: Kandidaten fuer v0.3.0: gridview (Auswahlraster), image masks (Kreis-Thumbnails), imagetable/tilemap (16x16-Rendering und PDI-Persistenz), animation loop (Frame-Preview), crank getCrankTicks (Frame-/Zoom-Rastung). Abweichungen muessen begruendet werden.

## 9.21 AD-031: Kontext-/Pause-Ansicht via `playdate.setMenuImage()` statt eigenem Pause-Screen

- Status: umgesetzt (Spec 006, US5)
- Entscheidung: Die erweiterte Kontext-/Pause-Ansicht (Tile-Uebersicht + Metainformationen) wird ueber `playdate.setMenuImage()` + `playdate.gameWillPause()` realisiert statt ueber einen eigenen Room/Screen — das 3-Slot-Systemmenue bleibt unangetastet, da `setMenuImage` einen davon unabhaengigen Mechanismus nutzt.
- Begruendung: `gameWillPause()` ist laut SDK-Doku wortwoertlich fuer genau diesen Anwendungsfall vorgesehen (research.md R4); kein neuer, vom Spiel eingefuehrter Eingabeweg noetig, der den nativen Playdate-Pause-Mechanismus verdoppeln wuerde (Constitution IV/Eingabe-Randbedingung).
- Konsequenz: Layout auf die linken 200px begrenzt (SDK-Vorgabe, rechte Haelfte vom System-Menue ueberdeckt); Details in [ADR-031](adr/ADR-031-Pause-Ansicht-setMenuImage.md).

## 9.22 AD-032: "Reset Frame" ersetzt "Delete Frame" im Systemmenue

- Status: umgesetzt (Spec 006, US4, Projektinhaber-Vorgabe)
- Entscheidung: Der dritte Systemmenue-Slot wechselt von "delete frame" auf "reset frame" (kopiert den Vorgaenger-Frame elementweise in den aktiven Frame); "show grid" bleibt unveraendert. `deleteCurrentFrame()` bleibt im Code, verliert aber ihren Menue-Aufrufer.
- Begruendung: Kein freier vierter Menue-Slot, kein kollisionsfreier D-Pad/A/B/Crank-Chord identifiziert (research.md R7); "reset frame" adressiert denselben Fehlerkorrektur-Anwendungsfall wie "delete frame", ohne Frame-Anzahl/-Position zu veraendern.
- Konsequenz: "delete frame" ist ab Spec 006 nicht mehr ueber das Menue erreichbar; ein Folge-Zugriffsweg waere bei Bedarf separat zu klaeren. Details in [ADR-032](adr/ADR-032-Reset-Frame-statt-Delete-Frame-im-Menue.md).

## 9.23 AD-035: Statischer Hintergrund-Cache statt Vollbild-Neuzeichnung im Zoom Room

- Status: umgesetzt (Spec 008, US1)
- Entscheidung: `ZoomRoom:drawGrid()` baut den statischen Anteil (Checkerboard, unbearbeitete Zellen im Subpixel-Zustand, Gitterlinien) einmalig in `cachedBackground` (`gfx.pushContext`/`gfx.popContext`) statt bei jeder Interaktion alle 576 Zellen plus ~2400 Gitterlinien neu zu berechnen; Redraw blittet den Cache und uebermalt nur `changedCells`.
- Begruendung: Code-Review + SDK-Doku (`inside_playdate/Inside Playdate.md`, Profiling-Abschnitt) zeigen, dass die CPU-Zeit fuer die Vielzahl an `sample()`/`drawLine()`-Aufrufen pro Interaktion die Ursache des gemeldeten Ruckelns ist, nicht die Playdate-eigene zeilenweise Display-Diffing (die erst NACH dem Lua-seitigen Zeichnen greift). Der Cache-Ansatz ist im Projekt bereits ueber `buildWorkingImage()` etabliert (Constitution IV/I).
- Konsequenz: Editier-/Commit-Logik unveraendert; Cache muss bei Kontextwechsel/Grid-Toggle explizit invalidiert werden (`backgroundDirty`). Details in [ADR-035](adr/ADR-035-Zoom-Room-Redraw-Cache.md).

## 9.24 AD-036: Pixel-Rotation via Crank-Volldrehung und exaktem Index-Remap

- Status: umgesetzt (Spec 008, US2)
- Entscheidung: Crank OHNE gehaltene B-Taste im Pixel Room (bislang wirkungslos) akkumuliert `getCrankChange()` in `rotationAccumDegrees` (analog `crankAccumDegrees`, Spec 006); bei ±360° netto wird `gridState` per direktem 16x16-Tabellen-Remap um 90 Grad rotiert, NICHT ueber `image:rotatedImage()`/`drawRotated()`.
- Begruendung: Die SDK-Doku warnt explizit vor Performance-Kosten und Dimensions-/Resampling-Eigenheiten der Bildtransformationsfunktionen; da der Editier-Zustand bereits als reine Bool-Tabelle vorliegt, ist ein exakter Index-Remap schneller, verlustfrei und ohne SDK-Aufruf umsetzbar (Constitution I/IV).
- Konsequenz: Pro `update()` weiterhin genau eine Crank-Lese-API (B+Crank-Zoomkette bleibt bei `getCrankTicks(4)` unangetastet). Details in [ADR-036](adr/ADR-036-Pixel-Rotation-Index-Remap.md).

## 9.25 AD-037: "Clear Screen" ersetzt "Reset Frame" vollstaendig im Systemmenue

- Status: umgesetzt (Spec 008, US3, Projektinhaber-Vorgabe)
- Entscheidung: Der dritte Systemmenue-Slot wechselt von "reset frame" (AD-032) auf "clear screen" (`clearCurrentFrame()`, setzt alle 375 Tile-Indizes des aktiven Frames auf den Voll-Weiss-Basisindex 1); "save + exit" und "show grid" bleiben unveraendert. Im Unterschied zu AD-032 wird `resetCurrentFrameToPrevious()` VOLLSTAENDIG aus dem Code entfernt statt als toter Code zu verbleiben.
- Begruendung: Projektinhaber-Vorgabe — die urspruengliche Schutzidee fuer versehentlich bemalte Frames wird bewusst fallengelassen (kein Reset-auf-Vorgaenger mehr); FR-011 fordert explizit vollstaendige Entfernung, nicht nur Entzug des Menue-Zugriffs (Constitution IV — keine Ansammlung toten Codes ohne Grund).
- Konsequenz: "reset frame" ist an keiner Stelle der Oberflaeche mehr erreichbar; `deleteCurrentFrame()` (seit AD-032 bereits ohne Aufrufer) bleibt unveraendert und ausserhalb des Scopes. Details in [ADR-037](adr/ADR-037-Clear-Screen-ersetzt-Reset-Frame.md).

## 9.26 AD-038: Backend-Dateinamen aus `client_image_id` statt separatem Namensfeld

- Status: umgesetzt (Spec 009)
- Entscheidung: Backend-Dateien (PDI intern, JSON, Frame-PNGs, Tilemap-PNG, GIF) werden nach `client_image_id ?? image_id` benannt statt nach der internen Zufalls-UUID allein. `client_image_id` ist der bereits seit Spec 004 bei jedem Sync uebermittelte, auf dem Geraet aus dem Projektnamen abgeleitete und sanitisierte Bezeichner (`ImageStore.sanitizeName()`) — kein neues, separat aus `frames.json` zu parsendes Namensfeld wird eingefuehrt. Die interne `image_id` (DB-Primaerschluessel) bleibt unveraendert die Grundlage fuer `/download/{typ}/{id}`-URLs und die Berechtigungspruefung.
- Begruendung: `client_image_id` ist bereits serverseitig gegen `^[a-z0-9\-]{1,64}$` validiert und bereits `UNIQUE (uid, client_image_id)` — ein zusaetzliches, aus `frames.json` geparstes `name`-Feld waere eine zweite, redundante Wahrheitsquelle fuer dieselbe Information (Constitution IV, research.md R3 zu Spec 009).
- Konsequenz: Update-in-place-Uploads mussten um eine Korrektur ergaenzt werden (die UPDATE-Anweisung aktualisierte bisher nur `png_path`/`gif_path`, nicht `pdi_path`/`json_path` — ohne Korrektur haette die DB nach der ersten Umbenennung eines Bestandsprojekts auf nicht mehr existierende Dateien gezeigt, research.md R4). Zusaetzlich werden bei jedem Re-Sync abgeleitete Render-Artefakte ohne eigene DB-Cache-Spalte (Frame-PNGs ab Index 1, Tilemap-PNG) aktiv geloescht, da sie sonst nach einem Re-Sync mit geaendertem Inhalt unbegrenzt veraltet weiter ausgeliefert wuerden. Details in [ADR-038](adr/ADR-038-Backend-Dateibenennung-client-image-id.md).

## 9.27 AD-039: Feste 3-Ebenen-Struktur je Frame ohne Add/Delete

- Status: umgesetzt (Spec 010, US3/US4, Projektinhaber-Klarstellung 3. Runde)
- Entscheidung: Jeder Frame hat **genau 3 Ebenen, immer** — eine feste Struktur wie die harte 12-Frame-Grenze. Es gibt keine Geste und keine UI zum Hinzufuegen oder Loeschen einer Ebene. `LayerModel` baut/validiert stets exakt 3 Ebenen (`padTo3`); `addLayer`/`deleteLayer` existieren nicht. Eine komplett leere Ebene 2 oder 3 wird beim Speichern **weggelassen** (1–3 Ebeneneintraege auf Platte) und beim Laden wieder auf 3 aufgefuellt — Alt-Bilder bleiben kompakt.
- Begruendung: Kein Add/Delete-Zustandsautomat, kein „aktive Ebene wurde geloescht“-Sonderfall, keine Layer View. `activeLayer` ist ein reiner 1..3-Cursor. Constitution IV (harte, einfache Grenzen ausdruecklich erwuenscht); der Projektinhaber verwarf das Second-Round-Modell „1–3 optionale Ebenen mit Add/Delete“ ausdruecklich.
- Konsequenz: Rueckwaertskompatibel (Alt-Bild → Ebene 1 + 2 leere obere); Frame-Wechsel aendert die Ebenenzahl nie, der aktive Index existiert immer. US4 wird dadurch zur reinen **Frame-Verwaltung**. Details in [ADR-039](adr/ADR-039-Feste-3-Ebenen-Struktur.md).

## 9.28 AD-040: Pixel-Transparenz als `kColorClear` im Tile + 3-Zustands-Hash

- Status: umgesetzt (Spec 010, US2)
- Entscheidung: Transparenz wird **pro Pixel direkt im 16×16-Tile-Bild** als `gfx.kColorClear` gefuehrt — **kein** per-Zelle-`transparency`-Array in `frames.json`. `ImageStoreCodec.hashTile`/`imagesVisiblyEqual` vergleichen **drei Klassen** (schwarz / weiss / transparent), sodass ein weisser und ein transparenter Hintergrund bei gleichem Ink-Muster getrennt dedupliziert werden. Der „Nicht-Tinte“-Zustand je Ebene ist **ebenenabhaengig**: weiss auf Ebene 1 (deren Hintergrund), transparent auf Ebenen 2–3 (damit untere Ebenen durchscheinen). Der Pixel-/Zoom-/Tile-Editierpfad nimmt diesen Off-State je aktiver Ebene entgegen; auf den oberen Ebenen faellt ein komplett weisses Tile auf „absent“ (Position 0) zusammen.
- Begruendung: Ein per-Zelle-Array kann keine gemischt-transparente Zelle ausdruecken und widerspricht der Dedup-Regel (spec.md Edge Case Z. 104). Playdate-1-Bit-Bilder tragen nativ eine Transparenzmaske; die bestehende Sheet-Compose/Slice-Pipeline nutzt bereits `kColorClear`-Hintergruende und erhaelt transparente Pixel unveraendert (Constitution I/II). Alt-Tiles sind nur schwarz/weiss — der 3-Klassen-Hash verhaelt sich fuer sie identisch zum alten 2-Klassen-Hash.
- Konsequenz: `PixelRoom.buildTileImage` startet den Canvas in der Off-State-Farbe; `PixelRoom:setCurrentTile(tile, idx, offStateCode)` und `ZoomRoom`/`EditorRoom.buildZoomContext` (`activeLayerIsBase`) reichen den Zustand durch. Der Radierer (A auf Tinte) auf Ebene 2/3 fuehrt zu „durchsichtig“, nicht zu opak-weiss.
- **Nachtrag 5. Runde (2026-09-01, Hardware-Test):** Im PixelRoom malt **nur A**. Die urspruengliche Spec-010-Zuweisung „B setzt den Nicht-Tinte-Zustand direkt“ (FR-007 alt) ist zurueckgenommen — auf Device unerwuenscht (gemalt wird mit A), und die B-Halten-Zoom-Out-Geste hinterliess bei jedem Loslassen einen ungewollten transparenten Pixel im Tile. `BButtonDown/Up` sind No-ops; B ist im PixelRoom nur noch der Zoom-Out-Modifier. Kein Pixelzustand wird dadurch unerreichbar: der A-Toggle deckt `Tinte ↔ Off-State` je Ebene ab. FR-007 sagt jetzt „B malt nicht in Pixel View“.
- Details in [ADR-040](adr/ADR-040-Pixel-Transparenz-im-Tile.md).

## 9.29 AD-041: Ebenen-Compositing als flacher Cache; US4 = Frame-Verwaltung

- Status: umgesetzt (Spec 010, US3/US4)
- Entscheidung: `imageData.frameLayers[f]` (genau 3 Ebenen) ist die Wahrheit; `imageData.frames[f]` ist ein **daraus abgeleiteter flacher 375er-Cache** (`LayerModel.compositeToFlat`: pro Zelle gewinnt die oberste Ebene mit nicht-leerer Position, sonst das Weiss-Tile), den die bestehende Tilemap zeichnet. Der Cache wird nach **jeder** Ebenen-Mutation (Malen, Shift, „clear screen“, Frame-Add/Wechsel) neu kompositiert; alle Editierpfade des EditorRoom schreiben ueber `writeActiveLayerPosition` ausschliesslich in die aktive Ebene. **US4** ist eine neue `FrameManagementView` (aus dem Tile View per Halten B + Kurbel rueckwaerts): Frames markieren (A), verschieben (Links/Rechts), loeschen (zweiter A-Druck; min. 1 Frame); B loslassen → zurueck. Keine Layer View, keine Animation Layer View.
- Begruendung: Der bestehende Renderpfad zeichnet bereits ein flaches 375er-Array — kein Compositing-Motor noetig (Constitution I/IV). Pixel-genaue Mehr-Ebenen-Ueberblendung (`LayerModel.compositeToTiles`) ist implementiert, aber fuer die „oberste Ebene je Zelle gewinnt“-Darstellung nicht noetig und noch nicht verdrahtet. Fuer US4 brauchen Frames Umordnen/Loeschen (steuerbare Animation), Ebenen nicht (feste Struktur, AD-039). „Zweiter A-Druck loescht“ statt „B loescht“, weil B waehrend der ganzen View gehalten wird (die Halte-Geste haelt den Nutzer in der View) — die Zwei-Schritt-Bestaetigung der ersten Klarstellungsrunde mit A statt B.
- Konsequenz: `EditorRoom:entered()` liest `imageData.returnFrame` und klemmt `currentFrame`/`activeLayer` in die evtl. kuerzere/umgeordnete Sequenz. Der frueher wirkungslose Zweig „B + Kurbel rueckwaerts = aeusserste Zoomstufe“ ist jetzt der Einstieg in die Frame-Verwaltung (FR-024 trivial erfuellt: nirgends eine Schleife). Details in [ADR-041](adr/ADR-041-Compositing-Cache-und-Frame-Verwaltung.md).

## 9.30 AD-042: Tile-View-Steuerungs-Redesign — B + D-Pad statt Kurbel, Kurbel = Tile-Picker

- Status: umgesetzt (Spec 010, 4. Klarstellungsrunde aus dem Hardware-Test)
- Entscheidung: Im Tile View wechselt **B halten + Hoch/Runter** die aktive Ebene (+1/-1, Wrap 1..3) und **B halten + Links/Rechts** den Frame (Rechts am Ende: neuer Frame als tiefe Kopie). Die freie **Kurbel (ohne B)** oeffnet ein **Tile-Picker-Overlay**: je ~30° Netto-Drehung eine Kachel weiter durch die **referenzierten** Tile-Indizes (`referencedTileIndices()` scannt die **Ebenen-Positionen** `frameLayers[*].layers[*].positions`, **nicht** den flachen Composite-Cache `imageData.frames` — sonst faellt eine nur auf einer verdeckten Ebene liegende Kachel heraus — und **nicht** `imagetable:getLength()`), Wrap am Ende, Auto-Ausblenden ~1,5 s nach der letzten Drehung. Die Pipette (kurzer B-Tipp) zeigt kurz „Tile N picked“ in der Bauchbinde. **B + Kurbel vor/zurueck** (Zoomkette / Frame-Verwaltung, AD-019/AD-041) bleibt unveraendert.
- Begruendung: Der Hardware-Test zeigte, dass eine volle 360°-Kurbelumdrehung fuer *einen* Ebenen- bzw. Frame-Schritt zu langsam und ueberdrehanfaellig ist, und dass die Kurbel im Tile View sonst brachliegt. „Ein Druck = ein Schritt“ ist praezise. CR-01 bleibt gewahrt: B-Zweig `getCrankTicks(4)`, Ohne-B-Zweig `getCrankChange()` + `crankAccumDegrees`-Akkumulator mit Sub-360°-Schwelle — nie beide APIs im selben Frame. `bNavConsumed` (in `bDpadNav` gesetzt, nur in `BButtonDown`/`BButtonUp` zurueckgesetzt) verhindert, dass der B-Release nach B + D-Pad zusaetzlich die Pipette ausloest.
- Konsequenz: Entfaellt — Frame-Cyclen per Kurbel-Volldrehung und Ebenen-Cyclen per Hoch/Runter + Kurbel (`layerAccumDegrees` entfernt). Betrifft AD-019 (fuer den EditorRoom), AD-041/US3 und research R3/R4/R9. B ist im Tile View stark ueberladen (Pipette, Ebene, Frame, Zoom, Frame-Verwaltung); die Entflechtung haengt an `bUsedForZoom` **und** `bNavConsumed`. Headless: alte „Up/Down + Crank“- und „Crank-Volldrehung = Frame“-Tests auf B + D-Pad umgeschrieben; neue Abschnitte fuer Tile-Picker (inkl. verdeckte Kachel, Abwahl-Slot, Cache-Invalidierung) und Pipetten-Meldung; `referencedTileIndices()` mit `buildPauseMenuImage` geteilt. Details in [ADR-042](adr/ADR-042-Tile-View-Steuerungs-Redesign.md).

## 9.31 AD-043: Aufgeschobene Pixel-Verschiebung — Puffern statt Neubau je Tastendruck

- Status: umgesetzt (Spec 010 US1, Perf-Review nach Hardware-Test, 2026-09-01)
- Entscheidung: `EditorRoom.shiftActiveLayer(direction)` (B + Pfeiltaste in der Zoom View) baut die 375 Tiles der aktiven Ebene **nicht mehr pro Tastendruck** neu. Es dekodiert die Ebene **einmal je Verschiebe-Geste** (`pendingShift = {frame, layerRef, grid, offX, offY}`) und akkumuliert jeden weiteren Tastendruck derselben Sitzung nur als Wrap-Versatz — **O(1)**. Materialisiert (375 Tiles neu bauen + hashen + Frame neu kompositieren) wird ausschliesslich in `EditorRoom:flushLayerShift()`, aufgerufen an jeder Stelle, die kanonische Tiles wirklich braucht: `applyTileEdits` (Malen respektiert den Shift, nicht umgekehrt), `ZoomRoom.zoomIntoPixelRoom`/`commitAndReturnToEditor`/`commitForTerminate`, ein neuer `BButtonUp`-Handler (natuerlicher, aber nicht zwingender Sitzungsabschluss) sowie defensiv `EditorRoom:entered()` und `buildPauseMenuImage()`. `buildZoomContext()` synthetisiert die 3x3-Live-Vorschau waehrend einer offenen Sitzung direkt aus dem gepufferten Raster (`LayerModel.imageFromGrid`), damit die Anzeige trotz aufgeschobener Materialisierung bei jedem Tastendruck aktuell bleibt.
- Begruendung: Eine Standalone-Messung (375-Tile-Ebene, ein 1px-Schritt) ergab **~192.000 `image:sample()`-Aufrufe + 375 `image.new()`** — auf dem Playdate geschaetzt mehrere hundert ms je Tastendruck, spuerbar ruckelig beim Halten der Pfeiltaste (genau das im `spec.md`-Risk-Record „Tile recalculation on every pixel shift could cause lag“ vorhergesehene Risiko). Modulo-Arithmetik ist additiv (`((x % n) - b) % n == (x - b) % n`), also sind N sequentielle 1px-Verschiebungen um `(dx,dy)` exakt aequivalent zu einer Verschiebung um `(N·dx, N·dy)` — das Puffern aendert das beobachtbare Ergebnis am Gestenende nicht (Offset-Algebra, bewiesen durch einen Vergleichstest). Bleibt bewusst auf dem bestehenden Pure-Lua-Decode/Rebuild-Pfad statt auf `image:draw()`-Blits umzusteigen, da der Headless-Mock `draw()` als No-op fuehrt — eine Blit-Loesung waere ungetestet geblieben.
- Konsequenz: Halten der Pfeiltaste kostet (Decode + O(1)×N + 1 Flush) statt N×(Decode + Rebuild + Rehash). `pendingShift` ist ein zweiter, impliziter Session-Zustand — jeder neue EditorRoom-Pfad, der `imageData.frameLayers`/`frames`/`imagetable` liest, MUSS `flushLayerShift()` zuerst aufrufen oder die Semantik sonst explizit bedenken. `newMockImage` (Testharness) bekam eine `copy()`-Methode (SDK-Aequivalent), bislang von keinem Test beruehrt. Headless: vier neue Testabschnitte (Pufferung + Offset-Algebra, Malen-fluscht-zuerst, ZoomRoom-Flush-Aufrufstellen inkl. Terminate-ohne-B-Release, Reinzoomen-fluscht-zuerst) + Korrektur der bestehenden `shiftActiveLayer`-Assertion. 393 Assertions gruen, `pdc` sauber, buildNumber 29. Geraete-Messung der tatsaechlichen Framerate bleibt offen (Phase 7 T053/T054). Details in [ADR-043](adr/ADR-043-Aufgeschobene-Pixel-Verschiebung.md).
