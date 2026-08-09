# ADR-038: Backend-Dateinamen aus `client_image_id` statt separatem Namensfeld

## Status
✅ **Umgesetzt** – `UploadHandler::handleUpload()`, `Renderer`, `download.php`

## Kontext
Spec 009 verlangt, dass Backend-Dateien (Tile-Daten, Positionsdaten,
gerenderte Bilder) nach dem auf dem Playdate vergebenen Projektnamen
benannt werden statt nach der internen, zufällig erzeugten Server-UUID
(`image_id`). Der Projektname selbst wird auf dem Gerät nirgends direkt
zum Backend übertragen — `frames.json` enthält zwar ein `name`-Feld, das
Backend liest es aber bislang nicht aus, und es müsste zusätzlich erst
filesystemsicher sanitisiert werden.

## Entscheidungs-Treiber
- **Bereits vorhandene, validierte Datenquelle:** `Source/ImageStore.lua`
  (`sanitizeName()`) erzeugt bereits seit v0.3.0 aus dem Projektnamen eine
  filesystemsichere ID (Kleinbuchstaben, `a-z0-9-`, Fallback `"unnamed"`) —
  dieselbe ID dient lokal als `saves/<id>/`-Ordnername.
- **Bereits seit Spec 004 im Sync-Protokoll vorhanden:** `Source/
  SyncService.lua` sendet diese ID bei jedem Upload als `image_id`-Feld;
  `backend/public/upload.php` validiert sie serverseitig erneut gegen
  `^[a-z0-9\-]{1,64}$` und speichert sie als `client_image_id` in der
  `images`-Tabelle (`UNIQUE (uid, client_image_id)` seit
  `002_sync_extensions.sql`, Spec 004).
- **Einfachheit (Constitution IV):** Ein zusätzliches, separat aus
  `frames.json` zu parsendes `name`-Feld wäre eine zweite, redundante
  Wahrheitsquelle für dieselbe Information.
- **Sicherheit:** Die Whitelist-Validierung von `client_image_id` existiert
  bereits und deckt den neuen Verwendungszweck (Dateiname statt nur
  DB-Lookup-Schlüssel) ab, ohne Änderung.

## Optionen

| Option | Vorteile | Nachteile |
|--------|----------|-----------|
| **A: `client_image_id` als Dateibasis wiederverwenden** | Kein neues Feld, keine neue Migration, bereits validiert und eindeutig pro UID | Setzt voraus, dass Uploads über den Sync-Pfad (mit `image_id`-Feld) laufen — bei manuellem Web-Upload ohne dieses Feld ist ein Fallback nötig |
| B: `name` aus `frames.json` parsen und in neuer DB-Spalte persistieren | Funktioniert auch ohne `client_image_id` | Zweite, redundante Wahrheitsquelle; erfordert eigene Sanitisierung + Kollisionsbehandlung; neue Migration |
| C: Backend-Adressierung (`/download/{typ}/{id}`) direkt auf `client_image_id` umstellen | Ein Bezeichner für alles | Scope-Erweiterung über den Feature-Wunsch hinaus ("nenne die Dateien", nicht "die URLs"); `client_image_id` ist optional und nicht global eindeutig über UIDs hinweg — ungeeignet als alleiniger Adressierungsschlüssel |

## Entscheidung
**Option A: `$base = $client_image_id ?? $image_id` als Basis aller
Backend-Dateinamen**

### Begründung
1. `client_image_id` ist bereits serverseitig validiert (Whitelist-Regex)
   und bereits eindeutig pro UID (`UNIQUE`-Constraint) — keine neue
   Validierungs- oder Kollisionslogik nötig.
2. Die interne `image_id` (DB-Primärschlüssel) bleibt unverändert die
   Grundlage für URL-Adressierung und Berechtigungsprüfung — nur Datei-
   und Downloadnamen ändern sich (spec.md FR-008).
3. Fehlt `client_image_id` (z. B. manueller Web-Upload ohne dieses Feld),
   fällt die Basis auf die bisherige `image_id` zurück — der Upload wird
   nicht abgelehnt (spec.md FR-007).

### Konsequenzen
- **Positiv:** Keine neue Migration, kein neues Feld, sofort nutzbar für
  jedes Projekt, das über den bestehenden Sync-Pfad hochgeladen wurde.
- **Negativ / Korrekturaufwand:** Der Update-in-place-Zweig von
  `handleUpload()` aktualisierte bisher nur `png_path`/`gif_path`, nicht
  `pdi_path`/`json_path` — da diese sich nun je nach `client_image_id`
  ändern können, musste die UPDATE-Anweisung erweitert werden (sonst hätte
  die DB nach der ersten Umbenennung eines Bestandsprojekts auf nicht mehr
  existierende Dateien gezeigt, research.md R4). Zusätzlich müssen bei
  jedem Re-Sync abgeleitete Render-Artefakte ohne eigene DB-Cache-Spalte
  (Frame-PNGs ab Index 1, Tilemap-PNG) aktiv gelöscht werden, da sie sonst
  nach einem Re-Sync mit geändertem Inhalt unbegrenzt veraltet weiter
  ausgeliefert würden.
- **Bekannte Grenze:** Bereits vor Spec 009 hochgeladene Dateien werden
  nicht rückwirkend umbenannt; die neue Benennung greift erst beim
  nächsten Upload desselben Projekts (spec.md Assumptions, bewusst
  akzeptiert).

## Alternativen Considered
Siehe Options-Tabelle oben — vollständige Herleitung in
`specs/009-tile-cleanup-png-export/research.md` R3/R4.

## Related
- [ADR-005: Tile-Kompaktierung vor Save](../09-architekturentscheidungen.md)
- [specs/009-tile-cleanup-png-export/research.md: R3/R4](../../specs/009-tile-cleanup-png-export/research.md)
- [specs/009-tile-cleanup-png-export/data-model.md: Abschnitt 2](../../specs/009-tile-cleanup-png-export/data-model.md)
- [specs/004-backend-sync/data-model.md: client_image_id](../../specs/004-backend-sync/plan.md)
