# Phase 0 Research: Editor-UI-Verbesserungen

**Feature**: 006-editor-ui-polish | **Date**: 2026-07-19

Alle Punkte gegen das lokal installierte Playdate SDK (`~/Developer/PlaydateSDK`,
**v3.0.6**) und den tatsächlichen Source-Code (`Source/EditorRoom.lua`,
`Source/ZoomRoom.lua`, `Source/PixelRoom.lua`, `Source/SelectionRoom.lua`,
`Source/Bauchbinde.lua`, `Source/main.lua`) verifiziert — Constitution
Prinzip I (SDK-First) und projektweite SDK-Verifikationsregel.

---

## R1: Crank-Volldrehung (FR-004/FR-005/FR-006) — `getCrankChange()` statt `getCrankTicks()`

**Ist-Zustand**: `EditorRoom.lua:392` liest `playdate.getCrankTicks(4)` und ruft
bei JEDEM zurückgegebenen Tick (also bereits nach 90°, da `4` Ticks pro
Umdrehung bedeutet) sofort `tickForward()`/`tickBackward()` auf — exakt das
vom Nutzer gemeldete Problem.

**Warum `getCrankTicks(1)` NICHT reicht**: Laut SDK-Doku sind Tick-Grenzen
**absolute** Positionen der Kurbel-Rotation, nicht relativ zum Drehbeginn des
Nutzers. `getCrankTicks(1)` würde also genau dann einen Tick liefern, wenn die
absolute 0°-Position überschritten wird — steht die Kurbel zufällig knapp
davor, reicht eine winzige Bewegung für einen "vollen" Tick. Das erfüllt nicht
die Anforderung "eine vollständige Umdrehung AB DER AKTUELLEN POSITION".

**Decision**: `playdate.getCrankChange()` (liefert `change`, den Winkel-Delta
in Grad seit dem letzten Aufruf, negativ bei Gegenuhrzeigersinn) in einen
eigenen, signierten Akkumulator (`crankAccumDegrees`) aufsummieren:

```lua
local change = playdate.getCrankChange()
crankAccumDegrees = crankAccumDegrees + change
if crankAccumDegrees >= 360 then
    crankAccumDegrees = crankAccumDegrees - 360
    tickForward()
elseif crankAccumDegrees <= -360 then
    crankAccumDegrees = crankAccumDegrees + 360
    tickBackward()
end
```

Ein einziger **signierter** Akkumulator (statt getrennter Vorwärts-/Rückwärts-
Zähler mit Reset-Logik) erfüllt alle vier Acceptance Scenarios der Spec ohne
Sonderfall-Code: Vor- und Rückwärtsbewegung heben sich im Summenwert von
selbst auf (AS1/AS3: 270° vor + 90° zurück bleibt bei 0° Nettofortschritt →
kein Wechsel), eine durchgehende Bewegung in eine Richtung erreicht ±360°
(AS2), und Einklappen mitten in der Drehung ändert nichts, weil einfach keine
weiteren `getCrankChange()`-Aufrufe mehr passieren (AS4) — der Akkumulator
bleibt stehen, bis die nächste Kurbel-Bewegung ihn weiterführt oder in die
Gegenrichtung zurückführt. Deckt sich mit Constitution Prinzip IV
(Einfachheit): kein zusätzlicher Zustandsautomat nötig.

**SelectionRoom.lua nutzt bereits `crankAccumDegrees` unter demselben Namen**
für die Sync-Geste (`SYNC_GESTURE_THRESHOLD_DEGREES = 720`, siehe Spec 004) —
dasselbe Muster (Akkumulation von `getCrankChange()`-Delta) ist damit bereits
im Projekt etabliert und bewährt, nur mit anderem Schwellwert und Reset auf 0
statt Restwert-Erhalt. Für diese Spec wird der **Restwert erhalten** (nicht
auf 0 zurückgesetzt), weil sich sonst bei zügigem Mehrfach-Drehen (Edge Case
"schnelles Drehen", bereits in `handleCrank()` für `getCrankTicks` behandelt)
Grad-Bruchteile verlieren würden.

**Alternativen verworfen**:
- `getCrankTicks(1)` — verworfen, siehe oben (absolute statt relative
  Positions-Grenzen).
