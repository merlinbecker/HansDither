# Contract Amendment: E-05/E-06/E-08/E-09 — PNG-Export statt PDI-Download, projektbasierte Dateinamen (Spec 009)

**Amendment zu**: [`specs/005-backend-service/contracts/backend-api.md`](../../005-backend-service/contracts/backend-api.md)
(bereits einmal ergänzt durch
[`specs/007-backend-upload-hardening/contracts/upload-hardening.md`](../../007-backend-upload-hardening/contracts/upload-hardening.md)
für E-04 — davon ist hier nichts betroffen)

Dieses Dokument ändert/ergänzt E-05, E-06 (entfällt), E-08, E-09. Alle
anderen Endpunkte (E-01 bis E-04, E-07) bleiben unverändert. Wo dieses
Dokument einer Zeile aus `backend-api.md` widerspricht, gilt diese Fassung
als aktuell.

---

## E-05: GET `/images` — GEÄNDERT

Ergänzt/ersetzt die Felder je Bild-Objekt:

```json
{
  "status": "success",
  "uid": "{uid}",
  "images": [
    {
      "id": "{uuid}",
      "uploaded_at": "{ISO-8601-Timestamp}",
      "has_png": true/false,
      "has_gif": true/false,
      "frame_count": 3,
      "json_url": "/download/json/{uuid}",
      "png_url": "/download/png/{uuid}",
      "tilemap_url": "/download/tilemap/{uuid}",
      "gif_url": "/download/gif/{uuid}"
    }
  ]
}
```

- **ENTFERNT**: `pdi_url` (FR-012 — kein PDI-Download mehr angeboten).
- **NEU**: `frame_count` (Integer, `>= 1`) — Anzahl der Animationsframes
  dieses Bildes, aus `frames.json` abgeleitet (data-model.md Abschnitt 4).
  Consumer bilden daraus Frame-Download-URLs als
  `{png_url}?frame={0..frame_count-1}` (0-basiert, spec.md Clarifications).
- **NEU**: `tilemap_url` — Download-URL für die Tilemap-PNG (E-08b).
- `png_url` bleibt unverändert der Standard-Frame (`frame=0`, kein
  `frame`-Parameter nötig).

**Web-Oberfläche** (`showImagesPage()`): Die Tabellenspalte "PDI" entfällt;
statt einer einzelnen Vorschau je Zeile wird pro Bild eine kleine Galerie
mit `frame_count` Vorschau-/Downloadlinks angezeigt (einer je Frame,
`?frame=N&inline=1` für die Vorschau, ohne `inline` für den Download);
zusätzlich ein Downloadlink für die Tilemap-PNG.

---

## E-06: GET `/download/pdi/{id}` — ENTFÄLLT

**Zweck vorher**: PDI-Binärdatei herunterladen.

**GEÄNDERT (FR-012/FR-013/FR-014)**: Die Route bleibt technisch erreichbar
(kein Routing-404 "unbekannter Typ"), liefert aber für JEDEN
authentifizierten, autorisierten Request:

**Response (410 Gone)**:
```json
{"error": "PDI-Download nicht mehr verfügbar"}
```

Auth-/Berechtigungsprüfung (401/404) laufen unverändert VOR dieser Antwort,
identisch zur Prüfreihenfolge aller anderen `/download/{typ}/{id}`-Routen —
kein neuer, schwächer geschützter Pfad. Die frühere Auslieferungsfunktion
(`deliverPdi()`) wird aus dem Code entfernt (kein toter Code, Constitution
IV, Präzedenzfall AD-037).

Die interne Verwendung der PDI-Datei (Tile-Extraktion für das Rendering,
`Renderer::loadAssets()`) ist von dieser Änderung NICHT betroffen — sie ist
kein Download-Endpunkt und bleibt vollständig erhalten.

---

## E-08: GET `/download/png/{id}` — GEÄNDERT (Frame-Auswahl)

**Zweck**: Gerendertes PNG eines einzelnen Frames herunterladen (vorher:
immer der erste Frame).

**Request**:
- Methode: GET
- Header: `X-Session-Token: {token}` (required)
- Parameter:
  - `id` (URL-Path): Image-UUID
  - `frame` (Query, optional, **NEU**): 0-basierter Frame-Index (spec.md
    Clarifications: "`frame=N`, N=0 = bisherige Vorschau"). Fehlt der
    Parameter, gilt `frame=0` (identisch zum bisherigen alleinigen
    Verhalten — rückwärtskompatibel, bestehende Links bleiben gültig).
  - `inline` (Query, optional): unverändert (`1` = `inline`-Disposition
    für `<img>`-Vorschau statt `attachment`)

