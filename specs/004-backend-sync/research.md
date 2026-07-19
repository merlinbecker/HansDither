# Phase 0 Research: Backend-Synchronisation (Playdate-Seite)

**Feature**: 004-backend-sync | **Date**: 2026-07-18

Alle Punkte wurden gegen das lokal installierte Playdate SDK (`~/Developer/PlaydateSDK`, **v3.0.6**) und den tatsächlichen Backend-Code (`backend/`, Spec 005) verifiziert — nicht nur gegen Dokumentation/Annahmen, gemäß Constitution Prinzip I (SDK-First) und der projektweiten SDK-Verifikationsregel.

---

## R1: System-Menü hat keinen freien Slot für "Sync" (kritischer Befund)

**Decision**: Sync wird NICHT über `playdate.getSystemMenu()` ausgelöst, sondern über eine Crank-Geste bei selektiertem Bild in der SelectionRoom (siehe R2).

**Rationale**: Playdate OS erlaubt maximal **drei** eigene System-Menü-Einträge (offiziell dokumentiert: "Playdate OS allows a maximum of three custom menu items to be added to the System Menu."). Codeprüfung zeigt, dass beide in Frage kommenden Räume diese bereits vollständig ausnutzen:
- `SelectionRoom.lua:121-142` (`buildSystemMenu`): "new image", "copy image", "delete image"
- `EditorRoom.lua:333-343` (`buildSystemMenu`): "save + exit", "delete frame", "show grid" (Checkmark)

Ein vierter Eintrag ist technisch unmöglich, ohne eine bestehende Funktion zu ersetzen. Das ursprüngliche Spec-Design (FR-002: "Sync-Eintrag im Kontextmenü") ging von einem in Wahrheit nicht mehr freien Primitiv aus.

**Alternatives considered**:
- "copy image" durch "sync" ersetzen → verworfen (Funktionsverlust, vom Nutzer nicht gewünscht)
- `addOptionsMenuItem` als zyklischer Aktions-Wähler (copy/delete/sync in einem Slot) → verworfen (Callback feuert erst beim Schließen des Menüs, ungewohnte UX für sofortige Aktionen)
- Crank-Geste (gewählt) → keine Funktion geht verloren, Crank ist in SelectionRoom aktuell vollständig ungenutzt (kein `cranked`-Handler, keine Crank-Queries in `SelectionRoom.lua`)

---

## R2: Crank als Sync-Auslöser — konkrete API

**Decision**: Kumulative Rotationsmessung über `playdate.getCrankChange()`, ausgewertet in `SelectionRoom:update()` nur wenn eine Zelle selektiert ist. ≥720° im Uhrzeigersinn (zwei volle Umdrehungen) löst Sync aus; ≥720° gegen den Uhrzeigersinn löst Reset der Verknüpfung aus. Richtungswechsel über eine kleine Toleranzschwelle hinaus setzt den Akkumulator zurück.

**Rationale**: `playdate.getCrankChange()` liefert die Winkeländerung (Grad) seit dem letzten Aufruf, negative Werte = Gegenuhrzeigersinn — passt direkt auf einen einfachen Akkumulator, der jeden Frame in `update()` aufsummiert wird (kein zusätzlicher Callback-Mechanismus nötig, konsistent mit dem bestehenden `update()`-Polling-Stil der Rooms).

Für den Hinweis-Text und das Icon:
- `playdate.ui.crankIndicator` (CoreLibs `ui/crankIndicator`, bereits über `CoreLibs/ui` importiert) — Standard-Crank-Hinweis-Icon, wie in vielen Playdate-Spielen.
- `playdate.isCrankDocked()` — liefert `true`, wenn die Kurbel eingeklappt ist; SDK-Doku empfiehlt explizit die Kombination mit dem Crank-Indicator/-Alert für genau diesen Fall.

**Alternatives considered**: `playdate.cranked(change, acceleratedChange)`-Callback statt Polling in `update()` → verworfen zugunsten von Konsistenz mit dem bestehenden `update()`-Stil der Rooms (kein anderer Room nutzt den `cranked`-Callback).

---

## R3: QR-Code-Generierung — korrigierter API-Name

**Decision**: `playdate.graphics.generateQRCodeSync(stringToEncode, desiredEdgeDimension)` (CoreLibs `qrcode`, `import "CoreLibs/qrcode"`).

**Rationale**: Der in der ursprünglichen Spec angenommene Name `playdate.graphics.qrCode` existiert nicht. Tatsächlich verfügbar (verifiziert in `CoreLibs/qrcode.lua` und `CoreLibs/__stub.lua`):
- `generateQRCodeSync(stringToEncode, desiredEdgeDimension)` — blockierend, gibt sofort ein `playdate.graphics.image` zurück.
- `generateQRCode(stringToEncode, desiredEdgeDimension, callback)` — asynchron über internen Timer, ruft `callback(image)` auf.

Da die QR-Erzeugung nur einmalig bei Auslösen der Sync-Geste passiert (kein Hot Path) und Coroutine-basierte Langläufer bereits das etablierte Muster für Wartezeiten sind (Constitution, `loadingBar.lua`), wurde ursprünglich die **synchrone** Variante (`generateQRCodeSync`) gewählt.

**Korrektur (Simulator-Validierung, 2026-07-18)**: `generateQRCodeSync` ist in der installierten SDK-Version 3.0.6 **defekt**. `CoreLibs/qrcode.lua` definiert `generateQRCodeSync` (Zeile 9) *vor* der lokalen Funktion `generateQRCodeImage` (Zeile 25) im selben File; der Aufruf `generateQRCodeImage(...)` in Zeile 21 löst sich dadurch (Lua-Scoping: ein `local function` ist erst ab seiner Deklarationszeile sichtbar) zur Laufzeit als globale Variable auf, die im ganzen File nie gesetzt wird → `global 'generateQRCodeImage' is not callable (a nil value)`. Dieser Fehler ist kein Mock-Fall (keine erfundene API — die Funktion existiert und ist dokumentiert), sondern ein echter Implementierungsfehler im ausgelieferten CoreLibs-Code, der nur durch tatsächliche Ausführung auf Simulator/Hardware auffällt (bestätigt den Grund für Constitution Prinzip V, Gate 2).

**Entscheidung (korrigiert)**: Es wird stattdessen die **asynchrone** Variante `generateQRCode(stringToEncode, desiredEdgeDimension, callback)` verwendet, die denselben Scoping-Fehler nicht hat (ihr interner Aufruf von `generateQRCodeImage` steht *nach* dessen Deklaration im File). Dafür ist eine laufende `playdate.timer`-Pumpe nötig — `playdate.timer.updateTimers()` wird jetzt in `main.lua:playdate.update()` aufgerufen (vorher war `CoreLibs/timer` importiert, aber ungenutzt). `SyncService:getQrImage(uid)` liefert `nil` zurück, solange die Generierung läuft, und cached das Ergebnis pro UID, sobald der Callback feuert; `drawPairingPrompt` zeigt in der Zwischenzeit einen Platzhaltertext.

**Payload**: `https://www.hans-dither.de/?uid={UID}` (Query-Parameter, siehe R5).

---

## R4: HTTP-Client — korrigierter API-Name und Coroutine-Zwang

**Decision**: `playdate.network.http` (CoreLibs, seit Playdate OS 2.7; installiertes SDK v3.0.6 unterstützt es). Alle Netzwerk-Aufrufe laufen innerhalb einer Coroutine, die von `playdate.update()` aus angestoßen wird — niemals aus einem Input-Handler (`AButtonDown` etc.) heraus.

**Rationale**: Der in der ursprünglichen Spec angenommene Name `playdate.net` existiert nicht; das korrekte Modul ist `playdate.network.http`. Zentrale API-Fakten (aus SDK-Doku verifiziert):
- `playdate.network.http.new(server, [port], [usessl], [reason])` — `usessl=true` ⇒ Port 443 (HTTPS) per Default.
- `new()` fordert bei Bedarf automatisch Netzwerkzugriff an (System-Dialog); dieser Vorgang nutzt intern `coroutine.yield()` und **darf nicht** beim Laden, in einem Input-Handler oder System-Callback aufgerufen werden — nur aus einem `playdate.update()`-Kontext.
- `connection:post(path, [headers], data)` ⇔ `connection:query(path, [headers], "POST", data)`; `data` ist ein roher String/Byte-Body — es gibt **keinen** eingebauten Multipart-Encoder.
- Requests sind asynchron über Callbacks (`setRequestCallback`, `setRequestCompleteCallback`, `setHeadersReadCallback`) oder Polling (`getBytesAvailable`, `read`).

