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

        // 4a. Update-in-place: existiert bereits ein Eintrag für (uid, client_image_id)?
        $existing_image_id = null;
        if ($client_image_id !== null && $client_image_id !== '') {
            $existing = db()->query(
                'SELECT id FROM images WHERE uid = ? AND client_image_id = ?',
                $uid, $client_image_id
            );
            if ($existing && !empty($existing)) {
                $existing_image_id = $existing[0]['id'];
            }
        }

        // 5. Image-ID bestimmen: bestehende Server-UUID (Update) oder neue (Neuanlage)
        $image_id = $existing_image_id ?? self::generateUUID();

        // 6. Dateien speichern (überschreibt bei Update-in-place dieselben Pfade)
        $pdi_path = $upload_dir . '/' . $image_id . '.pdi';
        $json_path = $upload_dir . '/' . $image_id . '.json';

        if (!move_uploaded_file($pdi_file['tmp_name'], $pdi_path)) {
            return ['status' => 'error', 'error' => 'Konnte PDI-Datei nicht speichern', 'http_code' => 500];
        }

        if (!move_uploaded_file($json_file['tmp_name'], $json_path)) {
            if ($existing_image_id === null) {
                unlink($pdi_path);
            }
            return ['status' => 'error', 'error' => 'Konnte JSON-Datei nicht speichern', 'http_code' => 500];
        }

        // 7. DB-Eintrag erstellen oder aktualisieren
        if ($existing_image_id !== null) {
            // Update-in-place: PNG/GIF zurücksetzen -> Neu-Rendering beim nächsten Abruf
            $success = db()->execute(
                'UPDATE images SET png_path = NULL, gif_path = NULL, uploaded_at = NOW() WHERE id = ?',
                $image_id
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
            return ['status' => 'error', 'error' => 'Fehler beim Speichern in Datenbank', 'http_code' => 500];
        }

        // 8. PNG asynchron generieren (on-demand, nicht sofort)

        return [
            'status' => 'success',
            'image_id' => $image_id,
            'message' => $existing_image_id !== null ? 'Aktualisierung erfolgreich. PNG wird neu generiert.' : 'Upload erfolgreich. PNG wird generiert.',
            'http_code' => 201
        ];
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
