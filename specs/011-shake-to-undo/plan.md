# Implementation Plan: Schüttel-Undo für die letzten 3 riskanten Aktionen

**Branch**: `feature/0.3-addons` | **Date**: 2026-09-02 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/011-shake-to-undo/spec.md`

---

## Summary

Hans-Dither bekommt eine **Undo-Funktion für genau die letzten 3 „riskanten" Operationen**: **Clear Screen**, **Frame löschen**, **90°-Pixel-Rotation** und **Pixel-Verschiebung**. Feingranulares Pixel-/Tile-Malen wird bewusst NICHT erfasst (Clarifications 2026-09-02).

Technischer Ansatz — drei neue SDK-freie Module + Verdrahtung in die bestehenden Räume:

1. **`UndoHistory.lua`** — Ringpuffer mit ≤ 3 Einträgen (reine Lua-Tabellen). Zwei Eintragsformen: *content* (betroffene Zellen einer Frame-Ebene, je Zelle vorheriger Tile-Index **und** vorheriges 16×16-Bild) und *deleteFrame* (tief kopierter `frameLayers`-Eintrag + `frames`-Cache-Eintrag + Ursprungsindex). Reiner Sitzungszustand, keine Persistenz.
2. **`ShakeDetector.lua`** — Zustandsautomat, der pro Frame einen Accelerometer-Sample `(x, y, z)` frisst und eine Links-Rechts-Sequenz auf der X-Achse (Vorzeichenwechsel über Schwellwert innerhalb eines Zeitfensters, danach Refraktärzeit) als Kante meldet. Algorithmus headless-testbar; die konkreten g-Werte sind Hardware-Tuning.
3. **`UndoPrompt.lua`** — modaler Bestätigungsdialog nach dem Muster von `SelectionRoom.drawConfirmDeleteDialog` / `confirmingDelete`. Benennt die betroffene Operation, „(A) Ja / (B) Nein", schluckt A/B/D-Pad/Crank.

`EditorRoom` besitzt die `UndoHistory`-Instanz (dort leben `imageData`, Composite-Cache und Tilemap; 3 der 4 Operationen laufen ohnehin über `EditorRoom`). `EditorRoom`, `ZoomRoom`, `PixelRoom` starten das Accelerometer in `entered()`, füttern in `update()` den `ShakeDetector` und rufen bei positiver Kante `EditorRoom:undoRequest()`. Das prüft über `UndoHistory:peekValid` die **Anwendbarkeit vorab** (fehlender Ziel-Frame → FR-006; `deleteFrame` an der 12-Frame-Grenze → FR-007) und öffnet den `UndoPrompt` nur, wenn ein „(A) Ja" garantiert zu einem erfolgreichen Undo führt (FR-012); sonst nur eine kurze Meldung. Das Bestätigen ruft `EditorRoom:undoLast()`, das den Eintrag anwendet, ggf. zum betroffenen Frame / zurück in den Tile View navigiert und neu kompositiert.

Alles nutzt vorhandene SDK-Mittel (Constitution I) und das bewährte Room-Muster (Constitution IV). Kein neues Speicherformat (Constitution II unberührt).

---

## Technical Context

**Language/Version**: Lua 5.3 via Playdate SDK (latest); Standard-Lua-Syntax (keine `+=`-pdc-Kurzform) für Headless-Testbarkeit

**Primary Dependencies**:
- Playdate SDK: **`playdate.startAccelerometer` / `stopAccelerometer` / `readAccelerometer`** (NEU für dieses Projekt), `playdate.graphics` (Dialog-Rendering), `playdate.getCurrentTimeMilliseconds` (Zeitfenster/Refraktär)
- Bestehende Module: `EditorRoom` (Composite-Cache, `registerTile`/`getTile`, `recompositeCell`/`recompositeCurrentFrame`, `shiftActiveLayer`), `LayerModel` (`copyArray`, Entry-Struktur), `FrameManagementView` (`deleteMarked`), `PixelRoom` (`rotateGridClockwise`/`rotateGridCounterClockwise`, `commitToZoomRoom`), `ZoomRoom` (`shiftActiveLayerContent`)

**Storage**: **Keine.** Der Undo-Verlauf ist reiner RAM-Sitzungszustand. Das PDI-/JSON-Speicherformat (Spec 009/010) bleibt unverändert.

**Testing**: `lua tests/headless_tests.lua` — MUSS mit „ALLE TESTS BESTANDEN" enden (Constitution V, Gate 1). Erweitert um einen Accelerometer-Mock (settable `(x,y,z)`) und einen neuen Abschnitt „Spec 011".

**Target Platform**: Playdate-Handheld + Simulator

**Project Type**: Pixel-/Tile-Editor (Lua), flaches `Source/`-Verzeichnis, Room-Architektur mit `switchRoom`-DI aus `main.lua`

**Performance Goals**:
- Native 30 FPS (`playdate.update`) in allen Editier-Räumen bleiben erhalten; die im Zoom View (Spec 008) mühsam erreichte flüssige Bedienung darf messbar nicht schlechter werden
- `ShakeDetector:feed()` pro Frame: O(1), nur ein paar Vergleiche + ein kleiner Ringpuffer von Peaks — kein `image.new`, keine Allokation im Normalfall
- `undoLast()` für Clear Screen / Frame löschen: eine `recompositeCurrentFrame`/`updateTilemapFrame`-Runde (wie ein Frame-Wechsel, bereits im Budget); für Shift/Rotation: ≤ 2 `recompositeCell`

**Constraints**:
- Eingaben nur D-Pad, A/B, Crank — alle im Editier-Raum bereits belegt; der Dialog MUSS daher vollständig modal sein (FR-013)
- Playdate-RAM: 3 Einträge à worst case ~1500 Integer (Frame-löschen-Snapshot: 3 Ebenen × 375 + Cache 375) + wenige `gfx.image`-Referenzen (nicht kopiert) — unkritisch
- Rückwärtskompatibilität: rein additiv, kein Einfluss auf Laden/Speichern bestehender Bilder
- Batterie: Accelerometer nur in den Editier-Räumen aktiv (Start in `entered()`, Stopp beim Rücksprung zu `SelectionRoom`/`TitleRoom`)

**Scale/Scope**:
- Verlaufstiefe: **fix 3** (harte Grenze, analog 12-Frame-Cap, Constitution IV)
- Erfasste Operationstypen: **genau 4** (Clear Screen, Frame löschen, Rotation, Pixel-Verschiebung)
- Betroffene Dateien: 3 neu, 5 modifiziert, 1 Testdatei erweitert
- arc42: 8 Kapitel + 3 neue ADRs (044–046)

---

## Constitution Check

*GATE: Muss vor Phase 0 bestehen. Nach Phase 1 erneut geprüft.*

### ✅ Principle I: SDK-First (NICHT VERHANDELBAR)

**Status**: PASS (mit begründeter Eigenlogik)

- Beschleunigungssensor wird über die offizielle SDK-API genutzt (`playdate.startAccelerometer` / `readAccelerometer`). Das SDK stellt **kein fertiges Shake-/Schüttel-Ereignis** bereit (Prüfung: CoreLibs enthalten kein Shake-Modul; `playdate.readAccelerometer` liefert nur rohe g-Werte). Die Links-Rechts-Erkennung ist daher zwingend Eigenlogik auf einer SDK-Primitive → **ADR-044** dokumentiert diese Abweichung; arc42 Kap. 4 + 9 benennen sie (Constitution I, Satz 3).
- Dialog-Rendering nutzt `playdate.graphics`-Primitiven wie der bestehende `SelectionRoom`-Bestätigungsdialog — kein neues UI-Framework.
- Kein eigener Serialisierer/Parser: der Verlauf wird nie geschrieben.
- Snapshots nutzen `LayerModel.copyArray` und `EditorRoom.registerTile`/`getTile` (bereits vorhanden).

### ✅ Principle II: Native Formate & PDI

**Status**: PASS (unverändert)

- Kein neues Datenformat, keine Änderung an `frames.json` / `sheet.pdi`, keine Änderung an `ImageStoreCodec`.
- Geprüft: `ImageStoreCodec.newSaveOperation` ist eine **reine Transformation** — `pruneUnusedTilesLayered` kopiert `frameLayers` tief und baut eine neue Imagetable; die **Live-`imageData` (Indizes, Imagetable) wird beim Speichern nicht umnummeriert** (Kommentar `ImageStoreCodec.lua:55-58`). Die einzige Imagetable-Mutation zur Laufzeit ist *Anhängen* (`appendTileToImagetable`, wächst nur). ⇒ In `UndoEntry` gespeicherte Tile-Indizes bleiben die ganze Editier-Sitzung gültig; `undoLast()` registriert zusätzlich die gespeicherten **Bild-Objekte** über `registerTile` neu (dedupliziert), also robust auch gegen künftige Änderungen.

### ✅ Principle III: Architekturdokumentation in arc42

**Status**: PASS (geplant, Phase 2 / `tasks.md`)

Pflicht-Updates (im selben Feature-Branch, Prinzip III):

| Kapitel | Inhalt |
|---|---|
| `arc42/02-randbedingungen.md` | Accelerometer als neue Eingabefähigkeit; Batterie-Hinweis |
| `arc42/04-loesungsstrategie.md` | Schüttel-Erkennung als Eigenlogik auf SDK-Accelerometer; Undo = Pre-State-Snapshots, sitzungslokal |
| `arc42/05-bausteinsicht.md` | Neue Bausteine `UndoHistory`, `ShakeDetector`, `UndoPrompt` + Einbindung |
| `arc42/06-laufzeitsicht.md` | Sequenz „Schütteln → Kante → Dialog → A → `undoLast` → Navigation + Recomposite" |
| `arc42/08-querschnittliche-konzepte.md` | Eingabe-/Modalitätskonzept um vollmodalen Dialog + Accelerometer-Lebenszyklus erweitern |
| `arc42/09-architekturentscheidungen.md` | ADR-044/045/046 (Kurzform) verlinken |
| `arc42/10-qualitaetsanforderungen.md` | Qualitätsszenarien Robustheit / Performance / Speicher |
| `arc42/11-risiken-und-technische-schulden.md` | 5 Risikoeinträge aus der Spec |
| `arc42/adr/ADR-044-Schuettel-Erkennung-Accelerometer.md` | NEU |
| `arc42/adr/ADR-045-Undo-Modell-3-Schritt-sitzungslokal.md` | NEU |
| `arc42/adr/ADR-046-Modaler-Undo-Dialog.md` | NEU |

### ✅ Principle IV: Einfachheit vor Ausbau

**Status**: PASS

- Harte Grenze: **3** Einträge, **4** Operationstypen. Kein Redo, keine beliebige Historie, kein Persistieren.
- `UndoPrompt` spiegelt das vorhandene `confirmingDelete`-Muster (kein neues Paradigma).
- Keine neue Datei-/Formatlogik; Verlauf ist eine Liste in `EditorRoom`.
- Coalescing-Regeln halten „eine Geste = ein Eintrag" simpel (siehe research R4).

### ✅ Principle V: Testpflicht (NICHT VERHANDELBAR)

**Status**: PASS (Gates erzwungen)

1. `lua tests/headless_tests.lua` → „ALLE TESTS BESTANDEN". Neuer Abschnitt „Spec 011" deckt ab: Ringpuffer-Verdrängung (FR-001), Operationsfilter (FR-002), Undo-Wiederherstellung je Typ inkl. „male, dann rotieren" (FR-002/004/005), `peekValid` siebt ungültige Einträge **vor dem Dialog** aus — fehlender Ziel-Frame (FR-006) **und** `deleteFrame` an der 12-Frame-Grenze (FR-007, kein „rejected" nach A-Druck), leerer Verlauf (FR-009), `ShakeDetector`-Kantenerkennung + Refraktär + Fehlalarm-Freiheit gegen ruhige Sample-Ströme (FR-010/011), `UndoPrompt`-Modalität (FR-013/015), `undoRequest`-Meldungspfade („Nothing to undo" / „cannot undo — frame limit").
2. **`Source/pdxinfo` `buildNumber` 30 → 31** vor dem ersten `pdc`-Build; dann `pdc Source "Hans Dither.pdx"` fehlerfrei.
- **Neuer Test-Mock** (eigener Task): `playdate.startAccelerometer`/`stopAccelerometer`/`readAccelerometer` in `tests/headless_tests.lua` ergänzen (settable Modul-Variable `(x,y,z)`), analog zum vorhandenen Crank-/Button-Mock.
- Manuelle Simulator-/Hardware-Integration (separater Task-Block, analog Spec 010 Phase 7): Schwellwert, Fehlalarm-Freiheit, Zoom-View-FPS, Dialog-Modalität auf echtem Gerät.

**Ergebnis Gate: PASS** — keine Verstöße, keine Einträge in Complexity Tracking nötig.

---

## Project Structure

### Documentation (this feature)

```text
specs/011-shake-to-undo/
├── spec.md              # Feature-Spezifikation
├── plan.md              # Diese Datei
├── research.md          # Phase 0 (dieser Lauf)
├── data-model.md        # Phase 1 (dieser Lauf)
├── quickstart.md        # Phase 1 (dieser Lauf)
├── contracts/
│   ├── undo-modules.md      # Modul-Schnittstellen UndoHistory / ShakeDetector / UndoPrompt
│   └── headless-mocks.md    # Accelerometer-Mock-Oberfläche für die Headless-Tests
└── tasks.md             # Phase 2 (/speckit-tasks — NICHT von /speckit-plan erzeugt)
```

### Source Code (Playdate-Lua-Projekt, flaches `Source/`)

```text
Source/
├── UndoHistory.lua          # NEU: Ringpuffer ≤3, Eintragsformen content/deleteFrame, apply*()
├── ShakeDetector.lua        # NEU: (x,y,z)-Stream → Links-Rechts-Kante (Schwellwert, Fenster, Refraktär)
├── UndoPrompt.lua           # NEU: modaler Bestätigungsdialog (Muster: SelectionRoom.confirmingDelete)
├── EditorRoom.lua           # MOD: hält UndoHistory; record bei clearCurrentFrame(); undoLast();
│                            #      Accelerometer-Lebenszyklus; ShakeDetector füttern; UndoPrompt gaten
├── ZoomRoom.lua             # MOD: Shift-„Run" abgrenzen (B-Halten) → EditorRoom.recordShiftRun*;
│                            #      Accelerometer füttern; UndoPrompt gaten; A-Bestätigung → zurück Tile View
├── PixelRoom.lua            # MOD: Snapshot beim ERSTEN rotateGrid*(); an EditorRoom bei commitToZoomRoom();
│                            #      Accelerometer füttern; UndoPrompt gaten
├── FrameManagementView.lua  # MOD: deleteMarked() meldet deleteFrame-Eintrag an EditorRoom (VOR table.remove)
└── main.lua                 # MOD: import "UndoHistory/ShakeDetector/UndoPrompt"; ggf. Referenzen durchreichen

