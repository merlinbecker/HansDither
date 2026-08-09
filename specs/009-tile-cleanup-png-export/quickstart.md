# Quickstart: Tile-Bereinigung, projektbasierte Dateibenennung und PNG-Export im Backend

**Feature**: 009-tile-cleanup-png-export

Zwei unabhängige Validierungspfade: (A) Playdate-seitige Tile-Bereinigung
über die bestehende Headless-Test-Suite, (B) Backend-Verhalten über
`curl`, als Erweiterung von `backend/TESTING.md` (gleiches Muster wie
Spec 007). Details der geprüften Regeln stehen in `data-model.md` und
`contracts/backend-api-amendment.md` — hier nur die Ablauf-/Kommandos.

---

## A. Playdate-seitig: Tile-Bereinigung (FR-001..004)

**Voraussetzung**: `lua` (5.4-kompatibel) lokal installiert, wie für alle
bestehenden Läufe von `tests/headless_tests.lua` (Constitution V).

**Kommando**:
```bash
lua tests/headless_tests.lua
```

**Erwartetes Ergebnis**: `ALLE TESTS BESTANDEN` — inklusive neuer
Testfälle (Sektion "ImageStoreCodec: Tile-Bereinigung beim Speichern",
Tasks-Phase) für:

1. Ein Tile, das in keinem Frame mehr referenziert wird, verschwindet aus
   der bereinigten Tile-Sammlung; verbleibende Positionen zeigen nach dem
   Remap weiterhin auf identischen Inhalt (data-model.md Abschnitt 1,
   Beispieltabelle).
2. Ein Bild, das ausschließlich Weiß/Schwarz nutzt, behält trotzdem genau
   2 Tiles (Basistiles nie entfernt, auch wenn eines davon ungenutzt wäre).
3. `pruneUnusedTiles()` liefert nie `tileCount < 2` (research.md R2,
   Invariante) — Regressionstest gegen genau das in `ImageStore.createImage()`
   erzeugte Neubild-Muster (1 Frame, alle Positionen = Index 1).
4. Round-Trip: Speichern (mit Bereinigung) → Laden → alle Frames
   pixelidentisch zum Stand vor dem Speichern (erweitert den bestehenden
   Round-Trip-Test aus Spec 001).

**Danach** (Constitution V, zweites Gate):
```bash
pdc Source "Hans Dither.pdx"
```
MUSS fehlerfrei durchlaufen.

---

## B. Backend: Dateibenennung, Frame-PNGs, Tilemap-PNG, PDI-Download entfällt

Erweitert `backend/TESTING.md` Abschnitt 4/6 um die neuen Szenarien dieser
Spec. Setup (Testdateien, `$BASE`, `$UID_TEST`, `$PIN`) identisch zu
`backend/TESTING.md` Abschnitt 0 — hier nicht wiederholt.

### B1. Upload MIT `image_id` → Dateien tragen den Projektnamen

```bash
UPLOAD=$(curl -s -X POST "$BASE/upload.php" \
  -F "uid=$UID_TEST" -F "token=$TOKEN" \
  -F "image_id=meinbild" \
  -F "pdi=@sheet.pdi;filename=sheet.pdi" \
  -F "json=@frames.json;filename=frames.json")
IMAGE_ID=$(echo "$UPLOAD" | python3 -c "import json,sys;print(json.load(sys.stdin)['image_id'])")
```

**Erwartung**: `201`; die Antwort liefert weiterhin die interne
`image_id` (UUID, unveränderte Adressierung, spec.md FR-008). Auf
Serverseite (per SSH/Datei-Listing, falls Zugriff vorhanden) liegen die
Dateien als `uploads/$UID_TEST/meinbild.pdi` und
`uploads/$UID_TEST/meinbild.json` — NICHT unter `$IMAGE_ID.pdi`
(data-model.md Abschnitt 2).

### B2. Re-Sync (Update-in-place) überschreibt dieselben Dateien, keine Duplikate

```bash
curl -s -X POST "$BASE/upload.php" \
  -F "uid=$UID_TEST" -F "token=$TOKEN" -F "image_id=meinbild" \
  -F "pdi=@sheet.pdi;filename=sheet.pdi" -F "json=@frames.json;filename=frames.json"
curl -s -H "Accept: application/json" -H "X-Session-Token: $TOKEN" \
  "$BASE/images?uid=$UID_TEST" | python3 -m json.tool
```

**Erwartung**: Weiterhin genau ein Eintrag mit `id=$IMAGE_ID` in der
Liste (kein zweiter Datensatz durch den erneuten Upload).

