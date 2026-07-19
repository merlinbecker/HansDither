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

function isWebFormSubmission(): bool {
    return (($_POST['web'] ?? '') === '1');
}

function redirectToImages(string $uid, string $token, string $query = ''): void {
    $base = '/images?uid=' . urlencode($uid) . '&token=' . urlencode($token);
    header('Location: ' . $base . $query);
    exit;
}

// Nur POST-Requests erlaubt
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    if (isWebFormSubmission()) {
        header('Location: /');
        exit;
    }
    header('HTTP/1.1 405 Method Not Allowed');
    echo json_encode(['error' => 'Nur POST-Requests erlaubt']);
    exit;
}

// UID und Token aus Formular oder Header
$uid = $_POST['uid'] ?? '';
$token = $_POST['token'] ?? ($_SERVER['HTTP_X_SESSION_TOKEN'] ?? '');

// Authentifizierung prüfen
if (empty($uid) || empty($token)) {
    if (isWebFormSubmission()) {
        header('Location: /');
        exit;
    }
    header('HTTP/1.1 401 Unauthorized');
    echo json_encode(['error' => 'UID und Token erforderlich']);
    exit;
}

// Token validieren
$session = Auth::validateToken($token);
if (!$session || $session['uid'] !== $uid) {
    if (isWebFormSubmission()) {
        header('Location: /login?uid=' . urlencode($uid) . '&error=invalid');
        exit;
    }
    header('HTTP/1.1 401 Unauthorized');
    echo json_encode(['error' => 'Nicht autorisiert - Ungültiges Token']);
    exit;
}

// Dateien prüfen
if (!isset($_FILES['pdi']) || !isset($_FILES['json'])) {
    if (isWebFormSubmission()) {
        redirectToImages($uid, $token, '&error=invalid');
    }
    header('HTTP/1.1 400 Bad Request');
    echo json_encode(['error' => 'PDI- und JSON-Datei erforderlich']);
    exit;
}

// Optionale lokale Bild-ID vom Playdate (Spec 004, Update-in-place, research.md R9);
// defensiv validiert, damit sie unverändert als client_image_id gespeichert wird
$client_image_id = $_POST['image_id'] ?? null;
if ($client_image_id !== null && !preg_match('/^[a-z0-9\-]{1,64}$/', $client_image_id)) {
    $client_image_id = null;
}

// Upload verarbeiten
$result = UploadHandler::handleUpload($uid, $_FILES['pdi'], $_FILES['json'], $client_image_id);

if (isWebFormSubmission()) {
    if (($result['status'] ?? 'error') === 'success') {
        redirectToImages($uid, $token, '&upload=ok');
    }
    redirectToImages($uid, $token, '&error=invalid');
}

// Response
header('Content-Type: application/json');
http_response_code($result['http_code'] ?? 201);
echo json_encode($result);
