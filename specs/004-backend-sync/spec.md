# Feature Specification: Backend-Synchronisation für Hans Dither

**Feature Branch**: `feature/0.3`

**Created**: 2026-07-12

**Status**: Draft

**Input**: User description: "Synchronisation zwischen Backend und Playdate: Export von auf dem Playdate erstellten Hans-Dither-Zeichnungen an ein Web-Backend, dort Anzeige und Download als PDI+JSON oder gerendertem PNG. QR-basiertes Pairing mit 4-stelliger PIN-Absicherung, Upload aller Projekte inkl. PDI und JSON, Backend rendert Tilemap zu PNG."

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Playdate mit Backend verknüpfen (Priority: P1)

Als Nutzer möchte ich mein Playdate-Gerät mit meinem Backend-Konto verknüpfen, um meine Zeichnungen später exportieren und ansehen zu können. Ich selektiere ein Bild in der Bildübersicht (SelectionRoom) und drehe die Kurbel zwei volle Umdrehungen im Uhrzeigersinn — solange ein Bild selektiert ist, zeigt das Playdate dazu einen Crank-Hinweis ("crank to sync") an. Da noch keine Verknüpfung existiert, generiert das Playdate selbst eine zufällige 4-stellige PIN und meldet sich damit SELBST beim Backend an (`POST /pair`) — ohne dass ich irgendetwas auf einer Website eingeben muss. Direkt im Anschluss lädt das Playdate das ausgewählte Bild hoch (US2) und zeigt danach einen QR-Code (Backend-Adresse + Playdate-UID) sowie die PIN an. Scanne ich diesen Code später auf einem anderen Gerät und gebe die angezeigte PIN im Browser ein, sehe ich meine bereits hochgeladenen Bilder — die Website-PIN-Eingabe ist also kein Upload-Gate mehr, sondern ausschließlich der Weg, das Ergebnis anzusehen.

**Why this priority**: Ohne Verknüpfung kann kein Upload erfolgen. Dies ist die Grundlage für den gesamten Sync-Workflow.

**Independent Test**: Einzige Abhängigkeit ist das Playdate SDK (QR-Code-Generierung, Crank-Rotationsmessung, lokale Zufallszahl für die PIN) plus das bestehende Backend (`POST /pair`, bereits aus Spec 005 vorhanden). Der QR-Code muss die Backend-URL + UID enthalten und kann mit jedem QR-Scanner gelesen werden. Die generierte PIN muss genau 4 Ziffern haben. Die Crank-Geste muss ohne Bildauswahl wirkungslos bleiben.

**Acceptance Scenarios**:

1. **Given** ein Bild ist in der SelectionRoom selektiert und Playdate ist nicht mit einem Backend verknüpft, **When** Nutzer die Kurbel zwei volle Umdrehungen im Uhrzeigersinn dreht, **Then** generiert das Playdate eine zufällige 4-stellige PIN, meldet sich selbst per `POST /pair` beim Backend an und fährt ohne weitere Nutzerinteraktion mit dem Upload des ausgewählten Bildes fort (US2).
2. **Given** der Upload war erfolgreich, **When** das Playdate den Ergebnisscreen zeigt, **Then** enthält dieser einen QR-Code (Backend-URL + UID) sowie die PIN, über die der Nutzer später auf der Website die hochgeladenen Bilder ansehen kann.
3. **Given** QR-Code wird auf einem anderen Gerät gescannt, **When** Nutzer die Backend-URL öffnet, **Then** wird die Playdate-UID erkannt und zur Eingabe der auf dem Playdate angezeigten PIN aufgefordert, um die Bilderliste anzusehen (reiner View-Zugang, kein Upload-Schritt).
4. **Given** Verknüpfung im Backend bereits vorhanden, **When** der Nutzer erneut die Crank-Sync-Geste auf einem Bild ausführt, **Then** überspringt das Playdate den Pairing-Schritt (ein einziger `/login`-Aufruf genügt) und lädt direkt hoch, ohne erneuten Netzwerk-Overhead.
5. **Given** ein Bild ist selektiert und die Kurbel ist eingeklappt, **When** die SelectionRoom den Crank-Hinweis anzeigt, **Then** wird zusätzlich der System-Crank-Alert eingeblendet, der zum Ausklappen auffordert.

---

### User Story 2 - Zeichnung zum Backend hochladen (Priority: P1)

Als Nutzer möchte ich eine einzelne, auf dem Playdate erstellte Zeichnung (Image) mit allen Frames an mein Backend hochladen, um sie dort anzeigen und herunterladen zu können. Ich selektiere das gewünschte Bild in der SelectionRoom und drehe die Kurbel zwei volle Umdrehungen im Uhrzeigersinn. Das Playdate autorisiert sich dabei automatisch mit der lokal gespeicherten, selbstgenerierten PIN (bei Bedarf inklusive automatischem Pairing, siehe US1) — ich muss nichts eingeben und nicht auf eine Website wechseln. Genau dieses eine Projekt (PDI-Datei + frames.json) wird übertragen; danach zeigt das Playdate einen Vollbild-Ergebnisscreen mit QR-Code (Backend-URL + UID) und PIN, über den ich das Ergebnis später in der Backend-Bilderliste aufrufen kann. Möchte ich mehrere Bilder synchronisieren, wiederhole ich die Geste pro Bild.

**Why this priority**: Der Upload ist der Kern des Sync-Features. Ohne ihn können Nutzer ihre Kreationen nicht exportieren.

**Independent Test**: Kann unabhängig von einer vorherigen Website-Interaktion getestet werden — US1 (Pairing) läuft bei Bedarf automatisch als Teil derselben Crank-Geste mit. Der Upload kann mit Mock-Backend getestet werden, das die empfangenen Dateien validiert (PDI-Format aus Spec 001, JSON-Struktur aus Spec 001).

**Acceptance Scenarios**:

1. **Given** ein Bild ist selektiert, **When** Nutzer die Kurbel zwei volle Umdrehungen im Uhrzeigersinn dreht, **Then** startet die Kette aus (bei Bedarf) Pairing + Login + Upload dieses einen Bildes direkt — keine PIN-Eingabe, kein Website-Besuch nötig.
2. **Given** Upload gestartet, **When** das Playdate sich im Hintergrund mit UID + gespeicherter PIN autorisiert, **Then** wird genau das selektierte Image (PDI + frames.json) an das Backend unter `/{UID}` gesendet.
3. **Given** Upload läuft, **When** Verbindung unterbrochen wird, **Then** wird der Upload angehalten und kann später fortgesetzt werden.
4. **Given** Upload erfolgreich, **When** das Playdate den QR-Code auf dem Ergebnisscreen anzeigt und dieser später gescannt wird, **Then** ist das neue Image in der Backend-Bilderliste sichtbar.
5. **Given** die lokal gespeicherte PIN wird vom Backend abgelehnt (z. B. eine Altlast aus einer alten, inzwischen abgeschafften Web-Pairing-Ära), **When** Upload versucht wird, **Then** pairt sich das Playdate automatisch neu (siehe FR-004b) und versucht den Login danach genau einmal erneut, statt den Nutzer manuell auf eine Website zu verweisen; schlägt auch das fehl, wird ein klarer Fehler angezeigt.
6. **Given** ein Bild wurde bereits einmal hochgeladen, **When** der Nutzer die Crank-Geste auf demselben Bild (derselben lokalen Bild-ID) erneut ausführt, **Then** wird der bestehende Backend-Eintrag für diese Bild-ID aktualisiert (Dateien ersetzt, Vorschaubilder neu generiert) statt ein neuer, unabhängiger Eintrag erzeugt — siehe FR-007b.

---

### User Story 3 - Projekte im Backend anzeigen und herunterladen (Priority: P2)

Als Nutzer möchte ich meine im Backend gespeicherten Projekte in einer Web-UI anzeigen und als PDI+JSON oder gerendertes PNG herunterladen können. Das Backend zeigt alle zu meiner UID gehörenden Images an. Ich kann einzelne Dateien (PDI, JSON) oder das serverseitig gerenderte PNG herunterladen.

**Why this priority**: Ohne Anzeige und Download hat der Upload keinen Nutzen für den User. Allerdings setzt dies den Upload (US2) voraus.

**Independent Test**: Backend kann unabhängig vom Playdate getestet werden. Manuelle PDI+JSON-Dateien können hochgeladen und angezeigt werden.

**Acceptance Scenarios**:

1. **Given** Backend-UI wird mit gültiger UID aufgerufen, **When** Seite lädt, **Then** werden alle Images dieser UID als Liste mit Vorschaubildern (PNG) angezeigt.
2. **Given** Image in der Liste ausgewält, **When** Nutzer "PDI herunterladen" wählt, **Then** wird die PDI-Datei zum Download angeboten.
3. **Given** Image in der Liste ausgewählt, **When** Nutzer "JSON herunterladen" wählt, **Then** wird die frames.json-Datei zum Download angeboten.
4. **Given** Image in der Liste ausgewählt, **When** Nutzer "PNG herunterladen" wählt, **Then** wird das serverseitig gerenderte PNG (400×240) zum Download angeboten.
5. **Given** Ungültige UID, **When** Backend-UI aufgerufen wird, **Then** wird "Keine Projekte gefunden" angezeigt.

---

### Edge Cases