Dieser Zwang zur Coroutine passt exakt auf das bereits etablierte Muster ("Coroutine-basierte Langläufer mit Fortschrittsanzeige", Constitution Prinzip IV / `RoomOperation.lua`, `loadingBar.lua`) — kein neues Nebenläufigkeitsmuster nötig.

**Multipart/form-data**: Muss manuell als String zusammengesetzt werden (Boundary + `Content-Disposition: form-data; name="..."` je Teil), da CoreLibs keinen Encoder mitliefert. Feldnamen `pdi` und `json` MÜSSEN exakt den Erwartungen von `backend/public/upload.php` (`$_FILES['pdi']`, `$_FILES['json']`) entsprechen — verifiziert im Backend-Quellcode.

**Alternatives considered**: `playdate.network.tcp` + manuelles HTTP-Framing → verworfen, unnötig, da `playdate.network.http` bereits Multipart-Bodies als Rohdaten akzeptiert.

**Ergänzung — kein Byte-Fortschritt für den Upload (FR-015)**: `getProgress()` liefert ausschließlich Fortschritt beim Lesen der Server-Antwort, nicht beim Senden des Request-Bodies. Der Upload-Fortschritt wird daher als Phasentext ("Verbinde…", "Sende…", "Warte auf Antwort…") über das bestehende `RoomOperation`/`loadingBar`-Muster (Phasennamen-Yield, wie bei `ImageStoreCodec`-Save/Load) angezeigt, nicht als Byte-Prozent-Balken.

---

## R5: Backend-Endpunkte — Contract-Doc vs. tatsächlicher Code (Diskrepanz gefunden)

**Decision**: SyncService nutzt ausschließlich die tatsächlich implementierten Endpunkte: `POST /login` (JSON-Response bei Nicht-Formular-Aufruf) gefolgt von `POST /upload` (Multipart, Felder `uid`+`token`+`pdi`+`json`). Kein separater Status-Endpunkt nötig — `/login` dient gleichzeitig als Verknüpfungsstatus-Check (FR-006a).

**Rationale**: Die Contract-Dokumentation aus Spec 005 (`specs/005-backend-service/contracts/backend-api.md`, E-04) beschreibt für `/upload` eine alternative Header-Authentifizierung `X-UID` + `X-PIN` neben dem Session-Token. **Diese Alternative existiert im tatsächlichen Code nicht** — `backend/public/upload.php` prüft ausschließlich `$_POST['token']` bzw. `X-Session-Token`-Header gegen `Auth::validateToken()`. Die Contract-Doku ist an dieser Stelle aspirational/veraltet; der Code ist die verbindliche Quelle.

Tatsächlicher, verifizierter Ablauf (`backend/public/index.php:285-326`, `backend/includes/auth.php:62-127`):
1. `POST /login` mit Formularfeldern `uid`+`pin` (kein `web=1`-Flag) → Response ist JSON (nicht HTML-Redirect):
   - `200`: `{"status":"success","session_token":"...","expires_at":"...","uid":"..."}`
   - `404`: `{"error":"UID nicht gefunden"}` → **noch nicht verknüpft** (Browser-Pairing steht noch aus)
   - `400`: `{"error":"UID oder PIN ungültig"}` → PIN abgelehnt (z. B. nach Reset im Backend)
   - `429`: `{"error":"Zu viele Fehlversuche..."}` → gesperrt
2. `POST /upload` mit Multipart-Body (`uid`, `token`, Datei-Felder `pdi` + `json`) → `201` mit `image_id`, oder `401`/`400`/`413`.

**Follow-up TODO** (nicht Teil von Spec 004, nur zur Nachverfolgung): Spec 005s `backend-api.md` sollte bei Gelegenheit korrigiert werden, um die X-UID/X-PIN-Alternative zu entfernen oder tatsächlich zu implementieren — außerhalb des Scopes dieses Features.

**Wichtige Ergänzung — Polling-Cadence darf die Rate-Limit-Sperre nicht selbst auslösen**: `Auth::login()` zählt jeden fehlgeschlagenen PIN-Versuch (`failed_attempts`, `backend/includes/auth.php:82-101`) und sperrt nach 3 Versuchen für 5 Minuten (`429`). Ein kontinuierliches Hintergrund-Polling des Verknüpfungsstatus (FR-006a) mit der eigenen PIN würde sich selbst aussperren können, sobald die im Browser eingetippte PIN (Tippfehler) nicht mit der auf dem Playdate generierten übereinstimmt — noch bevor der Nutzer das überhaupt bemerkt. **Entscheidung**: Der Statuscheck erfolgt daher ausschließlich bei einer expliziten Crank-Sync-Geste des Nutzers (menschliches Tempo), nie automatisch im Hintergrund. Das begrenzt die Versuchsfrequenz auf realistische menschliche Interaktion und vermeidet Selbstaussperrung durch Automatisierung.

---

## R6: Lokale Persistenz von UID/PIN/Pairing-Status

**Decision**: `playdate.datastore.write({uid=..., pin=..., paired=true}, "sync/state")` / `playdate.datastore.read("sync/state")`, konsistent mit dem bestehenden Muster in `ImageStore.lua` (`playdate.datastore.write(indexCache, "saves/index")`).

**Rationale**: Bereits etabliertes, verifiziertes Muster im Projekt; keine neue Persistenz-Technik nötig. Datei liegt getrennt von den Image-Daten (`saves/`) unter einem eigenen `sync/`-Präfix.

---

## R7: PIN-Generierung — Zufallsquelle

**Decision**: `math.random(0, 9999)`, formatiert als 4-stelliger String mit führenden Nullen; Seed via `math.randomseed(playdate.getSecondsSinceEpoch())` beim ersten Erzeugen, falls nicht bereits global geseedet.

**Rationale**: Im bestehenden Projekt-Code wird `math.randomseed` aktuell nirgends aufgerufen — ohne Seed liefert Lua eine deterministische Zufallsfolge (gleiche PIN bei jedem Programmstart wäre ein Sicherheitsproblem, wenn auch bei einer 4-stelligen PIN für den privaten Use Case zweitrangig). Ein einmaliger Seed beim Modul-Load von `SyncService.lua` schließt dieses Risiko ohne Zusatzaufwand.

---

## R9: Update-in-place bei Re-Sync — lokale Bild-ID als Schlüssel

**Decision**: Beim Upload wird zusätzlich zu `pdi`+`json` ein Multipart-Textfeld `image_id` mit der lokalen, stabilen Bild-ID gesendet. Das Backend erweitert `upload_handler.php`/`upload.php` additiv: Existiert bereits ein Eintrag für `(uid, client_image_id)`, werden die Dateien ersetzt und `png_path`/`gif_path` auf `NULL` zurückgesetzt (Neu-Rendering); sonst wird wie bisher ein neuer Eintrag mit neuer Server-UUID angelegt und `client_image_id` mitgespeichert. Erfordert eine schlanke Migration (neue nullable Spalte `client_image_id VARCHAR(64)` + `UNIQUE(uid, client_image_id)` in der `images`-Tabelle).

**Rationale**: Codeprüfung (`ImageStore.lua:87-99`, `sanitizeName`) zeigt: Lokale Bild-IDs sind bereits stabile, URL-sichere Slugs (`[a-z0-9-]+`, abgeleitet vom Bildnamen, lokal eindeutig durch Kollisionsprüfung `isIdTaken`), aber NICHT global eindeutig über mehrere Playdate-Geräte hinweg — daher Schlüssel `(uid, client_image_id)`, nicht `client_image_id` allein. Das erlaubte Zeichenset (keine Punkte/Slashes) ist bereits sicher für die Verwendung in serverseitigen Bezeichnern, ohne zusätzliche Sanitisierung nötig (Backend validiert dennoch defensiv mit demselben Muster). Diese Entscheidung ersetzt das ursprünglich angenommene "jeder Upload = neuer Eintrag"-Verhalten (verifiziert in `upload_handler.php:49` `generateUUID()`), da "Synchronisation" inhaltlich ein Aktualisieren impliziert, nicht ein Anhäufen von Duplikaten bei jeder erneuten Crank-Geste auf einem bereits hochgeladenen Bild.

