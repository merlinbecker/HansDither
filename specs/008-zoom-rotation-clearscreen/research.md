# Phase 0 Research: Zoom-Room-Performance, Pixel-Rotation und vereinfachte Frame-Verwaltung

**Feature**: 008-zoom-rotation-clearscreen | **Date**: 2026-07-22

Alle Punkte gegen das lokal installierte Playdate SDK (`~/Developer/PlaydateSDK`,
**v3.0.6**), die lokale Inside-Playdate-Referenz (`inside_playdate/*.md`) sowie
den tatsächlichen Source-Code (`Source/ZoomRoom.lua`, `Source/PixelRoom.lua`,
`Source/EditorRoom.lua`, `Source/ImageStoreCodec.lua`) verifiziert —
Constitution Prinzip I (SDK-First) und projektweite SDK-Verifikationsregel.

---

## R1: Zoom-Room-Ruckeln/Navigationsblockade (FR-001/002/003/004) — Ursache und Fix

**Ist-Zustand**: `ZoomRoom.lua:drawGrid()` wird bei JEDEM `needsRedraw`
(d. h. bei jeder Cursorbewegung, jedem Malstrich, auch während des
80-ms-Richtungstasten-Repeats) vollständig neu ausgeführt:

- Schleife über alle 24×24 = 576 Rasterzellen; für jede UNBEARBEITETE Zelle
  bis zu 4× `image:sample()` (Subpixel-Quadranten, seit Spec 006/R2) plus
  bis zu 4× `fillRect()` — macht bis zu ~2300 Sample- und ~2300
  Fill-Aufrufe pro Redraw.
- Gestrichelte Zellgrenzen (`drawDashedVLine`/`drawDashedHLine`): bei
  `DASH_LEN=2`/`GAP_LEN=2` über 240 px Kantenlänge und ~20 sichtbaren
  Linien je Richtung ergibt das ca. 2400 einzelne `gfx.drawLine()`-Aufrufe
  — **obwohl sich Zellgrenzen und Tile-Grenzen während einer gesamten
  Zoom-Room-Sitzung nie ändern.**

Diese Arbeit läuft synchron in `ZoomRoom:update()`, das von
`playdate.update()` aufgerufen wird — bei Refreshrate 30 fps (Default,
`playdate.display.setRefreshRate()`) stehen dafür 33 ms Budget zur
Verfügung. Wird dieses Budget durch die o. g. Aufrufmenge überschritten,
wirkt die Eingabeverarbeitung (D-Pad-Repeat alle 80 ms, Cursor-Folgeschritt)
verzögert bzw. "hängend" — das vom Projektinhaber vermutete
"tieferliegende Problem" ist nach Code-Review vermutlich **dieselbe
Ursache in verschärfter Form**, keine separate Bugklasse: Es wurde keine
Endlosschleife, kein blockierender Aufruf und keine fehlerhafte
Zustandslogik in `moveCursor()`/`processDirectionHold()`/
`paintCurrentCell()` gefunden (alle Invalidierungen sind bereits korrekt
zustandsbasiert, kein "immer redraw"-Antipattern).

**Wichtiger SDK-Fund** (`inside_playdate/7.16 Display.md`): Die
Playdate-Hardware macht bereits ein zeilenweises Diffing — unveränderte
Zeilen werden gar nicht an das physische Display gesendet. Das greift aber
erst NACH dem vollständigen Lua-seitigen Zeichnen des Frame-Buffers; es
reduziert also die Anzeige-Bandbreite, nicht die hier relevante CPU-Zeit
für die vielen Einzel-Draw-Aufrufe.