- Was passiert, wenn das Playdate offline ist? → Uploads werden lokal zwischengespeichert und beim nächsten Sync nachgeholt (Queue-System).
- Was passiert, wenn die lokal gespeicherte PIN vom Backend abgelehnt wird (z. B. eine Altlast aus einer alten, inzwischen abgeschafften Web-Pairing-Ära, bei der eine andere PIN im Backend landete)? → Das Playdate pairt sich automatisch selbst neu mit seiner lokal gecachten PIN (`POST /pair`, sicher solange die UID noch nie einen erfolgreichen Login hatte, siehe FR-004b/research.md R12/R13) und versucht den Login danach genau einmal erneut — kein manueller Website-Besuch nötig. Schlägt auch das fehl (z. B. weil die UID einem anderen, bereits bestätigten Gerät gehört — praktisch unerreichbar bei 2^64 zufälligen UIDs), wird eine klare Fehlermeldung angezeigt.
- Was passiert, wenn die UID bereits verknüpft ist? → Bestehende Verknüpfung wird verwendet (ein einziger `/login`-Aufruf genügt, kein `/pair`-Overhead); ein Zurücksetzen der Verknüpfung ist in diesem Release nicht vorgesehen (FR-013, YAGNI).
- Was passiert, wenn das Backend nicht erreichbar ist? → Fehler "Network error" wird angezeigt; Upload kann später wiederholt werden.
- Was passiert bei beschädigter PDI-Datei? → Backend versucht trotzdem zu rendern; bei Fehler wird PNG nicht generiert und im UI als "fehlerhaft" markiert.
- Was passiert, wenn mehrere Playdate-Geräte dieselbe UID haben? → Jedes Gerät generiert seine UID selbst zufällig (16 Hex-Zeichen, siehe FR-001); bei einer echten Kollision lehnt `/pair` den zweiten, bereits bestätigten Anspruch mit `409` ab (praktisch unerreichbar, siehe research.md R10/R13).
- Was passiert bei einem Bild mit sehr vielen Animationsframes (>100)? → Upload wird auf Protokollebene als ein zusammenhängender Request gesendet; Backend zeigt Fortschritt an (Bytes statt Bild-Anzahl, da nur ein Image pro Upload).
- Was passiert, wenn der Speicherplatz im Backend voll ist? → Backend lehnt neue Uploads ab und zeigt "Speicher voll" im UI.
- Was passiert, wenn die Kurbel eingeklappt ist, während ein Bild selektiert ist? → Das Playdate zeigt den `crank to sync`-Hinweis zusammen mit dem System-Crank-Alert (`playdate.isCrankDocked()`), der zum Ausklappen auffordert; ohne ausgeklappte Kurbel kann die Geste nicht ausgeführt werden.
- Was passiert bei unvollständiger oder unterbrochener Kurbel-Drehung (z. B. Richtungswechsel oder Abbruch bei 300°)? → Die kumulierte Rotation wird zurückgesetzt, sobald die Kurbel signifikant gegen die Uhrzeigerrichtung dreht oder die Bildauswahl wechselt; der Sync wird nicht ausgelöst.
- Was passiert, wenn dasselbe Bild mehrfach per Crank-Geste hochgeladen wird? → Das Backend aktualisiert den bestehenden Eintrag für diese (UID, lokale Bild-ID)-Kombination in-place (Dateien ersetzt, Vorschauen invalidiert) statt einen neuen anzulegen (FR-007b).
- Was passiert, wenn das automatische Re-Pairing (FR-004b) selbst in die 3-Versuche-Sperre des Backends läuft? → Kann strukturell nicht passieren: Ein `/login`-Fehlschlag mit `429` (bereits gesperrt) löst KEINEN automatischen `/pair`-Versuch aus (das würde die laufende Sperre ohnehin nicht aufheben) — nur `404` (UID unbekannt) und `400` (PIN passt nicht) lösen den Self-Heal-Pfad aus, und `404` erhöht laut Backend-Code (`backend/includes/auth.php`) nie den Fehlversuchszähler (research.md R11/R13).
- Was passiert, wenn der Nutzer auf der Website (nach dem Upload, zum Ansehen) eine andere PIN eingibt als die auf dem Playdate angezeigte? → Der Login auf der Website schlägt fehl (`400`), die bereits hochgeladenen Bilder bleiben unberührt; der Nutzer muss die korrekte, auf dem Playdate angezeigte PIN verwenden. Dies betrifft nur das Ansehen, nicht den Upload (siehe US1/US2 — der Upload ist zu diesem Zeitpunkt bereits abgeschlossen und unabhängig von der Website).

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Jedes Playdate-Gerät MUSS eine eindeutige Geräte-ID (UID) besitzen. Da das SDK keine Hardware-Seriennummer für Lua-Spiele bereitstellt (verifiziert in der Implementierungsphase, siehe Clarifications), MUSS das Playdate die UID beim ersten Sync-Versuch selbst zufällig generieren und dauerhaft lokal cachen (analog zur PIN-Generierung, FR-004).
- **FR-002**: Solange ein Bild in der SelectionRoom selektiert ist, MUSS das Playdate eine Crank-Geste (zwei vollständige Umdrehungen im Uhrzeigersinn, kumulativ ≥720°, ohne signifikante Gegenrichtung) als Sync-Auslöser für genau dieses eine Bild anbieten. **Begründung für diese Lösung statt eines System-Menü-Eintrags**: Das Playdate-SDK erlaubt maximal drei eigene System-Menü-Einträge; SelectionRoom und EditorRoom nutzen diese bereits vollständig für andere Funktionen (siehe research.md).
- **FR-002a**: Solange ein Bild selektiert ist, MUSS das Playdate einen visuellen Crank-Hinweis anzeigen (Text "crank to sync" + `playdate.ui.crankIndicator`); ist die Kurbel eingeklappt, MUSS zusätzlich der System-Crank-Alert erscheinen (`playdate.isCrankDocked()`).
- **FR-003**: Nach erfolgreichem Upload MUSS das Playdate einen QR-Code anzeigen, der die Backend-URL und die Geräte-UID enthält (Ergebnisscreen, siehe FR-007a). **Korrektur (2026-07-18, drittes Nutzer-Feedback)**: Der QR-Code erscheint nicht mehr VOR dem Upload als Warteschritt, sondern NACH dem Upload als Ergebnis — siehe FR-004/FR-004a/research.md R13.
- **FR-004**: Bei nicht verknüpftem Gerät MUSS das Playdate selbst eine zufällige 4-stellige PIN generieren und sich damit selbst beim Backend anmelden (`POST /pair`), OHNE auf eine Bestätigung durch den Nutzer auf einer Website zu warten. **Korrektur (2026-07-18, drittes Nutzer-Feedback, research.md R13)**: Ursprünglich musste der Nutzer die PIN zuerst im Browser eingeben, bevor ein Upload möglich war (Bestätigungs-Gate). Da uid UND PIN beide ausschließlich geräteseitig erzeugt werden, bietet dieses Gate keine zusätzliche Sicherheit — das Gerät registriert sich jetzt autonom und fährt direkt mit dem Upload fort (siehe US1/US2).
- **FR-004a**: Der Website-`/pair`- bzw. `/login`-Flow (Spec 005) bleibt bestehen, ist aber KEIN Upload-Gate mehr, sondern ausschließlich der Weg für den Nutzer, die bereits hochgeladenen Bilder in der Backend-Galerie anzusehen (Eingabe der auf dem Playdate angezeigten PIN, um sich einzuloggen). **Korrektur (2026-07-18)**: Ersetzt die ursprüngliche FR-004a ("Backend muss PIN-Eingabe erfordern, um die Verknüpfung zu bestätigen") — die Verknüpfung wird nicht mehr durch eine Website-Aktion bestätigt, sondern ist mit dem autonomen `/pair`-Aufruf des Geräts (FR-004) bereits abgeschlossen.
- **FR-004b**: Schlägt ein `/login`-Versuch des Geräts mit "UID unbekannt" (404) ODER "PIN passt nicht" (400) fehl, MUSS das Playdate automatisch (ohne Nutzerinteraktion) `POST /pair` mit seiner lokal gecachten UID+PIN aufrufen und den Login danach genau einmal erneut versuchen (Self-Heal). Das Backend MUSS dafür einen erneuten Pairing-Versuch für dieselbe UID zulassen, solange sie noch nie einen erfolgreichen Login hatte ("unbestätigt", bestehenden PIN-Hash überschreiben) — verhindert, dass ein Backend-Zustand aus einer früheren, fehlgeschlagenen Verknüpfung dauerhaft blockiert. Nach dem ersten erfolgreichen Login gilt die Verknüpfung als bestätigt und ist vor Überschreiben geschützt. Ein `/login`-Fehlschlag wegen Sperre (429) löst KEINEN automatischen `/pair`-Versuch aus (siehe research.md R12/R13).
- **FR-005**: Die PIN MUSS serverseitig gespeichert werden (gehasht, nicht im Klartext) und mit der UID verknüpft sein.
- **FR-006**: Das Playdate MUSS seine selbstgenerierte PIN dauerhaft lokal speichern (`playdate.datastore`, ab dem allerersten Sync-Versuch) und bei jedem Pairing/Login/Upload automatisch verwenden, ohne dass der Nutzer sie jemals eingeben muss.
- **FR-006a**: Das Playdate MUSS in der Lage sein, den Verknüpfungsstatus serverseitig zu prüfen (authentifizierter Testaufruf mit UID + eigener PIN). **Korrektur (2026-07-18, drittes Nutzer-Feedback, research.md R13)**: Dieser Check ist der erste Schritt jeder Crank-Sync-Geste (kein separater, wartender Prompt mehr) — schlägt er fehl, wird automatisch der Self-Heal-Pfad aus FR-004b ausgelöst, kein Hintergrund-Polling und kein Warten auf eine externe Bestätigung mehr nötig (das gesamte in einer Zwischenversion eingeführte Auto-Polling-Subsystem, research.md R11, wurde ersatzlos entfernt).
- **FR-006b**: Führt der Verknüpfungsstatus-Check (FR-006a, ggf. inklusive Self-Heal nach FR-004b) zu einer erfolgreichen Anmeldung, MUSS das Playdate automatisch mit dem Upload des Bildes fortfahren, das die auslösende Crank-Geste ausgewählt hatte — der Nutzer cranked einmal und das Bild landet ohne zweite Geste und ohne Website-Besuch beim Backend.
- **FR-007**: Der Upload MUSS genau das durch die Crank-Geste ausgewählte Image umfassen, als PDI-Datei + frames.json (gemäß Spec 001 Contract), zusammen mit der lokalen Bild-ID (siehe FR-007b). Mehrere Images werden durch wiederholte Crank-Gesten auf jeweils einzelnen Bildern synchronisiert, nicht als Sammel-Upload.
- **FR-007a**: Nach erfolgreichem Upload eines Images MUSS das Playdate einen Vollbild-Ergebnisscreen mit QR-Code (Backend-URL + UID) und PIN anzeigen, über den der Nutzer das hochgeladene Bild später in der Backend-Bilderliste aufrufen kann (Liste, kein Einzelbild-Deep-Link — siehe Clarifications).
- **FR-007b**: Das Playdate MUSS seine lokale, stabile Bild-ID (siehe `ImageStore.sanitizeName`, Format `[a-z0-9-]+`) beim Upload mitschicken. Das Backend MUSS beim erneuten Upload derselben (UID, lokale Bild-ID)-Kombination den bestehenden Eintrag aktualisieren (Dateien ersetzen, gerenderte Vorschauen invalidieren) statt einen neuen Eintrag anzulegen — erfordert eine kleine, additive Erweiterung des bestehenden Upload-Endpunkts aus Spec 005 (siehe Dependencies, contracts/sync-protocol.md).
- **FR-008**: Das Backend MUSS die hochgeladenen Dateien unter dem Pfad `/{UID}/` speichern.
- **FR-009**: Das Backend MUSS in der Lage sein, PDI-Dateien zu öffnen, die frames.json zu lesen, die Tilemap zu rekonstruieren und als PNG (400×240, 1-Bit) zu rendern.
- **FR-010**: Das Backend-UI MUSS alle Images einer UID in einer liste mit Vorschaubildern (PNG) anzeigen.
- **FR-011**: Das Backend-UI MUSS für jedes Image separate Download-Optionen für PDI, frames.json und PNG anbieten.
- **FR-012**: Das Playdate MUSS den Verknüpfungsstatus (verknüpft/nicht verknüpft) anzeigen. **Ergänzung (2026-07-18, research.md R14)**: Alle Sync-UI-Texte (Statuszeile, Fehlermeldungen, Ergebnisscreen) MÜSSEN Englisch und ASCII-only sein, konsistent mit dem Rest der App-UI — der Playdate-System-Font stellt Umlaute und Sonderzeichen wie den Halbgeviertstrich als Ersatzzeichen ("�") dar, auf echtem Gerät sichtbar geworden (Nutzer-Screenshot).
- **FR-013**: ~~Verknüpfung zurücksetzen~~ — **Out of Scope für dieses Feature** (YAGNI-Entscheidung, siehe Clarifications). Kein In-App-Mechanismus zum Zurücksetzen der Verknüpfung in diesem Release; kann bei tatsächlichem Bedarf in einer späteren Iteration nachgerüstet werden (z. B. erneut über eine Crank-Geste, sobald ein Bedarf konkret vorliegt).
- **FR-014**: Das Backend MUSS Uploads ohne gültige PIN ablehnen.
- **FR-015**: Das Playdate MUSS den Upload-Fortschritt des einen laufenden Vorgangs als Phasentext anzeigen (z. B. "Logging in...", "Uploading...") — kein Byte-/Prozent-Fortschrittsbalken, da `playdate.network.http` keine Fortschritts-API für den ausgehenden Request-Body bietet (`getProgress()` bezieht sich ausschließlich auf das Lesen der Antwort, siehe research.md R4).

