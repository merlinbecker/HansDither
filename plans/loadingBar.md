# loadingBar Plan fuer non-blocking Save/Load

Stand: 2026-04-23

## 1. Ziel

JSON-Lastige Lade- und Speichervorgaenge sollen fuer den Spieler sichtbar gemacht und so weit wie moeglich ueber mehrere Frames verteilt werden.

Es soll eine separate Komponente `loadingBar` geben, die in jedem Room eingeblendet werden kann, in dem JSON-Load oder JSON-Save stattfindet.

Darstellung:
- zentriertes Rechteck als Overlay
- Progress-Bar innerhalb des Rechtecks
- Status-Text unterhalb der Bar, z. B. `Tile 4 von 200`
- optionaler Phasen-Titel, z. B. `Speichere Spiel...`

## 2. Relevanter Ist-Zustand

Die teuren Operationen laufen heute synchron in einem einzigen Frame:

1. Laden eines Games
- `GameRoom` ruft beim Oeffnen direkt `LoadRoom:setGame(name, isNew)` auf.
- `LoadRoom:setGame()` macht fuer bestehende Games sofort `playdate.datastore.read("saves/" .. gameName)`.
- Direkt danach wird `PulpGameIO.prepareLoadedGame()` synchron ausgefuehrt.

2. Speichern eines Games
- `TileRoom:saveToFile()` fuehrt in einem Rutsch aus:
  - `syncCurrentRoomToGameData()`
  - `compactTileState()`
  - Neuaufbau von `tiles` und `frames`
  - `PulpGameIO.buildSaveDocument(...)`
  - `playdate.datastore.write(...)`
  - mehrere `playdate.datastore.writeImage(...)`

3. Weitere Save-Trigger
- `LoadRoom` speichert beim Erzeugen eines neuen Rooms aktuell sofort ueber `nextRoom:saveToFile()`.
- `main.lua` speichert beim Beenden synchron ueber `TileRoom:saveToFile()`.

## 3. Technische Randbedingung

Die Playdate-SDK-Doku erlaubt `coroutine.yield()` innerhalb von `playdate.update()`. Das ist die richtige Grundlage fuer frame-freundliche Arbeit.

Wichtig ist aber:
- `json.encode`, `json.decode`
- `playdate.datastore.read`
- `playdate.datastore.write`

sind jeweils einzelne blockierende Operationen.

Das bedeutet:
- Die Vor- und Nachbereitung kann sauber auf mehrere Frames verteilt werden.
- Die eigentliche finale JSON-Serialisierung bzw. -Deserialisierung bleibt in der ersten Ausbaustufe eine kurze, sichtbare Block-Phase.
- Ein wirklich vollstaendig non-blocking Save/Load ueber den gesamten JSON-Pfad waere nur mit einem eigenen inkrementellen Dateiformat oder einem stark anderen Persistenzmodell moeglich.

Planungsentscheidung:
- Phase 1 implementiert einen frame-freundlichen Ablauf mit sichtbarem Overlay und maximaler Aufteilung aller Lua-seitigen Schleifen.
- Die unvermeidbare finale `datastore`-Phase wird als eigener Schritt sichtbar markiert.
- Erst wenn das in der Praxis nicht reicht, lohnt sich eine zweite Architektur fuer ein alternatives Save-Format.

## 4. Zielbild der Architektur

Es gibt zwei getrennte Verantwortungen:

1. `loadingBar` als reine UI-Komponente in separater Datei
- Datei: `Source/loadingBar.lua`
- Verantwortlich fuer Zustand, Text, Progress und Zeichnen
- keine JSON- oder Datastore-Logik in dieser Datei

2. Ein asynchroner Room-lokaler Operationsablauf
- jeder Room, der Save/Load startet, bekommt genau eine `activeOperation`
- diese Operation wird in `update()` pro Frame weitergefuehrt
- waehrenddessen werden normale Eingaben blockiert oder ignoriert
- das Room-Rendering bleibt sichtbar, die `loadingBar` liegt als Overlay darueber

