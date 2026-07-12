# Feature Specification: Backend-Synchronisation für Hans Dither

**Feature Branch**: `feature/0.4`

**Created**: 2026-07-12

**Status**: Draft

**Input**: User description: "Synchronisation zwischen Backend und Playdate: Export von auf dem Playdate erstellten Hans-Dither-Zeichnungen an ein Web-Backend, dort Anzeige und Download als PDI+JSON oder gerendertem PNG. QR-basiertes Pairing mit 4-stelliger PIN-Absicherung, Upload aller Projekte inkl. PDI und JSON, Backend rendert Tilemap zu PNG."

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Playdate mit Backend verknüpfen (Priority: P1)

Als Nutzer möchte ich mein Playdate-Gerät über einen QR-Code mit meinem Backend-Konto verknüpfen, um meine Zeichnungen später exportieren zu können. Ich rufe den Sync aus dem Kontextmenü eines Bildes auf. Da noch keine Verknüpfung existiert, wird ein QR-Code mit der Backend-Adresse und meiner Playdate-UID angezeigt. Nach dem Scannen des Codes auf einem anderen Gerät lege ich eine 4-stellige PIN fest, die zukünftige Uploads autorisiert.

**Why this priority**: Ohne Verknüpfung kann kein Upload erfolgen. Dies ist die Grundlage für den gesamten Sync-Workflow.

**Independent Test**: Einzige Abhängigkeit ist das Playdate SDK (QR-Code-Generierung). Der QR-Code muss die Backend-URL + UID enthalten und kann mit jedem QR-Scanner gelesen werden. Die PIN-Eingabe muss validiert werden (genau 4 Ziffern).

**Acceptance Scenarios**:

1. **Given** Playdate ist nicht mit einem Backend verknüpft, **When** Nutzer Sync aus dem Kontextmenü wählt, **Then** wird ein QR-Code mit Backend-URL und Playdate-UID angezeigt.
2. **Given** QR-Code wird auf einem anderen Gerät gescannt, **When** Nutzer die Backend-URL öffnet, **Then** wird die Playdate-UID erkannt und zur PIN-Eingabe aufgefordert.
3. **Given** Backend zeigt PIN-Eingabefeld, **When** Nutzer eine 4-stellige Zahl eingibt und bestätigt, **Then** wird die Verknüpfung gespeichert und das Playdate als verknüpft markiert.
4. **Given** Verknüpfung erfolgreich, **When** Nutzer Sync-Menü öffnet, **Then** wird der Verknüpfungsstatus (verknüpft mit Backend-URL) angezeigt.

---

### User Story 2 - Zeichnung zum Backend hochladen (Priority: P1)

Als Nutzer möchte ich meine auf dem Playdate erstellten Zeichnungen (Images) mit allen Frames an mein Backend hochladen, um sie dort anzeigen und herunterladen zu können. Ich wähle den Upload aus dem Kontextmenü aus, werde zur PIN-Eingabe aufgefordert und bestätige den Upload. Alle Projekte (PDI-Datei + frames.json) werden übertragen.

**Why this priority**: Der Upload ist der Kern des Sync-Features. Ohne ihn können Nutzer ihre Kreationen nicht exportieren.

**Independent Test**: Setzt US1 voraus (Verknüpfung muss existieren). Der Upload kann mit Mock-Backend getestet werden, das die empfangenen Dateien validiert (PDI-Format aus Spec 001, JSON-Struktur aus Spec 001).

**Acceptance Scenarios**:

