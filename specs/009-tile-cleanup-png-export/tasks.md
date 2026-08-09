# Tasks: Tile-Bereinigung, projektbasierte Dateibenennung und PNG-Export im Backend

**Input**: Design documents from `/specs/009-tile-cleanup-png-export/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/backend-api-amendment.md](contracts/backend-api-amendment.md), [quickstart.md](quickstart.md)

**Tests**: Kein PHPUnit/Test-Framework im Projekt etabliert (Constitution V gilt
ausschließlich für `Source/*.lua`) — Backend-Verifikation erfolgt je Story über
`quickstart.md`-Szenarien gegen die deployte Umgebung, nicht über
automatisierte Testtasks. Der `Source/*.lua`-Teil (US1) erhält einen
automatisierten Testfall in `tests/headless_tests.lua` (Constitution V,
NICHT VERHANDELBAR — kein optionaler Test-Task, sondern Pflicht-Gate).

**Organization**: Tasks sind nach User Story gruppiert (spec.md-Prioritäten:
US1/US2 = P1, US3 = P2), damit jede Story unabhängig implementiert und
verifiziert werden kann. Frame-Indizes sind durchgängig 0-basiert
(spec.md Clarifications).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Kann parallel laufen (unterschiedliche Dateien, keine Abhängigkeiten)
- **[Story]**: Zugehörige User Story (US1-US3)

## Path Conventions

Playdate-Editor: `Source/ImageStoreCodec.lua` + `tests/headless_tests.lua`
(US1). Backend: `backend/includes/upload_handler.php` (US2),
`backend/includes/renderer.php` + `backend/public/download.php` +
`backend/public/index.php` (US3) — kein Framework, reines PHP/MySQLi, wie
in Spec 005/007 etabliert. Keine neuen Verzeichnisse, keine neue
Datenbank-Migration (plan.md "Structure Decision").

---

## Phase 1: Setup

**N/A** — keine neue Projekt-Struktur, kein neuer Endpunkt-Typ, keine neue
Abhängigkeit. Alle Änderungen erweitern bestehende Bausteine an bereits
etablierten Erweiterungspunkten (plan.md "Structure Decision"). Kein
Setup-Task erforderlich.

---

## Phase 2: Foundational

**N/A** — keine Infrastruktur, die MEHRERE Stories gemeinsam blockiert. US1
(Lua) ist vollständig dateidisjunkt zu US2/US3 (PHP). US2 und US3 teilen
sich kein Codesegment (US2: ausschließlich `upload_handler.php`; US3:
`renderer.php`/`download.php`/`index.php`); die Basis-Ableitung
`{base} = client_image_id ?? image_id` wird in US3 NICHT erneut aus
`client_image_id` berechnet, sondern aus dem bereits von US2 (bzw. dem
Bestandscode) korrekt gesetzten `pdi_path` abgeleitet
(`basename($image['pdi_path'], '.pdi')`) — dadurch funktioniert US3 auch
unabhängig davon, ob US2 bereits ausgeliefert ist (liefert dann vorübergehend
noch UUID-basierte Namen, keine falschen Ergebnisse). Kein
Foundational-Task erforderlich.

---

## Phase 3: User Story 1 - Ungenutzte Tiles beim Speichern entfernen (Priority: P1) 🎯 MVP

**Goal**: Beim Speichern eines Bildes werden über alle Frames hinweg
ungenutzte Tiles aus der Tile-Sammlung entfernt (außer den beiden
Basistiles), verbleibende Tiles lückenlos neu durchnummeriert, alle
Frame-Positionsdaten entsprechend aktualisiert.

**Independent Test** (aus spec.md): Ein Bild mit mehreren Frames anlegen,
ein Tile in allen Frames überschreiben, sodass sein ursprünglicher Inhalt
in keinem Frame mehr referenziert wird, speichern, App neu starten und
Bild neu laden — die Tile-Sammlung enthält den alten Inhalt nicht mehr,
alle Frames sehen weiterhin exakt so aus wie vor dem Speichern.

- [X] T001 [US1] Neue reine Funktion
  `ImageStoreCodec.pruneUnusedTiles(imagetable, frames, tileCount)` in
  `Source/ImageStoreCodec.lua` implementieren (data-model.md Abschnitt 1):
  `used`-Menge mit Basistiles 1/2 immer enthalten + allen in `frames`
  referenzierten Indizes füllen; `keepList` = aufsteigend sortierte,
  gültige (`<= tileCount`) Indizes aus `used`; `remap[old] = new`
  (1-basiert, lückenlos); neues Imagetable mit `#keepList` Einträgen
  befüllen; `frames` auf die neuen Indizes ummappen (Fallback auf
  `remap[1]` bei ungültigem Alt-Index); Rückgabe
  `newImagetable, newFrames, #keepList`. Invariante: `#keepList >= 2` in
  JEDEM Fall (research.md R2). Kein Zugriff auf `imageData.*` — reine
  Funktion ohne Seiteneffekt (research.md R2, FR-004 wird dadurch bewusst
  NICHT über Mutation erfüllt, sondern ist durch den Raum-Lebenszyklus
  bereits strukturell gegeben).

- [X] T002 [US1] `Source/ImageStoreCodec.lua::newSaveOperation()`: die
  bisherige No-Op-"Dedup"-Phase (aktuell Zeilen 26-35, Kommentar
  `-- Phase 1: Dedup (T014 - wird später in US2 implementiert...)`) durch
  einen echten Aufruf von `pruneUnusedTiles()` ersetzen; die lokalen
  Variablen `imagetable`/`frames`/`tileCount`, die von den nachfolgenden
  Phasen (Sheet ab Zeile 37, Frames ab Zeile 56, Bilddaten ab Zeile 68,
  Preview ab Zeile 74) gelesen werden, MÜSSEN ab hier die bereinigten
  Werte sein. `imageData.imagetable`/`imageData.frames`/
  `imageData.hashIndex` bleiben unverändert (T001 hat keinen
  Seiteneffekt) — kein zusätzlicher Code zur Live-State-Synchronisation
  nötig (research.md R2). Depends on T001.

- [X] T003 [P] [US1] Neue Testsektion "ImageStoreCodec: Tile-Bereinigung
  beim Speichern" in `tests/headless_tests.lua` (nach der bestehenden
  Sektion "ImageStoreCodec: Basistiles..." ab Zeile 875) mit mindestens
  vier Fällen (quickstart.md A): (1) ein in keinem Frame mehr
  referenziertes Tile verschwindet, verbleibende Positionen zeigen nach
  dem Remap auf identischen Inhalt (data-model.md Abschnitt 1
  Beispieltabelle); (2) ein Bild, das ausschließlich Weiß/Schwarz nutzt,
  behält trotzdem genau 2 Tiles; (3) Regressionstest gegen das
  `ImageStore.createImage()`-Neubild-Muster (1 Frame, alle Positionen =
  Index 1) — `pruneUnusedTiles()` liefert `tileCount == 2`, NICHT `1`; (4)
  Round-Trip: `newSaveOperation()` (mit Bereinigung) → `newLoadOperation()`
  → alle Frames pixelidentisch zum Stand vor dem Speichern.

- [X] T004 [US1] Constitution-V-Gates ausführen und bestätigen: `lua
  tests/headless_tests.lua` MUSS mit "ALLE TESTS BESTANDEN" enden; `pdc
  Source "Hans Dither.pdx"` MUSS fehlerfrei bauen (quickstart.md A).
  Depends on T001-T003.

**Checkpoint**: US1 ist nach T001-T004 vollständig funktionsfähig und
unabhängig testbar (kein Backend-Bezug).

---

## Phase 4: User Story 2 - Backend-Dateien nach Projektname statt Zufalls-ID benennen (Priority: P1)

**Goal**: Backend-Dateien (PDI, JSON, gerenderte Bilder) werden nach dem
vom Gerät übermittelten `client_image_id` (sanitisierter Projektname)
benannt statt nach der internen Zufalls-UUID; Re-Sync überschreibt
weiterhin dieselben Dateien; Upload ohne `client_image_id` fällt auf die
bisherige UUID-Benennung zurück; die interne Adressierung
(`/download/{typ}/{id}`) bleibt unverändert.

**Independent Test** (aus spec.md): Ein Projekt mit einem erkennbaren
Namen vom Playdate aus synchronisieren, anschließend im Backend die
zugehörigen Dateien herunterladen — alle Dateinamen enthalten den
Projektnamen, keine enthält die interne Zufalls-ID.

- [X] T005 [US2] `backend/includes/upload_handler.php::handleUpload()`
  Schritt 4a (aktuell Zeilen 60-70, `SELECT id FROM images WHERE uid = ?
  AND client_image_id = ?`) auf `SELECT id, pdi_path, json_path, png_path,
  gif_path FROM images WHERE ...` erweitern und die Alt-Werte in lokalen
  Variablen (`$old_pdi_path`, `$old_json_path`, `$old_png_path`,
  `$old_gif_path`) merken — Voraussetzung für T008/T009, da diese Werte
  nach dem UPDATE nicht mehr abrufbar wären (research.md R4).

- [X] T006 [US2] `backend/includes/upload_handler.php::handleUpload()`
  Schritt 6 (aktuell Zeilen 87-89, `$pdi_path = $upload_dir . '/' .
  $image_id . '.pdi'` etc.) ändern zu: `$base = $client_image_id ??
  $image_id`; `$pdi_path = $upload_dir . '/' . $base . '.pdi'`;
  `$json_path = $upload_dir . '/' . $base . '.json'` (data-model.md
  Abschnitt 2, research.md R3). `$client_image_id` ist bereits über
  `upload.php:74-77` gegen `^[a-z0-9\-]{1,64}$` validiert — keine
  zusätzliche Sanitisierung nötig (FR-009).

- [X] T007 [US2] `backend/includes/upload_handler.php::handleUpload()`
  Update-in-place-Zweig (aktuell Zeilen 104-110): UPDATE-Anweisung von
  `UPDATE images SET png_path = NULL, gif_path = NULL, uploaded_at =
  NOW() WHERE id = ?` auf `UPDATE images SET pdi_path = ?, json_path = ?,
  png_path = NULL, gif_path = NULL, uploaded_at = NOW() WHERE id = ?`
  ändern (mit den in T006 neu berechneten `$pdi_path`/`$json_path` als
  Parametern) — ohne diese Korrektur zeigt die DB nach der ersten
  Umbenennung eines Bestandsprojekts auf nicht mehr existierende Dateien
  (research.md R4, kritischer Bugfix, kein optionaler Task). `png_path =
  NULL`/`gif_path = NULL` MÜSSEN dabei zwingend erhalten bleiben (nicht
  versehentlich beim Umbauen der Anweisung entfernen) — sie sind die
  bestehende Cache-Invalidierung für den Standard-Frame (`frame=0`) und
  das GIF, auf die sich T012 explizit verlässt (research.md R4, zweiter
  Abschnitt). Depends on T005, T006.

- [X] T008 [US2] Direkt nach erfolgreichem `db()->commit()` im
  Update-in-place-Zweig: falls `$old_pdi_path !== $pdi_path` (aus T005/
  T006), `$old_pdi_path`, `$old_json_path`, `$old_png_path` (falls
  gesetzt) und `$old_gif_path` (falls gesetzt) best-effort per `unlink()`
  löschen (Fehler loggen, nicht als Request-Fehler behandeln) — verhindert
  verwaiste Alt-Dateien nach Umbenennung (research.md R4). Depends on
  T005-T007.

- [X] T009 [US2] Im selben Update-in-place-Zweig, direkt NEBEN T008 (also
  ebenfalls NACH erfolgreichem `db()->commit()`, NICHT vor dem Schreiben
  der neuen `pdi`/`json`-Dateien — die Löschung liegt sonst innerhalb der
  Transaktion und hätte bei einem nachfolgenden Rollback keinen
  Rücknahmepfad, während neu generierte PNGs verlustfrei on-demand
  nachgeliefert werden): UNABHÄNGIG von T008, läuft bei JEDEM Re-Sync
  (nicht nur bei geänderten Pfaden) — alle vorhandenen Dateien nach dem
  Muster `glob($upload_dir . '/' . $base . '-frame-*.png')` sowie — falls
  vorhanden — `$upload_dir . '/' . $base . '-table-16-16.png'` löschen
  (research.md R4, zweiter Abschnitt — sonst bleibt eine inhaltlich
  veraltete Frame-≥1-PNG oder Tilemap-PNG nach einem Re-Sync unbegrenzt
  bestehen, da diese Artefakte keine invalidierende DB-Spalte besitzen).
  `$base` enthält laut Validierung keine `glob()`-Metazeichen. Depends on
  T006-T007.

- [X] T010 [US2] Validierung gegen die deployte Umgebung: `quickstart.md`
  Szenarien B1 (Upload mit `image_id` → Dateien tragen den Projektnamen),
  B2 (Re-Sync überschreibt, kein Duplikat + Cache-Invalidierungs-Regressionstest
  mit geändertem Frame-Inhalt) und B6 (Upload ohne `image_id` → Fallback
  auf UUID) durchführen, Checkliste in `quickstart.md` abhaken. Depends on
  T005-T009. **Durchgeführt gegen https://www.hans-dither.de** (2026-08-09):
  B1 — Dateinamen `meinbild.json`/`.png`/`.gif` bestätigt (Content-
  Disposition); B2 — Re-Sync liefert `"Aktualisierung erfolgreich"` mit
  UNVERÄNDERTER `image_id` (kein Duplikat, weiterhin genau 1 Eintrag je
  Projekt), Cache-Invalidierungs-Regression bestätigt (Frame-1-PNG vor/
  nach geändertem Re-Sync unterscheidet sich, MD5 unterschiedlich); B6 —
  Upload ohne `image_id` → 201, Dateiname fällt auf die interne UUID
  zurück. Siehe T031 für einen dabei gefundenen und behobenen
  `deploy.sh`-Bug (unabhängig von US2s eigentlicher Logik).

**Checkpoint**: US1 UND US2 funktionieren nach T001-T010 beide unabhängig.

---

## Phase 5: User Story 3 - PNG-Export statt PDI-Download (Priority: P2)

**Goal**: Jeder Frame eines Bildes ist einzeln als PNG abrufbar; die
Tile-Sammlung ist zusätzlich als PNG in der Playdate-SDK-Namenskonvention
für Matrix-Imagetables (`<name>-table-16-16`) abrufbar; der rohe
PDI-Download entfällt vollständig aus Web-Oberfläche und JSON-Schnittstelle
(interne PDI-Nutzung fürs Rendering bleibt unberührt).

**Independent Test** (aus spec.md): Ein Bild mit mehreren Frames
hochladen, anschließend über das Backend jeden Frame einzeln als PNG
abrufen und zusätzlich die Tilemap-PNG herunterladen; die Tilemap-Datei
lässt sich unverändert in ein neues Playdate-SDK-Projekt legen und dort
als Matrix-Imagetable laden. Ein Versuch, die alte PDI-Route aufzurufen,
liefert eine eindeutige "nicht verfügbar"-Antwort.

**Hinweis zur Reihenfolge**: Baut laut spec.md ("Why this priority") auf
US2 auf, ist aber NICHT hart blockiert — `$base` wird hier aus
`basename($image['pdi_path'], '.pdi')` abgeleitet (Phase 2), nicht erneut
aus `client_image_id` berechnet.

- [X] T011 [US3] `backend/includes/renderer.php::writePng()` (aktuell
  Zeilen 216-246, hart auf `self::$canvasWidth`/`$canvasHeight`
  verdrahtet) verallgemeinern: Breite/Höhe aus den übergebenen `$rows`
  ableiten (`strlen($rows[0])`/`count($rows)`) statt der Canvas-Konstanten
  — Voraussetzung für T013 (Tilemap-PNG hat andere Abmessungen als
  400×240) (research.md R6).

- [X] T012 [US3] `backend/includes/renderer.php::renderToPng()` (aktuell
  Zeilen 40-67, einziger Aufrufer: `download.php:136`) zu
  `renderFrameToPng(string $image_id, string $uid, int $frameIndex = 0)`
  umbauen: `$base = basename($image['pdi_path'], '.pdi')`; Ziel-Pfad
  `$upload_dir/$base.png` für `$frameIndex === 0`, sonst
  `$upload_dir/$base-frame-{$frameIndex}.png` (0-basiert, spec.md
  Clarifications); für `$frameIndex === 0` weiterhin `png_path`-Spalte als
  Cache-Marker nutzen (unverändertes Verhalten); für `$frameIndex >= 1`
  KEINE DB-Spalte, nur `file_exists()`-Check (data-model.md Abschnitt 3,
  research.md R5). `composeFrame($assets, $frameIndex)` (bereits
  vorhanden) liefert die Pixel-Zeilen für den angeforderten Frame.
  Depends on T011.

- [X] T013 [US3] Neue Methode `Renderer::renderTilemapToPng(string
  $image_id, string $uid)` in `backend/includes/renderer.php`: PDI über
  `PdiParser::parseFile()` parsen (liefert bereits `['width', 'height',
  'rows']`, VOR dem Tile-Slicing in `loadAssets()`), diese Roh-Zeilen 1:1
  über die (in T011 verallgemeinerte) `writePng()` als
  `$upload_dir/$base-table-16-16.png` schreiben — kein Tile-Slicing nötig
  (research.md R6). Depends on T011.

- [X] T014 [US3] `backend/includes/renderer.php::renderToGif()` (aktuell
  Zeile 102, `$gif_path = $image['pdi_path'] . '.gif'` — Bestandsfehler,
  erzeugt `{basis}.pdi.gif`): auf `$upload_dir/$base.gif` korrigieren
  (`$base = basename($image['pdi_path'], '.pdi')`) (research.md R5).

- [X] T015 [P] [US3] `backend/public/download.php`: Funktion
  `deliverPdi()` (aktuell Zeilen 91-106) vollständig entfernen (FR-014,
  kein toter Code); `case 'pdi':` (aktuell Zeile 66-68) bleibt bestehen,
  liefert aber `410 Gone` mit `{"error": "PDI-Download nicht mehr
  verfügbar"}` — NACH der bestehenden Auth-/Berechtigungsprüfung, gleiche
  Reihenfolge wie alle anderen Typen (research.md R7, contracts
  E-06). Unabhängig von T011-T014 (anderes Programmsegment), daher [P].

- [X] T016 [US3] `backend/public/download.php::deliverPng()` (aktuell
  Zeilen 131-162) um `frame`-Query-Parameter erweitern: fehlt der
  Parameter, `$frame = 0`; sonst muss er eine Ganzzahl zwischen `0` und
  `frame_count - 1` sein (aus `json_path` gelesen), sonst `400 Bad
  Request` mit `{"error": "Ungültiger Frame-Index"}`; Aufruf von
  `Renderer::renderFrameToPng($image['id'], $uid, $frame)` statt des
  bisherigen `renderToPng()` (contracts E-08). Depends on T012.

- [X] T017 [US3] `backend/public/download.php`: neuer `case 'tilemap':`
  im Router (ergänzt den bestehenden `switch ($type)` ab Zeile 65) +
  neue Funktion `deliverTilemap()` (analog zu `deliverPng()`, aber ohne
  `frame`-Parameter, Content-Disposition-Dateiname
  `{$base}-table-16-16.png`, ruft `Renderer::renderTilemapToPng()` auf)
  (contracts E-08b). Depends on T013.

- [X] T018 [P] [US3] `backend/public/index.php::handleImagesRequest()`
  JSON-Zweig (aktuell Zeilen 364-376): `pdi_url` aus dem Response-Array
  entfernen; `frame_count` (aus `json_decode(file_get_contents($image
  ['json_path']))`, `count($data['frames'])`) und `tilemap_url`
  (`/download/tilemap/{id}?token=...`) ergänzen (contracts E-05,
  data-model.md Abschnitt 4). Unabhängig von T011-T017 (anderes File),
  daher [P].

- [X] T019 [US3] `backend/public/index.php::showImagesPage()` (aktuell
  Zeilen 392-478): Tabellenspalte "PDI" (Zeilen 439, 457-459) entfernen;
  pro Bild eine Galerie mit `frame_count` Vorschau-/Downloadlinks
  (`?frame=N&inline=1` für Vorschau, ohne `inline` für Download, `N` von
  `0` bis `frame_count-1`) sowie einen Downloadlink für die Tilemap-PNG
  ergänzen (contracts E-05, spec.md US3 Acceptance Scenario 1). Depends
  on T018 (gleiche Datei, `frame_count` muss aus dem HTML-Zweig ebenso
  verfügbar sein).

- [X] T020 [US3] Validierung gegen die deployte Umgebung: `quickstart.md`
  Szenarien B3 (Frame-Index 0 und 1 einzeln abrufbar, `frame=99` → 400),
  B4 (Tilemap-PNG mit korrektem SDK-Dateinamen, im Simulator ladbar) und
  B5 (PDI-Route → 410, kein `pdi_url` mehr in `/images`) durchführen,
  Checkliste abhaken. Depends on T011-T019. **Durchgeführt gegen
  https://www.hans-dither.de** (2026-08-09): B3 — Frame 0/1 liefern
  unterschiedliche, gültige 400×240-PNGs, `frame=99` → `400
  "Ungültiger Frame-Index"`; B4 — `meinbild-table-16-16.png`, 48×16 px
  (exakt 3 Tiles der Testdaten); B5 — `410 "PDI-Download nicht mehr
  verfügbar"`, kein `pdi_url` mehr in `/images`; zusätzlich HTML-Galerie
  verifiziert (keine PDI-Spalte, Tilemap-Link vorhanden, ein
  Vorschau-/Downloadlink je Frame). Siehe T030/T031 für zwei dabei
  gefundene und behobene Deployment-Bugs.

- [X] T030 [US3] **Bei T020 gefundener Bug (1/2)**: `.htaccess`-Routing
  kennt nur eine feste Typ-Liste (`RewriteRule
  ^download/(pdi|json|png|gif)/...`, generiert in `backend/deploy.sh`) —
  der neue Typ `tilemap` (T017) war dort NICHT ergänzt worden.
  `/download/tilemap/{id}` landete dadurch nie in `download.php`, sondern
  im generischen 404-Fallback von `index.php` (identische Fehlermeldung
  "Route nicht gefunden" wie ein echter Routing-Fehler — deshalb beim
  Code-Review nicht aufgefallen). Behoben: `deploy.sh` erzeugt jetzt
  `RewriteRule ^download/(pdi|json|png|tilemap|gif)/[A-Za-z0-9-]+$
  public/download.php [L]`. Re-deployed und gegen die Live-Umgebung
  erneut verifiziert (200 OK, korrekter `Content-Disposition`-Header).

- [X] T031 **Bei T020 gefundener Bug (2/2), schwerwiegender**:
  `backend/deploy.sh` synchronisiert per `rsync -az --delete` (bzw.
  `lftp mirror --delete` im FTPS-Fallback) das gesamte `backend/`-
  Verzeichnis auf den Server, OHNE `uploads/` auszuschließen. Da das
  lokale `backend/uploads/` bewusst per `.gitignore` leer gehalten wird,
  hat JEDER Deploy das entfernte `uploads/`-Verzeichnis auf diesen leeren
  Lokalstand gespiegelt und dabei ALLE dort abgelegten Dateien gelöscht —
  ein vorbestehender Bug (nicht durch Spec 009 verursacht), der beim
  Redeploy für T030 tatsächlich ausgelöst wurde (bestätigt per SSH:
  `uploads/` war bis auf `.htaccess` leer). Nutzer-Rückfrage ergab: keine
  echten Bestandsdaten betroffen, nur Testdaten. Behoben:
  `--exclude='uploads/'` (rsync) bzw. `--exclude-glob uploads/` (lftp) in
  `deploy.sh` ergänzt; `storage/` bewusst NICHT ausgeschlossen (wird lokal
  bei jedem Lauf frisch erzeugt, enthält nur ein regenerierbares Log).
  Re-deployed und per SSH verifiziert, dass ein erneuter Deploy
  `uploads/` nicht mehr anrührt. **Owner-Hinweis**: künftige Deploys sind
  jetzt sicher; falls vor dieser Korrektur echte Produktivdaten verloren
  gingen, wäre eine Wiederherstellung nur über ein Hosting-Backup
  (all-inkl.com/KAS) möglich — laut Rückfrage nicht nötig.

**Checkpoint**: US1, US2 UND US3 funktionieren nach T001-T020 UND
T030/T031 alle unabhängig UND zusammen; die Deployment-Pipeline selbst
ist jetzt ebenfalls verifiziert sicher.

---

## Phase 6: Polish & Cross-Cutting Concerns (Architecture Governance, iSAQB-Preset)

**Purpose**: Architektur-Evidenz, ADR- und arc42-Aktualisierung, die alle
drei Stories gemeinsam betreffen (plan.md "Architecture Governance").

- [X] T021 [P] `arc42/09-architekturentscheidungen.md` Abschnitt 9.5
  (AD-005 "Tile-Kompaktierung vor Save"): Status-Zeile von "umgesetzt" auf
  "umgesetzt (v0.2.x, Pulp-Ära); seit dem PDI-Umstieg (AD-017) als
  Platzhalter ohne Wirkung; mit Spec 009 erneut umgesetzt in
  `ImageStoreCodec.lua`" korrigieren; Konsequenz-Zeile um den Verweis auf
  die Invariante `tileCount >= 2` und den Mechanismus (`pruneUnusedTiles()`,
  reine Funktion ohne Live-State-Mutation) ergänzen (plan.md
  Architecture Governance, research.md R1). Depends on T001-T002 (Code
  muss existieren, bevor die Doku ihn beschreibt).

- [X] T022 [P] `arc42/09-architekturentscheidungen.md`: neuen Abschnitt
  "9.26 AD-038: Backend-Dateinamen aus `client_image_id` statt separatem
  Namensfeld" ergänzen — Inhalt aus plan.md AD-038 (research.md R3,
  Constitution IV). Depends on T005-T006.

- [X] T023 [P] `arc42/05-bausteinsicht.md`: Baustein `ImageStoreCodec` um
  die Bereinigungsphase (T001-T002) ergänzen; Backend-Bausteine
  `UploadHandler` (Pfadberechnung T005-T009), `Renderer`
  (`renderFrameToPng`/`renderTilemapToPng`, T011-T014) und `download.php`
  (Frame-/Tilemap-Routing, PDI-Entfernung, T015-T017) aktualisieren.
  Depends on T001-T017.

- [X] T024 [P] `arc42/06-laufzeitsicht.md`: Save-Sequenz um die neue
  Bereinigungsphase ergänzen (T001-T002); Download-Sequenz um
  Frame-/Tilemap-Auswahl und den Wegfall der PDI-Route aktualisieren
  (T015-T017). Depends on T001-T017.

- [X] T025 [P] `docs/architecture/security-review-backend.md`: neue Zeile
  ergänzen — Dateinamen, die aus `client_image_id` (geräteseitig gesetzt,
  serverseitig bereits whitelist-validiert per
  `^[a-z0-9\-]{1,64}$` in `upload.php`) abgeleitet werden, sind gegen
  Pfad-/Verzeichnistraversierung abgesichert (FR-009, research.md R3).
  Zusätzlich verifizieren, dass S-04 (PDI-Format-Validierung) nach
  Entfernen der PDI-Download-Route (T015) weiterhin zutrifft (interne
  PDI-Verarbeitung bleibt bestehen). Depends on T005-T006, T015.

- [X] T026 `arc42/adr/ADR-038-Backend-Dateibenennung-client-image-id.md`
  anlegen — Inhalt aus plan.md AD-038 (Entscheidung, Begründung,
  verworfene Alternative "separates `name`-Feld aus `frames.json`
  parsen"). Depends on T022.

- [X] T027 [P] `arc42/11-risiken-und-technische-schulden.md`: zwei neue
  Einträge ergänzen — (1) Fehler bei der Tile-Neuindizierung
  (`pruneUnusedTiles()`-Remap) als höchstes Einzelrisiko dieser Spec,
  Mitigation über T003/T004; (2) SDK-Namenskonvention-Drift-Risiko für
  `-table-16-16`-Dateien bei künftigen SDK-Versionen (plan.md
  Risiko-Review). Zusätzlich als Prozess-Lernpunkt vermerken: AD-005 war
  seit dem v0.3.0-Formatwechsel mit falschem "umgesetzt"-Status
  dokumentiert, ohne dass dies bei früheren Governance-Reviews auffiel.

- [X] T028 [P] `backend/TESTING.md`: neue Abschnitte (analog zu
  `quickstart.md` B1-B6) dauerhaft ergänzen — Upload mit/ohne `image_id`,
  Re-Sync-Überschreiben, Frame-PNG-Abruf, Tilemap-PNG, PDI-Route-410
  (spec 007 hat mit T010 dasselbe Muster für neue Szenarien etabliert).

- [X] T029 Abschließender Architektur-Review-Durchgang: `plan.md`
  "Post-Design Re-Check" gegen den tatsächlich umgesetzten Code (T001-T020)
  bestätigt — keine neue Abstraktionsschicht, keine neue
  Datenbank-Migration entstanden (bestätigt: `backend/sql/migrations/`
  unverändert, `client_image_id`/Frame-Anzahl vollständig aus Bestehendem
  abgeleitet). Zusätzlich entschieden: `specs/005-backend-service/
  contracts/backend-api.md` E-06 bleibt inhaltlich unverändert (Autorität
  bleibt `contracts/backend-api-amendment.md`, identisches Muster zu Spec
  007), aber um einen kurzen Verweis-Kommentar ergänzt ("Entfernt seit
  Spec 009 — liefert 410 Gone... Rest des Abschnitts nur noch historisch"),
  damit niemand die Basis-Contract-Datei isoliert liest und PDI-Download
  für weiterhin verfügbar hält. `checklists/requirements.md` unverändert
  vollständig (16/16). Audit-Evidenz-Checkpoints unten aktualisiert.
  Owner: Entwickler; Evidenz: dieser Task-Abschluss + T001-T031 vollständig
  abgeschlossen, inkl. Live-Validierung gegen https://www.hans-dither.de
  und zwei dabei gefundener/behobener Deployment-Bugs (T030/T031).
  Depends on T001-T028.

**Checkpoint**: Feature vollständig, alle Architektur-Evidenz-Artefakte
aktuell, bereit für `/speckit-implement` oder direkten Merge.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: N/A — kein Blocker
- **Foundational (Phase 2)**: N/A — kein Blocker für andere Phasen
- **User Stories (Phase 3-5)**: Können nach Phase 1/2 (die es nicht gibt)
  sofort beginnen. US1 (T001-T004, `Source/`) ist vollständig dateidisjunkt
  zu US2/US3 (`backend/`) und kann parallel bearbeitet werden. US2
  (T005-T010, ausschließlich `upload_handler.php`) und US3 (T011-T020,
  `renderer.php`/`download.php`/`index.php`) berühren ebenfalls
  unterschiedliche Dateien — US3 ist funktional unabhängig von US2
  einsetzbar (liefert dann übergangsweise UUID-basierte Namen), spec.md
  empfiehlt aber die Reihenfolge US2 vor US3 für sprechende Dateinamen ab
  dem ersten Tag.
- **Polish (Phase 6)**: Hängt von allen drei User Stories ab (T021-T029
  dokumentieren den tatsächlich umgesetzten Zustand).

### User Story Dependencies

- **US1 (P1)**: Keine Abhängigkeit von anderen Stories. T001→T002
  sequenziell (T002 nutzt die in T001 geschaffene Funktion), T003 kann
  parallel zu T001/T002 entstehen (eigene Datei), T004 hängt von
  T001-T003 ab.
- **US2 (P1)**: Keine Abhängigkeit von anderen Stories. T005→T006→T007→
  T008/T009 sequenziell (dieselbe Funktion, dieselbe Datei), T010 hängt
  von T005-T009 ab.
- **US3 (P2)**: Keine harte Abhängigkeit von US2 (siehe Foundational-Notiz
  oben), inhaltlich aber sinnvoll danach. Intern: T011 vor T012/T013
  (`writePng()`-Verallgemeinerung ist Voraussetzung); T014 unabhängig;
  T015 parallel zu T011-T014 möglich; T016 hängt von T012 ab, T017 von
  T013; T018 parallel zu T011-T017 möglich (anderes File); T019 hängt von
  T018 ab (gleiches File); T020 hängt von allem ab.

### Within Each User Story

- Keine Tests-vor-Implementierung-Reihenfolge (kein TDD angefordert;
  US1s Lua-Test in T003 verifiziert die in T001/T002 fertiggestellte
  Implementierung, Backend-Verifikation ist grundsätzlich nach
  Implementierung via `quickstart.md`)
- `quickstart.md`-Validierung immer als letzter Task je Story

---

## Parallel Execution Examples

```bash
# US1 und US2/US3 sind vollstaendig dateidisjunkt -> parallel bearbeitbar:
Task: "T001-T004 Source/ImageStoreCodec.lua + tests/headless_tests.lua (US1)"
Task: "T005-T010 backend/includes/upload_handler.php (US2)"

# Innerhalb von US3: T015 (download.php PDI->410) und T018 (index.php JSON)
# sind unabhaengig von den renderer.php-Aenderungen (T011-T014):
Task: "T011-T014 backend/includes/renderer.php (US3)"
Task: "T015 backend/public/download.php PDI-Route (US3, parallel)"
Task: "T018 backend/public/index.php JSON-Response (US3, parallel)"

# Polish-Phase: T021/T022/T023/T024/T025/T027/T028 sind unterschiedliche Dateien:
Task: "T021+T022 arc42/09-architekturentscheidungen.md"
Task: "T023 arc42/05-bausteinsicht.md"
Task: "T024 arc42/06-laufzeitsicht.md"
Task: "T025 docs/architecture/security-review-backend.md"
Task: "T027 arc42/11-risiken-und-technische-schulden.md"
Task: "T028 backend/TESTING.md"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1/2 entfallen (N/A)
2. T001-T004 umsetzen (Tile-Bereinigung im Editor)
3. **STOP and VALIDATE**: `lua tests/headless_tests.lua` + `pdc`-Build
4. Das im Feature-Wunsch zuerst genannte Kernproblem (ungenutzte Tiles auf
   dem Gerät) ist an diesem Punkt bereits gelöst — US2/US3 sind
   Backend-seitige Ergänzungen, kein Blocker für den MVP-Nutzen von US1

### Incremental Delivery

1. US1 (T001-T004) → Speichereffizienz auf dem Gerät (MVP)
2. US2 (T005-T010) → Backend-Dateien sprechend benannt
3. US3 (T011-T020) → PNG-/Tilemap-Export, PDI-Download entfällt
4. Polish (T021-T029) → Architektur-Evidenz vollständig

### Parallel Team Strategy

Mit zwei Personen: eine übernimmt US1 (T001-T004, `Source/`+`tests/`,
vollständig dateidisjunkt), die andere US2 dann US3 (T005-T020,
`backend/`, sequenziell wegen der spec.md-Empfehlung "US2 vor US3"). Bei
drei Personen kann US3 bereits parallel zu US2 begonnen werden
(Foundational-Notiz: keine harte Abhängigkeit), muss dann aber vor T020
auf T005-T010 warten, falls die Validierungsszenarien projektnamenbasierte
Dateinamen voraussetzen sollen.

---

## Audit-Evidenz-Checkpoints (iSAQB-Preset)

| Checkpoint | Status | Evidenz | Owner |
|---|---|---|---|
| Architektur-Arbeitsprodukte (arc42 Kap. 5/6) | ✅ Erfüllt | T023/T024 umgesetzt: `arc42/05-bausteinsicht.md` (ImageStoreCodec/UploadHandler/Renderer/download.php) und `06-laufzeitsicht.md` (Save-Sequenz + Frame-/Tilemap-Download-Sequenz, PDI-Wegfall) aktualisiert | Entwickler |
| Sicherheits-Evidenz (`docs/architecture/security-review-backend.md`) | ✅ Erfüllt | T025 umgesetzt: neue Zeile S-12 (Dateinamens-Sanitisierung) + S-04-Verifikation nach PDI-Entfernung | Entwickler |
| AD-005 (Status-Korrektur) | ✅ Erfüllt | T021 umgesetzt: Status-Zeile korrigiert, Konsequenz um Invariante/Mechanismus ergänzt | Entwickler |
| AD-038 (Backend-Dateibenennung) | ✅ Erfüllt | T022 (arc42 Kap. 9.26) + T026 (`arc42/adr/ADR-038-...md`) umgesetzt | Entwickler |
| Risiko-/Schulden-Review (`arc42/11-...md`) | ✅ Erfüllt | T027 umgesetzt: R-25 (Tile-Neuindizierung), R-26 (SDK-Namenskonvention-Drift) + Prozess-Lernpunkt zur AD-005-Diskrepanz ergänzt | Entwickler |
| Constitution-V-Gates für `Source/ImageStoreCodec.lua` (US1) | ✅ Erfüllt | T004: `lua tests/headless_tests.lua` → "ALLE TESTS BESTANDEN" (0 FAILs), `pdc Source "Hans Dither.pdx"` → fehlerfrei | Entwickler |
| Tile-Neuindizierung Round-Trip-Verifikation | ✅ Erfüllt | T003/T004: 4 Fälle inkl. Integrations-Round-Trip über die echte `newSaveOperation()`-Coroutine bestanden | Entwickler |
| Backend-Regressionsszenarien (`backend/TESTING.md`) | ✅ Erfüllt | T028 umgesetzt: Abschnitt 8 (B1-B6) dauerhaft ergänzt, Checkliste aktualisiert | Entwickler |
| Backend-Live-Validierung (B1-B6) | ✅ Erfüllt | T010/T020 gegen https://www.hans-dither.de durchgeführt (2026-08-09) — alle 6 Szenarien bestanden, siehe T010/T020-Notizen | Entwickler |
| Deployment-Pipeline-Sicherheit (`deploy.sh`) | ✅ Erfüllt | T030 (`.htaccess`-Routing um `tilemap` ergänzt) + T031 (kritischer Fund: `uploads/` fehlte in den `--delete`-Excludes, hätte bei jedem Deploy Nutzerdaten gelöscht — jetzt ausgeschlossen) | Entwickler |
| Multi-Geräte-/Sybil-Restrisiko (Spec 007, unverändert) | Open | Bewusst außerhalb des Scopes dieser Spec; Trigger zur Neubewertung unverändert: künftige Lösch-Funktion oder beobachteter Missbrauch (spec 007 Edge Cases) | Entwickler |
| SDK-Namenskonvention-Drift (`-table-16-16`) bei künftigen SDK-Versionen | Open | Kein aktueller Anlass zur Sorge (research.md R6, SDK-Doku verifiziert; Live-Test T020 bestätigt korrekte 48×16-PNG); Trigger zur Neubewertung: nächstes Playdate-SDK-Update (Constitution Prinzip I) | Entwickler |
| E-06-Entfernung im Basis-Contract erkennbar (`specs/005-backend-service/contracts/backend-api.md`) | ✅ Erfüllt | T029: Verweis-Kommentar bei E-06 ergänzt ("Entfernt seit Spec 009 — liefert 410 Gone"); Amendment-Datei bleibt Autorität | Entwickler |