Warum kein globaler Manager als erster Schritt:
- Die Kontrollfluesse sind aktuell stark room-zentriert.
- Die kleinste sichere Aenderung ist, Save/Load dort zu orchestrieren, wo sie heute bereits gestartet werden.
- Ein globaler Scheduler kann spaeter folgen, wenn mehrere Operationstypen dazukommen.

## 5. Geplante API der loadingBar-Komponente

Datei: `Source/loadingBar.lua`

Geplante Verantwortungen:
- sichtbaren/inaktiven Zustand halten
- Titel und Detailtext verwalten
- Fortschritt als `current`, `total` oder als `fraction` verwalten
- Overlay zeichnen
- optional Fehlertext anzeigen

Vorgeschlagene API:

```lua
loadingBar = {}

function loadingBar.new()
    -- returns instance
end

function instance:show(title, detailText)
end

function instance:updateProgress(current, total, detailText)
end

function instance:updateFraction(fraction, detailText)
end

function instance:setTitle(title)
end

function instance:setDetail(detailText)
end

function instance:finish()
end

function instance:fail(detailText)
end

function instance:isVisible()
end

function instance:draw()
end
```

UI-Details:
- feste Overlay-Groesse, damit das Layout in jedem Room gleich ist
- Progress-Breite geklemmt auf `0..1`
- Text defensiv kuerzen, damit er nicht aus dem Overlay laeuft
- Darstellung nur in Schwarz/Weiss, passend zum Rest des Projekts

## 6. Geplantes Async-Muster pro Room

Jeder betroffene Room bekommt denselben Ablauf:

1. Operation anstossen
- Room legt `activeOperation` an
- `activeOperation` enthaelt:
  - `co` fuer die Coroutine
  - `overlay` fuer die `loadingBar`
  - `onComplete`
  - `onError`
  - optional `result`

2. Operation pro Frame weitertreiben
- in `update()` wird zuerst geprueft, ob `activeOperation` laeuft
- wenn ja, wird die Coroutine einmal resumed
- jede Phase liefert Fortschrittsdaten an die `loadingBar`
- danach wird der normale Room gezeichnet und zum Schluss `loadingBar:draw()` aufgerufen

3. Input sperren
- waehrend `activeOperation` aktiv ist, sollen A/B, Cursor und Crank keine neuen Aktionen starten
- bestaetigte Keyboard-Aktionen muessen vor Start der Operation abgeschlossen sein

4. Abschluss
- bei Erfolg werden Resultate uebernommen und der Room wechselt erst danach weiter
- bei Fehlern bleibt der Benutzer im aktuellen Room und erhaelt eine lesbare Meldung

## 7. Load-Ablauf neu planen

### 7.1 GameRoom entkoppeln

Aktuell wird das Game geladen, bevor zu `LoadRoom` gewechselt wird. Dadurch gibt es kein sichtbares UI fuer den Ladezustand.

Geplante Aenderung:
- `GameRoom` uebergibt nur noch `gameName` und `isNew`
- `GameRoom` wechselt sofort in `LoadRoom`
- `LoadRoom` startet den Ladevorgang erst in `entered()` oder in einem expliziten `startLoadOperation()`

Vorteil:
- Das Overlay ist im richtigen Room sichtbar.
- Der Benutzer sieht direkt, dass geladen wird.

### 7.2 Phasen fuer bestehende Games

Vorgeschlagene Schritte in `LoadRoom`:

1. Overlay initialisieren
- Titel: `Lade Spiel...`
- Detail: `Speicherdaten lesen`

2. Ein Frame freigeben
- sofort `coroutine.yield()` nach dem Einblenden, damit das Overlay sicher sichtbar ist

3. Save-Datei lesen
- `playdate.datastore.read("saves/" .. gameName)`
- Detailtext: `Speicherstand lesen`

4. Dokument vorbereiten
- `PulpGameIO.prepareLoadedGame(...)`
- diese Funktion muss intern in kleinere Schritte aufgeteilt werden, damit zwischen Tile-/Frame-/Room-Schleifen yielded werden kann

5. Room-Namen und Previews nachziehen
- `refreshRoomNames()`
- `loadRoomPreviews()` optional ebenfalls in kleine Schritte teilen, da mehrere `readImage`-Aufrufe anfallen koennen