### Key Entities

- **Playdate Device**: Physisches Gerät mit eindeutiger UID (vom Playdate SDK). Enthält Images (Projekte).
- **Device UID**: Eindeutige Kennung des Playdate-Geräts (String, z. B. "pd-abc123def456"), vom Playdate selbst zufällig generiert (nicht vom SDK bereitgestellt, siehe FR-001) und lokal gecacht.
- **Backend Service**: Web-Dienst, der Uploads annimmt, speichert und PNGs rendert. Stellt UI unter einer Base-URL bereit.
- **PIN**: 4-stellige numerische Authentifizierung (0000-9999) für die Verknüpfung zwischen Gerät und Backend. Wird vom Playdate selbst zufällig generiert (nicht vom Nutzer gewählt) und autonom beim Backend registriert (FR-004); dauerhaft auf dem Playdate gecacht und dem Nutzer nur zum späteren Ansehen der Galerie im Browser gezeigt.
- **QR Code**: Enthält Backend-Base-URL + Device UID als Query-Parameter `uid` (z. B. `https://www.hans-dither.de/?uid=pd-abc123def456`). Wird auf dem Ergebnisscreen NACH einem erfolgreichen Upload angezeigt (FR-007a), nicht mehr als Warteschritt davor. Die Route `GET /?uid={UID}` ist bereits in Spec 005 implementiert (`backend/public/index.php:82-92`) und leitet automatisch zu `/pair?uid=` (unbekannte UID) bzw. `/login?uid=` (bekannte UID) weiter.
- **Image**: Hans Dither Projekt, bestehend aus PDI-Datei (Imagetable) + frames.json (Frame-Daten, gemäß Spec 001). Wird einzeln (nicht als Sammlung) über die Crank-Geste synchronisiert.
- **Rendered PNG**: Serverseitig generiertes Bild (400×240 Pixel, 1-Bit) aus PDI + frames.json.
- **Sync-Geste**: Kumulative Crank-Rotation (≥720° im Uhrzeigersinn = Sync/Upload dieses einen Bildes), gemessen ausschließlich während ein Bild in der SelectionRoom selektiert ist. Ersetzt den ursprünglich vorgesehenen System-Menü-Eintrag (siehe FR-002). Eine Gegen-Uhrzeigersinn-Geste zum Zurücksetzen der Verknüpfung ist in diesem Release nicht vorgesehen (FR-013, YAGNI).

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Der vollständige Sync-Workflow (Verknüpfung + Upload eines Images) kann in unter 2 Minuten abgeschlossen werden.
- **SC-002**: Hochgeladene Images sind innerhalb von 5 Sekunden im Backend-UI sichtbar.
- **SC-003**: Das serverseitig gerenderte PNG ist pixelgenau identisch mit der Darstellung auf dem Playdate (400×240, 1-Bit).
- **SC-004**: 100% aller erfolgreich hochgeladenen Images sind im Backend-UI abrufbar und herunterladbar.
- **SC-005**: Ein Nutzer kann ohne Anleitung die Verknüpfung und den ersten Upload innerhalb von 5 Minuten durchführen (US1 + US2).
- **SC-006**: Der Upload-Prozess blockiert die Playdate-Bedienung nicht; Nutzer kann Upload abbrechen und weiter arbeiten.

