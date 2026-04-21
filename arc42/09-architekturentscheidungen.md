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
