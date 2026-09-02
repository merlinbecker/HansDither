# Research: Schüttel-Undo für die letzten 3 riskanten Aktionen

**Feature**: `specs/011-shake-to-undo` | **Date**: 2026-09-02

Auflösung der offenen Punkte aus `spec.md` (Sektion *Audit Evidence Applicability → Open*) und der Technologiewahl. Format je Punkt: **Decision / Rationale / Alternatives considered**.

---

## R1 — Schüttel-Erkennung: welche SDK-Primitive?

**Decision**: `playdate.startAccelerometer()` beim Betreten der Editier-Räume, `playdate.readAccelerometer()` einmal pro `update()` (30 Hz), `playdate.stopAccelerometer()` beim Rücksprung zu `SelectionRoom`/`TitleRoom`. Die Links-Rechts-Erkennung ist Eigenlogik in `ShakeDetector.lua`.

**Rationale**: Das Playdate SDK hat **kein** Shake-/Gesten-Ereignis (Prüfung: keine CoreLibs-Datei dafür; `playdate.readAccelerometer` liefert nur rohe `(x, y, z)` in g). Damit ist Eigenlogik unumgänglich — begründete SDK-Abweichung nach Constitution I, festgehalten in **ADR-044** und arc42 Kap. 4/9. Der Sensor ist im Projekt bisher ungenutzt (`grep` über `Source/` → 0 Treffer) ⇒ **neue Plattformfähigkeit** (Spec 010 ging noch von „keine neuen Plattformfähigkeiten" aus; das gilt nicht mehr — arc42 Kap. 2).

**Alternatives considered**:
- *Menüeintrag „undo" im Systemmenü*: die 3 Menü-Slots sind belegt (save + exit / clear screen / show grid; `EditorRoom.buildSystemMenu`, „genau 3 Slots" laut research Spec 006). Verworfen — und der Nutzer hat explizit die Schüttel-Geste gewünscht.
- *Tastenkombination*: alle Tasten + Crank sind in den Editier-Räumen belegt (A malen, B Zoom-Out/Pipette/Nav, Crank Zoomkette/Picker). Verworfen.
- *`playdate.startAccelerometer` dauerhaft ab App-Start*: unnötiger Batterieverbrauch in Title-/Selection-Screen. Verworfen zugunsten Start/Stopp am Raum-Übergang.

---

## R2 — Undo-Wiederherstellung: Voll-Snapshot vs. inverse Delta (Spec Open #2)

**Decision**: **Voll-Snapshot des Pre-Zustands** je betroffener Einheit, kein inverses Delta.
- **Content-Operationen** (Clear Screen, Rotation, Pixel-Verschiebung): Der Eintrag hält je betroffener Zelle `{ cellIdx, prevPosIndex, prevImage }` — der vorherige Tile-Index in `layer.positions` **und** eine Referenz auf das vorherige 16×16-`gfx.image`. Undo: für jede Zelle `registerTile(prevImage)` (dedupliziert/hängt an) → `layer.positions[cellIdx] = neuerIndex` → `recompositeCell(cellIdx)`; danach `updateTilemapFrame()`. Clear Screen hat schlicht alle 375 Zellen im Eintrag.
- **Strukturoperation** (Frame löschen): Der Eintrag hält `{ index, frameLayersEntry (tiefe Kopie), framesEntry (Kopie des 375er-Cache oder nil) }`. `framesEntry` folgt demselben `if imageData.frames`-Guard wie `FrameManagementView.deleteMarked` — fehlt der flache Cache, ist es `nil` und wird beim Undo übersprungen. Undo: `table.insert(imageData.frameLayers, i, frameLayersEntry)` + (falls vorhanden) `table.insert(imageData.frames, i, framesEntry)`, dann `currentFrame = i`, `updateTilemapFrame`.