Der SDK-Hinweis "Important: The following functions can be quite slow,
especially when rotating images off-axis" (`inside_playdate/Inside
Playdate.md`, Abschnitt Image-Transformationen) bezieht sich ausdrücklich
NUR auf `drawRotated`/`rotatedImage`/`drawScaled`/`drawSampled` — nicht auf
das hier verwendete einfache `image:sample()`. Das Problem liegt also
nachweislich an der **Menge** der Aufrufe pro Interaktion, nicht an einer
einzelnen teuren SDK-Funktion.

**Decision**: Statischer Hintergrund-Cache + minimaler Overlay-Redraw,
nach dem in `inside_playdate/Inside Playdate.md` (Abschnitt zu
`pushContext`) selbst dokumentierten Muster: *"…speichert unser Zeichnen,
macht es einfacher zu zeichnen und hilft, die Performance zu verbessern,
da wir nicht jedes Mal jedes Element einzeln neu zeichnen müssen."*

1. **`cachedBackground` (playdate.graphics.image, 240×240)**: wird EINMAL
   aufgebaut — beim Betreten des Zoom Room bzw. nach
   `setFromEditorContext()`/`setNewTile()`/`updateExistingTile()` oder
   einem `showGridLines`-Toggle — mittels `gfx.pushContext(cachedBackground)`
   … `gfx.popContext()`. Enthält: Checkerboard-Seitenflächen, alle 576
   Zellen im unbearbeiteten Subpixel-Zustand, gestrichelte Zellgrenzen,
   durchgezogene Tile-Grenzen.
   - Bereits im Projekt etabliertes Muster: `buildWorkingImage()` in
     `ZoomRoom.lua` nutzt schon `gfx.pushContext(img)`/`gfx.popContext()`
     für denselben Offscreen-Zweck (Constitution IV — bestehende Muster
     wiederverwenden statt neue Abstraktion einzuführen).
2. **`changedCells` (Liste von `{row, col}`)**: wird in `paintCurrentCell()`
   gepflegt (Zelle hinzufügen, falls noch nicht enthalten). Ersetzt den
   Voll-Scan über alle 576 Zellen beim Redraw.
3. **`drawGrid()` (neu)**: `cachedBackground:draw(OFFSET_X, OFFSET_Y)` (ein
   Blit-Aufruf) → nur die Zellen aus `changedCells` einzeln übermalen →
   Cursor zeichnen. Aus "576 Zellen × 4 Samples + ~2400 Linien" wird
   "1 Blit + 0–wenige Zellen + Cursor".
4. **Cache-Invalidierung**: nur bei den o. g. seltenen Ereignissen
   (Zoom-Kontext-Wechsel, Grid-Toggle, neues Tile aus PixelRoom) — nicht
   bei Cursorbewegung/Malstrich. Der einmalige Aufbauaufwand (die
   ursprünglichen ~2300 Sample-Aufrufe) fällt dadurch nur einmal pro
   Zoom-Room-Aufenthalt an, nicht pro Interaktion.
5. **Ergänzend**: `playdate.graphics.setScreenClipRect()` auf den
   tatsächlich betroffenen Bildschirmbereich vor dem Overlay-Redraw, als
   zusätzliche (kostengünstige) Absicherung gegen unnötige Framebuffer-
   Schreibzugriffe außerhalb der geänderten Zelle(n).
6. **Empirische Verifikation vor Abschluss** (Constitution V, hardware-nahe
   Prüfung): `playdate.getStats()`-Game-Zeit-Anteil bzw. Sampler-Profil
   (`inside_playdate/Inside Playdate.md`, Abschnitt 7.15 Profiling) auf
   echter Hardware vor/nach dem Fix vergleichen, um den Rückgang der
   CPU-Last objektiv zu belegen (siehe quickstart.md).

**Alternativen verworfen**:
- Nur `setClipRect`/`setScreenClipRect` einsetzen, OHNE Hintergrund-Cache
  — verworfen: verhindert nur unnötige Framebuffer-Schreibzugriffe, aber
  NICHT die teuren Lua-seitigen `sample()`/`drawLine()`-Berechnungen
  selbst, die weiterhin pro Interaktion für die gesamte Fläche anfielen.
- Statisches Gitter/Tile-Grenzen als vorgerendertes Bild, aber
  Zellinhalte weiterhin live sampeln — verworfen: die Gitterlinien
  (~2400 `drawLine()`-Aufrufe) sind zwar der größte Einzelposten, aber die
  ~2300 `sample()`-Aufrufe bei jeder Cursorbewegung bleiben ohne
  Änderungs-Set-Tracking trotzdem unnötig; beide Optimierungen gehören
  zusammen (Änderungs-Set macht auch die Zelleninhalte cache-fähig).
- `playdate.graphics.sprite`-basierte Dirty-Rect-Verwaltung (SDK-eigenes
  Sprite-System, `addDirtyRect`/`markDirty`) — verworfen für diese Version:
  würde eine Umstellung von direktem Framebuffer-Zeichnen auf ein
  Sprite-Objekt bedeuten (größerer Umbau als für den Fix nötig,
  Constitution IV/Einfachheit); der manuelle Hintergrund-Cache erreicht
  denselben Effekt mit minimaler Änderung an der bestehenden `drawGrid()`.

---

## R2: "Volle Umdrehung" im Pixel Room (FR-005/006/007) — Crank-Mechanik

**Ist-Zustand**: `PixelRoom.lua:update()` liest `playdate.getCrankTicks(4)`
JEDEM Aufruf, verwendet den akkumulierten Wert aber nur, wenn B gehalten
wird (Zoom-Out bei `ticks <= -4`; Vorwärts-Zoom ist an dieser innersten
Zoomstufe bewusst ein No-op). Ist B NICHT gehalten, wird `ticks` in jedem
Frame auf `0` zurückgesetzt — reine Crank-Drehung ohne B hat aktuell also
**keinerlei Wirkung** im Pixel Room. Für die neue Rotation ist dieser
Eingabekanal somit frei, ohne bestehendes Verhalten zu verdrängen.

**Decision**: Exakt dasselbe Muster wie `EditorRoom.lua:handleCrank()`
(Spec 006, research.md R1) auf `PixelRoom.lua` übertragen — dort bereits
bewährt und Constitution-IV-konform (Wiederverwendung statt Neuerfindung):

```lua
if playdate.buttonIsPressed(playdate.kButtonB) then
    -- unveraendert: getCrankTicks(4) fuer Zoom-Out
    local crankTicks = playdate.getCrankTicks(4) or 0
    ticks = ticks + crankTicks
    if ticks <= -4 then ticks = 0; commitToZoomRoom(); switchRoomFunction(nextRoom)
    elseif ticks > 0 then ticks = 0 end
