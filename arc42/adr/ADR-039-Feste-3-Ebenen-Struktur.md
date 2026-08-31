# ADR-039: Feste 3-Ebenen-Struktur je Frame ohne Add/Delete

## Status
✅ **Umgesetzt** (Spec 010, Projektinhaber-Klarstellung 3. Runde) – `Source/LayerModel.lua`, `Source/ImageStoreCodec.lua`

## Kontext
Spec 010 fuehrt Ebenen ein. Die 2. Klarstellungsrunde legte ein *Maximum*
von 3 Ebenen fest (Ebene 1 Pflicht, 2–3 optional, Add/Delete ueber eine
Layer View). Bei der Umsetzung fiel auf: die Spec beschreibt **nur das
Loeschen** von Ebenen — es gibt keine spezifizierte Geste, um Ebene 2 oder
3 ueberhaupt anzulegen. Ein frisch geladenes Ein-Ebenen-Bild bliebe damit
fuer immer einlagig; die ganze Mehr-Ebenen-Funktion waere im Editor nicht
erreichbar.

Die 3. Klarstellungsrunde (2026-08-31) loeste das auf: Ebenen sind eine
**feste Struktur von genau 3 pro Frame**, analog zur harten Grenze von 12
Animationsframes.

## Entscheidungs-Treiber
- **Kein „Add Layer“-Gestenloch**: ohne Add/Delete entfaellt die Frage,
  welche knappe D-Pad/A/B/Crank-Kombination eine Ebene erzeugt.
- **Constitution IV**: harte, einfache Grenzen sind ausdruecklich
  erwuenscht (wie MAX_FRAMES = 12); kein Add/Delete-Zustandsautomat, kein
  „aktive Ebene wurde geloescht“-Sonderfall, keine Layer View.
- **Rueckwaertskompatibilitaet**: Alt-Bilder haben eine flache Ebene.
- **Speicher**: 12 Frames × 3 Ebenen × 375 Tile-Indizes ist unkritisch.

## Optionen

| Option | Vorteile | Nachteile |
|--------|----------|-----------|
| **A: genau 3 Ebenen, immer; kein Add/Delete; leere obere Ebenen auf Platte weggelassen** | Kein Add-Geste noetig, minimaler Zustand, `activeLayer` = reiner 1..3-Cursor, Alt-Bilder bleiben kompakt | Nutzer kann die Ebenenzahl nicht reduzieren (aber: leere Ebene kostet nichts) |
| B: 1–3 optionale Ebenen mit Layer View (2. Runde) | flexibel | braucht Add-Geste (unspezifiziert), Delete-Active-Handling, eigene View — viel UI/Zustand ohne klaren Workflow-Gewinn |
| C: unbegrenzt viele Ebenen | maximal flexibel | Performance unvorhersehbar, Crank-Cyclen wird zaeh, widerspricht Constitution IV |

## Entscheidung
**Option A.** `LayerModel.LAYER_COUNT = 3`. `newFrameLayersFromFlat`
liefert immer 3 Ebenen (Basis + 2 leere), `padTo3()` fuellt/stutzt auf
genau 3, `validate()` verlangt exakt 3 (layerIndex 0..2) und keine
„absent“ (0) auf Ebene 1. `addLayer`/`deleteLayer` sind entfernt.
`ImageStoreCodec.newLoadOperation` bringt jeden Frame nach dem Parsen per
`padTo3()` auf 3; `createFramesTableV11` schreibt nur bis zur hoechsten
Ebene mit Inhalt (1–3 Eintraege).

### Begruendung
1. Beseitigt das reale Blockerproblem (keine Ebene-2-Erzeugungsgeste),
   ohne eine zu erfinden.
2. Folgt exakt dem etablierten 12-Frame-Muster (Constitution IV).
3. Frame-Wechsel aendert die Ebenenzahl nie → der aktive Index (1..3)
   existiert immer, kein Wrap noetig (nur ein defensives `clampActive`
   fuer defekte Daten bleibt).

### Konsequenzen
- **Positiv**: deutlich weniger Zustand; `imageData.frames` bleibt ein
  einfacher abgeleiteter Cache (AD-041); Alt-Bilder unveraendert kompakt.
- **Negativ**: eine bewusst „gefuellte“ Ebene 2/3 laesst sich nicht
  wieder auf „existiert nicht“ zuruecksetzen — nur leeren (Radierer /
  „clear screen“). Akzeptiert, da eine leere Ebene nichts kostet.
- US4 wird zur **Frame-Verwaltung** (AD-041).

## Related
- [ADR-041: Compositing-Cache & Frame-Verwaltung](ADR-041-Compositing-Cache-und-Frame-Verwaltung.md)
- [specs/010-layer-management-with-transparency/research.md: R9](../../specs/010-layer-management-with-transparency/research.md)
- [specs/010-layer-management-with-transparency/spec.md: Clarifications 3. Runde, FR-012/012b/012c](../../specs/010-layer-management-with-transparency/spec.md)
