# Quickstart: Validierung Zoom-Room-Performance, Pixel-Rotation und "Clear Screen"

**Feature**: 008-zoom-rotation-clearscreen | **Purpose**: End-to-End-Validierung der drei Anpassungen im Playdate Simulator (+ verpflichtende Hardware-Prüfung für Performance und Crank-Rotation)

---

## Vorbereitung

### Voraussetzungen
- [X] Playdate SDK installiert (`pdc` im PATH, verifiziert: v3.0.6)
- [X] Lua-Interpreter für Headless-Tests (`lua tests/headless_tests.lua`)
- [ ] Ein Test-Bild mit ≥2 Frames und mindestens einem asymmetrischen
      Pixelmuster in mindestens einem Tile (für den Rotations-Test)
- [ ] Echtes Playdate-Gerät verfügbar (Performance- und Crank-Gefühl sind
      laut Constitution zwingend hardware-nah zu prüfen, nicht nur im
      Simulator)

### Constitution-Gate (Prinzip V, vor jeder Abschlussmeldung)
1. `lua tests/headless_tests.lua` → MUSS mit "ALLE TESTS BESTANDEN" enden — **[X] bestanden** (alle drei User Stories, inkl. neuer Testfälle für Cache-Invalidierung, Rotations-Algorithmus und Clear-Screen)
2. `pdc Source "Hans Dither.pdx"` → MUSS fehlerfrei durchlaufen — **[X] bestanden**
3. Rauchtest im Playdate Simulator (`open -a "Playdate Simulator" "Hans Dither.pdx"`): App startet und läuft mehrere Sekunden ohne Absturz — **[X] bestanden**. Ersetzt NICHT die interaktive Validierung der Szenarien unten (Crank drehen, Richtungstasten halten, Menüpunkte auswählen) — dafür ist manuelle Bedienung durch einen Menschen nötig, außerhalb der Möglichkeiten dieser Sitzung.

---

## Validierungsszenarien

### Szenario 1: Zoom Room reagiert ohne Ruckeln (US1, FR-001/002/003/004)
**Ziel**: Cursorbewegung und Malen im Zoom Room fühlen sich wie im
Tile-Editor an, keine Blockaden

**Schritte**:
1. Auf echtem Gerät in den Zoom Room zoomen (B+Crank vorwärts)
2. Richtungstaste 5+ Sekunden gehalten in alle vier Richtungen bewegen
3. Währenddessen mehrfach A drücken (Malstrich über mehrere Zellen)
4. `playdate.getStats()`- bzw. Sampler-Messung (Simulator: Sampler-Button)
   vor und nach dem Fix vergleichen

**Erwartet**: Keine wahrnehmbare Verzögerung oder Aussetzer während der
gesamten Sequenz; die gemessene "game"-Zeit pro Frame ist gegenüber dem
Vorher-Zustand spürbar gesunken (objektiver Nachweis, nicht nur Eindruck)

