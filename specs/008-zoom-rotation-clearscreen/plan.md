# Implementation Plan: Zoom-Room-Performance, Pixel-Rotation und vereinfachte Frame-Verwaltung

**Branch**: `feature/0.3` | **Date**: 2026-07-22 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/008-zoom-rotation-clearscreen/spec.md`

## Summary

Drei rein clientseitige Änderungen in bestehenden Räumen (`ZoomRoom`,
`PixelRoom`, `EditorRoom`), keine neuen Dateien: (1) `ZoomRoom` ersetzt die
vollständige Neuzeichnung aller 576 Rasterzellen bei jeder Interaktion
durch einen einmalig aufgebauten Hintergrund-Cache (`cachedBackground`)
plus ein kleines Änderungs-Set (`changedCells`) — behebt sowohl das
gemeldete Ruckeln als auch die vermutete Navigationsblockade, die laut
Code-Review keine separate Ursache hat (research.md R1). (2) `PixelRoom`
erhält einen Rotations-Akkumulator (`rotationAccumDegrees`, analog zum
bestehenden `crankAccumDegrees`-Muster aus Spec 006) auf dem bisher
ungenutzten Crank-ohne-B-Eingabekanal; eine volle Umdrehung rotiert
`gridState` exakt per Index-Remap um 90° (kein SDK-Bildtransform, siehe
research.md R2/R3). (3) `EditorRoom` ersetzt den Systemmenü-Eintrag
"reset frame" (Spec 006/AD-032) vollständig durch "clear screen"
(`clearCurrentFrame()`, setzt den aktiven Frame auf den Voll-Weiß-Basis-
Index); `resetCurrentFrameToPrevious()` wird — anders als bei AD-032 —
komplett aus dem Code entfernt (research.md R4).

## Technical Context

**Language/Version**: Lua (Playdate SDK Lua-Runtime, lokal verifiziert
gegen SDK v3.0.6)

**Primary Dependencies**: Playdate SDK CoreLibs (`playdate.getCrankChange`,
`playdate.getCrankTicks` [B+Crank-Zoomkette unverändert],
`gfx.pushContext`/`gfx.popContext`, `image:draw()`,
`playdate.graphics.setScreenClipRect` [ergänzende Absicherung],
`playdate.getStats()`/Sampler [Performance-Nachweis]); bestehende
Projekt-Bausteine `ZoomRoom`/`PixelRoom`/`EditorRoom` (Spec 003/006),
`ImageStoreCodec` (Basistile-Invariante Index 1/2, Spec 001)

**Storage**: Keine neuen Formate/Dateien — liest/schreibt ausschließlich
die bereits vorhandene Laufzeitrepräsentation `imageData` (frames,
imagetable) sowie reinen Room-lokalen Laufzeit-Zustand (Cache-Image,
Änderungs-Set, Rotations-Akkumulator); keine Persistenz-Änderung

**Testing**: Headless-Tests (`lua tests/headless_tests.lua`, Constitution
V Gate 1) für alle logik-/arithmetikbasierten Anteile ohne echte
Hardware-Abhängigkeit (Cache-Invalidierungs-Trigger, Änderungs-Set-Pflege,
Rotations-Akkumulator-Arithmetik, Rotations-Algorithmus an einem
Test-Pixelmuster, `clearCurrentFrame()`-Array-Zuweisung, Menü-Inhalt) —
siehe quickstart.md "Headless-testbare Anteile". Performance UND
Crank-Rotationsgefühl MÜSSEN zusätzlich auf echter Hardware geprüft werden
(Constitution-Workflow, Simulator ist laut SDK-Doku spürbar schneller als
das Gerät); objektiver Performance-Nachweis über `playdate.getStats()`/
Sampler vor/nach dem Fix (research.md R1, quickstart.md Szenario 1). Gate
2 (`pdc Source "Hans Dither.pdx"`) MUSS nach jeder Implementierungs-Task
fehlerfrei durchlaufen (Constitution V).

**Target Platform**: Playdate (Device + Simulator), 400×240, 1-Bit

**Project Type**: Single project (Lua-App unter `Source/`)

**Performance Goals**: Zoom Room reagiert auf Cursorbewegung/Malstrich ohne
wahrnehmbare Verzögerung, äquivalent zum Tile-Editor (SC-001); Redraw pro
Interaktion beschränkt sich auf einen Bild-Blit plus höchstens wenige
geänderte Zellen statt eines Vollbild-Scans über 576 Zellen (FR-002);
objektiv nachgewiesener Rückgang der Game-CPU-Zeit gegenüber dem
Vorher-Zustand (research.md R1, keine feste ms-Zahl vorgegeben — siehe
Spec-Assumption zur Messmethode).

**Constraints**: Constitution I (SDK-First — `gfx.pushContext`/
`image:draw()` statt Neuerfindung eines Cache-Mechanismus, kein
`image:rotatedImage()`/`drawRotated()` wegen dokumentierter SDK-
Performance-Warnung, siehe research.md R3); Constitution II (keine neuen
Persistenzformate); Constitution IV (Wiederverwendung des
`crankAccumDegrees`-Musters aus Spec 006 für die neue Rotation statt
neuer Abstraktion; vollständige statt teilweise Entfernung toten Codes für
"Reset Frame", da FR-011 dies explizit fordert); System-Menü bleibt bei 3
Slots (kein neuer Slot, reiner Eintrags-Tausch wie schon bei AD-032)

**Scale/Scope**: 3 geänderte Dateien (`ZoomRoom.lua`, `PixelRoom.lua`,
`EditorRoom.lua`), 0 neue Dateien, 0 entfallende Dateien; betrifft 3 User
Stories, keine Backend-/Netzwerk-Berührung (Spec 004/005/007
unangetastet, Constitution-Randbedingung "Netzwerk (Sync-Ausnahme)"
bleibt unverändert erfüllt)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Prinzip | Prüfung | Status |
|---|---|---|
| I. SDK-First | Alle drei User Stories stützen sich auf bereits verifizierte SDK-Bausteine statt Eigenbau (research.md): `gfx.pushContext`/`image:draw()` für den Hintergrund-Cache (bereits im Projekt via `buildWorkingImage()` etabliert), `getCrankChange()` für die Rotations-Akkumulation (bereits in `EditorRoom.lua` etabliert, Spec 006), `playdate.getStats()`/Sampler für den Performance-Nachweis. Bewusst KEINE SDK-Bildtransformation (`rotatedImage`/`drawRotated`) für die Pixel-Rotation — dokumentierte SDK-Performance-Warnung, reiner Lua-Tabellen-Remap ist exakt und schneller (research.md R3). | PASS |
| II. Native Formate & PDI | Keine neuen Datenformate; alle Änderungen wirken innerhalb der bestehenden `imageData`-Laufzeitstruktur (Frame-Arrays, Imagetable-Basisindizes). | PASS |
| III. arc42-Pflege | Wird im selben Änderungsschnitt aktualisiert (siehe Architecture Governance unten): arc42 Kap. 5 (Bausteine: `ZoomRoom`/`PixelRoom`/`EditorRoom`), Kap. 6 (neue Laufzeitszenarien: Zoom-Redraw-Cache, Pixel-Rotation, Clear-Screen), Kap. 9 (AD-035/036/037), Kap. 10 (Qualitätsszenario Zoom-Performance), Kap. 11 (Risiken/technische Schuld), Kap. 12 (Glossar: "reset frame" durch "clear screen" ersetzt). | PASS |
| IV. Einfachheit | Hintergrund-Cache + Änderungs-Set statt SDK-Sprite-Dirty-Rect-Umbau (kleinerer, gezielterer Eingriff, research.md R1); Rotations-Akkumulator ist 1:1-Wiederverwendung des bestehenden `crankAccumDegrees`-Musters (kein neuer Automatentyp); Index-Remap statt Bild-Encode/Decode-Umweg (research.md R3); `clearCurrentFrame()` ist strukturell identisch zu `resetCurrentFrameToPrevious()`, nur mit konstanter Quelle statt Vorgänger-Frame. Vollständige Entfernung von `resetCurrentFrameToPrevious()` vermeidet Ansammlung weiteren toten Codes (FR-011). | PASS |
| V. Testpflicht | Beide Gates werden nach jeder Task ausgeführt (siehe quickstart.md Constitution-Gate). Headless-Testfälle für Cache-Invalidierung, Änderungs-Set, Rotations-Akkumulator-Arithmetik, Rotations-Algorithmus (bekanntes Testmuster, Rundlauf-Test über 4 Rotationen) und `clearCurrentFrame()`-Array-Zuweisung sind in quickstart.md/tasks.md eingeplant. Performance-Fix zusätzlich mit objektivem Hardware-Nachweis (`getStats()`/Sampler) statt rein subjektiver Bewertung. | PASS |

**Post-Design Re-Check (nach Phase 1)**: PASS — `data-model.md` und
`contracts/zoom-pixel-editor-updates.md` führen keine neuen
Abstraktionsschichten ein; alle neuen Zustände (`cachedBackground`,
`changedCells`, `backgroundDirty`, `rotationAccumDegrees`) sind einfache
Primitive/Tabellen im jeweils bereits zuständigen Room-Modul. Complexity
Tracking bleibt leer.

**Nutzer-gemeldeter Bug nach Implementierungsabschluss (behoben)**: Gemalte
Zellen im Zoom Room verschwanden beim nächsten Redraw (z. B. reine
Cursorbewegung) wieder und wurden erst nach Verlassen/Wiederbetreten des
Zoom Room sichtbar. Ursache: `ZoomRoom.lua:drawGrid()` leerte
`changedCells` fälschlich nach JEDEM Redraw statt nur beim Cache-Aufbau in
`buildBackgroundCache()` — der Cache selbst erfährt von der Änderung aber
nur bei einem vollen Rebuild. `data-model.md`/`ADR-035` beschrieben das
korrekte Verhalten bereits richtig ("wird beim Cache-Aufbau geleert"); nur
die Implementierung wich davon ab. Behoben durch Entfernen des überzähligen
`changedCells = {}` am Ende von `drawGrid()`, plus neuem Regressionstest in
`tests/headless_tests.lua` (siehe `tasks.md` T003/T004). Als direkte Folge
musste auch der bestehende Test "reine Cursorbewegung löst 0 Redraws aus"
präzisiert werden: das gilt nur auf einem frischen (unbearbeiteten)
Cache-Stand — sobald mindestens eine Zelle editiert wurde, wird sie ab
diesem Zeitpunkt bei JEDEM weiteren Redraw korrekt mit übermalt, bis der
nächste volle Rebuild stattfindet (das ist der eigentliche Zweck des Fixes,
kein neuer Kompromiss).

Secure-Architecture: **N/A bestätigt** — alle drei User Stories sind rein
lokale Rendering-/Editier-/Menü-Änderungen ohne Netzwerk-, Auth- oder
Persistenzformat-Berührung (Spec 004/005/007 unangetastet, Constitution-
Randbedingung "Netzwerk (Sync-Ausnahme)" bleibt erfüllt).

## Project Structure

### Documentation (this feature)

```text
specs/008-zoom-rotation-clearscreen/
├── plan.md                          # Diese Datei
├── research.md                      # Phase 0: R1-R4, SDK-Verifikation je User Story
├── data-model.md                    # Phase 1: neue Zustände je Room, Rotations-Formel
├── quickstart.md                    # Phase 1: Validierungsszenarien (Simulator + Hardware-Pflichtprüfung)
├── contracts/
│   └── zoom-pixel-editor-updates.md # Phase 1: neue Contracts (ZR-01..03, PR-01..04, EM-01..03)
├── checklists/
│   └── requirements.md              # bereits vorhanden (aus /speckit-specify)
└── tasks.md                         # Phase 2 (/speckit-tasks — nicht Teil dieses Laufs)
```

### Source Code (repository root)

```text
Source/
├── ZoomRoom.lua          # GEÄNDERT: drawGrid() nutzt cachedBackground + changedCells
│                         #   statt Vollbild-Scan (R1); Editier-/Commit-Logik unverändert
├── PixelRoom.lua         # GEÄNDERT: rotationAccumDegrees + rotateGridClockwise()/
│                         #   rotateGridCounterClockwise() auf Crank-ohne-B-Pfad (R2/R3);
│                         #   B+Crank-Zoomkette unverändert
├── EditorRoom.lua        # GEÄNDERT: buildSystemMenu() "reset frame" -> "clear screen";
│                         #   resetCurrentFrameToPrevious() entfernt, clearCurrentFrame() neu (R4)
└── tests/headless_tests.lua  # GEÄNDERT: neue Testfälle für R1/R2/R3/R4