6. Operation abschliessen
- Grid aktualisieren
- Menue aktualisieren
- Overlay entfernen

### 7.3 Neue Games

Bei `isNew == true` ist kein JSON-Load noetig.

Plan:
- kein Overlay fuer den reinen Wechsel in `LoadRoom`
- erst beim ersten echten Save oder beim Erzeugen eines Rooms ggf. Overlay anzeigen

## 8. Save-Ablauf neu planen

### 8.1 TileRoom als primaerer Save-Ort

`TileRoom:saveToFile()` wird in zwei Ebenen zerlegt:

1. `saveToFile()` wird zum Trigger
- startet nur noch `startSaveOperation(options)`
- macht selbst keine schwere Arbeit mehr direkt

2. `startSaveOperation()` baut eine Coroutine
- diese Coroutine arbeitet die Save-Phasen nacheinander ab
- zwischen groesseren Schleifen wird yielded

### 8.2 Geplante Save-Phasen

1. Overlay sichtbar machen
- Titel: `Speichere Spiel...`
- Detail: `Vorbereitung`

2. Einen Frame freigeben
- direkt yielden, damit die UI sicher gezeichnet wird

3. Room-State synchronisieren
- `syncCurrentRoomToGameData()`

4. Tiles komprimieren
- `compactTileState()` in schrittweise Verarbeitung aufteilen
- Fortschritt z. B. pro Tile oder pro Zeile aktualisieren
- Detailtext: `Tile X von Y pruefen`

5. `tiles` und `frames` aufbauen
- Schleife ueber die komprimierte `imagetable`
- Detailtext: `Tile X von Y serialisieren`

6. Pulp-Dokument erzeugen
- `PulpGameIO.buildSaveDocument(...)` in unterbrechbare Teilschritte aufteilen
- Detailtexte nach Phase:
  - `Dokument vorbereiten`
  - `Tiles uebernehmen`
  - `Frames uebernehmen`
  - `Rooms uebernehmen`

7. JSON final speichern
- Detailtext: `JSON schreiben`
- `playdate.datastore.write(outputDocument, "saves/" .. name)`
- das bleibt voraussichtlich die kuerzeste unvermeidbare Block-Phase

8. Preview-Bilder speichern
- aktueller Room-Preview
- Gesamt-Preview
- Detailtext: `Vorschaubilder schreiben`

9. Abschluss
- `needsRedraw = true`
- optional Callback fuer `Save + Back`

### 8.3 Save aus LoadRoom beim Room-Anlegen

Der aktuelle Ablauf speichert beim Erzeugen eines neuen Rooms noch in `LoadRoom`.

Planungsentscheidung:
- diese direkte Speicherung sollte aus `LoadRoom` verschwinden
- `LoadRoom` soll nur den in-memory Zustand vorbereiten und dann in `TileRoom` wechseln
- der eigentliche Save passiert spaeter explizit in `TileRoom` oder ueber einen gezielten Autosave-Trigger mit Overlay

Begruendung:
- Room-Erzeugen ist fachlich noch keine Persistenz-Pflicht
- der aktuelle Save direkt vor dem Room-Wechsel kostet unnötig Zeit an einer UX-empfindlichen Stelle
- weniger unerwartete IO auf dem Weg in den Editor

## 9. PulpGameIO fuer Schrittbetrieb vorbereiten

Der groesste Umbau liegt nicht in der UI, sondern in den monolithischen Schleifen.

Geplante Richtung:
- bestehende Logik fachlich beibehalten
- aber grosse Funktionen in kleinere, resume-faehige Schritte zerlegen

Empfohlene Strategie:

1. keine komplette Neuschreibung
- vorhandene Hilfsfunktionen weiterverwenden
- ID-Mapping und Normalisierung unveraendert lassen

2. neue schrittweise Varianten einfuehren
- z. B. `PulpGameIO.buildSaveDocumentAsync(...)`
- oder Hilfsfunktionen, die Zustandsobjekte Schritt fuer Schritt abarbeiten

3. Yield-Grenzen an natuerlichen Schleifen setzen
- Tiles
- Frames
- Rooms
- Preview-Liste

