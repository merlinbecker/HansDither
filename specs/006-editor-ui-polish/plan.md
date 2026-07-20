# Implementation Plan: Editor-UI-Verbesserungen — Bauchbinde, Frame-Navigation, Titel- und Zoom-Darstellung

**Branch**: `feature/0.3` | **Date**: 2026-07-19 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/006-editor-ui-polish/spec.md`

## Summary

Sechs UI-Korrekturen/-Erweiterungen aus direktem Nutzer-Feedback, alle rein
clientseitig in bestehenden Räumen (`EditorRoom`, `ZoomRoom`, `SelectionRoom`,
`Bauchbinde`) sowie in `main.lua` (neuer `gameWillPause`-Hook): (1) Crank-
Frame-Navigation wechselt von tick-basierter Rasterung
(`getCrankTicks(4)`, bereits ab 90° auslösend) auf einen signierten
Grad-Akkumulator via `getCrankChange()`, der erst bei ±360° netto auslöst
(R1). (2) `ZoomRoom` zeigt unbearbeitete Zellen künftig in echter
2×2-Subpixel-Auflösung statt einer einzelnen, das ganze 10×10-Feld
einfärbenden Stichprobe (R2). (3) `EditorRoom` erhält einen
Inaktivitäts-Timer + cursor-abhängige Seiten-Logik für die Bauchbinde,
analog zum bestehenden `statusMessage`-Muster (R3). (4) Eine neue
Kontext-/Pause-Ansicht nutzt `playdate.setMenuImage()` +
`playdate.gameWillPause()` statt eines vierten (nicht verfügbaren)
System-Menü-Slots oder eines neuen Screens (R4). (5) Ein VHS-Störeffekt
entsteht über zeitlich wechselnde `gfx.setPattern`-Phasen statt
Pro-Pixel-Zufallsrauschen (R5, während der Implementierung korrigiert —
`setDitherPattern` hat entgegen der ursprünglichen Annahme keinen
Phasen-Offset, siehe research.md R5). (6) Der Titelscreen lädt für den aktuell
selektierten Eintrag lazy die vollen Frame-/Imagetable-Daten nach und
spielt sie vollflächig ab, während alle anderen Einträge unverändert
statische Kreis-Thumbnails bleiben (R6). "Reset Frame" (R7) kopiert den
Vorgänger-Frame elementweise; ausgelöst über einen neuen Menüpunkt
"reset frame", der laut Projektinhaber-Vorgabe den bisherigen
"delete frame"-Menüpunkt ersetzt (AD-032, siehe research.md R7 und
Architecture Governance unten — "delete frame" entfällt damit als
Menü-Aktion).

## Technical Context

**Language/Version**: Lua (Playdate SDK Lua-Runtime, lokal verifiziert
gegen SDK v3.0.6)

**Primary Dependencies**: Playdate SDK CoreLibs (`playdate.getCrankChange`,
`playdate.getCrankTicks` [Zoomkette unverändert], `playdate.setMenuImage`,
`playdate.gameWillPause`, `gfx.setPattern` (Phasen-Offset, korrigiert von der
ursprünglich angenommenen `gfx.setDitherPattern`, siehe research.md R5),
`gfx.tilemap`/`imagetable`,
`playdate.timer`); bestehende Projekt-Bausteine `Bauchbinde`,
`RoomOperation`, `loadingBar`, `ImageStoreCodec` (Spec 001/003),
`ImageStore.getPreviewImage` (Spec 002)

**Storage**: Keine neuen Formate/Dateien — liest ausschließlich die bereits
über `ImageStoreCodec.newLoadOperation` verfügbare Laufzeitrepräsentation
`imageData` (frames, imagetable, hashIndex); keine Persistenz-Änderung

**Testing**: Headless-Tests (`lua tests/headless_tests.lua`, Constitution V
Gate 1) für zeit-/logikbasierte Anteile ohne echte Hardware-Abhängigkeit
(Crank-Akkumulator-Arithmetik, Bauchbinde-Timer/Seiten-Logik,
"Reset Frame"-Kopie, Tile-Zähl-Logik der Pause-Ansicht — alle mockbar über
bereits etablierte SDK-Mocks); manuelle Simulator-/Hardware-Szenarien in
[quickstart.md](quickstart.md) für rein visuelle/Timing-Aspekte
(VHS-Dither-Optik, Titelscreen-Animation, tatsächliches Crank-Gefühl auf
Hardware). Gate 2 (`pdc Source "Hans Dither.pdx"`) MUSS nach jeder
Implementierungs-Task fehlerfrei durchlaufen (Constitution V).

**Target Platform**: Playdate (Device + Simulator), 400×240, 1-Bit

**Project Type**: Single project (Lua-App unter `Source/`)

**Performance Goals**: Kein wahrnehmbarer Frame-Einbruch (Constitution
"Interaktionen müssen flüssig bleiben"): Zoom-Subpixel-Rendering bleibt auf
max. 24×24 Zellen à 4 Sample-Aufrufe begrenzt (kein Vollbild-Scan);
Pause-Bild-Aufbau läuft ausschließlich einmalig in `gameWillPause()`, nicht
pro Frame; VHS-Effekt nutzt Dither-Pattern-Phasenwechsel statt
Pro-Pixel-Schleife über 96.000 Pixel (research.md R5); Titelscreen-Ladevor-
gang für den animierten Hintergrund läuft asynchron (Coroutine), blockiert
kein Frame.

**Constraints**: Constitution I (SDK-First — `setMenuImage`/
`gameWillPause`/`getCrankChange`/`setPattern` statt Eigenbau, siehe
research.md); Constitution II (keine neuen Persistenzformate); System-
Menü-Limit weiterhin 3 Slots, bereits vollständig durch `EditorRoom`
belegt — kein zusätzlicher Slot verfügbar, daher ersetzt "reset frame" den
bisherigen "delete frame"-Menüpunkt statt einen vierten Slot zu belegen
(AD-032, entschieden per Projektinhaber-Vorgabe);
Constitution "Eingaben: D-Pad, A/B, Crank sind die einzigen Eingabegeräte"
(keine neue Hardware-Eingabe für die Pause-Ansicht — sie nutzt bewusst den
nativen Menü-Tasten-Pause-Mechanismus des Betriebssystems statt einer
eigenen Geste)

**Scale/Scope**: 4 geänderte Dateien (`EditorRoom.lua`, `ZoomRoom.lua`,
`SelectionRoom.lua`, `main.lua`), 0 neue Dateien, 0 entfallende Dateien;
betrifft 6 User Stories, keine Backend-/Netzwerk-Berührung (Spec
004/005 unangetastet, Constitution-Randbedingung "Netzwerk (Sync-Ausnahme)"
bleibt unverändert erfüllt)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Prinzip | Prüfung | Status |
|---|---|---|
| I. SDK-First | Jede der 6 User Stories stützt sich auf einen bereits verifizierten SDK-Baustein statt Eigenbau (research.md Zusammenfassungstabelle): `getCrankChange` statt eigener Winkel-Sensorik, `image:sample` statt eigenem Pixel-Zugriff, `setMenuImage`/`gameWillPause` statt eigenem Pause-Screen, `setPattern` statt Pro-Pixel-Rauschen (Signatur während der Implementierung korrigiert, siehe research.md R5), bestehendes `ImageStoreCodec`/`RoomOperation`-Ladepattern statt neuer Async-Infrastruktur. | PASS |
| II. Native Formate & PDI | Keine neuen Datenformate; alle Änderungen lesen/kopieren ausschließlich innerhalb der bestehenden `imageData`-Laufzeitstruktur (Frame-Arrays, Imagetable). | PASS |
| III. arc42-Pflege | Umgesetzt (T024/T027): arc42 Kap. 5 (Bausteine: `EditorRoom`/`ZoomRoom`/`SelectionRoom`/`main.lua`-Änderungen), Kap. 6 (neue Laufzeitszenarien 6.10-6.12: Bauchbinden-Timer, Pause-Bild-Aufbau, Titelscreen-Animation; 6.3 auf die neue Crank-Volldrehung aktualisiert), Kap. 8 (Querschnittskonzept "zeitbasierte Sichtbarkeits-Übergänge" ergänzt — das "ggf." aus der Planungsphase ist damit aufgelöst: die Bauchbinden-Logik reicht dasselbe Timeout→needsRedraw-Muster wie `statusMessage` weiter, statt ein neues Konzept einzuführen), Kap. 9 (AD-031/AD-032 referenziert), Kap. 12 (Glossar: "Kontext-/Pause-Ansicht" und "reset frame" neu, "Bauchbinde"-Eintrag präzisiert). | PASS |
| IV. Einfachheit | Signierter Einzel-Akkumulator statt Richtungs-Automat (R1); Wiederverwendung bestehender Diff-Strukturen (`gridState`/`baselineGrid`) statt neuem Parallel-Zustand (R2); Wiederverwendung des `statusMessage`-Timer-Musters statt neuer Abstraktion (R3); `setMenuImage` statt neuem Room (R4); Dither-Phasenwechsel statt aufwändiger Pixel-Simulation (R5); Lazy-Load nur für die Selektion statt Vorab-Laden aller Einträge (R6). Kein Zuwachs an dauerhafter Komplexität, der nicht direkt einem der 6 FR-Blöcke dient. | PASS |
| V. Testpflicht | Umgesetzt: beide Gates (`lua tests/headless_tests.lua` → "ALLE TESTS BESTANDEN", `pdc Source "Hans Dither.pdx"` → fehlerfrei) laufen nach jeder Task grün. Testfälle für Crank-Akkumulator-Arithmetik (T005), Bauchbinde-Sichtbarkeit/-Seite (T009, inkl. Regressionstest für den unten dokumentierten CR-02-Fund), Reset-Frame-Kopie (T013), Tile-Zähl-Logik der Pause-Ansicht (T017) und Titelscreen-Lazy-Load/1-Frame-Fall (T022) sind ergänzt. | PASS |

**Post-Design Re-Check (nach Phase 1)**: PASS — `data-model.md` und
`contracts/editor-room-ui-polish.md` führen keine neuen Abstraktionsschichten
ein; alle neuen Zustände (Crank-Akkumulator, Bauchbinde-Timer,
Titelscreen-Lade-Zustand) sind einfache Primitive/Tabellen im jeweils
bereits zuständigen Room-Modul. Complexity Tracking bleibt leer.

**Architektur-Review-Durchlauf (T029, nach Implementierung)**: Umsetzung
gegen `contracts/editor-room-ui-polish.md` CR-01 bis CR-11 geprüft — alle
elf Contract-Klauseln sind wie spezifiziert umgesetzt und headless-test-
verifiziert. Zwei Abweichungen wurden während der Implementierung
gefunden und korrigiert (kein offener Punkt, beide behoben):
1. **research.md R5 (SDK-Signatur)**: Die ursprüngliche Annahme
   `gfx.setDitherPattern(level, ditherType, xPhase, yPhase)` war falsch —
   die reale SDK-Funktion hat keinen Phasen-Offset. Korrigiert auf
   `gfx.setPattern(pattern, xPhase, yPhase)` (siehe research.md R5,
   data-model.md Abschnitt 5, T021).
2. **Contract CR-02 (Bauchbinden-Aktivität)**: Der erste
   Implementierungsstand aktualisierte `lastActivityMs` bei B-Druck nicht
   direkt, sondern nur indirekt über `pipette()` bei B-Release — und dort
   nur, wenn `bUsedForZoom == false`. Ein langes B-Halten ohne
   Crank-Bewegung hätte die Bauchbinde dadurch fälschlich ausblenden
   können, bevor B losgelassen wird. Gefunden beim klausel-für-Klausel-
   Abgleich gegen CR-02 ("B-Druck/-Release" als zwei eigenständige
   Auslöser), sofort behoben (`BButtonDown`/`BButtonUp` setzen
   `lastActivityMs` jetzt beide unconditional) und mit einem
   Regressionstest abgesichert.

Secure-Architecture: **N/A bestätigt** — alle sechs User Stories sind
rein lokale UI-/Renderingänderungen; der einzige Persistenz-Zugriff
(Titelscreen-Lazy-Load, US6) liest ausschließlich bereits vorhandene
lokale Save-Daten über den etablierten `ImageStoreCodec`-Pfad, keine
neue Netzwerk-, Auth- oder Datenspeicherungs-Berührung (Spec 004/005
unangetastet, Constitution-Randbedingung "Netzwerk (Sync-Ausnahme)"
bleibt erfüllt).

## Project Structure

### Documentation (this feature)

```text
specs/006-editor-ui-polish/
├── plan.md                          # Diese Datei
├── research.md                      # Phase 0: R1-R7, SDK-Verifikation je User Story
├── data-model.md                    # Phase 1: neue Zustände je Room, Pause-Bild-Layout
├── quickstart.md                    # Phase 1: Validierungsszenarien (Simulator + Hardware-Crank-Check)
├── contracts/
│   └── editor-room-ui-polish.md     # Phase 1: geänderte/neue Contracts (Bauchbinde, Pause-Bild, Crank, Titelscreen)
├── checklists/
│   └── requirements.md              # bereits vorhanden (aus /speckit-specify)
└── tasks.md                         # Phase 2 (/speckit-tasks — nicht Teil dieses Laufs)
```

### Source Code (repository root)

```text
Source/
├── EditorRoom.lua        # GEÄNDERT: Crank-Akkumulator (R1), Bauchbinde-Timer/Seite (R3),
│                         #   buildPauseMenuImage() (R4), reset-frame-Logik (R7),
│                         #   Menü-Umbau: "delete frame" -> "reset frame" (AD-032)
├── ZoomRoom.lua          # GEÄNDERT: drawGrid() zeigt Subpixel-Hintergrund für
│                         #   unbearbeitete Zellen (R2); Editier-/Commit-Logik unverändert
├── SelectionRoom.lua     # GEÄNDERT: Vollbild-Animation + VHS-Effekt für selektierten
│                         #   Eintrag (R5/R6); Kreis-Rendering für übrige Einträge unverändert
├── main.lua               # GEÄNDERT: neuer playdate.gameWillPause()-Hook (R4)
├── Bauchbinde.lua         # UNVERÄNDERT: bleibt reiner Zeichen-Helfer (research.md R3)
├── ZoomRoom.lua/PixelRoom.lua-Zoomkette  # UNVERÄNDERT (B+Crank-Pfad bleibt getCrankTicks(4))
└── tests/headless_tests.lua  # GEÄNDERT: neue Testfälle für R1/R3/R7 und Pause-Tile-Zählung (R4)