- Getrennte Vorwärts-/Rückwärts-Akkumulatoren mit explizitem Reset bei
  Richtungswechsel — verworfen zugunsten des einfacheren signierten
  Akkumulators (Constitution IV), der dasselbe Verhalten ohne
  Richtungserkennungs-Sonderfall liefert.

**Wichtig**: `ZOOM_TICK_THRESHOLD`/B+Crank-Zoomkette (`getCrankTicks(4)`,
Zeile 392/397) bleibt **unverändert** — laut Spec-Annahme betrifft die
Volldrehungs-Anforderung ausschließlich die reine Frame-Navigation ohne
gedrückte B-Taste. Die Crank-Lesung muss daher aufgeteilt werden: Ist B
gehalten, weiterhin `getCrankTicks(4)` für die Zoomkette; ist B nicht
gehalten, `getCrankChange()` für die neue Frame-Akkumulation. Da beide
API-Aufrufe denselben internen "seit letztem Aufruf"-Zustand der Kurbel
fortschreiben, muss **pro Frame genau einer** von beiden aufgerufen werden
(nie beide), sonst gehen Grad-/Tick-Anteile verloren — bereits jetzt so
gelöst (Zeile 393 verzweigt exklusiv zwischen beiden Pfaden).

---

## R2: Zoom-View-Hintergrund in echter 16×16-Auflösung (FR-007/FR-008/FR-009)

**Ist-Zustand**: `ZoomRoom.lua:decodeImageIntoGrids()` sampelt pro 2×2-Block
NUR den EINEN Pixel `img:sample((c-1)*2, (r-1)*2)` (oben links) und
`drawGrid()` färbt die gesamte 10×10-Displayzelle einheitlich mit diesem
einen Sample-Wert. Enthält ein 2×2-Block z. B. 2 schwarze und 2 weiße
Quellpixel, sieht der Nutzer nur eine flächige Farbe — exakt das gemeldete
Problem (FR-009 verlangt, alle vier Einzelpixel zu unterscheiden, BEVOR die
Zelle bearbeitet wird).

**Decision**: Zweigleisige Darstellung pro Zelle in `drawGrid()`, basierend
auf dem bereits vorhandenen `gridState`/`baselineGrid`-Vergleich (aktuell nur
für `slotHasCellEdits()`/`collectEdits()` genutzt):

- **Unbearbeitete Zelle** (`gridState[r][c] == baselineGrid[r][c]`, der
  Nutzer hat sie in dieser Sitzung noch nicht übermalt): alle vier
  Einzelpixel des zugehörigen 2×2-Blocks aus `slot.editedImage or
  slot.originalImage` einzeln sampeln und als vier 5×5-Subquadranten
  innerhalb der 10×10-Zelle zeichnen (echte Quellauflösung sichtbar,
  FR-007/FR-009).
- **Bearbeitete Zelle** (Wert weicht vom Baseline ab): weiterhin EIN
  flächiger 10×10-Block wie bisher — nach einer Bearbeitung IST der Block
  laut Editier-Semantik (FR-008: Zelle wird als Ganzes gefüllt/geleert)
  tatsächlich einheitlich, es gibt keine feinere Information mehr zu zeigen.

Kein neuer Zustand nötig — `gridState`/`baselineGrid` und die
Slot-Referenzen (`slots[sr][sc].originalImage`/`.editedImage`) existieren
bereits exakt für diesen Zweck (bisher nur für die Diff-Erkennung beim
Commit verwendet, jetzt zusätzlich fürs Rendering). Das Editier-Modell selbst
(ein Bool pro Zelle, Fill/Clear als Ganzes) bleibt unverändert — FR-008
fordert ausdrücklich, dass das weiterhin so bleibt.

**Alternativen verworfen**:
- Eigene, zusätzliche 16×16-pro-Slot-Rohpixel-Struktur parallel zu
  `gridState` pflegen — verworfen: mehr Zustand, während `slot.originalImage`
  bereits das komplette Quellbild jederzeit sample-fähig bereithält.
- Immer (auch nach Bearbeitung) die vier Subpixel zeigen — verworfen:
  widerspricht FR-008 (Zelle ist nach Bearbeitung ein einheitlicher Block,
  keine Subpixel-Illusion vortäuschen, die real nicht mehr existiert).

---

