# Backend-API manuell testen (ohne Playdate)

Kompletter End-to-End-Durchlauf gegen das deployte Backend mit `curl`.
Reihenfolge entspricht dem echten Sync-Workflow: Pairing → Login → Upload →
Liste → Downloads (PDI/JSON/PNG/GIF) → Logout.

> Diese Datei wird nicht deployt (`*.md` ist im deploy.sh-Upload ausgeschlossen).

## 0. Setup: Variablen und Testdateien

```bash
BASE="https://www.hans-dither.de"
UID_TEST="test-device-001"
PIN="1234"
```

**Testdateien erzeugen** (echtes Playdate-PDI-Format, kein Gerät nötig).
Erzeugt `sheet.pdi` mit 3 Tiles (weiß, schwarz, Schachbrett) und eine
`frames.json` mit 2 Animationsframes:

```bash
python3 - <<'EOF'
import json, struct, zlib

# --- sheet.pdi: 48x16 px = 3 Tiles à 16x16 (Spec 001: Tile 1 = weiß, 2 = schwarz) ---
w, h, stride = 48, 16, 6
rows = []
for y in range(h):
    bits = ""
    for x in range(w):
        if x < 16:   bit = 1                        # Tile 1: weiß
        elif x < 32: bit = 0                        # Tile 2: schwarz
        else:        bit = 1 if (x + y) % 2 == 0 else 0  # Tile 3: Schachbrett
        bits += str(bit)
    rows.append(bits.ljust(stride * 8, "0"))

color = b"".join(
    bytes(int(row[i:i+8], 2) for i in range(0, stride * 8, 8)) for row in rows
)
cell = struct.pack("<8H", w, h, stride, 0, 0, 0, 0, 0) + color

# komprimierte Variante (wie playdate.datastore.writeImage sie schreibt)
pdi = (b"Playdate IMG" + struct.pack("<I", 0x80000000)
       + struct.pack("<4I", len(cell), w, h, 0) + zlib.compress(cell))
open("sheet.pdi", "wb").write(pdi)

# --- frames.json: 25x15-Grid, 2 Frames ---
f1 = [1] * 375
f1[0], f1[1] = 2, 3          # oben links: schwarz + Schachbrett
f2 = [2] * 375               # Frame 2: komplett schwarz
json.dump({"version": 1, "name": "curl-test", "gridWidth": 25, "gridHeight": 15,
           "tileCount": 3, "frames": [f1, f2]}, open("frames.json", "w"))

# --- Negativ-Fixture: kein Playdate-Format ---
open("fake.pdi", "wb").write(b"PDI\x00" + b"A" * 64)
print("OK: sheet.pdi, frames.json, fake.pdi erzeugt")
EOF
```

---

## 1. Erreichbarkeit & Sicherheit (FR-001, S-08, T048/T049)

```bash
# Startseite erreichbar (200, HTML mit UID-Formular)
curl -s -o /dev/null -w "%{http_code}\n" "$BASE/"

# HTTP → HTTPS Redirect (301)
curl -s -o /dev/null -w "%{http_code}\n" "http://www.hans-dither.de/"

# Secrets dürfen NICHT abrufbar sein (jeweils 403 oder 404 — niemals 200!)
for p in .deploy.env deploy.sh includes/config.php includes/database.php \
         storage/php_error.log uploads/ .gitignore; do
  printf "%-28s → %s\n" "$p" "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/$p")"
done
```

**Erwartung:** `/` = 200, HTTP-Redirect = 301, alle Secret-Pfade = 403/404.

---

## 2. Pairing — neue Verknüpfung (US1, E-02)

```bash
# Happy Path: unbekannte UID + 4-stellige PIN → 201
curl -s -w "\nHTTP %{http_code}\n" -X POST "$BASE/pair" \
  -d "uid=$UID_TEST" -d "pin=$PIN"
```

**Erwartung:** `{"status":"success", ...}` mit HTTP 201.

**Fehlerfälle (FR-004, SC-005, T055):**