**Validierung** (ergänzt Punkt 1-3 aus E-06/analog):
4. `frame` MUSS, falls angegeben, eine Ganzzahl zwischen `0` und
   `frame_count - 1` des Bildes sein (data-model.md Abschnitt 3)

**Response (200 OK)**:
- Content-Type: `image/png`
- Content-Disposition: `{attachment|inline}; filename="{base}.png"`
  (Frame 0) oder `filename="{base}-frame-{N}.png"` (Frame N ≥ 1) —
  `{base}` = `client_image_id` oder Fallback `{id}` (data-model.md
  Abschnitt 2)
- Body: PNG-Binärdaten (400×240, 1-Bit) des angeforderten Frames

**Fehler** (ergänzt E-06/E-08-Fehlerliste):
- 401 Unauthorized: `{"error": "Nicht autorisiert"}` *(unverändert)*
- 404 Not Found: `{"error": "Image nicht gefunden"}` *(unverändert)*
- **NEU** 400 Bad Request: `{"error": "Ungültiger Frame-Index"}`
  (`frame` fehlerhaft oder außerhalb `0..frame_count-1`)
- 500 Internal Server Error: `{"error": "PNG konnte nicht generiert werden"}`
  *(unverändert)*

**Hinweis**: Frame 0 wird weiterhin bei Bedarf on-demand erzeugt und über
die bestehende `png_path`-Spalte als bereits-generiert markiert. Frames
≥ 1 werden ebenfalls on-demand erzeugt, aber NICHT in der Datenbank
zwischengespeichert — der Pfad ist aus `id`/`client_image_id` + `frame`
deterministisch, ein Dateisystem-Check (`file_exists()`) ersetzt die
DB-Abfrage (data-model.md Abschnitt 3, research.md R5).

---

## E-08b: GET `/download/tilemap/{id}` — NEU

**Zweck**: Die Tile-Sammlung (Tilemap/Imagetable) eines Bildes als PNG in
der Playdate-SDK-Namenskonvention für Matrix-Imagetables herunterladen
(FR-011).

**Request**:
- Methode: GET
- Header: `X-Session-Token: {token}` (required)
- Parameter: `id` (URL-Path): Image-UUID; `inline` (Query, optional)

**Validierung**: Analog zu E-08 (Auth, Image-Existenz, Berechtigung) —
kein `frame`-Parameter (die Tilemap ist frame-unabhängig).

**Response (200 OK)**:
- Content-Type: `image/png`
- Content-Disposition:
  `{attachment|inline}; filename="{base}-table-16-16.png"`
- Body: PNG-Binärdaten — die Tile-Sammlung als Matrix-Imagetable-Bild
  (Breite = min(tileCount, 25) × 16, Höhe = ⌈tileCount / 25⌉ × 16,
  identisch zur Sheet-Geometrie aus `ImageStoreCodec.getSheetDimensions()`,
  research.md R6). Die Datei ist ohne Umbenennung per
  `playdate.graphics.imagetable.new("{base}")` in ein anderes
  Playdate-SDK-Projekt ladbar, sofern sie unter diesem Namen im
  `images`-Ordner des Zielprojekts abgelegt wird.

**Fehler**: Analog zu E-08 (401/404/500), kein 400 (kein `frame`-Parameter).

---

## E-09: GET `/download/gif/{id}` — GEÄNDERT (nur Dateiname)

**Request/Validierung/Response**: Unverändert (Auth, Berechtigung,
Content-Type, GIF89a-Inhalt).

**GEÄNDERT**: `Content-Disposition`-Dateiname ist jetzt `{base}.gif`
(vorher fehlerhaft `{id}.pdi.gif`, research.md R5) — `{base}` wie in E-08
definiert.

---

## Unverändert

- E-01 bis E-04 (inkl. der Spec-007-Erweiterungen), E-07 (`/download/json/{id}`)
- Request-Format, Authentifizierung, Fehlerformat (`{"error": "..."}`)
- `C-01`/`S-01..S-11` (Datei-Format- und Sicherheits-Contracts) — ergänzt um
  eine neue Sicherheits-Zeile, siehe `docs/architecture/security-review-backend.md`
  (geplant, siehe plan.md Architecture Governance)
