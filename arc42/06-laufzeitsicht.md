# 6. Laufzeitsicht

Die Diagramme zeigen bewusst nur die architekturrelevanten Interaktionen zwischen den Bausteinen; Schritt-Details stehen in den nummerierten Listen darunter.

## 6.1 Szenario: Spielstart bis Editor

```mermaid
sequenceDiagram
    actor N as Nutzer
    participant T as TitleRoom
    participant S as SelectionRoom
    participant E as EditorRoom
    participant C as ImageStore/Codec

    N->>T: A
    T->>S: switchRoom
    S->>C: listImages / Previews
    N->>S: A auf Bild
    S->>E: setImage(id) + switchRoom
    E->>C: Load-Coroutine (RoomOperation)
    C-->>E: imageData (frameweise Phasen)
    Note over E: Tilemap zeigt Frame 1
```

1. Runtime startet und importiert alle Rooms.
2. main.lua setzt TitleRoom als currentRoom und registriert Input-Handler.
3. A in TitleRoom wechselt zum SelectionRoom (Einbahnstrasse: kein Weg zurueck zum Splash).
4. Nutzer waehlt ein bestehendes Bild oder erstellt ein neues (A auf Neu-Eintrag oder Systemmenue; Namenseingabe ueber das SDK-Keyboard, Commit/Abbruch via keyboardWillHideCallback).
5. SelectionRoom ruft EditorRoom:setImage(id) und wechselt zum EditorRoom.
6. entered() startet die Load-Operation (ImageStoreCodec.newLoadOperation) als RoomOperation mit loadingBar; Phasen: Frames lesen, Bilddaten lesen, Slicing, Validierung.
7. Nach Erfolg steht imageData (imagetable, frames, hashIndex) bereit; die Tilemap zeigt Frame 1, Cursor und Frame-Anzeige sind sichtbar.
8. Bei Ladefehlern kehrt der EditorRoom ohne Absturz zum SelectionRoom zurueck.

Ergebnis: Der Editor ist direkt nach der Bildauswahl aktiv — ohne zwischengeschaltete Room-Auswahl (FR-001).

## 6.2 Szenario: Tileweise malen im EditorRoom

1. Nutzer bewegt den Cursor mit dem D-Pad (Halten wiederholt via SDK-keyRepeatTimer).
2. Der A-Druck startet einen Strich und legt dessen Malwert fest: Zelle zeigt bereits das aktive Zeichen-Tile (bzw. Schwarz ohne Auswahl) -> der Strich malt Weiss (Radierer); sonst malt er das Zeichen-Tile (bzw. Schwarz).
3. Solange A gehalten bleibt, malt jede Cursor-Bewegung die neu betretene Zelle mit demselben Strichwert; A-Release beendet den Strich.
4. Kurzes B (Release ohne Zoom-Ticks) uebernimmt das Tile unter dem Cursor als aktives Zeichen-Tile (Pipette); Pipette auf Weiss waehlt ab.
5. Jede Mutation schreibt frames[currentFrame] und aktualisiert die Tilemap per setTileAtPosition; needsRedraw steuert das Zeichnen.

Ergebnis: Der Frame-Zustand ist visuell aktuell und liegt vollstaendig in imageData vor.

## 6.3 Szenario: Animationsframes per Crank

1. Crank vorwaerts (eine Rastung, getCrankTicks(4)) wechselt zum naechsten Frame; existiert keiner und sind < 12 vorhanden, entsteht er als flache Kopie des aktuellen.
2. Crank rueckwaerts wechselt einen Frame zurueck; auf Frame 1 rotiert die Navigation zum letzten existierenden Frame (rueckwaerts entstehen nie Frames).
3. Bei 12 Frames rotiert vorwaerts zu Frame 1.
4. Mehrere Rastungen pro Update werden sequenziell abgearbeitet; jede Kopie basiert auf ihrem direkten Vorgaenger.
5. Frame-Wechsel = tilemap:setTiles(frames[f], 25) + Redraw; die Bauchbinde zeigt "Frame n/m".
6. "delete frame" im Systemmenue entfernt den aktiven Frame (Nachruecker wird aktiv); beim letzten verbliebenen Frame wirkungslos.

Ergebnis: Bis zu 12 Frames sind vollstaendig per Crank erstell-, durchlauf- und loeschbar (FR-006..FR-008a).

## 6.4 Szenario: Zoomkette EditorRoom -> ZoomRoom -> PixelRoom

