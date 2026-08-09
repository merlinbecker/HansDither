# Phase 1 Data Model: Tile-Bereinigung, projektbasierte Dateibenennung und PNG-Export im Backend

**Feature**: 009-tile-cleanup-png-export

Diese Spec führt **keine neue Datenbank-Tabelle und keine neue Spalte** ein
(Constitution IV, research.md R3/R5 — `client_image_id` und die
Frame-Anzahl aus `frames.json` decken den Bedarf bereits ab). Betroffen
sind: ein neuer, reiner Transformations-Algorithmus auf der Playdate-Seite,
eine geänderte Pfadberechnung + eine Korrektur einer bestehenden
UPDATE-Anweisung im Backend, und ein abgeleitetes (nicht persistiertes)
Datenfeld für die Web-Oberfläche.

---

## 1. Tile-Bereinigung (`ImageStoreCodec.pruneUnusedTiles`)

**Eingabe**: `imagetable` (SDK-Imagetable, `tileCount` Einträge),
`frames` (Array von bis zu 12 Frame-Arrays à 375 1-basierte Tile-Indizes),
`tileCount` (Integer).

**Algorithmus**:

1. `used = {1: true, 2: true}` — die beiden Basistiles (Voll-Weiß,
   Voll-Schwarz) sind immer "genutzt", unabhängig von `frames` (spec.md
   FR-002, `EditorRoom.lua:142`-Invariante).
2. Für jedes `frame` in `frames`, für jeden `tileIndex` in `frame`:
   `used[tileIndex] = true`.
3. `keepList` = aufsteigend sortierte Liste aller Indizes in `used`, die
   `<= tileCount` sind (Schutz gegen bereits vorhandene ungültige
   Alt-Indizes — werden stillschweigend ignoriert, nicht in die neue
   Sammlung übernommen).
4. `remap[oldIndex] = newIndex` für `newIndex, oldIndex` in `ipairs(keepList)`
   (1-basiert, lückenlos).
5. Neues `imagetable` mit `#keepList` Einträgen; für jeden `newIndex` wird
   `imagetable:getImage(keepList[newIndex])` hinein kopiert.
6. Neue `frames`: jede Position `frame[i]` wird durch `remap[frame[i]]`
   ersetzt; ein `frame[i]`, das in `used` fehlt (kann nach Schritt 3 nicht
   vorkommen, da JEDE referenzierte Position per Definition in `used`
   steht) oder außerhalb `1..tileCount` liegt, fällt auf `remap[1]` zurück
   (Basistile Weiß) als Sicherheitsnetz.
7. Rückgabe: `newImagetable, newFrames, #keepList`.

**Invariante** (research.md R2): `#keepList >= 2` in JEDEM Fall, da Schritt
1 die Basistiles unabhängig von ihrer Nutzung immer in `used` aufnimmt.

**Kein Seiteneffekt**: Die Funktion liest `imagetable`/`frames` nur lesend;
`imageData.imagetable`, `imageData.frames`, `imageData.hashIndex` werden
NICHT verändert (research.md R2). Aufrufer: `ImageStoreCodec.newSaveOperation()`
ersetzt ab der "Dedup"-Phase seine lokalen `imagetable`/`frames`/`tileCount`-
Variablen durch das Ergebnis dieser Funktion, BEVOR die nachfolgenden Phasen
(Sheet, Frames, Bilddaten, Preview) darauf zugreifen.

**Beispiel**:

| Zustand | Tiles (Index → Inhalt) | Frame 1 (Auszug) |
|---|---|---|
| Vor Bereinigung | 1=Weiß, 2=Schwarz, 3=Muster-A, 4=Muster-B (nirgends mehr referenziert), 5=Muster-C | `[1, 3, 5, 1, ...]` |
| Nach Bereinigung | 1=Weiß, 2=Schwarz, 3=Muster-A, 4=Muster-C | `[1, 3, 4, 1, ...]` |

(Tile 4 "Muster-B" entfällt; Tile 5 "Muster-C" rückt auf Index 4.)

---

## 2. Backend-Dateibasis (Pfadberechnung)

**Kein neues Feld** — die Basis wird bei jeder Pfadberechnung aus bereits
vorhandenen Werten abgeleitet:

```
base = client_image_id ?? image_id   // image_id = interne UUID (Primärschlüssel, unverändert für Adressierung)
```

| Datei | Pfadmuster (relativ zu `uploads/{uid}/`) | Vorher |
|---|---|---|
| PDI | `{base}.pdi` | `{image_id}.pdi` |
| JSON | `{base}.json` | `{image_id}.json` |
| Frame-PNG, Standard (`frame` fehlt/`=0`) | `{base}.png` | `{image_id}.pdi.png` (Bestandsfehler, research.md R5) |
| Frame-PNG (`frame=N`, N ≥ 1, 0-basiert) | `{base}-frame-{N}.png` | *(existierte nicht)* |
| Tilemap-PNG | `{base}-table-16-16.png` | *(existierte nicht)* |
| GIF | `{base}.gif` | `{image_id}.pdi.gif` (Bestandsfehler, research.md R5) |

