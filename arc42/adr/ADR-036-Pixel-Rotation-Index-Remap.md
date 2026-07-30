# ADR-036: Pixel-Rotation via Crank-Volldrehung und exaktem Index-Remap

## Status
✅ **Umgesetzt** – `PixelRoom.lua`

## Kontext
Spec 008 (US2) fordert eine neue Funktion: Pixelbilder im Pixel Room
sollen sich per voller Kurbelumdrehung um 90° im Uhrzeigersinn drehen
lassen, ohne Auflösungsverlust. `PixelRoom.lua:update()` liest aktuell
`playdate.getCrankTicks(4)` bei JEDEM Aufruf, verwendet den Wert aber nur
bei gehaltener B-Taste (Zoom-Out-Geste); ohne B wird der Wert verworfen —
reine Crank-Drehung ist aktuell wirkungslos und damit als Eingabekanal
frei.

Die lokale Inside-Playdate-Referenz warnt ausdrücklich:
*"The following functions can be quite slow, especially when rotating
images off-axis. Transforming a large image can take many milliseconds
on the device."* (`image:drawRotated`/`rotatedImage`/`drawScaled`/
`drawSampled`). Zusätzlich dokumentiert die SDK für `rotatedImage()`:
*"Unless rotating by a multiple of 180 degrees, the new image will have
different dimensions than the original"* — ein Hinweis auf echtes
Pixel-Resampling statt exaktem Remap. Der Editier-Zustand liegt in
`PixelRoom.lua` bereits als einfache 16×16-Bool-Tabelle (`gridState`) vor.

## Entscheidungs-Treiber
- **Explizite Anforderung "ohne Auflösungsprobleme"** (spec.md) — schließt
  Resampling-Funktionen aus.
- **SDK-Performance-Warnung** für Bildtransformationsfunktionen
  (Constitution I — SDK-Nutzung muss begründet abgewogen werden).
- **Bereits etabliertes Crank-Akkumulator-Muster** (`crankAccumDegrees`,
  Spec 006/AD-019-Umfeld) für "volle Umdrehung ab aktueller Position".
- **Freier Eingabekanal**: Crank ohne B hat im Pixel Room aktuell keine
  Funktion.

## Optionen

| Option | Vorteile | Nachteile |
|--------|----------|-----------|
| **A: `getCrankChange()`-Akkumulator + direkter 16×16-Tabellen-Remap** | Exakt, kein Resampling, kein SDK-Bildtransform-Aufruf, wiederverwendet bestehendes Akkumulator-Muster | Erfordert eigene (kleine) Remap-Formel statt SDK-Fertigfunktion |
| B: `image:rotatedImage(90)` auf gebautes Tile anwenden, zurück nach `gridState` dekodieren | SDK-Fertigfunktion, kein eigener Algorithmus | Umweg über Bild-Encode/Decode; SDK-Performance-Warnung; Dimensions-/Resampling-Risiko laut SDK-Doku |
| C: Rotation an B+Crank koppeln (zusätzliche Umdrehung während B gehalten) | Kein neuer Akkumulator nötig | Kollidiert mit bestehender Zoom-Out-Geste (`ticks <= -4`); Spec fordert Rotation ausdrücklich ohne Zusatztaste |

## Entscheidung
**Option A**: Crank ohne B akkumuliert `playdate.getCrankChange()` in
`rotationAccumDegrees` (analog `crankAccumDegrees`); bei ±360° netto wird
`gridState` per direktem Index-Remap rotiert:

```
new[r][c] = old[17 - c][r]   -- 90° im Uhrzeigersinn (vorwaerts)
new[r][c] = old[c][17 - r]   -- 90° gegen den Uhrzeigersinn (rueckwaerts)
```

### Begründung
1. **Exaktheit**: Ein Tabellen-Remap auf einer reinen Bool-Matrix ist per
   Definition verlustfrei — es gibt kein Resampling, keine Kantenglättung,
   keine Dimensionsänderung.
2. **Performance**: 256 Zellen sind trivial günstig; kein SDK-Aufruf mit
   dokumentiertem Performance-Risiko nötig.
3. **Konsistenz**: Wiederverwendung des bereits im Projekt etablierten
   Crank-Akkumulator-Musters (Constitution IV) statt eines neuen
   Konzepts.

### Konsequenzen
- **Positiv**: Rotation ist exakt, schnell und ohne neue SDK-Abhängigkeit.
- **Negativ**: Zwei parallele Crank-Lesepfade (B gehalten/nicht gehalten)
  müssen weiterhin strikt exklusiv pro `update()`-Aufruf bleiben (wie
  bereits in `EditorRoom.lua` gelöst) — Regressionsrisiko für die
  bestehende B+Crank-Zoomkette, mitigiert durch Headless-Test im selben
  Testlauf.

## Alternativen Considered
Siehe Options-Tabelle oben — vollständige Herleitung in
`specs/008-zoom-rotation-clearscreen/research.md` R2/R3.

## Related
- [ADR-035: Zoom-Room-Redraw-Cache](ADR-035-Zoom-Room-Redraw-Cache.md)
- [specs/008-zoom-rotation-clearscreen/research.md: R2, R3](../../specs/008-zoom-rotation-clearscreen/research.md)
- [specs/008-zoom-rotation-clearscreen/contracts/zoom-pixel-editor-updates.md: PR-01..04](../../specs/008-zoom-rotation-clearscreen/contracts/zoom-pixel-editor-updates.md)
