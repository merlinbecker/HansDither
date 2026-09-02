# ADR-044: Schüttel-Erkennung als Eigenlogik auf `playdate.readAccelerometer`

## Status
✅ **Umgesetzt** (Spec 011, US1) — `Source/ShakeDetector.lua`,
`Source/EditorRoom.lua` (`onShakeSample`, Accelerometer-Lebenszyklus),
`Source/ZoomRoom.lua` / `Source/PixelRoom.lua` (Sensor-Polling pro Frame).
Endgültige `T/W/R`-Werte: **offen bis zum Hardware-Test** (Spec Open #4,
siehe *Offen*).

## Kontext
Spec 011 löst den Undo-Dialog durch **einmaliges Schütteln nach links und
rechts** aus (ausdrücklicher Nutzerwunsch). Das Playdate SDK bietet dafür
**kein** fertiges Primitiv:

- `playdate.readAccelerometer()` liefert nur rohe `(x, y, z)` in g.
- Es gibt **kein** Shake-/Gesten-Ereignis in den CoreLibs
  (`grep` über die SDK-CoreLibs → nichts; research.md R1).
- Der Sensor ist im Projekt bisher **ungenutzt** (`grep` über `Source/`
  → 0 Treffer) ⇒ **neue Plattformfähigkeit**. Die Spec-010-Randbedingung
  „keine neuen Plattformfähigkeiten" gilt ab hier nicht mehr
  (arc42 Kap. 2 nachgezogen).

Damit ist Eigenlogik unumgänglich — eine **begründete SDK-Abweichung**
nach Constitution I.

## Entscheidungs-Treiber
- Erkennen werden soll die **Richtungssequenz** „links und rechts", nicht
  bloß „Erschütterung" — sonst löst Gehen/Ablegen aus (Fehlalarm, SC-006).
- **Headless-Testbarkeit** (Constitution V): die Erkennung darf keine
  SDK-Objekte berühren, damit synthetische Sample-Folgen sie prüfen können.
- **Batterie / Zoom-View-FPS** (Spec 008 hat den Zoom-View mühsam flüssig
  bekommen): der Sensor läuft nur in den drei Editier-Views, das Polling
  ist ein einziger `readAccelerometer()` + ein Zustandsschritt pro Frame.
- Der Bestätigungsdialog ist die **zweite Sicherung** — ein seltener
  Fehlalarm kostet nur einen B-Druck.

## Optionen

| Option | Vorteile | Nachteile |
|--------|----------|-----------|
| **A: Eigener X-Achsen-Zustandsautomat (`±T`-Peaks, `W`-Fenster, `R`-Refraktärzeit) in `ShakeDetector.lua`** | erkennt die geforderte Links-Rechts-Sequenz; SDK-frei → headless testbar; winziger Zustand, eine Rechenoperation/Frame | `T/W/R` müssen am Gerät justiert werden |
| B: Betrags-Schwelle `sqrt(x²+y²+z²) > T` | trivial | erkennt keine Richtungssequenz; anfällig für Geh-Fehlalarme; „links und rechts" nicht abgebildet |
| C: Menüeintrag „undo" statt Geste | kein Sensor | die 3 Systemmenü-Slots sind belegt (save+exit / clear screen / show grid); Nutzer wollte ausdrücklich die Geste |
| D: Tastenkombination | kein Sensor | alle Tasten + Crank sind in den Editier-Views belegt (A malen, B Zoom-Out/Pipette/Nav, Crank Zoomkette/Picker) |

## Entscheidung
**Option A.** `ShakeDetector.new(opts?) -> d` mit `d:feed(x, y, z, nowMs)
-> bool` und `d:reset()`:

- Merke den Zeitpunkt des letzten Peaks `x > +T` und des letzten Peaks
  `x < −T` (X = Geräte-Längsachse).
- Liegen beide Polaritäten **innerhalb `W` ms** vor → **Kante** (Rückgabe
  `true`), Merker leeren, `R` ms Refraktärsperre setzen.
