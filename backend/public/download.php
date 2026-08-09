<?php
/**
 * Hans Dither Backend - Download Handler
 * 
 * Stellt PDI-, JSON- und PNG-Dateien zum Download bereit.
 */

require_once __DIR__ . '/../includes/config.php';
require_once __DIR__ . '/../includes/database.php';
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/upload_handler.php';
require_once __DIR__ . '/../includes/renderer.php';

// Request-Pfad analysieren
$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

// Token aus Query-Parameter oder Header
$token = $_GET['token'] ?? ($_SERVER['HTTP_X_SESSION_TOKEN'] ?? null);

// Pfad-Muster: /download/{type}/{id}
$path_parts = explode('/', trim($path, '/'));

if (count($path_parts) < 3 || $path_parts[0] !== 'download') {
    header('HTTP/1.1 404 Not Found');
    echo json_encode(['error' => 'Route nicht gefunden']);
    exit;
}

$type = $path_parts[1] ?? '';
$id = $path_parts[2] ?? '';
$inline = (($_GET['inline'] ?? '') === '1');

if (empty($type) || empty($id) || !preg_match('/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i', $id)) {
    header('HTTP/1.1 400 Bad Request');
    echo json_encode(['error' => 'Ungültige Image-ID']);
    exit;
}

// Authentifizierung prüfen
if (empty($token)) {
    header('HTTP/1.1 401 Unauthorized');
    echo json_encode(['error' => 'Token erforderlich']);
    exit;
}

$session = Auth::validateToken($token);
if (!$session) {
    header('HTTP/1.1 401 Unauthorized');
    echo json_encode(['error' => 'Ungültiges Token']);
    exit;
}

$uid = $session['uid'];

// Image prüfen
$image = UploadHandler::getImage($id, $uid);
if (!$image) {
    header('HTTP/1.1 404 Not Found');
    echo json_encode(['error' => 'Image nicht gefunden oder keine Berechtigung']);
    exit;
}

// Datei ausliefern
switch ($type) {
    case 'pdi':
        // Spec 009 FR-012/013/014: PDI-Download entfällt vollständig aus
        // der Nutzer-Oberfläche/API; deliverPdi() wurde entfernt (kein
        // toter Code, research.md R7). 410 statt 404 — der Typ ist bewusst
        // entfernt, nicht unbekannt. Läuft NACH der Auth-/Berechtigungs-
        // prüfung oben, identisch zur Reihenfolge aller anderen Typen.
        header('HTTP/1.1 410 Gone');
        echo json_encode(['error' => 'PDI-Download nicht mehr verfügbar']);
        break;

    case 'json':
        deliverJson($image);
        break;

    case 'png':
        deliverPng($image, $uid, $inline);
        break;

    case 'tilemap':
        deliverTilemap($image, $uid, $inline);
        break;

    case 'gif':
        deliverGif($image, $uid, $inline);
        break;

    default:
        header('HTTP/1.1 400 Bad Request');
        echo json_encode(['error' => 'Ungültiger Dateityp']);
        break;
}

/**
 * Liefert eine JSON-Datei aus
 */
function deliverJson(array $image): void {
    if (!file_exists($image['json_path'])) {
        header('HTTP/1.1 404 Not Found');
        echo json_encode(['error' => 'JSON-Datei nicht gefunden']);
        exit;
    }
    
    header('Content-Type: application/json');
    header('Content-Disposition: attachment; filename="' . basename($image['json_path']) . '"');
    header('Content-Length: ' . filesize($image['json_path']));
    header('Cache-Control: no-cache, must-revalidate');
    header('Pragma: public');
    
    readfile($image['json_path']);
    exit;
}

/**
 * Liefert die PNG-Datei eines einzelnen Frames aus (generiert on-demand
 * wenn nötig) — Spec 009 FR-010, contracts E-08.
 *
 * Frame-Index ist 0-basiert (spec.md Clarifications, ?frame=N, N=0 =
 * bisherige Vorschau); fehlt der Parameter, gilt frame=0.
 */
