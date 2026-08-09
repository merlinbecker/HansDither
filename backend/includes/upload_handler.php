<?php
/**
 * Hans Dither Backend - Upload-Handler
 * 
 * Verwaltet das Hochladen und Speichern von PDI- und JSON-Dateien.
 */

require_once __DIR__ . '/database.php';
require_once __DIR__ . '/validation.php';
require_once __DIR__ . '/auth.php';

class UploadHandler {
    
    /**
     * Verarbeitet einen Upload-Request
     *
     * @param string $uid UID des Nutzers
     * @param array $pdi_file $_FILES-Array für PDI-Datei
     * @param array $json_file $_FILES-Array für JSON-Datei
     * @param string|null $client_image_id Optionale lokale Bild-ID vom Playdate (Spec 004,
     *        research.md R9). Bekannt aus einem vorherigen Upload derselben UID -> bestehender
     *        Eintrag wird aktualisiert (Update-in-place) statt ein Duplikat anzulegen. Fehlt der
     *        Parameter, bleibt das Verhalten exakt wie zuvor (immer Neuanlage).
     * @return array Ergebnis
     */
    public static function handleUpload(string $uid, array $pdi_file, array $json_file, ?string $client_image_id = null): array {
        // 1. UID prüfen
        if (!Auth::uidExists($uid)) {
            return ['status' => 'error', 'error' => 'UID nicht gefunden', 'http_code' => 404];
        }

        // 2. PDI-Datei validieren
        $pdi_validation = Validation::validateUploadedFile($pdi_file);
        if (!$pdi_validation['valid']) {
            return ['status' => 'error', 'error' => $pdi_validation['error'], 'http_code' => $pdi_validation['http_code'] ?? 400];
        }

        // 3. JSON-Datei validieren
        $json_validation = Validation::validateUploadedFile($json_file);
        if (!$json_validation['valid']) {
            return ['status' => 'error', 'error' => $json_validation['error'], 'http_code' => $json_validation['http_code'] ?? 400];
        }

        // 4. Upload-Verzeichnis für UID erstellen
        $upload_dir = UPLOADS_DIR . '/' . $uid;
        if (!is_dir($upload_dir)) {
            if (!mkdir($upload_dir, 0755, true)) {
                return ['status' => 'error', 'error' => 'Konnte Upload-Verzeichnis nicht erstellen', 'http_code' => 500];
            }
        }

        // Ab hier: Transaktion mit Row-Lock auf den UID-eigenen users-Datensatz
        // (Spec 007, AD-033) — serialisiert gleichzeitige Uploads derselben UID,
        // damit der Zähl-Check unten (4b) race-sicher ist (FR-011). Validierung
        // (Schritte 2/3) und Verzeichnis-Anlage (Schritt 4) laufen bewusst VOR der
        // Transaktion, damit der Lock nicht länger als nötig gehalten wird.
        db()->beginTransaction();
        db()->query('SELECT uid FROM users WHERE uid = ? FOR UPDATE', $uid);

        // 4a. Update-in-place: existiert bereits ein Eintrag für (uid, client_image_id)?
        // Spec 009 research.md R4: pdi_path/json_path/png_path/gif_path werden
        // hier zusätzlich mitgelesen (nicht nur id) — sie werden als "alte"
        // Pfade gebraucht, um nach einer Umbenennung (Schritt 6) verwaiste
        // Dateien aufzuräumen (Schritt 8b); nach dem UPDATE in Schritt 7 wären
        // sie nicht mehr abrufbar.
        $existing_image_id = null;
        $old_pdi_path = null;
        $old_json_path = null;
        $old_png_path = null;
        $old_gif_path = null;
        if ($client_image_id !== null && $client_image_id !== '') {
            $existing = db()->query(
                'SELECT id, pdi_path, json_path, png_path, gif_path FROM images WHERE uid = ? AND client_image_id = ?',
                $uid, $client_image_id
            );
            if ($existing && !empty($existing)) {
                $existing_image_id = $existing[0]['id'];
                $old_pdi_path = $existing[0]['pdi_path'];
                $old_json_path = $existing[0]['json_path'];
                $old_png_path = $existing[0]['png_path'];
                $old_gif_path = $existing[0]['gif_path'];
            }
        }

        // 4b. Upload-Obergrenze prüfen (Spec 007, FR-001/FR-002/FR-011) — NUR bei
        // Neuanlage; Update-in-place (4a hat einen Treffer geliefert) erzeugt
        // keinen zusätzlichen Speicherplatz-Slot und bleibt vom Limit unberührt
        // (FR-003).
        if ($existing_image_id === null) {
            $count = db()->queryScalar('SELECT COUNT(*) FROM images WHERE uid = ?', $uid);
            if ($count >= 12) {
                db()->rollback();
                return ['status' => 'error', 'error' => 'Upload-Limit erreicht (maximal 12 Bilder pro Gerät)', 'http_code' => 403];
            }
        }

        // 5. Image-ID bestimmen: bestehende Server-UUID (Update) oder neue (Neuanlage)
        $image_id = $existing_image_id ?? self::generateUUID();

        // 6. Dateien speichern (überschreibt bei Update-in-place dieselben Pfade)
        // Spec 009 FR-006/FR-007: Dateiname basiert auf dem vom Gerät
        // übermittelten, aus dem Playdate-Projektnamen abgeleiteten Bezeichner
        // (client_image_id) statt der internen Zufalls-ID; fehlt er, Fallback
        // auf die bisherige ID (research.md R3). client_image_id ist bereits in
        // upload.php gegen ^[a-z0-9\-]{1,64}$ validiert — kein Pfad-/
        // Verzeichnistraversierungs-Risiko (FR-009). Die interne $image_id
        // bleibt unverändert der DB-Primärschlüssel für Adressierung/
        // Berechtigungsprüfung (FR-008).
        $base = $client_image_id ?? $image_id;
        $pdi_path = $upload_dir . '/' . $base . '.pdi';
        $json_path = $upload_dir . '/' . $base . '.json';

        if (!move_uploaded_file($pdi_file['tmp_name'], $pdi_path)) {
            db()->rollback();
            return ['status' => 'error', 'error' => 'Konnte PDI-Datei nicht speichern', 'http_code' => 500];
        }

        if (!move_uploaded_file($json_file['tmp_name'], $json_path)) {
            if ($existing_image_id === null) {
                unlink($pdi_path);
            }
            db()->rollback();
            return ['status' => 'error', 'error' => 'Konnte JSON-Datei nicht speichern', 'http_code' => 500];
        }

        // 7. DB-Eintrag erstellen oder aktualisieren
        if ($existing_image_id !== null) {
            // Update-in-place: pdi_path/json_path MÜSSEN mit aktualisiert werden
            // (Spec 009 research.md R4 — sonst zeigt die DB nach einer
            // Umbenennung auf nicht mehr existierende Dateien, da Schritt 6 sie
            // bereits neu berechnet hat). png_path/gif_path bleiben NULL — das
            // ist die bestehende Cache-Invalidierung für den Standard-Frame
            // (frame=0) und das GIF, auf die sich der Renderer weiterhin
            // verlässt; NICHT versehentlich entfernen.
            $success = db()->execute(
                'UPDATE images SET pdi_path = ?, json_path = ?, png_path = NULL, gif_path = NULL, uploaded_at = NOW() WHERE id = ?',
                $pdi_path, $json_path, $image_id
            );
        } else {
            $success = db()->execute(
                'INSERT INTO images (id, uid, client_image_id, pdi_path, json_path, png_path) VALUES (?, ?, ?, ?, ?, NULL)',
                $image_id, $uid, $client_image_id, $pdi_path, $json_path
            );
        }

        if (!$success) {
            if ($existing_image_id === null) {
                unlink($pdi_path);
                unlink($json_path);
            }
            db()->rollback();
            return ['status' => 'error', 'error' => 'Fehler beim Speichern in Datenbank', 'http_code' => 500];
        }

        db()->commit();

        // 8. Aufräumen NACH dem Commit (Spec 009, research.md R4) — bewusst
        // ausserhalb der Transaktion: verlorene Render-Artefakte werden beim
        // nächsten Abruf verlustfrei neu gerendert, ein Rollback träfe sonst
        // auf bereits gelöschte, nicht zurücknehmbare Dateien.
        if ($existing_image_id !== null) {
            // Umbenennung (Basis hat sich seit dem letzten Sync geändert):
            // alte pdi_path/json_path/png_path/gif_path best-effort löschen,
            // sonst blieben verwaiste Alt-Dateien im UID-Verzeichnis liegen.
            if ($old_pdi_path !== null && $old_pdi_path !== $pdi_path) {
                foreach ([$old_pdi_path, $old_json_path, $old_png_path, $old_gif_path] as $stale_path) {
                    if ($stale_path && file_exists($stale_path)) {
                        @unlink($stale_path);
                    }
                }
            }

            // Bei JEDEM Re-Sync (nicht nur bei Umbenennung): vorhandene
            // Frame-≥1-/Tilemap-PNGs für die AKTUELLE Basis löschen — sie
            // besitzen keine DB-Spalte, die sie sonst als veraltet markieren
            // könnte, und würden sonst nach einem Re-Sync mit geändertem
            // Inhalt unbegrenzt weiter ausgeliefert.
            foreach ((glob($upload_dir . '/' . $base . '-frame-*.png') ?: []) as $stale_frame) {
                @unlink($stale_frame);
            }
            $stale_tilemap = $upload_dir . '/' . $base . '-table-16-16.png';
            if (file_exists($stale_tilemap)) {
                @unlink($stale_tilemap);
            }
        }

        // 9. PNG asynchron generieren (on-demand, nicht sofort)

        return [
            'status' => 'success',
            'image_id' => $image_id,
            'message' => $existing_image_id !== null ? 'Aktualisierung erfolgreich. PNG wird neu generiert.' : 'Upload erfolgreich. PNG wird generiert.',
            'http_code' => 201
        ];
    }
    
