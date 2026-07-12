<?php
/**
 * Hans Dither Backend - Upload Handler
 * 
 * Verarbeitet POST-Requests zum Hochladen von PDI- und JSON-Dateien.
 */

require_once __DIR__ . '/../includes/config.php';
require_once __DIR__ . '/../includes/database.php';
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/upload_handler.php';
require_once __DIR__ . '/../includes/validation.php';

// Nur POST-Requests erlaubt
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('HTTP/1.1 405 Method Not Allowed');
    echo json_encode(['error' => 'Nur POST-Requests erlaubt']);
    exit;
}

// UID und Token aus Formular oder Header
$uid = $_POST['uid'] ?? '';
$token = $_POST['token'] ?? ($_SERVER['HTTP_X_SESSION_TOKEN'] ?? '');

// Authentifizierung prüfen
if (empty($uid) || empty($token)) {
    header('HTTP/1.1 401 Unauthorized');
    echo json_encode(['error' => 'UID und Token erforderlich']);
    exit;
}

// Token validieren
$session = Auth::validateToken($token);
if (!$session || $session['uid'] !== $uid) {
    header('HTTP/1.1 401 Unauthorized');
    echo json_encode(['error' => 'Nicht autorisiert - Ungültiges Token']);
    exit;
}

// Dateien prüfen
if (!isset($_FILES['pdi']) || !isset($_FILES['json'])) {
    header('HTTP/1.1 400 Bad Request');
    echo json_encode(['error' => 'PDI- und JSON-Datei erforderlich']);
    exit;
}

// Upload verarbeiten
$result = UploadHandler::handleUpload($uid, $_FILES['pdi'], $_FILES['json']);

// Response
header('Content-Type: application/json');
http_response_code($result['http_code'] ?? 201);
echo json_encode($result);