**Alternatives considered**:
- Duplikat bei jedem Re-Sync (kein Backend-Change) → verworfen, entspricht nicht der Nutzererwartung an "Sync"
- Server generiert weiterhin zufällige IDs, Playdate merkt sich die zurückgegebene Server-ID nach erstem Upload lokal für spätere Updates → verworfen: erfordert zusätzliche lokale Zuordnungstabelle (lokale ID ↔ Server-ID) und schlägt fehl, wenn diese Zuordnung durch Geräte-Reset/Neuinstallation verloren geht; der client-seitige Schlüssel ist robuster, da er aus bereits vorhandenen, stabilen lokalen Daten (dem Bildnamen-Slug) abgeleitet wird

---

## R10: Keine Geräte-UID-API im SDK — UID wird lokal generiert (Implementierungsphase)

**Decision**: Die UID wird, wie die PIN, vom Playdate selbst zufällig generiert (16 Hex-Zeichen, Präfix `pd-`, z. B. `pd-a1b2c3d4e5f6a7b8`) und beim ersten Sync-Versuch dauerhaft in `sync/state` gecacht (`SyncService:getOrCreateUid()`).

**Rationale**: Vollständige Durchsicht aller `playdate.*`-Top-Level-Funktionen in `CoreLibs/__stub.lua` (Zeilen 8–98, u. a. `apiVersion`, `metadata`, `getSystemLanguage`, alle Crank-/Button-/Zeit-Funktionen) sowie gezielte Suche in der HTML-Dokumentation nach "serial"/"unique identifier"/"device id" ergab: **keine** Geräte-Seriennummer- oder Hardware-ID-API existiert für Lua-Spiele. `playdate.metadata()` liefert nur spielbezogene Metadaten (bundleID, version, buildNumber), keine Geräteinformation. Dies wurde erst während der Implementierung entdeckt (nicht bereits in der Planungsphase R1–R9 verifiziert) — ein Lücke in der ursprünglichen SDK-Verifikation, die die ursprüngliche Spec-Annahme "UID wird vom Playdate SDK bereitgestellt" (FR-001) übernommen hatte, ohne diese konkrete API zu prüfen.

**Alternatives considered**:
- `playdate.metadata()` / `bundleID` → verworfen: identifiziert das Spiel, nicht das Gerät; auf allen Geräten identisch.
- UID vom Nutzer manuell eingeben lassen → verworfen: widerspricht der gesamten UX-Prämisse (keine Tastatureingabe nötig), unnötige Komplexität.
- Zufällige UID lokal generieren und cachen (gewählt) → konsistent mit der bereits etablierten PIN-Generierung (research.md R7), keine zusätzliche Nutzerinteraktion, kein SDK-Feature-Bedarf.

**Kollisionsrisiko**: 16 Hex-Zeichen = 2^64 mögliche Werte; bei einer Handvoll privater Nutzer vernachlässigbar. Sollte dennoch eine Kollision auftreten, würde das Backend (Spec 005, `UNIQUE`-Constraint auf `uid`) die zweite `/pair`-Anfrage mit `409 Conflict` ablehnen (siehe `specs/005-backend-service/contracts/backend-api.md` E-02) — kein stiller Datenverlust, aber ein verwirrender Fehlerfall für den betroffenen Nutzer. Akzeptiertes Restrisiko für den privaten, nicht-kommerziellen Use Case (siehe spec.md Assumptions).

---

## R11: Auto-Polling während der QR+PIN-Prompt ist sicher (Implementierungsphase, Nutzer-Feedback) — **SUPERSEDED von R13**

**Historisch**: Solange `pairingPromptActive` war, rief `SyncService:tick()` automatisch alle 3s erneut `/login` auf, begrenzt auf ein 5-Minuten-Gesamtbudget. Die Sicherheitsanalyse dieses Abschnitts (404 erhöht `failed_attempts` nie, nur 400 tut das) bleibt technisch korrekt und wird von R13 weiterverwendet — aber der gesamte Polling-Mechanismus selbst (`pollCo`, `pollingActive`, `nextPollAtMs`, `pollDeadlineAtMs`, ein separater, auf eine Website-Bestätigung wartender QR+PIN-Prompt) wurde ersatzlos entfernt, siehe R13: Es gibt nach dem Redesign nichts mehr, worauf gewartet werden müsste — das Gerät pairt sich bei Bedarf selbst, ohne auf eine externe Bestätigung zu warten.

**Warum hier stehen gelassen statt gelöscht**: Historische Nachvollziehbarkeit — dieser Abschnitt dokumentiert eine Zwischenlösung, die auf Basis eines zweiten Simulator-Tests (Nutzer-Feedback) eingeführt und beim direkt folgenden Test (Screenshot-Feedback, dritter Simulator-Test) durch ein grundsätzlicheres Redesign ersetzt wurde. Die Rate-Limit-Analyse (404 vs. 400 vs. `failed_attempts`) bleibt die Grundlage für die Sicherheit von R13s automatischem Re-Pair-Versuch.

---

## R12: Vertipp-Dead-End beim Pairing — Website-Copy-Fix + Backend-Re-Pairing für unbestätigte UIDs (Implementierungsphase, Advisor-Review)

**Befund**: Der eigentliche Grund für "PIN eingegeben, aber keine Verknüpfung erfolgt" lag nicht im Playdate-Code, sondern im Backend-Formular `backend/public/index.php::showPairForm()` (Spec 005): Der Text forderte nur "Gib eine 4-stellige PIN ein", ohne zu spezifizieren, dass es die AUF DEM GERÄT ANGEZEIGTE PIN sein muss. Ein Nutzer, der dem Formular wörtlich folgt, erfindet eine eigene PIN — `Auth::pair()` legt damit einen Nutzer-Datensatz an, dessen `pin_hash` nie zur Geräte-PIN passen kann; jeder nachfolgende `/login`-Versuch vom Gerät bekommt dauerhaft `400`. Dieselbe Fehlerklasse wie die bereits gefundenen Diskrepanzen (X-UID/X-PIN-Header, Geräte-UID-API) — Dokumentation/Implementierung eines abhängigen Systems (Spec 005) hinkte einer Design-Änderung in Spec 004 hinterher.

**Decision (zwei Teile, beide additiv/rückwärtskompatibel)**:
1. **Sofortiger Fix**: Formulartext in `showPairForm()` korrigiert ("Gib die auf deinem Playdate angezeigte PIN ein…").
2. **Strukturelle Absicherung**: Auch nach Fix 1 bleibt ein Tippfehler möglich. Neue Spalte `users.confirmed_at` (Migration `002_sync_extensions.sql`), gesetzt beim ersten erfolgreichen `Auth::login()`. `Auth::pair()` überschreibt den `pin_hash` einer bestehenden UID, solange `confirmed_at IS NULL` (unbestätigt); ist die UID bereits bestätigt, bleibt der bisherige Schutz (`409 Conflict`) bestehen. `index.php`-Routing (`showUidForm`, `showPairForm`) nutzt `Auth::isConfirmed()` statt `Auth::uidExists()`, damit ein erneuter Aufruf derselben QR-URL bei unbestätigter UID wieder zum Pairing-Formular statt zum (dann sinnlosen) Login-Formular führt.

**Rationale**: Fix 1 allein reduziert das Risiko drastisch, beseitigt es aber nicht vollständig (Tippfehler bleiben möglich). Ohne Fix 2 wäre ein einmaliger Tippfehler ein permanenter Dead-End (kein Reset-Mechanismus in diesem Release, FR-013 YAGNI) — inakzeptabel für ein Feature, dessen einziger Zweck die zuverlässige Erstverknüpfung ist. Der Schutz bleibt dabei erhalten: eine bereits bestätigte (aktiv genutzte) UID kann nicht von einem Dritten übernommen werden, nur unbestätigte.

