# Quickstart: Schüttel-Undo validieren

**Feature**: `specs/011-shake-to-undo` | **Date**: 2026-09-02

Nachweisbare End-to-End-Szenarien, dass die Undo-Funktion wirkt. Detail-Verträge: [contracts/undo-modules.md](contracts/undo-modules.md); Datenstrukturen: [data-model.md](data-model.md).

---

## Voraussetzungen

- Playdate SDK installiert (`pdc`, Playdate Simulator).
- Lua-Interpreter für die Headless-Gates (`lua tests/headless_tests.lua`).
- Branch `feature/0.3-addons`, Feature-Verzeichnis `specs/011-shake-to-undo` (aktiv laut `.specify/feature.json`).
- Spec 010 (Clear Screen, Rotation, Frame-Verwaltung, Pixel-Verschiebung) ist auf dem Branch implementiert und grün.

---

## Gate 1 — Headless-Tests (Constitution V)

```sh
lua tests/headless_tests.lua
```

**Erwartung**: endet mit `ALLE TESTS BESTANDEN`. Der neue Abschnitt „Spec 011" deckt ab:
- Ringpuffer verdrängt den ältesten bei der 4. riskanten Operation (V1).
- Reines Malen erzeugt keinen Eintrag (V8).
- Undo stellt Clear Screen / Rotation / Pixel-Verschiebung / Frame löschen exakt wieder her (V5–V7, V9).
- „Male, dann rotieren" — Undo behält die gemalten Pixel, nimmt nur die Rotation zurück (V11).
- `deleteFrame`-Undo an der 12-Frame-Grenze wird abgelehnt (V10).
- `ShakeDetector`: saubere Links-Rechts-Kante feuert; ruhiges Halten / zu langsam / einseitig feuern nie; Refraktärzeit greift (V12–V16).
- `UndoPrompt` ist modal: A bestätigt genau einmal, B verwirft, zweites Schütteln bei offenem Dialog ist wirkungslos (V17–V20).
- Accelerometer wird nur in Tile/Zoom/Pixel-View gepollt, in Selection/Title/FrameManagement nicht (V21).

## Gate 2 — Build (Constitution V)

```sh
# 1. Source/pdxinfo: buildNumber 30 -> 31
# 2. dann:
pdc Source "Hans Dither.pdx"
```

**Erwartung**: fehlerfreier Build; `buildNumber` ist 31.

---

## Szenario A — Clear Screen zurücknehmen (US1, FR-002/004/005)

1. Simulator starten, Bild öffnen, im Tile View einige Tiles malen.
2. Systemmenü → **clear screen**. Der aktive Ebeneninhalt ist weg.
3. Simulator: **Menü → „Shake"** (bzw. auf Hardware das Gerät einmal nach links und rechts schütteln).
4. **Erwartung**: Dialog „Undo Clear Screen? (A) Ja (B) Nein" erscheint.
5. **A** drücken.
6. **Erwartung**: der gemalte Inhalt ist vollständig zurück; der Dialog ist zu.

## Szenario B — Rotation zurücknehmen, Malen bleibt (US1, FR-002)

1. In den Pixel View zoomen (B + Crank vorwärts ×2). Ein asymmetrisches Muster in die 16×16-Zelle malen.
2. Crank eine volle Umdrehung → das Grid dreht sich 90°.
3. Zurück zum Tile View (B + Crank rückwärts) — die Rotation wird committet.
4. Schütteln → Dialog „Undo Rotation?" → **A**.
5. **Erwartung**: die Zelle steht wieder ungedreht, **aber die zuvor gemalten Pixel sind erhalten** (nur die Rotation wurde zurückgenommen).

## Szenario C — Pixel-Verschiebung: ein Schütteln nimmt den ganzen Schub zurück (US1, FR-002; research R4)

1. Im Zoom View auf eine Zelle mit Inhalt. **B halten** und **5×** Right — der Inhalt wandert 5 Pixel in den Nachbarn.
2. **B loslassen.**
3. Schütteln → Dialog „Undo Pixel-Verschiebung?" → **A**.
4. **Erwartung**: Quell- und Nachbarzelle stehen wieder auf dem Stand von vor dem B-Halten (nicht nur 1 Pixel zurück). Ein einziges Schütteln genügt.

## Szenario D — Frame löschen zurücknehmen (US1, FR-005/007)

1. Bild mit ≥ 3 Frames. B + Crank rückwärts → Frame-Verwaltung.
2. Frame 2 markieren (A), erneut **A** → Frame 2 gelöscht. **B loslassen** → zurück im Tile View.
3. Schütteln → Dialog „Undo Frame löschen?" → **A**.
4. **Erwartung**: Frame 2 ist mit Inhalt an Position 2 zurück; der Editor steht auf Frame 2.
5. Randfall: Wenn seit dem Löschen wieder 12 Frames existieren → statt Wiederherstellung kurz „cannot undo — frame limit"; nichts ändert sich.

## Szenario E — Dreistufiger Verlauf & Verdrängung (US2, FR-001)

1. Nacheinander: Clear Screen, dann eine Rotation (mit Commit), dann eine Pixel-Verschiebung.
2. 3× (Schütteln → A). **Erwartung**: nach dem 3. Undo ist der Zustand wie vor allen dreien.
3. 4. Schütteln. **Erwartung**: kurze Meldung „Nothing to undo", kein Dialog.
4. Jetzt 4 riskante Operationen ausführen, dann Schütteln → der Dialog betrifft die **4.**; nach genügend Undos ist die **1.** nicht mehr erreichbar.

## Szenario F — Dialog ist vollständig modal (US3, FR-013/015, SC-005)

1. Irgendeine riskante Operation ausführen, dann schütteln → Dialog offen.
2. Bei offenem Dialog probieren: D-Pad, Crank drehen, A gedrückt halten, B.
3. **Erwartung**: kein Malen, kein Zoom, kein Cursor-/Frame-/Room-Wechsel; nur **A** = Undo, **B** = Abbrechen. Ein zweites Schütteln währenddessen bewirkt nichts.

## Szenario G — Verlauf ist sitzungslokal (FR-008, SC-008)

1. Riskante Operation ausführen (Verlauf hat 1 Eintrag).
2. Systemmenü → **save + exit** → zurück im Auswahlbildschirm; dasselbe Bild erneut öffnen.
3. Schütteln. **Erwartung**: „Nothing to undo" — der Verlauf startet leer.

---

## Manuelle Hardware-Integration (separat, vor „fertig")

| Prüfung | Kriterium |
|---|---|
| Schüttel-Erkennung | In ≥ **9 von 10** bewussten Links-Rechts-Bewegungen erscheint der Dialog (SC-006) |
| Fehlalarm | 2 min normales Halten/Bedienen (Cursor, Zoom, Malen) ohne bewusstes Schütteln → **kein** Dialog |
| Zoom-View-FPS | FPS-Anzeige im Zoom View mit aktivem Feature identisch zur Spec-008-Basislinie |
| Batterie/Sensor | Accelerometer läuft nur in Tile/Zoom/Pixel-View; im Auswahl-/Startscreen gestoppt |
| Schwellwert-Feinabgleich | `T` / `W` / `R` in `ShakeDetector` so einstellen, dass die beiden ersten Zeilen erfüllt sind; Endwerte in **ADR-044** eintragen (schließt Spec Open #4) |
