# Quickstart: Validierung Editor-UI-Verbesserungen

**Feature**: 006-editor-ui-polish | **Purpose**: End-to-End-Validierung der sechs UI-Korrekturen im Playdate Simulator (+ punktuelle Hardware-Prüfung für Crank-Gefühl)

---

## Vorbereitung

### Voraussetzungen
- [ ] Playdate SDK installiert (`pdc` im PATH, verifiziert: v3.0.6)
- [ ] Lua-Interpreter für Headless-Tests (`lua tests/headless_tests.lua`)
- [ ] Mind. ein Test-Bild mit ≥2 Frames und mehr als 30 unterschiedlichen Tiles im Editor angelegt (für US5-Truncation-Test ggf. ein zweites Bild mit >120 Tiles)

### Constitution-Gate (Prinzip V, vor jeder Abschlussmeldung)
1. `lua tests/headless_tests.lua` → MUSS mit "ALLE TESTS BESTANDEN" enden
2. `pdc Source "Hans Dither.pdx"` → MUSS fehlerfrei durchlaufen

---

## Validierungsszenarien

### Szenario 1: Zoom-View zeigt echte 16×16-Pixel (US1, FR-007/008/009)
**Ziel**: Subpixel-Hintergrund statt einfarbiger Zellen

**Schritte**:
1. Ein Tile mit gemischtem Schwarz/Weiß-Muster im PixelRoom anlegen (z. B. Schachbrett)
2. Zurück in den EditorRoom, dann per B+Crank in den ZoomRoom dieses Tiles zoomen

**Erwartet**: Jede unbearbeitete 10×10-Zelle zeigt bis zu 4 unterschiedlich gefärbte 5×5-Quadranten (die realen Quellpixel); nach dem ersten Malstrich auf einer Zelle wird genau diese Zelle einfarbig (CR-04)

**Prüfungen**:
- [ ] Vier-Quadranten-Darstellung vor jeder Bearbeitung sichtbar
- [ ] Nach Bearbeitung: Zelle einfarbig (kein Rückfall in Quadranten-Darstellung)
- [ ] Editier-Verhalten (Malstrich, Commit, Dedup) unverändert gegenüber vorher

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 2: Frame-Wechsel erst nach voller Kurbel-Umdrehung (US2, FR-004/005/006)
**Ziel**: Keine ungewollten Frame-Wechsel bei Teildrehungen

**Schritte**:
1. Bild mit ≥3 Frames öffnen, Frame 2 aktiv
2. Crank im Simulator um 270° im Uhrzeigersinn ziehen, dann loslassen (Slider stehen lassen)
3. Crank um weitere 90° im Uhrzeigersinn ziehen (insgesamt 360°, ohne Zwischenstopp der Kurbel-Bewegung als Reset)
4. Crank um 270° drehen, dann um 90° in die Gegenrichtung zurückdrehen (netto 180°)

**Erwartet**: Nach Schritt 2 bleibt Frame 2 aktiv; nach Schritt 3 wechselt die Anzeige genau einmal zu Frame 3; nach Schritt 4 bleibt der zuletzt angezeigte Frame unverändert

**Prüfungen**:
- [ ] AS1 (270°, kein Wechsel)
- [ ] AS2/AS3 (360° gesamt, genau ein Wechsel)
- [ ] AS4 (Teildrehung + Einklappen, kein Wechsel)
- [ ] Edge Case: 270° vor + 90° zurück (netto 180°) löst KEINEN Wechsel aus
- [ ] **Hardware-Zusatzprüfung**: dasselbe auf echtem Gerät — Kurbel-Gefühl bei `getCrankChange()` kann von der Simulator-Slider-Näherung abweichen
- [ ] **Regressionsprüfung (CR-01)**: B+Crank-Zoomkette (rein/raus) funktioniert weiterhin unverändert im selben Testlauf

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 3: Bauchbinde blendet aus und weicht dem Cursor aus (US3, FR-001/002/003)
**Ziel**: Automatisches Ausblenden + Cursor-abgewandte Positionierung

**Schritte**:
1. EditorRoom öffnen, Cursor in die rechte Bildschirmhälfte bewegen, 5+ Sekunden nichts tun
2. Cursor in die linke Bildschirmhälfte bewegen (beliebige Eingabe)

**Erwartet**: Nach Schritt 1 blendet die Bauchbinde nach 5s aus; jede Eingabe blendet sie sofort wieder ein; bei Cursor rechts erscheint sie links, bei Cursor links erscheint sie rechts (CR-02/CR-03)

**Prüfungen**:
- [ ] Ausblenden nach exakt ~5s Inaktivität
- [ ] Sofortiges Wiedereinblenden bei D-Pad/A/B/Crank-Eingabe
- [ ] Seiten-Logik: rechts↔links korrekt invers zur Cursorposition
- [ ] Status-Bauchbinde (Fehlertext links) bleibt von dieser Logik unberührt

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 4: "Reset Frame" kopiert den Vorgänger-Frame (US4, FR-014/015)
**Ziel**: Frame-Inhalt auf Vorgänger zurücksetzen