---

## Clarifications

### Session 2026-07-18

- Q: Bleibt dieses Feature auf einem eigenen Branch (`feature/0.4`, wie im Spec-Header vermerkt), oder wird es auf dem aktuellen Branch weitergeführt? → A: Alles wird auf `feature/0.3` weitergeführt; kein separater Sync-Branch. Der Feature-Branch-Header wurde entsprechend korrigiert.
- Q: Spec 005 (Backend-Service, bereits implementiert) realisiert das Pairing über manuelle UID-Eingabe auf einer Startseite (`/` mit Eingabefeld) statt über einen vom Playdate generierten QR-Code — welcher Flow ist für Spec 004 maßgeblich? → A: Der QR-Code-Pairing-Flow vom Playdate (US1) bleibt der primäre, essenzielle Flow. Die manuelle UID-Eingabe in `backend/public/index.php` dient nur Testzwecken und bleibt als Fallback bestehen, ist aber nicht der Produktivpfad.
- Q: Ist eine ausgebaute Marketing-/Erklär-Startseite für hans-dither.de Teil dieses Feature-Scopes? → A: Nein, das ist für eine spätere Iteration vorgesehen. Für den QR-Pairing-Flow reicht die bereits in Spec 005 implementierte funktionale Route `GET /?uid={UID}` (leitet automatisch zu `/pair?uid=` bzw. `/login?uid=` weiter, siehe `backend/public/index.php:82-92`) als Sprungziel des QR-Codes.
- Q: Die Constitution (v1.1.0, Technische Randbedingungen) schließt Netzwerkabhängigkeiten aus ("Persistenz: ... keine Netzwerkabhängigkeiten"), was im Widerspruch zu diesem Feature (HTTP-Uploads via `playdate.net`) steht. Wie wird das aufgelöst? → A: Die Constitution wird amendet — klargestellt, dass sich das Netzwerkverbot nur auf die Kern-Zeichenpersistenz bezieht (lokal, ohne Cloud-Save), Sync/Backend ist eine explizit zugelassene, separate Netzwerk-Fähigkeit. **Offener Folgeschritt**: `/speckit-constitution` MUSS vor `/speckit-plan` ausgeführt werden, um diese Klarstellung formal (MINOR-Versionserhöhung + ADR) in der Constitution zu verankern.
- Q: FR-006 verlangt eine erneute PIN-Abfrage bei jedem Upload — das Playdate hat aber keine Tastatur (nur D-Pad/A/B/Crank). Wie soll die PIN-Autorisierung beim Upload praktisch funktionieren? → A: Keine erneute Eingabe. Die PIN wird nach der Erstverknüpfung lokal auf dem Playdate gecacht und automatisch bei jedem Upload verwendet.
- Q: Die PIN wird beim Pairing im Browser vergeben (nicht auf dem Playdate) — das Playdate kennt sie also zunächst nicht. Wie erfährt/erhält das Playdate die PIN, damit es sie cachen kann? → A: Das Playdate generiert die PIN selbst (zufällig, 4-stellig) und zeigt sie zusammen mit dem QR-Code an; der Nutzer überträgt sie durch Abtippen im Browser. Damit kennt das Playdate seine PIN von Anfang an und muss nie eine vom Nutzer gewählte PIN empfangen — FR-004 wird entsprechend umgekehrt (PIN-Ursprung: Gerät statt Nutzer).

### Session 2026-07-18 (Planungsphase — SDK-Verifikation)

