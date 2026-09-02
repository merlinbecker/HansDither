# ADR-047: CR-01 praezisiert — beide Crank-Lese-APIs jeden Frame entleeren

- **Status:** umgesetzt (Spec 011, Code-Review-Nachbesserung Batch 2, Findings F1/F2)
- **Kontext:** Spec 006 CR-01 (bzw. PR-01 fuer den PixelRoom) forderte bisher
  woertlich „pro `update()` wird **genau eine** Crank-Lese-API aufgerufen": im
  B-Zweig `playdate.getCrankTicks(4)` (Zoomkette / Frame-Verwaltung), im
  Ohne-B-Zweig `playdate.getCrankChange()` (Tile-Picker im EditorRoom bzw.
  90°-Rotation im PixelRoom). Ziel war, dass eine einzelne physische Drehung
  nicht anteilig in beide Akkumulatoren zerfaellt.

## Problem

`getCrankTicks(n)` ist **zustandsbehaftet**: der Rueckgabewert sind die Ticks
**seit dem letzten Aufruf**. Wird die API waehrend einer laengeren Picker- bzw.
Rotationsdrehung (Ohne-B-Zweig) nie aufgerufen, sammelt der SDK-interne Zaehler
den kompletten Rueckstand. Der **erste** Frame mit gehaltener B-Taste liest dann
in einem Schlag z. B. ±4 Ticks und loest ungewollt `zoomIn()` /
`openFrameManagementView()` (EditorRoom, F2) bzw. den Zoom-Out aus dem PixelRoom
(F1) aus — ohne jede B-Crank-Bewegung. Bei offenem Undo-Dialog lief der
Crank-Block gar nicht, sodass **beide** Zaehler ueber die Dialog-Lebensdauer
stauten und beim Schliessen als Phantom-Zoom / Picker-Sprung abflossen.
`ZoomRoom:update()` war gegen genau diesen Effekt bereits geschuetzt (liest
`getCrankTicks(4)` bedingungslos jeden Frame, eigener Kommentar seit Spec 008).

## Entscheidung

CR-01 / PR-01 wird praezisiert:

> Pro `update()` **steuert genau eine** Crank-Lese-API die Logik (Zweig-Wahl
> ueber die B-Taste). **Beide** APIs werden aber **jeden Frame genau einmal
> gelesen**; der nicht genutzte Wert wird verworfen. Der Leseaufruf selbst ist
> der Drain, der den zustandsbehafteten SDK-Zaehler frisch haelt.

Umsetzung: `EditorRoom:handleCrank()` und `PixelRoom:update()` lesen `crankTicks`
und `crankChange` am Block-Anfang in lokale Variablen; die B-/Ohne-B-/Dialog-
Verzweigung wertet weiterhin nur je eine davon aus. Bei offenem Undo-Dialog und
in den Load-/Save-Zweigen des `EditorRoom:update()` werden beide APIs ebenfalls
bedingungslos gelesen (nur Drain).

## Begruendung

- Die urspruengliche „nur eine lesen"-Regel schuetzt vor **Signal-Aufteilung**
  einer laufenden Geste. Diese Aufteilung passiert nur, wenn beide gelesenen
  Werte **ausgewertet** werden — nicht, wenn einer verworfen wird. `getCrankChange`
  und `getCrankTicks` fuehren im SDK **getrennte** Basiswerte; ein Drain-Aufruf
  der einen API beeinflusst die andere nicht.
- Der Zweig ist fuer die Dauer einer Geste stabil (B bleibt gehalten bzw. los),
  daher bekommt der jeweils aktive Akkumulator das volle Signal. Verworfen wird
  nur der Bruchteil im Umschalt-Frame — das ist erwuenscht (Rest-Drehung von vor
  dem B-Druck soll keinen Zoom ausloesen).
- `ZoomRoom` beweist das Muster seit Spec 008 im Feld.

## Konsequenz

- `Source/EditorRoom.lua`, `Source/PixelRoom.lua`: Crank-Block liest beide APIs
  vorab; Kommentare auf die praezisierte Regel umgeschrieben. `ZoomRoom`
  unveraendert (war schon konform).
- Headless: Aufrufzaehler `crankTicksReadCount` / `crankChangeReadCount` im
  Mock; neue Abschnitte pruefen fuer beide Raeume, dass **jeder** Zweig (B /
  ohne B / offener Dialog) beide Zaehler erhoeht. Die bestehenden CR-01/PR-01-
  Regressionstests (B+Crank-Zoomkette loest weiterhin aus) bleiben unveraendert
  gruen.
- Doku: CR-01-Formulierungen in arc42 05/06/08 und Risiko R-22 in arc42 11
  nachgezogen.
- `buildNumber` 33 → 34, `pdc` sauber, 535 Assertions gruen.
