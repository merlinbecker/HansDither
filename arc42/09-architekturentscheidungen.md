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
- Konsequenz: Zusätzliche Mappinglogik zwischen Tileindex und Pixel-Detaileditor.

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

- Status: umgesetzt
- Entscheidung: TileRoom verwendet zwei Modi (TilePickerMode/AnimationMode). B kurz fungiert als Pipette, B lang (>=1.5s) toggelt den Modus, B+Crank startet den Zoom und bricht dabei einen pending Long-Press ab. Die Modusrueckmeldung wird ueber die wiederverwendbare Bauchbinde-Komponente angezeigt.
- Begruendung: Entkoppelt unmittelbare Tile-Auswahl von kuenftigen Animationsfunktionen, reduziert Eingabekonflikte und schafft ein einheitliches UI-Muster fuer Hinweise.
- Konsequenz: Zusaetzlicher Zustandsautomat fuer B-Short/Long-Press, Cancel-Pfad und Mode-State notwendig; die Prioritaet zwischen Pipette, Moduswechsel und Zoom muss explizit im Update-Pfad abgesichert werden.

## 9.15 AD-015: Native Runtime-Aufloesung bei beibehaltener Pulp-Datenaufloesung

- Status: umgesetzt
- Entscheidung: Die Runtime arbeitet auf nativer Display-Aufloesung 400x240 (`setScale(1)`), waehrend Tile-/Frame-Daten und Room-Previews weiterhin im Pulp-Arbeitsraum (8x8 Tiles, 200x120) verbleiben.
- Begruendung: Allgemeine UI und Schrift sollen schaerfer dargestellt werden, ohne die Persistenz- und Importkompatibilitaet des Pulp-Datenmodells aufzugeben.
- Konsequenz: TileRoom benoetigt einen Offscreen-Buffer fuer skalierte Tilemap-Darstellung; ZoomRoom und PixelRoom arbeiten mit vergroesserten Zellgroessen; Dokumentation und Tests muessen zwei koordinative Ebenen auseinanderhalten.
