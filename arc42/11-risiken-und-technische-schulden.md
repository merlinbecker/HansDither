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
| R-21 | Titelscreen-Lazy-Load-Ueberlappung bei schnellem Selektionswechsel (Spec 006, US6): mehrere aufeinanderfolgende RoomOperation-Ladevorgaenge fuer verschiedene Eintraege koennten sich theoretisch ueberschneiden | Falscher/veralteter Vollbild-Hintergrund koennte kurzzeitig sichtbar werden | Mitigiert: `SelectionRoom:setSelectedIndex()` verwirft einen laufenden Ladevorgang fuer den VERLASSENEN Eintrag durch reines Ueberschreiben der Referenz (nie wieder resumed, kein Seiteneffekt); headless-testverifiziert (T022 — Selektionswechsel vor Abschluss laedt nachweislich nur den neuen Eintrag) |
| R-22 | Crank-Dual-Path-Regression (Spec 006, US2): `getCrankChange()`-Akkumulator (Frame-Navigation) und `getCrankTicks(4)`-Zoomkette duerfen sich pro `update()` nicht gegenseitig den Kurbel-Zustand "wegkonsumieren" | Wuerden beide APIs im selben Frame gelesen, gingen Grad-/Tick-Anteile verloren — Frame-Navigation ODER Zoomkette koennten unzuverlaessig werden | Mitigiert: `handleCrank()` verzweigt exklusiv zwischen beiden Lesepfaden (Contract CR-01, nie beide im selben Aufruf); Regressionstest fuer die B+Crank-Zoomkette im selben Testlauf wie der neue Akkumulator (T005) |
| R-23 | Zoom-Room-Ursachenbefund unbestaetigt (Spec 008, AD-035): Code-Review stuft die Vollbild-Neuberechnung als wahrscheinliche Ursache sowohl des Ruckelns als auch der vermuteten "tieferliegenden" Navigationsblockade ein, ohne einen isolierten separaten Bug gefunden zu haben | Sollte nach dem Redraw-Cache-Fix weiterhin eine Blockade auftreten, waere die eigentliche Ursache noch offen | Akzeptiert (subjektiv bestaetigt): Hardware-Test (T005, quickstart.md Szenario 1) bestanden — Befund "keine Aussetzer mehr gemerkt"; der urspruenglich geplante objektive `playdate.getStats()`/Sampler-Vergleich wurde NICHT durchgefuehrt (Projektinhaber-Entscheidung, subjektiver Spieltest als ausreichend akzeptiert) |
| R-24 | Wegfall der Frame-Schutzfunktion (Spec 008, AD-037): "Reset Frame" wird ersatzlos durch "Clear Screen" ersetzt, ohne Schutz vor versehentlichem Bemalen eines Frames | Versehentlich bemalte Frames koennen nicht mehr auf den Vorgaengerstand zurueckgesetzt werden | Bewusst akzeptierte Projektinhaber-Entscheidung (spec.md Assumptions); keine Gegenmassnahme vorgesehen |
| R-25 | Fehler bei der Tile-Neuindizierung (Spec 009, AD-005): `pruneUnusedTiles()`-Remap koennte bei fehlerhafter Implementierung zu falschen oder fehlenden Tile-Inhalten nach dem Neuladen fuehren | Beruehrt direkt die Kernanforderung "verlustfreies Speichern" (Spec 001 FR-006) — hoechste Kritikalitaet dieser Spec | Mitigiert: dedizierte Headless-Tests inkl. Round-Trip-Verifikation ueber die echte `newSaveOperation()`-Coroutine und Regressionstest gegen das `ImageStore.createImage()`-Neubild-Muster (`tests/headless_tests.lua`, Sektion "Tile-Bereinigung beim Speichern") |

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
- Toter Code `resetCurrentFrameToPrevious()` (Spec 008, AD-037): vollstaendig entfernt statt — wie `deleteCurrentFrame()` seit AD-032 — als unbenutzte Funktion im Code zu verbleiben; FR-011 forderte explizit vollstaendige Entfernung (Constitution IV).
- AD-005-Status-Diskrepanz (Spec 009): "Tile-Kompaktierung vor Save" war seit dem v0.3.0-PDI-Formatwechsel (mind. seit Spec 001, 2026-07-03) mit dem irrefuehrenden Status "umgesetzt" dokumentiert, obwohl der Code seither nur einen wirkungslosen Platzhalter enthielt (`ImageStoreCodec.lua`-Kommentar "Phase 1: Dedup (T014 - wird spaeter in US2 implementiert...)"). Dies fiel bei keinem der dazwischenliegenden Governance-Reviews (Spec 004/005/006/007/008) auf. Mit Spec 009 korrigiert (AD-005-Status aktualisiert) und tatsaechlich umgesetzt. **Prozess-Lernpunkt:** kuenftige Architecture-Governance-Abschnitte sollten bei "Status: umgesetzt"-ADRs stichprobenartig gegen den aktuellen Code verifizieren, nicht nur bei neu hinzukommenden Entscheidungen.

