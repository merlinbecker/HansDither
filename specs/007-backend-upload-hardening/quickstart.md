# Quickstart: Absicherung des Backends gegen unbegrenzte/missbräuchliche Uploads

**Feature**: 007-backend-upload-hardening

Erweitert `backend/TESTING.md` (Abschnitt 4 "Upload") um die neuen
Negativ-Szenarien dieser Spec. Setzt voraus, dass Abschnitt 0-3 aus
`TESTING.md` bereits einmal durchlaufen wurden (Basis-Fixtures,
Grundverständnis des `curl`-Musters). Jedes Szenario hier ist einer
Success-Criterion aus `spec.md` zugeordnet (SC-001 bis SC-006) und mit
einer eigenen, frischen Test-UID isoliert, damit die Szenarien in
beliebiger Reihenfolge und wiederholt laufen können.

## 0. Setup: zusätzliche Variablen und Negativ-Fixtures

```bash
BASE="https://www.hans-dither.de"
PIN="1234"
```

Zusätzlich zu `sheet.pdi`/`frames.json`/`fake.pdi` aus `TESTING.md`
Abschnitt 0 werden folgende Negativ-Fixtures benötigt:

```bash
python3 - <<'EOF'
import json, struct, zlib, os

# --- exakt 300 KB und 301 KB (Grenzfall, spec.md Edge Cases) ---
# Reales PDI drumherum, Rest mit Nullen aufgefüllt, damit die Dateigröße
# exakt stimmt (Inhalt jenseits der echten Zelle wird vom Parser ohnehin
# nicht erreicht, da hier NUR die Größenprüfung getestet wird, die VOR
# dem Parsing greift).
def pad_pdi(path, total_bytes):
    base = open("sheet.pdi", "rb").read()
    with open(path, "wb") as f:
        f.write(base + b"\x00" * max(0, total_bytes - len(base)))

pad_pdi("exactly_300kb.pdi", 300 * 1024)
pad_pdi("over_300kb.pdi", 300 * 1024 + 1)

# --- PDI mit korrektem Magic, aber strukturell kaputtem Rest (R3) ---
open("corrupt_magic_ok.pdi", "wb").write(b"Playdate IMG" + b"\x00" * 20)

# --- Schema-verletzende JSON-Varianten (R4) ---
def dump(name, obj):
    json.dump(obj, open(name, "w"))

base = {"version": 1, "name": "t", "gridWidth": 25, "gridHeight": 15,
        "tileCount": 3, "frames": [[1] * 375]}

wrong_grid = dict(base); wrong_grid["gridWidth"] = 24
dump("schema_wrong_grid.json", wrong_grid)

short_frame = dict(base); short_frame["frames"] = [[1] * 370]
dump("schema_short_frame.json", short_frame)

oob_tile = dict(base); oob_tile["frames"] = [[1] * 374 + [99]]  # tileCount=3, 99 außerhalb
dump("schema_oob_tile.json", oob_tile)

too_many_frames = dict(base); too_many_frames["frames"] = [[1] * 375] * 13
dump("schema_too_many_frames.json", too_many_frames)

dump("schema_not_object.json", [1, 2, 3])  # syntaktisch gueltig, falscher Typ

print("OK: Groessen-/Schema-Negativfixtures erzeugt")
EOF
ls -la exactly_300kb.pdi over_300kb.pdi
```

---

## Szenario 1 — SC-001: 12-Bilder-Obergrenze pro UID

```bash
UID_LIMIT="test-limit-$(date +%s)"
curl -s -X POST "$BASE/pair" -d "uid=$UID_LIMIT" -d "pin=$PIN" > /dev/null
TOKEN=$(curl -s -X POST "$BASE/login" -d "uid=$UID_LIMIT" -d "pin=$PIN" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['session_token'])")

# 12 unterschiedliche Bilder hochladen -> alle 201
for i in $(seq -w 1 12); do
  curl -s -o /dev/null -w "img-$i: HTTP %{http_code}\n" -X POST "$BASE/upload.php" \
    -H "X-Session-Token: $TOKEN" -F "uid=$UID_LIMIT" \
    -F "image_id=img-$i" -F "pdi=@sheet.pdi" -F "json=@frames.json"
done

# 13. (neues) Bild -> 403, Limit erreicht
curl -s -w "\nHTTP %{http_code}\n" -X POST "$BASE/upload.php" \
  -H "X-Session-Token: $TOKEN" -F "uid=$UID_LIMIT" \
  -F "image_id=img-13" -F "pdi=@sheet.pdi" -F "json=@frames.json"
```

**Erwartung:** `img-01` bis `img-12` = 201, `img-13` = 403 mit
`{"error": "Upload-Limit erreicht (maximal 12 Bilder pro Gerät)"}`.

