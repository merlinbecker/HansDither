<?php
/**
 * Hans Dither Backend - Authentifizierung
 * 
 * Veraltet PIN-Authentifizierung, Session-Management und Rate-Limiting.
 */

require_once __DIR__ . '/database.php';

class Auth {
    
    /**
     * Nutzer mit UID und PIN verknüpfen (erster Zugriff)
     * 
     * @param string $uid Playdate-Geräte-ID
     * @param string $pin 4-stellige PIN
     * @return array Ergebnis
     */
    public static function pair(string $uid, string $pin): array {
        // Validierung
        if (empty($uid)) {
            return ['status' => 'error', 'error' => 'UID darf nicht leer sein', 'http_code' => 400];
        }

        if (!self::isValidUid($uid)) {
            return ['status' => 'error', 'error' => 'Ungültige UID. Erlaubt: Buchstaben, Ziffern, "-", "_" (max. 64 Zeichen)', 'http_code' => 400];
        }

        if (!preg_match(PIN_REGEX, $pin)) {
            return ['status' => 'error', 'error' => 'PIN muss genau ' . PIN_LENGTH . ' Ziffern enthalten', 'http_code' => 400];
        }
        
        // Prüfen ob UID bereits existiert (Race Condition Schutz)
        $existing = db()->query('SELECT uid, confirmed_at FROM users WHERE uid = ?', $uid);
        $pin_hash = password_hash($pin, PASSWORD_BCRYPT);

        if ($existing && is_array($existing) && count($existing) > 0) {
            // Spec 004: Die PIN wird vom Playdate generiert, nicht vom Nutzer gewählt — überträgt
            // der Nutzer beim Pairing versehentlich eine andere PIN als die auf dem Gerät gezeigte,
            // kann sich das Gerät nie erfolgreich einloggen. Solange noch kein erfolgreicher Login
            // stattgefunden hat (confirmed_at IS NULL), ist die Verknüpfung daher überschreibbar —
            // erst ein bestätigtes Pairing ist vor Übernahme geschützt (research.md R12).
            if ($existing[0]['confirmed_at'] !== null) {
                return ['status' => 'error', 'error' => 'UID bereits verknüpft', 'http_code' => 409];
            }

            $success = db()->execute(
                'UPDATE users SET pin_hash = ?, failed_attempts = 0, locked_until = NULL WHERE uid = ?',
                $pin_hash, $uid
            );
        } else {
            $success = db()->execute(
                'INSERT INTO users (uid, pin_hash, failed_attempts, locked_until) VALUES (?, ?, 0, NULL)',
                $uid, $pin_hash
            );
        }

        if (!$success) {
            return ['status' => 'error', 'error' => 'Fehler beim Speichern', 'http_code' => 500];
        }

        return ['status' => 'success', 'message' => 'Verknüpfung erfolgreich hergestellt', 'uid' => $uid, 'http_code' => 201];
    }
    
    /**
     * Anmeldung mit bestehender UID und PIN
     * 
     * @param string $uid Playdate-Geräte-ID
     * @param string $pin 4-stellige PIN
     * @return array Ergebnis mit Session-Token
     */
    public static function login(string $uid, string $pin): array {
        if (!self::isValidUid($uid)) {
            return ['status' => 'error', 'error' => 'Ungültige UID', 'http_code' => 400];
        }

        // Nutzer finden
        $user = db()->query('SELECT uid, pin_hash, failed_attempts, locked_until FROM users WHERE uid = ?', $uid);
        
        if (!$user || empty($user)) {
            return ['status' => 'error', 'error' => 'UID nicht gefunden', 'http_code' => 404];
        }
        
        $user = $user[0];
        
        // Sperrung prüfen
        if ($user['locked_until'] && new DateTime($user['locked_until']) > new DateTime()) {
            return ['status' => 'error', 'error' => 'Zu viele Fehlversuche. Bitte in 5 Minuten erneut versuchen', 'http_code' => 429];
        }
        
        // PIN prüfen
        if (!password_verify($pin, $user['pin_hash'])) {
            // Fehlversuch zählen
            $failed_attempts = $user['failed_attempts'] + 1;
            
            if ($failed_attempts >= MAX_FAILED_ATTEMPTS) {
                // Account sperren
                $lockout_time = date('Y-m-d H:i:s', time() + LOCKOUT_DURATION);
                db()->execute(
                    'UPDATE users SET failed_attempts = ?, locked_until = ? WHERE uid = ?',
                    $failed_attempts, $lockout_time, $uid
                );
                return ['status' => 'error', 'error' => 'Zu viele Fehlversuche. Bitte in 5 Minuten erneut versuchen', 'http_code' => 429];
            } else {
                // Fehlversuche erhöhen
                db()->execute(
                    'UPDATE users SET failed_attempts = ? WHERE uid = ?',
                    $failed_attempts, $uid
                );
                return ['status' => 'error', 'error' => 'UID oder PIN ungültig', 'http_code' => 400];
            }
        }
        
        // Erfolg - Session erstellen
        $token = self::generateToken();
        $expires_at = date('Y-m-d H:i:s', time() + SESSION_TIMEOUT);
        
        // Session speichern
        db()->execute(
            'INSERT INTO sessions (token, uid, expires_at) VALUES (?, ?, ?)',
            $token, $uid, $expires_at
        );
        
        // Fehlversuche zurücksetzen + Verknüpfung als bestätigt markieren (research.md R12) —
        // ab hier verweigert pair() ein Überschreiben dieser UID (Schutz vor Übernahme)
        db()->execute(
            'UPDATE users SET failed_attempts = 0, locked_until = NULL, confirmed_at = COALESCE(confirmed_at, NOW()) WHERE uid = ?',
            $uid
        );
        
        return [
            'status' => 'success',
            'session_token' => $token,
            'expires_at' => $expires_at,
            'uid' => $uid,
            'http_code' => 200
        ];
    }
    