```bash
# Leere UID → 400
curl -s -w "\nHTTP %{http_code}\n" -X POST "$BASE/pair" -d "uid=" -d "pin=1234"

# Nicht-numerische PIN → 400
curl -s -w "\nHTTP %{http_code}\n" -X POST "$BASE/pair" -d "uid=other-uid" -d "pin=abcd"

# PIN zu kurz/lang → 400
curl -s -w "\nHTTP %{http_code}\n" -X POST "$BASE/pair" -d "uid=other-uid" -d "pin=123"
curl -s -w "\nHTTP %{http_code}\n" -X POST "$BASE/pair" -d "uid=other-uid" -d "pin=12345"

# UID mit Sonderzeichen/Traversal → 400
curl -s -w "\nHTTP %{http_code}\n" -X POST "$BASE/pair" \
  --data-urlencode "uid=../../etc/passwd" -d "pin=1234"

# Bereits verknüpfte UID erneut → 409
curl -s -w "\nHTTP %{http_code}\n" -X POST "$BASE/pair" -d "uid=$UID_TEST" -d "pin=9999"
```

---

## 3. Login & Session-Token (US2, E-03)

```bash
# Login → 200 mit session_token
LOGIN=$(curl -s -X POST "$BASE/login" -d "uid=$UID_TEST" -d "pin=$PIN")
echo "$LOGIN"

# Token extrahieren (ohne jq)
TOKEN=$(echo "$LOGIN" | python3 -c "import sys,json; print(json.load(sys.stdin)['session_token'])")
echo "TOKEN=$TOKEN"
```

**Rate-Limiting (FR-007) — mit einer Wegwerf-UID testen, sonst sperrst du dich aus:**

```bash
curl -s -X POST "$BASE/pair" -d "uid=ratelimit-test" -d "pin=1111" > /dev/null
for i in 1 2 3 4; do
  curl -s -o /dev/null -w "Versuch $i: HTTP %{http_code}\n" \
    -X POST "$BASE/login" -d "uid=ratelimit-test" -d "pin=0000"
done
```

**Erwartung:** Versuch 1–2 = 400, Versuch 3 = 429 (Sperre greift), Versuch 4 = 429.
Nach 5 Minuten ist die UID wieder frei.

---

## 4. Upload (US2/004, E-04, FR-013)

```bash
# Happy Path: echtes PDI + JSON → 201 mit image_id
UPLOAD=$(curl -s -X POST "$BASE/upload.php" \
  -H "X-Session-Token: $TOKEN" \
  -F "uid=$UID_TEST" \
  -F "pdi=@sheet.pdi" \
  -F "json=@frames.json")
echo "$UPLOAD"
IMAGE_ID=$(echo "$UPLOAD" | python3 -c "import sys,json; print(json.load(sys.stdin)['image_id'])")
echo "IMAGE_ID=$IMAGE_ID"
```

**Fehlerfälle:**

```bash
# Ohne Token → 401
curl -s -w "\nHTTP %{http_code}\n" -X POST "$BASE/upload.php" \
  -F "uid=$UID_TEST" -F "pdi=@sheet.pdi" -F "json=@frames.json"

# Ungültiges PDI (falsches Magic) → 400 "Ungültige PDI-Datei"
curl -s -w "\nHTTP %{http_code}\n" -X POST "$BASE/upload.php" \
  -H "X-Session-Token: $TOKEN" -F "uid=$UID_TEST" \
  -F "pdi=@fake.pdi" -F "json=@frames.json"

# Kaputtes JSON → 400
echo '{not json' > broken.json
curl -s -w "\nHTTP %{http_code}\n" -X POST "$BASE/upload.php" \
  -H "X-Session-Token: $TOKEN" -F "uid=$UID_TEST" \
  -F "pdi=@sheet.pdi" -F "json=@broken.json"

# Datei > 10MB → 413
dd if=/dev/zero bs=1m count=11 2>/dev/null | \
  { printf 'Playdate IMG'; cat; } > big.pdi
curl -s -w "\nHTTP %{http_code}\n" -X POST "$BASE/upload.php" \
  -H "X-Session-Token: $TOKEN" -F "uid=$UID_TEST" \
  -F "pdi=@big.pdi" -F "json=@frames.json"
```

---

## 5. Images-Liste (US3, E-05)

```bash
# JSON-Variante (wie das Playdate/Skripte sie nutzen)
curl -s -H "Accept: application/json" -H "X-Session-Token: $TOKEN" \
  "$BASE/images?uid=$UID_TEST" | python3 -m json.tool

# HTML-Variante im Browser:
echo "$BASE/images?uid=$UID_TEST&token=$TOKEN"
```

**Erwartung:** `images`-Array mit `id`, `pdi_url`, `json_url`, `png_url`, `gif_url`.

