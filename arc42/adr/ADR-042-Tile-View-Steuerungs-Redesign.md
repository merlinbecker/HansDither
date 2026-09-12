# ADR-042: Tile-View-Steuerungs-Redesign — B + D-Pad statt Kurbel, Kurbel = Tile-Picker

## Status
✅ **Umgesetzt** (Spec 010, 4. Klarstellungsrunde aus dem Hardware-Test) –
`Source/EditorRoom.lua`, `tests/headless_tests.lua`.
**10. Runde (2026-09-07)**: Picker oeffnet erst nach voller Kurbelumdrehung
(`pickerArmDegrees`) — siehe *Nachtrag (10. Runde)* unten.

## Kontext
Die 3. Runde legte fest: Ebene wechseln = Hoch/Runter halten + volle
Kurbelumdrehung (AD-041/US3); Frame wechseln = volle Kurbelumdrehung ohne
Modifier (bestehendes Verhalten seit AD-019).

Der Test auf echter Hardware zeigte drei Probleme:

1. Eine **volle 360°-Umdrehung fuer einen einzigen Ebenenschritt** ist
   langsam und leicht zu ueberdrehen.
2. Eine volle Umdrehung fuer **einen Frame** ist unpraezise — die
   Animation Frame fuer Frame durchzugehen ist muehsam.
3. Die Kurbel macht im Tile View **sonst nichts**, waehrend die
   Kachelauswahl weiterhin bedeutet: Cursor auf eine vorhandene Kachel
   fahren und mit B pipettieren.

## Entscheidungs-Treiber
- **Ein Druck = ein Schritt** fuer Ebene und Frame (keine
  Umdrehungszaehlung, kein Ueberdrehen).
- Die freie Kurbel sinnvoll belegen, ohne einen dritten Kurbel-Modus
  einzufuehren.
- **Contract CR-01**: pro `update()` genau **eine** Crank-Lese-API — nie
  `getCrankChange()` und `getCrankTicks()` im selben Frame.
- `getCrankTicks` ist in dieser Codebase zustandsbehaftet (siehe
  `EditorRoom:update()` — Ticks werden nach Operationen bewusst
  verworfen); der Headless-Mock liefert einen festen Tickwert und kann
  einen „ticks-per-revolution“-Umschaltbug **nicht** fangen.
- **B + Kurbel vor/zurueck** (Zoomkette / Frame-Verwaltung, AD-019/AD-041)
  ist bewaehrt und bleibt unangetastet.

## Optionen

| Option | Vorteile | Nachteile |
|--------|----------|-----------|
| **A: Ebene/Frame auf B + D-Pad; freie Kurbel = Tile-Picker ueber die referenzierten Kacheln** | Ein Druck = ein Schritt; Kurbel bekommt eine echte Aufgabe; B + Kurbel unveraendert | B ist staerker ueberladen (Pipette, Ebene, Frame, Zoom, Frame-Verwaltung) — muss sauber entflochten werden |
| B: Ebene/Frame auf der Kurbel lassen, Modifier fuer den Picker | wenig Aenderung | dritter Kurbel-Modus; die Kurbel war ja gerade der unangenehme Teil |
| C: Tick-basierter Picker via zweitem `getCrankTicks(tpr)` | „rastet“ pro Kachel | zweite Tick-API-Aufrufstelle, zustandsbehaftet; Mock blind → Hardware-Risiko |

## Entscheidung
**Option A.**

**Tile View — Steuerung:**

| Eingabe | Wirkung |
|---------|---------|
| D-Pad (ohne B) | Kachel-Cursor bewegen (unveraendert) |
| **B halten + Hoch / Runter** | aktive Ebene +1 / -1 (Wrap 1..3) |
| **B halten + Links / Rechts** | Frame zurueck / vor; **B + Rechts am letzten Frame** haengt einen neuen Frame an (tiefe Kopie — die einzige Frame-Anlage-Geste) |
| **Kurbel (ohne B)** | Tile-Picker-Overlay: oeffnet erst nach einer **vollen Umdrehung** (≥ 360° netto, vorzeichenbehaftet, beliebige Richtung — 10. Runde); danach je ~30° Netto-Drehung eine Kachel weiter durch die **referenzierten** Tile-Indizes, Wrap am Ende; Overlay blendet ~1,5 s nach der letzten Drehung aus |
| B + Kurbel vorwaerts / rueckwaerts | Zoomkette / Frame-Verwaltung (**unveraendert**, Tick-basiert) |
| kurzer B-Tipp (ohne D-Pad/Kurbel dazwischen) | Pipette; Bauchbinde zeigt kurz „Tile N picked“ |

**Umsetzungsdetails:**