    /**
     * Ermittelt die Anzahl der Animationsframes eines Images aus der
     * bereits gespeicherten frames.json (Spec 009, data-model.md
     * Abschnitt 4) — kein neues DB-Feld, rein abgeleitet. Genutzt für die
     * Frame-Index-Validierung beim PNG-Download (download.php) und für
     * die Galerie-Anzeige in der Bilder-Liste (index.php).
     *
     * @param array $image Image-Datensatz (json_path)
     * @return int|null Frame-Anzahl oder null, falls nicht ermittelbar
     */
    public static function getFrameCount(array $image): ?int {
        if (empty($image['json_path']) || !file_exists($image['json_path'])) {
            return null;
        }
        $raw = file_get_contents($image['json_path']);
        if ($raw === false) {
            return null;
        }
        $data = json_decode($raw, true);
        if (!is_array($data) || !isset($data['frames']) || !is_array($data['frames'])) {
            return null;
        }
        return count($data['frames']);
    }

    /**
     * Generiert eine UUID v4
     *
     * @return string
     */
    public static function generateUUID(): string {
        $data = random_bytes(16);
        
        // Setze Version 4 (UUID v4) und Variante
        $data[6] = chr(ord($data[6]) & 0x0f | 0x40);
        $data[8] = chr(ord($data[8]) & 0x3f | 0x80);
        
        return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
    }
    