Anmerkung: Die im Meeting offene Frage zur Zielaufloesung ist geklaert — die Playdate-Hardware ist 400x240, "420x240" war ein Versprecher (siehe AD-016).

## 11.4 Priorisierung

- Kurzfristig: R-05 (Validierungsszenarien v0.3.0 ausstehend), R-06, R-13 (Messung), T-07
- Mittelfristig: R-03, R-08, T-02
- Langfristig: T-03, T-01, T-06, R-14
- Mitigiert (Spec 006): R-21 (Titelscreen-Lazy-Load-Ueberlappung, verwirft alte Ladevorgaenge), R-22 (Crank-Dual-Path-Regression, exklusive API-Verzweigung) — beide headless-testverifiziert, keine offenen Massnahmen
- **Akzeptiert, subjektiv bestaetigt (Spec 008)**: R-23 (Zoom-Room-Ursachenbefund) — Implementierung (Redraw-Cache, AD-035), Headless-Tests UND Hardware-Test (T005, quickstart.md Szenario 1, Befund "keine Aussetzer mehr gemerkt") sind abgeschlossen und bestanden; der urspruenglich zusaetzlich vorgesehene objektive `playdate.getStats()`/Sampler-Vergleich wurde bewusst nicht durchgefuehrt (Projektinhaber-Entscheidung). — Akzeptiert (Spec 008): R-24 (Wegfall der Frame-Schutzfunktion, bewusste Projektinhaber-Entscheidung)
- **Mitigiert (Spec 009)**: R-25 (Tile-Neuindizierungs-Fehlerrisiko) — dedizierte Headless-Tests inkl. Coroutine-Integrations-Round-Trip bestanden (siehe `tests/headless_tests.lua`)

---

## 11.5 Backend-Risiken (Hans Dither Sync)