**Sicherheitsrelevanz**: Ändert Auth-Semantik einer als "Complete" markierten Spec (005) — Security-Review-Nachtrag erforderlich (siehe tasks.md T027, weiterhin offen).

**Alternatives considered**:
- Nur Fix 1, Risiko dokumentiert akzeptieren → abgelehnt (Nutzerentscheidung): zu hohes Risiko für einen permanenten, nur per manuellem DB-Zugriff behebbaren Dead-End.
- Vollständiger Reset-/Unpair-Mechanismus (FR-013 wieder aufnehmen) → abgelehnt: größerer Scope als nötig, YAGNI-Entscheidung aus einer früheren Runde bleibt bestehen; das `confirmed_at`-Re-Pairing löst exakt das hier akute Problem, ohne einen allgemeinen Reset-Flow zu bauen.

**Nachtrag (R13)**: Der hier beschriebene Backend-Mechanismus (`confirmed_at`, überschreibbarer `pin_hash` für unbestätigte UIDs) ist unverändert gültig und wird durch das Redesign in R13 sogar zentraler: Statt dass ein MENSCH nach einem Tippfehler die Website erneut besucht, ruft ab R13 das GERÄT selbst automatisch erneut `/pair` auf, sobald `/login` mit `not_paired` oder `unauthorized` fehlschlägt — derselbe Backend-Schutzmechanismus, jetzt vom autonomen Self-Heal-Pfad genutzt statt von einer manuellen Website-Aktion.

---

## R8: Offline-Queue

**Decision**: Da Upload jetzt pro Einzelbild erfolgt (nicht mehr Sammel-Upload), reduziert sich die Offline-Queue auf einen einzelnen "pending upload"-Zustand pro Bild (kein Mehr-Bild-Queue-Management nötig). Bei Verbindungsabbruch während eines Uploads wird der Zustand `pending` in `sync/state` unter der jeweiligen Image-ID vermerkt und beim nächsten erfolgreichen Netzwerkzugriff (nächste Crank-Geste auf demselben Bild, oder ein expliziter Retry) erneut versucht.

**Rationale**: Vereinfachung gegenüber dem ursprünglichen Mehrbild-Batch-Queue-Design, direkte Folge der R1/US2-Entscheidung (Einzelbild-Sync statt Sammel-Upload). Passt zu Constitution Prinzip IV (Einfachheit vor Ausbau).

---

## R13: Autonomes Pairing statt Website-Bestätigungs-Gate (Implementierungsphase, drittes Nutzer-Feedback nach Screenshot)

**Befund**: Der bis hierhin gebaute Ablauf (Crank → QR+PIN anzeigen → warten, bis der Nutzer die PIN auf der Website eingibt → Auto-Polling erkennt das → erst DANACH Upload) hat trotz aller Einzelkorrekturen (R11, R12) beim dritten realen Test wieder "sieht das Gerät scheinbar nicht" gemeldet, und der Nutzer stellte die zugrunde liegende Prämisse selbst infrage: Wozu muss das Gerät überhaupt auf eine Website-Bestätigung warten, bevor es hochladen darf? uid UND pin werden BEIDE ausschließlich vom Gerät generiert — kein Wert stammt vom Menschen. Der QR-Code + PIN auf dem Display SIND bereits der vollständige Nachweis "physischer Zugriff auf dieses Gerät"; ein späteres Website-Login mit denselben zwei Werten beweist exakt denselben Fakt kein zweites Mal wirksamer, nur später. Das Bestätigungs-Gate lieferte objektiv keine zusätzliche Sicherheit, aber die gesamte Komplexität von R11 (Polling-Intervall, Timeout, Race-Guard) und einen Großteil des Fehlerbilds aus R12.

**Decision**: `POST /pair` wird direkt vom Gerät aufgerufen — derselbe Endpunkt, den bisher nur das Web-Formular ansprach (`backend/public/index.php::handlePairRequest()` liefert bereits JSON statt eines Redirects, sobald kein `web=1`-Formularfeld gesetzt ist; keine Backend-Änderung nötig). `SyncService:startSync(imageId)` löst pro Crank-Geste genau EINE Kette aus, ohne auf externe Bestätigung zu warten:

1. `POST /login` mit der lokal gecachten `uid`+`pin`.
2. Schlägt das mit `not_paired` (404, UID unbekannt) ODER `unauthorized` (400, UID bekannt aber `pin_hash` passt nicht — z. B. eine Altlast aus der alten, jetzt abgeschafften Web-Pairing-Ära) fehl: automatisch `POST /pair` mit derselben `uid`+`pin`, danach genau ein `/login`-Retry. `Auth::pair()` überschreibt `pin_hash` nur, solange `confirmed_at IS NULL` (R12) — der Self-Heal ist also sicher und betrifft nie eine fremde, bereits bestätigte UID (`409` → `uid_taken`, bei 2^64 zufälligen UIDs praktisch unerreichbar).
3. Schlägt `/login` mit `locked` (429) fehl: KEIN automatischer `/pair`-Versuch (würde die laufende Sperre nicht aufheben, siehe R12-Nachtrag) — sofort eine klare Fehlermeldung.
4. Bei Erfolg: Multipart-Upload des Bildes, danach Vollbild-QR+PIN-Ergebnisscreen.

Die Website-PIN-Eingabe (`/pair`- bzw. `/login`-Formular aus Spec 005) bleibt bestehen, ist aber ab jetzt kein Upload-Gate mehr, sondern ausschließlich der Weg, die bereits hochgeladenen Bilder in der Backend-Galerie anzusehen — genau das vom Nutzer vorgeschlagene Modell ("kann direkt das Bild hochladen ... danach kann man sich mit dem PIN auf der Website anmelden und sieht das hochgeladene Bild").

**Entfernt** (ersatzlos, siehe R11-Superseded-Hinweis): der separate, auf Website-Bestätigung wartende QR+PIN-Prompt (`pairingPromptActive`), das gesamte Auto-Polling-Subsystem (`pollCo`, `pollingActive`, `nextPollAtMs`, `pollDeadlineAtMs`, `POLL_INTERVAL_MS`, `POLL_TIMEOUT_MS`), der persistente In-Prompt-Statustext (`pairingSubStatus`) und der `syncGeneration`-Race-Guard (ohne mehrsekündiges Polling gibt es kein spät eintreffendes, verwaistes Ergebnis mehr, das ein bereits geschlossenes Overlay wieder aufreißen könnte). `resultQrActive`/`pairingPromptActive` werden zu einem einzigen `resultModalActive` zusammengeführt, das erst NACH erfolgreichem Upload gesetzt wird (FR-007a).

**Rationale**: Weniger Zustand, weniger Fehlerfälle, kein Warten — und die einzige verbliebene Wartezeit (Netzwerk-Roundtrip von Login/Pair/Upload) ist ohnehin kurz und über die bestehende `loadingBar` sichtbar. Das Sicherheitsmodell ändert sich dabei NICHT: Beide Werte (uid, pin) waren schon vorher ausschließlich geräteseitig erzeugt: ob das Gerät sie selbst an `/pair` schickt oder ein Mensch sie von Hand abtippt, ist derselbe Vertrauensanker (physischer Zugriff aufs Display), nur mit einem Schritt weniger.

**Alternatives considered**:
- Bestätigungs-Gate beibehalten, nur Polling robuster machen (kürzeres Intervall, bessere Statusanzeige) → verworfen: löst nicht das strukturelle Problem, dass das Gate keine echte zusätzliche Sicherheit bietet, sondern nur zusätzliche Fehlerfälle (Timeout, Race, PIN-Tippfehler-Dead-Ends) erzeugt.
- `/pair` weiterhin nur über das Web-Formular, Gerät ruft stattdessen einen neuen, dedizierten "auto-pair"-Endpunkt auf → verworfen: unnötiger Backend-Scope, `/pair` liefert für Nicht-Formular-POSTs bereits das benötigte JSON-Verhalten (verifiziert in `backend/public/index.php:187-211`).