- `handleCrank()` B-Zweig: unveraendert `getCrankTicks(4)`. Ohne-B-Zweig:
  `getCrankChange()`. CR-01 bleibt gewahrt, da If/Else. **10. Runde
  (2026-09-07):** der Ohne-B-Zweig hat jetzt **zwei** vorzeichenbehaftete
  Grad-Akkumulatoren, gewaehlt ueber `pickerVisible`: solange der Picker
  **zu** ist, sammelt `pickerArmDegrees`, bis `|·| ≥ PICKER_ACTIVATE_DEGREES`
  (360°) — dann oeffnet der Picker (die Oeffnungsdrehung waehlt **keine**
  Kachel). Vor-/Zurueck-Ruetteln hebt sich gegen 0 auf; eine ganze Drehung
  in **beliebiger** Richtung oeffnet (der Picker hat keinen Kurbel-Indikator,
  also nicht auf eine Richtung festlegen — anders als die richtungs­gebundene
  `SelectionRoom`-Sync-Geste bei 720°). Solange der Picker **offen** ist,
  macht `crankAccumDegrees` unveraendert die 30°/Kachel-Schrittung
  (`PICKER_DEGREES_PER_TILE = 30`). `pickerArmDegrees` wird bei Aktivierung,
  bei der 1,5-s-Auto-Ausblendung, bei jedem B-Halten und in `entered()` auf
  0 gesetzt.
- `referencedTileIndices()` scannt die **Ebenen-Positionen**
  (`frameLayers[*].layers[*].positions`, `0` uebersprungen) — **nicht** den
  flachen Composite-Cache `imageData.frames` und **nicht**
  `imagetable:getLength()`. Der Composite-Cache behaelt je Zelle nur die
  oberste Kachel (`compositeToFlat`); eine Kachel, die nur auf einer
  verdeckten Ebene liegt, fiele daraus heraus und koennte mitten in der
  Sitzung verschwinden, sobald eine hoehere Ebene die Zelle abdeckt.
  `imagetable:getLength()` ist ebenfalls falsch (Sitzungs-Edits haengen
  neue Tiles an und verwaisen alte; erst das Speichern
  `pruneUnusedTilesLayered` raeumt auf). **Kurbeln auf Kachel 1 muss
  `activeTile` wirklich auf `nil` setzen** (Abwahl/Toggle-Modus) — nicht
  `(picked == 1) and nil or picked` (Lua: ergibt immer `picked`), sondern ein
  explizites `if`.
  `EditorRoom:buildPauseMenuImage` (Pause-/Kontext-Ansicht, CR-06) nutzt seit
  Spec 010 **denselben** `referencedTileIndices()`-Scan — die frueher dort
  verwendete Composite-Cache-Iteration hat verdeckte Kacheln in „Tiles: N“
  untergezaehlt.
- **Picker-Cache + Abwahl-Slot:** `stepTilePicker` kann bei schnellem Kurbeln
  ~12x je `update()` feuern, dazu einmal je `draw()`. `pickerList()`
  memoisiert `referencedTileIndices()` (`pickerTileList`; invalidiert bei jeder
  Tile-Mutation via `recompositeCell`/`recompositeCurrentFrame`/`entered()`)
  **und haengt Index 1 vorne an** — der Abwahl-/Toggle-Slot muss auch dann
  erreichbar sein, wenn keine Zelle Kachel 1 referenziert (sonst
  Ein-Element-Liste ohne Rueckweg). `referencedTileIndices()` selbst hat
  **keine** Beigabe — sonst zaehlte `buildPauseMenuImage` bei solchen Bildern
  eine Kachel zu viel; die Pause-Ansicht nutzt den un-erweiterten Scan direkt.
- **`bNavConsumed`** wird in `bDpadNav()` gesetzt und **nur** in
  `BButtonDown`/`BButtonUp` zurueckgesetzt — nie aus dem Live-Tastenzustand
  beim Release abgeleitet (der Nutzer kann die Richtungstaste vor B
  loslassen). Verhindert, dass der B-Release nach B + D-Pad zusaetzlich
  die Pipette ausloest.
- Der Key-Repeat-Callback von `startMove` prueft `buttonIsPressed(B)` und
  friert den Cursor ein, falls B **nach** der schon gehaltenen
  Richtungstaste dazukommt (statt gegen die Navigation zu laufen).
- Tile-Picker-Overlay + „Tile N picked“-Hinweis folgen dem etablierten
  Timeout-Muster (gecachtes Sichtbarkeits-Flag, Uebergangs-`needsRedraw`
  in `update()` — wie `bauchbindeVisible`/`statusMessage`), sonst
  verschwaenden sie bei fehlender weiterer Eingabe nie.

### Konsequenzen
- **Positiv**: Ebene/Frame praezise (ein Druck = ein Schritt); die Kurbel
  hat im Tile View endlich eine Aufgabe; B + Kurbel (Zoom/Frame-Verwaltung)
  und die Zoom-View-Geste „B + Pfeil = Pixel-Shift“ (FR-001) bleiben
  unberuehrt — verschiedene Raeume, kein Konflikt.
