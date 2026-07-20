# Phase 0 Research: Absicherung des Backends gegen unbegrenzte/missbräuchliche Uploads

**Feature**: 007-backend-upload-hardening | **Date**: 2026-07-19

Alle Punkte gegen den tatsächlichen Ist-Zustand des Backends verifiziert
(`backend/includes/validation.php`, `backend/includes/upload_handler.php`,
`backend/includes/pdi_parser.php`, `backend/includes/database.php`,
`backend/sql/migrations/001_create_tables.sql`/`002_sync_extensions.sql`) —
nicht nur gegen die Nutzerbeschreibung, gemäß Constitution Prinzip I
(sinngemäß auf Backend-Code angewendet: erst prüfen, was bereits da ist,
bevor neu gebaut wird) und dem projektweiten Grundsatz "gegen den echten
Code verifizieren statt gegen Annahmen".

---

## R1: Upload-Obergrenze pro UID — Transaktion + Row-Lock auf `users` statt neuem Zähler-Feld

**Ist-Zustand**: `UploadHandler::handleUpload()` prüft aktuell nur
`Auth::uidExists($uid)`, danach werden Dateien validiert und gespeichert —
es gibt KEINE Prüfung, wie viele Bilder die UID bereits besitzt. Die
`images`-Tabelle hat bereits einen Index auf `uid` (`idx_uid`,
`001_create_tables.sql`) sowie eine Unique-Constraint `(uid,
client_image_id)` (`002_sync_extensions.sql`) — ein `COUNT(*) FROM images
WHERE uid = ?` ist damit bereits effizient möglich, ohne Schema-Änderung.

**Race-Condition-Problem**: Ein einfacher `COUNT`-Check gefolgt von einem
`INSERT` (zwei getrennte Anweisungen) ist NICHT race-safe — zwei nahezu
gleichzeitige Uploads derselben UID könnten beide denselben Zählerstand
(z. B. 11) lesen und beide erfolgreich einfügen, wodurch 13 Bilder
entstünden (FR-011).

**Decision**: `UploadHandler::handleUpload()` öffnet für den
Zähl-Check + die anschließende Neuanlage eine MySQL-Transaktion und sperrt
zu Beginn den `users`-Datensatz der UID exklusiv:

```sql
START TRANSACTION;
SELECT uid FROM users WHERE uid = ? FOR UPDATE;   -- ersetzt/ergänzt Auth::uidExists
-- nur falls NICHT Update-in-place (client_image_id unbekannt):
SELECT COUNT(*) FROM images WHERE uid = ?;        -- innerhalb derselben Transaktion konsistent
-- >= 12 -> ROLLBACK, 403
-- < 12  -> Datei-Schreibvorgänge + INSERT/UPDATE wie bisher, dann COMMIT
```

Der `users`-Datensatz existiert für jede gepairte UID bereits (angelegt
beim Pairing, Spec 005) und wird sonst nirgends exklusiv gesperrt — er
dient hier ausschließlich als natürliches, bereits vorhandenes
Sperr-Ziel ("Mutex pro UID"), OHNE dass sein Inhalt verändert wird. Zwei
gleichzeitige Uploads DERSELBEN UID werden dadurch serialisiert: der
zweite Request wartet, bis der erste committet/rollt zurück, und sieht
danach den aktualisierten Zählerstand.

**Alternativen verworfen**:
- Neues `image_count`-Zählerfeld in `users`, bei jedem Upload
  inkrementiert — verworfen: müsste bei jedem zukünftigen Lösch-/
  Bereinigungspfad synchron gehalten werden (zusätzliche Fehlerquelle,
  derzeit gibt es noch keine Löschfunktion, aber Spec 007 Edge Cases
  benennt das als zukünftig denkbar); ein `COUNT(*)` gegen die ohnehin
  vorhandene, indizierte Tabelle ist immer korrekt, ganz ohne
  Synchronisationsrisiko.
- Anwendungsseitiges Locking (z. B. PHP-`flock()` auf eine Datei pro UID)
  statt Datenbank-Transaktion — verworfen: all-inkl.com Shared Hosting mit
  potenziell mehreren PHP-Worker-Prozessen/Servern macht dateibasiertes
  Locking unzuverlässiger als einen DB-Row-Lock, der ohnehin durch MySQL
  selbst korrekt über Prozessgrenzen hinweg funktioniert (Constitution IV
  — die einfachere UND korrektere Option).
- `SELECT ... FOR UPDATE` direkt auf `images` (z. B. gegen eine
  Dummy-Zeile) — verworfen: `users` ist der semantisch korrekte,
  garantiert existierende 1-Zeile-pro-UID-Anker; `images` hat bei einer
  UID ohne bisherige Uploads (0 Zeilen) kein Zeilenziel zum Sperren.