tests/headless_tests.lua     # MOD: Accelerometer-Mock + Abschnitt „Spec 011"
Source/pdxinfo               # MOD: buildNumber 30 → 31 (Gate 2)
arc42/…                      # MOD: 8 Kapitel + 3 ADR-Dateien (siehe Principle III)
.github/copilot-instructions.md  # MOD: Plan-Verweis auf specs/011-shake-to-undo/plan.md
```

**Structure Decision**: Einzelnes Playdate-Lua-Projekt, flaches `Source/`. Drei neue, bewusst SDK-freie Hilfsmodule (headless-testbar), die von den bestehenden Räumen verdrahtet werden. Kein `Source/Rooms/` oder `Source/Models/` (existiert nicht — vgl. `LayerModel.lua`-Kopfkommentar). `deleteCurrentFrame()` in `EditorRoom.lua:427` ist **toter Code ohne Aufrufer** (Kommentar dort) — NICHT instrumentieren; der Live-Löschpfad ist `FrameManagementView.deleteMarked()`.

---

## Architecture Governance & Technical Debt (iSAQB-Preset)

### Geplante Architektur-Arbeitsprodukte

| Arbeitsprodukt | Pfad | Trigger | Owner / Reviewer |
|---|---|---|---|
| Bausteinsicht-Update | `arc42/05-bausteinsicht.md` | neue Module + Modulschnitt | `/speckit-implement` (Task) / Merlin |
| Laufzeitsicht-Sequenz | `arc42/06-laufzeitsicht.md` | neuer modaler Ablauf | `/speckit-implement` / Merlin |
| Querschnitt: Eingabe/Modalität + Sensor-Lebenszyklus | `arc42/08-querschnittliche-konzepte.md` | belegte Eingaben + neue Plattformfähigkeit | `/speckit-implement` / Merlin |
| Lösungsstrategie-Absatz | `arc42/04-loesungsstrategie.md` | SDK-First-Abweichung | `/speckit-implement` / Merlin |
| Randbedingung | `arc42/02-randbedingungen.md` | Accelerometer = neue Eingabefähigkeit | `/speckit-implement` / Merlin |
| **ADR-044** Schüttel-Erkennung über Accelerometer | `arc42/adr/ADR-044-*.md` + Kap. 9 | SDK-First-Abweichung, Algorithmuswahl | `/speckit-implement` / Merlin |
| **ADR-045** Undo-Modell: 3-Schritt, nur riskante Ops, sitzungslokal | `arc42/adr/ADR-045-*.md` + Kap. 9 | Datenmodell + Snapshot-Mechanik | `/speckit-implement` / Merlin |
| **ADR-046** Modaler Undo-Dialog in den Editier-Räumen | `arc42/adr/ADR-046-*.md` + Kap. 9 | Modalität gegen belegte Eingaben | `/speckit-implement` / Merlin |
| Qualitätsszenarien | `arc42/10-qualitaetsanforderungen.md` | NFR Robustheit/Performance/Speicher | `/speckit-implement` / Merlin |
| Risiken & techn. Schulden | `arc42/11-risiken-und-technische-schulden.md` | 5 Risiken aus Spec | `/speckit-implement` / Merlin |

**`docs/architecture/`**: Vorgabe wird über `arc42/09` + `arc42/adr/` erfüllt (Projektkonvention, Constitution III schreibt `arc42/` vor) — dokumentierte, begründete Abweichung vom Preset-Default-Pfad.

### Qualitätsszenarien (Design-relevant)

| Attribut | Szenario | Messung / Abnahme |
|---|---|---|
| Robustheit | Nach versehentlichem „Clear Screen" stellt Schütteln + „(A) Ja" den Ebeneninhalt vollständig wieder her | Headless: Positions-Array vor/nach identisch. Simulator: < 1 s, visuell identisch |
| Performance | `ShakeDetector:feed()` + `readAccelerometer()` pro Frame im Zoom View | Hardware: FPS-Anzeige im Zoom View vor/nach dem Feature unverändert (Spec-008-Basis) |
| Speicher | 3 Einträge, davon einer ein Frame-löschen-Snapshot | Headless: Eintrag ist tiefe Kopie (kein Alias auf `imageData`); grobe Größenabschätzung dokumentiert (~1500 ints/Eintrag worst case) |
| Bedienbarkeit / Sicherheit | Bei offenem Dialog löst keine Taste/Crank eine Editier-Aktion aus | Headless: Room-Inputhandler früh-return bei `UndoPrompt.isOpen()`; Simulator: A/B/D-Pad/Crank durchprobieren |

### Risiken & Gegenmaßnahmen (aus Spec übernommen, Phase-2-Nachverfolgung)

| Risiko | Gegenmaßnahme | Status |
|---|---|---|
| Fehlalarm der Schüttel-Geste | Schwellwert + erzwungene Links-Rechts-Sequenz + Refraktärzeit; Dialog als 2. Sicherung; Hardware-Test | Offen bis Hardware-Test |
| Accelerometer-Polling ↓ Zoom-View-FPS | leichte O(1)-Erkennung; FPS-Messung Hardware; ggf. Polling ausdünnen | Offen bis Hardware-Test |
| Snapshot-Speicher bei Frame-löschen-Undo | nur Positions-Arrays + Bild-*Referenzen* kopieren, keine Pixel-Kopien; grobe Budget-Notiz in data-model | Adressiert im Design |
| Verlaufseinträge durch spätere Struktur-Änderung ungültig | `undoLast()` überspringt/verwirft Einträge mit fehlendem Ziel-Frame (FR-006); Verlauf bei Bildwechsel leeren | Adressiert im Design |
| Modaler Dialog kollidiert mit belegten Eingaben | `UndoPrompt.isOpen()`-Gate in allen Room-Inputhandlern + `update()`-Crank-Blöcken; Direction-Holds beim Öffnen leeren | Adressiert im Design (FR-013, SC-005) |

### Sicherheitsrelevante Architektur

**Nicht betroffen.** Rein lokale In-Memory-Funktion: kein Netzwerk, keine Secrets, keine Persistenz, keine neue Angriffsfläche. Der secure-architecture-Preset wird **NICHT** angewandt (`N/A`). Re-Evaluations-Trigger: falls der Undo-Verlauf je auf Platte oder ins Backend geschrieben wird.

### Audit Evidence Applicability (Plan-Ebene)

| Checkpoint | Status | Evidenz / Begründung / Follow-up |
|---|---|---|
| Spec Open #1 — Pixel-Verschiebungs-Granularität | **Resolved** | → research.md **R4** (Coalescing „ein B-Halten-Run = ein Eintrag"). Spec-Open-Zeile aktualisiert |
| Spec Open #2 — Wiederherstellungs-Mechanik / RAM-Budget | **Resolved** | → research.md **R2/R3** + data-model.md „UndoEntry". Voll-Snapshot pro betroffener Zelle (Index + Bild); Frame-löschen = tiefe Kopie. Budgetnotiz dokumentiert. Spec-Open-Zeile aktualisiert |
| Spec Open #3 — Gesten-Verhalten in `FrameManagementView` | **Resolved** | → research.md **R6**. Geste dort NICHT aktiv; `deleteFrame`-Eintrag entsteht bei `deleteMarked()`, Dialog erst nach Rückkehr in den Tile View. Spec-Open-Zeile aktualisiert |
| Spec Open #4 — konkreter Bewegungsschwellwert (SC-006) | **Open** | Owner: Hardware-Test. Follow-up: T-/Fenster-/Refraktär-Werte nach erstem Gerätetest in ADR-044 eintragen. Trigger: Phase „Manuelle Hardware-Integration"; erneut bei Nutzer-Feedback zu Fehlauslösung |
| arc42 Kap. 2/4/5/6/8/9/10/11 | **Applicable** | Update-Tasks in `tasks.md` (siehe Principle III); Owner `/speckit-implement` + Merlin |
| arc42 Kap. 3 (Kontext) / Kap. 7 (Verteilung) | **N/A** | Keine neue externe Schnittstelle bzw. Build-/Deployment-Änderung. Trigger: externe Gesten-Anbindung / persistierte Sensor-Konfig |
| ADR-044 / 045 / 046 | **Applicable** | Neu anzulegen (Kurzform in Kap. 9 + Datei in `arc42/adr/`) |
| secure-architecture-Preset | **N/A** | Begründung siehe oben |
| Constitution V Gate 1 (headless) | **Applicable** | Abschnitt „Spec 011" + Accelerometer-Mock; endet mit „ALLE TESTS BESTANDEN" |
| Constitution V Gate 2 (`buildNumber` +1, `pdc`) | **Applicable** | `Source/pdxinfo` 30 → 31 vor erstem Testbuild |
| Manuelle Simulator-/Hardware-Integration | **Applicable** | Eigener Task-Block; deckt SC-006 + Zoom-FPS + Modalität ab |

---

## Complexity Tracking

*Keine Constitution-Verstöße — Tabelle bleibt leer.*

| Design-Punkt | Begründung | Verworfene Alternative |
|---|---|---|
| 3 eigene SDK-freie Module statt Logik in den Räumen | Headless-Testbarkeit (Constitution V), klarer Modulschnitt | Logik verstreut in `EditorRoom`/`ZoomRoom`/`PixelRoom` → schwer testbar, dupliziert |
| Voll-Snapshot der betroffenen Zellen (Index + Bild) | Robust gegen Tile-Dedup/Prune; einheitliche `apply`-Logik | Inverse Deltas je Typ (z. B. „rotiere zurück") → bricht, sobald Tiles geteilt/umnummeriert werden |
| Rotation-Snapshot beim ERSTEN `rotateGrid*()`, nicht bei `setCurrentTile` | `setCurrentTile` lädt den Grid VOR dem Malen; ein Snapshot dort würde spätere Mal-Edits mit-zurücknehmen (Verstoß gegen FR-002/SC-003) | Snapshot bei `setCurrentTile` — verwirft ungewollt Mal-Edits |
| `deleteFrame`-Eintrag bei `deleteMarked()` erzeugen, Dialog erst im Tile View | B ist in der `FrameManagementView` durch die Halte-Geste belegt; Geste dort inaktiv | Geste auch in der `FrameManagementView` → Eingabekonflikt mit B-Halten |

---

## Next Steps

**Phase 0** (dieser Lauf): ✅ `research.md` erzeugt — alle offenen Punkte außer dem Hardware-Schwellwert (SC-006) aufgelöst.

**Phase 1** (dieser Lauf): ✅ `data-model.md`, `contracts/undo-modules.md`, `contracts/headless-mocks.md`, `quickstart.md` erzeugt; `.github/copilot-instructions.md` auf diesen Plan gezeigt; Spec-Open-Tabelle aktualisiert.

**Phase 2** (`/speckit-tasks`): `tasks.md` mit Reihenfolge Module → Verdrahtung → Tests → arc42 → Build-Gate → manuelle Integration.