**Prüfungen**:
- [x] Cursorbewegung bleibt über die vollen 5 Sekunden gleichmäßig flüssig
- [x] Malstrich über mehrere Zellen hinweg korrekt und ohne Aussetzer
- [x] Alle bestehenden Zoom-Room-Funktionen (Rasteranzeige, Invert, "All
      Similar", Out-of-Bounds, Dedup-Commit) unverändert funktionsfähig
- [x] **Hardware-Pflichtprüfung**: dieselbe Sequenz auf echtem Gerät, nicht
      nur im Simulator (Simulator-Performance ist laut SDK-Doku spürbar
      besser als auf dem Gerät)
- [ ] Objektive Messung (`getStats()`/Sampler) zeigt reduzierte CPU-Last —
      **nicht durchgeführt**: Projektinhaber hat auf echter Hardware
      gespielt und keine Aussetzer/Ruckler mehr bemerkt (subjektiver
      Eindruck), aber keinen formalen Vorher/Nachher-Messwert erfasst

**Status**: [x] Bestanden (subjektiv auf echter Hardware — Befund: "keine
Aussetzer mehr gemerkt"; kein objektiver `getStats()`/Sampler-Vergleich
durchgeführt) | [ ] Fehlgeschlagen

---

### Szenario 2: Pixelbild per Volldrehung rotieren (US2, FR-005/006/007/008)
**Ziel**: 90°-Rotation im Uhrzeigersinn nach einer vollen Kurbelumdrehung, exakt und ohne Auflösungsverlust

**Schritte**:
1. Im Pixel Room ein asymmetrisches Muster zeichnen (z. B. ein "L")
2. Crank um 270° im Uhrzeigersinn drehen, dann loslassen (Slider stehen lassen)
3. Crank um weitere 90° im Uhrzeigersinn drehen (insgesamt 360° netto)
4. Vier weitere volle Umdrehungen vorwärts hintereinander durchführen
5. Eine volle Umdrehung rückwärts durchführen

**Erwartet**: Nach Schritt 2 unverändertes Muster; nach Schritt 3 ist das
Muster exakt um 90° im Uhrzeigersinn gedreht (jedes Pixel an der
rechnerisch korrekten Position); nach Schritt 4 (4× 90° = 360°) entspricht
das Bild wieder exakt dem Ausgangsmuster; nach Schritt 5 ist das Muster um
90° gegen den Uhrzeigersinn gedreht

**Prüfungen**:
- [x] Teildrehung (270°) löst keine sichtbare Rotation aus
- [x] Volle Umdrehung (360° netto) rotiert exakt 90° im Uhrzeigersinn
- [x] Vierfache Rotation ergibt wieder das exakte Ausgangsbild (Rundlauf)
- [x] Rückwärtsdrehung rotiert symmetrisch gegen den Uhrzeigersinn
- [x] Kein Pixel geht verloren, keine Kanten-Unschärfe (exakter Remap statt SDK-Bildtransformation)
- [x] Nach dem Herauszoomen ist die Rotation im Editor/Zoom Room sichtbar (Dedup-Commit-Pfad unverändert)
- [x] **Regressionsprüfung**: B+Crank-Zoom-Out aus dem Pixel Room funktioniert weiterhin unverändert im selben Testlauf

**Status**: [x] Bestanden (Befund: "geht super", auf echter Hardware getestet) | [ ] Fehlgeschlagen

---

### Szenario 3: "Clear Screen" ersetzt "Reset Frame" (US3, FR-011/012/013/014/015)
**Ziel**: Aktiven Frame vollständig leeren, andere Frames unberührt, "Reset Frame" nicht mehr auffindbar

**Schritte**:
1. Bild mit ≥2 Frames öffnen, in Frame 1 und Frame 2 unterschiedliche Muster malen
2. Frame 2 aktiv, Systemmenü öffnen
3. "clear screen" auswählen
4. Zu Frame 1 wechseln und dessen Inhalt prüfen
5. "clear screen" auf einem bereits leeren Frame erneut auslösen

**Erwartet**: Nach Schritt 3 ist Frame 2 vollständig weiß; Frame 1 (Schritt
4) zeigt weiterhin sein ursprüngliches Muster, unverändert; Schritt 5
bleibt wirkungslos (Frame bleibt weiß, keine Fehler)

**Prüfungen**:
- [x] Systemmenü zeigt "clear screen" an der Stelle des früheren "reset frame"
- [x] "reset frame" ist an KEINER Stelle der Oberfläche mehr auffindbar
- [x] Aktiver Frame ist nach "clear screen" vollständig weiß
- [x] Anderer Frame bleibt unverändert
- [x] Frame-Anzahl und -Reihenfolge unverändert
- [x] Wiederholtes "clear screen" auf bereits leerem Frame ist idempotent (kein Fehler, keine Änderung)

**Status**: [x] Bestanden (auf echter Hardware getestet) | [ ] Fehlgeschlagen

---

## Headless-testbare Anteile (Constitution V, in tasks.md als Testfälle einzuplanen)

- Zoom-Room-Cache-Invalidierung: `backgroundDirty` wird bei
  `setFromEditorContext()`/`setNewTile()`/`updateExistingTile()` gesetzt,
  NICHT bei reiner Cursorbewegung (mockbar ohne echtes Rendering;
  **korrigiert bei der Implementierung**: `showGridLines` ändert sich
  ausschließlich innerhalb von `setFromEditorContext()`, es gibt keinen
  separaten Live-Toggle in einer laufenden Zoom-Room-Sitzung, siehe
  data-model.md).
- `changedCells`-Pflege: `paintCurrentCell()` fügt Zellen genau einmal
  hinzu (keine Duplikate bei mehrfachem Malen derselben Zelle).
- Rotations-Akkumulator-Arithmetik (`rotationAccumDegrees`): Teildrehung
  löst keine Rotation aus; Richtungswechsel heben sich auf; exakt 360°
  löst genau eine Rotation aus (analog zu den bestehenden Testfällen für
  `crankAccumDegrees`, Spec 006 T005).
- Rotations-Algorithmus (`rotateGridClockwise`/`rotateGridCounterClockwise`):
  bekanntes asymmetrisches 16×16-Testmuster vor/nach Rotation exakt
  vergleichen; vierfache Rotation ergibt wieder das Ausgangsmuster.
- `clearCurrentFrame()`: setzt alle 375 Indizes auf `1`; andere Frames
  bleiben unverändert; Menü enthält `"clear screen"` und NICHT mehr
  `"reset frame"` (analog zum bestehenden Testmuster für "reset frame"
  vs. "delete frame", Spec 006 T013).
- Regressionstest: B+Crank-Zoomkette (ZoomRoom/PixelRoom) bleibt in allen
  drei User Stories unverändert funktionsfähig.