| ID | Risiko | Auswirkung | Gegenmassnahme | Status |
|---|---|---|---|---|
| R-14 | Brute-Force-Angriff auf 4-stellige PIN | 10.000 Kombinationen können theoretisch durchprobiert werden | Rate-Limiting (3 Versuche → 5 Min Sperre), HTTPS erzwingen, keine detaillierten Fehlermeldungen | **Umgesetzt** |
| R-15 | Speicherwachstum durch viele PDI-Dateien | all-inkl.com Hosting hat Speicherlimits | Max. Dateigröße 300 KB je Datei (Spec 007, vorher 10MB), Obergrenze von 12 Bildern pro Gerät (Spec 007, R-19), abgelaufene Sessions bereinigen | **Umgesetzt** |
| R-16 | all-inkl.com Performance-Limits | Shared Hosting kann bei vielen Requests langsam werden | Einfache Architektur (kein Framework), PNG on-demand (nicht sofort), Caching von PNGs | **Umgesetzt** |
| R-17 | GD-Bibliothek nicht verfügbar | PNG-Rendering funktioniert nicht | Prüfen bei Deployment, Fallback-Meldung in UI | **Offen** |
| R-18 | MySQL-Verbindungmäßig überlastet | Datenbank-Requests blockieren | Prepared Statements, Indexe auf Tabellen, Connection Pooling (Singleton) | **Umgesetzt** |
| R-19 | Multi-Geräte-/Sybil-Umgehung des Pro-Gerät-Limits: eine Person mit mehreren UIDs (z. B. mehreren Playdate-Geräten oder manuell erzeugten UIDs) kann das 12-Bilder-Limit pro UID beliebig oft umgehen | Das Limit begrenzt nur pro Gerät, nicht pro Person — kein echter Schutz gegen einen gezielt entschlossenen Angreifer | Bewusst akzeptiert und NICHT Teil des Scopes von Spec 007 (spec.md Assumptions); Re-Evaluierung falls künftig eine serverseitige Lösch-Funktion entsteht oder Missbrauch beobachtet wird | **Akzeptiert (Open)** |
| R-20 | Verlängerte Row-Lock-Dauer bei mehreren GLEICHZEITIGEN Uploads DERSELBEN UID: die neue Transaktion (Spec 007, ADR-033) hält den `users`-Datensatz der UID während `move_uploaded_file()` + DB-Schreibvorgang gesperrt | Kurze Wartezeiten bei parallelen Uploads derselben UID (untypischer Fall — ein Gerät lädt normalerweise sequenziell hoch) | Unkritisch bei erwarteter Nutzungsfrequenz (ein Playdate lädt je Crank-Geste sequenziell hoch); Beobachtungspunkt, keine Gegenmaßnahme nötig, solange kein Bottleneck beobachtet wird | **Akzeptiert (Beobachtung)** |
| R-26 | SDK-Namenskonvention-Drift (Spec 009, AD-038): weicht die Playdate-SDK-Namenskonvention für Matrix-Imagetables (`<name>-table-<w>-<h>`) in einer künftigen SDK-Version vom hier zugrunde gelegten Muster ab, wird der Tilemap-Export inkompatibel | Heruntergeladene Tilemap-PNGs ließen sich nicht mehr direkt in ein neues SDK-Projekt übernehmen | Kein aktueller Anlass zur Sorge (gegen die SDK-Dokumentation verifiziert, Spec 009 research.md R6); zu beobachten bei künftigen Playdate-SDK-Updates (Constitution Prinzip I) | **Akzeptiert (Beobachtung)** |

## 11.6 Backend-Technische Schulden

| ID | Schuldenpunkt | Hintergrund | Abbaupfad | Status |
|---|---|---|---|---|
| T-04 | Keine automatischen Unit-Tests | Fokus lag auf schneller Implementierung | PHPUnit-Tests für Kernfunktionen (Auth, Validation, Upload) | **Offen** |
| T-05 | Keine API-Versionierung | Erste Version, noch keine Rückwärtskompatibilität nötig | Version in URL/Pfad integrieren (z. B. /v1/upload) | **Offen** |
| T-06 | Session-Tokens werden nicht automatisch bereinigt | Abgelaufene Tokens bleiben in DB | Cron-Job oder Request-basierte Bereinigung | **Offen** |
| T-07 | Keine Request-Logging für Analytics | Keine Statistiken über Nutzung | Logging-Framework integrieren (z. B. Monolog) | **Offen** |

## 11.7 Priorisierung (Backend)

- **Umgesetzt:** R-14, R-15, R-16, R-18
- **Offen (kann später):** R-17, T-04, T-05, T-06, T-07
- **Akzeptiert:** 4-stellige PIN ist für den Anwendungsfall ausreichend (10.000 Kombinationen + Rate-Limiting); R-19 (Multi-Geräte-/Sybil-Umgehung, bewusst außerhalb des Scopes von Spec 007); R-20 (Row-Lock-Dauer bei paralleler Nutzung derselben UID, unkritisch bei erwarteter Nutzungsfrequenz); R-26 (SDK-Namenskonvention-Drift, Spec 009 — Beobachtungspunkt bei künftigen SDK-Updates)
