# 11. Risiken und technische Schulden

## 11.1 Risiken

| ID | Risiko | Auswirkung | Gegenmassnahme |
|---|---|---|---|
| R-01 | Fehler im Tile-Remapping bei Kompaktierung | Falsche Darstellung oder Datenverlust in Rooms | Zusatztets fuer Mappingfaelle, Validierung nach Save/Reload |
| R-02 | Inkompatible Aenderungen im Pulp-Format | Externe Nutzung eingeschraenkt | Defensive Defaults und Merge-Strategie beibehalten |
| R-03 | Hardwareperformance bei wachsendem Umfang | Eingabeverzoegerung | Redraw-Pfade eng halten, Datenstrukturen simpel halten |
| R-04 | Begrenzte UI-Kapazitaet (MAX_GAMES/MAX_ROOMS) | Funktionale Skalierungsgrenze fuer Nutzer | Konfigurierbare Limits und Paging als spaetere Erweiterung |
| R-05 | Fehlendes automatisiertes Test-Setup | Regressionen bleiben spaet sichtbar | Reproduzierbare manuelle Testmatrix und spaeter Skripttests |
| R-06 | Mappingfehler im ZoomRoom-Slot-Commit | Tile-Aenderungen landen an falscher Position | Slot-/Koordinatenmapping zentral halten und mit Randfaellen testen |
| R-07 | Zustandsdrift showGrid vs. showGridLines | Inkonsistente Rasterdarstellung zwischen TileRoom und ZoomRoom | showGrid beim Room-Laden rekonstruieren und beim Zoom-Kontext immer uebergeben |
| R-08 | Restblockierung bei finalem Datastore read/write | Kurzzeitige Hiccups trotz inkrementeller Vorbereitung | Finale Phase sichtbar markieren, Datenmengen beobachten, ggf. spaeter alternatives Persistenzformat evaluieren |
| R-09 | Importer-Schemaabweichungen bei Fremd-JSON | Import erzeugt unvollstaendige/ungueltige Struktur | Strikte JSON-Validierung, klare Fehlermeldungen, defensive Defaults |
| R-10 | Hash-Paritaet zwischen Lua- und JS-Pfad driftet | Unterschiedliches Dedupe-Verhalten im Editor vs. Importer | Hash-/Dedupe-Regeln dokumentieren und mit Referenzfaellen querpruefen |
| R-11 | Drift zwischen nativer Anzeigeebene und Pulp-Datenraum | Falsche Cursor-/Tile-Zuordnung oder inkonsistente Previewdarstellung | Render- und Persistenzpfade getrennt halten, Koordinatenwechsel explizit dokumentieren und manuell querpruefen |

## 11.2 Technische Schulden

| ID | Schuldenpunkt | Hintergrund | Abbaupfad |
|---|---|---|---|
| T-01 | Teilweise globale/lokale State-Variablenmischung | Historisch gewachsene Room-Implementierung | State-Objekte pro Room strukturieren |
| T-02 | Begrenzte Fehlerbehandlung bei Dateiproblemen | Fokus lag auf Kernflow statt Robustheit | Einheitliche Fehlerstrategie + UI-Hinweise |
| T-03 | Keine Undo/Redo-Funktion | Featureumfang bewusst reduziert | Undo-Stack pro Room/PixelSession einfuehren |
| T-04 | Grid-Logik nur teilweise vereinheitlicht | LoadRoom ist bereits in LoadRoomGrid extrahiert, GameRoom folgt anderem Pfad | Optionale weitere Harmonisierung fuer Navigationsrooms evaluieren |
| T-05 | Keine automatischen Kompatibilitaetstests | Formatkomplexitaet stieg mit PulpGameIO | Golden-File-Tests fuer Save-Dokumente |
| T-06 | Pixelvergleich im ZoomRoom ist linear pro Commit | Einfache Implementierung fuer robuste Aenderungserkennung | Spaeter optional Hash-Caching pro Slot einfuehren |
| T-07 | Statische Analyzer-Warnungen bei Playdate-APIs | Typ-/Nilability-Modell kennt Runtime-Objekte nur begrenzt | Gezielte lokale Guards/Annotationen oder Analyzer-Profile fuer SDK definieren |
| T-08 | Importer hat nur manuelle Regressionstests | Browser-Tool entwickelt sich getrennt vom Runtime-Code | Kleine Testfaellsammlung mit bekannten JSON/PNG-Paaren versionieren |
| T-09 | Duales Koordinatenmodell nur implizit im Code verteilt | Anzeige-Scaling steckt in Konstanten, Buffer-Rendering und Room-spezifischen Geometrien | Mittelfristig zentrale Render-/Geometry-Konstanten oder DisplayConfig einfuehren |

## 11.3 Priorisierung

- Kurzfristig: R-01, R-05, R-08, R-09, R-11, T-05, T-07
- Mittelfristig: T-04, R-04, T-09
- Langfristig: T-03, T-01, T-06, R-10, T-08