4. Rueckgabestruktur standardisieren
- jede Phase liefert:
  - `title`
  - `detail`
  - `current`
  - `total`

Wichtig:
- Das Ziel ist nicht Parallelitaet, sondern kontrollierte Unterbrechbarkeit pro Frame.

## 10. Betroffene Dateien im ersten Implementierungsschnitt

Sicher betroffen:
- `Source/main.lua`
- `Source/GameRoom.lua`
- `Source/LoadRoom.lua`
- `Source/TileRoom.lua`
- `Source/PulpGameIO.lua`
- `Source/loadingBar.lua` neu

Optional spaeter:
- ein zusaetzliches Helper-Modul fuer Operationen, falls sich die Coroutine-Steuerung in mehreren Rooms dupliziert

## 11. Risiken und Gegenmassnahmen

### Risiko 1: UI bleibt trotz Overlay kurz haengen
Ursache:
- `datastore.read/write` oder `json.encode/decode` blockieren am Ende trotzdem kurz.

Gegenmassnahme:
- alle vorbereitenden Schleifen konsequent aufsplitten
- Finalisierungsphase im Overlay explizit benennen
- Dauer spaeter messen, bevor ein groesserer Persistenz-Umbau gestartet wird

### Risiko 2: Save-Logik aendert unabsichtlich Daten
Ursache:
- Umbau von `PulpGameIO.buildSaveDocument()` in schrittweise Verarbeitung.

Gegenmassnahme:
- zuerst die bestehende Logik in kleinere, testbare Einheiten extrahieren
- Datenstruktur und Mapping-Regeln unveraendert lassen
- Roundtrip-Faelle mit bestehenden Saves pruefen

### Risiko 3: Room-Wechsel mitten in aktiver Operation
Ursache:
- Input oder Menue erlaubt neue Aktionen waehrend Save/Load.

Gegenmassnahme:
- waehrend `activeOperation` keine weiteren Navigationen erlauben
- Menue-Aktionen defensiv blockieren

### Risiko 4: Terminate-Save kann nicht wirklich asynchron sein
Ursache:
- `playdate.gameWillTerminate()` ist kein guter Ort fuer mehrstufige UI-Arbeit.

Gegenmassnahme:
- Terminate-Save vorerst synchron als Fallback behalten
- eigentliche Strategie auf explizite Saves und `Save + Back` konzentrieren

## 12. Implementierungsreihenfolge

1. `loadingBar` als isolierte UI-Komponente bauen
2. Room-lokales `activeOperation`-Muster in `LoadRoom` einziehen
3. Load-Pfad aus `GameRoom` nach `LoadRoom` verlagern
4. `LoadRoom`-Ladevorgang sichtbar und frame-freundlich machen
5. `TileRoom`-Save auf Coroutine-Trigger umbauen
6. `compactTileState()` in schrittweise Arbeit zerlegen
7. `PulpGameIO.buildSaveDocument()` in resume-faehige Phasen aufteilen
8. Preview-Schreiben nach hinten schieben und sichtbar machen
9. direkten Save beim neuen Room aus `LoadRoom` entfernen oder gezielt verschieben
10. Fallback- und Fehlerpfade stabilisieren

## 13. Detaillierte Todo-Liste fuer die Umsetzung

### Phase A - loadingBar Komponente
- [ ] `Source/loadingBar.lua` anlegen
- [ ] Konstruktor und internen Zustand definieren (`visible`, `title`, `detail`, `progress`)
- [ ] `show`, `updateProgress`, `updateFraction`, `finish`, `fail`, `draw` implementieren
- [ ] zentriertes Overlay in 200x120 Layout entwerfen
- [ ] Textkuerzung und Progress-Clamping robust machen

### Phase B - Gemeinsames Operationsmuster
- [ ] in `LoadRoom` Struktur fuer `activeOperation` einfuehren
- [ ] in `TileRoom` Struktur fuer `activeOperation` einfuehren
- [ ] kleinen Helper fuer `resumeOperation()` in beiden Rooms oder gemeinsam extrahieren
- [ ] Eingaben waehrend laufender Operation blockieren
- [ ] Overlay immer nach dem normalen Room-Inhalt zeichnen