`image_id` (DB-Primärschlüssel, UUID) bleibt unverändert die Grundlage für
`/download/{typ}/{id}`-URLs und die Berechtigungsprüfung (`uid`-Abgleich) —
ausschließlich die auf der Festplatte abgelegten und in
`Content-Disposition` ausgelieferten Dateinamen ändern sich (spec.md
FR-008).

**Update-in-place-Korrektur** (research.md R4): Beim Aktualisieren eines
bestehenden Datensatzes (bekannte `client_image_id`) MUSS die UPDATE-Anweisung
`pdi_path` und `json_path` neu setzen (bisher nur `png_path`/`gif_path`):

```sql
UPDATE images
SET pdi_path = ?, json_path = ?, png_path = NULL, gif_path = NULL, uploaded_at = NOW()
WHERE id = ?
```

Weichen die neu berechneten Pfade von den zuvor gespeicherten ab (Alt-
Datensatz, erste Umbenennung nach dieser Änderung), werden die alten
Dateien (`pdi_path`, `json_path`, ggf. alte `png_path`/`gif_path`) nach
erfolgreichem Commit best-effort gelöscht (siehe research.md R4 für den
vollständigen Ablauf). Der dafür nötige Lookup (Schritt 4a in
`handleUpload()`) muss dazu `pdi_path, json_path, png_path, gif_path`
mitlesen (nicht nur `id`), BEVOR das UPDATE die Zeile überschreibt.

**Zusätzlich, bei JEDEM Re-Sync (nicht nur bei Umbenennung)**: Alle bereits
vorhandenen Frame-PNGs ab Frame-Index 1 (0-basiert, `{base}-frame-*.png`,
per `glob()`) sowie eine vorhandene Tilemap-PNG (`{base}-table-16-16.png`)
werden gelöscht — sie besitzen (anders als der Standard-Frame `frame=0`/
GIF über `png_path`/`gif_path = NULL`) keine DB-Spalte, die sie als
veraltet markieren könnte; ohne diesen Schritt würde bei gleichbleibendem
`base` eine inhaltlich veraltete, aber namensgleiche Datei unbegrenzt
weiter ausgeliefert (research.md R4, zweiter Abschnitt). Dieser Schritt
läuft — wie das Umbenennungs-Cleanup oben — NACH erfolgreichem
`db()->commit()`, nicht vor dem Schreiben der neuen `pdi`/`json`-Dateien:
Er liegt außerhalb der Transaktion, damit ein Rollback nicht auf bereits
gelöschte, aber nicht zurücknehmbare Render-Artefakte trifft. Verlorene
Artefakte sind unkritisch, da sie beim nächsten Abruf verlustfrei neu
gerendert werden.

---

## 3. Frame-Auswahl beim PNG-Download (kein neues Feld)

**0-basiert**, wie in der Nutzer-Klärung festgelegt (spec.md Clarifications:
"`frame=N`, N=0 = bisherige Vorschau"):

| Query-Parameter `frame` | Bedeutung | Datei | DB-Caching |
|---|---|---|---|
| fehlt oder `0` | Erster Frame (bisheriges Standardverhalten) | `{base}.png` | Ja — bestehende Spalte `png_path` (unverändertes Verhalten) |
| `1`..`frameCount-1` | N-ter Frame (0-basiert) | `{base}-frame-{N}.png` | Nein — Pfad ist aus `base`+`N` deterministisch, `file_exists()`-Check statt DB-Spalte (research.md R5) |
| `< 0`, nicht-numerisch, `>= frameCount` | Ungültig | — | 400 Bad Request, `{"error": "Ungültiger Frame-Index"}` |

`frameCount` wird pro Request aus der bereits geladenen `frames.json`
bestimmt (`count($meta['frames'])`, identisch zu `Renderer::loadAssets()`),
kein zusätzlicher Query.

---

## 4. `frame_count` für die Bilder-Liste (abgeleitet, nicht persistiert)

Für die Galerie-Ansicht (Nutzer-Klärung: ein Vorschau-/Downloadlink pro
Frame) wird beim Aufbau der Bilder-Liste je Bild `json_path` gelesen und
`count($data['frames'])` gebildet — kein neues DB-Feld (research.md R5).
Zustandsübergang: keiner, reine Ableitung bei jedem Seitenaufruf/JSON-Request.

---

## 5. Entfernte Felder/Routen

| Element | Vorher | Nachher |
|---|---|---|
| `images[].pdi_url` (JSON, `/images`) | vorhanden | entfernt |
| `<td>`-Spalte "PDI" (HTML, `/images`) | vorhanden | entfernt |
| `GET /download/pdi/{id}` | liefert PDI-Binärdaten | `410 Gone`, `deliverPdi()` entfernt (kein toter Code) |

Kein Zustandsübergang in der Datenbank — die `images`-Tabelle bleibt
schemagleich; `pdi_path` wird intern weiterhin gespeichert und gelesen
(für das Rendering), nur nicht mehr über den Download-Endpunkt exponiert.