**Race-Condition-Stichprobe** (research.md R1 — nicht deterministisch
per `curl` beweisbar, aber ein guter Rauch-Test für den Row-Lock):

```bash
UID_RACE="test-race-$(date +%s)"
curl -s -X POST "$BASE/pair" -d "uid=$UID_RACE" -d "pin=$PIN" > /dev/null
TOKEN_RACE=$(curl -s -X POST "$BASE/login" -d "uid=$UID_RACE" -d "pin=$PIN" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['session_token'])")

# 11 Bilder vorab anlegen (1 Slot frei)
for i in $(seq -w 1 11); do
  curl -s -o /dev/null -X POST "$BASE/upload.php" -H "X-Session-Token: $TOKEN_RACE" \
    -F "uid=$UID_RACE" -F "image_id=race-$i" -F "pdi=@sheet.pdi" -F "json=@frames.json"
done

# 5 gleichzeitige Requests um den letzten Slot -> nur EINER darf 201 bekommen
for i in a b c d e; do
  curl -s -o /dev/null -w "race-$i: HTTP %{http_code}\n" -X POST "$BASE/upload.php" \
    -H "X-Session-Token: $TOKEN_RACE" -F "uid=$UID_RACE" \
    -F "image_id=race-$i" -F "pdi=@sheet.pdi" -F "json=@frames.json" &
done
wait
```

**Erwartung:** genau EIN `race-*` = 201, die übrigen VIER = 403. Bei
Bedarf per SSH verifizieren, dass `SELECT COUNT(*) FROM images WHERE uid
= 'test-race-...'` exakt `12` ist, niemals `13`.

---

## Szenario 2 — SC-003: Dateigrößen-Grenze 300 KB (Grenzfall exakt)

```bash
UID_SIZE="test-size-$(date +%s)"
curl -s -X POST "$BASE/pair" -d "uid=$UID_SIZE" -d "pin=$PIN" > /dev/null
TOKEN_SIZE=$(curl -s -X POST "$BASE/login" -d "uid=$UID_SIZE" -d "pin=$PIN" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['session_token'])")

# Exakt 300 KB -> akzeptiert (Grenze ist inklusiv, spec.md Edge Cases)
curl -s -w "\nexactly_300kb: HTTP %{http_code}\n" -X POST "$BASE/upload.php" \
  -H "X-Session-Token: $TOKEN_SIZE" -F "uid=$UID_SIZE" \
  -F "image_id=size-a" -F "pdi=@exactly_300kb.pdi" -F "json=@frames.json"

# 300 KB + 1 Byte -> 413
curl -s -w "\nover_300kb: HTTP %{http_code}\n" -X POST "$BASE/upload.php" \
  -H "X-Session-Token: $TOKEN_SIZE" -F "uid=$UID_SIZE" \
  -F "image_id=size-b" -F "pdi=@over_300kb.pdi" -F "json=@frames.json"
```

**Erwartung:** `exactly_300kb.pdi` = 201, `over_300kb.pdi` = 413 mit
`{"error": "Datei zu groß (max. 300KB)"}`.

---

## Szenario 3 — SC-002: PDI-Format-Validierung (inkl. korrektem Magic, kaputtem Rest)

```bash
# Bekanntes Negativ-Fixture aus TESTING.md (falsches Magic) -> 400
curl -s -w "\nfake.pdi: HTTP %{http_code}\n" -X POST "$BASE/upload.php" \
  -H "X-Session-Token: $TOKEN_SIZE" -F "uid=$UID_SIZE" \
  -F "image_id=fmt-a" -F "pdi=@fake.pdi" -F "json=@frames.json"

# NEU: korrektes Magic, aber strukturell kaputter Rest (testet R3 —
# nicht nur die Magic-Bytes werden geprüft, sondern der volle Parse)
curl -s -w "\ncorrupt_magic_ok.pdi: HTTP %{http_code}\n" -X POST "$BASE/upload.php" \
  -H "X-Session-Token: $TOKEN_SIZE" -F "uid=$UID_SIZE" \
  -F "image_id=fmt-b" -F "pdi=@corrupt_magic_ok.pdi" -F "json=@frames.json"
```

**Erwartung:** BEIDE = 400 `{"error": "Ungültiger Dateityp"}` — das
zweite Fixture beweist, dass die Prüfung über die Magic-Bytes
hinausgeht (sonst würde `corrupt_magic_ok.pdi` fälschlich durchgehen).

---

## Szenario 4 — SC-004: JSON-Schema-Validierung

```bash
for f in schema_wrong_grid schema_short_frame schema_oob_tile \
         schema_too_many_frames schema_not_object; do
  curl -s -w "\n$f: HTTP %{http_code}\n" -X POST "$BASE/upload.php" \
    -H "X-Session-Token: $TOKEN_SIZE" -F "uid=$UID_SIZE" \
    -F "image_id=$f" -F "pdi=@sheet.pdi" -F "json=@$f.json"
done
```

