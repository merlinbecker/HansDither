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

## 11.3 Risiken aus dem v0.3.0-Planungsschnitt

| ID | Risiko | Auswirkung | Gegenmassnahme |
|---|---|---|---|
| R-12 | JSON-Positionsablage je Frame koennte bei 12 Frames x 375 Positionen zu gross/langsam werden | Lange Save-/Ladezeiten, Speicherverbrauch | Alternative Ablageformen in der Planungsphase von Spec 001 evaluieren (offene Konzeptfrage); Ergebnis als AD dokumentieren |
| R-13 | Unbegrenzte Bildanzahl + bis zu 12 Frames pro Bild | Wachsende PDI-/JSON-Groessen, laengere Ladezeiten im Auswahlscreen | Vorschaubilder separat persistieren, Bilder lazy laden, Fortschrittsanzeige beibehalten |
| R-14 | Verlust der Pulp-Interoperabilitaet durch Formatwechsel | Alte Saves und Importer-Tool sind mit v0.3.0 nicht nutzbar | Bewusst akzeptiert (Nicht-Ziel Migration); alte Dateien werden ignoriert, nicht geloescht; Importer-Anpassung als spaeteres Vorhaben |

Anmerkung: Die im Meeting offene Frage zur Zielaufloesung ist geklaert — die Playdate-Hardware ist 400x240, "420x240" war ein Versprecher (siehe AD-016). Mit Umsetzung von AD-016 entfallen R-11 und T-09; mit AD-018 entfaellt R-04; mit AD-017 entfallen R-02 und R-10.

## 11.4 Priorisierung

- Kurzfristig: R-01, R-05, R-08, R-09, R-11, R-12, T-05, T-07
- Mittelfristig: T-04, R-04, R-13, T-09
- Langfristig: T-03, T-01, T-06, R-10, R-14, T-08