arc42/                    # Kap. 5, 6, 9, 10, 11, 12 im selben Änderungsschnitt (siehe Architecture Governance)
arc42/adr/                # NEU: ADR-035 (Zoom-Redraw-Cache), ADR-036 (Pixel-Rotation-Mechanik), ADR-037 (Clear Screen ersetzt Reset Frame)
```

**Structure Decision**: Kein neuer Room, keine neue Datei — alle drei User
Stories sind Verhaltensänderungen INNERHALB bestehender Räume, die bereits
exakt die betroffenen Daten (`gridState`, Crank-Zustand, `imageData`,
Systemmenü) besitzen.

## Complexity Tracking

Keine Constitution-Verstöße — Tabelle entfällt.

## Architecture Governance (iSAQB-Preset)

- **Architektur-Arbeitsprodukte**: arc42 Kap. 5 (Bausteinsicht:
  `ZoomRoom`-Redraw-Cache, `PixelRoom`-Rotationslogik,
  `EditorRoom`-Systemmenü-Änderung), Kap. 6 (Laufzeitszenarien:
  Zoom-Redraw mit Hintergrund-Cache, Pixel-Rotation per Volldrehung,
  Clear-Screen-Ablauf), Kap. 9 (AD-035, AD-036, AD-037), Kap. 10
  (Qualitätsszenario Zoom-Room-Reaktionsfähigkeit, ergänzt QS-02), Kap. 11
  (Risiken/technische Schuld: Restrisiko unbestätigter Root-Cause,
  akzeptierter Wegfall der Frame-Schutzfunktion), Kap. 12 (Glossar:
  "reset frame"-Eintrag durch "clear screen" ersetzt). Kein neues
  `docs/architecture/`-Artefakt nötig — bestätigt N/A wie bereits in
  spec.md begründet (dieser Pfad wird im Projekt ausschließlich für das
  Backend-Sicherheitsreview genutzt, Spec 005/007); die
  arc42-Kapitelaktualisierung genügt für dieses rein clientseitige
  Editor-Feature. Owner: Entwickler; Evidenz: Feature-Branch-Diff der
  arc42-Kapitel (wird in diesem Schritt bereits vorgenommen, siehe unten).
- **ADRs**:
  - **AD-035** (NEU, **entschieden**): "Statischer Hintergrund-Cache +
    Änderungs-Set statt Vollbild-Neuzeichnung im Zoom Room" — Hintergrund:
    `drawGrid()` berechnete bislang bei jeder Interaktion alle 576 Zellen
    plus ~2400 Gitterlinien neu (research.md R1); Entscheidung:
    `gfx.pushContext`/`image:draw()`-Cache (bereits im Projekt via
    `buildWorkingImage()` etabliertes Muster) plus `changedCells`-Liste
    statt eines größeren Umbaus auf `playdate.graphics.sprite`-Dirty-Rects.
    Status: entschieden, dokumentiert in
    `arc42/adr/ADR-035-Zoom-Room-Redraw-Cache.md`.
  - **AD-036** (NEU, **entschieden**): "Pixel-Rotation via Crank-Volldrehung
    ohne B, exakter Tabellen-Remap statt SDK-Bildtransformation" —
    Hintergrund: Crank-ohne-B ist im Pixel Room aktuell wirkungslos
    (freier Eingabekanal); `image:rotatedImage()`/`drawRotated()` sind
    laut SDK-Doku für Transformationen "quite slow" und für
    Nicht-180°-Winkel potenziell dimensionsverändernd/resamplingbehaftet
    (research.md R3). Entscheidung: `getCrankChange()`-Akkumulator (analog
    `crankAccumDegrees`, Spec 006) plus direkter 16×16-Index-Remap
    (`new[r][c] = old[17-c][r]`). Status: entschieden, dokumentiert in
    `arc42/adr/ADR-036-Pixel-Rotation-Index-Remap.md`.
  - **AD-037** (NEU, **entschieden**, Projektinhaber-Vorgabe): "'Clear
    Screen' ersetzt 'Reset Frame' vollständig im Systemmenü" — Hintergrund:
    Projektinhaber lässt die ursprüngliche Schutzidee für versehentlich
    bemalte Frames fallen (spec.md Assumptions); im Unterschied zu AD-032
    (Spec 006, "delete frame" blieb als toter Code erhalten) verlangt
    FR-011 dieser Spec die VOLLSTÄNDIGE Entfernung von
    `resetCurrentFrameToPrevious()`, nicht nur ihres Menü-Zugriffs.
    Entscheidung: dritter Menü-Slot zeigt `"clear screen"`
    (`clearCurrentFrame()`, setzt aktiven Frame auf Basis-Index 1);
    `resetCurrentFrameToPrevious()` wird gelöscht. Status: entschieden,
    dokumentiert in
    `arc42/adr/ADR-037-Clear-Screen-ersetzt-Reset-Frame.md`. Owner:
    Projektinhaber.
- **Risiko-/Schulden-Review**:
  - **Risiko**: Der genaue Ursachenbefund für die ursprünglich vermutete
    "tieferliegende Navigationsblockade" ist nicht durch einen isolierten
    Bug bestätigt, sondern durch Code-Review als wahrscheinlich identische
    Ursache wie das Ruckeln eingestuft (research.md R1). Mitigation:
    objektiver Hardware-Nachweis (`getStats()`/Sampler) vor Abschluss
    (quickstart.md Szenario 1); sollte nach dem Fix weiterhin eine
    Blockade auftreten, ist dies ein Follow-up außerhalb dieser Spec.
  - **Risiko (akzeptiert)**: Vollständiger Wegfall von "Reset Frame" ohne
    Schutzfunktion für versehentlich bemalte Frames — bewusste
    Projektinhaber-Entscheidung (siehe spec.md Assumptions), nicht
    mitigiert.
  - **Technische Schuld — abgebaut**: `resetCurrentFrameToPrevious()` wird
    aktiv entfernt statt (wie `deleteCurrentFrame()` seit AD-032) als
    toter Code liegen zu bleiben (FR-011, AD-037).
  - N/A: Sicherheitsarchitektur (rein lokale Rendering-/Editier-/
    Menü-Änderungen, keine Netzwerk-/Auth-/Datenspeicherungs-Berührung,
    Constitution-Randbedingung unverändert erfüllt).
- **Offen (Open)**: Keine — alle drei ADR-Kandidaten aus spec.md sind mit
  dieser Planung entschieden (AD-035/036/037); verbleibt nur das oben
  genannte Restrisiko zum Navigations-Ursachenbefund, das über den
  quickstart.md-Hardware-Nachweis abgesichert wird.