- **Negativ**: B ist im Tile View stark ueberladen; die Entflechtung haengt
  an `bUsedForZoom` (Kurbel) **und** `bNavConsumed` (D-Pad). Ein neuer
  B-Pfad muss beide Flags bedenken.
- **Entfaellt**: Frame-Cyclen per Kurbel-Volldrehung (`crankAccumDegrees`
  360°-Schwelle) und Ebenen-Cyclen per Hoch/Runter + Kurbel
  (`layerAccumDegrees`, entfernt). Betrifft AD-019 (fuer den EditorRoom),
  AD-041/US3 und R3/R4/R9.
- Headless: die alten „Up/Down + Crank“-Ebenen-Tests und die
  „Crank-Volldrehung = Frame“-Tests wurden auf B + D-Pad umgeschrieben;
  neue Abschnitte fuer Tile-Picker (Schritt/Wrap/Auto-Ausblenden, verdeckte
  Kachel, Cache-Invalidierung, echte Abwahl, Bild ohne Zelle=1) und die
  Pipetten-Meldung. Alle Assertions gruen, `pdc` sauber, buildNumber 27.

## Nachtrag (10. Runde, 2026-09-07) — volle Umdrehung zum Oeffnen

**Trigger**: Hardware-Test des ausgelieferten 8./9.-Runden-Builds. Der Picker
oeffnete bei der **kleinsten** Kurbelbewegung (`if change ~= 0 then pickerVisible
= true`). Beim Ein- oder Auspacken der Kurbel — oder bei versehentlichem
Antippen — poppte das Overlay staendig auf und verdeckte die Arbeit.

**Entscheidung**: Der Picker erscheint erst nach einer **vollen Umdrehung**
(`PICKER_ACTIVATE_DEGREES = 360`, vorzeichenbehafteter `pickerArmDegrees`,
`math.abs(...) >= 360`, beliebige Richtung). Ist er offen, gilt die 30°/Kachel-
Schrittung unveraendert — man waehlt fein aus und kann die Kurbel danach wieder
einpacken, ohne das Overlay erneut auszuloesen; nach der Auto-Ausblendung
braucht es wieder eine volle Umdrehung. **B + Kurbel** (Zoomkette / Frame-Room,
Tick-basiert) ist unberuehrt. Konsistent mit der `PixelRoom`-Rotation (360°-
Wrap) und der `SelectionRoom`-Sync-Geste (720°), aber richtungsneutral.

**Alternativen verworfen**: (a) nur eine 20°-Totzone — zu klein, ein beherzter
Anstupser reicht immer noch; (b) `math.max(0, ...)` nur im Uhrzeigersinn wie
`SelectionRoom` — die Sync-Geste hat einen Crank-Indikator, der Picker nicht,
also darf eine volle Gegendrehung nicht wirkungslos + rueckmeldungsfrei bleiben.

**Tests**: `tests/headless_tests.lua` — Ruetteln (+90/−90 ×4, Summe 0) oeffnet
nicht; 270° Teildrehung oeffnet nicht; +90° weiter (Summe 360°) oeffnet ohne
Kachelauswahl; die bestehenden Picker-Abschnitte oeffnen jetzt per
`openPickerWithFullTurn()` vor der 30°-Schrittung. Alle Assertions gruen, `pdc`
sauber, buildNumber 41.

**Am Geraet gegenzupruefen (T094)**: (1) eine langsame volle Umdrehung oeffnet
zuverlaessig (kein Stottern durch 0-Frames bei sehr langsamem Drehen); (2)
langsamer, gleichgerichteter Dauer-Drift oeffnet **nicht** faelschlich; (3) die
volle Kurbeldrehung triggert **keinen** Fehl-Shake (Spec 011 Undo-Prompt),
waehrend der Picker geoeffnet wird.

## Offen (Phase 7, Simulator/Hardware)
- Haptik der 30°/Kachel-Schwelle auf echter Kurbel (evtl. nachjustieren).
- Overlay-Layout (7er-Filmstreifen, mittig) am Geraet gegenpruefen.
- `pickerList()`-Cache am Geraet gegen die 60-FPS-Grenze pruefen (T053);
  bei Bedarf zusaetzlich beim Overlay-Ausblenden freigeben.

## Related
- [arc42 §9.19 AD-019: Crank steuert Animationsframes, B+Crank die Zoomstufen](../09-architekturentscheidungen.md)
- [ADR-041: Compositing-Cache und Frame-Verwaltung](ADR-041-Compositing-Cache-und-Frame-Verwaltung.md)
- [ADR-039: Feste 3-Ebenen-Struktur](ADR-039-Feste-3-Ebenen-Struktur.md)
- [specs/010-layer-management-with-transparency/research.md: R10](../../specs/010-layer-management-with-transparency/research.md)
- [specs/010-layer-management-with-transparency/spec.md: Clarifications 4. Runde, FR-013/014/016, FR-025..027](../../specs/010-layer-management-with-transparency/spec.md)
