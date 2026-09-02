# Contract: Headless-Test-Mock-Oberfläche (Accelerometer)

**Feature**: `specs/011-shake-to-undo`

`tests/headless_tests.lua` lädt die echten `Source/*.lua` mit **strikten** Playdate-Mocks: jeder Zugriff auf eine nicht gemockte SDK-Methode wirft „erfundene SDK-API?". Dieses Feature nutzt zum ersten Mal den Beschleunigungssensor → der `playdate`-Mock MUSS um genau diese Symbole erweitert werden, sonst schlägt schon das Laden von `ShakeDetector.lua` / der modifizierten Räume fehl.

---

## Zu ergänzende Symbole im `playdate`-Mock

| Symbol | Mock-Verhalten | Test-Steuerung |
|---|---|---|
| `playdate.startAccelerometer()` | setzt Modulflag `accelRunning = true`; erhöht `accelStartCount` | `accelRunning`, `accelStartCount` lesbar |
| `playdate.stopAccelerometer()` | `accelRunning = false`; erhöht `accelStopCount` | lesbar |
| `playdate.readAccelerometer() -> x, y, z` | erhöht `accelReadCount`; liefert `accelXYZ[1], accelXYZ[2], accelXYZ[3]` | `accelXYZ` (Default `{0, 0, 1}`) testseitig setzbar Frame für Frame |

Optional (nur falls der Code es abfragt — sonst weglassen, um den strikten Mock scharf zu halten):

| Symbol | Mock-Verhalten |
|---|---|
| `playdate.accelerometerIsRunning() -> bool` | `return accelRunning` |

**Platzierung**: im selben Block wie `buttonIsPressed` / `getCrankTicks` / `getCrankChange` (der bestehende `playdate`-Mock-Tabellenliteral). Keine Änderung an `strictTable` nötig — die neuen Felder sind reguläre Funktions­einträge.

---

## Beispiel-Nutzung im Testabschnitt „Spec 011"

```lua
-- Schüttel-Sequenz simulieren: pro "Frame" accelXYZ setzen, dann room:update()
accelXYZ = { 1.0, 0, 0 };  nowMs = 0;    EditorRoom:update()   -- +x-Ausschlag
accelXYZ = { -1.0, 0, 0 }; nowMs = 200;  EditorRoom:update()   -- -x-Ausschlag  -> Kante
check(undoPromptOpenedWith == "Undo Clear Screen?", "Schuetteln oeffnet den Undo-Dialog")

-- Fehlalarm: 300 ruhige Frames
for i = 1, 300 do accelXYZ = {0.05, 0, 0.99}; nowMs = i*33; EditorRoom:update() end
check(not UndoPrompt.isOpen(), "Ruhiges Halten oeffnet keinen Dialog")
```

`nowMs` wird bereits vom bestehenden Zeit-Mock (`playdate.getCurrentTimeMilliseconds`) geliefert — dieselbe Modulvariable, die auch Bauchbinde-/Picker-Timeouts in den vorhandenen Tests steuert.

---

## Nicht-Ziele des Mocks

- Kein physikalisches Sensormodell (Rauschen, Gravitationsvektor-Rotation). Die Tests prüfen den **Zustandsautomaten** (`ShakeDetector`), nicht die reale Sensorcharakteristik.
- Reale g-Werte, die 9/10-Erkennung ohne Fehlalarm liefern → **Hardware-Test** (Spec Open #4, ADR-044).
