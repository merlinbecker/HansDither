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

- Status: umgesetzt
- Entscheidung: Ungenutzte Tiles werden entfernt, Referenzen remapped, Basistiles immer behalten.
- Begruendung: Spart Speicher, verhindert schleichende Datenaufblaehung.
- Konsequenz: Remap-Fehler sind ein Risiko und muessen abgesichert werden.

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

- Status: umgesetzt (v0.3.0), ersetzt den Tile-Picker (AD-002-Teilverhalten) und den EditMode-Automaten aus AD-014
- Entscheidung: Crank ohne Modifier wechselt Frames (vorwaerts: naechster Frame als Kopie des aktuellen, rueckwaerts: zurueck; harte Grenze 12 Frames, danach Rotation). B waehlt das Tile an der Cursor-Position (Pipette), A zeichnet bzw. toggelt Schwarz/Weiss. B+Crank zoomt durch genau drei Stufen; der globale Tile-Picker und der B-Long-Press-Moduswechsel entfallen.
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