function deliverPng(array $image, string $uid, bool $inline = false): void {
    $frame_count = UploadHandler::getFrameCount($image);
    if ($frame_count === null) {
        header('HTTP/1.1 500 Internal Server Error');
        echo json_encode(['error' => 'Frame-Anzahl konnte nicht ermittelt werden']);
        exit;
    }

    $frame_param = $_GET['frame'] ?? '0';
    if (!ctype_digit((string)$frame_param)) {
        header('HTTP/1.1 400 Bad Request');
        echo json_encode(['error' => 'Ungültiger Frame-Index']);
        exit;
    }
    $frame = (int)$frame_param;
    if ($frame < 0 || $frame >= $frame_count) {
        header('HTTP/1.1 400 Bad Request');
        echo json_encode(['error' => 'Ungültiger Frame-Index']);
        exit;
    }

    $png_path = Renderer::renderFrameToPng($image['id'], $uid, $frame);
    if ($png_path === false) {
        header('HTTP/1.1 500 Internal Server Error');
        echo json_encode(['error' => 'PNG konnte nicht generiert werden']);
        exit;
    }

    if (!file_exists($png_path)) {
        header('HTTP/1.1 404 Not Found');
        echo json_encode(['error' => 'PNG-Datei nicht gefunden']);
        exit;
    }

    $disposition = $inline ? 'inline' : 'attachment';
    header('Content-Type: image/png');
    header('Content-Disposition: ' . $disposition . '; filename="' . basename($png_path) . '"');
    header('Content-Length: ' . filesize($png_path));
    header('Cache-Control: no-cache, must-revalidate');
    header('Pragma: public');

    readfile($png_path);
    exit;
}

/**
 * Liefert die Tilemap-PNG aus (SDK-Namenskonvention, generiert on-demand
 * wenn nötig) — Spec 009 FR-011, contracts E-08b.
 */
function deliverTilemap(array $image, string $uid, bool $inline = false): void {
    $tilemap_path = Renderer::renderTilemapToPng($image['id'], $uid);
    if ($tilemap_path === false) {
        header('HTTP/1.1 500 Internal Server Error');
        echo json_encode(['error' => 'Tilemap-PNG konnte nicht generiert werden']);
        exit;
    }

    if (!file_exists($tilemap_path)) {
        header('HTTP/1.1 404 Not Found');
        echo json_encode(['error' => 'Tilemap-PNG nicht gefunden']);
        exit;
    }

    $disposition = $inline ? 'inline' : 'attachment';
    header('Content-Type: image/png');
    header('Content-Disposition: ' . $disposition . '; filename="' . basename($tilemap_path) . '"');
    header('Content-Length: ' . filesize($tilemap_path));
    header('Cache-Control: no-cache, must-revalidate');
    header('Pragma: public');

    readfile($tilemap_path);
    exit;
}

/**
 * Liefert ein animiertes GIF aus (generiert on-demand wenn nötig)
 */
function deliverGif(array $image, string $uid, bool $inline = false): void {
    $gif_path = $image['gif_path'] ?? null;

    if (empty($gif_path) || !file_exists($gif_path)) {
        $gif_path = Renderer::renderToGif($image['id'], $uid);
        if ($gif_path === false) {
            header('HTTP/1.1 500 Internal Server Error');
            echo json_encode(['error' => 'GIF konnte nicht generiert werden']);
            exit;
        }
    }

    $disposition = $inline ? 'inline' : 'attachment';
    header('Content-Type: image/gif');
    header('Content-Disposition: ' . $disposition . '; filename="' . basename($gif_path) . '"');
    header('Content-Length: ' . filesize($gif_path));
    header('Cache-Control: no-cache, must-revalidate');
    header('Pragma: public');

    readfile($gif_path);
    exit;
}