**Schritte**:
1. Frame 1 und Frame 2 mit unterschiedlichem Inhalt anlegen
2. Auf Frame 2 im System-Menü "reset frame" auswählen (CR-08 — ersetzt den bisherigen "delete frame"-Eintrag)
3. Auf Frame 1 (kein Vorgänger) dieselbe Aktion versuchen
4. Prüfen, dass "delete frame" nicht mehr im Menü erscheint (bewusste Konsequenz von AD-032)

**Erwartet**: Frame 2 entspricht danach exakt Frame 1; auf Frame 1 hat die Aktion keine Wirkung

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 5: Kontext-/Pause-Ansicht mit Tile-Übersicht (US5, FR-010/011/012/013)
**Ziel**: `setMenuImage` zeigt Tile-Raster + Zähler + Metainformationen

**Schritte**:
1. Bild mit bekannter Tile-Anzahl (z. B. 30) und Frame-Anzahl (z. B. 4) öffnen
2. Menü-Taste drücken (Simulator: entsprechende Taste/Menüpunkt für System-Pause)
3. Zweites Bild mit >120 unterschiedlichen Tiles öffnen, Menü-Taste erneut drücken

**Erwartet**: Pause-Bild zeigt bis zu 120 Tile-Vorschauen im 12×10-Raster (links, `x<200`), "Tiles: 30" unten links, "Frames: 4" als Metainformation; bei >120 Tiles zeigt das Raster nur einen Ausschnitt, die Zahl bleibt korrekt vollständig (CR-06/CR-07)

**Prüfungen**:
- [ ] Alle Inhalte liegen sichtbar links (nicht vom System-Menü verdeckt)
- [ ] Gesamtzahl basiert auf tatsächlich referenzierten Tile-Indizes, nicht auf Imagetable-Länge
- [ ] Truncation bei >120 Tiles: Zahl bleibt korrekt, Raster zeigt Teilmenge
- [ ] Pause-Bild wird NICHT jeden Frame neu berechnet (Performance — z. B. per Log-Zeile in `buildPauseMenuImage()` verifizieren, dass sie nur bei tatsächlichem Pausieren aufgerufen wird)

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

### Szenario 6: Titelscreen zeigt animierten Hintergrund mit VHS-Effekt (US6, FR-016/017/018)
**Ziel**: Vollbild-Animation nur für den selektierten Eintrag

**Schritte**:
1. SelectionRoom öffnen, ein Bild mit 3 Frames selektieren, kurz warten (Lazy-Load)
2. Selektion zügig zwischen mehreren Bildern hin- und herbewegen
3. Ein Bild mit genau 1 Frame selektieren

**Erwartet**: Der Hintergrund des selektierten Bilds spielt dessen Frames vollflächig ab, überlagert von sichtbarem VHS-Störeffekt; andere Einträge bleiben statische Kreise; bei schnellem Wechsel kein Leerbild/Sprung (CR-09); 1-Frame-Bild zeigt Standbild mit weiterhin aktivem VHS-Effekt (CR-11)

**Prüfungen**:
- [ ] Nur der selektierte Eintrag ist vollflächig animiert
- [ ] Andere Einträge unverändert als Kreise erkennbar (FR-018)
- [ ] Kein sichtbarer Leerbild-Frame beim schnellen Selektionswechsel
- [ ] VHS-Effekt sichtbar, aber nicht so aufdringlich, dass der Bildinhalt unkenntlich wird (Open-Punkt, visuell kalibrieren)
- [ ] 1-Frame-Fall: kein Frame-Wechsel-Flackern, VHS-Effekt trotzdem aktiv

**Status**: [ ] Nicht getestet | [ ] Bestanden | [ ] Fehlgeschlagen

---

## Headless-testbare Anteile (Constitution V, in tasks.md als Testfälle einzuplanen)

- Crank-Akkumulator-Arithmetik (R1): reine Zahlenlogik, mockbar ohne echten Crank
- Bauchbinde-Sichtbarkeit/-Seite (R3): mockbare Zeit (`getCurrentTimeMilliseconds`) + Cursor-Position
- "Reset Frame"-Kopie (R7): reine Array-Kopie, kein SDK-Bezug
- Tile-Zähl-Logik der Pause-Ansicht (R4, `totalDistinctTileCount`): reine Iteration über `imageData.frames`

Rein visuelle/zeitbasierte Anteile (Subpixel-Rendering, VHS-Dither-Optik,
Titelscreen-Animation, tatsächliches Kurbel-Gefühl) bleiben manuelle
Simulator-/Hardware-Szenarien oben — nicht sinnvoll headless prüfbar.