## R3: Bauchbinde — Inaktivitäts-Timer und Cursor-Ausweich-Logik (FR-001/002/003)

**Ist-Zustand**: `Bauchbinde.lua` ist ein reines, zustandsloses Zeichen-
Helferlein (`drawBottom(text, side, screenW, screenH)`, `gfx` injiziert für
Headless-Testbarkeit) — keine Sichtbarkeits- oder Zeit-Logik. `EditorRoom.lua`
ruft es aktuell JEDEN Frame bedingungslos mit `side="right"` fest verdrahtet
auf (Zeile 441).

**Decision**: Inaktivitäts-Timer UND Seiten-Berechnung leben in
`EditorRoom.lua` (nicht in `Bauchbinde.lua`) — analog zum bereits
bestehenden `statusMessage`/`statusUntilMs`-Muster (Zeile 57/58/83-87), das
exakt dasselbe Problem (zeitgesteuerte Sichtbarkeit via
`playdate.getCurrentTimeMilliseconds()`) bereits im selben Modul löst.
`Bauchbinde.lua` bleibt unverändert ein reiner Zeichen-Helfer — kein neuer
DI-Bedarf für eine Zeitquelle, keine Aufweichung der bestehenden
Headless-Testbarkeitsgrenze des Moduls.

Neuer Zustand in `EditorRoom.lua`:
- `lastActivityMs` — bei JEDER Eingabe aktualisiert: D-Pad-Bewegung
  (`moveCursor`), A-Druck (`beginStroke`), B-Druck/-Release, UND
  Crank-Bewegung (`crankTicks ~= 0` in `handleCrank()` bzw. `change ~= 0`
  nach R1) — deckt alle in FR-002 genannten Eingabearten ab.
- Sichtbarkeit: `bauchbindeVisible = (nowMs - lastActivityMs) < 5000`.
- Seite: `side = (cursor.x <= GRID_COLS / 2) and "right" or "left"` — Cursor
  in der linken Bildschirmhälfte → Bauchbinde rechts (und umgekehrt), wie
  in FR-003 gefordert. Bei exakter Mitte (`GRID_COLS = 25`, ungerade — es
  gibt keine exakte Mitte bei ungerader Spaltenzahl, `cursor.x` ist immer
  eindeutig links oder rechts von 12.5) entfällt der in den Edge Cases der
  Spec besprochene Sonderfall bereits durch die ungerade Spaltenzahl.

**Alternativen verworfen**:
- Timer-/Sichtbarkeitslogik in `Bauchbinde.lua` verlagern — verworfen:
  würde das Modul von einer reinen Zeichenfunktion zu einer zustandsbehafteten
  Komponente mit eigener Zeitquelle machen, obwohl das bereits etablierte
  `statusMessage`-Muster im Aufrufer (EditorRoom) genau dafür existiert.

---

## R4: Kontext-/Pause-Ansicht (FR-010/011/012/013) — `playdate.setMenuImage()` statt neuem Screen

**Ist-Zustand**: `EditorRoom.lua:buildSystemMenu()` nutzt bereits alle 3
verfügbaren System-Menü-Slots (`save + exit`, `delete frame`,
`show grid`-Checkmark) — bestätigt gegen den tatsächlichen Code, deckt sich
mit der in spec.md genannten Beobachtung aus Spec 004 (3-Slot-Limit). Das
native System-Menü selbst kann keine eigene Grafik wie ein Tile-Raster
rendern (nur Text-Items + optionale Checkmarks).

