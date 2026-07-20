# Contract Amendment: E-04 `POST /upload` — Absicherung (Spec 007)

**Amendment zu**: [`specs/005-backend-service/contracts/backend-api.md`
E-04](../../005-backend-service/contracts/backend-api.md#e-04-post-upload--image-hochladen)

Dieses Dokument ändert/ergänzt AUSSCHLIESSLICH E-04. Alle anderen
Endpunkte (E-01 bis E-05+) bleiben unverändert. Wo dieses Dokument einer
Zeile aus `backend-api.md` widerspricht, gilt diese Fassung als aktuell.

---

## Geänderte Validierungsregeln

Ersetzt Punkt 5 und ergänzt Punkt 6/7 der E-04-Validierungsliste:

1. Session-Token oder UID+PIN muss gültig sein *(unverändert)*
2. Dateien müssen `.pdi` und `.json` Endung haben *(unverändert)*
3. **JSON**: `json_decode()` muss erfolgreich sein und ein Objekt/Array
   zurückgeben *(unverändert, Basis-Check bleibt vor dem neuen
   Schema-Check bestehen)*
4. **PDI**: Playdate-SDK-Format (Magic `Playdate IMG`, optional
   zlib-komprimiert); Bilddaten müssen vollständig parsebar sein
   *(unverändert im Verhalten — research.md R3 verifiziert, dass dies
   bereits vollständig strukturell prüft, keine reine Endungsprüfung)*
5. **GEÄNDERT** — Dateigrößen: Max. **300 KB** pro Datei (vorher 10 MB;
   research.md R2), gilt für PDI UND JSON je einzeln, nicht als Summe
6. **NEU** — JSON-Schema: die dekodierte JSON-Struktur muss dem in
   `data-model.md` definierten `frames.json`-Schema entsprechen
   (`version`, `name`, `gridWidth=25`, `gridHeight=15`, `tileCount`,
   `frames[1..12]` à exakt 375 Tile-Indizes im gültigen Bereich;
   research.md R4)
7. **NEU** — Upload-Obergrenze: die UID darf zum Zeitpunkt des Requests
   noch nicht 12 unterschiedliche Bilder besitzen (Zählung via
   `COUNT(*) FROM images WHERE uid = ?`, race-safe innerhalb einer
   Transaktion mit Row-Lock; research.md R1). Ausnahme: Update-in-place
   einer bereits bekannten `client_image_id` zählt NICHT gegen das
   Limit (FR-003).

Prüfreihenfolge (für konsistente Fehlerpriorität bei mehreren
Verletzungen gleichzeitig, korrigiert bei der T024-Implementierungsprüfung
gegen den tatsächlichen Code in `Validation::validateUploadedFile()`):
Auth (401) → Dateigröße (413) → Dateiendung (400) → PDI-Struktur (400) →
JSON-Syntax (400) → JSON-Schema (400) → Upload-Limit (403). Die
Größenprüfung (`$file['size']` aus `$_FILES`, Schritt 2 der bestehenden
Funktion) lief bereits vor Spec 007 vor der Endungsprüfung (Schritt 3) —
unverändertes Verhalten, hier nur präzise dokumentiert. Das Limit wird
zuletzt geprüft, da es den teuersten Prüfschritt (Transaktion + Row-Lock)
darstellt und Requests, die ohnehin an Format/Größe scheitern, ihn nicht
mehr erreichen sollen.

---

## Neue/geänderte Fehler-Responses

Ersetzt den Fehler-Block von E-04 vollständig:

- 401 Unauthorized: `{"error": "Nicht autorisiert"}` (ungültiges
  Token/UID/PIN) *(unverändert)*
- 400 Bad Request: `{"error": "Ungültiger Dateityp"}` (PDI-Magic/-Struktur
  ungültig) *(unverändert)*
- **GEÄNDERT** 413 Payload Too Large:
  `{"error": "Datei zu groß (max. 300KB)"}` (Schwellwert von 10MB auf
  300KB gesenkt, research.md R2)
- **NEU** 400 Bad Request:
  `{"error": "JSON-Struktur ungültig: {konkretes Feld}"}` — Beispiele:
  `{"error": "JSON-Struktur ungültig: gridWidth muss 25 sein"}`,
  `{"error": "JSON-Struktur ungültig: frames[2] hat 370 statt 375 Werte"}`,
  `{"error": "JSON-Struktur ungültig: frames[0][12] = 99 liegt außerhalb von 1..tileCount"}`
  (research.md R4; Nachricht benennt IMMER das konkret verletzte Feld,
  kein generisches "JSON ungültig")
- **NEU** 403 Forbidden:
  `{"error": "Upload-Limit erreicht (maximal 12 Bilder pro Gerät)"}`
  (research.md R1/R5 — bewusst 403 statt 429, da kein Zeit-, sondern ein
  Mengenlimit; ein Retry ohne vorherige Löschung ist nie erfolgreich)
- 429 Too Many Requests: `{"error": "Zu viele Requests"}` (Rate Limiting)
  *(unverändert, weiterhin ausschließlich für zeitbasiertes Limiting,
  NICHT für das neue Mengenlimit — siehe research.md R5 zur Abgrenzung)*

---

## Client-seitige Anzeige (research.md R6) — zwei Verifikationsebenen für SC-005

SC-005 fordert wörtlich vier unterscheidbare Begründungen: "Limit vs.
Größe vs. Format vs. Schema". Dieser Abschnitt legt fest, auf welcher
Ebene diese vier Fälle jeweils unterscheidbar sein müssen, da
`quickstart.md` (Phase 1) SC-005 ausschließlich über `curl` verifiziert
(kein Geräte-UI-Test im Projekt etabliert, Constitution V gilt nur für
`Source/*.lua`-Tests, nicht für UI-Screenshots):

- **API-Ebene (curl, `quickstart.md`)**: Alle vier Fälle sind bereits
  durch unterschiedliche HTTP-Status+Body-Kombinationen unterscheidbar:
  413 (Größe), 400 mit `"Ungültiger Dateityp"` (Format), 400 mit
  `"JSON-Struktur ungültig: {Feld}"` (Schema), 403 (Limit). SC-005 ist
  auf dieser Ebene vollständig erfüllt — dies ist die Ebene, auf der die
  Spec tatsächlich verifiziert wird.
- **Geräte-UI-Ebene (`Source/SyncService.lua`)**: Bewusst NUR Limit und
  Größe bekommen einen eigenen Anzeige-Text (Tabelle unten). Format- und
  Schema-Fehler können durch normale App-Nutzung praktisch NICHT
  auftreten — die App erzeugt PDI/JSON stets lokal korrekt
  (`ImageStoreCodec.lua`); diese beiden Prüfungen sind ausschließlich
  ein Schutz gegen Requests AUSSERHALB der App (der ursprüngliche
  Bedrohungsfall dieser Spec: "jemand mit Kenntnis der Architektur").
  Ein Angreifer, der gezielt fehlerhafte Dateien schickt, sieht ohnehin
  nie den Playdate-Bildschirm — die für IHN relevante Unterscheidung
  liegt bereits auf der API-Ebene vor. Eine fünfte Geräte-Text-Variante
  für einen für legitime Nutzer unerreichbaren Fehlerfall wäre
  zusätzliche, nicht angeforderte Komplexität (Constitution IV).

`Source/SyncService.lua` parst NIEMALS den `error`-Text aus dem
Response-Body zur Anzeige (bestehendes Muster dieser Datei — der Body
wird nur geloggt, nie gerendert). Stattdessen bildet
`attemptUpload()`/`startUpload()` jeden relevanten HTTP-Status auf einen
eigenen, fest codierten, ASCII-only Client-Text ab:

| HTTP-Status | SC-005-Kategorie | `reason` (intern) | Angezeigter Text (Gerät) | Automatischer Retry? |
|---|---|---|---|---|
| 401 | *(Auth, außerhalb SC-005)* | `token_expired` | *(kein eigener Text — löst sofortigen Login-Retry aus)* | Ja, genau einmal |
| 413 | Größe | `too_large` | `"File too large to upload"` | Nein |
| 400 (Format/Schema) | Format / Schema | `upload_failed` *(generischer Zweig, unverändert — auf API-Ebene weiterhin per Body-Text unterscheidbar)* | `"Upload failed"` | Nein |
| **403 (NEU)** | **Limit** | **`limit_reached`** | **`"Upload limit reached (12 images)"`** | **Nein** |

---

## Unverändert

- Request-Format (Multipart, Parameter-Namen, Header) — unverändert
- Erfolgs-Response (201) — unverändert
- Verarbeitungsschritte 1-4 (UUID, Speicherung, DB-Eintrag,
  PNG-Rendering) — unverändert, laufen nach dem neuen Prüfblock wie
  bisher
- Alle anderen Endpunkte (`/pair`, `/login`, `/images`, `/download`) —
  nicht Teil dieser Spec
