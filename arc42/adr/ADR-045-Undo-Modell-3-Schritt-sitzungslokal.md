# ADR-045: Undo-Modell — 3 Schritte, sitzungslokal, Voll-Snapshot des Pre-Zustands

## Status
✅ **Umgesetzt** (Spec 011, US1/US2) — `Source/UndoHistory.lua`,
`Source/EditorRoom.lua` (`record*` / `apply*` / `undoLast` / `undoRequest`),
`Source/FrameManagementView.lua` (`deleteMarked` meldet den gelöschten
Frame), `Source/ZoomRoom.lua` / `Source/PixelRoom.lua` (Rotation-/Shift-
Erfassungspunkte).

## Kontext
Undo soll die **letzten 3** potenziell großflächig zerstörerischen
Operationen zurücknehmen können — und **nur diese vier**:

1. **Clear Screen** (`EditorRoom.clearCurrentFrame()` — leert trotz Namen
   nur die **aktive Ebene**)
2. **Frame löschen** (`FrameManagementView.deleteMarked()` — **nicht** der
   tote `EditorRoom.deleteCurrentFrame()`)
3. **90°-Pixel-Rotation** (`PixelRoom.rotateGrid*()`)
4. **Pixel-Verschiebung** (`ZoomRoom.shiftActiveLayerContent()` →
   `EditorRoom:shiftActiveLayer()`, ADR-043)

Feingranulares Malen zählt **nicht** (zwei Clarifications, Session
2026-09-02). Kein Redo, keine Persistenz (Constitution IV — harte einfache
Grenzen sind hier erwünscht; arc42 Kap. 4 „Kein Undo/Redo-Stack" wird für
genau diesen begrenzten Fall aufgehoben).

## Entscheidungs-Treiber
- Ein zurückgenommener Zustand muss **exakt** dem Stand von unmittelbar vor
  der Operation entsprechen (FR-002).
- **FR-008**: Speichern leert den Verlauf nicht — ein Undo nach dem
  Speichern muss weiter funktionieren.
- **FR-012**: Der Dialog erscheint nur, wenn „(A) Ja" **garantiert** zu
  einem Undo führt.
- **RAM** auf dem Playdate-Lua-Heap ist knapp — 3 Einträge, worst case ein
  gelöschter Frame.
- Headless-Testbarkeit (Constitution V).

## Optionen

| Option | Vorteile | Nachteile |
|--------|----------|-----------|
| **A: Voll-Snapshot des Pre-Zustands je betroffener Zelle (`prevPosIndex` + `prevImage`-Referenz); Frame löschen = tiefe Kopie. Zwei `apply`-Pfade.** | robust gegen Tile-Sharing + Umnummerierung; nur 2 Codepfade; billig (Rotation/Shift ≤ 2 Zellen) | Clear-Screen-Eintrag hält alle 375 Zellen (aber nur ints + Referenzen) |
| B: inverse Deltas („rotiere zurück", „schiebe zurück") | minimaler Speicher | bricht, sobald Tiles geteilt oder beim Speichern umnummeriert werden; vier operationsspezifische Inversen |
| C: ganzen Frame bei jeder Content-Op kopieren | ein Codepfad | verschwenderisch — Rotation/Shift betreffen ≤ 2 Zellen |
| D: nur Tile-Index speichern, kein Bild | kleinster Eintrag | bricht bei Rotation/Shift — dort entstehen **neue** Tile-Bilder, die nach dem Undo neu erzeugt werden müssen |

## Entscheidung
**Option A.**

### `UndoHistory` (Ringpuffer, `Source/UndoHistory.lua`)
- `push(entry)` — anhängen, vorne auf `MAX = 3` kürzen (FIFO, FR-001).
- `peekValid(imageData) -> entry, reason` — vom jüngsten Eintrag nach unten:
  - `content`-Eintrag mit fehlendem/aus-dem-Bereich-gefallenem `frameIndex`
    → **verwerfen** (FR-006).
  - `deleteFrame`, dessen Wiedereinfügen `#frameLayers >= 12` verletzen
    würde → **verwerfen**, `reason = "frame-limit"` merken (FR-007).
  - erster anwendbarer Eintrag → zurückgeben; keiner → `nil` (+ `reason`).
- `coalesceTarget(op, frameIndex, layerArrayIndex)` — jüngster Eintrag mit
  gleichem Ziel **und** `runOpen == true` (für den Shift-Run, siehe unten).