1. **Given** Playdate ist mit Backend verknüpft, **When** Nutzer Upload aus dem Kontextmenü wählt, **Then** wird PIN-Eingabefeld angezeigt.
2. **Given** Nutzer gibt korrekte PIN ein, **When** Upload bestätigt wird, **Then** werden alle Images (PDI + frames.json) an das Backend unter `/{UID}` gesendet.
3. **Given** Upload läuft, **When** Verbindung unterbrochen wird, **Then** wird der Upload angehalten und kann später fortgesetzt werden.
4. **Given** Upload erfolgreich, **When** Backend-UI aufgerufen wird, **Then** sind die neuen Images in der Liste sichtbar.
5. **Given** Nutzer gibt falsche PIN ein (3 Versuche), **When** Upload versucht wird, **Then** wird Fehler "Falsche PIN" angezeigt und Upload abgebrochen.

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
- Was passiert bei falscher PIN-Eingabe beim Upload? → Nach 3 Fehlversuchen wird der Upload für 5 Minuten gesperrt.
- Was passiert, wenn die UID bereits verknüpft ist? → Existing Verknüpfung wird verwendet; Nutzer kann im Sync-Menü die Verknüpfung zurücksetzen.
- Was passiert, wenn das Backend nicht erreichbar ist? → Fehler "Backend nicht erreichbar" wird angezeigt; Upload kann später wiederholt werden.
- Was passiert bei beschädigter PDI-Datei? → Backend versucht trotzdem zu rendern; bei Fehler wird PNG nicht generiert und im UI als "fehlerhaft" markiert.
- Was passiert, wenn mehrere Playdate-Geräte dieselbe UID haben? → Jedes Gerät bekommt eine eigene UID vom Playdate SDK; dieser Fall sollte nicht auftreten.
- Was passiert mit sehr großen Projekten (>100 Frames)? → Upload wird segmentiert; Backend zeigt Fortschritt an.
- Was passiert, wenn der Speicherplatz im Backend voll ist? → Backend lehnt neue Uploads ab und zeigt "Speicher voll" im UI.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Jedes Playdate-Gerät MUSS eine eindeutige Geräte-ID (UID) besitzen, die vom Playdate SDK bereitgestellt wird.
- **FR-002**: Das Playdate MUSS einen Sync-Eintrag im Kontextmenü der Images anbieten.
- **FR-003**: Bei nicht verknüpftem Gerät MUSS der Sync-Eintrag einen QR-Code anzeigen, der die Backend-URL und die Geräte-UID enthält.
- **FR-004**: Bei erstem Aufruf über den QR-Code MUSS das Backend die Eingabe einer 4-stelligen PIN erfordern.
- **FR-005**: Die PIN MUSS serverseitig gespeichert werden (gehasht, nicht im Klartext) und mit der UID verknüpft sein.
- **FR-006**: Beim Upload MUSS das Playdate die PIN erneut abfragen, um den Vorgang zu autorisieren.
- **FR-007**: Der Upload MUSS alle Images des Geräts umfassen, jeweils als PDI-Datei + frames.json (gemäß Spec 001 Contract).
- **FR-008**: Das Backend MUSS die hochgeladenen Dateien unter dem Pfad `/{UID}/` speichern.
- **FR-009**: Das Backend MUSS in der Lage sein, PDI-Dateien zu öffnen, die frames.json zu lesen, die Tilemap zu rekonstruieren und als PNG (400×240, 1-Bit) zu rendern.
- **FR-010**: Das Backend-UI MUSS alle Images einer UID in einer liste mit Vorschaubildern (PNG) anzeigen.
- **FR-011**: Das Backend-UI MUSS für jedes Image separate Download-Optionen für PDI, frames.json und PNG anbieten.
- **FR-012**: Das Playdate MUSS den Verknüpfungsstatus (verknüpft/nicht verknüpft) anzeigen.
- **FR-013**: Das Playdate MUSS die Möglichkeit bieten, die Backend-Verknüpfung zurückzusetzen.
- **FR-014**: Das Backend MUSS Uploads ohne gültige PIN ablehnen.
- **FR-015**: Das Playdate MUSS Upload-Fortschritt anzeigen (z. B. "Uploading X/Y images").

### Key Entities