**Befund**: `playdate.setMenuImage(image, [xOffset])` (Inside Playdate.html
§2.3) ist exakt für diesen Zweck vorgesehen: "While the game is paused it
can optionally provide an image to be displayed **alongside** the System
Menu." Wichtige Einschränkung aus der Doku: "All important content should
be in the **left half** of the image in an area **200 pixels wide**, as the
menu will obscure the rest." Das zugehörige Callback
`playdate.gameWillPause()` ("Called before the system pauses the game... 
e.g., updating the menu image") ist laut Doku-Beispiel wörtlich für genau
diesen Anwendungsfall (Menü-Bild kurz vor dem Pausieren aktualisieren)
vorgesehen — kein `gameWillPause`-Hook existiert bisher in `main.lua`.

**Decision**: Neuer `playdate.gameWillPause()`-Hook in `main.lua`, der —
sofern `currentRoom` EditorRoom, ZoomRoom oder PixelRoom ist (alle drei
kennen dasselbe `imageData`, siehe `applyTileEdits`/`imageDataRef`) —
`EditorRoom:buildPauseMenuImage()` aufruft und das Ergebnis an
`playdate.setMenuImage(img)` übergibt. Der Bildaufbau (12×10-Tile-Raster im
linken 200px-Bereich, Gesamtzahl unten links, Frame-Anzahl als
Metainformation) läuft NUR beim tatsächlichen Pausieren (nicht bei jedem
Redraw) — passend zum seltenen Auslöse-Ereignis, kein Performance-Risiko.

Gesamtzahl unterschiedlicher Tiles (FR-011) wird NICHT aus
`imagetable:getLength()` übernommen (könnte nie mehr referenzierte
Alt-Einträge mitzählen, siehe Kommentar in `ImageStoreCodec.lua` zu den
garantierten Basis-Tiles Index 1/2), sondern frisch durch Iteration über
alle `imageData.frames[*]`-Einträge als Set unterschiedlicher Indizes
berechnet (max. 12 × 375 = 4500 Vergleiche, unkritisch für einen einmaligen
Pause-Trigger).

**Neuer ADR-Kandidat AD-031** ("Kontext-/Pause-Ansicht via
`setMenuImage`/`gameWillPause` statt eigenem In-Game-Screen") — löst den in
spec.md als "Open" markierten ADR-Punkt auf.

**Alternativen verworfen**:
- Eigener neuer Room ("PauseRoom"), betreten über eine weitere
  Crank-/Button-Geste — verworfen: Constitution-Randbedingung "D-Pad,
  A/B-Buttons und Crank sind die einzigen Eingabegeräte" böte zwar
  technisch eine Geste an, aber der native Playdate-Pause-Mechanismus
  (Menü-Taste) IST bereits die etablierte, plattformkonforme Pause-Geste;
  ein zusätzlicher eigener Pause-Screen würde diese verdoppeln/verwirren
  und widerspricht Constitution IV (Einfachheit — SDK bietet die passende
  Lösung bereits nativ an, Prinzip I SDK-First).
- Bestehende Menü-Items ersetzen/konsolidieren, um einen 4. Slot für einen
  Grafik-Hinweis freizumachen — hinfällig, da `setMenuImage` gar keinen
  Menü-Item-Slot belegt (separater Mechanismus).

---

## R5: VHS-Griesel-Effekt (FR-017) — Pattern-Phasenwechsel statt Pro-Pixel-Zufall

**Befund**: Das SDK bietet kein natives "Noise"/"Static"/"VHS"-Widget
(Doku-Grep ergebnislos).

**KORRIGIERT während der Implementierung (T021, Constitution I —
SDK-Verifikation vor Umsetzung)**: Die ursprünglich hier dokumentierte
Annahme, `gfx.setDitherPattern(level, ditherType, xPhase, yPhase)` böte
einen Phasen-Offset, war FALSCH — gegen die tatsächliche SDK-Doku
verifiziert (`Inside Playdate.html`) lautet die reale Signatur
`playdate.graphics.setDitherPattern(alpha, [ditherType])`, OHNE
`xPhase`/`yPhase`-Parameter. Der Phasen-Offset `(default 0, 0)`, der beim
ersten Lesen fälschlich dieser Funktion zugeordnet wurde, gehört zu einer
ANDEREN, benachbart dokumentierten Funktion: `gfx.setPattern(pattern,
[x, y])` — setzt ein 8-Byte-Bitmuster (bzw. ein Bild) als Zeichenmuster,
mit genau dem gesuchten optionalen `x,y`-Phasen-Offset. Diese Funktion ist
im Projekt bereits an zwei Stellen verifiziert im Einsatz (`ZoomRoom.lua`,
`PixelRoom.lua`, Checkerboard-Seitenflächen).

**Decision (korrigiert)**: Der VHS-Effekt wird über `gfx.setPattern(pattern,
xPhase, yPhase)` mit einem irregulären 8-Byte-Muster erzeugt, dessen
`xPhase`/`yPhase` sich alle `VHS_PHASE_INTERVAL_MS` ändern — erzeugt ein
flimmerndes Störmuster über dem Vollbild-Hintergrund, ohne pro Frame 96.000
Einzelpixel (400×240) manuell zufällig zu setzen (das wäre auf der
Zielhardware ein reales Performance-Risiko, Constitution "Performance:
Interaktionen müssen flüssig bleiben"). Da `setPattern`/`setColor`
laut SDK-Doku exklusiv sind, MUSS nach dem Overlay-`fillRect` wieder
`gfx.setColor(...)` aufgerufen werden, sonst rendern nachfolgende
UI-Elemente (Gridview-Kreise, Bauchbinde) fälschlich im Muster statt in
Vollfarbe — in `SelectionRoom.lua` umgesetzt. Konkretes Muster/Intervall
wurde als Implementierungs-Detail direkt in `SelectionRoom.lua` festgelegt
(kein separates Datenmodell-Kapitel nötig, siehe data-model.md Abschnitt 5);
finale visuelle Kalibrierung bleibt wie geplant offen (siehe plan.md
Architecture Governance, T023).

**Alternativen verworfen**:
- Pro-Pixel-Zufallsrauschen via `gfx.drawPixel` in einer Doppelschleife über
  400×240 — verworfen: potenzielles Performance-Risiko auf Zielhardware,
  während Pattern-Phasenwechsel dieselbe visuelle Wirkung nativ und
  günstig erzielt.
- `gfx.setDitherPattern(alpha, ditherType)` mit zeitlich wechselndem
  `alpha`/`ditherType` (kein Phasen-Offset, da die Funktion diesen
  Parameter tatsächlich nicht besitzt) — verworfen: liefert bestenfalls
  ein Flackern der GESAMTEN Fläche gleichzeitig, kein sich räumlich
  verschiebendes Störmuster, wie es "VHS-Griesel" nahelegt.

---

## R6: Titelscreen-Vollbild-Animation (FR-016/FR-018) — Lazy-Load der vollen Frame-Daten nur für die Auswahl

**Ist-Zustand**: `SelectionRoom.lua` zeigt für jeden Eintrag nur ein
statisches, kreisförmig maskiertes `preview`-Thumbnail (72×72,
`ImageStore.getPreviewImage`, gecacht in `thumbCache`) — ein einzelnes
Bild, keine Frame-Sequenz, keine Tile-/Imagetable-Daten.

**Decision**: Für den vollflächigen animierten Hintergrund werden die
VOLLEN Bilddaten (Imagetable + alle Frames, wie `EditorRoom` sie beim Laden
über `ImageStoreCodec.newLoadOperation` bezieht) NUR für den aktuell
selektierten Eintrag lazy nachgeladen (Coroutine + `RoomOperation`,
bestehendes Muster) — nicht für alle Kreise gleichzeitig (Performance,
Speicher). Bei Selektionswechsel wird ein laufender Ladevorgang für den
vorherigen Eintrag verworfen; bis der neue geladen ist, bleibt der
bisherige Kreis-Look sichtbar (kein Sprung/Leerbild). Nach Laden: Tilemap
wird pro Frame im Wechsel (Timer-getrieben, gleiche Frame-Reihenfolge wie
Editor) auf vollen 400×240 skaliert/positioniert gezeichnet, überlagert vom
R5-Störeffekt; alle anderen Einträge bleiben unverändert die bestehenden
statischen Kreis-Thumbnails (FR-018 — kein Rerendering nötig, da deren
Zeichenpfad unverändert bleibt).

**Alternativen verworfen**:
- Alle Frame-Daten aller Einträge beim Betreten von `SelectionRoom`
  vorab laden — verworfen: unnötiger Speicher-/Ladeaufwand für Einträge,
  die möglicherweise nie ausgewählt werden (Constitution IV).
- Animation aus dem bereits vorhandenen 72×72-Preview hochskalieren statt
  echter Frame-Daten — verworfen: `preview` ist nur ein EINZELNES
  Standbild (kein Animationsverlauf), liefert keine Frame-Sequenz.

---

## R7: "Reset Frame" (FR-014/FR-015) — Deep-Copy des Vorgänger-Frame-Arrays

**Befund**: Frames sind in `imageData.frames[n]` bereits einfache
Ganzzahl-Arrays fester Länge (`GRID_COLS * GRID_ROWS = 375`, Tile-Indizes).
`tickForward()` (Zeile 158-174) kopiert beim Anlegen eines neuen Frames
bereits elementweise aus dem Vorgänger (`copy[i] = tileIndex`) — exakt die
Operation, die "Reset Frame" braucht, nur auf den AKTUELLEN statt einen
neuen Frame angewendet.

**Decision**: Neue Funktion `resetCurrentFrameToPrevious()`: no-op, wenn
`currentFrame == 1` (FR-015, kein Vorgänger); sonst
`imageData.frames[currentFrame][i] = imageData.frames[currentFrame - 1][i]`
für alle 375 Indizes, gefolgt von `updateTilemapFrame()` +
`needsRedraw = true` — dieselbe Sequenz wie bei jeder anderen
Frame-Mutation in diesem Modul. Kein neuer Tile-Dedup-Bedarf: es werden nur
bereits existierende Tile-INDIZES kopiert, keine neuen Tile-Bilder erzeugt.

**Auslösung — ADR AD-032, entschieden (Projektinhaber-Vorgabe)**: Kein
freier System-Menü-Slot (R4 — bereits 3/3 belegt durch "save + exit"/
"delete frame"/"show grid", und `setMenuImage` transportiert keine
Aktionen, nur ein Bild). Eine Prüfung aller bestehenden
D-Pad/A/B/Crank-Kombinationen zeigt: es gibt AKTUELL keinen wirklich freien
Chord — A löst in `AButtonDown` immer bedingungslos `beginStroke()` aus
(auch während B gehalten wird), D-Pad-Bewegung ist ebenfalls nicht an den
B-Zustand gekoppelt; jede neue Chord-Belegung würde also eine bestehende
(wenn auch ungewöhnliche) Eingabe-Kombination überschreiben.

**Entscheidung**: Der Menüpunkt **"delete frame" wird durch "reset frame"
ersetzt** — der dritte Menü-Slot behält seine Position, wechselt aber die
Funktion; "show grid" bleibt unverändert erhalten. Neuer Menü-Aufbau:
`"save + exit"`, `"reset frame"`, `"show grid"` (Checkmark).

**Konsequenz**: Die bisherige "delete frame"-Aktion (FR-008a aus Spec 003:
aktiven Frame entfernen, Nachrücker aktiv) ist damit NICHT mehr über das
Menü erreichbar — die Implementierungsfunktion `deleteCurrentFrame()` kann
im Code verbleiben (kein toter Code, falls später ein anderer
Zugriffsweg gewünscht wird), verliert aber ihren einzigen Aufrufer.
Begründung/Abwägung liegt beim Projektinhaber (explizite Vorgabe); aus
Editor-Workflow-Sicht ist "reset frame" (Vorgänger-Inhalt übernehmen) eine
sinnvolle Alternative zu "delete frame" (Frame entfernen), wenn der Nutzer
mit einem Frame unzufrieden ist — beide Aktionen adressieren denselben
Fehlerkorrektur-Anwendungsfall, "reset frame" verliert dabei aber keine
Frame-Anzahl/Positionsstruktur. Owner: Projektinhaber (Entscheidung bereits
getroffen); falls "delete frame" weiterhin gebraucht wird, ist ein
Folge-Slot/-Zugriffsweg außerhalb dieser Spec zu klären.

---

## Zusammenfassung: SDK-Bausteine für diese Spec (neu verifiziert)

| Bedarf | Verifizierter SDK-Baustein |
|---|---|
| Volldrehungs-Akkumulation (FR-004/005) | `playdate.getCrankChange()` (nicht `getCrankTicks`) |
| Echte Zoom-Pixel-Auflösung (FR-007) | `image:sample(x,y)` pro Einzelpixel (bereits im Projekt genutzt) |
| Kontext-/Pause-Ansicht (FR-010) | `playdate.setMenuImage(image)` + `playdate.gameWillPause()` |
| VHS-Effekt (FR-017) | `gfx.setPattern(pattern, xPhase, yPhase)` (korrigiert, siehe R5 — `setDitherPattern` hat keinen Phasen-Offset) |
| Titelscreen-Animation (FR-016) | Bestehendes `ImageStoreCodec.newLoadOperation` + `RoomOperation`-Muster |
