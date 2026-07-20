<?php
/**
 * Hans Dither Backend - Datenbank-Verbindung
 * 
 * Stellt eine sichere MySQLi-Verbindung mit Prepared Statements bereit.
 */

require_once __DIR__ . '/config.php';

class Database {
    private $connection;
    private static $instance = null;
    
    private function __construct() {
        // Verbindung herstellen
        $this->connection = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME, (int)DB_PORT);
        
        if ($this->connection->connect_error) {
            $this->logError('Datenbank-Verbindungsfehler: ' . $this->connection->connect_error);
            self::failWithDbError();
        }
        
        // Zeichenkodierung setzen
        $this->connection->set_charset('utf8mb4');
    }
    
    /**
     * Singleton-Instanz abrufen
     */
    public static function getInstance(): Database {
        if (self::$instance === null) {
            self::$instance = new Database();
        }
        return self::$instance;
    }
    
    /**
     * Prepared Statement vorbereiten
     * 
     * @param string $query SQL-Query mit Platzhaltern (?)
     * @return mysqli_stmt
     */
    public function prepare(string $query): mysqli_stmt {
        $stmt = $this->connection->prepare($query);
        if (!$stmt) {
            $this->logError('Prepare-Fehler: ' . $this->connection->error . ' - Query: ' . $query);
            self::failWithDbError();
        }
        return $stmt;
    }

    /**
     * Bricht den Request mit HTTP 500 und nutzerfreundlicher Meldung ab
     * (Edge Case spec.md: "Datenbankfehler — bitte später erneut versuchen")
     */
    private static function failWithDbError(): void {
        if (!headers_sent()) {
            http_response_code(500);
            header('Content-Type: application/json');
        }
        die(json_encode(['error' => 'Datenbankfehler — bitte später erneut versuchen']));
    }
    
    /**
     * Query mit Parametern ausführen (für SELECT)
     * 
     * @param string $query SQL-Query mit Platzhaltern
     * @param mixed ...$params Parameter
     * @return array|bool Ergebniszeilen oder false bei Fehler
     */
    public function query(string $query, ...$params) {
        $stmt = $this->prepare($query);
        
        if (!empty($params)) {
            $types = $this->getTypes($params);
            $stmt->bind_param($types, ...$params);
        }
        
        if (!$stmt->execute()) {
            $this->logError('Execute-Fehler: ' . $stmt->error);
            $stmt->close();
            return false;
        }

        $result = $stmt->get_result();
        if (!$result) {
            // Für INSERT/UPDATE/DELETE
            $affected = $stmt->affected_rows > 0;
            $stmt->close();
            return $affected;
        }

        $rows = [];
        while ($row = $result->fetch_assoc()) {
            $rows[] = $row;
        }

        $stmt->close();
        // Leeres SELECT-Ergebnis MUSS [] liefern (nicht true) — sonst kippt
        // jede empty()/count()-Prüfung der Aufrufer (uidExists, login, validateToken)
        return $rows;
    }
    
    /**
     * Einfache Abfrage ohne Parameter (für SELECT)
     */
    public function querySimple(string $query) {
        $result = $this->connection->query($query);
        if (!$result) {
            $this->logError('Query-Fehler: ' . $this->connection->error);
            return false;
        }
        
        $rows = [];
        while ($row = $result->fetch_assoc()) {
            $rows[] = $row;
        }

        return $rows;
    }
    
    /**
     * Skalarwert abrufen (z.B. für COUNT, MAX, etc.)
     */
    public function queryScalar(string $query, ...$params) {
        $result = $this->query($query, ...$params);
        if ($result === false) {
            return false;
        }
        
        if (is_array($result) && !empty($result)) {
            $first = reset($result);
            return reset($first);
        }
        
        return $result;
    }
    
    /**
     * INSERT/UPDATE/DELETE ausführen
     */
    public function execute(string $query, ...$params): bool {
        $stmt = $this->prepare($query);
        
        if (!empty($params)) {
            $types = $this->getTypes($params);
            $stmt->bind_param($types, ...$params);
        }
        
        $success = $stmt->execute();
        if (!$success) {
            $this->logError('Execute-Fehler: ' . $stmt->error);
        }
        
        $stmt->close();
        return $success;
    }
    
    /**
     * Transaktion starten (Spec 007, AD-033: race-safer Upload-Zähl-Check)
     */
    public function beginTransaction(): bool {
        return $this->connection->begin_transaction();
    }

    /**
     * Transaktion committen
     */
    public function commit(): bool {
        return $this->connection->commit();
    }

    /**
     * Transaktion zurückrollen
     */
    public function rollback(): bool {
        return $this->connection->rollback();
    }

    /**
     * Letzte Insert-ID abrufen
     */
    public function getInsertId(): int {
        return $this->connection->insert_id;
    }
    
    /**
     * Anzahl betroffener Zeilen
     */
    public function getAffectedRows(): int {
        return $this->connection->affected_rows;
    }
    
    /**
     * Typen-String für bind_param generieren
     */
    private function getTypes(array $params): string {
        $types = '';
        foreach ($params as $param) {
            if (is_int($param)) {
                $types .= 'i';
            } elseif (is_float($param)) {
                $types .= 'd';
            } elseif (is_string($param)) {
                $types .= 's';
            } elseif (is_null($param)) {
                $types .= 's';
            } else {
                $types .= 's';
            }
        }
        return $types;
    }
    
    /**
     * Fehler loggen
     */
    private function logError(string $message): void {
        $log_dir = __DIR__ . '/../logs';
        if (!is_dir($log_dir)) {
            mkdir($log_dir, 0755, true);
        }
        
        $log_file = $log_dir . '/db_errors.log';
        $timestamp = date('Y-m-d H:i:s');
        file_put_contents($log_file, "[$timestamp] $message\n", FILE_APPEND);
    }
    
    /**
     * Verbindung schließen
     */
    public function close(): void {
        if ($this->connection) {
            $this->connection->close();
        }
    }
    
    /**
     * Prüfen ob Tabelle existiert
     */
    public function tableExists(string $tableName): bool {
        $result = $this->querySimple("SHOW TABLES LIKE '$tableName'");
        return is_array($result) && count($result) > 0;
    }
}

// Hilfsfunktion für einfache Abfragen
function db() {
    return Database::getInstance();
}
