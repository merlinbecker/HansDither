# 8. Querschnittliche Konzepte

## 8.1 Input- und Navigationskonzept

> Die vollstaendige, tastengenaue Bedienreferenz je Room (jede Taste, jede
> B-/Crank-Kombination, die Systemmenue-Eintraege und die Schuettelgeste)
> steht in `STEUERUNG.md` im Projektwurzelverzeichnis. Dieser Abschnitt
> beschreibt das dahinterliegende Konzept, nicht jede Einzelbindung.

- Jeder Room liefert einen eigenen Input-Handler.
- Ein zentraler switchRoom-Mechanismus tauscht Handler atomar aus.
- Bedienmuster im Editor (AD-019; Tile-View-Steuerung seit Spec 010 durch **AD-042** ueberarbeitet):
  - D-Pad bewegt den Brush-Cursor tileweise; Halten wiederholt (SDK-keyRepeatTimer). Ist B gehalten, wird der Cursor eingefroren.
  - A malt als Strich: Der A-Druck bestimmt den Malwert — steht der Cursor auf dem aktiven Zeichen-Tile (bzw. Schwarz), malt der Strich Weiss (Radierer), sonst das Zeichen-Tile (bzw. Schwarz). Solange A gehalten wird, malen Cursor-Bewegungen denselben Wert weiter; Zellen werden nicht einzeln invertiert. Gleiche Semantik in allen drei Editierstufen (Editor-, Zoom-, PixelRoom).
  - B (kurz, ohne D-Pad/Kurbel dazwischen) ist die Pipette: Tile an der Cursor-Position wird aktives Zeichen-Tile; Pipette auf Weiss waehlt ab. Sie feuert bei B-Release, sofern B nicht fuer Zoom (`bUsedForZoom`) oder Ebene/Frame (`bNavConsumed`) genutzt wurde, und zeigt kurz "Tile N picked" in der Bauchbinde.
  - **B halten + Hoch/Runter** wechselt die aktive Ebene (+1/-1, Wrap 1..3); **B halten + Links/Rechts** wechselt den Frame (Rechts am letzten Frame = neuer Frame als tiefe Kopie).
  - **Kurbel ohne Modifier** oeffnet im Tile View einen **Tile-Picker** ueber die tatsaechlich referenzierten Kacheln. **Seit Spec 010, 10. Runde:** der Picker erscheint erst nach einer **vollen Umdrehung** (`pickerArmDegrees`, vorzeichenbehaftet, `|·| ≥ 360°`, beliebige Richtung — Vor-/Zurueck-Ruetteln hebt sich gegen 0 auf und oeffnet nichts; die Oeffnungsdrehung waehlt keine Kachel). Ist er offen, je ~30° Netto-Drehung eine Kachel weiter, Wrap am Ende; das Overlay blendet ~1,5 s nach der letzten Drehung aus, danach ist wieder eine volle Umdrehung noetig. Ein globaler „walk-the-cursor“-Tile-Picker existiert weiterhin nicht.
  - **B halten + Crank** wechselt die Zoomstufe bzw. oeffnet die Frame-Verwaltung (Tick-Akkumulation, `getCrankTicks(4)`); waehrend B gehalten ist, laeuft der Tile-Picker nicht. An den Enden der Zoomkette (Editor vorwaerts→Zoom, PixelRoom vorwaerts) bzw. rueckwaerts im Editor gilt die Frame-Verwaltungs-Geste. CR-01 **praezisiert (AD-047)**: pro `update()` **steuert** genau eine Crank-Lese-API die Logik (B-Zweig `getCrankTicks(4)`, Ohne-B-Zweig `getCrankChange()`) — **beide werden aber jeden Frame gelesen** und der nicht genutzte Wert verworfen, sonst entlaedt der zustandsbehaftete Tick-Zaehler einen Rueckstau beim ersten B-Frame als Phantom-Zoom.
  - **Schuetteln (links-rechts)** oeffnet seit Spec 011 den Undo-Dialog (AD-044..046). Die Geste ist in Tile-, Zoom- und Pixel-View aktiv, **nicht** in der FrameManagementView (dort ist B durch die Halte-Geste belegt). Erkennung: eigener `ShakeDetector` auf `playdate.readAccelerometer` (kein SDK-Shake-Ereignis).