arc42/                    # Kap. 5, 6, 8, 9, 12 im Umsetzungsschnitt (siehe Constitution Check)
arc42/adr/                # NEU: ADR-031 (Pause-Ansicht via setMenuImage), ADR-032 (Reset-Frame-Auslösung)
```

**Structure Decision**: Kein neuer Room, keine neue Datei — alle sechs User
Stories sind Verhaltensänderungen INNERHALB bestehender Räume, die bereits
exakt die betroffenen Daten (`imageData`, Crank-Zustand, Menü) besitzen.
`Bauchbinde.lua` bleibt bewusst unverändert (research.md R3) — Timer-/
Positions-Logik lebt beim jeweiligen Aufrufer, nicht im Zeichen-Helfer, um
dessen Headless-Testbarkeit als reine Funktion nicht durch eine SDK-Zeit-
quelle aufzuweichen.

## Complexity Tracking

Keine Constitution-Verstöße — Tabelle entfällt. AD-032 (Reset-Frame-
Auslösung, Menüpunkt-Tausch "delete frame" → "reset frame") ist per
Projektinhaber-Vorgabe entschieden, siehe Architecture Governance unten.

## Architecture Governance (iSAQB-Preset)

- **Architektur-Arbeitsprodukte**: arc42 Kap. 5 (Bausteinsicht:
  `EditorRoom`/`ZoomRoom`/`SelectionRoom`-Änderungen, neuer
  `main.lua`-Hook), Kap. 6 (Laufzeitszenarien: Crank-Volldrehungs-
  Akkumulation, Pause-Bild-Aufbau bei `gameWillPause`, Titelscreen-
  Lazy-Load-Animation), Kap. 9 (AD-031, AD-032), Kap. 12 (Glossar-Update:
  "Kontext-/Pause-Ansicht"). Kein neues `docs/architecture/`-Artefakt nötig
  — die arc42-Kapitelaktualisierung genügt (reines Client-UI-Feature ohne
  eigenständige Systemgrenze), löst den in spec.md offen gelassenen Punkt
  auf. Owner: Entwickler; Evidenz: Feature-Branch-Diff der arc42-Kapitel.
- **ADRs**:
  - **AD-031** (NEU): "Kontext-/Pause-Ansicht via `playdate.setMenuImage()`
    + `playdate.gameWillPause()` statt eigenem In-Game-Pause-Screen" —
    Hintergrund: 3-Slot-Menü-Limit bereits ausgeschöpft, natives Menü kann
    keine eigene Grafik rendern; `setMenuImage` ist laut SDK-Doku exakt für
    diesen Zweck vorgesehen (research.md R4). Status: entschieden, zu
    dokumentieren in `arc42/adr/ADR-031-Pause-Ansicht-setMenuImage.md`
    vor Implementierungs-Abschluss.
  - **AD-032** (NEU, **entschieden**): Auslöse-Mechanismus für "Reset
    Frame" — kein freier Menü-Slot, keine kollisionsfreie
    D-Pad/A/B/Crank-Chord identifiziert (research.md R7). Entscheidung
    (Projektinhaber-Vorgabe): Menüpunkt "delete frame" wird durch
    "reset frame" ersetzt; "show grid" bleibt unverändert. Neuer
    Menü-Aufbau: `"save + exit"`, `"reset frame"`, `"show grid"`.
    Konsequenz: `deleteCurrentFrame()`/FR-008a (Spec 003) ist ab dieser
    Spec über kein Menü mehr erreichbar (Funktion bleibt im Code, verliert
    ihren Aufrufer). Status: entschieden, zu dokumentieren in
    `arc42/adr/ADR-032-Reset-Frame-statt-Delete-Frame-im-Menue.md` vor
    Implementierungs-Abschluss. Owner: Projektinhaber.
- **Risiko-/Schulden-Review**: Neu zu beobachten — (1) Titelscreen-
  Lazy-Load könnte bei sehr schnellem Durchschalten der Auswahl mehrere
  Ladevorgänge überlappen lassen; Mitigation: laufende Ladevorgänge für
  einen verlassenen Eintrag verwerfen (research.md R6), in quickstart.md
  als Szenario zu prüfen. (2) `getCrankChange()`-Akkumulator und
  `getCrankTicks(4)`-Zoomkette dürfen sich pro Frame nicht gegenseitig den
  Kurbel-Zustand "wegkonsumieren" (research.md R1, Detailhinweis) —
  Regressionsrisiko für die bestehende Zoomkette, daher zwingend Headless-
  Test + manuelle Hardware-Prüfung beider Pfade in derselben Sitzung. N/A:
  Sicherheitsarchitektur (rein lokale UI-Änderungen, keine Netzwerk-/
  Auth-/Datenspeicherungs-Berührung, Constitution-Randbedingung
  unverändert erfüllt).
- **Offen (Open)**: Exakte Dither-Parameter für den VHS-Effekt
  (`ditherType`/`level`/Phasenwechsel-Intervall) — visuell zu kalibrieren,
  kein SDK-Zwang; Owner: Entwickler; Follow-up: quickstart.md-Szenario
  "VHS-Effekt sichtbar und nicht zu aufdringlich"; Re-Evaluierung: erster
  Simulator-Test nach Implementierung. (AD-032 ist entschieden, siehe oben.)