- Während der Sperre feuert `feed` nie.
- `feed` alloziert im Normalfall nichts.

**Startparameter** (Hardware-Tuning): `T = 0.85 g`, `W = 500 ms`,
`R = 1200 ms`.

**Lebenszyklus** (`EditorRoom`/`ZoomRoom`/`PixelRoom`):
`playdate.startAccelerometer()` in `entered()` (idempotent),
`playdate.stopAccelerometer()` beim Rücksprung zu `SelectionRoom`
(`EditorRoom` „no image"-Zweig + Load-/Save-Callbacks). In der
`FrameManagementView` wird der Sensor **nicht** ausgewertet (B ist dort
durch die Halte-Geste belegt, ADR-046 / research.md R6).

Jeder der drei Editier-Views liest einmal pro `update()`
`playdate.readAccelerometer()` und reicht das Sample an
`EditorRoom:onShakeSample(x, y, z, commitAndReturn?)` weiter. `EditorRoom`
besitzt die eine `ShakeDetector`-Instanz — Zoom-/Pixel-View füttern sie
nur.

### Begründung
- Der X-Achsen-Automat ist die einfachste Form, die „einmal links, einmal
  rechts" von „gerüttelt" unterscheidet.
- `nowMs` wird als Parameter hereingereicht (`playdate.getCurrentTimeMilliseconds()`
  im Aufrufer) → `feed` bleibt eine reine Funktion des Sample-Stroms und
  ist mit einer Mock-Uhr Frame-für-Frame testbar (R8/R9).
- Ein Detektor in `EditorRoom` statt drei: FR-010 (Geste in drei Views)
  bleibt an einer Stelle.

### Konsequenzen
- **Positiv**: SDK-frei, headless voll abgedeckt (V12–V16: saubere Folge
  feuert; 300 ruhige Samples feuern nie; Peaks > `W` auseinander feuern
  nie; nur positive Peaks feuern nie; Refraktärsperre unterdrückt das
  zweite Feuern). Sensor nur in den Editier-Views aktiv.
- **Negativ / offen**: `T/W/R` sind Startwerte. Die reale g-Kurve, die die
  SC-006-Quote (≥ 9/10 bewusste Bewegungen, 2 min ohne Fehlalarm) trifft,
  ist Hardware-Tuning. Die Justierung ändert `Source/ShakeDetector.lua` →
  eigener `buildNumber`-+1-/`pdc`-Zyklus, nicht bloß ein ADR-Edit.
- **Neue Plattformfähigkeit**: Accelerometer ist ab Spec 011 in Benutzung
  (arc42 Kap. 2). Batterie-Hinweis dort: Sensor nur Tile/Zoom/Pixel-View.

## Offen (Manuelle Hardware-Integration, Spec Open #4 / Tasks T042/T044)
- `T/W/R` am Playdate-Gerät justieren, bis ≥ 9/10 bewusste Links-Rechts-
  Bewegungen erkannt werden und 2 min normales Bedienen keinen Fehlalarm
  erzeugt. **Endwerte hier nachtragen** und Spec Open #4 schließen.
- Zoom-View-FPS vor/nach dem Sensor-Polling gegen die Spec-008-Basislinie
  prüfen (Risiko R-27, Kap. 11).

## Related
- [ADR-045: Undo-Modell — 3 Schritte, sitzungslokal](ADR-045-Undo-Modell-3-Schritt-sitzungslokal.md)
- [ADR-046: Modaler Undo-Dialog](ADR-046-Modaler-Undo-Dialog.md)
- [ADR-036: Pixel-Rotation Index-Remap](ADR-036-Pixel-Rotation-Index-Remap.md) (verwandtes Muster: exakte Eigenlogik auf Rohdaten statt SDK-Bildtransform)
- [specs/011-shake-to-undo/research.md: R1, R8, R9](../../specs/011-shake-to-undo/research.md)
- [specs/011-shake-to-undo/spec.md: FR-010, FR-011, FR-017, SC-006](../../specs/011-shake-to-undo/spec.md)
