# Contract: Editor-UI-Verbesserungen — geänderte/neue Schnittstellen

**Feature**: 006-editor-ui-polish | **Date**: 2026-07-19

Ergänzt (überschreibt NICHT) `specs/003-editor-animation-zoom/contracts/editor-room.md`
— nur hier gelistete Punkte ändern sich; alle dort dokumentierten E-01..E-03/
Z-01..Z-03-Contracts bleiben unverändert gültig.

## 1. Crank-Eingabe-Contract (ersetzt die Frame-Zeile aus editor-room.md §2)

| Eingabe | Kontext | Wirkung |
|---|---|---|
| Crank-Drehung, netto ≥360° in eine Richtung seit letztem Wechsel (`getCrankChange()`-Akkumulation, `crankAccumDegrees`) | Editor, B nicht gehalten | Frame vor/zurück; vorwärts legt Kopie an (< 12), rotiert bei 12→1; rückwärts rotiert 1→letzter (FR-004/005/006) |
| Crank-Teildrehung < 360° netto | Editor, B nicht gehalten | KEIN Frame-Wechsel; Akkumulator bleibt stehen bis zur nächsten Bewegung (FR-004/005/006) |
| Crank-Richtungswechsel vor Erreichen von 360° | Editor, B nicht gehalten | Netto-Akkumulator sinkt/steigt entsprechend; KEIN Frame-Wechsel, solange \|Akkumulator\| < 360° |
| B halten + Crank | Editor/ZoomRoom/PixelRoom | **UNVERÄNDERT**: Zoomstufe rein/raus über `getCrankTicks(4)` (research.md R1 — beide Crank-APIs dürfen sich pro Frame nicht gegenseitig den Zustand entziehen, siehe Detailhinweis) |

**CR-01**: Pro `EditorRoom:update()`-Aufruf wird GENAU EINE Crank-Lese-API
aufgerufen — `getCrankChange()` wenn B nicht gehalten, sonst
`getCrankTicks(4)` (bestehendes Verhalten). Niemals beide im selben Frame.

## 2. Bauchbinde-Sichtbarkeits-Contract (ergänzt editor-room.md §2)

**CR-02**: Die Frame-Positions-Bauchbinde ("Frame n/m") wird nur gezeichnet,
wenn `(nowMs - lastActivityMs) < 5000`. Jede der folgenden Eingaben setzt
`lastActivityMs = nowMs`: D-Pad-Bewegung (auch Repeat-Ticks), A-Druck,
B-Druck/-Release, Crank-Delta ≠ 0 (beide Lesepfade aus Abschnitt 1).

**CR-03**: Die Anzeigeseite ist `"right"`, wenn `cursor.x <= 12`
(linke Bildschirmhälfte), sonst `"left"` — invers zur Cursorposition
(FR-003). Die separate Status-Bauchbinde (`statusMessage`, immer `"left"`)
bleibt unverändert und unabhängig hiervon.

## 3. Zoom-Rendering-Contract (ergänzt/präzisiert Z-01 aus editor-room.md)

**CR-04**: Für eine Zoom-Zelle `(r,c)`, deren `gridState[r][c]` seit dem
Betreten des Zoom-Kontexts unverändert ist (`== baselineGrid[r][c]`), MUSS
der Hintergrund die vier realen Quellpixel des zugehörigen 2×2-Blocks aus
`slot.editedImage or slot.originalImage` einzeln zeigen (FR-007/009). Für
bereits bearbeitete Zellen gilt weiterhin Z-01 unverändert (ein flächiger
2×2-Pixel-Block pro Malstrich). Das Editier-Verhalten selbst (`beginStroke`/
`paintCurrentCell`/`collectEdits`) ändert sich NICHT (FR-008).

## 4. Kontext-/Pause-Ansicht-Contract (NEU)

```lua
-- Source/EditorRoom.lua (neu)
EditorRoom:buildPauseMenuImage() -> playdate.graphics.image | nil
-- nil, wenn kein imageData geladen ist (z. B. Room noch nicht entered())

-- Source/main.lua (neu)
function playdate.gameWillPause()
    if currentRoom == EditorRoom or currentRoom == ZoomRoom or currentRoom == PixelRoom then
        playdate.setMenuImage(EditorRoom:buildPauseMenuImage())
    else
        playdate.setMenuImage(nil)
    end
end
```

**CR-05**: Das Bild ist 400×240px; jeglicher informationstragender Inhalt
liegt in `x ∈ [0, 200)` (SDK-Vorgabe, rechte Hälfte wird vom System-Menü
überdeckt).

**CR-06**: Die angezeigte Gesamtzahl (`FR-011`) ist die Anzahl
UNTERSCHIEDLICHER Tile-Indizes, die tatsächlich in mindestens einem
`imageData.frames[*]`-Eintrag referenziert werden (NICHT
`imagetable:getLength()`, siehe data-model.md Abschnitt 4).

**CR-07**: Übersteigt die Gesamtzahl 120, zeigt das Raster nur die ersten
120 (aufsteigende Tile-Index-Reihenfolge); die angezeigte Gesamtzahl bleibt
davon unberührt korrekt (FR-013).

**CR-08 (AD-032, entschieden)**: "Reset Frame" wird über einen
System-Menü-Eintrag `"reset frame"` ausgelöst, der den bisherigen
`"delete frame"`-Eintrag ERSETZT (nicht `"show grid"`). Finaler Menü-Aufbau
in `EditorRoom:buildSystemMenu()`:

```lua
menu:addMenuItem("save + exit", ...)
menu:addMenuItem("reset frame", function() resetCurrentFrameToPrevious() end)
menu:addCheckmarkMenuItem("show grid", showGrid, ...)
```

`deleteCurrentFrame()` bleibt als Funktion im Code bestehen, hat aber ab
dieser Spec KEINEN Menü-Aufrufer mehr (FR-008a aus Spec 003 ist damit über
das Menü nicht mehr erreichbar — Projektinhaber-Entscheidung, siehe
research.md R7/plan.md AD-032).

## 5. Titelscreen-Animations-Contract (NEU, `SelectionRoom.lua`)

**CR-09**: Bei Selektionswechsel wird ein laufender Lazy-Load für den
VERLASSENEN Eintrag nicht abgewartet — der neue Eintrag startet sofort
seinen eigenen `RoomOperation`-Ladevorgang; solange kein `fullImageData`
für den aktuell selektierten Eintrag vorliegt, bleibt dessen bisheriges
statisches Kreis-Thumbnail sichtbar (kein Leerbild, kein Sprung).

**CR-10**: Nur der aktuell selektierte Eintrag zeigt den animierten
Vollbild-Hintergrund; alle anderen Einträge werden unverändert über den
bestehenden Pfad (`drawImageThumbnail`/`createCircularThumbnail`) gezeichnet
(FR-018) — kein Eingriff in deren Rendering-Code.

**CR-11**: Bei genau 1 Frame läuft kein Frame-Wechsel-Timer;
`titleAnimFrame` bleibt konstant `1`, der VHS-Effekt (Abschnitt "VHS")
bleibt trotzdem aktiv (FR-016 Acceptance Scenario 4).
