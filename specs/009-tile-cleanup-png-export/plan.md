# Implementation Plan: Tile-Bereinigung, projektbasierte Dateibenennung und PNG-Export im Backend

**Branch**: `feature/0.3` | **Date**: 2026-08-09 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/009-tile-cleanup-png-export/spec.md`

## Summary

Drei zusammenhängende Änderungen: (1) Der bislang als Platzhalter existierende
"Dedup"-Schritt im Save-Pfad des Editors (`Source/ImageStoreCodec.lua`) wird zu
einer echten Tile-Bereinigung ausgebaut, die über alle Frames hinweg
ungenutzte Tiles entfernt und verbleibende Positionsverweise neu
durchnummeriert — Basistiles (Weiß/Schwarz) bleiben dabei immer erhalten
(research.md R1/R2). (2) Das Backend benennt Dateien künftig nach dem
bereits beim Sync übermittelten, sanitisierten Projekt-Bezeichner
(`client_image_id`) statt nach der internen Zufalls-UUID — kein neues
Datenfeld nötig, da dieser Bezeichner bereits vorhanden, validiert und pro
Gerät eindeutig ist (research.md R3); eine Korrektur der bisher
lückenhaften Update-in-place-Logik verhindert dabei verwaiste Alt-Dateien
(research.md R4). (3) Das Backend liefert jeden Animationsframe einzeln als
PNG sowie die Tile-Sammlung als PNG in der Playdate-SDK-Namenskonvention
für Matrix-Imagetables (`<name>-table-16-16`); der rohe PDI-Download entfällt
vollständig aus der Nutzer-Oberfläche und API, bleibt aber intern für das
Rendering im Einsatz (research.md R5-R7).

## Technical Context

**Language/Version**: Lua 5.4-Subset (Playdate SDK, wie im gesamten
Projekt) für den Editor-Teil; PHP 8.x (kein Framework, MySQLi), wie in Spec
005/007 etabliert, für den Backend-Teil. Keine neue Sprache/Laufzeit.

**Primary Dependencies**: Playdate CoreLibs `graphics.imagetable` (neue
Funktion `ImageStoreCodec.pruneUnusedTiles()` nutzt ausschließlich bereits
verwendete SDK-Aufrufe: `imagetable.new()`, `:getImage()`/`:setImage()`,
`:getLength()` — kein neuer SDK-Baustein, Constitution I). Backend:
bestehende Bausteine `UploadHandler`, `Renderer`, `PdiParser` aus Spec 005;
keine neuen externen PHP-Bibliotheken (GD bleibt einzige Bild-Abhängigkeit,
bereits vorhanden).

**Storage**: Playdate `playdate.datastore`/`playdate.file` (unverändert,
nur der Inhalt von `sheet.pdi`/`frames.json` wird vor dem Schreiben
bereinigt). Backend: MySQL (bestehendes Schema, **keine neue Migration** —
research.md R3/R5) + Dateisystem `uploads/{uid}/` (geänderte
Namenskonvention, siehe data-model.md).

**Testing**: `lua tests/headless_tests.lua` (Constitution V, Pflicht-Gate 1)
+ `pdc Source "Hans Dither.pdx"` (Pflicht-Gate 2) für den Lua-Teil;
`curl`-basierte End-to-End-Szenarien nach etabliertem Muster aus
`backend/TESTING.md` (kein PHPUnit im Projekt, Constitution V gilt nur für
`Source/*.lua` — identische Einordnung wie Spec 007) für den Backend-Teil;
siehe `quickstart.md` für den vollständigen Ablauf beider Pfade.

**Target Platform**: Playdate-Hardware/-Simulator (Editor-Teil);
all-inkl.com Shared Hosting PHP/MySQL (Backend-Teil, wie Spec 005/007).

**Project Type**: Erweiterung bestehender Bausteine — kein neues Projekt,
kein neuer Endpunkt-Typ (E-08/E-09 werden erweitert, ein neuer Endpunkt
E-08b "Tilemap" kommt hinzu, E-06 "PDI" entfällt inhaltlich).

**Performance Goals**: `pruneUnusedTiles()` ist ein einmaliger linearer
Scan über höchstens 12 Frames × 375 Positionen (4500 Referenzen) plus einen
Kopiervorgang über höchstens einige hundert Tiles — läuft innerhalb der
bereits bestehenden "Dedup"-Yield-Phase in einem einzigen `update()`-Tick,
ohne die etablierte Coroutine-Struktur (`RoomOperation`) zu verändern.
Backend: Frame-PNGs und Tilemap-PNG werden on-demand gerendert (identisches
Muster zum bestehenden Frame-1-PNG/GIF, kein Vorab-Rendering beim Upload).

**Constraints**: Maximal 12 Frames, 375 Positionen pro Frame (Spec 001,
unverändert); maximal 12 Bilder pro Gerät (Spec 007, unverändert) —
`frame_count`-Ableitung aus `frames.json` bleibt dadurch performant genug
für die Bilder-Liste (research.md R5). Bestehende Sicherheitsmaßnahmen
(PIN-Hashing, Upload-Limit, Dateigrößen-/Schema-Validierung) bleiben
unverändert; die Whitelist-Validierung von `client_image_id`
(`upload.php`, `^[a-z0-9\-]{1,64}$`) bleibt die alleinige Schutzmaßnahme
gegen Pfadtraversierung bei der neuen Verwendung als Dateiname (FR-009).

**Scale/Scope**: 2 geänderte Lua-Dateien (`Source/ImageStoreCodec.lua`,
`tests/headless_tests.lua`), 4 geänderte PHP-Dateien
(`backend/includes/upload_handler.php`, `backend/includes/renderer.php`,
`backend/public/download.php`, `backend/public/index.php`), 0 neue
Datenbank-Migrationen, 0 neue externe Abhängigkeiten. Betrifft den
Save-Pfad des Editors sowie die Endpunkte E-05, E-06 (entfällt), E-08, E-09
und den neuen E-08b aus `specs/005-backend-service/contracts/backend-api.md`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Prinzip | Prüfung | Status |
|---|---|---|
| I. SDK-First | `pruneUnusedTiles()` nutzt ausschließlich bereits im Projekt verwendete Imagetable-Aufrufe (`imagetable.new/getImage/setImage/getLength`), kein neuer SDK-Baustein. Backend-Teil ist nicht anwendbar (kein Playdate-SDK-Code, identisch zur Begründung in Spec 005/007). | PASS |
| II. Native Formate & PDI | Setzt die Constitution-Vorgabe "Tiles MÜSSEN vor dem Speichern via Hashing dedupliziert werden" direkt um — genauer: vervollständigt sie um die bislang fehlende Bereinigungshälfte (nicht mehr referenzierte Tiles entfernen), die seit dem PDI-Umstieg (AD-017) als offener Punkt im Code stand (research.md R1, Kommentar "T014"). Kein neues Format, kein Format-Wechsel. | PASS |
| III. arc42-Pflege | Umsetzungsschnitt aktualisiert `arc42/09-architekturentscheidungen.md` AD-005 (Status-Korrektur + neuer Bezug auf `ImageStoreCodec.lua`, research.md R1) und ergänzt ein neues AD für die Backend-Dateibenennung; `arc42/05-bausteinsicht.md`/`06-laufzeitsicht.md` (Save-Pfad-Erweiterung, neue Download-Route E-08b) und `docs/architecture/security-review-backend.md` (neue Zeile zur Dateinamens-Sanitisierung) — als Tasks in Phase 2 einzuplanen, analog zum etablierten Vorgehen aus Spec 007 (dort ebenfalls in `/speckit-plan` deklariert, in der Tasks-/Implementierungsphase geschrieben). | PASS (geplant) |
| IV. Einfachheit | Kein neues Datenbankfeld/keine neue Migration (Wiederverwendung von `client_image_id`, Ableitung von `frame_count` aus bereits vorhandener `frames.json` statt neuer Spalte, research.md R3/R5); Frame-PNGs ≥ 2 nutzen deterministische Pfade + `file_exists()` statt einer neuen Cache-Spalte; keine zusätzliche Live-State-Mutation im Editor, wo die bestehende Raum-Lebenszyklus-Garantie bereits ausreicht (research.md R2); `deliverPdi()` wird vollständig entfernt statt nur unerreichbar gemacht (kein toter Code, FR-014). | PASS |
| V. Testpflicht | Gilt für den Lua-Teil (`Source/ImageStoreCodec.lua`) — vor Abschluss: `lua tests/headless_tests.lua` MUSS mit "ALLE TESTS BESTANDEN" enden (neue Testfälle für Bereinigung + Invariante `tileCount >= 2`, siehe quickstart.md A), `pdc Source ...pdx` MUSS fehlerfrei bauen. Für den reinen Backend-Teil N/A (Prinzip V gilt nur für `Source/*.lua`), Verifikation dort über `curl`-Szenarien in quickstart.md B (Erweiterung von `backend/TESTING.md`). | PASS (zu verifizieren bei Implementierung) |

**Post-Design Re-Check (nach Phase 1)**: PASS — `data-model.md` und
`contracts/backend-api-amendment.md` führen keine neue Abstraktionsschicht
und keine neue Tabelle/Spalte ein; die Pfadberechnung ist eine lokale
Erweiterung von `UploadHandler::handleUpload()`/`Renderer`, die
Tile-Bereinigung eine lokale, reine Funktion in `ImageStoreCodec.lua`.
Complexity Tracking bleibt leer.

## Project Structure

### Documentation (this feature)

```text
specs/009-tile-cleanup-png-export/
├── plan.md                        # Diese Datei
├── research.md                    # Phase 0: R1-R7, Ist-Zustand-Verifikation + Entscheidungen
├── data-model.md                  # Phase 1: Bereinigungs-Algorithmus, Dateibasis-Schema, Frame-Auswahl
├── quickstart.md                  # Phase 1: Lua-Headless-Tests (A) + curl-Szenarien (B)
├── contracts/
│   └── backend-api-amendment.md   # Phase 1: Amendment zu specs/005-backend-service/contracts/backend-api.md E-05/E-06/E-08/E-09 + neu E-08b
├── checklists/
│   └── requirements.md            # bereits vorhanden (aus /speckit-specify)
└── tasks.md                       # Phase 2 (/speckit-tasks — nicht Teil dieses Laufs)
```

### Source Code (repository root)

```text
Source/
├── ImageStoreCodec.lua      # GEÄNDERT: neue Funktion pruneUnusedTiles() (research.md
│                             #   R1/R2, data-model.md Abschnitt 1); newSaveOperation()
│                             #   nutzt sie ab der "Dedup"-Phase statt des bisherigen
│                             #   No-Op-Kommentars (Zeilen 26-35)
└── ImageStore.lua            # UNVERÄNDERT: createImage() ruft weiterhin
                              #   newSaveOperation() unverändert auf; Invariante
                              #   tileCount >= 2 bleibt für den Neuanlage-Fall erhalten
                              #   (research.md R2). copyImage() (Zeilen 182-247) ruft
                              #   KEINE Save-Operation auf — kopiert sheet/frames/preview
                              #   direkt auf Datastore-Ebene; da jede gespeicherte Datei ab
                              #   dieser Spec bereits bereinigt auf der Platte liegt, kopiert
                              #   copyImage() automatisch den bereits bereinigten Stand mit,
                              #   ohne selbst etwas tun zu müssen

tests/
└── headless_tests.lua       # GEÄNDERT: neue Sektion "ImageStoreCodec: Tile-Bereinigung
                              #   beim Speichern" (quickstart.md A)

backend/
├── includes/
│   ├── upload_handler.php   # GEÄNDERT: Pfadberechnung via client_image_id ?? image_id
│   │                         #   (research.md R3); Lookup in Schritt 4a liest zusätzlich
│   │                         #   pdi_path/json_path/png_path/gif_path; UPDATE-Zweig setzt
│   │                         #   pdi_path/json_path neu + räumt verwaiste Alt-Dateien bei
│   │                         #   Umbenennung auf UND löscht bei JEDEM Re-Sync vorhandene
│   │                         #   {base}-frame-*.png/{base}-table-16-16.png (research.md R4)
│   ├── renderer.php          # GEÄNDERT: writePng() verallgemeinert (Breite/Höhe aus
│   │                         #   Parametern statt Canvas-Konstanten); renderFrameToPng()
│   │                         #   ersetzt renderToPng() (frame-Parameter); neue Funktion
│   │                         #   renderTilemapToPng() (research.md R6)
│   ├── validation.php        # UNVERÄNDERT (client_image_id-Regex bereits in upload.php)
│   └── pdi_parser.php        # UNVERÄNDERT (weiterhin intern für Rendering genutzt)
└── public/
    ├── download.php          # GEÄNDERT: deliverPdi() entfernt, case 'pdi' → 410 (FR-013/014);
    │                         #   case 'png' liest frame-Query-Parameter; neue case 'tilemap'
    │                         #   + deliverTilemap() (contracts/backend-api-amendment.md E-08/E-08b)
    ├── upload.php             # UNVERÄNDERT (client_image_id-Validierung bereits vorhanden)
    └── index.php              # GEÄNDERT: JSON-Response ohne pdi_url, mit frame_count +
                                #   tilemap_url (E-05); HTML-Liste ohne PDI-Spalte, mit
                                #   Frame-Galerie + Tilemap-Link

backend/TESTING.md              # GEÄNDERT: neue Abschnitte B1-B6 ergänzt (Referenz aus quickstart.md)
```

**Structure Decision**: Keine neuen Dateien im Sinne neuer Bausteine — alle
Änderungen erweitern bestehende Module an ihren bereits etablierten
Erweiterungspunkten (Save-Coroutine-Phase, Upload-Pfadberechnung,
Renderer-Methoden, Download-Router). Der einzige neue "Endpunkt"
(`/download/tilemap/{id}`) ist ein zusätzlicher `case`-Zweig im bereits
bestehenden `download.php`-Router, kein neues Skript.

## Complexity Tracking

Keine Constitution-Verstöße — Tabelle entfällt.

## Architecture Governance (iSAQB-Preset)

- **Architektur-Arbeitsprodukte**: arc42 Kap. 5 (Bausteinsicht:
  `ImageStoreCodec`-Erweiterung um Bereinigungsschritt; Backend-Bausteine
  `UploadHandler`/`Renderer`/`download.php` geändert), Kap. 6
  (Laufzeitsicht: Save-Sequenz erhält Bereinigungsphase; Download-Sequenz
  verliert PDI-Route, gewinnt Frame-/Tilemap-Auswahl), Kap. 9
  (Architekturentscheidungen, siehe ADRs unten), `docs/architecture/
  security-review-backend.md` (neue Zeile: aus Geräte-Eingabe abgeleitete
  Dateinamen sind über die bestehende Whitelist-Regex abgesichert) — als
  Tasks in Phase 2 einzuplanen. Owner: Entwickler; Evidenz:
  Feature-Branch-Diff + Verweis auf research.md R1-R7.
- **ADRs**:
  - **AD-005** (AKTUALISIERT, nicht neu — research.md R1): Status-Zeile von
    "umgesetzt" auf "umgesetzt (v0.2.x, Pulp-Ära); seit dem PDI-Umstieg
    (AD-017) als Platzhalter ohne Wirkung; mit Spec 009 erneut umgesetzt in
    `ImageStoreCodec.lua`" korrigiert; Entscheidungstext bleibt inhaltlich
    identisch ("ungenutzte Tiles werden entfernt, Referenzen remapped,
    Basistiles immer behalten"), Konsequenz-Zeile ergänzt um den Verweis auf
    die Invariante `tileCount >= 2` (research.md R2) und den konkreten
    Mechanismus (`pruneUnusedTiles()`, reine Funktion ohne Live-State-
    Mutation). Hintergrund: Der Kommentar `-- Phase 1: Dedup (T014 ...)` in
    `ImageStoreCodec.lua` ist der Beleg, dass diese bereits 2026 (Pulp-Ära)
    getroffene Entscheidung beim v0.3.0-Formatwechsel nicht mitgewandert
    ist — eine reine Dokumentationskorrektur eines bestehenden ADRs, kein
    neuer Trade-off. Status: entschieden, bei Implementierung in
    `arc42/09-architekturentscheidungen.md` Abschnitt 9.5 zu übernehmen.
  - **AD-038** (NEU): "Backend-Dateinamen aus `client_image_id`
    (Sync-seitig bereits sanitisierter Projektname) statt aus einem neuen,
    separaten Namensfeld ableiten" — Hintergrund: `client_image_id` wird
    bereits seit Spec 004 bei jedem Sync übertragen, ist bereits serverseitig
    gegen `^[a-z0-9\-]{1,64}$` validiert und bereits `UNIQUE (uid,
    client_image_id)` — ein zusätzliches, aus `frames.json` geparstes
    `name`-Feld wäre eine zweite, redundante Wahrheitsquelle für dieselbe
    Information (Constitution IV, research.md R3). Status: entschieden, zu
    dokumentieren in `arc42/adr/ADR-038-Backend-Dateibenennung-client-image-id.md`.
  - **Bewusst KEIN eigenes ADR**: "Tile-Bereinigung als reine
    Serialisierungs-Transformation statt Live-State-Mutation" — im
    spec.md-Architecture-Governance-Abschnitt als offener ADR-Kandidat
    vermerkt, aber kein architektonischer Trade-off zwischen echten
    Alternativen: Die Untersuchung des Raum-Lebenszyklus (research.md R2)
    zeigt, dass "Editier-Sitzung arbeitet nach dem Speichern mit dem
    bereinigten Stand weiter" (FR-004) bereits strukturell garantiert ist
    (Speichern verlässt immer den Editor; Wiedereintritt lädt immer neu) —
    es gibt keine zweite Alternative, die tatsächlich gegeneinander
    abzuwägen wäre. Als Recherche-Ergebnis in research.md R2 festgehalten,
    nicht als ADR.
- **Risiko-/Schulden-Review**:
  - Fehler bei der Tile-Neuindizierung (`pruneUnusedTiles()`-Remap) sind
    das höchste Einzelrisiko dieser Spec — sie berühren direkt die
    Kernanforderung "verlustfreies Speichern" (Spec 001 FR-006). Mitigation:
    dedizierte Headless-Testfälle (quickstart.md A) inkl. Round-Trip-Check
    vor Implementierungsabschluss (Constitution V, kein Ausnahmefall).
  - Bestandsdaten-Migration ist implizit/lazy (spec.md Assumptions): alte
    Dateien werden erst beim nächsten Re-Sync umbenannt. Ohne die in
    research.md R4 beschriebene Korrektur der UPDATE-Anweisung (bisher
    aktualisiert sie `pdi_path`/`json_path` NICHT) würde die Datenbank nach
    der ersten Umbenennung eines Bestandsprojekts auf nicht mehr
    existierende Dateien zeigen — dies ist kein neues Risiko, sondern ein
    durch diese Spec aufgedeckter, in derselben Änderung zu behebender
    Bestandsfehler; als expliziter Tasks-Punkt zu führen, nicht optional.
  - Die in R5 gewählte Vereinfachung (keine DB-Spalte für Frame-≥2-/
    Tilemap-PNGs, nur `file_exists()`) hätte ohne die in research.md R4
    (zweiter Abschnitt) ergänzte Bereinigung bei JEDEM Re-Sync eine
    stille Regression eingeführt: Der Standard-Frame (`frame=0`)/GIF werden bereits heute über
    `png_path = NULL`/`gif_path = NULL` korrekt invalidiert, Frame ≥ 2 und
    die Tilemap-PNG hätten OHNE explizites Löschen bei gleichbleibendem
    `base` beliebig lange eine veraltete Datei ausgeliefert. Als
    verpflichtender Tasks-Punkt (nicht optional) zu führen, mit
    Regressionstest in quickstart.md B2.
  - Weicht die Playdate-SDK-Namenskonvention für Matrix-Imagetables in
    einer künftigen SDK-Version vom hier zugrunde gelegten Muster ab, wird
    der Tilemap-Export inkompatibel — zu beobachten bei SDK-Updates
    (Constitution Prinzip I), aktuell laut SDK-Doku (research.md R6) kein
    Blocker.
  - AD-005 war seit dem v0.3.0-Formatwechsel (mind. seit Spec 001,
    2026-07-03) mit falschem "umgesetzt"-Status dokumentiert, ohne dass dies
    bei den seither gelaufenen Governance-Reviews (Spec 004/005/006/007/008)
    auffiel — als Prozess-Lernpunkt vermerkt: künftige Architecture-
    Governance-Abschnitte sollten bei "Status: umgesetzt"-ADRs stichprobenartig
    gegen den aktuellen Code verifizieren, nicht nur bei neu hinzukommenden
    Entscheidungen.
- **Sicherheitsrelevante Architektur**: Ja — Backend-Dateinamen werden ab
  dieser Änderung aus einem geräteseitig gesetzten Wert abgeleitet
  (`client_image_id`). Die bestehende serverseitige Whitelist-Validierung
  (`upload.php`, `^[a-z0-9\-]{1,64}$`) ist die maßgebliche Kontrolle gegen
  Pfad-/Verzeichnistraversierung und wurde für den neuen Verwendungszweck
  (Dateiname statt nur DB-Lookup-Schlüssel) geprüft: Der Zeichenraum
  erlaubt weder `.` noch `/` noch Null-Bytes, ein Escape aus
  `uploads/{uid}/` ist damit strukturell ausgeschlossen (research.md R3,
  FR-009) — bestätigt ausreichend, kein zusätzlicher Kontrollmechanismus
  nötig. Kein dediziertes Secure-Architecture-Preset im Projekt installiert;
  die Sicherheitsbewertung erfolgt wie bei Spec 007 inline über
  `docs/architecture/security-review-backend.md`.
- **Offen (Open)**: Keine — beide ADR-Punkte (AD-005-Korrektur, AD-038) und
  die R4-Korrektur sind mit dieser Planung entschieden, kein Blocker für
  `/speckit-tasks`.