- `pop()`, `clear()`, `isEmpty()`.

### Eintragsformen
- **`content`** (`op ∈ {clear, rotate, shift}`):
  `{ kind="content", op, frameIndex, layerArrayIndex, cells = { [cellIdx] = { prevPosIndex, prevImage } } }`.
  `clear` hat schlicht alle 375 Zellen der aktiven Ebene.
- **`deleteFrame`**:
  `{ kind="deleteFrame", op="deleteFrame", index, frameLayersEntry (tiefe Kopie), framesEntry (Kopie des 375er-Cache oder nil) }`.
  `framesEntry` folgt demselben `if imageData.frames`-Guard wie
  `FrameManagementView.deleteMarked` — fehlt der flache Cache, ist es `nil`.

### Erfassungspunkte (research.md R3)
| Operation | Wo | Erfasst |
|---|---|---|
| Clear Screen | `clearCurrentFrame()`, **vor** dem Überschreiben von `layer.positions` (`recordClear`) | aktive Ebene, alle 375 `{prevPosIndex, prevImage}` |
| Frame löschen | `FrameManagementView.deleteMarked()`, **vor** `table.remove` → `EditorRoom:recordDeleteFrame(index, tiefeKopie, cacheKopie?)` | ganzer Frame + Ursprungsindex |
| 90°-Rotation | `PixelRoom`: Snapshot beim **ERSTEN** `rotateGrid*()` je `setCurrentTile`-Sitzung (Flag `rotationSnapshotTaken`, in `setCurrentTile` zurückgesetzt); Übergabe an `EditorRoom:recordRotation(cellIdx, prevImage)` **erst bei `commitToZoomRoom()`** (via `ZoomRoom:setNewTile`) | Pre-Rotation-16×16-Bild der Zelle |
| Pixel-Verschiebung | `ZoomRoom`: `recordShiftCandidates` beim ersten Shift eines „B-Halte-Runs"; `coalesceTarget` sammelt weitere Zellen in **denselben** Eintrag; `endShiftRun()` bei `BButtonUp` / Raumwechsel / Commit (`runOpen = false`) | `{prevPosIndex, prevImage}` je ≤ 2 Zellen, Snapshot = Run-Start |

### Anwendung (nur in `EditorRoom`, research.md R7)
- `applyContentEntry(entry)` — je Zelle `layer.positions[cellIdx] =
  resolvePrevIndex(cell)`; bei `op=="clear"` `recompositeCurrentFrame()`,
  sonst je Zelle `recompositeCell` + `updateTilemapFrame()`.
- `applyDeleteFrameEntry(entry)` — `table.insert` in `frameLayers` (und
  `frames`, falls vorhanden) an `min(index, n+1)`; `activeLayer` klemmen.
- `EditorRoom:undoLast() -> "applied" | "empty"` — `peekValid` liefert den
  Eintrag (die 12-Grenze ist hier bereits ausgesiebt, **keine** Ablehnung
  mehr), anwenden nach `kind`, `currentFrame` auf den betroffenen Frame,
  `undoHistory:pop()`.

`resolvePrevIndex(cell)` bevorzugt `cell.prevPosIndex` — die Imagetable
**wächst zur Laufzeit nur** (`appendTileToImagetable`), sie nummeriert nie
um (`ImageStoreCodec.newSaveOperation` ist eine reine Transformation auf
tiefen Kopien, `ImageStoreCodec.lua:55-58`), also bleibt der ursprüngliche
Index die ganze Sitzung gültig. `cell.prevImage` (das gespeicherte 16×16-
Bild) ist nur das **Sicherheitsnetz**: liegt `prevPosIndex` außerhalb
`imagetable:getLength()` oder weicht das Bild dort ab, wird `prevImage`
per `registerTile` neu registriert.

## Begründung
- Inverse Deltas (Option B) brechen bei geteilten Tiles / Umnummerierung;
  der Bild-Referenz-Weg konsultiert nie blind einen alten Index. ⇒ FR-008
  bleibt widerspruchsfrei, Constitution II bleibt PASS.
- Nur zwei `apply`-Pfade statt vier operationsspezifische Inversen.
- „B-Halte-Run = ein Eintrag" (ADR-043-Endform: Shift läuft synchron pro
  Tastendruck): jeder 1-px-Druck als eigener Eintrag würde den 3er-Puffer
  sofort mit 3 Pixeln füllen — im Widerspruch zu „nur große Operationen".
