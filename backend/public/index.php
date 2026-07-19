<?php
/**
 * Hans Dither Backend - Startseite
 * 
 * Einstiegspunkt: UID-Eingabe, Pairing, Login und Images-Liste
 */

require_once __DIR__ . '/../includes/config.php';
require_once __DIR__ . '/../includes/database.php';
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/upload_handler.php';

// Request-Methode und Pfad analysieren
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);

/**
 * Liest den Session-Token aus Header (X-Session-Token), Query-Parameter oder Cookie
 */
function requestSessionToken(): ?string {
    return $_SERVER['HTTP_X_SESSION_TOKEN'] ?? ($_GET['token'] ?? ($_COOKIE['session_token'] ?? null));
}

/**
 * Web-Formulare markieren sich mit web=1 und erwarten Redirects statt JSON.
 */
function isWebFormSubmission(): bool {
    return ($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST' && (($_POST['web'] ?? '') === '1');
}

// Routing
switch ($path) {
    case '/':
    case '/index.php':
        // Startseite: UID-Eingabe
        showUidForm();
        break;
        
    case '/pair':
        // POST: Neue Verknüpfung herstellen
        if ($method === 'POST') {
            handlePairRequest();
        } else {
            showPairForm();
        }
        break;
        
    case '/login':
        // POST: Bestehende Verknüpfung nutzen
        if ($method === 'POST') {
            handleLoginRequest();
        } else {
            showLoginForm();
        }
        break;
        
    case '/images':
        // GET: Images-Liste anzeigen
        if ($method === 'GET') {
            handleImagesRequest();
        }
        break;
        
    case '/logout':
        // GET: Logout
        handleLogoutRequest();
        break;
        
    default:
        // Unbekannte Route
        header('HTTP/1.1 404 Not Found');
        echo json_encode(['error' => 'Route nicht gefunden']);
        break;
}

/**
 * Zeigt das UID-Eingabeformular
 */
function showUidForm(): void {
    // UID-Routing MUSS vor jeglicher HTML-Ausgabe passieren (header() sonst wirkungslos)
    $error_message = '';
    if (isset($_GET['uid']) && $_GET['uid'] !== '') {
        $uid = trim($_GET['uid']);
        if (!Auth::isValidUid($uid)) {
            $error_message = 'Ungültige UID. Erlaubt: Buchstaben, Ziffern, "-", "_" (max. 64 Zeichen).';
        } elseif (Auth::isConfirmed($uid)) {
            // UID ist bestätigt verknüpft -> zu Login weiterleiten
            header('Location: /login?uid=' . urlencode($uid));
            exit;
        } else {
            // UID existiert noch nicht ODER ist eine unbestätigte Verknüpfung
            // (research.md R12) -> (erneut) zu Pairing weiterleiten
            header('Location: /pair?uid=' . urlencode($uid));
            exit;
        }
    }
    ?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hans Dither - Backend</title>
    <link rel="stylesheet" href="/assets/css/style.css">
</head>
<body>
    <div class="container">
        <h1>Hans Dither Sync</h1>
        <p>Verbinde dein Playdate mit diesem Backend, um deine Zeichnungen zu speichern und herunterzuladen.</p>

        <?php if (!empty($error_message)): ?>
            <div class="error"><?php echo htmlspecialchars($error_message); ?></div>
        <?php endif; ?>

        <form action="/" method="GET" class="form">
            <label for="uid">Playdate UID:</label>
            <input type="text" id="uid" name="uid" placeholder="z. B. pd-abc123def456" required>
            <button type="submit">Weiter</button>
        </form>
    </div>
</body>
</html>
    <?php
}

/**
 * Zeigt das Pairing-Formular (UID + PIN eingeben)
 */
function showPairForm(): void {
    $uid = trim($_GET['uid'] ?? '');
    $error = $_GET['error'] ?? '';

    if (empty($uid) || !Auth::isValidUid($uid)) {
        header('Location: /');
        exit;
    }

    // Bereits bestätigt verknüpfte UIDs nicht erneut pairen lassen (unbestätigte
    // dürfen das, siehe Auth::pair() / research.md R12 — ermöglicht Retry nach
    // einer PIN mit Tippfehler statt permanentem Dead-End)
    if (Auth::isConfirmed($uid)) {
        header('Location: /login?uid=' . urlencode($uid) . '&error=uid_exists');
        exit;
    }

    $error_message = '';
    if ($error === 'invalid') {
        $error_message = 'PIN muss genau 4 Ziffern enthalten.';
    }

    ?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hans Dither - Verknüpfung herstellen</title>
    <link rel="stylesheet" href="/assets/css/style.css">
</head>
<body>
    <div class="container">
        <h1>Verknüpfung herstellen</h1>
        <p>Gib die <strong>auf deinem Playdate angezeigte</strong> 4-stellige PIN ein, um dein Playdate mit UID <strong><?php echo htmlspecialchars($uid); ?></strong> zu verknüpfen. Die PIN erscheint auf dem Playdate-Bildschirm, sobald du dort die Sync-Kurbel-Geste ausführst.</p>

        <?php if (!empty($error_message)): ?>
            <div class="error"><?php echo htmlspecialchars($error_message); ?></div>
        <?php endif; ?>
        
        <form action="/pair" method="POST" class="form">
            <input type="hidden" name="uid" value="<?php echo htmlspecialchars($uid); ?>">
            <input type="hidden" name="web" value="1">
            <label for="pin">4-stellige PIN:</label>
            <input type="password" id="pin" name="pin" pattern="\d{4}" maxlength="4" placeholder="1234" required>
            <button type="submit">Verknüpfen</button>
        </form>
        
        <p><a href="/">Zurück zur UID-Eingabe</a></p>
    </div>
</body>
</html>
    <?php
}

/**
 * Verarbeitet Pairing-Request (POST /pair)
 */
function handlePairRequest(): void {
    $uid = $_POST['uid'] ?? '';
    $pin = $_POST['pin'] ?? '';
    
    $result = Auth::pair($uid, $pin);

    if (isWebFormSubmission()) {
        if ($result['status'] === 'success') {
            header('Location: /login?uid=' . urlencode($uid) . '&paired=1');
            exit;
        }

        if (($result['http_code'] ?? 400) === 409) {
            header('Location: /login?uid=' . urlencode($uid) . '&error=uid_exists');
            exit;
        }

        header('Location: /pair?uid=' . urlencode($uid) . '&error=invalid');
        exit;
    }

    header('Content-Type: application/json');
    http_response_code($result['http_code'] ?? 500);
    echo json_encode($result);
}

/**
 * Zeigt das Login-Formular
 */
function showLoginForm(): void {
    $uid = trim($_GET['uid'] ?? '');
    $error = $_GET['error'] ?? '';
    $paired = $_GET['paired'] ?? '';

    if (empty($uid) || !Auth::isValidUid($uid)) {
        header('Location: /');
        exit;
    }

    // Prüfen ob UID existiert
    if (!Auth::uidExists($uid)) {
        header('Location: /pair?uid=' . urlencode($uid));
        exit;
    }
    
    $error_message = '';
    switch ($error) {
        case 'uid_exists':
            $error_message = 'UID bereits verknüpft. Bitte melde dich an.';
            break;
        case 'locked':
            $error_message = 'Zu viele Fehlversuche. Bitte in 5 Minuten erneut versuchen.';
            break;
        case 'invalid':
            $error_message = 'UID oder PIN ungültig.';
            break;
    }

    $success_message = '';
    if ($paired === '1') {
        $success_message = 'Verknüpfung erfolgreich hergestellt. Bitte jetzt mit deiner PIN anmelden.';
    }
    
    ?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hans Dither - Anmelden</title>
    <link rel="stylesheet" href="/assets/css/style.css">
</head>
<body>
    <div class="container">
        <h1>Anmelden</h1>
        <p>Melde dich mit deiner PIN für UID <strong><?php echo htmlspecialchars($uid); ?></strong> an.</p>
        
        <?php if (!empty($error_message)): ?>
            <div class="error"><?php echo htmlspecialchars($error_message); ?></div>
        <?php endif; ?>

        <?php if (!empty($success_message)): ?>
            <div class="success"><?php echo htmlspecialchars($success_message); ?></div>
        <?php endif; ?>
        
        <form action="/login" method="POST" class="form">
            <input type="hidden" name="uid" value="<?php echo htmlspecialchars($uid); ?>">
            <input type="hidden" name="web" value="1">
            <label for="pin">4-stellige PIN:</label>
            <input type="password" id="pin" name="pin" pattern="\d{4}" maxlength="4" placeholder="1234" required>
            <button type="submit">Anmelden</button>
        </form>
        
        <p><a href="/">Zurück zur UID-Eingabe</a></p>
    </div>
</body>
</html>
    <?php
}

/**
 * Verarbeitet Login-Request (POST /login)
 */
function handleLoginRequest(): void {
    $uid = $_POST['uid'] ?? '';
    $pin = $_POST['pin'] ?? '';
    
    $result = Auth::login($uid, $pin);
    
    if ($result['status'] === 'success') {
        // Session-Token in Cookie speichern (optional, hauptsächlich für Web-UI)
        setcookie('session_token', $result['session_token'], [
            'expires' => strtotime($result['expires_at']),
            'path' => '/',
            'secure' => true,
            'httponly' => true,
            'samesite' => 'Strict'
        ]);

        if (isWebFormSubmission()) {
            header('Location: /images?uid=' . urlencode($uid) . '&token=' . urlencode($result['session_token']));
            exit;
        }

        header('Content-Type: application/json');
        echo json_encode([
            'status' => 'success',
            'session_token' => $result['session_token'],
            'expires_at' => $result['expires_at'],
            'uid' => $uid,
            'redirect' => '/images?uid=' . $uid . '&token=' . $result['session_token']
        ]);
    } else {
        if (isWebFormSubmission()) {
            $code = $result['http_code'] ?? 400;
            $error = $code === 429 ? 'locked' : 'invalid';
            header('Location: /login?uid=' . urlencode($uid) . '&error=' . $error);
            exit;
        }

        header('Content-Type: application/json');
        http_response_code($result['http_code'] ?? 400);
        echo json_encode($result);
    }
}

/**
 * Verarbeitet Images-Request (GET /images)
 */
function handleImagesRequest(): void {
    $uid = trim($_GET['uid'] ?? '');
    $token = requestSessionToken() ?? '';
    
    // Authentifizierung prüfen
    if (empty($uid) || empty($token)) {
        header('HTTP/1.1 401 Unauthorized');
        echo json_encode(['error' => 'Nicht autorisiert - UID und Token erforderlich']);
        return;
    }
    
    // Token validieren
    $session = Auth::validateToken($token);
    if (!$session || $session['uid'] !== $uid) {
        header('HTTP/1.1 401 Unauthorized');
        echo json_encode(['error' => 'Nicht autorisiert - Ungültiges Token']);
        return;
    }
    
    // Images laden
    $images = UploadHandler::getAllImages($uid);
    
    // HTML oder JSON?
    $accept = $_SERVER['HTTP_ACCEPT'] ?? '';
    if (strpos($accept, 'application/json') !== false || isset($_GET['format']) && $_GET['format'] === 'json') {
        // JSON-Response
        header('Content-Type: application/json');
        
        $image_list = [];
        foreach ($images as $image) {
            $image_list[] = [
                'id' => $image['id'],
                'uploaded_at' => $image['uploaded_at'],
                'has_png' => !empty($image['png_path']),
                'has_gif' => !empty($image['gif_path']),
                'pdi_url' => '/download/pdi/' . $image['id'] . '?token=' . $token,
                'json_url' => '/download/json/' . $image['id'] . '?token=' . $token,
                'png_url' => '/download/png/' . $image['id'] . '?token=' . $token,
                'gif_url' => '/download/gif/' . $image['id'] . '?token=' . $token
            ];
        }
        
        echo json_encode([
            'status' => 'success',
            'uid' => $uid,
            'images' => $image_list
        ]);
    } else {
        // HTML-Response
        showImagesPage($uid, $token, $images);
    }
}

/**
 * Zeigt die Images-Liste als HTML
 */
function showImagesPage(string $uid, string $token, array $images): void {
    $uploadStatus = $_GET['upload'] ?? '';
    $uploadError = $_GET['error'] ?? '';
    ?>
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hans Dither - Meine Projekte</title>
    <link rel="stylesheet" href="/assets/css/style.css">
</head>
<body>
    <div class="container">
        <h1>Meine Projekte</h1>
        <p>UID: <strong><?php echo htmlspecialchars($uid); ?></strong></p>
        <p><a href="/logout?token=<?php echo htmlspecialchars($token); ?>">Abmelden</a></p>

        <?php if ($uploadStatus === 'ok'): ?>
            <div class="success">Upload erfolgreich.</div>
        <?php elseif ($uploadError === 'invalid'): ?>
            <div class="error">Upload fehlgeschlagen. Bitte prüfe PDI/JSON und versuche es erneut.</div>
        <?php endif; ?>
        
        <h2>Upload-Formular</h2>
        <form action="/upload.php" method="POST" enctype="multipart/form-data" class="form">
            <input type="hidden" name="uid" value="<?php echo htmlspecialchars($uid); ?>">
            <input type="hidden" name="token" value="<?php echo htmlspecialchars($token); ?>">
            <input type="hidden" name="web" value="1">
            <label for="pdi">PDI-Datei:</label>
            <input type="file" id="pdi" name="pdi" accept=".pdi" required>
            <label for="json">JSON-Datei:</label>
            <input type="file" id="json" name="json" accept=".json" required>
            <button type="submit">Hochladen</button>
        </form>
        
        <h2>Meine Bilder</h2>
        
        <?php if (empty($images)): ?>
            <p>Keine Bilder hochgeladen.</p>
        <?php else: ?>
            <table class="images-table">
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Datum</th>
                        <th>Vorschau</th>
                        <th>PDI</th>
                        <th>JSON</th>
                        <th>PNG</th>
                        <th>GIF</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($images as $image): ?>
                        <tr>
                            <td><?php echo htmlspecialchars(substr($image['id'], 0, 8)); ?>...</td>
                            <td><?php echo htmlspecialchars(date('d.m.Y H:i', strtotime($image['uploaded_at']))); ?></td>
                            <td>
                                <img
                                    src="/download/png/<?php echo htmlspecialchars($image['id']); ?>?token=<?php echo htmlspecialchars($token); ?>&inline=1"
                                    alt="Vorschau <?php echo htmlspecialchars(substr($image['id'], 0, 8)); ?>"
                                    class="preview-image"
                                >
                            </td>
                            <td>
                                <a href="/download/pdi/<?php echo htmlspecialchars($image['id']); ?>?token=<?php echo htmlspecialchars($token); ?>" download>PDI</a>
                            </td>
                            <td>
                                <a href="/download/json/<?php echo htmlspecialchars($image['id']); ?>?token=<?php echo htmlspecialchars($token); ?>" download>JSON</a>
                            </td>
                            <td>
                                <a href="/download/png/<?php echo htmlspecialchars($image['id']); ?>?token=<?php echo htmlspecialchars($token); ?>" download>PNG</a>
                            </td>
                            <td>
                                <a href="/download/gif/<?php echo htmlspecialchars($image['id']); ?>?token=<?php echo htmlspecialchars($token); ?>" download>GIF</a>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>
    </div>
</body>
</html>
    <?php
}

/**
 * Verarbeitet Logout-Request
 */
function handleLogoutRequest(): void {
    $token = requestSessionToken() ?? '';
    
    if (!empty($token)) {
        Auth::invalidateToken($token);
        
        // Cookie löschen
        setcookie('session_token', '', [
            'expires' => time() - 3600,
            'path' => '/'
        ]);
    }
    
    header('Location: /');
    exit;
}