### Phase C - Load-Pfad verlagern
- [ ] `GameRoom` so aendern, dass es keine schweren Loads mehr direkt ausfuehrt
- [ ] `LoadRoom:setGame()` auf reine Kontextuebergabe reduzieren
- [ ] `LoadRoom:entered()` oder `startLoadOperation()` als neuen Startpunkt festlegen
- [ ] ersten Yield direkt nach dem Einblenden des Overlays einbauen

### Phase D - Load schrittweise machen
- [ ] Lesen der Save-Datei als eigene Ladephase markieren
- [ ] `PulpGameIO.prepareLoadedGame()` analysieren und in Teilphasen schneiden
- [ ] Tile-, Frame- und Room-Schleifen mit Yield-Punkten versehen
- [ ] `refreshRoomNames()` und `loadRoomPreviews()` bei Bedarf ebenfalls stueckeln
- [ ] Erfolgs- und Fehlerabschluss sauber in `LoadRoom` rueckfuehren

### Phase E - Save-Trigger umbauen
- [ ] `TileRoom:saveToFile()` in leichten Trigger verwandeln
- [ ] `startSaveOperation(options)` einfuehren
- [ ] Callback-Szenarien fuer `Save + Back` und spaetere Autosaves definieren
- [ ] Menue-Handler auf den neuen asynchronen Ablauf umstellen

### Phase F - Save-Vorbereitung zerstueckeln
- [ ] `syncCurrentRoomToGameData()` als eigene Phase kennzeichnen
- [ ] `compactTileState()` in inkrementelle Arbeit umbauen
- [ ] Aufbau von `v2Tiles` und `v2Frames` mit Fortschrittsupdates versehen
- [ ] `loadRoomIntoTilemap(currentRoomIndex)` im Save-Pfad weiterhin konsistent halten

### Phase G - PulpGameIO schrittfaehig machen
- [ ] `buildBaseDocument()` und die nachfolgenden Schleifen logisch separieren
- [ ] Tile-Ausgabe in eine resume-faehige Phase auslagern
- [ ] Frame-Ausgabe in eine resume-faehige Phase auslagern
- [ ] Room-Ausgabe in eine resume-faehige Phase auslagern
- [ ] Fortschrittsdaten standardisieren, damit Rooms sie direkt an `loadingBar` geben koennen

### Phase H - Finale Persistenz und Previews
- [ ] `playdate.datastore.write(...)` als explizite Finalisierungsphase anzeigen
- [ ] `writeImage(...)` fuer Room-Preview als eigene Phase anzeigen
- [ ] `writeImage(...)` fuer Game-Preview als eigene Phase anzeigen
- [ ] Fehlerbehandlung fuer fehlgeschlagene Writes vereinheitlichen

### Phase I - Aufraeumen des Room-Anlegen-Flows
- [ ] direkten Save in `LoadRoom.openTileRoom(..., isNew)` entfernen
- [ ] pruefen, ob neuer Room nur in-memory angelegt werden kann
- [ ] falls Persistenz sofort noetig bleibt, expliziten Async-Save mit Overlay in `LoadRoom` einfuehren

### Phase J - Validierung
- [ ] bestehendes Game mit vielen Tiles laden und Sichtbarkeit des Overlays pruefen
- [ ] grosses Game speichern und Phasen-/Textwechsel pruefen
- [ ] `Save + Back` waehrend langer Saves pruefen
- [ ] Rueckkehr von `TileRoom` nach `LoadRoom` mit aktualisierten Daten pruefen
- [ ] neue Room-Erstellung ohne wahrnehmbaren Hiccup pruefen
- [ ] `gameWillTerminate()` bewusst als synchronen Fallback dokumentieren

## 14. Konkrete erste Implementierungshypothese

Die kleinste wirksame Aenderung ist:
- Load aus `GameRoom` nach `LoadRoom` verlegen
- Save in `TileRoom` ueber eine Coroutine abwickeln
- `loadingBar` als Overlay in beiden Rooms zeichnen

Wenn danach die Hiccups fast nur noch in `datastore.read/write` liegen, ist das kein Fehlschlag, sondern die erwartete technische Grenze von Phase 1.