- Q: FR-002 sah einen "Sync-Eintrag im Kontextmenü" vor. SDK-Verifikation in der Planungsphase ergab: Das Playdate-SDK erlaubt maximal drei eigene System-Menü-Einträge (`playdate.getSystemMenu()`), und SelectionRoom ("new image", "copy image", "delete image") wie EditorRoom ("save + exit", "delete frame", "show grid") nutzen diese bereits vollständig aus. Ein vierter Eintrag ist technisch nicht möglich. Wie soll der Sync-Einstiegspunkt stattdessen realisiert werden? → A: Crank-Geste bei selektiertem Bild in der SelectionRoom (zwei volle Umdrehungen im Uhrzeigersinn = Sync/Upload dieses einen Bildes). Die Kurbel ist in SelectionRoom aktuell vollständig ungenutzt. Bei Bildauswahl erscheint ein Crank-Hinweis ("crank to sync" + `playdate.ui.crankIndicator`); bei eingeklappter Kurbel zusätzlich der System-Crank-Alert (`playdate.isCrankDocked()`). Damit einher geht eine Änderung des Upload-Modells: Statt eines Sammel-Uploads aller Images (ursprüngliches FR-007) wird **jedes Bild einzeln** per eigener Crank-Geste synchronisiert; nach erfolgreichem Upload zeigt das Playdate erneut den QR-Code zur Ansicht in der Backend-Bilderliste (neues FR-007a). FR-002, FR-003, FR-007, US1, US2 und die Edge Cases wurden entsprechend angepasst.

### Session 2026-07-18 (Planungsphase — Advisor-Review)

- Q: Bei erneutem Upload desselben lokalen Bildes vergibt das Backend aktuell (Spec 005, unverändert) bei jedem Upload eine neue, zufällige Image-ID — kein Update-Mechanismus. Soll ein Re-Sync per Crank-Geste einen neuen, unabhängigen Eintrag erzeugen (Duplikat, kein Backend-Change) oder den bestehenden Eintrag aktualisieren (Update in-place, erfordert kleine Backend-Erweiterung)? → A: Update in-place. Das Playdate schickt seine stabile lokale Bild-ID (`ImageStore.sanitizeName`-Format, `[a-z0-9-]+`) beim Upload mit; das Backend erweitert `upload_handler.php`/`upload.php` um ein optionales `image_id`-Feld: ist die Kombination (UID, lokale Bild-ID) bereits bekannt, werden die Dateien ersetzt und Vorschauen invalidiert, statt einen neuen Eintrag anzulegen (neues FR-007b). Dies ist eine kleine, additive, rückwärtskompatible Erweiterung des bestehenden, als "Complete" markierten Spec-005-Backends — kein neues Backend-Feature, sondern eine gezielte Korrektur, damit "Synchronisation" tatsächlich synchronisiert statt zu duplizieren.
- Q: Der Post-Upload-QR-Code (FR-007a) zeigt auf die gesamte Backend-Bilderliste (`/?uid=`), nicht auf das eine gerade hochgeladene Bild — ein Einzelbild-Deep-Link existiert im Backend nicht. Reicht der Listen-Link, oder soll ein Einzelbild-Deep-Link ergänzt werden? → A: Der Listen-Link reicht; kein Backend-Change für diesen Punkt. Das neue Bild ist nach Login in der Liste sichtbar (SC-002, < 5 Sekunden).
- Q: FR-013 (Verknüpfung zurücksetzen) wurde zuvor mit einer selbst vorgeschlagenen, vom Nutzer nicht angeforderten Gegen-Uhrzeigersinn-Geste belegt. Beibehalten oder als YAGNI aus dem Scope streichen? → A: Streichen (YAGNI). FR-013 ist für dieses Release Out of Scope; kann bei tatsächlichem Bedarf später nachgerüstet werden. Alle Referenzen auf die Gegen-Uhrzeigersinn-Geste wurden aus Spec, Edge Cases und Key Entities entfernt.

### Session 2026-07-18 (Implementierungsphase — SDK-Verifikation)

- Q: FR-001 nahm an, die UID werde "vom Playdate SDK bereitgestellt". Verifikation gegen `CoreLibs/__stub.lua` (vollständige Liste aller `playdate.*`-Top-Level-Funktionen) ergab: Es existiert keine Geräte-Seriennummer-/eindeutige-Hardware-ID-API für Lua-Spiele (kein `getDeviceUniqueIdentifier()` o. ä.) — vermutlich bewusst aus Privacy-Gründen von Panic nicht exponiert. Wie wird die UID stattdessen bestimmt? → A: Das Playdate generiert die UID selbst zufällig (16 Hex-Zeichen, Präfix `pd-`) beim ersten Sync-Versuch, mit derselben geseedeten Zufallsquelle wie die PIN (research.md R7), und cached sie dauerhaft in `sync/state` (analog zur PIN). FR-001, Key Entities "Device UID" und die entsprechende Assumption wurden korrigiert. Kollisionsrisiko zwischen zwei Geräten wird als vernachlässigbar akzeptiert (16 Hex-Zeichen ≈ 2^64 Kombinationen, privater Use Case) — siehe research.md R10.

### Session 2026-07-18 (Implementierungsphase — erster Simulator-Test durch den Nutzer)