---

## R2: Dateigrößen-Grenze — 300 KB statt 10 MB, je Einzeldatei

**Ist-Zustand**: `Validation::$maxFileSize = 10 * 1024 * 1024` (10 MB),
angewendet identisch auf PDI- UND JSON-Datei (`validateUploadedFile()`
Schritt 2, sowie nochmals separat in `validateJsonFile()`). Bei
Überschreitung bereits korrekt `413 Payload Too Large` (Contract-konform
zu `specs/005-backend-service/contracts/backend-api.md` E-04).

**Decision**: `$maxFileSize` auf `300 * 1024` (300 KB) senken — gilt weiter
für BEIDE Dateien je einzeln (unverändertes Prüfmuster, nur der
Schwellwert sinkt), konsistent mit spec.md FR-006/Assumption "je
Einzeldatei, nicht als Summe". Bestehender `413`-Fehlerpfad und dessen
Meldungstext ("Datei zu groß (max. 10MB)") werden auf den neuen Wert
angepasst.

**Alternativen verworfen**: Getrennte Grenzen für PDI (typischerweise noch
kleiner) und JSON — verworfen als unnötige Komplexität; ein gemeinsamer
300-KB-Wert für beide deckt beide realistischen Dateigrößen (ein
25×~-Tile-Sheet plus 12×375-Zahlen-JSON liegt nach Beobachtung bestehender
Testdaten in `backend/TESTING.md` weit darunter) ohne zwei Konstanten
pflegen zu müssen (Constitution IV).

---

## R3: PDI-Format-Validierung — bereits vollständig vorhanden, kein Gap

**Befund**: `PdiParser::hasValidMagic()` prüft die 12-Byte-Signatur
`"Playdate IMG"`; `PdiParser::parseFile()`/`parse()` parst DANACH
vollständig: Flags (inkl. zlib-Kompressions-Bit), bei Bedarf
`gzuncompress()`, den 16-Byte-Cell-Header (`clip_width/height`, `stride`,
Clip-Ränder, Alpha-Flag), rekonstruiert die vollständige Bitmap inkl.
Alpha-Maskierung UND validiert dabei implizit Längen-Konsistenz
(`strlen($cell) < $needed` → `false` bei jeder strukturellen
Inkonsistenz). `Validation::validatePdiFile()` ruft beides auf UND prüft
zusätzlich Abmessungs-Plausibilität (`maxPdiWidth`/`maxPdiHeight`). Ein
manipulierter Datei-Inhalt mit korrekter `.pdi`-Endung, der NICHT dem
echten Format entspricht, wird an mindestens einer dieser Stufen
zuverlässig abgelehnt (Magic falsch → sofort `false`; Magic gefälscht,
aber Rest inkonsistent → `parseFile()` liefert `false` an mehreren
Stellen).

**Decision**: KEINE Code-Änderung für FR-004/FR-005 — beide Anforderungen
sind durch den bestehenden Mechanismus bereits vollständig erfüllt. Die
zugehörige Tasks-Phase (siehe tasks.md) wird als VERIFIKATIONS-Task
geführt (gezielte Negativ-Tests gegen den bestehenden Code, kein Neubau) —
vermeidet Doppel-Implementierung entgegen Constitution IV.

**Einzige Ergänzung**: `docs/architecture/security-review-backend.md`
Eintrag S-04 wird von "Dateityp-Validierung erfolgt BEVOR Dateien
gespeichert werden ✅" auf eine präzisere Formulierung aktualisiert, die
explizit die STRUKTURELLE (nicht nur Endungs-/Magic-)Tiefe der Prüfung
benennt — reine Dokumentations-Präzisierung, keine Verhaltensänderung.

---

## R4: JSON-Schema-Validierung — neue Prüfung gegen die Spec-001-Struktur

**Ist-Zustand**: `Validation::validateJsonFile()` prüft aktuell nur: (a)
Datei lesbar, (b) `json_decode()` liefert nicht `null` (syntaktisch
gültiges JSON), (c) Ergebnis ist Objekt oder Array, (d) Größe. KEINE
Prüfung von Pflichtfeldern, Datentypen oder Array-Längen — ein JSON wie
`{"foo": "bar"}` oder `[1,2,3]` würde aktuell als "valide" durchgehen und
gespeichert werden.

**Referenz-Schema** (bereits definiert in
`specs/001-pdi-storage-format/data-model.md` Abschnitt "Bild / Frames"):