    /**
     * Session-Token validieren
     * 
     * @param string $token Session-Token
     * @return array|false Ergebnis mit UID oder false
     */
    public static function validateToken(string $token) {
        if (empty($token)) {
            return false;
        }
        
        $session = db()->query(
            'SELECT token, uid, expires_at FROM sessions WHERE token = ? AND expires_at > NOW()',
            $token
        );
        
        if (!$session || empty($session)) {
            return false;
        }
        
        return ['uid' => $session[0]['uid'], 'token' => $session[0]['token']];
    }
    
    /**
     * Session-Token ungültig machen
     * 
     * @param string $token Session-Token
     */
    public static function invalidateToken(string $token): void {
        db()->execute('DELETE FROM sessions WHERE token = ?', $token);
    }
    
    /**
     * Alle abgelaufenen Sessions bereinigen
     */
    public static function cleanupSessions(): int {
        $result = db()->execute('DELETE FROM sessions WHERE expires_at < NOW()');
        return db()->getAffectedRows();
    }
    
    /**
     * Session-Token generieren (UUID v4)
     * 
     * @return string
     */
    private static function generateToken(): string {
        $data = random_bytes(16);
        
        // Setze Version 4 (UUID v4) und Variante
        $data[6] = chr(ord($data[6]) & 0x0f | 0x40);
        $data[8] = chr(ord($data[8]) & 0x3f | 0x80);
        
        return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
    }
    
    /**
     * Prüft das UID-Format gegen die Whitelist (contracts S-01, data-model VARCHAR(64))
     *
     * @param string $uid Playdate-Geräte-ID
     * @return bool
     */
    public static function isValidUid(string $uid): bool {
        return preg_match(UID_REGEX, $uid) === 1;
    }

    /**
     * Prüfen ob UID existiert
     *
     * @param string $uid Playdate-Geräte-ID
     * @return bool
     */
    public static function uidExists(string $uid): bool {
        $user = db()->query('SELECT uid FROM users WHERE uid = ?', $uid);
        return $user && !empty($user);
    }

    /**
     * Prüft ob eine UID bereits einen erfolgreichen Login hatte (research.md R12).
     * Unbestätigte UIDs dürfen erneut gepaired werden (siehe pair()).
     *
     * @param string $uid Playdate-Geräte-ID
     * @return bool
     */
    public static function isConfirmed(string $uid): bool {
        $user = db()->query('SELECT confirmed_at FROM users WHERE uid = ?', $uid);
        return $user && !empty($user) && $user[0]['confirmed_at'] !== null;
    }
    
    /**
     * Nutzer löschen (inkl. aller Images und Sessions)
     * 
     * @param string $uid Playdate-Geräte-ID
     * @return bool
     */
    public static function deleteUser(string $uid): bool {
        // Foreign Key CASCADE löscht Images und Sessions automatisch
        return db()->execute('DELETE FROM users WHERE uid = ?', $uid);
    }
}