- Q: Erster echter Pairing-Versuch (QR anzeigen, im Browser Website öffnen, PIN eingeben) führte zu keiner Verknüpfung und keinem Upload. Root Cause? → A: Das Backend-Pairing-Formular (`backend/public/index.php`) forderte den Nutzer nur zu "eine PIN eingeben" auf, ohne zu spezifizieren, dass es die AUF DEM PLAYDATE ANGEZEIGTE PIN sein muss — eine bereits in den Assumptions (Zeile 177, oben) korrekt vorhergesagte, aber nie umgesetzte Lücke ("was außerhalb des Playdate-seitigen Scopes von Spec 004 liegt" — dieser Fix betrifft Backend-Code aus Spec 005 und wurde daher in dieser Runde nachgeholt statt weiter aufgeschoben, da er die Kernfunktion von Spec 004 blockierte). FR-004a entsprechend korrigiert.
- Q: Wie soll das Gerät erkennen, dass die Website-Verknüpfung abgeschlossen wurde, ohne dass der Nutzer erneut zum Playdate zurückkehren und cranken muss? → A: Automatisches periodisches Polling während der QR+PIN-Prompt sichtbar ist (FR-006a-Korrektur), begrenzt auf ein festes Intervall/Timeout. Ursprünglich war explizites Hintergrund-Polling wegen Sperr-Risiko ausgeschlossen worden — Analyse des tatsächlichen Backend-Codes (`backend/includes/auth.php`) zeigte, dass `404` (UID/Pairing noch unbekannt) die Fehlversuchssperre nie auslöst, wodurch Polling in diesem konkreten Zustand sicher ist (research.md R11).
- Q: Soll nach erfolgreicher Verknüpfung automatisch mit dem Upload fortgefahren werden? → A: Ja (FR-006b) — der Nutzer cranked einmal für ein Bild; Pairing ist ein interner Zwischenschritt, kein separates Ziel.
- Q: Der ursprüngliche 400-Fehlerpfad generierte bei falscher PIN automatisch eine NEUE Geräte-PIN und zeigte sie erneut an — macht das Sinn? → A: Nein, das behebt das Problem nicht (der Backend-Hash ist bereits mit der falschen, vom Nutzer eingegebenen PIN fixiert) und verschlimmert es sogar (Auto-Retry mit einer neuen, aber weiterhin nicht zum Backend passenden PIN würde die 3-Versuche-Sperre auslösen). Stattdessen: PIN bleibt unverändert, Auto-Polling stoppt, Nutzer wird angewiesen, auf der Website erneut zu pairen (siehe FR-004b, research.md R12).
- Q: Was, wenn eine bereits (fälschlich) angelegte Verknüpfung mit falscher PIN im Backend nicht mehr korrigierbar ist? → A: Backend-Erweiterung (additiv, Spec 005): Eine UID gilt erst nach dem ersten erfolgreichen Login als "bestätigt" (neue Spalte `confirmed_at`); unbestätigte Verknüpfungen dürfen per erneutem `/pair`-Aufruf überschrieben werden (FR-004b). Sicherheitsrelevant (Auth-Semantik-Änderung an einer als "Complete" markierten Spec) — siehe research.md R12, Security-Review-Nachtrag in Phase 6 (T027) weiterhin offen.

### Session 2026-07-18 (Implementierungsphase — drittes Nutzer-Feedback nach Screenshot)

- Q: Auch nach dem Auto-Polling-Fix (vorherige Session) meldete der Nutzer per Screenshot, dass der Ablauf für ihn nicht nachvollziehbar sei, und stellte die Grundannahme selbst infrage: Muss das Gerät überhaupt auf eine Website-Bestätigung warten, bevor es hochladen darf? → A: Nein — das Bestätigungs-Gate wird entfernt (research.md R13). uid und PIN werden beide ausschließlich vom Gerät erzeugt; das Gerät ruft `POST /pair` jetzt selbst auf (derselbe Endpunkt, den bisher nur das Web-Formular ansprach) und lädt danach im selben Zug hoch, ohne auf eine externe Bestätigung zu warten. Die Website-PIN-Eingabe wird zu einem reinen Ansehen-Schritt NACH dem Upload. FR-003, FR-004, FR-004a, FR-004b, FR-006a, FR-006b, US1 und US2 wurden entsprechend neu gefasst; das gesamte Auto-Polling-Subsystem aus der vorherigen Session (research.md R11) wurde ersatzlos entfernt.
- Q: Derselbe Screenshot zeigte "�" anstelle von Umlauten und dem Halbgeviertstrich in den Sync-Statustexten — warum, und wie beheben? → A: Der Playdate-System-Font deckt diese Zeichen nicht ab (Font-Glyphenlücke, kein Logikfehler). Alle Sync-UI-Texte wurden auf Englisch/ASCII-only umgestellt, konsistent mit dem Rest der App-UI (siehe research.md R14, FR-012-Ergänzung).
- Q: Der Nutzer bemängelte außerdem eine wahrgenommene Verzögerung bei der QR-Code-Generierung ("wieso dauert das so lange?"). Ursache und Fix? → A: Die asynchrone QR-Erzeugung ist SDK-seitig bewusst über mehrere Frames verteilt (research.md R3) und lässt sich nicht beschleunigen, ohne auf die defekte synchrone Variante zurückzugreifen. Sie wurde aber bisher erst NACH dem Netzwerk-Roundtrip gestartet und hängte sich so als zusätzliche sichtbare Wartezeit an; jetzt wird sie bereits bei `startSync()` parallel zum Pairing/Login/Upload angestoßen (research.md R15), wodurch die wahrgenommene Wartezeit in der Praxis meist auf die Netzwerkzeit allein sinkt.
- Q: Der Screenshot zeigte außerdem ein visuell überladenes Overlay (schwebende Box über dem sichtbaren Kreisraster). Wie beheben? → A: Das Ergebnis-Overlay ist jetzt ein echtes Vollbild-Modal (400×240 opak) statt einer kleinen, zentrierten Box — deckt Kreisraster, Statuszeile und Crank-Hinweis vollständig ab, statt sie durchscheinen zu lassen (research.md R13, FR-007a).

---

## Assumptions