| Feld | Typ | Regel |
|---|---|---|
| `version` | number | vorhanden, `>= 1` |
| `name` | string | vorhanden (Länge > 0) |
| `gridWidth` | number | exakt `25` |
| `gridHeight` | number | exakt `15` |
| `tileCount` | number | `>= 1` |
| `frames` | array | 1 bis 12 Einträge |
| `frames[f]` | array | exakt `gridWidth × gridHeight` = 375 Zahlen |
| `frames[f][i]` | number | `1 <= x <= tileCount` |

**Decision**: Neue Methode `Validation::validateFramesJsonSchema(array
$data): array` (aufgerufen zusätzlich zu, nicht statt der bestehenden
generischen JSON-Prüfung) — reine PHP-Feldprüfung ohne externe
JSON-Schema-Bibliothek (AD-034, Constitution IV: sechs feste Felder, eine
Array-Dimension mit fester Länge — eine generische Schema-Engine wäre für
diesen einen, stabilen Anwendungsfall unverhältnismäßig). Verletzung
IRGENDEINER Regel → Upload wird mit `400 Bad Request` und einer auf das
konkret verletzte Feld hinweisenden Meldung abgelehnt (FR-008/FR-009).

**Alternativen verworfen**:
- Externe JSON-Schema-Bibliothek (z. B. `justinrainbow/json-schema`) mit
  einer `.json`-Schema-Definitionsdatei — verworfen (AD-034): zusätzliche
  Composer-Abhängigkeit auf Shared Hosting (Spec 005 etabliert explizit
  "PHP/MySQL ohne Frameworks"), für ein einziges, seit Spec 001 stabiles
  Format unverhältnismäßiger Mehraufwand gegenüber ca. 20 Zeilen
  PHP-Prüflogik.
- Nur Pflichtfelder prüfen, Tile-Index-Wertebereich (`1 <= x <=
  tileCount`) auslassen — verworfen: genau diese Prüfung schützt die
  nachgelagerte PNG-/GIF-Rendering-Pipeline (Spec 005) vor
  Index-Out-of-Bounds-Zugriffen auf die Imagetable, ein zentrales Ziel
  dieser Härtungs-Spec.

---

## R5: Neuer HTTP-Fehlercode für "Limit erreicht" — 403 statt 429/400