- **Playdate Device**: Physisches Gerät mit eindeutiger UID (vom Playdate SDK). Enthält Images (Projekte).
- **Device UID**: Eindeutige Kennung des Playdate-Geräts (String, z. B. "pd-abc123def456").
- **Backend Service**: Web-Dienst, der Uploads annimmt, speichert und PNGs rendert. Stellt UI unter einer Base-URL bereit.
- **PIN**: 4-stellige numerische Authentifizierung (0000-9999) für die Verknüpfung zwischen Gerät und Backend.
- **QR Code**: Enthält Backend-Base-URL + Device UID (z. B. `https://backend.example.com/pair?uid=pd-abc123def456`).
- **Image**: Hans Dither Projekt, bestehend aus PDI-Datei (Imagetable) + frames.json (Frame-Daten, gemäß Spec 001).
- **Rendered PNG**: Serverseitig generiertes Bild (400×240 Pixel, 1-Bit) aus PDI + frames.json.

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

## Assumptions

- Die Backend-Base-URL ist konfigurierbar (z. B. über Einstellungen im Playdate-Menü).
- Die PIN wird serverseitig als Hash (z. B. bcrypt) gespeichert, nicht im Klartext.
- Offline-Handling: Uploads werden lokal in einer Queue zwischengespeichert und bei nächster Internetverbindung nachgeholt.
- PDI- und JSON-Format entsprechen exakt dem Spec 001 Contract (imageData, imagetable, frames, hashIndex).
- Das Backend unterstützt CORS für Anfragen vom Playdate-Simulator.
- Die 4-stellige PIN bietet ausreichenden Schutz für den beabsichtigten Use Case (private, nicht-kommerzielle Nutzung).
- Das Playdate SDK (Version aktuell) bietet ausreichende Funktionen für QR-Code-Generierung und HTTP-Anfragen.
- Bestehende "Tools" im Projekt (vermutlich `Source/tools/` oder ähnliche Hilfsmodule) können als technische Basis für HTTP- und QR-Funktionen dienen.
- Die UID des Playdate wird vom SDK einmalig generiert und bleibt über die Lebensdauer des Geräts gleich.
- Backend-Speicher: Pro UID werden bis zu 1000 Images unterstützt (praktisches Limit für erste Version).
- PNG-Rendering: Server verwendet dieselbe Logik wie das Playdate SDK zur Tilemap-Rekonstruktion.

---

## Dependencies

- **Spec 001 (PDI Storage Format)**: PDI- und JSON-Format für Images, imageData-Contract.
- **Spec 002 (Start/Selection Screen)**: Kontextmenü-Integration für Images, Navigation.
- **Spec 003 (Editor Animation Zoom)**: imageData-Struktur mit Frames, die synchronisiert werden muss.
- **Playdate SDK**: QR-Code-Generierung (`playdate.graphics.qrCode`), HTTP-Client (`playdate.net`).
- **Backend-Infrastruktur**: Webserver mit HTTPS, Dateispeicher, PNG-Rendering-Bibliothek.

---

## Architecture Governance (iSAQB-Preset)

- **Betroffene Architekturaspekte**: Bausteinsicht (neue Bausteine: SyncService auf Playdate, Backend-Service), Laufzeitsicht (Sync- und Upload-Flows), Querschnittskonzepte (Sicherheit/PIN-Authentifizierung, Netzwerkkommunikation).
- **Erwartete Evidenz**: Aktualisierte arc42-Kapitel 5 (Bausteine: SyncService, Backend-Service), 6 (Laufzeitszenarien: Sync, Upload, Rendering), 8 (Querschnitt: Authentifizierung, Netzwerk), 10 (Qualitätsanforderungen: Performance, Sicherheit), 11 (Risiken: Offline-Handling, Speichergrenzen).
- **ADR erforderlich**: Ja — Entscheidungen zu QR-basiertem Pairing (AD-021), PIN-basierter Authentifizierung (AD-022), Backend-Integration (AD-023), Offline-Queue (AD-024).
- **Sicherheitsrelevante Architektur**: Ja — Datenübertragung (HTTPS), Authentifizierung (PIN), Datenspeicherung (PIN-Hashing). Sicherheits-Review vor Implementierung erforderlich (Constitution Extension).
- **Risiken**: Offline-Handling (Datenverlust bei Gerätewechsel), PIN-Sicherheit (Brute-Force-Angriffe bei schwacher PIN), Speicherwachstum ( viele große Projekte pro UID).
