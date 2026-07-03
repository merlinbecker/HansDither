# Quickstart: Validierung Natives PDI-Speicherformat

**Feature**: 001-pdi-storage-format | **Date**: 2026-07-03

Manuelle Validierungsszenarien im Playdate Simulator (Projekt hat kein automatisiertes Test-Setup). Referenzen: [contracts/storage-format.md](contracts/storage-format.md), [data-model.md](data-model.md).

## Voraussetzungen

- Playdate SDK installiert; Build via `pdc Source HansDither.pdx`, Start im Simulator.
- Datenordner im Simulator: `<SDK>/Disk/Data/de.merlinbecker.hansdither/` — hier lassen sich `saves/index.json`, `saves/<id>/frames.json` direkt inspizieren.
- Die Szenarien setzen die UI-Anbindung aus Spec 002/003 voraus; bis dahin können sie über einen temporären Debug-Einstieg (Simulator-Konsole) gegen die ImageStore-API ausgeführt werden.

## Szenario 1: Round-Trip (SC-001, FR-001..FR-006)

1. Neues Bild anlegen (Name via Tastatur), in 3 Frames unterschiedliche Tiles malen.
2. Editor verlassen (Autosave) → App beenden → App neu starten → Bild öffnen.
3. **Erwartet**: Alle 3 Frames pixelidentisch; `saves/<id>/` enthält `frames.json`, `sheet.pdi`, `preview.pdi`; `frames.json` hat 3 Arrays à 375 Einträge.

## Szenario 2: Dedup-Invariante (SC-002, FR-002)

1. Bild anlegen, eine Fläche von ≥ 100 Zellen mit demselben selbstgemalten Tile füllen (insgesamt genau 4 unterschiedliche Tile-Inhalte inkl. Weiß/Schwarz).
2. Speichern; `frames.json` → `tileCount` prüfen und `sheet.pdi`-Abmessungen ansehen.
3. **Erwartet**: `tileCount` = 4; Sheet ist 64×16 px (4 Zellen); alle 100 Positionen referenzieren denselben Index.

## Szenario 3: Maximallast + Fortschritt (SC-004, FR-011, Messpunkt für Risiko R-12)

1. Bild mit 12 Frames erzeugen (Crank vorwärts bis zur Rotation), in mehreren Frames großflächig unterschiedlich malen.
2. Speichern und erneut laden; dabei loadingBar beobachten; Dateigröße von `frames.json` notieren.
3. **Erwartet**: Fortschritt durchgehend sichtbar, kein Freeze > ~1 s; `frames.json` ≤ ~25 KB; Laden stellt alle 12 Frames korrekt her. Messwerte in AD-017 (arc42) nachtragen.

## Szenario 4: Verwaltung (SC-003, FR-007, FR-009, FR-013)

1. 10+ Bilder anlegen (eines mit bereits vergebenem Namen versuchen).
2. Ein Bild kopieren, die Kopie ändern und speichern; danach ein anderes Bild löschen.
3. **Erwartet**: Namenskollision wird abgelehnt/mit Suffix gelöst; Kopie ist unabhängig (Original unverändert); nach Löschen ist der Ordner weg, `index.json` konsistent, übrige Bilder öffnen normal.

## Szenario 5: Defekte Speicherstände (SC-005, FR-010)

1. Bei geschlossener App im Datenordner manipulieren: (a) `sheet.pdi` eines Bildes löschen, (b) in `frames.json` eines anderen Bildes einen Index auf 999 setzen, (c) `index.json` löschen.
2. App starten und alle Bilder durchprobieren.
3. **Erwartet**: (a) Bild öffnet nicht, Fehlerstatus, kein Absturz; (b) betroffene Zelle wird weiß dargestellt, Rest korrekt; (c) neuer leerer Index, App startet sauber, keine Bildordner gelöscht.

## Szenario 6: Terminate-Hook (FR-005)

1. Bild im Editor offen, malen, dann Simulator-Menü „Exit Game" (löst `gameWillTerminate` aus).
2. App neu starten, Bild öffnen.
3. **Erwartet**: Letzter Malstand vorhanden; `lastEditedId` zeigt auf dieses Bild.

---

## Validierung

### Durchgeführte Tests (Implementierungsstand: 2026-07-03)

| Szenario | Status | Datum | Befund |
|---|---|---|---|
| **Szenario 1** (Round-Trip) | ⏳ pending | - | Implementierung abgeschlossen, Test im Simulator ausstehend |
| **Szenario 2** (Dedup-Invariante) | ⏳ pending | - | Hash-Funktion implementiert, Dedup-Logik noch ausstehend |
| **Szenario 3** (Maximallast) | ⏳ pending | - | Implementierung abgeschlossen, Test ausstehend |
| **Szenario 4** (Verwaltung) | ⏳ pending | - | API implementiert, Test ausstehend |
| **Szenario 5** (Defekte Speicherstände) | ⏳ pending | - | Grundlegende Fehlerbehandlung implementiert, Test ausstehend |
| **Szenario 6** (Terminate-Hook) | ⏳ pending | - | Hook vorbereitet, Integration mit TileRoom ausstehend |

### Debug-Testfunktion

In `Source/main.lua` ist eine Debug-Funktion `testImageStore()` verfügbar, die via Simulator-Konsole aufgerufen werden kann. Diese testet:
- Index-Erstellung
- Bild-Erstellung
- Bild-Auflistung
- Bild-Kopieren
- Bild-Laden
- Vorschaubild-Abruf

**Aufruf im Simulator**: In der Lua-Konsole `testImageStore()` eingeben.