else
    -- NEU: getCrankChange() fuer Rotations-Akkumulator, ersetzt "ticks = 0"
    local change = playdate.getCrankChange() or 0
    rotationAccumDegrees = rotationAccumDegrees + change
    if rotationAccumDegrees >= 360 then
        rotationAccumDegrees = rotationAccumDegrees - 360
        rotateGridClockwise()
    elseif rotationAccumDegrees <= -360 then
        rotationAccumDegrees = rotationAccumDegrees + 360
        rotateGridCounterClockwise()
    end
end
```

Pro `update()`-Aufruf wird weiterhin GENAU EINE Crank-Lese-API verwendet
(nie beide im selben Frame) — dieselbe Regel, die `EditorRoom.lua`
bereits für den B-Held/B-nicht-Held-Split durchsetzt (CR-01, Spec 006).
Teildrehungen (< 360°) verändern `rotationAccumDegrees`, lösen aber KEINE
sichtbare Rotation aus (FR-007) — Richtungswechsel heben sich im
signierten Summenwert von selbst auf, kein Sonderfall nötig (identisch zur
Begründung in Spec 006 R1).

**Alternativen verworfen**:
- `getCrankTicks(N)` mit kleinem `N` (z. B. 1 Tick pro Umdrehung) —
  verworfen aus demselben Grund wie in Spec 006 R1: Tick-Grenzen sind
  ABSOLUTE Kurbelpositionen, nicht relativ zum Drehbeginn; das erfüllt
  nicht "eine vollständige Umdrehung AB DER AKTUELLEN POSITION".
- Rotation an B+Crank koppeln (z. B. B gehalten + zusätzliche Vollumdrehung)
  — verworfen: würde mit der bestehenden Zoom-Out-Geste (`ticks <= -4`)
  kollidieren bzw. sie verdrängen; die Spec fordert zudem explizit
  Rotation OHNE zusätzliche Taste ("bei einer vollen Umdrehung des
  Cranks").

---

## R3: Rotations-Algorithmus (FR-005/006) — exakter Index-Remap statt SDK-Bildtransformation

**Ist-Zustand**: `PixelRoom.lua` hält den Editier-Zustand bereits als
einfache 16×16-Bool-Tabelle (`gridState[row][col]`, `true` = schwarz) —
keine SDK-Bild-Rotation nötig, um "keine Auflösungsverluste" (Spec-Vorgabe)
zu garantieren.

**Warum NICHT `image:rotatedImage(90)`/`image:drawRotated()`**: Der
SDK-Hinweis in `inside_playdate/Inside Playdate.md` ("Important: The
following functions can be quite slow… Transforming a large image can
take many milliseconds on the device") gilt für diese Funktionsfamilie
unabhängig von der Bildgröße als Warnung; zusätzlich dokumentiert die SDK
für `rotatedImage()` ausdrücklich: *"Unless rotating by a multiple of 180
degrees, the new image will have different dimensions than the original"*
— ein Hinweis, dass die Funktion für allgemeine (nicht notwendigerweise
quadratische) Bilder gedacht ist und über echtes Pixel-Resampling
arbeitet. Für ein striktes 1-Bit-Raster ohne jede Kantenglättung ist ein
direkter Index-Remap exakt, schnell (256 Zellen) und frei von jedem
Resampling-Risiko.

**Decision**: Für ein N×N-Raster (`N = GRID_ROWS = GRID_COLS = 16`, 1-basiert)
gilt für eine 90°-Drehung im Uhrzeigersinn:

```
new[r][c] = old[N + 1 - c][r]      -- 90° im Uhrzeigersinn (FR-005)
```

und für die Gegenrichtung (volle Rückwärtsdrehung, FR-006):

```
new[r][c] = old[c][N + 1 - r]      -- 90° gegen den Uhrzeigersinn
```

Verifiziert an einem 2×2-Beispiel (A/B obere Zeile, C/D untere Zeile):
nach 90°-Drehung im Uhrzeigersinn steht C oben links, A oben rechts, D
unten links, B unten rechts — die Formel liefert exakt dieses Ergebnis.
Implementierung: neue temporäre Tabelle aufbauen, dann `gridState`
ersetzen (kein In-Place-Remap, da sich Lese- und Schreibposition
überlappen würden).

**Alternativen verworfen**:
- `image:rotatedImage(90)` auf das aus `gridState` gebaute Tile anwenden,
  danach zurück in `gridState` dekodieren — verworfen: unnötiger
  Umweg über Bild-Encode/Decode plus die o. g. SDK-Performance-Warnung,
  obwohl das Ergebnis bei einem quadratischen reinen Schwarz/Weiß-Bild
  vermutlich pixelgenau wäre; der direkte Tabellen-Remap ist einfacher
  UND nachweislich schneller (Constitution IV).
- Rotation erst beim Commit (`commitToZoomRoom()`/`buildTileImage()`)
  anwenden statt live auf `gridState` — verworfen: das Malraster
  (`gridView`) und die Live-Anzeige müssten sonst getrennt vom
  gespeicherten Zustand geführt werden; direktes Rotieren von `gridState`
  hält Anzeige und Zustand durchgängig konsistent, ohne neuen
  Zwischenzustand (FR-008).

---

## R4: "Clear Screen" ersetzt "Reset Frame" (FR-011/012/013/014/015)

**Ist-Zustand**: `EditorRoom.lua:resetCurrentFrameToPrevious()` (Spec
006/AD-032) kopiert den Vorgänger-Frame elementweise in den aktiven Frame;
ausgelöst über den Systemmenü-Eintrag `"reset frame"`
(`buildSystemMenu()`, dritter von drei Slots, nach `"save + exit"`, vor
`"show grid"`). `ImageStoreCodec.sliceSheetToImagetable()` dokumentiert
die Basistile-Invariante des Editors: **Index 1 = Voll-Weiß, Index 2 =
Voll-Schwarz** — dieselbe Invariante, die auch der Schwarz/Weiß-Toggle
(Spec 003, FR-004) nutzt.

**Decision**: Neue Funktion `clearCurrentFrame()`, strukturell identisch
zu `resetCurrentFrameToPrevious()`, aber mit dem konstanten Basis-Index
1 (Voll-Weiß) statt dem Vorgänger-Frame-Array als Quelle:

```lua
local function clearCurrentFrame()
    if inputBlocked() then return end
    local current = imageData.frames[currentFrame]
    for i = 1, #current do
        current[i] = 1  -- Index 1 = Voll-Weiß (ImageStoreCodec-Invariante)
    end
    updateTilemapFrame()
    needsRedraw = true