```mermaid
sequenceDiagram
    participant E as EditorRoom
    participant Z as ZoomRoom
    participant P as PixelRoom

    E->>Z: setFromEditorContext (3x3-Slots + Raster)
    Z->>P: setCurrentTile (Arbeitsbild, 16x16)
    P-->>Z: setNewTile / updateExistingTile
    Z-->>E: applyTileEdits (nur geaenderte Slots)
    Note over E: Dedup via hashIndex + Pixelvergleich
```

1. Im EditorRoom wird B gehalten und der Crank-Trigger erreicht (Tick-Akkumulation); waehrend B gehalten ist, loest der Crank keine Frame-Wechsel aus.
2. EditorRoom baut den 3x3-Kontext um den Cursor (Slots mit frameIndexPos/originalIndex/originalImage, 24x24-gridState per 2x2-Blockauslese, showGrid, imageData-Referenz) und uebergibt ihn an ZoomRoom.
3. ZoomRoom rendert das 24x24-Malraster; ein Malstrich setzt genau einen 2x2-Pixelblock; out-of-bounds-Slots sind nicht editierbar.
4. B+Crank vorwaerts oeffnet den PixelRoom mit dem Arbeitsbild des Cursor-Slots in echten 16x16 Pixeln; ein Malstrich setzt genau 1 Pixel.
5. PixelRoom-Rueckgabe: Standardpfad als bearbeitetes Tile (setNewTile) oder "All Similar" in-place in die Imagetable (updateExistingTile, wirkt auf alle Verwendungen ueber alle Frames).
6. B+Crank rueckwaerts im ZoomRoom committet nur tatsaechlich geaenderte Slots an EditorRoom:applyTileEdits (Dedup: hashIndex-Treffer + Pixelvergleich oder neues Tile) und kehrt zurueck; geschrieben wird ausschliesslich der aktive Frame.

Ergebnis: Pixelgenaue Aenderungen ueber alle drei Stufen; unveraenderte Slots erzeugen keine neuen Tiles (Z-03).

## 6.5 Szenario: Autosave beim Verlassen

```mermaid
sequenceDiagram
    actor N as Nutzer
    participant E as EditorRoom
    participant O as RoomOperation
    participant C as ImageStoreCodec
    participant S as SelectionRoom

    N->>E: Systemmenue "save + exit"
    E->>O: start(Save-Coroutine)
    loop pro Frame in update()
        O->>C: coroutine.resume
        C-->>O: Phase (Dedup … Index)
    end
    O-->>E: onComplete
    E->>S: switchRoom
    S->>S: entered(): Previews neu laden
```

1. Nutzer waehlt im Systemmenue des EditorRoom "save + exit".
2. EditorRoom startet eine RoomOperation mit ImageStoreCodec.newSaveOperation; Eingaben (inkl. Menueaktionen) sind blockiert.
3. Phasen: Dedup, Sheet, Frames, Bilddaten, Preview, Index (Index als letzte Phase, C-06); loadingBar zeigt Titel und Phase.
4. Nach Erfolg wechselt der EditorRoom zum SelectionRoom; dessen entered() laedt die Previews neu (aktualisiertes Thumbnail).
5. Bei Fehlern bleibt der Editor bedienbar und zeigt einen Fehlerstatus; kein Datenverlust im Speicher.
6. Zusaetzlich speichert playdate.gameWillTerminate() das offene Bild; aktive Zoomstufen committen zuvor ihren Slot-Zustand (PixelRoom -> ZoomRoom -> EditorRoom).

Ergebnis: Verlassen und Beenden speichern automatisch; der Auswahlscreen zeigt den aktuellen Stand (FR-014).

## 6.6 Fehler-/Ausnahmeszenarien

- Fehlende/ungueltige Save-Dateien beim Laden: Load-Operation endet defensiv; Rueckkehr zum SelectionRoom ohne Absturz.
- Ungueltige Tile-Referenzen in frames.json: Validierung faellt auf das Weiss-Tile zurueck.
- Fehler in laufender RoomOperation: Overlay zeigt Fehlerstatus; der Room raeumt seine Operationsreferenz auf und bleibt stabil bedienbar.
- Keyboard-Abbruch bei Bild-Anlage im SelectionRoom: keine Neuerstellung, Grid wird sauber aktualisiert (keyboardWillHideCallback(false)).
- Namenskollision bei der Anlage: automatischer Suffix-Retry (name-1, name-2, …) statt Fehlermeldung.
- Eingaben waehrend laufender Save-/Load-Operation: blockiert (inkl. Systemmenue-Aktionen des EditorRoom).
- Defekte frames.json beim Laden: Frames falscher Laenge werden verworfen (ohne Luecken in der Frame-Liste); sind alle Frames defekt, wird ein weisser Leerframe erzeugt — der Editor setzt frames[1] voraus.
- Navigation im SelectionRoom ausserhalb vorhandener Eintraege: Selektion klemmt am letzten Eintrag (kein Fehler, kein Leerlauf).

