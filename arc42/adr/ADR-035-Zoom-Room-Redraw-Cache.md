# ADR-035: Statischer Hintergrund-Cache statt Vollbild-Neuzeichnung im Zoom Room

## Status
✅ **Umgesetzt** – `ZoomRoom:drawGrid()`

## Kontext
Der Zoom Room ruckelt so stark, dass präzises Bedienen und Pixel-Setzen
kaum möglich sind (Spec 008, US1). Code-Review von `ZoomRoom.lua` zeigt:
`drawGrid()` wird bei JEDER Interaktion (Cursorbewegung, Malstrich, auch
während des 80-ms-Richtungstasten-Repeats) vollständig neu ausgeführt —
Schleife über alle 24×24 = 576 Zellen mit bis zu 4 `image:sample()`-
Aufrufen je unbearbeiteter Zelle (~2300 Aufrufe) plus gestrichelte
Zellgrenzen und durchgezogene Tile-Grenzen (~2400 `gfx.drawLine()`-
Aufrufe), obwohl sich Gitterlinien und die meisten Zellinhalte innerhalb
einer Zoom-Room-Sitzung nie ändern.

Die lokale Inside-Playdate-Referenz (`inside_playdate/7.16 Display.md`)
bestätigt: Die Playdate-Hardware sendet ohnehin nur geänderte
Bildschirmzeilen an das physische Display (zeilenweises Diffing) — das
greift aber erst NACH dem vollständigen Lua-seitigen Zeichnen des
Frame-Buffers und reduziert daher nicht die hier relevante CPU-Zeit.
`inside_playdate/Inside Playdate.md` warnt zudem explizit nur vor
`drawRotated`/`rotatedImage`/`drawScaled`/`drawSampled` als "quite slow" —
nicht vor dem hier verwendeten einfachen `image:sample()`. Das Problem
liegt also nachweislich an der Menge der Aufrufe pro Interaktion.

Ein vom Projektinhaber vermutetes "tieferliegendes Problem", das die
Navigation blockiert, konnte im Code-Review nicht als separate Ursache
(z. B. Endlosschleife, blockierender Aufruf) bestätigt werden — die
Zustandsinvalidierung (`needsRedraw`) ist bereits korrekt implementiert.

## Entscheidungs-Treiber
- **Kernproblem des Feature-Wunschs**: Nutzbarkeit des Zoom Room "muss
  unbedingt verbessert werden" (spec.md).
- **SDK-Beleg**: dokumentiertes Offscreen-Cache-Muster
  (`inside_playdate/Inside Playdate.md`, `pushContext`-Beispiel) als
  ausdrücklich empfohlene Performance-Technik.
- **Bestehendes Muster im Projekt**: `buildWorkingImage()` in
  `ZoomRoom.lua` nutzt bereits `gfx.pushContext`/`gfx.popContext` für
  denselben Offscreen-Zweck (Constitution IV).
- **Einfachheit (Constitution IV)**: minimaler Eingriff in bestehende
  Editier-/Commit-Logik, kein Wechsel des Rendering-Modells.

## Optionen

| Option | Vorteile | Nachteile |
|--------|----------|-----------|
| **A: Statischer Hintergrund-Cache + Änderungs-Set** | Direkt im bestehenden Modul umsetzbar, wiederverwendet ein bereits etabliertes Muster (`pushContext`), reduziert Aufrufe von Tausenden auf einen Blit + wenige Zellen | Cache muss bei Kontextwechsel/Grid-Toggle explizit invalidiert werden |
| B: Nur `setClipRect`/`setScreenClipRect` ohne Cache | Einfach zu ergänzen | Verhindert nur unnötige Framebuffer-Schreibzugriffe, NICHT die teuren `sample()`/`drawLine()`-Berechnungen selbst |
| C: Umstellung auf `playdate.graphics.sprite` mit Dirty-Rect-Verwaltung | SDK-eigenes, vollautomatisches Dirty-Rect-System | Größerer Umbau (direktes Framebuffer-Zeichnen → Sprite-Objekt) als für den Fix nötig; widerspricht Constitution IV (Einfachheit) für diesen Umfang |

## Entscheidung
**Option A**: `cachedBackground` (400×240-Image inkl. Checkerboard-Seiten,
korrigiert bei der Implementierung von der ursprünglich geplanten
240×240-Variante — ein einziger `draw(0, 0)`-Aufruf genügt so für den
gesamten Bildschirm) wird einmalig bei
Kontextwechsel/Grid-Toggle aufgebaut (`backgroundDirty`-Flag); jeder
Redraw blittet den Cache und übermalt nur die in `changedCells`
gesammelten tatsächlich geänderten Zellen.

### Begründung
1. **Direkter Ursachenbezug**: Adressiert exakt die im Code-Review
   identifizierte Ursache (Vollbild-Neuberechnung pro Interaktion), nicht
   nur ein Symptom.
2. **Wiederverwendung statt Neuerfindung**: `gfx.pushContext`/
   `gfx.popContext` ist im Projekt bereits etabliert
   (`buildWorkingImage()`); kein neuer Renderingmechanismus nötig.
3. **Geringstes Risiko**: Editier-/Commit-Logik (`beginStroke`,
   `collectEdits`, Dedup-Pfad) bleibt vollständig unangetastet — nur der
   Zeichenweg ändert sich.

### Konsequenzen
- **Positiv**: Redraw pro Interaktion sinkt von ~2300 Sample- + ~2400
  Line-Aufrufen auf einen Bild-Blit plus höchstens wenige Zellen.
- **Negativ**: Neuer Invalidierungs-Zustand (`backgroundDirty`,
  `changedCells`) muss bei allen relevanten Ereignissen korrekt gesetzt
  werden — vergessene Invalidierung würde zu veralteten
  Hintergrundinhalten führen (mitigiert durch Headless-Tests, siehe
  quickstart.md).
- Empirischer Nachweis der Verbesserung erfolgt über `playdate.getStats()`/
  Sampler auf echter Hardware vor/nach dem Fix (research.md R1).

## Alternativen Considered
Siehe Options-Tabelle oben — vollständige Herleitung in
`specs/008-zoom-rotation-clearscreen/research.md` R1.

## Related
- [ADR-036: Pixel-Rotation via Index-Remap](ADR-036-Pixel-Rotation-Index-Remap.md)
- [specs/008-zoom-rotation-clearscreen/research.md: R1](../../specs/008-zoom-rotation-clearscreen/research.md)
- [specs/008-zoom-rotation-clearscreen/contracts/zoom-pixel-editor-updates.md: ZR-01..03](../../specs/008-zoom-rotation-clearscreen/contracts/zoom-pixel-editor-updates.md)