**Cache-Invalidierung bei geändertem Inhalt** (research.md R4, zweiter
Abschnitt — deckt eine sonst stillschweigend veraltete Frame-PNG auf).
Frame-Indizes sind 0-basiert (spec.md Clarifications: "`frame=N`, N=0 =
bisherige Vorschau"); die Testdaten aus `backend/TESTING.md` Abschnitt 0
haben genau 2 Frames, also gültige Indizes `0` und `1` — der zweite Frame
ist `frame=1`:

```bash
curl -s -o before.png "$BASE/download/png/$IMAGE_ID?token=$TOKEN&frame=1"
# frames.json lokal so ändern, dass der zweite Frame (Index 1) sich sichtbar
# unterscheidet (z. B. komplett weiß statt komplett schwarz), dann erneut
# hochladen:
curl -s -X POST "$BASE/upload.php" \
  -F "uid=$UID_TEST" -F "token=$TOKEN" -F "image_id=meinbild" \
  -F "pdi=@sheet.pdi;filename=sheet.pdi" -F "json=@frames_changed.json;filename=frames.json"
curl -s -o after.png "$BASE/download/png/$IMAGE_ID?token=$TOKEN&frame=1"
cmp before.png after.png   # -> Dateien MÜSSEN sich unterscheiden (kein exit 0)
```

**Erwartung**: `after.png` unterscheidet sich von `before.png` — die zuvor
generierte PNG für Frame-Index 1 wurde beim Re-Sync verworfen, nicht
unverändert weiter ausgeliefert.

### B3. Frame-PNGs einzeln abrufbar (FR-010)

```bash
curl -s -o frame0.png "$BASE/download/png/$IMAGE_ID?token=$TOKEN"
curl -s -o frame1.png "$BASE/download/png/$IMAGE_ID?token=$TOKEN&frame=1"
curl -s -o /dev/null -w "%{http_code}\n" \
  "$BASE/download/png/$IMAGE_ID?token=$TOKEN&frame=99"   # -> 400
```

**Erwartung**: `frame0.png`/`frame1.png` sind gültige, unterschiedliche
400×240-PNGs (Testdaten aus `backend/TESTING.md` Setup: die beiden Frames
unterscheiden sich); `frame=99` liefert `400` mit
`{"error": "Ungültiger Frame-Index"}` (contracts/backend-api-amendment.md
E-08).

### B4. Tilemap-PNG in SDK-Namenskonvention (FR-011)

```bash
curl -s -D - -o tilemap.png "$BASE/download/tilemap/$IMAGE_ID?token=$TOKEN" | grep -i content-disposition
```

**Erwartung**: `Content-Disposition` nennt `meinbild-table-16-16.png`;
`tilemap.png` ist ein gültiges PNG mit der Sheet-Breite/-Höhe aus
`ImageStoreCodec.getSheetDimensions()` (bei den 3 Test-Tiles aus
`backend/TESTING.md`: 48×16 px). Manuelle SDK-Prüfung (optional, nicht
Teil der automatisierten Kette): Datei nach `Source/images/` eines
Test-Playdate-Projekts als `tilemap-table-16-16.png` kopieren,
`playdate.graphics.imagetable.new("tilemap")` lädt sie fehlerfrei im
Simulator.

### B5. PDI-Download liefert 410, kein Download-Link mehr in Liste/HTML (FR-012/013)

```bash
curl -s -o /dev/null -w "%{http_code}\n" "$BASE/download/pdi/$IMAGE_ID?token=$TOKEN"   # -> 410
curl -s -H "Accept: application/json" -H "X-Session-Token: $TOKEN" \
  "$BASE/images?uid=$UID_TEST" | grep -c pdi_url   # -> 0
```

**Erwartung**: `410`, kein `pdi_url`-Feld mehr in der JSON-Antwort.

### B6. Upload OHNE `image_id` → Fallback auf interne ID (FR-007)

```bash
curl -s -X POST "$BASE/upload.php" \
  -F "uid=$UID_TEST" -F "token=$TOKEN" \
  -F "pdi=@sheet.pdi;filename=sheet.pdi" -F "json=@frames.json;filename=frames.json"
```

**Erwartung**: `201`, Upload wird angenommen (nicht abgelehnt); Dateien
liegen unter der neu generierten `image_id` (UUID) als Basis, identisch
zum bisherigen Verhalten.

---

## Checkliste (Ergänzung zu `backend/TESTING.md`)

- [ ] B1: Dateien tragen `image_id`-Bezeichner statt UUID
- [ ] B2: Re-Sync überschreibt statt zu duplizieren
- [ ] B3: Frame-Index 0 und 1 einzeln abrufbar, ungültiger Index → 400
- [ ] B4: Tilemap-PNG mit korrektem SDK-Dateinamen, im Simulator ladbar
- [ ] B5: PDI-Route → 410, kein `pdi_url` mehr in `/images`
- [ ] B6: Upload ohne `image_id` weiterhin erfolgreich (Fallback)
- [ ] A: `lua tests/headless_tests.lua` → "ALLE TESTS BESTANDEN"
- [ ] A: `pdc Source "Hans Dither.pdx"` fehlerfrei