## 6.7 Szenario: Offline-Import PNG (Tools/Importer, historisch)

Das Browser-Tool importiert PNGs in Pulp-JSON-Dokumente (v0.2-Format) und ist mit dem v0.3.0-Speicherformat nicht kompatibel (R-14). Der Ablauf bleibt dokumentiert, weil das Tool weiterhin im Repository liegt: JSON laden -> PNG normalisieren (200x120) -> 8x8-Slicing + FNV-1a-Dedupe -> neuer Room -> Export als neue Datei.

---

## 6.8 Backend-Szenarien (Hans Dither Sync)

### 6.8.1 Szenario: UID-Verknüpfung (Pairing)

```mermaid
sequenceDiagram
    actor U as Nutzer (Browser)
    participant B as Backend-Service
    participant A as Auth-Modul
    participant D as Datenbank

    U->>B: GET / (UID-Eingabe)
    U->>B: GET /pair?uid=test-device-001
    B->>D: SELECT uid FROM users WHERE uid = ?
    D-->>B: Kein Ergebnis
    B->>U: 200 OK (Pairing-Formular)
    U->>B: POST /pair (uid, pin=1234)
    B->>A: pair(uid, pin)
    A->>D: INSERT INTO users (uid, pin_hash, ...)
    D-->>A: Erfolg
    A-->>B: {status: "success", uid: "..."}
    B->>U: 201 Created
```

1. Nutzer gibt UID in das Formular auf der Startseite ein
2. Backend prüft, ob UID bereits existiert
3. Wenn nicht: Pairing-Formular mit PIN-Eingabe wird angezeigt
4. Nutzer gibt 4-stellige PIN ein
5. Backend: PIN wird mit bcrypt gehasht und in DB gespeichert
6. Erfolgmeldung wird zurückgegeben

**Ergebnis:** UID ist mit PIN verknüpft, Nutzer kann sich anmelden.

### 6.8.2 Szenario: Login und Images-Liste

```mermaid
sequenceDiagram
    actor U as Nutzer (Browser)
    participant B as Backend-Service
    participant A as Auth-Modul
    participant D as Datenbank
    participant I as Images-Modul

    U->>B: GET / (UID-Eingabe: test-device-001)
    B->>D: SELECT uid FROM users WHERE uid = ?
    D-->>B: Ergebnis gefunden
    B->>U: 302 Redirect /login?uid=test-device-001
    U->>B: GET /login?uid=test-device-001
    U->>B: POST /login (uid, pin=1234)
    B->>A: login(uid, pin)
    A->>D: SELECT pin_hash, failed_attempts FROM users WHERE uid = ?
    D-->>A: pin_hash
    A->>A: password_verify(pin, pin_hash)
    alt PIN korrekt
        A->>D: INSERT INTO sessions (token, uid, expires_at)
        A->>D: UPDATE users SET failed_attempts = 0
        A-->>B: {status: "success", session_token: "...", uid: "..."}
        B->>U: 200 OK
        U->>B: GET /images?uid=...&token=...
        B->>A: validateToken(token)
        A->>D: SELECT token, uid FROM sessions WHERE token = ?
        D-->>A: Session-Daten
        A-->>B: {uid: "..."}
        B->>I: getAllImages(uid)
        I->>D: SELECT * FROM images WHERE uid = ?
        D-->>I: Images-Liste
        I-->>B: Images-Daten
        B->>U: 200 OK (Images-Liste als HTML/JSON)
    else PIN falsch
        A->>D: UPDATE users SET failed_attempts = failed_attempts + 1
        alt failed_attempts >= 3
            A->>D: UPDATE users SET locked_until = NOW() + INTERVAL 5 MINUTE
            A-->>B: {error: "Zu viele Fehlversuche", http_code: 429}
            B->>U: 429 Too Many Requests
        else
            A-->>B: {error: "UID oder PIN ungültig", http_code: 400}
            B->>U: 400 Bad Request
        end
    end
```