**Rationale**:
- Inverse Deltas („rotiere zurück", „schiebe zurück") brechen, sobald Tiles **geteilt** oder beim Speichern **umnummeriert** werden. Geprüft: `ImageStoreCodec.newSaveOperation` nummeriert die **Live-`imageData` NICHT** um (reine Transformation auf tiefen Kopien, `ImageStoreCodec.lua:55-58`); die einzige Laufzeit-Mutation der Imagetable ist *Anhängen* (`appendTileToImagetable`, wächst nur). Trotzdem ist der Bild-Referenz-Weg der robusteste: `undoLast()` konsultiert nie einen alten Index blind, sondern re-registriert das gespeicherte Bild. ⇒ **FR-008** („Speichern leert den Verlauf nicht") bleibt widerspruchsfrei umsetzbar; Constitution II bleibt PASS.
- Einheitliche `apply`-Logik: nur zwei Codepfade (`applyContentEntry`, `applyDeleteFrameEntry`) statt vier operations­spezifische Inversen.

**RAM-Budget** (worst case, 3 Einträge):
- Clear-Screen-Eintrag: 375 × (int + Bildreferenz) ≈ ein paar KB Tabelle (Bilder nicht kopiert).
- Frame-löschen-Eintrag: 3 Ebenen × 375 ints + 375-Cache ≈ ~1500 ints ≈ ~12–24 KB Lua-Tabelle.
- Gesamt < ~100 KB — unkritisch auf dem Playdate-Lua-Heap.

**Alternatives considered**:
- *Ganzen Frame bei jeder Content-Op kopieren*: einfacher, aber verschwenderisch (Rotation/Shift betreffen ≤ 2 Zellen). Verworfen.
- *Nur Index speichern, kein Bild*: bricht bei Rotation/Shift, weil dort **neue** Tile-Bilder entstehen, die nach dem Undo neu erzeugt werden müssen. Verworfen.

---

## R3 — Wann entsteht welcher Eintrag? (Erfassungspunkte)

**Decision**:

| Operation | Erfassungspunkt | Erfasst |
|---|---|---|
| Clear Screen | in `EditorRoom.clearCurrentFrame()`, **vor** dem Überschreiben von `layer.positions` | aktive Ebene: alle 375 `{cellIdx, prevPosIndex, prevImage}` + `currentFrame` + Ebenen-Array-Index |
| Frame löschen | in `FrameManagementView.deleteMarked()`, **vor** `table.remove` | tiefe Kopie `frameLayers[marked]` + `frames[marked]` + `marked` (Ursprungsindex). Meldung an `EditorRoom` über eine durchgereichte Referenz |
| 90°-Rotation | in `PixelRoom`, beim **ERSTEN** `rotateGridClockwise()` / `rotateGridCounterClockwise()` einer Bearbeitungssitzung (Flag `rotationSnapshotTaken`); an `EditorRoom` übergeben, **wenn** `commitToZoomRoom()` die Änderung tatsächlich zurückschreibt | Pre-Rotation-`gridState` der betroffenen Zelle → daraus 16×16-Bild; Zelle + `currentFrame` + Ebenen-Index |
| Pixel-Verschiebung | in `ZoomRoom`, beim **ersten** Shift eines „B-Halte-Runs" (siehe R4); Snapshot der ≤ 2 betroffenen Zellen über `EditorRoom` | `{cellIdx, prevPosIndex, prevImage}` je betroffener Zelle |

**Rationale**:
- **Clear Screen** heißt trotz des Namens „aktive Ebene leeren" (`EditorRoom.lua:451` — `fill = layerIndex==0 and 1 or 0`, nur `layer.positions`). Der Eintrag erfasst daher **nur die aktive Ebene**, nicht den ganzen Frame. (Wichtig für die Implementierung — Name und UI-Begriff „Clear Screen" legen fälschlich „ganzer Frame" nahe.)
- **Rotation**: `PixelRoom.setCurrentTile()` lädt `gridState` **vor** jedem Malen; ein Snapshot dort würde bei „20 Pixel malen, dann 1× rotieren" die 20 Mal-Edits mit-zurücknehmen — Verstoß gegen FR-002/SC-003. Deshalb Snapshot erst beim ersten `rotateGrid*()`. Und **Übergabe an die History erst beim Commit** (`commitToZoomRoom`), damit kein History-Eintrag auf eine nie zurückgeschriebene Änderung zeigt (Nutzer rotiert, verlässt PixelRoom ohne Commit-Pfad).
- **`deleteCurrentFrame()` in `EditorRoom.lua:427` ist toter Code** (kein Aufrufer, Kommentar dort). Nur `FrameManagementView.deleteMarked()` instrumentieren.

**Alternatives considered**:
- *Rotation-Eintrag sofort beim `rotateGrid*()` pushen*: Risiko eines „hängenden" Eintrags ohne Commit. Verworfen zugunsten Push-beim-Commit mit Snapshot-Zeitpunkt = erstes `rotateGrid*()`.

---

## R4 — Granularität der Pixel-Verschiebung (Spec Open #1)

**Decision**: Ein **„B-Halte-Run" = ein Verlaufseintrag.** Der Run beginnt beim ersten `shiftActiveLayerContent()` nach einem `BButtonDown` und endet beim `BButtonUp` (oder beim Verlassen der `ZoomRoom`, oder bei Ziel-Zellwechsel). Der Snapshot der betroffenen Zellen wird **einmal beim Run-Start** genommen; weitere Shifts im selben Run erweitern denselben Eintrag um neu betroffene Zellen, ohne einen zweiten Eintrag zu pushen.

**Rationale**: Die Pufferung aus einer früheren Spec-010-Iteration ist entfallen (ADR-043-Endform: „synchron pro Tastendruck"). Jeder 1-Pixel-Tastendruck als eigener Eintrag würde den 3er-Puffer sofort mit 3 Pixeln füllen — unbrauchbar und im Widerspruch zu „nur große Operationen" (Clarification). Die B-Halte-Klammer ist die natürliche Geste-Grenze und deckt sich mit dem vorhandenen ZoomRoom-Muster (`bHeld` steuert bereits Zoom vs. Shift, `ZoomRoom.lua:626`).

**Alternatives considered**:
- *Jeder Tastendruck = ein Eintrag*: siehe oben, verworfen.
- *Zeitfenster-Coalescing (alle Shifts innerhalb X ms)*: unnötig komplex; die B-Klammer ist präziser und schon vorhanden. Verworfen.

---

## R5 — Modaler Dialog: neues Muster oder vorhandenes wiederverwenden?

**Decision**: `UndoPrompt.lua` als **ein** gemeinsames Modul, das das `SelectionRoom.confirmingDelete`-Muster nachbildet: zentrierte 200×80-Box, Zeile 1 = „Undo <Operation>?", Zeile 2 „(A) Ja", Zeile 3 „(B) Nein". API: `open(actionLabel, onConfirm)`, `isOpen()`, `handleA()`, `handleB()`, `draw()`. Jeder der drei Editier-Räume:
- ruft am Ende von `draw()` `UndoPrompt.draw()`,
- prüft in **jedem** Inputhandler-Callback und in den `update()`-Crank-Blöcken zuerst `if UndoPrompt.isOpen() then …` (A → `handleA`, B → `handleB`, alles andere → geschluckt),
- leert beim Öffnen die Direction-Hold-Automaten (`clearDirectionHold()` o. ä.).

**Rationale**: Constitution IV verlangt Wiederverwendung bewährter Muster. `SelectionRoom` zeigt exakt diese Modalität (A/B/Crank/Nav werden geschluckt, solange `confirmingDelete` gesetzt ist — `SelectionRoom.lua:368/429/537/567/588`). Ein Modul statt drei Kopien hält FR-013 an einer Stelle testbar.

**Alternatives considered**:
- *Pro Raum eigener `confirmingUndo`-Zustand*: dreifache Duplizierung derselben Gate-Logik. Verworfen.
- *SDK `playdate.ui`-Dialog*: es gibt keinen fertigen modalen Ja/Nein-Dialog in `playdate.ui`; `gridview` wäre zweckentfremdet. Verworfen.

---

## R6 — Schüttel-Geste in der `FrameManagementView`? (Spec Open #3)

**Decision**: **Nein.** Die Geste ist nur in Tile View (`EditorRoom`), Zoom View (`ZoomRoom`) und Pixel View (`PixelRoom`) aktiv. In der `FrameManagementView` wird das Accelerometer nicht ausgewertet (und nicht zwingend gestartet). Ein `deleteFrame`-Eintrag entsteht dort bei `deleteMarked()`; der Nutzer erreicht den Undo-Dialog erst, nachdem er B loslässt und `returnToEditor()` zurück in den Tile View führt.

**Rationale**: In der `FrameManagementView` ist **B durch die Halte-Geste belegt** (`bWasHeld`, Loslassen = zurück zum Tile View, `FrameManagementView.lua:166-179`). Ein „(B) Nein" im Dialog würde mit dem Verlassen kollidieren, und Schütteln währenddessen wäre verwirrend. Der Löschvorgang selbst ist trotzdem rückgängig machbar — der Eintrag wird beim Löschen erzeugt, nur der Dialog erscheint eine Interaktion später im Tile View.

**Alternatives considered**:
- *Geste auch in der `FrameManagementView`, Dialog mit A=Ja / D-Pad=Nein*: bricht die etablierte „B loslassen = zurück"-Regel und die Konsistenz „A=Ja, B=Nein". Verworfen.

---

## R7 — Anwendbarkeit, Einstieg und Navigation (FR-006/007/009/016)

**Decision**: Trennung von **Anwendbarkeitsprüfung** (`UndoHistory:peekValid`) und **Anwendung** (`EditorRoom:undoLast`):

*`peekValid(imageData) -> entry, reason`* (läuft VOR dem Dialog):
1. Vom jüngsten Eintrag nach unten: `content` mit fehlendem Ziel-Frame → verwerfen (FR-006). `deleteFrame`, dessen Wiedereinfügen `#frameLayers >= 12` verletzt → verwerfen, `reason = "frame-limit"` merken (FR-007).
2. Erster anwendbarer Eintrag → zurückgeben. Keiner → `entry = nil` (mit `reason`).

*`EditorRoom:undoRequest()`* (Einstieg der erkannten Geste):
- `entry` vorhanden → `UndoPrompt.open(labelFor(entry), () -> self:undoLast())` (FR-012).
- kein `entry` → `showStatus(reason == "frame-limit" and "cannot undo — frame limit" or "Nothing to undo")`, **kein Dialog** (FR-007/FR-009).

*`EditorRoom:undoLast()`* (als `onConfirm`, nachdem `hasUndo` „es gibt etwas" garantiert hat):
- Eintrag anwenden (`applyContentEntry` / `applyDeleteFrameEntry`); `currentFrame` auf den betroffenen Frame setzen; `updateTilemapFrame()` / `recompositeCurrentFrame`; `pop()`; `needsRedraw = true`. **Keine** Ablehnung mehr an dieser Stelle — die 12-Grenze ist schon in `peekValid` ausgesiebt.

*Aus `ZoomRoom`/`PixelRoom`*: `onConfirm` committet zuerst offene Zell-Edits über den vorhandenen `commitForTerminate`-Pfad, ruft `switchRoom(EditorRoom)` (→ `EditorRoom:entered()` läuft **vollständig** durch, liest `imageData.returnFrame`, klemmt `currentFrame`), und **erst danach** `undoLast()` (das `currentFrame` final setzt). `undoLast()` wird nie aus `switchRoom`/`entered()` heraus aufgerufen, daher kein Wettlauf um `currentFrame`. Betreffen die committeten Zoom-Raster-Edits dieselben Zellen wie der Undo-Eintrag, überschreibt der Restore sie bewusst (der Nutzer hat „rückgängig" gewählt) — dokumentiert, kein Bug.

**Rationale**: „Dialog erscheint nur, wenn ein Undo garantiert klappt" (FR-012) verlangt, dass die 12-Grenze **vor** dem Dialog geprüft wird — sonst verspricht der Dialog einen Undo und nimmt ihn nach dem A-Druck zurück. Ein zentraler Anwendungs-Einstieg hält die Invarianten (Composite-Cache, Tilemap, `activeLayer`-Clamp) an einer Stelle.

**Alternatives considered**:
- *12-Grenze erst in `undoLast()` prüfen und `"rejected"` zurückgeben*: bricht FR-012 (Dialog ohne garantierten Erfolg) und zwingt den Nutzer zu einem zweiten Schütteln. Verworfen (war der erste Entwurf).
- *Undo direkt im aktuellen Raum anwenden*: `ZoomRoom`/`PixelRoom` müssten Composite-/Tilemap-Zustand selbst konsistent halten — Duplizierung. Verworfen.

---

## R8 — `ShakeDetector`-Algorithmus (headless-testbar)

**Decision**: Zustandsautomat über den X-Achsen-Wert `x` (Gerät-Längsachse):
- Halte den Zeitpunkt des letzten Peaks `> +T` und `< −T` (T = Schwellwert in g).
- Eine **Kante** feuert, wenn ein Peak der einen Polarität und danach (innerhalb `W` ms) ein Peak der anderen Polarität auftritt (= „einmal nach links und rechts").
- Nach einer Kante: `R` ms Refraktärzeit, in der nichts feuert.
- Startwerte (Hardware-Tuning, ADR-044): `T ≈ 0.85 g`, `W ≈ 500 ms`, `R ≈ 1200 ms`.
- API: `ShakeDetector.new(opts)` → `{ feed(x, y, z, nowMs) -> bool, reset() }`. Reine Funktion des Sample-Stroms + interner Kleinzustand.

**Rationale**: Kein Bezug auf SDK-Objekte ⇒ voll headless-testbar: synthetische Sample-Folgen (ruhig / einseitiger Ruck / sauberer Links-Rechts-Schwung / zu langsam) prüfen Kanten- und Refraktärverhalten sowie Fehlalarm-Freiheit (FR-010/011, SC-006-Anteil). Die **realen g-Werte**, die 9/10 Erkennung ohne Fehlalarm liefern, bleiben Hardware-Tuning (Spec Open #4).

**Alternatives considered**:
- *Betrag `sqrt(x²+y²+z²)`-Schwelle*: erkennt „Erschütterung", aber nicht die geforderte **Richtungssequenz** „links und rechts"; anfälliger für Geh-Fehlalarme. Als sekundäres Gate evtl. später, jetzt YAGNI.
- *SDK-Tiefpass/Kalibrierung*: kein solches SDK-Feature; eigener Filter wäre Overkill für eine bewusste Geste. Verworfen.

---

## R9 — Headless-Test-Mock für das Accelerometer

**Decision**: In `tests/headless_tests.lua` den `playdate`-Mock ergänzen um:
`startAccelerometer = function() accelRunning = true end`, `stopAccelerometer = function() accelRunning = false end`, `readAccelerometer = function() return accelXYZ[1], accelXYZ[2], accelXYZ[3] end`, mit einer testseitig setzbaren Modulvariable `accelXYZ = {0,0,1}`. Analog zum bestehenden Button-/Crank-Mock (`heldButtons`, `crankTicksValue`).

**Rationale**: Der strikte `strictTable`-Mock wirft sonst „erfundene SDK-API" bei jedem Accelerometer-Zugriff (genau der gewünschte Schutz — deshalb muss die echte API explizit gemockt werden). Setzbare Werte erlauben Frame-für-Frame-Simulation eines Schüttelverlaufs.

**Alternatives considered**:
- *`ShakeDetector` ganz ohne SDK testen und die Room-Integration ungetestet lassen*: ließe die „Room ruft `readAccelerometer` pro Frame"-Verdrahtung ungeprüft. Der Mock kostet ~5 Zeilen — mitnehmen.

---

## Zusammenfassung offener Punkte nach Phase 0

| Punkt | Status |
|---|---|
| Pixel-Verschiebungs-Granularität | **Gelöst** (R4) |
| Snapshot-Mechanik / RAM-Budget | **Gelöst** (R2/R3) |
| Geste in `FrameManagementView` | **Gelöst** (R6) |
| Konkreter Bewegungsschwellwert `T/W/R` (SC-006) | **Offen** — Owner Hardware-Test; Follow-up: Werte in ADR-044 nachtragen; Trigger: erste Gerätesitzung |
