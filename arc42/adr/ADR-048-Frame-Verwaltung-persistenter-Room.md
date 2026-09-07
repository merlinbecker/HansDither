# ADR-048: Frame-Verwaltung als dauerhafter Room mit Thumbnail-Raster

## Status
✅ **Umgesetzt** (Spec 010, 8. Runde aus dem Hardware-Test; 9. Runde aus
`/speckit-clarify`) — `Source/FrameManagementView.lua` (neu geschrieben),
`Source/UndoHistory.lua` (`remapFrames` + `{inserted}`), `Source/EditorRoom.lua`
(`onFramesReindexed` nimmt `{inserted}`).

## Kontext
Spec 010 US4 (3. Runde) fuehrte die `FrameManagementView` als modalen
„B halten"-List-View ein: Eintritt aus dem Tile View mit B + Kurbel
rueckwaerts, Verbleib nur solange B gehalten, Verlassen durch B-Loslassen,
Loeschen per zweitem A-Druck auf dem markierten Frame.

Der Hardware-Test zeigte zwei Probleme:

1. **B-Timing-Sackgasse.** Kommt der letzte Kurbel-Tick der Eintrittsgeste
   erst nach dem B-Release an, ist der einzige Ausgang (gehalten → los) nie
   mehr ausloesbar. Commit `c2cbb6f` flickte das mit einem „erneuter B-Tipp"-
   Notausgang — fragil.
2. **Unbequemes Umsortieren.** Mit dauernd gehaltenem B laesst sich in Ruhe
   nichts anordnen; der Listen-View passt nicht zum „mehrere Frames
   umstellen"-Workflow.

`/speckit-clarify` (9. Runde) legte fest: die Steuerung soll sich wie im
Bild-Auswahl-Room (`SelectionRoom`) verhalten — plus der Zusatz
„Verschieben" — und Loeschen soll ueber das Kontextmenue laufen.

## Entscheidungs-Treiber
- Constitution I: `playdate.ui.gridview` ist die SDK-Primitive fuer Raster
  (schon in `SelectionRoom` und `PixelRoom` im Einsatz).
- Constitution IV: bewaehrtes `SelectionRoom`-Muster wiederverwenden (Raster,
  D-Pad-Navigation, System-Menue fuer destruktive Aktionen,
  `confirmingDelete`-Bestaetigungsdialog), nicht neu erfinden.
- Der Room-Exit muss deterministisch sein, ohne auf Kurbel-Dezeleration zu
  spekulieren — und headless testbar.
- Spec 011: jede Frame-Umnummerierung muss die `UndoHistory` mitziehen
  (`onFramesReindexed`), sonst zeigt ein spaeteres Undo in den falschen Frame.

## Entscheidung
`FrameManagementView` ist ein **dauerhafter Room** im `switchRoom`-Schema.

- **Eintritt** unveraendert: `EditorRoom:handleCrank()` erkennt B gehalten +
  Kurbel rueckwaerts → `openFrameManagementView()` → `switchRoom`.
- **Verlassen: B + Kurbel VORWAERTS**, ausgewertet **erst nachdem B seit
  `entered()` einmal losgelassen wurde** (`bReleasedSinceEnter`). `update()`
  liest pro Frame nur `getCrankTicks(4)` (CR-01/AD-047) in `crankAccu`; bei
  nicht gehaltenem B → `bReleasedSinceEnter = true`, `crankAccu = 0`; bei
  gehaltenem B **und** armiert **und** `crankAccu >= EXIT_TICK_THRESHOLD` →
  `returnToEditor()` (setzt `imageData.returnFrame`).
- **Raster**: `playdate.ui.gridview` (3 Spalten); `thumbCache[pos]` je Frame
  aus `imageData.frames[f]` durch ein `playdate.graphics.tilemap` in ein Bild
  (einmal in `entered()`; Reorder tauscht nur zwei Cache-Eintraege,
  Delete/Duplicate `table.remove`/`insert`).
- **A** ist ein reiner Markieren/Aufheben-Umschalter (`marked = (marked ==
  cursor) and nil or cursor`) — **loescht nie**.
- **D-Pad**: ohne Markierung Cursor-Navigation (hoch/runter = ±NUM_COLS); mit
  Markierung verschiebt es den markierten Frame in der Sequenz — Links/Rechts
  = ein `swapFrames` + ein `onFramesReindexed({swapped})`, Hoch/Runter = bis
  zu NUM_COLS solche **sequenziellen Nachbar-Swaps** hintereinander
  (`frameLayers` + `frames` + `thumbCache` im Gleichschritt).