- 12-Grenze **in `peekValid`**, nicht in `undoLast`: FR-012 verlangt, dass
  der Dialog nur bei garantiertem Erfolg erscheint. Ein „rejected" nach
  dem A-Druck (erster Entwurf) zwänge zu einem zweiten Schütteln.

**RAM-Budget** (worst case, 3 Einträge): Clear-Eintrag ≈ wenige KB
(375 ints + Referenzen, Bilder nicht kopiert); `deleteFrame`-Eintrag ≈
3 × 375 ints + 375-Cache ≈ 12–24 KB Lua-Tabelle. Gesamt < ~100 KB —
unkritisch.

## Konsequenzen
- **Positiv**: robust, zwei Codepfade, sitzungslokal (kein Speicherformat
  berührt — `frames.json` bleibt bei `"1.1"`). Headless voll abgedeckt
  (V1–V11, V22/V23).
- **Negativ**: der Clear-Eintrag trägt 375 Zell-Records; akzeptiert, weil
  es nur ints + Referenzen sind.
- **Lebenszyklus**: `EditorRoom:clearUndoHistory()` (→ `undoHistory:clear()`
  + `shakeDetector:reset()` + `shiftRun = nil`) läuft in `handleLoadSuccess`
  und überall, wo zu `SelectionRoom` gewechselt wird
  (`handleSaveAndExit`-Callback, `handleLoadError`) — SC-008: Verlauf nach
  Bildwechsel / Editor-Verlassen garantiert leer.
- **Zwei Implementierungs-Fallen** (headless-testverifiziert, hier
  festgehalten, damit sie nicht erneut abgeleitet werden müssen):
  1. **Stale Run-State über Bildwechsel.** `shiftRun` (der offene
     Verschiebe-Eintrag) muss in **allen** Load-/Save-Pfaden auf `nil`
     zurück, sonst koalesziert ein Shift im neu geladenen Bild in einen
     Eintrag des alten Bildes. → `shiftRun = nil` zusätzlich in
     `handleLoadError` / `handleLoadSuccess` / `handleSaveAndExit`-Callback
     und in `clearUndoHistory()`.
  2. **Index- vs. Bild-Restore.** Ein bedingungsloses
     `registerTile(prevImage)` beim Undo erzeugt mit der Bild-Identitäts-
     Semantik des Mocks (und potenziell am Gerät) falsche Indizes. →
     `resolvePrevIndex` bevorzugt den index-stabilen `prevPosIndex` und
     re-registriert das Bild nur als Sicherheitsnetz.
- **Test-Nachtrag**: `UndoPrompt.currentLabel()` (Accessor) für die
  Label-Prüfung; Accelerometer-Mock in `tests/headless_tests.lua`
  (`startAccelerometer`/`stopAccelerometer`/`readAccelerometer` +
  `accelXYZ`/`accelRunning`/Zähler, ADR-044 / research.md R9).
- 494 Assertions grün, `pdc` sauber, `buildNumber` 32.

## Offen
- RAM-Grobabschätzung am Gerät gegenprüfen (Task T042, Qualitätsszenario
  „Speicher", Kap. 10).

## Related
- [ADR-044: Schüttel-Erkennung](ADR-044-Schuettel-Erkennung-Accelerometer.md)
- [ADR-046: Modaler Undo-Dialog](ADR-046-Modaler-Undo-Dialog.md)
- [ADR-043: Pixel-Verschiebung pro Tile](ADR-043-Pixel-Verschiebung-pro-Tile.md) (liefert die zurücknehmbare Shift-Operation)
- [ADR-041: Compositing-Cache und Frame-Verwaltung](ADR-041-Compositing-Cache-und-Frame-Verwaltung.md) (`frameLayers` = Wahrheit, `frames` = Cache; `apply*` hält beide im Gleichschritt)
- [ADR-039: Feste 3-Ebenen-Struktur](ADR-039-Feste-3-Ebenen-Struktur.md)
- [specs/011-shake-to-undo/research.md: R2, R3, R4, R7](../../specs/011-shake-to-undo/research.md)
- [specs/011-shake-to-undo/data-model.md](../../specs/011-shake-to-undo/data-model.md)