**Erwartung:** alle FÜNF = 400, jeweils mit einer auf das konkret
verletzte Feld hinweisenden `error`-Meldung (nicht identischer Text bei
allen fünf — siehe `contracts/upload-hardening.md`).

---

## Szenario 5 — SC-005: Unterscheidbare Ablehnungsgründe (API-Ebene)

Zusammenfassender Vergleich der vier Kategorien (Ergebnisse aus den
Szenarien 1-4 oben):

| Kategorie | Auslöser | HTTP-Status | Unterscheidbar von den anderen drei? |
|---|---|---|---|
| Limit | 13. Bild derselben UID | 403 | Ja — einziger 403 |
| Größe | Datei > 300 KB | 413 | Ja — einziger 413 |
| Format | Ungültiges PDI | 400, `"Ungültiger Dateityp"` | Ja — Text nennt "Dateityp" |
| Schema | Ungültige JSON-Struktur | 400, `"JSON-Struktur ungültig: ..."` | Ja — Text nennt konkretes Feld |

Für die Geräte-UI-seitige Verifikation (nur Limit/Größe bekommen einen
eigenen Text, siehe `contracts/upload-hardening.md` "Client-seitige
Anzeige") ist kein `curl`-Test möglich — das ist bereits über
`tests/headless_tests.lua` (Testfall "Upload-Limit erreicht (403)...")
abgedeckt, Constitution V.

---

## Szenario 6 — SC-006: Update-in-place funktioniert weiterhin bei erreichtem Limit

Direkt im Anschluss an Szenario 1 (UID `$UID_LIMIT` hat bereits 12
Bilder):

```bash
# Bestehendes Bild "img-01" erneut hochladen (Re-Sync) -> weiterhin 201,
# NICHT 403, obwohl das Limit erreicht ist
curl -s -w "\nHTTP %{http_code}\n" -X POST "$BASE/upload.php" \
  -H "X-Session-Token: $TOKEN" -F "uid=$UID_LIMIT" \
  -F "image_id=img-01" -F "pdi=@sheet.pdi" -F "json=@frames.json"

# Zaehler bleibt bei 12, nicht 13
curl -s -H "X-Session-Token: $TOKEN" "$BASE/images?uid=$UID_LIMIT" \
  | python3 -c "import sys,json; print(len(json.load(sys.stdin)['images']))"
```

**Erwartung:** Re-Upload von `img-01` = 201 (nicht 403), Bildanzahl
danach weiterhin `12`.

---

## Aufräumen

Wie `TESTING.md` Abschnitt 8 — zusätzlich alle in diesem Dokument
verwendeten Test-UIDs entfernen (`test-limit-*`, `test-race-*`,
`test-size-*`):

```bash
ssh <user>@<host>
cd hans-dither.de
mysql -h localhost -u <db-user> -p <db> \
  -e "DELETE FROM users WHERE uid LIKE 'test-limit-%' OR uid LIKE 'test-race-%' OR uid LIKE 'test-size-%'"
rm -rf uploads/test-limit-* uploads/test-race-* uploads/test-size-*
```

---

## Checkliste

| # | Test | SC | Erwartung | OK |
|---|------|----|-----------|----|
| 1 | 12 Bilder hochladen | SC-001 | alle 201 | ☑ |
| 1 | 13. Bild | SC-001 | 403 | ☑ |
| 1 | 5 gleichzeitige Requests um letzten Slot | SC-001, FR-011 | genau 1× 201, 4× 403 | ☑ |
| 2 | exakt 300 KB | SC-003 | 201 | ☑ |
| 2 | 300 KB + 1 Byte | SC-003 | 413 | ☑ |
| 3 | falsches Magic | SC-002 | 400 | ☑ |
| 3 | korrektes Magic, kaputter Rest | SC-002, R3 | 400 | ☑ |
| 4 | 5 Schema-Verletzungen | SC-004 | alle 400, feldspezifische Meldung | ☑ |
| 5 | 4 Kategorien im Vergleich | SC-005 | alle 4 unterscheidbar | ☑ (aus obigen Läufen: 403/413/400×2, alle mit unterschiedlichem Fehlertext) |
| 6 | Re-Upload bei erreichtem Limit | SC-006 | 201, Anzahl bleibt 12 | ☑ |

**Durchgeführt am 2026-07-20 gegen https://www.hans-dither.de** (Produktion,
nach Deployment). Test-UIDs (`test-limit-*`, `test-race-*`, `test-size-*`)
und ihre Upload-Verzeichnisse wurden anschließend per SSH aufgeräumt und
verifiziert (0 verbleibende Test-Einträge in der DB).

Wenn alle Haken gesetzt sind, ist die Härtung bereit für
`/speckit-tasks` → Implementierung.
