# Phase 0 Research: Tile-Bereinigung, projektbasierte Dateibenennung und PNG-Export im Backend

**Feature**: 009-tile-cleanup-png-export | **Date**: 2026-08-09

Alle Punkte gegen den tatsächlichen Ist-Zustand des Codes verifiziert
(`Source/ImageStoreCodec.lua`, `Source/ImageStore.lua`, `Source/EditorRoom.lua`,
`Source/RoomOperation.lua`, `backend/includes/*.php`, `backend/public/*.php`,
`arc42/09-architekturentscheidungen.md`) — nicht nur gegen spec.md, gemäß dem
projektweiten Grundsatz "gegen den echten Code verifizieren statt gegen
Annahmen" (Constitution Prinzip I, analog auf Backend-Code angewendet;
etabliertes Muster aus Spec 007 research.md).

---

## R1: AD-005 "Tile-Kompaktierung vor Save" existiert bereits — ist aber seit v0.3.0 nicht mehr umgesetzt

**Befund**: `arc42/09-architekturentscheidungen.md` Abschnitt 9.5 dokumentiert
bereits eine Architekturentscheidung mit exakt diesem Inhalt:

> AD-005: Tile-Kompaktierung vor Save — Status: umgesetzt — Entscheidung:
> Ungenutzte Tiles werden entfernt, Referenzen remapped, Basistiles immer
> behalten.

Diese Entscheidung stammt aus der Pulp-JSON-Ära (vor AD-017, das den
Speicherpfad in v0.3.0 auf PDI-Tilemap/Imagetable umgestellt hat). AD-017
listet explizit "ersetzt AD-003 und AD-004 im Speicherpfad" — AD-005 wird
dort NICHT erwähnt, ist also weder offiziell ersetzt noch fortgeführt worden.
Der tatsächliche Code bestätigt, dass die Kompaktierung beim Übergang auf das
PDI-Format verloren ging: `Source/ImageStoreCodec.lua:26-35` (`newSaveOperation`,
Phase "Dedup") enthält den wörtlichen Kommentar:

```lua
-- Phase 1: Dedup (T014 - wird später in US2 implementiert, hier zunächst ohne Dedup)
-- Für MVP: alle Tiles werden als einzigartig behandelt
coroutine.yield("Dedup")
```

D. h. die Phase existiert als Platzhalter, tut aber nichts — der Status
"umgesetzt" in AD-005 ist für den aktuellen (PDI-basierten) Code **falsch**.
Dieser vorliegende Task ist exakt die im Kommentar referenzierte, seit v0.3.0
offene Arbeit (T014).

**Decision**: Kein neues ADR für die Grundidee "ungenutzte Tiles entfernen,
Basistiles behalten" — AD-005 wird bei der Umsetzung aktualisiert (Status,
Entscheidungstext bezieht sich künftig explizit auf `ImageStoreCodec.lua`
statt des früheren Pulp-Pfads, Konsequenz-Zeile ergänzt um den Hinweis auf
den jetzt echten Remap-Mechanismus), analog zum bestehenden Präzedenzfall
AD-017 ("ersetzt AD-003 und AD-004" — Status-Zeile wird in-place geändert,
kein neues ADR-Dokument für dieselbe Kernentscheidung). Die konkrete
Formulierung wird als Planungsartefakt hier festgehalten und bei der
Umsetzung in `arc42/09-architekturentscheidungen.md` übernommen (siehe
Abschnitt "Architecture Governance" unten).

---

## R2: Kein Bedarf, den Live-Editierzustand (`imageData`) beim Speichern zu mutieren

**Befund**: Der einzige Speicher-Einstiegspunkt im Editor ist
`EditorRoom.lua:342-354` (`handleSaveAndExit`, System-Menü "save + exit") —
er startet `ImageStoreCodec.newSaveOperation(imageData)` und wechselt im
`onComplete`-Callback **unbedingt** den Raum zurück zu `selectionRoom`. Es
gibt keinen Menüpunkt oder Codepfad, der nach dem Speichern im selben
`imageData`-Objekt weiter editieren lässt. Wird der Editor erneut betreten,
lädt `startLoadOperation()` → `ImageStoreCodec.newLoadOperation()` das Bild
vollständig neu von der (jetzt bereinigten) Datei und ersetzt `imageData`
komplett (`EditorRoom.lua:316`, `handleLoadSuccess`).

