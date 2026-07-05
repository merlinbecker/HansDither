# 11. Risiken und technische Schulden

## 11.1 Risiken

| ID | Risiko | Auswirkung | Gegenmassnahme |
|---|---|---|---|
| R-03 | Hardwareperformance bei wachsendem Umfang | Eingabeverzoegerung | Redraw-Pfade eng halten, Datenstrukturen simpel halten; Frame-Wechsel ohne Bildkopien |
| R-05 | Fehlendes automatisiertes Test-Setup | Regressionen bleiben spaet sichtbar | Reproduzierbare manuelle Testmatrix (quickstart-Szenarien je Spec) und spaeter Skripttests |
| R-06 | Mappingfehler im Zoom-Slot-Commit | Tile-Aenderungen landen an falscher Frame-Position | Slot-/frameIndexPos-Mapping zentral halten und mit Randfaellen (out-of-bounds-Ecken) testen |
| R-07 | Zustandsdrift showGrid vs. showGridLines | Inkonsistente Rasterdarstellung zwischen EditorRoom und ZoomRoom | showGrid immer im Zoomkontext uebergeben (QS-07) |
| R-08 | Restblockierung bei finalem Datastore read/write | Kurzzeitige Hiccups trotz inkrementeller Vorbereitung | Finale Phase sichtbar markieren, Datenmengen beobachten |
| R-13 | Unbegrenzte Bildanzahl + bis zu 12 Frames pro Bild; Imagetable waechst beim Malen ohne Kompaktierung | Wachsende PDI-/JSON-Groessen, laengere Ladezeiten im Auswahlscreen | Vorschaubilder separat persistieren, Bilder lazy laden, Fortschrittsanzeige beibehalten; Imagetable-Wachstum bei intensivem Detail-Malen messen (quickstart Szenario 5), ggf. spaetere Kompaktierung |
| R-14 | Verlust der Pulp-Interoperabilitaet durch Formatwechsel | Alte Saves und Importer-Tool sind mit v0.3.0 nicht nutzbar | Bewusst akzeptiert (Nicht-Ziel Migration); alte Dateien werden ignoriert, nicht geloescht; Importer-Anpassung als spaeteres Vorhaben |

## 11.2 Technische Schulden

| ID | Schuldenpunkt | Hintergrund | Abbaupfad |
|---|---|---|---|
| T-01 | Teilweise globale/lokale State-Variablenmischung | Historisch gewachsene Room-Implementierung | State-Objekte pro Room strukturieren |
| T-02 | Begrenzte Fehlerbehandlung bei Dateiproblemen | Fokus lag auf Kernflow statt Robustheit | Einheitliche Fehlerstrategie + UI-Hinweise |
| T-03 | Keine Undo/Redo-Funktion | Featureumfang bewusst reduziert | Undo-Stack pro Frame/PixelSession einfuehren |
| T-06 | Pixelvergleich im Zoom-Commit ist linear pro Commit | Einfache Implementierung fuer robuste Aenderungserkennung | Spaeter optional Hash-Caching pro Slot einfuehren |
| T-07 | Statische Analyzer-Warnungen bei Playdate-APIs | Typ-/Nilability-Modell kennt Runtime-Objekte nur begrenzt | Gezielte lokale Guards/Annotationen oder Analyzer-Profile fuer SDK definieren |

## 11.3 Erledigte Punkte (v0.3.0-Umsetzungsschnitt)

- R-11 (Drift zwischen Anzeigeebene und Pulp-Datenraum) und T-09 (duales Koordinatenmodell): erledigt mit AD-016 — es gibt nur noch eine Koordinatenebene (400x240, 16x16-Tiles).
- R-02 (Pulp-Formataenderungen) und R-10 (Hash-Paritaet Lua/JS): entfallen mit AD-017 — das Pulp-Format wird nicht mehr geschrieben; der Importer ist als historisch markiert (siehe R-14).
- R-04 (MAX_GAMES/MAX_ROOMS-Grenzen): entfallen mit AD-018 — flache Bilder ohne feste Anzahlgrenzen.
- R-01 (Tile-Remapping bei Kompaktierung), T-04 (Grid-Harmonisierung GameRoom/LoadRoom), T-05 (Kompatibilitaetstests fuer Pulp-Dokumente), T-08 (Importer-Regressionstests): gegenstandslos, da Kompaktierung, LoadRoom/GameRoom und der Pulp-Speicherpfad entfernt wurden; der Importer ist eingefroren.
- T-10 (unverdrahtetes GameRoom.lua): erledigt — Datei im v0.3.0-Umsetzungsschnitt entfernt (Konvergenz-Task T039).
- R-12 (JSON-Positionsablage zu gross/langsam): geklaert in Spec 001 — frames.json mit 375 Indizes je Frame ist umgesetzt; Groessen-/Ladezeitbeobachtung laeuft unter R-13 weiter.

Anmerkung: Die im Meeting offene Frage zur Zielaufloesung ist geklaert — die Playdate-Hardware ist 400x240, "420x240" war ein Versprecher (siehe AD-016).

## 11.4 Priorisierung

- Kurzfristig: R-05 (Validierungsszenarien v0.3.0 ausstehend), R-06, R-13 (Messung), T-07
- Mittelfristig: R-03, R-08, T-02
- Langfristig: T-03, T-01, T-06, R-14
