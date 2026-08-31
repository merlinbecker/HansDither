# ADR-041: Ebenen-Compositing als flacher Cache; US4 = Frame-Verwaltung

## Status
✅ **Umgesetzt** (Spec 010, US3/US4) – `Source/LayerModel.lua`
(`compositeToFlat`), `Source/EditorRoom.lua`,
`Source/FrameManagementView.lua`

## Kontext
Der EditorRoom zeichnet seinen Frame ueber ein `playdate.graphics.tilemap`,
das ein **flaches 375er-Array** von Tile-Indizes erwartet
(`imageData.frames[currentFrame]`). Mit 3 Ebenen je Frame (AD-039) stellt
sich die Frage, wie „alle Ebenen sichtbar“ (research.md R3) im Tile View
realisiert wird, ohne den Renderpfad umzubauen.

Zweitens: die 2. Klarstellungsrunde sah eine Layer View + Animation Layer
View vor. Mit festen 3 Ebenen (AD-039) hat die Layer View keinen Zweck
mehr. Der Projektinhaber stellte klar (3. Runde): US4 wird eine
**Frame-Verwaltung** — Frames anordnen + loeschen, damit die Animation
steuerbar bleibt.

## Entscheidungs-Treiber
- **Constitution I/IV**: den bestehenden Tilemap-Renderpfad
  wiederverwenden statt einen Compositing-Motor / mehrere Tilemaps
  einzufuehren.
- Editier-Pfade des EditorRoom (`setCell`, `applyTileEdits`,
  `tickForward`, `clearCurrentFrame`, `buildZoomContext`) schreiben/lesen
  bisher direkt `imageData.frames` — muessen auf die aktive Ebene
  umgelenkt werden, sonst gehen Mehr-Ebenen-Edits beim Speichern verloren.
- B + Kurbel rueckwaerts im Tile View war bisher ein bewusster No-op
  („aeusserste Zoomstufe“) — freier Einstiegskanal.

## Optionen (Compositing)

| Option | Vorteile | Nachteile |
|--------|----------|-----------|
| **A: `imageData.frames` = abgeleiteter flacher Cache; pro Zelle gewinnt die oberste Ebene mit `positions[c] ~= 0`, sonst Weiss-Tile; nach jeder Mutation neu kompositiert** | Renderpfad unveraendert; billig (ein 375er-Array); Single-Layer-Bild = Identitaet | „oberste Ebene je Zelle gewinnt“ ist grob — kein pixel-genaues Durchscheinen mehrerer Ebenen in EINER Zelle |
| B: pro Zelle ein zusammengefuehrtes Tile bauen (`compositeToTiles`) | WYSIWYG bis auf den Pixel | registriert bei jedem Edit neue Tiles; Perf-Kosten; nur bei mehrfach belegten Zellen ueberhaupt anders |

## Entscheidung
**Compositing: Option A.** `LayerModel.compositeToFlat(entry)` erzeugt das
flache Array; `EditorRoom` regeneriert es je editierter Zelle
(`recompositeCell`) bzw. ganz (`recompositeCurrentFrame`) nach jeder
Ebenen-Mutation. Alle Editier-Pfade schreiben ueber
`writeActiveLayerPosition` ausschliesslich in
`frameLayers[currentFrame].layers[activeLayer]`. `tickForward` dupliziert
per `LayerModel.cloneFrameLayers` (tiefe Kopie aller 3 Ebenen).
`compositeToTiles` (Option B) ist implementiert, aber **nicht im
Renderpfad verdrahtet** — fuer die aktuelle Darstellung nicht noetig
(Phase-7-Aufgabe T053).

**US4: `Source/FrameManagementView.lua`** (neuer Room). Einstieg aus dem
Tile View per Halten B + Kurbel rueckwaerts (`EditorRoom.handleCrank`,
`zoomTickAccu <= -ZOOM_TICK_THRESHOLD`). Steuerung:

- D-Pad hoch/runter: Listen-Cursor (hebt Markierung auf)
- A: Frame markieren; **A erneut** auf dem markierten Frame: loeschen
  (abgelehnt bei nur 1 Frame)
- Links/Rechts: markierten Frame eine Position frueher/spaeter (geklemmt);
  `frameLayers[a]↔[b]` und `frames[a]↔[b]` im Gleichschritt
- B loslassen: `switchRoom(editorRoom)`, `imageData.returnFrame` gesetzt

`EditorRoom:entered()` liest `returnFrame`, klemmt `currentFrame` +
`activeLayer` in die evtl. kuerzere/umgeordnete Sequenz.

### Begruendung
- **„Zweiter A-Druck loescht“ statt „B loescht“** (abweichend von der
  1.-Runde-Klarstellung „B bestaetigt Loeschen“): B wird die ganze View
  ueber **gehalten** — die Halte-Geste haelt den Nutzer in der View. B
  kann daher nicht zugleich „loeschen“ bedeuten. Zwei A-Druecke sind
  dieselbe Zwei-Schritt-Sicherung, nur mit A statt B.
- FR-024 („Navigations-Schleifen verhindern“) ist trivial erfuellt: eine
  Geste rein, eine raus, keine Hierarchie.

### Konsequenzen
- **Positiv**: Renderpfad unangetastet; Single-Layer-Bilder verhalten
  sich exakt wie vorher (Composite = Identitaet).
- **Negativ**: `imageData.frames` ist jetzt ein abgeleiteter Wert, den
  **jede** Ebenen-Mutation neu berechnen muss — vergisst das ein neuer
  Pfad, gehen Mehr-Ebenen-Edits beim Speichern still verloren (durch
  Tests abgesichert).
- `compositeToTiles` bleibt vorerst ungenutzter, getesteter Code
  (Phase-7-Verdrahtung).

## Related
- [ADR-039: Feste 3-Ebenen-Struktur](ADR-039-Feste-3-Ebenen-Struktur.md)
- [ADR-040: Pixel-Transparenz im Tile](ADR-040-Pixel-Transparenz-im-Tile.md)
- [ADR-032: Reset Frame statt Delete Frame im Menue](ADR-032-Reset-Frame-statt-Delete-Frame-im-Menue.md)
- [specs/010-layer-management-with-transparency/research.md: R3, R5](../../specs/010-layer-management-with-transparency/research.md)