1. Nutzer gibt bestehende UID ein
2. Backend erkennt UID und leitet zu Login weiter
3. Nutzer gibt PIN ein
4. Backend verifiziert PIN mit bcrypt
5. Bei Erfolg: Session-Token wird generiert und gespeichert
6. Nutzer wird zur Images-Liste weitergeleitet
7. Session-Token wird für alle folgenden Requests verwendet

**Ergebnis:** Nutzer ist authentifiziert und sieht seine Images.

### 6.8.3 Szenario: PDI + JSON Upload

```mermaid
sequenceDiagram
    actor U as Nutzer (Browser)
    participant B as Backend-Service
    participant A as Auth-Modul
    participant V as Validation-Modul
    participant UH as Upload-Handler
    participant D as Datenbank
    participant F as Dateisystem

    U->>B: POST /upload.php (pdi, json, uid, token)
    B->>A: validateToken(token)
    A-->>B: {uid: "..."}
    B->>UH: handleUpload(uid, pdi_file, json_file)
    UH->>V: validateUploadedFile(pdi_file)
    V->>V: Prüfe Magic Bytes (PDI\x00) + Header
    V-->>UH: {valid: true}
    UH->>V: validateUploadedFile(json_file)
    V->>V: json_decode()
    V-->>UH: {valid: true}
    UH->>F: mkdir -p /uploads/{uid}
    UH->>F: move_uploaded_file(pdi, /uploads/{uid}/{uuid}.pdi)
    UH->>F: move_uploaded_file(json, /uploads/{uid}/{uuid}.json)
    UH->>D: INSERT INTO images (id, uid, pdi_path, json_path)
    D-->>UH: Erfolg
    UH-->>B: {status: "success", image_id: "..."}
    B->>U: 201 Created
```

1. Nutzer wählt PDI- und JSON-Datei im Upload-Formular aus
2. Backend prüft Session-Token
3. PDI-Datei wird validiert: Magic Bytes + Header-Parse
4. JSON-Datei wird validiert: json_decode() muss erfolgreich sein
5. Dateien werden unter `/uploads/{UID}/{uuid}.pdi` und `.json` gespeichert
6. DB-Eintrag wird erstellt
7. Erfolgmeldung mit Image-ID wird zurückgegeben

**Ergebnis:** PDI + JSON sind hochgeladen und in DB registriert.

### 6.8.4 Szenario: PNG Download (on-demand Rendering)

```mermaid
sequenceDiagram
    actor U as Nutzer (Browser)
    participant B as Backend-Service
    participant A as Auth-Modul
    participant UH as Upload-Handler
    participant R as Renderer
    participant D as Datenbank
    participant F as Dateisystem

    U->>B: GET /download/png/{image_id}?token=...
    B->>A: validateToken(token)
    A-->>B: {uid: "..."}
    B->>UH: getImage(image_id, uid)
    UH->>D: SELECT * FROM images WHERE id = ? AND uid = ?
    D-->>UH: Image-Daten
    UH-->>B: Image-Daten
    alt png_path existiert
        B->>F: readfile(png_path)
        F-->>B: PNG-Daten
        B->>U: 200 OK (image/png)
    else png_path ist NULL
        B->>R: renderToPng(image_id, uid)
        R->>UH: getImage(image_id, uid)
        UH-->>R: Image-Daten
        R->>F: loadPdiFile(pdi_path)
        F-->>R: PDI-Daten
        R->>F: loadJsonFile(json_path)
        F-->>R: JSON-Daten
        R->>R: generatePng(pdi_data, json_data)
        R->>F: imagepng() nach /uploads/{uid}/{uuid}.png
        R->>UH: savePngPath(image_id, png_path)
        UH->>D: UPDATE images SET png_path = ? WHERE id = ?
        D-->>UH: Erfolg
        R-->>B: png_path
        B->>F: readfile(png_path)
        F-->>B: PNG-Daten
        B->>U: 200 OK (image/png)
    end
```

1. Nutzer klickt auf PNG-Download-Link
2. Backend prüft Session-Token und Berechtigung
3. Falls PNG noch nicht existiert: On-demand Rendering
4. PDI-Datei wird geparst (Magic Bytes, Header, Pixel-Daten)
5. JSON-Datei wird geparst (Tilemap-Daten)
6. PNG wird mit GD-Bibliothek generiert (400x240, 1-Bit)
7. PNG wird gespeichert und Pfad in DB aktualisiert
8. PNG wird an Nutzer ausgeliefert

**Ergebnis:** Nutzer erhält PNG-Datei (generiert on-demand beim ersten Zugriff).