---

## R14: ASCII-only Sync-UI-Texte (Font-Glyphenlücke, Nutzer-Screenshot)

**Befund**: Ein vom Nutzer bereitgestellter Screenshot des laufenden Pairing-Prompts zeigte "�" (Ersatzzeichen) anstelle von deutschen Umlauten (ü) UND des Halbgeviertstrichs (—) in mehreren `SyncService.lua`-Statustexten (z. B. "verkn�pft", "nicht �berein"). Der Playdate-System-Font (über `gfx.drawText`/`drawTextAligned` genutzt, keine explizite Font-Ladung im Projekt) deckt diese Zeichen nicht ab — nur auf echtem Gerät/Simulator sichtbar, von den Text-Mocks der Headless-Testsuite naturgemäß nicht erkennbar (reine String-Vergleiche, kein Font-Rendering).

**Decision**: Alle Sync-bezogenen UI-Strings in `Source/SyncService.lua` (Statuszeile, Ergebnis-Overlay, `loadingBar`-Detailtexte) sind jetzt Englisch und ASCII-only — konsistent mit dem Rest der App-UI (SelectionRoom/EditorRoom-Texte sind bereits durchgehend Englisch: "new image", "copy image", "(A) delete" etc.), statt einzelne Umlaute/Sonderzeichen zu transliterieren (ü→ue, —→-). Betroffen waren u. a. `getStatusText()`, alle `showStatus(...)`-Aufrufe und die Overlay-Texte in `drawResultModal()`.

**Rationale**: Sprachkonsistenz mit der bestehenden UI ist die naheliegendere Lösung als eine gemischt deutsch/transliterierte Statuszeile, UND behebt gleichzeitig das Font-Problem (ASCII ist immer im System-Font enthalten). Eine benutzerdefinierte Font-Datei nur für Umlaute wäre für ein paar Statuszeilen unverhältnismäßiger Aufwand (Constitution Prinzip IV, Einfachheit vor Ausbau).

**Alternatives considered**:
- Zeichen transliterieren (ü→ue, ö→oe, ä→ae, ß→ss, —→-, …→...), Rest bleibt Deutsch → verworfen: uneinheitlich mit dem Rest der App-UI und liest sich holprig ("Verkn**ue**pft").
- Custom Font mit vollständigem Unicode-Glyphensatz laden → verworfen: Aufwand steht in keinem Verhältnis zu ein paar Statuszeilen, kein anderer Teil der App nutzt bisher eine Custom-Font.

---

## R15: QR-Code-Vorabgenerierung parallel zum Netzwerk-Roundtrip (Nutzer-Feedback: "wieso dauert die QR-Generierung so lange?")

**Befund**: Die asynchrone QR-Erzeugung (`generateQRCode`, siehe R3) verteilt die eigentliche Kodierung bewusst über mehrere `playdate.update()`-Frames statt sie in einem Frame zu blockieren — das ist SDK-Design, keine App-seitige Ineffizienz, und lässt sich ohne Rückgriff auf die defekte `generateQRCodeSync`-Variante (R3) nicht "schneller" machen. Vorher wurde `SyncService:getQrImage(uid)` aber erst beim ERSTEN Zeichnen des Ergebnis-Overlays aufgerufen — also erst NACH dem kompletten Login/Pair/Upload-Netzwerk-Roundtrip —, wodurch sich die (kurze, aber spürbare) QR-Generierungszeit als zusätzliche, sichtbare Wartezeit an die Netzwerk-Wartezeit anschloss, statt mit ihr zu überlappen.

**Decision**: `SyncService:startSync(imageId)` ruft `SyncService:getQrImage(uid)` bereits zu Beginn auf (die `uid` ist rein lokal bekannt, kein Netzwerk-Roundtrip nötig) und verwirft den Rückgabewert — der eigentliche Zweck ist, die asynchrone Generierung anzustoßen, BEVOR die `loadingBar`-Operation (Login/Pair/Upload) beginnt. Bis das Ergebnis-Overlay nach erfolgreichem Upload gezeichnet wird, ist der QR-Code in aller Regel bereits fertig (Cache-Hit über `qrForUid`).

**Rationale**: Kostenlose Parallelisierung zweier voneinander unabhängiger asynchroner Vorgänge (Zeitmultiplexing über `playdate.update()`-Frames für die QR-Erzeugung, Coroutine-Yields für HTTP) — kein zusätzlicher State, kein Risiko, reduziert nur die wahrgenommene Wartezeit.

---

## R16: Log-Instrumentierung + Simulator-Dev-Testtrigger (Nutzer-Feedback: "Log-Meldungen für den Ablauf" + "Tests zum Abfeuern im Simulator")

**Befund**: Der komplette Pairing/Login/Upload-Ablauf lief bisher nur sichtbar über die `loadingBar`-Phasentexte und die finalen `showStatus()`-Meldungen — für Entwicklung/Debugging im Simulator gab es keine granulare Nachvollziehbarkeit (welcher Schritt lief wann, wie lange dauerte welcher HTTP-Call, warum wurde auto-gepairt) und keinen Weg, einzelne Schritte (nur Login, nur Pair) isoliert gegen das echte Backend zu testen, ohne jedes Mal eine Crank-Geste + ein echtes Bild zu benötigen.

**Decision**:
1. Alle Kernfunktionen in `SyncService.lua` (`httpPostAndWait`, `pair`, `login`, `ensurePairedAndLoggedIn`, `attemptUpload`, `uploadWithRetry`, `getQrImage`, `startSync`, die Kettenabschluss-Callback in `startUpload`, `tick`) loggen jetzt über ein einheitliches `logSync(...)`-Präfix (`"[Sync] ..."`), inkl. Laufzeitmessung (`playdate.getCurrentTimeMilliseconds()`-Differenzen) für jeden HTTP-Request, die QR-Generierung und die Gesamtkette — beantwortet direkt "wie lange dauert welcher Schritt tatsächlich" statt nur gefühlt.
2. Fünf Dev-Testtrigger (`SyncService:devTestLogin/-Pair/-FullRoundtrip/-DumpState/-ResetPairing`) sind über `playdate.keyPressed` (Tasten `0`–`4`) erreichbar. `playdate.keyPressed` wird laut SDK ausschließlich im Simulator aufgerufen, nie auf echtem Gerät — kein zusätzliches Gate nötig, der Block ist auf dem Gerät automatisch inert. Reine Login-/Pair-Tests laufen isoliert über dieselben internen `login()`/`pair()`-Funktionen wie die Hauptkette (kein Duplikat-Code); der volle Roundtrip-Test ruft `SyncService:startSync()` mit dem ersten gespeicherten Bild auf. Ein gemeinsames `runOperation(...)`-Gerüst ersetzt den vorher in `startUpload` inline liegenden `RoomOperation`-Boilerplate, damit die Dev-Trigger dieselbe loadingBar-UX nutzen wie der Produktionspfad, statt eigene Overlay-Logik zu duplizieren.
3. Voraussetzung für Fortschritt der Dev-Trigger ist wie beim Crank-Pfad, dass `SelectionRoom` aktiv ist (nur deren `update()` treibt `SyncService:tick()` an) — dokumentiert im Code-Kommentar statt zusätzlicher Infrastruktur, da das exakt dem bereits bestehenden Verhalten des Produktionspfads entspricht.

**Rationale**: Beide Wünsche (Logging, modulare Testtrigger) betreffen reines Entwicklungswerkzeug ohne Auswirkung auf FR/Contracts — daher keine Änderung an spec.md/contracts/data-model.md, nur dieser Research-Eintrag zur Nachvollziehbarkeit. `playdate.keyPressed` statt eines vierten System-Menü-Eintrags (R1: nur 3 Slots, bereits ausgeschöpft) vermeidet jede Kollision mit der Produktions-UI.

---

## R17: `status == 0` wurde als HTTP-Status missinterpretiert (echter Simulator-Log deckte den Fehler auf)