**Befund**: Die bestehende Konvention in
`specs/005-backend-service/contracts/backend-api.md` nutzt `429 Too Many
Requests` bereits spezifisch für ZEITBASIERTES Rate-Limiting (Login-
Fehlversuche, "Zu viele Fehlversuche. Bitte in 5 Minuten erneut
versuchen"). Das Upload-Limit aus dieser Spec ist KEIN Zeit-, sondern ein
Mengen-/Kontingent-Limit (dauerhaft, nicht durch Warten auflösbar) — eine
Wiederverwendung von `429` würde beim Client (Playdate-Seite, Spec 004)
fälschlich "später nochmal versuchen" suggerieren, obwohl ein Retry ohne
Lösch-Aktion nie erfolgreich wäre.

**Decision**: Neuer, bisher unbenutzter Code `403 Forbidden` für den
Fall "Upload-Limit erreicht" — semantisch korrekt (Anfrage ist
authentifiziert/autorisiert, wird aber aus Policy-Gründen dauerhaft
abgelehnt) und klar von `429` (temporär) und `400`/`413` (Format-/
Größenfehler dieser EINEN Anfrage) unterscheidbar (FR-010, SC-005).

---

## R6: 403-Antwort erreichte den Nutzer NICHT als unterscheidbare Meldung — Lücke in `Source/SyncService.lua`

**Befund**: R5 begründet den neuen `403`-Code serverseitig, aber
FR-002/SC-005 verlangen mehr als eine korrekte HTTP-Antwort — der Nutzer
MUSS am Gerät eine erkennbar andere Meldung als bei anderen Fehlern sehen
("Meldung, die den Grund erkennbar unterscheidet"). Beim Nachverfolgen des
Antwortpfads bis zur UI (`Source/SyncService.lua`) zeigte sich: die
Statuscode-Zuordnung in `attemptUpload()` kannte VOR dieser Ergänzung nur
`201`/`401`/`413` explizit — jeder andere Code (also auch der neue `403`)
fiel in den `else`-Zweig (`reason = "upload_failed"`), und
`startUpload()`s Ergebnis-Callback zeigt für `"upload_failed"` den
generischen Text `"Upload failed"` — identisch zu einem echten
Server-/Format-Fehler. Ein rein serverseitiger Blick auf diese Spec hätte
diese Lücke NICHT gefunden, da das Backend-Verhalten (403 zurückgeben)
bereits korrekt ist — der Bruch liegt in der Playdate-seitigen
Interpretation dieses Codes.

**Ergänzung zu SC-005**: SC-005 fordert wörtlich vier unterscheidbare
Begründungen ("Limit vs. Größe vs. Format vs. Schema"). Diese vier sind
bereits auf API-Ebene (unterschiedliche HTTP-Status+Body-Kombinationen,
`curl`-verifizierbar in quickstart.md) vollständig unterscheidbar — dort
wird SC-005 auch tatsächlich verifiziert, da kein Geräte-UI-Test im
Projekt etabliert ist. Auf Geräte-UI-Ebene bekommen bewusst NUR Limit und
Größe einen eigenen Text (siehe Tabelle in
`contracts/upload-hardening.md`), da Format-/Schema-Fehler durch normale
App-Nutzung nicht auftreten können (App erzeugt PDI/JSON stets lokal
korrekt) und ausschließlich Requests außerhalb der App betreffen, die
den Playdate-Bildschirm ohnehin nie erreichen.

**Decision**: `Source/SyncService.lua` um einen expliziten `403`-Zweig
ergänzt: `attemptUpload()` gibt `{ ok = false, reason = "limit_reached" }`
zurück (analog zum bestehenden `413`-Zweig), `startUpload()`s Callback
zeigt dafür die eigene Meldung `"Upload limit reached (12 images)"`
(ASCII-only, gleiche Konvention wie alle anderen Sync-Statustexte, siehe
Kommentar-Block "Statusanzeige (FR-012)" in der Datei) statt in den
generischen `else`-Zweig zu fallen. Kein Retry für `403` (anders als
`401`) — ein erneuter Versuch ohne vorherige Löschung wäre nie
erfolgreich, entspricht dem bestehenden Muster für `413`
("`too_large`" wird ebenfalls nicht automatisch wiederholt). Bereits
umgesetzt und verifiziert: `lua tests/headless_tests.lua` (neuer Testfall
"Upload-Limit erreicht (403) zeigt eindeutige Meldung...") endet mit
"ALLE TESTS BESTANDEN", `pdc Source ...pdx` baut ohne Fehler
(Constitution V, beide Gates bestanden).

**Alternativen verworfen**:
- Den 403-Fall clientseitig unbehandelt lassen und als Follow-up-Spec
  dokumentieren (analog zur bewusst offen gelassenen Sybil-Problematik) —
  verworfen: anders als die Sybil-Frage (ein Restrisiko AUSSERHALB des
  ursprünglichen Nutzerauftrags) ist die erkennbare Nutzer-Meldung ein
  explizit vom Nutzer geforderter Kern-Bestandteil dieser Spec ("muss eine
  Meldung den weiteren Upload blockieren") — das Weglassen hätte SC-005
  end-zu-end unerfüllt gelassen, obwohl das Backend korrekt wäre.
- Eine neue, generische Fehler-Anzeige-Infrastruktur (z. B. serverseitige
  Fehlertexte direkt an den Client durchreichen und dort anzeigen) statt
  eines fest codierten Client-Texts — verworfen (Constitution IV): der
  bestehende `showStatus(text)`-Mechanismus mit fest codierten,
  ASCII-only-Texten pro `reason` ist das etablierte Muster für alle
  bisherigen Fehlerfälle dieser Datei; eine generische
  Text-Durchreichung wäre eine neue Abstraktion für einen einzelnen
  zusätzlichen Fall.

---

## Zusammenfassung: Geänderte/neue Bausteine

| Bedarf | Baustein | Status |
|---|---|---|
| Upload-Zähl-Check (FR-001/002/003/011) | `UploadHandler::handleUpload()` + `Database::beginTransaction/commit/rollback` (neu) | NEU |
| Dateigröße 300 KB (FR-006) | `Validation::$maxFileSize` | GEÄNDERT (Konstante) |
| PDI-Format (FR-004/005) | `PdiParser`/`Validation::validatePdiFile()` | BEREITS VOLLSTÄNDIG — nur verifiziert |
| JSON-Schema (FR-007/008/009) | `Validation::validateFramesJsonSchema()` (neu) | NEU |
| Fehlermeldungen (FR-010) | bestehendes `{"error": "..."}`-Muster + neuer 403-Code | GEÄNDERT (Codes/Texte) |
| Erkennbare Nutzer-Meldung (FR-002, SC-005) | `Source/SyncService.lua`: `attemptUpload()`/`startUpload()` neuer `limit_reached`-Zweig | NEU (research.md R6, bereits umgesetzt + getestet) |