```bash
# Ohne/mit falschem Token → 401
curl -s -o /dev/null -w "%{http_code}\n" "$BASE/images?uid=$UID_TEST"
curl -s -o /dev/null -w "%{http_code}\n" "$BASE/images?uid=$UID_TEST&token=00000000-0000-4000-8000-000000000000"
```

---

## 6. Downloads: PDI, JSON, PNG, GIF (E-06 … E-09)

```bash
curl -s -o out.pdi  "$BASE/download/pdi/$IMAGE_ID?token=$TOKEN"
curl -s -o out.json "$BASE/download/json/$IMAGE_ID?token=$TOKEN"
curl -s -o out.png  "$BASE/download/png/$IMAGE_ID?token=$TOKEN"
curl -s -o out.gif  "$BASE/download/gif/$IMAGE_ID?token=$TOKEN"

file out.pdi out.json out.png out.gif
cmp sheet.pdi out.pdi && echo "PDI: identisch mit Upload ✓"
```

**Erwartung:**
- `out.pdi` identisch zur hochgeladenen Datei
- `out.png`: `PNG image data, 400 x 240` — zeigt Frame 1 (oben links ein
  schwarzes und ein Schachbrett-Tile, Rest weiß)
- `out.gif`: `GIF image data ... 400 x 240` — animiert: Frame 1 wie PNG,
  Frame 2 komplett schwarz, Endlos-Loop (im Browser/Vorschau öffnen)

```bash
# Berechtigungen: fremde/unbekannte Image-ID → 404
curl -s -o /dev/null -w "%{http_code}\n" \
  "$BASE/download/pdi/00000000-0000-4000-8000-000000000000?token=$TOKEN"

# Ungültiges ID-Format → 400
curl -s -o /dev/null -w "%{http_code}\n" "$BASE/download/pdi/../etc/passwd?token=$TOKEN"
```

---

## 7. Logout (Session-Invalidierung)

```bash
curl -s -o /dev/null -w "%{http_code}\n" "$BASE/logout?token=$TOKEN"   # 302 → /

# Token ist danach ungültig → 401
curl -s -o /dev/null -w "%{http_code}\n" "$BASE/images?uid=$UID_TEST&token=$TOKEN"
```

---

## 8. Aufräumen (optional)

> **SSH-Hinweis (all-inkl.com):** Der Login landet im Account-**Home**, nicht im
> Webroot. Erst in den Domain-Ordner wechseln: `cd hans-dither.de` — dort liegen
> `includes/`, `uploads/`, `storage/` etc.

Test-UIDs (`test-device-001`, `ratelimit-test`) samt Uploads per SSH entfernen:

```bash
ssh <user>@<host>
cd hans-dither.de                      # ← Webroot, nicht das Home!
mysql -h localhost -u <db-user> -p <db> \
  -e "DELETE FROM users WHERE uid IN ('test-device-001','ratelimit-test')"
rm -rf uploads/test-device-001 uploads/ratelimit-test
# FK ON DELETE CASCADE räumt images + sessions automatisch mit ab
```

---

## Checkliste

| # | Test | Erwartung | OK |
|---|------|-----------|----|
| 1 | Startseite / HTTPS-Redirect | 200 / 301 | ☐ |
| 1 | Secret-Pfade | alle 403/404 | ☐ |
| 2 | Pairing happy path | 201 | ☐ |
| 2 | Pairing-Validierung (PIN/UID) | 400 / 409 | ☐ |
| 3 | Login + Token | 200 + `session_token` | ☐ |
| 3 | Rate-Limit nach 3 Fehlversuchen | 429 | ☐ |
| 4 | Upload happy path | 201 + `image_id` | ☐ |
| 4 | Upload-Validierung | 401 / 400 / 413 | ☐ |
| 5 | Images-Liste (JSON + HTML) | 200, alle 4 URLs | ☐ |
| 6 | PDI-Roundtrip | Datei identisch | ☐ |
| 6 | PNG 400×240 (Frame 1) | korrekt gerendert | ☐ |
| 6 | GIF animiert (2 Frames, Loop) | korrekt gerendert | ☐ |
| 7 | Logout invalidiert Token | 302, danach 401 | ☐ |

Wenn alle Haken gesetzt sind, ist das Backend bereit für die Playdate-Anbindung
(Spec 004: Upload-Flow vom Gerät).
