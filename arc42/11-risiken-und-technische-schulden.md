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

## 11.2 Technische Schulden

| ID | Schuldenpunkt | Hintergrund | Abbaupfad |
|---|---|---|---|
| T-01 | Teilweise globale/lokale State-Variablenmischung | Historisch gewachsene Room-Implementierung | State-Objekte pro Room strukturieren |
| T-02 | Begrenzte Fehlerbehandlung bei Dateiproblemen | Fokus lag auf Kernflow statt Robustheit | Einheitliche Fehlerstrategie + UI-Hinweise |
| T-03 | Keine Undo/Redo-Funktion | Featureumfang bewusst reduziert | Undo-Stack pro Room/PixelSession einfuehren |
| T-04 | Teilweise doppelte Logik in Grid-Raumen | Schnelle Iterationen in GameRoom/LoadRoom | Gemeinsame Grid-Komponente extrahieren |
| T-05 | Keine automatischen Kompatibilitaetstests | Formatkomplexitaet stieg mit PulpGameIO | Golden-File-Tests fuer Save-Dokumente |
| T-06 | Pixelvergleich im ZoomRoom ist linear pro Commit | Einfache Implementierung fuer robuste Aenderungserkennung | Spaeter optional Hash-Caching pro Slot einfuehren |

## 11.3 Priorisierung

- Kurzfristig: R-01, R-05, R-06, R-07, T-05
- Mittelfristig: T-04, R-04
- Langfristig: T-03, T-01, T-06