- Die Backend-Base-URL ist konfigurierbar (z. B. über Einstellungen im Playdate-Menü).
- Die PIN wird serverseitig als Hash (z. B. bcrypt) gespeichert, nicht im Klartext.
- Offline-Handling: Uploads werden lokal in einer Queue zwischengespeichert und bei nächster Internetverbindung nachgeholt.
- PDI- und JSON-Format entsprechen exakt dem Spec 001 Contract (imageData, imagetable, frames, hashIndex).
- Das Backend unterstützt CORS für Anfragen vom Playdate-Simulator.
- Die 4-stellige PIN bietet ausreichenden Schutz für den beabsichtigten Use Case (private, nicht-kommerzielle Nutzung).
- Da die PIN vom Playdate generiert (nicht vom Nutzer erdacht) und danach dauerhaft lokal gecacht wird, ist keine On-Device-Zifferneingabe per D-Pad nötig; das bestehende Web-PIN-Formular aus Spec 005 (`/pair`) wird unverändert wiederverwendet — bezeichnungstext weist explizit auf die auf dem Playdate angezeigte PIN hin (`backend/public/index.php`). **Umbewertet (2026-07-18, research.md R13)**: Dieses Formular wird inzwischen nur noch für den Website-seitigen Ansehen-Login genutzt, nicht mehr als Upload-Voraussetzung — das Gerät ruft denselben `/pair`-Endpunkt jetzt direkt selbst auf.
- Die Verknüpfungsstatus-Prüfung (FR-006a) kann denselben Mechanismus wie ein regulärer Login (UID + PIN → Autorisierung) nutzen; ein dediziertes Backend-Statusendpoint ist nicht zwingend erforderlich. **Bestätigt (2026-07-18, research.md R13)**: `POST /pair` ist für Nicht-Formular-Aufrufe (kein `web=1`-Feld) bereits JSON-basiert nutzbar — das Gerät verwendet exakt denselben Endpunkt wie das Web-Formular, keine Backend-Änderung nötig.
- Das installierte Playdate SDK (v3.0.6) wurde verifiziert: QR-Code-Generierung existiert als `playdate.graphics.generateQRCode()` / `generateQRCodeSync()` (CoreLibs/qrcode), HTTP-Anfragen als `playdate.network.http` (CoreLibs, seit Playdate OS 2.7). Die in früheren Entwurfsständen angenommenen Namen `playdate.graphics.qrCode` und `playdate.net` existieren nicht und werden nicht verwendet.
- Es existiert kein `Source/tools/`-Verzeichnis im Projekt; ein neues Modul (Arbeitstitel `SyncService.lua`) wird analog zu den bestehenden Room-/Service-Dateien direkt unter `Source/` angelegt.
- Die UID wird vom Playdate selbst (nicht vom SDK) einmalig zufällig generiert und lokal gecacht; sie bleibt über die Lebensdauer der App-Installation gleich, solange der lokale Datastore nicht gelöscht wird (kein Hardware-Bezug, siehe FR-001).
- Backend-Speicher: Pro UID werden bis zu 1000 Images unterstützt (praktisches Limit für erste Version).
- PNG-Rendering: Server verwendet dieselbe Logik wie das Playdate SDK zur Tilemap-Rekonstruktion.

---

## Dependencies

- **Spec 001 (PDI Storage Format)**: PDI- und JSON-Format für Images, imageData-Contract.
- **Spec 002 (Start/Selection Screen)**: Kontextmenü-Integration für Images, Navigation.
- **Spec 003 (Editor Animation Zoom)**: imageData-Struktur mit Frames, die synchronisiert werden muss.
- **Spec 005 (Backend-Service)**: Bereits implementiert (`backend/`). Stellt UID/PIN-Pairing (`/pair`, `/login`), den Deep-Link-Einstieg (`GET /?uid=`), Datei-Storage (`/{UID}/`) und Upload-Endpunkt (`backend/public/upload.php`) bereit. Spec 004 baut überwiegend die Playdate-seitige Gegenstelle zu diesem bestehenden Backend, erfordert aber eine kleine, additive, rückwärtskompatible Erweiterung des Upload-Endpunkts für Update-in-place-Semantik (FR-007b) — kein neues Backend, kein Bruch bestehender Funktionalität.
- **Playdate SDK**: QR-Code-Generierung (`playdate.graphics.generateQRCode`/`generateQRCodeSync`, CoreLibs/qrcode), HTTP-Client (`playdate.network.http`, CoreLibs, ab Playdate OS 2.7), Crank-Messung (`playdate.getCrankChange()`, `playdate.isCrankDocked()`, `playdate.ui.crankIndicator`). Verifiziert gegen installiertes SDK v3.0.6 in der Planungsphase (Constitution Prinzip I).
- **Backend-Infrastruktur**: Webserver mit HTTPS, Dateispeicher, PNG-Rendering-Bibliothek (bereits vorhanden, siehe Spec 005).

---

## Architecture Governance (iSAQB-Preset)

- **Betroffene Architekturaspekte**: Bausteinsicht (neue Bausteine: SyncService auf Playdate, Backend-Service), Laufzeitsicht (Sync- und Upload-Flows), Querschnittskonzepte (Sicherheit/PIN-Authentifizierung, Netzwerkkommunikation).
- **Erwartete Evidenz**: Aktualisierte arc42-Kapitel 5 (Bausteine: SyncService, Backend-Service), 6 (Laufzeitszenarien: Sync, Upload, Rendering), 8 (Querschnitt: Authentifizierung, Netzwerk), 10 (Qualitätsanforderungen: Performance, Sicherheit), 11 (Risiken: Offline-Handling, Speichergrenzen).
- **ADR erforderlich**: Ja — Entscheidungen zu QR-basiertem Pairing (AD-021), geräteseitig generierter PIN-Authentifizierung mit lokalem Caching (AD-022), Backend-Integration (AD-023), Offline-Queue (AD-024), Crank-Geste statt System-Menü als Sync-Einstiegspunkt wegen 3-Slot-Limit (AD-029), Update-in-place bei Re-Sync via client-seitiger Bild-ID (AD-030) — AD-025–028 bereits durch Spec 005 belegt.
- **Sicherheitsrelevante Architektur**: Ja — Datenübertragung (HTTPS), Authentifizierung (PIN), Datenspeicherung (PIN-Hashing, lokales PIN-Caching auf dem Gerät). Sicherheits-Review vor Implementierung erforderlich (Constitution Extension).
- **Risiken**: Offline-Handling (Datenverlust bei Gerätewechsel), PIN-Sicherheit (Brute-Force-Angriffe bei schwacher PIN), Speicherwachstum (viele große Projekte pro UID), lokal gecachte PIN bei Geräteverlust (kein zusätzlicher Schutz über die 4-stellige PIN hinaus — akzeptiert gemäß Assumptions).
- **Constitution-Status**: Erledigt — Constitution v1.2.0 (2026-07-18) enthält jetzt den expliziten Randbedingungs-Punkt "Netzwerk (Sync-Ausnahme)", der `playdate.network.http`-Nutzung für dieses Feature zulässt, sofern der Kern-Editor offline nutzbar bleibt. Kein Blocker mehr vor `/speckit-plan`.