- **System-Menue** (wie `SelectionRoom:buildSystemMenu`): „delete frame" →
  No-op bei 1 Frame, sonst `confirmingDelete` + A/B-Dialog nach dem
  `SelectionRoom.drawConfirmDeleteDialog`-Muster; (A) fuehrt tiefe Kopie +
  `table.remove` (beide Arrays + `thumbCache`) + `onFramesReindexed({removed})`
  + `EditorRoom:recordDeleteFrame` (Spec 011, Reihenfolge wie zuvor) aus,
  (B) bricht ab. „duplicate frame" → No-op bei 12 Frames, sonst tiefe Kopie
  an `cursor+1` + `onFramesReindexed({inserted})`.
- **`UndoHistory:remapFrames`** bekommt den `{inserted = i}`-Fall: Eintraege
  mit `frameIndex`/`index` `>= i` ruecken um eins nach oben — der Spiegel von
  `{removed}`; nichts wird verworfen.
- **Schuetteln bleibt inaktiv** — Spec 011 FR-010 schliesst die
  Frame-Verwaltung namentlich aus; der Room startet den Accelerometer nicht.
  Der R6-Grund („B ist durch die Halte-Geste belegt") ist mit dem
  persistenten Room hinfaellig, das Ergebnis nicht. Schuetteln im Frame-Room
  zu aktivieren waere eine Spec-011-FR-010-Aenderung, hier ausserhalb Scope.

## Konsequenzen
- **Weniger Zustand:** `bWasHeld` und der B-Loslassen-Exit-Automat entfallen;
  die c2cbb6f-Sackgasse ist damit verschwunden.
- **Kein neues Reindex-Format fuer Reorder:** die Umordnung bleibt eine Folge
  von `{swapped}`-Nachbar-Schritten, die `UndoHistory` schon beherrscht.
  Nur „duplicate frame" bringt `{inserted}` neu.
- **Kein Room-eigenes „add frame":** „Frame anhaengen" bleibt die
  Tile-View-Geste B + Rechts auf dem letzten Frame (FR-016).
- **Persistenz unveraendert:** Frame-Reihenfolge/-Anzahl round-trippen wie
  bisher ueber v1.1.
- Headless: `FrameManagementView`-Abschnitte neu geschrieben (A-Toggle,
  Raster-Navigation, Hoch/Runter = 3 `{swapped}`, Menue-Loeschen mit
  Bestaetigung, Menue-Duplizieren, 12er-Grenze, armierter Exit);
  `remapFrames({inserted})` als Unit-Test; V9/V23b/F4/V21 auf den Menue-Pfad
  bzw. das neue Modell umgestellt und gruen. buildNumber 39 → 40, `pdc`
  sauber.
- **Offen (Geraet, T094):** `thumbCache`-Aufbau-Zeit fuer 12 Frames < 1
  Frame; kein Fehl-Exit durch Kurbel-Nachlauf der Eintrittsgeste (R-32).

## Verworfene Alternativen
- *B-Loslassen-Exit als zweiten Ausgang behalten* — reintroduziert genau die
  c2cbb6f-Fragilitaet, die diese Runde beseitigt.
- *Frischer Tick-Akkumulator ohne B-Merker* — setzt voraus, dass die Hand die
  Kurbel sofort stoppt; auf echter Hardware falsch.
- *Loeschen weiter per zweitem A-Druck* — die 9.-Runde-Klarstellung will die
  `SelectionRoom`-Analogie (destruktive Aktionen im Menue, mit Bestaetigung).
- *„Hoch/Runter" als ein `swapFrames(from, from±NUM_COLS)`* — ordnet die
  dazwischen liegenden Frames falsch und erzeugt ein `{swapped}`-Paar, das
  `remapFrames` fehlinterpretiert.

## Bezug
- Spec: `specs/010-layer-management-with-transparency/spec.md` — Clarifications
  8./9. Runde; FR-018..FR-022, SC-004; Key Entities „Frame Management Room".
- Plan/Contracts: `plan.md` „Eighth-Round Update" + Ninth-Round-Callout;
  `contracts/frame-room-and-overlay.md`; `research.md` R11/R12.
- arc42: §9.36; Kap. 5 (FrameManagementView-Zeile), §6.17, Kap. 8
  („Symmetrische B+Kurbel-Room-Gesten mit Arming"), QS-25/QS-26, R-32/R-33.
- Verwandt: AD-041 (US4 = Frame-Verwaltung), AD-042 (Eintrittsgeste),
  AD-047 (CR-01), Spec 011 AD-044/AD-045 (`recordDeleteFrame`,
  `remapFrames`, FR-010).