    /**
     * Lädt ein Image aus der Datenbank
     * 
     * @param string $image_id Image-UUID
     * @param string $uid UID des Nutzers (für Berechtigungsprüfung)
     * @return array|false Image-Daten oder false
     */
    public static function getImage(string $image_id, string $uid) {
        $images = db()->query(
            'SELECT id, uid, pdi_path, json_path, png_path, gif_path, uploaded_at FROM images WHERE id = ? AND uid = ?',
            $image_id, $uid
        );
        
        if (!$images || empty($images)) {
            return false;
        }
        
        return $images[0];
    }
    
    /**
     * Lädt alle Images für eine UID
     * 
     * @param string $uid UID des Nutzers
     * @return array Liste der Images
     */
    public static function getAllImages(string $uid): array {
        $images = db()->query(
            'SELECT id, uid, pdi_path, json_path, png_path, gif_path, uploaded_at FROM images WHERE uid = ? ORDER BY uploaded_at DESC',
            $uid
        );
        
        return $images ?: [];
    }
    
    /**
     * Löscht ein Image
     * 
     * @param string $image_id Image-UUID
     * @param string $uid UID des Nutzers (für Berechtigungsprüfung)
     * @return bool
     */
    public static function deleteImage(string $image_id, string $uid): bool {
        // Image-Daten abrufen
        $image = self::getImage($image_id, $uid);
        if (!$image) {
            return false;
        }
        
        // Dateien löschen
        $files_to_delete = [$image['pdi_path'], $image['json_path']];
        if ($image['png_path']) {
            $files_to_delete[] = $image['png_path'];
        }
        if (!empty($image['gif_path'])) {
            $files_to_delete[] = $image['gif_path'];
        }
        
        foreach ($files_to_delete as $file) {
            if (file_exists($file)) {
                unlink($file);
            }
        }
        
        // DB-Eintrag löschen
        return db()->execute('DELETE FROM images WHERE id = ? AND uid = ?', $image_id, $uid);
    }
    
    /**
     * Speichert den PNG-Pfad in der Datenbank
     * 
     * @param string $image_id Image-UUID
     * @param string $png_path Pfad zur PNG-Datei
     * @return bool
     */
    public static function savePngPath(string $image_id, string $png_path): bool {
        return db()->execute(
            'UPDATE images SET png_path = ? WHERE id = ?',
            $png_path, $image_id
        );
    }

    /**
     * Speichert den GIF-Pfad in der Datenbank
     *
     * @param string $image_id Image-UUID
     * @param string $gif_path Pfad zur GIF-Datei
     * @return bool
     */
    public static function saveGifPath(string $image_id, string $gif_path): bool {
        return db()->execute(
            'UPDATE images SET gif_path = ? WHERE id = ?',
            $gif_path, $image_id
        );
    }
    
    /**
     * Prüft ob ein Image einem Nutzer gehört
     * 
     * @param string $image_id Image-UUID
     * @param string $uid UID des Nutzers
     * @return bool
     */
    public static function isImageOwner(string $image_id, string $uid): bool {
        return self::getImage($image_id, $uid) !== false;
    }
}