**Befund**: Ein realer Simulator-Testlauf mit dem neuen Logging aus R16 zeigte `POST /login -> 0 (3267ms, 0 bytes)` gefolgt von `login: unauthorized (status=0)` und einem daraufhin ausgelösten (ebenfalls scheiternden) Auto-Pair-Versuch. `0` ist kein gültiger HTTP-Statuscode (kleinster realer Wert ist 100) — er bedeutet, dass `connection:getResponseStatus()` nie eine echte Server-Antwort gesehen hat (Verbindungsfehler: DNS/TLS/Timeout/Offline). `httpPostAndWait` prüfte bisher nur `status == nil` als Fehlerfall, nicht `status == 0`, wodurch dieser Verbindungsfehler bis in `login()`/`pair()` als regulärer (aber unbekannter) HTTP-Status durchgereicht wurde und dort im generischen else-Zweig als `"unauthorized"`/`"invalid"` fehlinterpretiert wurde — inhaltlich eine PIN-Ablehnung vortäuschend, wo tatsächlich gar keine Antwort ankam. Das erklärt den beobachteten fälschlichen Auto-Pair-Versuch (nur für `not_paired`/`unauthorized` vorgesehen, siehe R13) bei einer reinen Netzwerkstörung.

**Verifikation Backend selbst gesund**: `curl` direkt gegen `https://www.hans-dither.de/login` (unbekannte UID) und `/pair` (neue UID), sowohl über HTTP/2 als auch erzwungenes HTTP/1.1, liefert in allen vier Kombinationen die korrekten Antworten (404 bzw. 201, gültige TLS-Kette). **Kein Redeploy nötig** — die Störung lag ausschließlich auf der Verbindung zwischen Simulator und Backend zum Testzeitpunkt (Ursache nicht abschließend geklärt: Internetverbindung des Testrechners, VPN/Firewall, oder ein transienter Aussetzer; das gefixte Logging zeigt beim nächsten Lauf `connection:getError()` im Klartext).

**Decision**: `httpPostAndWait` behandelt `status == nil` UND `status == 0` einheitlich als Verbindungsfehler (`reason = "network"`) und gibt `connection:getError()` im Log aus. Dadurch bleibt `ensurePairedAndLoggedIn()`s Auto-Pair-Eligibility-Prüfung (nur `not_paired`/`unauthorized`) korrekt — ein reiner Netzwerkfehler löst jetzt korrekt keinen Pairing-Versuch mehr aus.

---

## R18: Netzwerk-Berechtigungsdialog nachrecherchiert — verifiziert bereits erteilt, kein Code-Bug; `setConnectTimeout` ergänzt

**Nutzer-Rückfrage**: Nach dem R17-Fix weiterhin `NO RESPONSE` nach ~3.2s, Nutzer vermutete, HTTP-Requests bräuchten laut SDK zwingend zuerst ein explizit eingeholtes Nutzer-Einverständnis (`requestAccess`), das im Code fehle.

**Befund** (verifiziert gegen `Inside Playdate.html` §HTTP und das offizielle Lua-Beispiel `PlaydateSDK-3.0.6/Examples/Networking/Playdate/Source/main.lua`):
- `playdate.network.http.new(server, port, usessl, reason)` fragt laut Doku-Text automatisch selbst nach Berechtigung, falls nötig ("will automatically request access if needed"), über einen internen `coroutine.yield()` — das offizielle Beispiel ruft `requestAccess()` explizit **nirgends** auf, nur `new()` + `assert(conn, "The user needs to allow this")`. Unser Code folgt exakt diesem offiziellen Muster; `requestAccess()` ist laut Doku nur für das optionale VORAB-Einholen der Erlaubnis gedacht ("if you want to present the access dialog ahead of time"), keine Voraussetzung.
- Direkt auf der Festplatte verifiziert: Die Simulator-Instanz, auf die `pdc`/`open` tatsächlich zeigen (`~/Developer/PlaydateSDK`, `which pdc` → `.../PlaydateSDK/bin/pdc`), hatte in `Disk/Data/de.merlinbecker.hansdither/Permissions` bereits den Inhalt `net+` — Netzwerk-Zugriff war für dieses Spiel bereits erteilt, **bevor** der fehlgeschlagene Testlauf aus dem R17-Log stattfand. Das Einverständnis-Gate war zum Fehlerzeitpunkt also bereits erfüllt, nicht die Ursache von `NO RESPONSE`.
- Abweichung vom offiziellen Beispiel gefunden: Dieses ruft explizit `http_conn:setConnectTimeout(2)` auf; unser Code setzte bisher keinen Timeout und verließ sich auf einen undokumentierten SDK-Default. Das erklärt plausibel die auffällig konstante ~3.2s-Dauer der Fehlschläge (ein fester interner Default-Timeout statt zufälliger Netzwerk-Flakiness) — behebt aber nicht die eigentliche Verbindungsstörung, macht das Verhalten nur deterministisch/dokumentiert.

**Decision**: Kein `requestAccess()` ergänzt (Beleg: nicht nötig, Permission bereits erteilt, offizielles Beispiel nutzt es auch nicht — Constitution Prinzip IV, keine ungerechtfertigte Komplexität). Stattdessen: `connection:setConnectTimeout(8)` in `httpPostAndWait` ergänzt (Zeilen bei R17-Fix), analog zum offiziellen Beispiel. Zusätzlich wurden `sync/state.json` UND `Permissions` in BEIDEN lokalen Simulator-Datenverzeichnissen (`PlaydateSDK` und `PlaydateSDK-3.0.6`) auf Nutzerwunsch zurückgesetzt (Crank-Hinweis erscheint wieder, uid/pin/paired neu, UND der Berechtigungsdialog wird beim nächsten Sync-Versuch nachweislich erneut gezeigt) — das liefert einen sauberen, beobachtbaren Test: erscheint der Dialog, wird er bestätigt, und schlägt der Request danach TROTZDEM fehl, ist das der endgültige Beweis, dass die Störung nicht am Einverständnis liegt, sondern an der eigentlichen Netzwerkverbindung des Simulator-Prozesses (Firewall/EDR/Netzwerkpfad — außerhalb der Reichweite des App-Codes).

---

## R19: `NO RESPONSE` bleibt auch nach frischem Reset+`setConnectTimeout` bestehen — Simulator bringt eigenes libcurl/OpenSSL mit, Ursache bleibt außerhalb des App-Codes; Diagnose-Sonde ergänzt

**Nutzer-Rückmeldung nach R18-Reset**: Frischer uid/pin (Reset griff), aber `POST /login` weiterhin `NO RESPONSE after 3409ms (connection error: unknown)` — obwohl dieselbe Domain im Browser sofort erreichbar ist.

