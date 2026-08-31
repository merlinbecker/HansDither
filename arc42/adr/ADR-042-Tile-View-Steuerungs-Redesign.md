# ADR-042: Tile-View-Steuerungs-Redesign — B + D-Pad statt Kurbel, Kurbel = Tile-Picker

## Status
✅ **Umgesetzt** (Spec 010, 4. Klarstellungsrunde aus dem Hardware-Test) –
`Source/EditorRoom.lua`, `tests/headless_tests.lua`

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
| **Kurbel (ohne B)** | Tile-Picker-Overlay: je ~30° Netto-Drehung eine Kachel weiter durch die **referenzierten** Tile-Indizes, Wrap am Ende; Overlay blendet ~1,5 s nach der letzten Drehung aus |
| B + Kurbel vorwaerts / rueckwaerts | Zoomkette / Frame-Verwaltung (**unveraendert**, Tick-basiert) |
| kurzer B-Tipp (ohne D-Pad/Kurbel dazwischen) | Pipette; Bauchbinde zeigt kurz „Tile N picked“ |

**Umsetzungsdetails:**

- `handleCrank()` B-Zweig: unveraendert `getCrankTicks(4)`. Ohne-B-Zweig:
  `getCrankChange()` + `crankAccumDegrees`-Akkumulator mit **Sub-360°-
  Schwelle** (`PICKER_DEGREES_PER_TILE = 30`). CR-01 bleibt gewahrt, da
  If/Else.
- `referencedTileIndices()` scannt `imageData.frames` (die flachen
  Composite-Caches) wie `EditorRoom:buildPauseMenuImage` (CR-06) — **nicht**
  `imagetable:getLength()`. Sitzungs-Edits haengen neue Tiles an und
  verwaisen alte; erst das Speichern (`pruneUnusedTilesLayered`) raeumt
  auf. Index 1 (Weiss) ist immer referenziert → „keine Auswahl“
  (`activeTile = nil`, Toggle-Modus) ist stets erreichbar, konsistent zur
  Pipette.
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
  neue Abschnitte fuer Tile-Picker (Schritt/Wrap/Auto-Ausblenden) und die
  Pipetten-Meldung. 356 Assertions gruen, `pdc` sauber, buildNumber 24.

## Offen (Phase 7, Simulator/Hardware)
- Haptik der 30°/Kachel-Schwelle auf echter Kurbel (evtl. nachjustieren).
- Overlay-Layout (7er-Filmstreifen, mittig) am Geraet gegenpruefen.

## Related
- [arc42 §9.19 AD-019: Crank steuert Animationsframes, B+Crank die Zoomstufen](../09-architekturentscheidungen.md)
- [ADR-041: Compositing-Cache und Frame-Verwaltung](ADR-041-Compositing-Cache-und-Frame-Verwaltung.md)
- [ADR-039: Feste 3-Ebenen-Struktur](ADR-039-Feste-3-Ebenen-Struktur.md)
- [specs/010-layer-management-with-transparency/research.md: R10](../../specs/010-layer-management-with-transparency/research.md)
- [specs/010-layer-management-with-transparency/spec.md: Clarifications 4. Runde, FR-013/014/016, FR-025..027](../../specs/010-layer-management-with-transparency/spec.md)