end
```

Menü-Umbau in `buildSystemMenu()`: dritter Slot wechselt von
`"reset frame"` (ruft `resetCurrentFrameToPrevious()`) auf
`"clear screen"` (ruft `clearCurrentFrame()`); `"save + exit"` und
`"show grid"` unverändert (gleiche Struktur wie AD-032 in Spec 006).

**Toter Code — Entscheidung (Constitution IV)**: FR-011 fordert
ausdrücklich VOLLSTÄNDIGE Entfernung von "Reset Frame" (nicht nur
Entfernung des Menü-Zugriffs, wie es AD-032 seinerzeit für "delete frame"
bewusst offenließ). Deshalb wird `resetCurrentFrameToPrevious()` aktiv AUS
DEM CODE ENTFERNT, nicht nur ihres Menü-Aufrufers beraubt —
Einfachheit vor Ansammeln toten Codes. `deleteCurrentFrame()` (seit
AD-032 bereits ohne Menü-Aufrufer) bleibt unverändert und ist nicht
Gegenstand dieser Spec.

**Alternativen verworfen**:
- `resetCurrentFrameToPrevious()` im Code belassen (wie `deleteCurrentFrame()`
  seit AD-032) — verworfen: FR-011 fordert VOLLSTÄNDIGE Entfernung der
  Funktion "Reset Frame", nicht nur ihres Menüpunkts; zwei orphane
  Frame-Funktionen ohne Aufrufer wären unnötig angehäufte Komplexität
  ohne jeden Nutzen (Constitution IV).
- Bestätigungsdialog vor "Clear Screen" — verworfen: siehe spec.md
  Assumptions (Projektinhaber lässt die ursprüngliche Schutzidee bewusst
  fallen; kein bestehender Menüpunkt im Projekt hat eine Bestätigung).

---

## Zusammenfassung SDK-Verifikation (Constitution I)

| Baustein | SDK-Funktion | Bereits verifiziert gegen |
|---|---|---|
| Zoom-Hintergrund-Cache | `gfx.pushContext(image)`/`gfx.popContext()`, `image:draw()` | `inside_playdate/Inside Playdate.md` (Offscreen-Drawing-Beispiel), bereits genutzt in `ZoomRoom.lua:buildWorkingImage()` |
| Zoom-Redraw-Absicherung | `playdate.graphics.setScreenClipRect()` | `inside_playdate/Inside Playdate.md` §Graphics (setClipRect/setScreenClipRect) |
| Performance-Nachweis | `playdate.getStats()`, Sampler | `inside_playdate/Inside Playdate.md` §7.15 Profiling |
| Rotations-Trigger | `playdate.getCrankChange()` | `inside_playdate/7.10 Crank.md`; Muster bereits in `EditorRoom.lua:handleCrank()` (Spec 006 R1) etabliert |
| Rotations-Algorithmus | reiner Lua-Tabellen-Remap (kein SDK-Aufruf) | bewusst KEINE `image:rotatedImage()`/`drawRotated()` — SDK-Performance-Warnung, s. R3 |
| Clear Screen | reine Lua-Array-Zuweisung (kein SDK-Aufruf) | `ImageStoreCodec.sliceSheetToImagetable()`-Invariante (Index 1 = Weiß) |