**Root-Cause-Untersuchung (systematisch, mehrere Hypothesen geprüft und verworfen)**:
- **DNS/IPv6 ausgeschlossen**: `dig` zeigt für `www.hans-dither.de`/`hans-dither.de` ausschließlich einen A-Record (`85.13.149.237`), keinen AAAA-Record — ein IPv6-zuerst-Hänger kann also gar nicht auftreten, dieser Rechner hat davon unabhängig ohnehin funktionierendes IPv6 (verifiziert gegen google.com).
- **SNI/Virtual-Hosting geprüft**: Der Server ist strikt SNI-basiert (Shared Hosting bei kasserver.com) — ohne SNI liefert er ein KOMPLETT ANDERES Zertifikat (`*.kasserver.com` statt `hans-dither.de`). Mit korrektem SNI (wie es jeder normale HTTPS-Client inkl. curl automatisch sendet) liefert er die korrekte, gültige `hans-dither.de`-Kette (Let's-Encrypt-Chain, Root `ISRG Root X1`/`ISRG Root X2`).
- **Rohe TCP-Erreichbarkeit ausgeschlossen**: Ein roher Python-Socket-Connect (unsigniert, kein curl) zur Server-IP:443 verbindet in 0,05s — die Route/Firewall auf diesem Rechner blockt also nicht pauschal jeden Prozess.
- **Wichtigster neuer Befund**: `otool`/`strings` auf das Simulator-Binary zeigen, dass der Playdate Simulator sein EIGENES, statisch gelinktes `libcurl 8.20.0` mit `OpenSSL`-TLS-Backend mitbringt — NICHT Apples System-`Security.framework`/`SecTrust` (trotz verlinktem `Security.framework` für andere Zwecke) und keine im App-Bundle mitgelieferte `cacert.pem`. Das ist eine vom Shell-`curl` UND vom rohen Python-Socket-Test komplett unabhängige Netzwerk-Implementierung — ein Prozess- oder TLS-Stack-spezifischer Unterschied ist damit die einzig verbleibende, durch Evidenz gestützte Erklärungskategorie (z. B. prozessspezifische Filterung durch eine Endpoint-Security-Lösung wie das auf diesem Rechner aktive `com.jamf.protect.security-extension`, ODER ein Unterschied im von diesem eigenen `libcurl`/OpenSSL genutzten CA-Trust-Store gegenüber dem System-Trust-Store). Beide Erklärungen bleiben an dieser Stelle **Hypothese, nicht Beweis** — der `setConnectTimeout(8)`-Wert aus R18 wurde nicht erreicht (Fehlschlag bei ~3,4s statt ~8s), was zusätzlich zeigt, dass die Störung VOR oder UNABHÄNGIG von unserem eigenen Timeout-Wert eintritt.
- **Nebenbefund (nicht ursächlich, aber real und separat erwähnenswert)**: Auf diesem Entwicklerrechner ist `/opt/homebrew/etc/openssl@3/cert.pem` nur 42 Bytes groß (praktisch leer, kein vollständiges CA-Bundle) — falls IRGENDEIN Tool auf diesem Rechner (nicht zwingend der Simulator) sich auf diesen Pfad statt auf das funktionierende `/etc/ssl/cert.pem` (333 KB) verlässt, würde JEDE TLS-Verbindung fehlschlagen. Das passt aber zeitlich nicht exakt zum beobachteten Verhalten (eine leere Trust-Anchor-Liste scheitert typischerweise sofort beim Zertifikats-Check, nicht erst nach ~3,4s) — daher hier nur dokumentiert, nicht als Ursache behauptet.

**Decision**: Statt einer weiteren ungeprüften Fix-Vermutung (Iron Law: kein Fix ohne Root-Cause-Beweis) wurde `httpPostAndWait` zu `httpAndWait(host, path, headers, body, phaseLabel, method)` verallgemeinert (Host/Methode jetzt Parameter statt fest verdrahtet) und ein sechster Dev-Testtrigger ergänzt: **Taste `5` — `SyncService:devTestNetworkProbe()`** führt exakt denselben Verbindungscode gegen `example.com` (bekannt erreichbar, andere CA-Kette, anderer Betreiber) statt gegen `BACKEND_HOST` aus. Das Ergebnis dieser EINEN Taste entscheidet zwischen den beiden verbleibenden Hypothesen, ohne weitere Spekulation:
  - Schlägt die Sonde GENAUSO fehl (`NO RESPONSE`) → der Simulator-Prozess erreicht GAR KEIN HTTPS, unabhängig vom Ziel-Host → Problem liegt am Netzwerkpfad/der Prozessfilterung des Simulators selbst, nicht am Backend (kein Redeploy, keine Code-Änderung an SyncService möglich, die das beheben würde).
  - Kommt die Sonde durch (Status 2xx) → das Problem ist spezifisch für `www.hans-dither.de`/`85.13.149.237` (z. B. CA-Kette/TLS-Konfiguration) → weitere Untersuchung dort nötig (z. B. Server-seitige TLS-Konfiguration, alternative CA-Zwischenzertifikate ausliefern).

**Rationale**: Die Sonde ist reines Diagnosewerkzeug (wie R16), keine Produktionsänderung — sie liefert den einzigen noch fehlenden Datenpunkt, um zwischen "Simulator-weites Netzwerkproblem" und "backend-spezifisches Problem" zu unterscheiden, ohne dass ich (ohne GUI-Zugriff auf den Simulator) weiter raten müsste.

---

## R20: Live-Socket-Aufzeichnung zeigt Verbindung auf Port 80 statt 443 trotz `usessl=true` — Port jetzt explizit statt `nil`

**Befund**: Die `devTestNetworkProbe` (R19) kam gegen `example.com` erfolgreich durch (Status 200) — das widerlegt "Simulator erreicht generell kein HTTPS" endgültig. Auffällig blieb aber: die erfolgreiche Sonde brauchte **3202ms**, fast identisch zur Dauer der gescheiterten Backend-Anfragen (~3,4s) — kein Zufall, sondern ein gemeinsamer Faktor. DNS wurde daraufhin direkt ausgeschlossen: `scutil --dns` zeigt keine PAC/Proxy-Konfiguration, und `socket.getaddrinfo()` (dieselbe API, die auch C-Programme nutzen) löst beide Hosts in unter 50ms auf, mit und ohne IPv6.

Eine Live-Aufzeichnung der offenen Sockets des Simulator-Prozesses (`lsof -i -p <pid>`, alle 0,25–0,3s während eines echten Tastendruck-Tests) lieferte den entscheidenden Fund: der Simulator-Prozess (PID der laufenden `Playdate Simulator.app`) baute mindestens einmal eine `ESTABLISHED`-Verbindung zu `85.13.149.237:80` auf (Klartext-HTTP-Port) — obwohl unser Code durchgehend `usessl=true` setzt. Andere Verbindungen im selben Aufzeichnungsfenster gingen korrekt auf Port 443. Der offizielle SDK-Beispielcode (`Examples/Networking/Playdate/Source/main.lua`) übergibt in JEDEM gezeigten `http.new(...)`-Aufruf einen expliziten Port (`net.http.new("localhost", 65433, false, ...)`) — nie `nil` kombiniert mit `usessl=true`. Unser Code tat bisher genau das (`playdate.network.http.new(host, nil, true, ...)`) und verließ sich damit auf einen vom offiziellen Beispiel nirgends demonstrierten, undokumentierten Port-Default.

**Hypothese (nicht 100% isoliert bewiesen, aber die einzige verbleibende mit direkter Sockel-Evidenz)**: Wird der Port intern aus `nil` + `usessl` fehlerhaft berechnet (Default fällt gelegentlich auf 80 statt 443 zurück), verbindet der Client auf Port 80 und versucht dort trotzdem einen TLS-Handshake (ClientHello) — ein Klartext-Webserver auf Port 80 kann damit nichts anfangen, hängt oder bricht ohne sauberen HTTP-Status/PDNetErr ab. Das passt exakt zum beobachteten Symptom (`NO RESPONSE`, `status=nil`, `getError()=nil`).

**Decision**: `playdate.network.http.new(host, nil, true, ...)` → `playdate.network.http.new(host, 443, true, ...)` in `httpAndWait` — Port jetzt immer explizit, wie im offiziellen Beispiel demonstriert, für sowohl den Produktionspfad (`BACKEND_HOST`) als auch die Diagnose-Sonde (`example.com`). Minimale, gezielte Änderung (eine Zeile) statt eines größeren Umbaus — Iron Law der systematischen Fehlersuche: erst Hypothese mit Evidenz, dann EIN gezielter Test. Beide Constitution-Gates grün. **Noch nicht final verifiziert** — der nächste echte Simulator-Testlauf (Taste `1`/`3`) zeigt, ob das die Störung tatsächlich behebt oder ob weitere Ursachen (z. B. die eingangs unbestätigte Prozessfilterungs-Hypothese) noch zusätzlich greifen.

---

## R21: `playdate.json` existiert nicht — echter API-Name ist der globale `json` (Absturz + fehlendes UI-Update auf denselben Bug zurückgeführt)

**Befund**: Nach dem R20-Portfix ging der Roundtrip endlich durch (`POST /login -> 200`), stürzte aber sofort danach ab: `SyncService.lua:370: attempt to index a nil value (field 'json')` in `login()` bei `playdate.json.decode(respBody)`. Gegen die SDK-Doku (`Inside Playdate.html` §7.21 JSON) und das offizielle Beispiel `Examples/Level 1-1/Source/levelLoader.lua` verifiziert: JSON-Encoding/-Decoding hängt NICHT unter `playdate.*`, sondern ist ein eigener GLOBALER Name `json` (`json.decode(...)`, `json.encode(...)`), analog zu `math`/`string`/`table` — kein `CoreLibs/json`-Importpfad existiert überhaupt (`pdc`-Build bestätigt: "No such file: CoreLibs/json"), es ist ein natives C-API-Feature ohne Lua-Import-Bedarf. Unser Code griff bisher konsequent auf `playdate.json.decode` zu, was JEDES Mal deterministisch abstürzt, sobald `/login` mit Status 200 antwortet (nicht nur gelegentlich) — die Test-Suite fing das nicht ab, weil ihr eigener Mock (`tests/headless_tests.lua`) denselben falschen Namen erfunden hatte (`playdate.json = strictTable(...)`) statt den echten globalen `json` nachzubilden — dieselbe Fehlerklasse wie der bereits dokumentierte `generateQRCodeSync`-Bug (Mock und SDK divergierten, "erfundene API" auf beiden Seiten identisch falsch, daher unsichtbar für `strictTable`).

**Erklärt auch das zweite gemeldete Symptom ("UI aktualisiert nicht")**: `resultModalActive = true` wird erst im `onDone`-Callback von `startUpload` gesetzt, NACHDEM die Kette (inkl. `login()`) erfolgreich durchgelaufen ist. Ein Coroutine-Absturz (wie dieser) landet stattdessen im `onError`-Zweig von `RoomOperation:resume()` — `resultModalActive` wird nie gesetzt, das Ergebnis-Overlay erscheint nie. Kein separater UI-Bug nötig, um beide Symptome zu erklären — derselbe Absturz erklärt beides vollständig (`SelectionRoom.lua`s Redraw-Gate `needsRedraw or SyncService:isBusy() or SyncService:isShowingQrOverlay() or ...` ist korrekt jeden Frame neu ausgewertet, keine Stale-Flag-Problematik).

**Decision**: `playdate.json.decode(respBody)` → `json.decode(respBody)` in `login()` (`Source/SyncService.lua`). Test-Mock in `tests/headless_tests.lua` korrigiert: `playdate.json = strictTable(...)` → globales `json = strictTable(...)`, alle `playdate.json.encode(...)`-Aufrufe im Testcode auf `json.encode(...)` angepasst. (Ein Zwischenversuch, stattdessen `import "CoreLibs/json"` zu ergänzen, scheiterte am `pdc`-Build mit "No such file" — sofort verworfen, da die Datei in dieser SDK-Version schlicht nicht existiert; das eigentliche Problem war der falsche API-Name, kein fehlender Import.) Beide Constitution-Gates grün.

---

## R22: `readFileBytes` suchte `sheet.pdi`, echte Datei heißt `sheet` — `datastore.writeImage` hängt anders als `datastore.write` KEINE Endung an

**Befund**: Nach dem R21-Fix lief der Roundtrip bis zum Upload durch, scheiterte dann mit `upload: local_read_error (pdi=false json=true)`. Direkt auf der Platte verifiziert (`Disk/Data/de.merlinbecker.hansdither/saves/aaaa/`): die Datei heißt `sheet` (keine `.pdi`-Endung), `frames.json` dagegen MIT `.json`-Endung. Gegen SDK-Doku verifiziert (`Inside Playdate.html` §Datastore): `playdate.datastore.write(table, path)` — "The `.json` extension should be omitted from the file name" (wird also automatisch angehängt); `playdate.datastore.writeImage(image, path)` dagegen — "By default, this method writes out a PDI file… If you want to write out a GIF file, append a `.gif` extension to your path" (also KEINE automatische `.pdi`-Anhängung, der übergebene Pfad wird wörtlich verwendet). `ImageStoreCodec.lua` schreibt/liest bereits korrekt ohne Endung (`savePath .. "/sheet"`), `SyncService:attemptUpload` griff aber auf `"saves/" .. imageId .. "/sheet.pdi"` zu — Pfad-Mismatch. Dieselbe Fehlerklasse wie R21: der Test-Mock (`tests/headless_tests.lua`, `mockRawFiles["saves/bild1/sheet.pdi"]`) hatte denselben falschen Namen erfunden wie der Code, daher unsichtbar für die Test-Suite.

**Decision**: `SyncService:attemptUpload` liest jetzt von `"saves/" .. imageId .. "/sheet"` (ohne `.pdi`). Test-Mocks in `tests/headless_tests.lua` entsprechend korrigiert. Die Multipart-Upload-Feldbezeichnung (`multipartFile(boundary, "pdi", imageId .. ".pdi", ...)`) bleibt unverändert — das ist nur der an den Server gesendete Anzeige-Dateiname, unabhängig vom lokalen Lesepfad. Beide Constitution-Gates grün.

---

## R23: Fortschrittsbalken wurde nie gefüllt (Nutzer-Feedback) — kein Aufrufer kennt einen echten Fortschrittsanteil, SDK hat kein Spinner-Widget

**Nutzer-Feedback**: "spare dir die loadingbar, da du sie nicht fuellen kannst. definiere einen spinner, gibt es irgendwas in der doku?"

**Befund**: Grep über alle drei Aufrufer von `loadingBar`/`RoomOperation` (`SyncService.lua`, `EditorRoom.lua`, `RoomOperation.lua`) zeigt: KEINER ruft je `loadingBar:updateFraction`/`updateProgress` auf — `RoomOperation:resume()` setzt bei jedem Yield nur den Phasen-TEXT (`overlay:setDetail(value)`), nie einen Zahlenanteil. `progress` blieb also immer bei `0` (der einzige Ort, der es je auf einen anderen Wert setzte, war `fail()`, das es auf `1` zwang — ein reiner Nebeneffekt, kein echter Fortschritt). Der Balken war in dieser gesamten Codebasis nie funktional befüllt, unabhängig von Sync — reine unbenutzte Komplexität (Constitution Prinzip IV). Gegen `Inside Playdate.html` verifiziert: es gibt KEIN natives Spinner-/Activity-Indicator-Widget im SDK — einzige "Indicator"-Klasse ist `playdate.ui.crankIndicator` (`CoreLibs/ui/crankIndicator.lua`), die speziell für Crank-Gesten-Aufforderungen gedacht ist, kein generisches Warte-Widget.

**Decision**: `Source/loadingBar.lua` umgebaut: `progress`/`updateFraction`/`updateProgress`/`clamp` (unbenutzt nach Entfernung) entfernt, stattdessen ein simpler Text-Spinner (`| / - \` rotierend alle 150ms, über `playdate.getCurrentTimeMilliseconds()` seit `show()`). Nutzt ausschließlich bereits im Projekt verifizierte Primitiven (`gfx.drawTextAligned`, `getCurrentTimeMilliseconds`) — keine neue, ungeprüfte SDK-Fläche. Bei `fail()` zeigt der Spinner-Platz statt der Animation ein statisches `!!` (ASCII-only, R14). Betrifft alle drei Aufrufer gleichermaßen (Save/Load in EditorRoom, Sync-Kette) — eine einzige gemeinsame Komponente, ein einziger Fix. Beide Constitution-Gates grün.

---

## Zusammenfassung: Korrigierte SDK-Referenzen (vs. ursprüngliche Spec-Annahmen)

| Ursprüngliche Annahme (Spec-Entwurf) | Verifizierter, tatsächlicher API-Name |
|---|---|
| `playdate.graphics.qrCode` | `playdate.graphics.generateQRCodeSync` / `generateQRCode` |
| `playdate.net` | `playdate.network.http` |
| `playdate.json.decode`/`.encode` | globales `json.decode`/`json.encode` (kein `playdate.*`-Feld, kein CoreLibs-Import, R21) |
| Sync-Eintrag im System-Menü | Crank-Geste (System-Menü hat keinen freien Slot, siehe R1) |
| Sammel-Upload aller Images | Einzelbild-Upload pro Crank-Geste (siehe R1/US2) |
| `Source/tools/` als Basis | Existiert nicht; neues `Source/SyncService.lua` |
| Re-Sync = neuer Eintrag (Duplikat) | Re-Sync = Update in-place via `(uid, client_image_id)` (R9) |
| Gegen-Uhrzeigersinn-Geste = Verknüpfung zurücksetzen | Entfernt (YAGNI) — FR-013 Out of Scope für dieses Release |