`ImageStore.createImage()` (`ImageStore.lua:121-179`) treibt
`newSaveOperation` ebenfalls synchron, aber unmittelbar nach der Anlage eines
neuen Bildes — auch hier gibt es kein „Weiterbearbeiten desselben
`imageData`-Objekts" im Anschluss; die Funktion gibt nur die `id` zurück,
das lokale `imageData` wird verworfen.

**Decision**: Die Tile-Bereinigung (FR-001 bis FR-003) wird als **reine,
lokale Transformation innerhalb der Save-Coroutine** implementiert: eine neue
Funktion `ImageStoreCodec.pruneUnusedTiles(imagetable, frames, tileCount)`
berechnet ein bereinigtes `imagetable`, neu durchnummerierte `frames` und den
neuen `tileCount` **ohne** `imageData.imagetable`, `imageData.frames` oder
`imageData.hashIndex` zu verändern. Diese lokalen Werte ersetzen ab der
"Dedup"-Phase die bisherigen `imagetable`/`frames`/`tileCount`-Variablen für
die nachfolgenden Phasen (Sheet, Frames, Bilddaten, Preview). FR-004
("aktive Editier-Sitzung arbeitet nach dem Speichern mit dem bereinigten
Stand weiter") ist damit durch die bestehende Raum-Lebenszyklus-Garantie
bereits erfüllt — es gibt keinen Beobachtungspunkt, an dem ein
divergierendes `imageData` sichtbar würde, da das Objekt beim Verlassen des
Editors verworfen und beim Wiedereintritt frisch geladen wird. Eine
zusätzliche Mutation von `imageData` (inkl. korrektem Remap von `hashIndex`
und Neubindung von `tilemap:setImageTable()`/`setTiles()`) wäre redundante
Komplexität ohne beobachtbaren Nutzen (Constitution IV) und ein
unnötiges Fehlerrisiko. Dies war im spec.md-Architecture-Governance-Abschnitt
als offener ADR-Kandidat vermerkt — wird hiermit als Recherche-Ergebnis
aufgelöst, nicht als eigenes ADR (kein architektonischer Trade-off, sondern
eine Tatsachenfeststellung über den bestehenden Raum-Lebenszyklus).

**Invariante, die die Implementierung einhalten MUSS**: `pruneUnusedTiles()`
liefert immer `newTileCount >= 2` — auch wenn nach der Bereinigung nur die
beiden Basistiles referenziert sind (oder gar keine Nicht-Basis-Tiles
existieren). Grund: `ImageStore.createImage()` erzeugt ein neues Bild mit
genau 2 Tiles und einem Frame, dessen 375 Positionen alle auf Index 1
zeigen — ein Bereinigungsalgorithmus, der `tileCount` naiv aus der Menge
referenzierter Indizes berechnet, würde hier fälschlich `tileCount = 1`
liefern. `ImageStoreCodec.sliceSheetToImagetable()` würde das beim nächsten
Laden zwar mit `math.max(count, 2)` unsichtbar "reparieren" (ein Fake-Tile 2
entstünde) — das widerspricht aber FR-002/FR-003 (Positionen müssen exakt auf
denselben Inhalt zeigen) und ist daher als Implementierungsfehler zu werten,
nicht als akzeptabler Grenzfall.

---

## R3: `client_image_id` ist bereits der sanitisierte Projektname — kein neues Feld nötig

**Befund**: `Source/ImageStore.lua:87-107` (`sanitizeName`) erzeugt aus dem
vom Nutzer vergebenen Projektnamen eine ID (Kleinbuchstaben, nur
`a-z0-9-`, Fallback `"unnamed"`) — dieselbe ID wird als lokaler
Speicherordner-Name verwendet (`ImageStore.lua:127`, `saves/<id>/`) UND beim
Sync als `image_id`-Feld mitgeschickt (`Source/SyncService.lua:477`,
`buildMultipartBody`). `backend/public/upload.php:74-77` validiert diesen
Wert serverseitig erneut gegen dieselbe Zeichenklasse
(`/^[a-z0-9\-]{1,64}$/`) und verwirft ihn bei Nichtübereinstimmung
(auf `null`, kein Upload-Abbruch) — er landet als `client_image_id` in der
`images`-Tabelle (`002_sync_extensions.sql`, bereits `UNIQUE (uid,
client_image_id)`). Es gibt in `ImageStore.lua` **keine Umbenennungsfunktion**
für bestehende Projekte — die ID ist ab Anlage stabil für die Lebensdauer
des Projekts auf dem Gerät.

**Decision**: FR-006/FR-007 werden ohne neues Datenbankfeld und ohne
Parsen von `name` aus `frames.json` umgesetzt — `client_image_id` (bereits
vorhanden, bereits validiert, bereits eindeutig pro UID) wird direkt als
Basis für alle Backend-Dateinamen verwendet. Fällt `client_image_id` weg
(manueller Web-Upload ohne `image_id`-Feld), fällt die Basis auf die
interne `image_id` (UUID) zurück — identisch zum bisherigen Verhalten.
FR-009 (keine Pfadtraversierung) ist durch die bereits bestehende
Whitelist-Regex-Prüfung in `upload.php` abgedeckt (keine `.`/`/`/Null-Bytes
möglich); es ist keine zusätzliche Sanitisierung nötig, nur die
Wiederverwendung dieses bereits geprüften Werts für einen neuen Zweck
(Dateiname statt nur DB-Lookup-Schlüssel).

**Alternativen verworfen**:
- Neues, separates `name`-Feld aus `frames.json` parsen und in einer neuen
  Spalte persistieren — verworfen: `client_image_id` leistet exakt dasselbe
  bereits, mit bereits etablierter Validierung und Eindeutigkeits-Constraint;
  ein Parallel-Feld wäre eine unnötige zweite Wahrheitsquelle (Constitution
  IV).
- Die interne `id` (UUID, DB-Primärschlüssel) durch `client_image_id`
  ersetzen und URLs/Berechtigungsprüfung darauf umstellen — verworfen (siehe
  spec.md FR-008/Assumption): `download.php:34` validiert den `id`-Pfad-
  Parameter bereits hart gegen ein UUID-Muster; eine Umstellung der
  Adressierung wäre eine Scope-Erweiterung, die im Feature-Wunsch nicht
  verlangt ist ("nenne die DATEIEN", nicht "die URLs").

---

## R4: Update-in-place aktualisiert `pdi_path`/`json_path` NICHT — Korrektur nötig, sonst zeigt die DB nach Umbenennung ins Leere

**Befund**: `backend/includes/upload_handler.php:104-116` — der
Update-in-place-Zweig (`existing_image_id !== null`) führt aus:

```php
UPDATE images SET png_path = NULL, gif_path = NULL, uploaded_at = NOW() WHERE id = ?
```

`pdi_path`/`json_path` werden dabei **nicht** aktualisiert, weil sie bisher
über die gesamte Lebensdauer eines Datensatzes konstant blieben (immer aus
der unveränderlichen internen `image_id` berechnet). Sobald die
Pfadberechnung stattdessen von `client_image_id` abhängt (R3), gilt das
nicht mehr automatisch für **bereits vor dieser Änderung angelegte Zeilen**:
Beim nächsten Re-Sync eines solchen Projekts nimmt `handleUpload()` den
Update-in-place-Zweig (bekannte `client_image_id`), berechnet NEUE Pfade
(`{client_image_id}.pdi`/`.json`), schreibt die Dateien dorthin
(`move_uploaded_file`) — aber die DB-Zeile behält die ALTEN, jetzt nicht mehr
existierenden `pdi_path`/`json_path`-Werte. Jeder nachfolgende Render- oder
Download-Versuch würde eine nicht mehr existierende Datei lesen wollen.

**Decision**: Der Update-in-place-Zweig MUSS `pdi_path`/`json_path` in
JEDEM Fall neu setzen (nicht nur `png_path`/`gif_path` zurücksetzen):

```php
UPDATE images SET pdi_path = ?, json_path = ?, png_path = NULL, gif_path = NULL, uploaded_at = NOW() WHERE id = ?
```

Zusätzlich: Unterscheiden sich die neu berechneten Pfade von den zuvor in
der DB gespeicherten (Alt-Datensatz mit UUID-basiertem Namen, jetzt erstmals
umbenannt), MÜSSEN die alten Dateien (`pdi_path`, `json_path` und — falls
gesetzt — die alten `png_path`/`gif_path`) nach erfolgreichem Schreiben der
neuen Dateien und erfolgreichem COMMIT der Transaktion best-effort gelöscht
werden (`unlink()`, Fehler beim Löschen werden geloggt, nicht als
Request-Fehler behandelt) — sonst blieben verwaiste Dateien im
UID-Verzeichnis liegen (Speicherleck über die Zeit, betrifft potenziell
jeden der bis zu 12 Bestands-Slots pro Gerät, Spec 007 FR-011). Sind alte
und neue Pfade identisch (Normalfall: Projekt wurde schon einmal seit
dieser Änderung synchronisiert), entfällt das Löschen (keine Änderung).

Die für diesen Schritt nötigen Alt-Pfade MÜSSEN VOR dem UPDATE gelesen
werden — der bestehende Lookup in Schritt 4a
(`upload_handler.php`: `SELECT id FROM images WHERE uid = ? AND
client_image_id = ?`) wird dafür auf `SELECT id, pdi_path, json_path,
png_path, gif_path FROM images WHERE ...` erweitert; sonst sind die
Alt-Werte nach dem UPDATE nicht mehr abrufbar.

**Zweite, davon unabhängige Lücke (nicht nur bei Umbenennung — bei JEDEM
Re-Sync)**: R5 legt fest, dass Frame-PNGs ab dem zweiten Frame (0-basiert
`frame=1` aufwärts, spec.md Clarifications) sowie die Tilemap-PNG NICHT
über eine DB-Spalte invalidiert werden, sondern rein über `file_exists()`
entschieden wird, ob neu gerendert wird. Das ist beim BISHERIGEN
Standard-Frame-PNG (`frame=0`)/GIF unproblematisch, weil deren Pfad-Spalten
bei jedem Update-in-place explizit auf `NULL` gesetzt werden (bestehendes
Verhalten, unverändert) — das ist die Invalidierung. Für
`{base}-frame-N.png` (N ≥ 1) und `{base}-table-16-16.png` GIBT es aber
keine Spalte, die auf `NULL` gesetzt werden könnte: Lädt ein Nutzer ein
Projekt mit geändertem zweiten Frame (`frame=1`) erneut hoch (gleicher
`base`, da `client_image_id` unverändert), existiert `{base}-frame-1.png`
von der vorherigen Fassung bereits auf der Festplatte — der
`file_exists()`-Check schlägt an, und die ALTE, jetzt veraltete PNG-Datei
wird unbegrenzt weiter ausgeliefert, obwohl die zugrunde liegende
PDI-Datei bereits die neue Fassung ist.

**Decision (Ergänzung)**: Der Update-in-place-Zweig MUSS bei JEDEM
Re-Sync (nicht nur bei Umbenennung) zusätzlich alle bereits vorhandenen
abgeleiteten Render-Artefakte für den AKTUELLEN `base` löschen, bevor die
neuen Dateien geschrieben werden: alle Dateien, die dem Muster
`{base}-frame-*.png` entsprechen (`glob()`), sowie — falls vorhanden —
`{base}-table-16-16.png`. Da `base` bereits gegen `^[a-z0-9\-]{1,64}$`
validiert ist, enthält es keine `glob()`-Metazeichen (`*`, `?`, `[`) — das
Muster ist sicher bildbar. Dieser Schritt ist UNABHÄNGIG vom
Umbenennungs-Cleanup weiter oben (der nur bei geänderten Pfaden greift) und
läuft bei JEDEM Update-in-place, auch wenn sich der Dateiname nicht
geändert hat — genau wie das bestehende `png_path = NULL`/`gif_path = NULL`
für den Standardfall.

---

## R5: Backend-Dateinamen-Schema — Basis-Pfad statt Doppel-Endung, on-demand ohne neue DB-Spalte

**Befund**: `backend/includes/renderer.php:60` und `:102` hängen `.png`
bzw. `.gif` direkt an den vollständigen `pdi_path` an (der bereits auf
`.pdi` endet) — erzeugt de facto `{basis}.pdi.png`/`{basis}.pdi.gif` statt
der im Contract (`specs/005-backend-service/contracts/backend-api.md` E-08/
E-09) dokumentierten `{id}.png`/`{id}.gif`. Da beide Downloadpfade ohnehin
umgebaut werden (frame-Parameter, neue Tilemap-Route), wird dieser
Bestandsfehler im selben Zug behoben (Constitution IV — keine
Doppel-Endungen beibehalten, wenn der Code an dieser Stelle ohnehin
angefasst wird).

**Decision**: Eine gemeinsame Basis (`$base = $client_image_id ??
$image_id`, identisch zur Pfadberechnung in `upload_handler.php`, R3/R4)
bestimmt alle abgeleiteten Dateinamen:

| Datei | Muster | Beispiel (`base="meinbild"`) |
|---|---|---|
| PDI (intern, kein Download mehr) | `{base}.pdi` | `meinbild.pdi` |
| JSON | `{base}.json` | `meinbild.json` |
| Frame-PNG (Standard, `frame`-Parameter fehlt oder `=0`) | `{base}.png` | `meinbild.png` |
| Frame-PNG (`frame=N`, N ≥ 1, 0-basiert — Nutzer-Klärung in spec.md) | `{base}-frame-{N}.png` | `meinbild-frame-2.png` |
| Tilemap-PNG | `{base}-table-{zellbreite}-{zellhöhe}.png` | `meinbild-table-16-16.png` |
| GIF | `{base}.gif` | `meinbild.gif` |

Der Standardfall (`frame` fehlt oder `=0`) bleibt bewusst `{base}.png` ohne
Suffix — identisch zum bisherigen alleinigen PNG-Dateinamen, sodass die
bestehende `png_path`-Spalte (Cache-Marker "wurde schon einmal gerendert")
unverändert für GENAU diesen einen Fall weiterverwendet werden kann
(kein Schema-Wechsel für den Standardfall). Für `frame >= 1` gibt es **keine
DB-Caching-Spalte** — der Pfad ist aus `base` und `frame` vollständig
deterministisch berechenbar, ein `file_exists()`-Check (exakt das bereits
bestehende Muster aus `deliverPng()`) reicht aus, ohne neue Spalte
(Constitution IV, analog zur in Spec 007 R1 verworfenen redundanten
Zähler-Spalte — ein aus vorhandenen Daten ableitbarer Wert wird nicht
zusätzlich persistiert).

**`frame_count` für die Galerie-Anzeige** (aus der Nutzer-Klärung: Galerie
mit einem Link je Frame auf der Projekte-Seite): wird beim Rendern der
Bilder-Liste (`handleImagesRequest()`/`showImagesPage()` in
`backend/public/index.php`) aus der bereits vorhandenen `json_path`-Datei
gelesen (`json_decode()`, `count($data['frames'])`) — kein neues DB-Feld,
kein neuer Query. Bei max. 12 Bildern pro UID (Spec 007 FR-001) ist das
zusätzliche Lesen kleiner JSON-Dateien beim Aufruf der Listen-Seite
vernachlässigbar (dieselbe Größenordnung wie die bereits heute für
`Validation::validateFramesJsonSchema()` gelesenen Dateien, Spec 007 R4).

---

## R6: Tilemap-PNG — Sheet 1:1 als PNG, keine Tile-Slicing-Logik nötig

**Befund**: `Renderer::loadAssets()` (`renderer.php:118-168`) parst
`sheet.pdi` bereits vollständig über `PdiParser::parseFile()` zu
`['width', 'height', 'rows']` (Roh-Pixelzeilen), BEVOR es die einzelnen
16×16-Tiles daraus schneidet. Für die Tilemap-PNG (FR-011) wird genau diese
Zwischenform 1:1 als PNG geschrieben — kein Tile-Slicing, kein erneutes
Zusammensetzen, identische Breite/Höhe wie das Sheet.
`Renderer::writePng()` ist aktuell hart auf `self::$canvasWidth/Height`
(400×240) verdrahtet; wird verallgemeinert, um Breite/Höhe aus den
übergebenen `$rows` (bzw. expliziten Parametern) zu übernehmen, statt der
Konstanten — eine kleine, lokale Signaturänderung, kein neuer Baustein.

**Zusätzlich verifiziert** (Zweiteffekt der Tile-Bereinigung, R1-R3): Ein
durch die neue Bereinigung kleineres Sheet ändert zum ersten Mal die
tatsächliche Sheet-Breite (`ImageStoreCodec.getSheetDimensions()`: <25
Tiles → schmaleres Sheet, nicht mehr zwingend 400px breit).
`Renderer::loadAssets()` leitet `$sheet_tiles_per_row` bereits dynamisch aus
`$sheet['width']` ab (`intdiv($sheet['width'], $ts)`, Zeile 143) statt die
Konstante 25 fest anzunehmen — das bestehende Backend-Slicing bleibt damit
auch für schmalere, bereinigte Sheets korrekt, ohne Änderung. Die
Tilemap-PNG-Route selbst umgeht dieses Slicing ohnehin komplett (schreibt
die Sheet-Rohdaten direkt), ist also von dieser Frage nicht betroffen.

**SDK-Namenskonvention-Grenzen geprüft**: `inside_playdate/7.20.12 Image
Table.md` beschreibt die Matrix-Imagetable-Ladefunktion
(`imagetable.new(name)` aus `<name>-table-<w>-<h>.png`) rein über
Zellbreite/-höhe (hier immer 16×16) und implizite Spaltenanzahl aus der
Gesamtbreite — keine Mindest- oder Vielfaches-Anforderung an die
Tile-Anzahl über die reine Bild-Teilbarkeit durch `w`/`h` hinaus. Ein
bereinigtes Sheet mit z. B. 7 Tiles (112×16 px) ist ein gültiges
Matrix-Imagetable-Bild.

---

## R7: PDI-Download entfernen — 410 statt 404, `deliverPdi()` vollständig entfernen

**Befund**: `backend/public/download.php:65-86` routet über ein
`switch ($type)`; `case 'pdi'` ruft `deliverPdi()` (Zeilen 91-106) auf, die
die Rohdatei mit `Content-Type: application/octet-stream` ausliefert.
`backend/public/index.php:371` (JSON) und `:458` (HTML) verweisen beide
darauf (`pdi_url` bzw. eine Tabellenzelle "PDI").

**Decision**: `deliverPdi()` wird vollständig entfernt (FR-014, Constitution
IV — kein toter Code, Präzedenzfall AD-037 "Clear Screen ersetzt Reset
Frame vollständig"). Der `case 'pdi':` Zweig bleibt in `download.php`
**bestehen**, liefert aber `410 Gone` mit
`{"error": "PDI-Download nicht mehr verfügbar"}` — bewusst NICHT einfach in
den `default:`-Zweig (400 "Ungültiger Dateityp") fallen gelassen, da `pdi`
kein unbekannter, sondern ein bewusst entfernter Typ ist (FR-013 verlangt
eine "eindeutige" Antwort; 410 transportiert diese Unterscheidung auch auf
HTTP-Ebene). Die Prüfung erfolgt NACH der bestehenden Auth-/Berechtigungs-
prüfung (identische Reihenfolge wie alle anderen Typen), damit kein
zusätzlicher, unauthentifizierter Prüfpfad entsteht. Die interne Nutzung
der PDI-Datei bleibt unberührt (`PdiParser::parseFile()` wird von
`Renderer::loadAssets()` weiterhin für JEDES Rendering benötigt) — nur der
Download-Endpunkt für Nutzer entfällt.

---

## Zusammenfassung: Geänderte/neue Bausteine

| Bedarf | Baustein | Status |
|---|---|---|
| Tile-Bereinigung (FR-001..003) | `ImageStoreCodec.pruneUnusedTiles()` (neu) + `newSaveOperation()`-Phase "Dedup" (geändert, war Platzhalter) | NEU |
| Kein Live-State-Sync nötig (FR-004) | — (durch Raum-Lebenszyklus bereits erfüllt, R2) | KEINE ÄNDERUNG NÖTIG |
| Backend-Dateibasis (FR-006/007/008/009) | `UploadHandler::handleUpload()` (Pfadberechnung via `client_image_id`) | GEÄNDERT |
| Update-in-place-Pfadkorrektur + Aufräumen (R4, Voraussetzung für FR-006 bei Bestandsdaten) | `UploadHandler::handleUpload()` (UPDATE-Query + `unlink()`) | NEU (Korrektur eines sonst entstehenden Bugs) |
| Frame-PNGs (FR-010) | `Renderer::renderFrameToPng()` (neu, ersetzt bisheriges `renderToPng()`), `download.php` `frame`-Query-Parameter | NEU/GEÄNDERT |
| Tilemap-PNG (FR-011) | `Renderer::renderTilemapToPng()` (neu), `writePng()` verallgemeinert, `download.php` neue Route `tilemap` | NEU |
| PDI-Download entfernen (FR-012/013/014) | `download.php` (`deliverPdi()` entfernt, `case 'pdi'` → 410), `index.php` (JSON-Feld/HTML-Spalte entfernt) | GEÄNDERT/ENTFERNT |
| `frame_count` für Galerie | `index.php` (`handleImagesRequest()`/`showImagesPage()`, JSON-Datei lesen) | NEU (kein DB-Feld) |
| Architektur-Doku | `arc42/09-architekturentscheidungen.md` AD-005 (aktualisiert), neues AD (Backend-Dateibenennung), `docs/architecture/security-review-backend.md` (neue Zeile) | GEPLANT (Umsetzung in Tasks-Phase) |