- **Voll-modale Dialoge** (Spec 011, AD-046; Muster aus `SelectionRoom.confirmingDelete`): Solange `UndoPrompt.isOpen()` gilt, prueft **jeder** Input-Callback und **jeder** `update()`-Crank-Block der drei Editier-Views zuerst diesen Zustand — A → `UndoPrompt.handleA()`, B → `UndoPrompt.handleB()`, alles andere (D-Pad, Crank, A-Strich) wird geschluckt, keine Room-Transition. Ein zweites Schuetteln bei offenem Dialog ist folgenlos (`open` ist No-op). Der Dialog wird als letztes in `draw()` gezeichnet und liegt damit ueber Raster/Cursor/Bauchbinde. `undoRequest` committet offene Zoom-/Pixel-Edits **vor** der Label-Wahl, damit Dialogtext und „(A) Ja"-Wirkung zusammenpassen; der Dialog erscheint dann im Tile View.

- **Accelerometer-Lebenszyklus** (Spec 011): `playdate.startAccelerometer()` in `entered()` der drei Editier-Views (idempotent), `playdate.stopAccelerometer()` beim Ruecksprung zu `SelectionRoom` (EditorRoom „no image"-Zweig + Load-/Save-Callbacks). Nicht aktiv im Title-/Selection-Screen und in der FrameManagementView — Batterieschonung und kein Polling-Overhead im muehsam fluessig gemachten Zoom-View (Spec 008). Gelesen wird der Sensor genau einmal je `update()`.

- Der Editing-Flow ist gestuft (genau drei Zoomstufen, FR-009):
  - EditorRoom (25x15-Tilemap, 16x16-Tiles),
  - ZoomRoom (3x3-Tile-Kontext als 24x24-Malraster, 2x2-Pixelbloecke),
  - PixelRoom (Einzeltile mit echten 16x16 Pixeln).

Nutzen: klare mentale Modelle ohne Moduswechsel — der fruehere EditMode-Automat samt B-Long-Press (AD-014) ist ersatzlos entfallen. Seit AD-042 (Hardware-Test): „ein Druck = ein Schritt“ fuer Ebene und Frame (B + D-Pad), die sonst brachliegende Kurbel dient der Kachelwahl; B + Crank (Zoom / Frame-Verwaltung) bleibt unveraendert.

## 8.2 Rendering- und Redraw-Konzept

- Rendering ist zustandsbasiert ueber needsRedraw ("dirty flag"): Raeume zeichnen nur nach Zustandsaenderung neu, der Framebuffer bleibt sonst stehen.
- Ausnahme SelectionRoom bei offenem SDK-Keyboard: solange keyboard.isVisible() gilt, wird jeder Frame gezeichnet (Keyboard-Animation + live mitlaufende Eingabezeile).
- EditorRoom zeichnet die Tilemap direkt bei (0,0) auf die volle 400x240-Flaeche — Daten- und Anzeigeaufloesung fallen zusammen (AD-016), ein Offscreen-Buffer existiert nicht mehr. Cursor (PencilCursor), optionales Grid-Overlay und Bauchbinde liegen darueber.
- Frame-Wechsel sind reine Index-Operationen: tilemap:setTiles(frames[f], 25) plus Redraw; im Update-Pfad werden keine Bilder kopiert.
- ZoomRoom zeichnet Zellinhalt plus Tilegrenzen; gestrichelte Zellgrenzen folgen dem showGrid-Status des Editors. PixelRoom rendert sein 16x16-Raster ueber gridview.
- loadingBar und Bauchbinde nutzen die native Aufloesung fuer scharfe Text- und UI-Darstellung.
- Timer-Updates (keyRepeat, Richtungshalten) laufen zentral im Update-Loop des jeweiligen Rooms.
- Zeitbasierte Sichtbarkeits-Uebergaenge (z. B. statusMessage-Timeout, seit Spec 006 auch die Bauchbinden-Inaktivitaets-Anzeige) muessen ihren Uebergang selbst per Zeitvergleich in update() erkennen und dabei EXPLIZIT needsRedraw = true setzen, sonst zeichnet draw() (das nur bei needsRedraw == true laeuft) die Aenderung nie sichtbar nach — reiner Zeitablauf ohne eine andere, zustandsaendernde Eingabe loest sonst keinen Redraw aus. Beide bestehenden Faelle folgen demselben Muster: einen Zustandswert cachen, bei jedem update() gegen die aktuelle Zeit pruefen, nur bei tatsaechlichem Uebergang needsRedraw setzen (kein Redraw-Zwang bei jedem Frame).

Nutzen: geringer Overhead auf limitierter Hardware, eine einzige Koordinatenebene (R-11/T-09 entfallen).

## 8.3 Persistenz- und Formatkonzept

- Ein Bild wird nativ gespeichert (AD-017, Constitution II): saves/<id>/sheet.pdi (deduplizierte 16x16-Tiles als PDI), frames.json (375 Tile-Indizes je Frame, max. 12 Frames), preview.pdi (Vorschaubild aus Frame 1).
- Tiles werden vor dem Speichern via FNV-1a-Hash dedupliziert; kein Tile wird doppelt abgelegt.
- Die Laufzeitrepraesentation imageData = {id, name, imagetable, frames, hashIndex} entsteht beim Laden (Sheet-Slicing) und ist die einzige Datenquelle des Editors.
- Der Index (saves/index) wird als letzte Save-Phase aktualisiert (C-06) und traegt lastEditedId fuer den Startscreen.
- Datei-Endungen vergibt der SDK-Datastore selbst (.json bei write/read, .pdi bei writeImage/readImage); im Code stehen Pfade daher ohne Endung. Geloescht wird deshalb der komplette Bild-Ordner rekursiv (playdate.file.delete(path, true)) statt einzelner Dateien.

Nutzen: schnelle SDK-native Ladepfade ohne eigene Parser; Unabhaengigkeit vom Pulp-Oekosystem.

## 8.4 Tile-Lifecycle-Konzept

- Basistiles sind stabil: Index 1 = Voll-Weiss, Index 2 = Voll-Schwarz (Grundlage von Toggle und "Zuruecksetzen auf Weiss"). Diese Invariante wird an beiden Entstehungsorten der Imagetable erzwungen: bei der Neuanlage (createImage) und beim Laden (sliceSheetToImagetable erzeugt fehlende Basistiles als Fallback, auch bei fehlendem oder unvollstaendigem Sheet).
- Malen im Editor schreibt ausschliesslich Frame-Indizes; neue Tile-Bilder entstehen nur ueber den Zoom-Commit.
- Zoom-Commits uebergeben nur geaenderte Slots; EditorRoom:applyTileEdits dedupliziert ueber hashIndex-Treffer plus Pixelvergleich oder haengt ein neues Tile an die Imagetable an (waechst dynamisch, mit Neuaufbau-Fallback) und fuehrt den hashIndex nach.
- Geschrieben wird ausschliesslich frames[currentFrame] (FR-013) — mit einer dokumentierten Ausnahme: "All Similar" (PixelRoom) bearbeitet das Tile in-place in der Imagetable und wirkt damit auf alle Verwendungen ueber alle Frames hinweg.
- Eine Kompaktierung ungenutzter Tiles findet derzeit nicht statt; das Wachstum der Imagetable wird beobachtet (R-13).

Nutzen: begrenzter Speicherverbrauch durch Dedup und konsistente Tile-Referenzen ueber alle Frames.

## 8.5 Evolutionaeres Planungskonzept

Die Entwicklung folgt dem Spec-Kit-Ablauf (Constitution -> Spec -> Plan -> Tasks -> Implementierung) unter specs/; arc42 wird im selben Aenderungsschnitt mitgezogen (Constitution III). Historische Plaene unter plans/ und support/concepts dokumentieren die Evolution bis v0.2.

Nutzen: nachvollziehbare Entscheidungen und kontrollierte technische Schulden.

## 8.6 Asynchrones Operationskonzept (Save/Load)

- Langlaufende Save/Load-Aktionen laufen room-lokal ueber RoomOperation als Coroutine, fortgesetzt pro Frame in update().
- RoomOperation reicht Phasen-Yields als Detailtext ans Overlay und das Ergebnis der Coroutine an onComplete durch; Fehler laufen ueber onError (Overlay-Fehlerstatus, Room raeumt seine Referenz auf).
- Waehrend einer aktiven Operation werden konkurrierende Eingaben blockiert — im EditorRoom einschliesslich der Systemmenue-Aktionen.
- JSON-/Datastore-read/write bleiben als einzelne Runtime-Aufrufe blockierend; diese Phasen sind explizit als finale Schritte markiert.

Nutzen: sichtbarer Fortschritt, bessere Responsivitaet, weniger Duplikation zwischen Rooms.

## 8.7 Modul-Verantwortungen

- ImageStore (Verwaltung/Index) ist von ImageStoreCodec (Kodierung/Dekodierung) getrennt.
- Wiederverwendbare UI-Bausteine (loadingBar, Bauchbinde, PencilCursor) sind von Room-Logik entkoppelt.
- Der EditorRoom buendelt Cursor-, Mal-, Frame- und Zoom-Trigger-Logik in einem Room; die Zoomraeume kapseln ihre Raster- und Commit-Logik selbst.

Nutzen: klare Zustandsgrenzen und geringe Kopplung zwischen Persistenz und UI.

## 8.8 SDK-Konformitaets- und Testkonzept

Hintergrund: Eine Serie von Laufzeit-Crashes in v0.3.0 ging auf dieselbe Fehlerklasse zurueck — plausibel klingende, aber nicht existierende SDK-APIs, die erst beim ersten Aufruf auf dem Geraet crashen (Lua ist dynamisch, pdc prueft keine API-Namen).

Regeln:

| Regel | Begruendung / typischer Fehler |
|---|---|
| import nur auf Dateiebene | import ist eine pdc-Compile-Direktive; Aufruf zur Laufzeit wirft "import() called outside of pdz loading". |
| SDK-Aufrufe gegen die lokale SDK-Quelle verifizieren (CoreLibs/*.lua, CoreLibs/__stub.lua, Inside Playdate) | Erfundene APIs wie gridview:setSelectedCell, keyboard.setCommitCallback oder gfx.drawImage — richtig sind setSelection(section, row, col), keyboardWillHideCallback(ok) und image:draw(x, y). |
| Gridview-/SDK-Callbacks als Methoden definieren (self-Parameter) | Das Gridview ruft drawCell als self:drawCell(...) auf; ohne self verschieben sich alle Argumente um eins. |
| Keyboard-Callbacks sind Felder, keine Setter; show(text) setzt den Textinhalt | Es gibt keine set*Callback-Funktionen und keinen Prompt-Parameter. |
| Kein Raumwechsel aus SDK-Callbacks heraus, solange das SDK-Modul aktiv ist | keyboardWillHideCallback feuert beim START der Zuklapp-Animation; das Keyboard haelt playdate.update und einen Input-Handler. Ein switchRoom in dem Moment korrumpiert den Handler-Stack. Muster: Absicht vormerken (pendingCommitName) und in update() ausfuehren, sobald keyboard.isVisible() false ist. |
| Jeder SDK-Aufruf im Code traegt einen Referenz-Kommentar | Der Code dient zugleich als SDK-Lernmaterial (Projektziel). |

Teststrategie: tests/headless_tests.lua laedt die echten Source-Dateien mit strikten Playdate-Mocks in einem normalen Lua-Interpreter; jeder Zugriff auf eine unbekannte SDK-Methode schlaegt sofort fehl. Getestet werden Navigations-Klemmen des SelectionRoom, der Keyboard-Commit/Abbruch-Flow und die reinen Codec-Helfer (Sheet-Geometrie). Der pdc-Build fungiert zusaetzlich als Syntax-Gate.

Nutzen: Die haeufigste Crash-Klasse wird vor dem Simulator-Lauf gefangen; Regressionen in der Raum-Logik sind ohne Geraet pruefbar.

## 8.9 Import-Integritaetskonzept (Tools/Importer, historisch)

- Das Browser-Tool arbeitet auf dem Pulp-JSON-Format (v0.2) und ist mit dem v0.3.0-Format nicht kompatibel (R-14); eine Anpassung ist ein spaeteres Vorhaben.
- Es bleibt strikt offline und exportbasiert (kein in-place Ueberschreiben) und nutzt dasselbe Dedupe-Prinzip (FNV-1a) wie der Editorpfad.

Nutzen: klare Trennung zur Device-Runtime; dokumentierter Ausgangspunkt fuer einen kuenftigen v0.3.0-Import.

---

## 8.10 Backend-Querschnittskonzepte (Hans Dither Sync)

### 8.10.1 Authentifizierungs- und Session-Konzept

**Prinzipien:**
- **UID-basiert:** Jeder Nutzer wird über eine einzigartige Playdate-Geräte-ID (UID) identifiziert
- **PIN-Authentifizierung:** 4-stellige numerische PIN (10.000 Kombinationen) für Zugriff
- **Keine Cookies:** Authentifizierung erfolgt pro Request via Session-Token (Header oder Query-Parameter)
- **Session-Management:** Tokens sind UUIDs mit 30 Minuten Gültigkeit

**Ablauf:**
1. **Pairing:** UID + PIN → bcrypt-Hash der PIN → Speicherung in `users`-Tabelle
2. **Login:** UID + PIN → password_verify() gegen gespeicherten Hash → Session-Token generieren
3. **Autorisierung:** Jeder geschützte Endpunkt prüft das Session-Token → Extraktion der UID
4. **Berechtigung:** Dateizugriff nur wenn `image.uid == session.uid`

**Sicherheitsmechanismen:**
- **Rate-Limiting:** 3 Fehlversuche → 5 Minuten Sperre (locked_until Timestamp)
- **bcrypt:** PIN wird NIE im Klartext gespeichert (PASSWORD_BCRYPT)
- **Token-Invalidierung:** Session-Tokens können explizit ungültig gemacht werden
- **Automatische Bereinigung:** Abgelaufene Sessions werden periodisch gelöscht

**Nutzen:** Einfache, aber sichere Authentifizierung ohne externe Abhängigkeiten (kein OAuth, keine Framework-Libraries).

### 8.10.2 Dateivalidierungs-Konzept

**Prinzipien:**
- **Whitelist-Ansatz:** Nur explizit erlaubte Dateitypen (.pdi, .json)
- **Inhaltsprüfung:** Dateiendung reicht NICHT aus – Inhalt muss validiert werden
- **Fail-Secure:** Bei Validierungsfehler wird die Datei NICHT gespeichert

**Validierungskette für PDI:**
1. Dateiendung = `.pdi`
2. Magic Bytes: Erste 4 Bytes müssen `PDI\x00` sein
3. Header-Parse: Version (4 Bytes), Width (2 Bytes), Height (2 Bytes) als Little-Endian
4. Plausibilität: Width/Height > 0 und < 1000
5. Dateigröße: > 0 und < 10MB

**Validierungskette für JSON:**
1. Dateiendung = `.json`
2. MIME-Type = `application/json` (optional)
3. `json_decode()` muss erfolgreich sein und ein Objekt/Array zurückgeben
4. Dateigröße: < 10MB

**Gefährliche Dateitypen (Blockliste):**
- Ausführbare Dateien: `.php`, `.exe`, `.sh`, `.py`, `.rb`, `.js`, `.asp`
- Archivdateien: `.zip`, `.tar`, `.gz`
- Konfigurationsdateien: `.htaccess`, `.env`

**Nutzen:** Verhindert Upload von schädlichem Code oder Dateien, die Server-Sicherheit gefährden (S-04, S-05).

### 8.10.3 Dateispeicherungs-Konzept

**Prinzipien:**
- **UID-Isolation:** Jeder Nutzer hat sein eigenes Verzeichnis `/uploads/{UID}/`
- **UUID-basierte Dateinamen:** Keine nutzerspezifischen Dateinamen → Keine Kollisionen
- **On-demand Rendering:** PNG wird erst beim ersten Download generiert und dann gecacht

**Speicherpfade:**
```
/uploads/{UID}/
├── {image-uuid}.pdi      # Original PDI-Datei
├── {image-uuid}.json     # Tilemap-JSON
└── {image-uuid}.png      # Gerendertes PNG (optional)
```

**Datenbank-Abbildung:**
- `images.id` → Dateinamen (ohne Endung)
- `images.pdi_path` → Vollständiger Pfad zur PDI-Datei
- `images.json_path` → Vollständiger Pfad zur JSON-Datei
- `images.png_path` → Vollständiger Pfad zur PNG-Datei (NULL wenn nicht generiert)

**Nutzen:** Einfache Zuordnung, berechtigungsbasierter Zugriff, Skalierbarkeit durch UID-Struktur.

### 8.10.4 PNG-Rendering-Konzept

**Prinzipien:**
- **On-demand:** PNG wird erst generiert, wenn es angefordert wird
- **Caching:** Generiertes PNG wird gespeichert für zukünftige Zugriffe
- **GD-Bibliothek:** Standard-PHP-Bibliothek für Bildbearbeitung

**Rendering-Prozess:**
1. PDI-Datei parsen: Magic Bytes, Header (Version, Width, Height), Pixel-Daten
2. JSON-Datei parsen: Tilemap-Daten (Frames, Tile-Definitionen)
3. Basis-Bild erstellen: `imagecreate(width, height)`
4. Pixel setzen: 1 Bit pro Pixel aus PDI-Daten (0 = weiß, 1 = schwarz)
5. Tilemap anwenden: Falls JSON Tile-Daten enthält, diese über die PDI-Pixel legen
6. PNG speichern: `imagepng()` mit 1-Bit Farbtiefe
7. Pfad in DB speichern: `UPDATE images SET png_path = ?`

**Bildgröße:**
- Standard: 400x240 Pixel (Playdate Display)
- Farbtiefe: 1-Bit (schwarz-weiß)
- Format: PNG (verlustfreie Kompression)

**Nutzen:** Serverseitiges Rendern ermöglicht Anzeige der Projekte ohne Playdate-Hardware.

### 8.10.5 Fehlerbehandlungs-Konzept

**HTTP-Status-Codes:**
| Code | Bedeutung | Nutzung |
|------|-----------|---------|
| 200 | OK | Erfolgreiche GET-Requests |
| 201 | Created | Erfolgreiche POST (Erstellung) |
| 400 | Bad Request | Validierungsfehler |
| 401 | Unauthorized | Authentifizierungsfehler |
| 403 | Forbidden | Berechtigungsfehler |
| 404 | Not Found | Ressource nicht gefunden |
| 409 | Conflict | UID bereits verknüpft |
| 413 | Payload Too Large | Datei zu groß (>10MB) |
| 429 | Too Many Requests | Rate-Limiting aktiv |
| 500 | Internal Server Error | Server-Fehler |

**Fehlerformat (JSON):**
```json
{
  "error": "menschliche Fehlermeldung"
}
```

**Prinzipien:**
- **Generische Fehlermeldungen:** Keine Details über interne Struktur (Security)
- **HTTP-Status immer setzen:** Klare Unterscheidung zwischen Client- und Server-Fehlern
- **Logging:** Alle Fehler werden in Log-Dateien protokolliert (`/logs/`)

**Nutzen:** Konsistente Fehlerbehandlung, einfache Debugging-Möglichkeit für Entwickler.

## Konsolidierte Tile-View-Overlay-Leiste (Spec 010, 8. Runde, AD-049)

Die Tile View haelt mehrere passive Hinweis-Overlays: Frame/Ebenen-Label
(FR-015), Tile-Picker-Filmstreifen (FR-025), „Tile N picked"-Toast (FR-027),
Statustexte. **Konzept:** Sie teilen sich EINE Leiste in der dem Tile-Cursor
abgewandten Bildschirmzone.

- Horizontale Haelfte weiter nach `cursor.x` (Spec 006 FR-003), vertikaler
  Rand nach `cursor.y`: `overlayAnchor(cursorY, GRID_ROWS)` → `"bottom"` fuer
  die obere Cursor-Haelfte, sonst `"top"` (Gleichstand → `"bottom"`).
- `Bauchbinde:draw(lines, side, vAnchor, w, h)` zeichnet mehrzeilig; Label
  und Statustext stehen als zwei Bandzeilen in derselben Box (kein separater
  fixer „left"-Statusbalken mehr).
- Der Tile-Picker-Filmstreifen liegt bei Sichtbarkeit in derselben Zone; die
  Statuszeile weicht dann auf den gegenueberliegenden Anker aus, damit sich
  nichts ueberzeichnet (SC-008).
- Der modale Undo-Dialog (Spec 011, `UndoPrompt`) bleibt eine **eigene,
  darueberliegende Schicht** — Spec 011 FR-013 verlangt volle Modalitaet; er
  wird nicht in die passive Leiste gefaltet, nur seine Platzierung ist
  koordiniert.
- Die Anker-/Region-Logik sind reine Funktionen (`overlayAnchor`,
  `overlayRegionRect`, `cursorCellRect`) und werden gegen SC-008 headless
  geprueft (Leiste schneidet fuer jede Cursorzeile die Cursor-Zelle nie).

## Symmetrische B+Kurbel-Room-Gesten mit Arming (Spec 010, 9. Runde, AD-048)

Der Frame-Room wird mit **B + Kurbel rueckwaerts** betreten und mit **B +
Kurbel vorwaerts** verlassen. Weil die Eintrittsgeste die Kurbel noch in
Bewegung haelt, wenn der Room schon offen ist, wird die Verlassen-Geste
**erst scharf, nachdem B seit `entered()` einmal losgelassen wurde**
(`bReleasedSinceEnter`). Der Room liest pro `update()` **nur** `getCrankTicks(4)`
(nie `getCrankChange()` — CR-01/AD-047) in einen `crankAccu`, der bei nicht
gehaltenem B auf 0 zurueckgesetzt wird. Das gleiche Muster (Arming-Boolean
statt Vorzeichen-Heuristik) ist die Vorlage fuer kuenftige symmetrische
Kurbel-Gesten.
