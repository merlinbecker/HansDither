-- SyncService.lua — Backend-Synchronisation für Hans Dither (Spec 004).
--
-- Pairing + Einzelbild-Upload zu einem bestehenden PHP/MySQL-Backend
-- (Spec 005, backend/). Eingestiegen wird ausschließlich über eine
-- Crank-Geste in SelectionRoom (kein System-Menü-Slot mehr frei,
-- research.md R1) — SelectionRoom misst die Rotation und ruft bei
-- Erreichen der Schwelle SyncService:startSync(imageId) auf.
--
-- SDK-Bausteine hier:
--  * playdate.network.http  — HTTP-Client (ab Playdate OS 2.7), nur aus
--    einer via playdate.update() getriebenen Coroutine aufrufbar
--    (Permission-Dialog nutzt intern coroutine.yield())
--  * playdate.graphics.generateQRCode — asynchrone QR-Code-Erzeugung
--    (generateQRCodeSync ist in SDK v3.0.6 defekt: CoreLibs/qrcode.lua
--    referenziert generateQRCodeImage VOR dessen lokaler Deklaration im
--    selben File, greift also zur Laufzeit auf ein nie gesetztes Global
--    zu -> "global 'generateQRCodeImage' is not callable". Nur auf echtem
--    Gerät/Simulator sichtbar, kein Mock-fähiger API-Erfindungsfehler.)
--  * playdate.datastore     — lokale Persistenz des Sync-Zustands
--  * playdate.file          — rohes Lesen von sheet/frames.json (auf der
--    Disk heißt die Sheet-Datei "sheet" OHNE .pdi-Endung — writeImage()
--    hängt die Endung anders als datastore.write() NICHT automatisch an,
--    siehe R22)
--
-- Lange Vorgänge (Login-Check, Upload) laufen als RoomOperation-Coroutine
-- wie Save/Load in ImageStoreCodec — SelectionRoom treibt sie per
-- SyncService:tick() aus ihrem update() an.
--
-- Pairing-Ablauf (research.md R13, Redesign nach Nutzer-Feedback):
-- Das Gerät generiert uid+pin lokal und meldet sich damit SELBST beim
-- Backend an (POST /pair — derselbe Endpunkt, den bisher nur das
-- Web-Formular aufrief, siehe backend/public/index.php:handlePairRequest,
-- der ohne "web=1"-Feld bereits JSON statt eines Redirects liefert). Eine
-- Bestätigung auf der Website VOR dem Upload bringt hier keine zusätzliche
-- Sicherheit: uid UND pin werden beide ausschließlich vom Gerät erzeugt,
-- der QR-Code auf dem Display IST bereits der komplette Nachweis "physischer
-- Zugriff aufs Gerät" — ein Website-Login mit denselben Werten beweist
-- exakt dasselbe, nur später. Der Ablauf ist daher: Crank -> Login-Versuch
-- -> bei 404 (unbekannt) ODER 400 (PIN passt nicht, z. B. Altlast aus einem
-- früheren Tippfehler-Pairing) automatisch (Re-)Pair mit der lokalen PIN,
-- dann Login-Retry -> Upload. Auth::pair() erlaubt das Überschreiben von
-- pin_hash, solange die UID noch nie einen erfolgreichen Login hatte
-- (confirmed_at IS NULL), macht diesen Self-Heal-Pfad also sicher (research.md
-- R12). Die Website-PIN-Eingabe ist damit kein Upload-Gate mehr, sondern nur
-- noch der Weg, die bereits hochgeladenen Bilder anzusehen.

import "CoreLibs/graphics"
import "CoreLibs/qrcode"
import "RoomOperation"
import "loadingBar"
import "ImageStore"

local gfx = playdate.graphics

SyncService = {}

-- ── Konstanten ────────────────────────────────────────────────────────────

local BACKEND_HOST = "www.hans-dither.de"
local BACKEND_URL = "https://" .. BACKEND_HOST
SyncService.SYNC_GESTURE_THRESHOLD_DEGREES = 720

-- ── Logging (Nutzer-Feedback: Ablauf im Simulator-Log nachvollziehen) ────
--
-- Ein einheitliches Präfix macht die Sync-Zeilen in der (sonst von jedem
-- Raum bestückten) Simulator-Konsole leicht filterbar/grep-bar.
local function logSync(fmt, ...)
    print("[Sync] " .. string.format(fmt, ...))
end

-- ── Modul-Zustand ─────────────────────────────────────────────────────────

local cachedState = nil        -- sync/state, lazy geladen
local overlay = loadingBar.new()
local operation = nil          -- aktive RoomOperation (Pairing+Login+Upload-Kette)
local pinSeeded = false

local resultModalActive = false  -- Vollbild-QR+PIN-Ergebnisscreen nach erfolgreichem Upload
local qrImage = nil
local qrForUid = nil
local qrPendingForUid = nil    -- uid, für die aktuell asynchron generiert wird

local statusMessage = nil      -- kurzzeitige Statusmeldung (z. B. Fehlertext)
local statusUntilMs = nil

-- ── Persistenz (data-model.md SyncState) ─────────────────────────────────

function SyncService:getState()
    if cachedState == nil then
        cachedState = playdate.datastore.read("sync/state") or {}
    end
    return cachedState
end

function SyncService:saveState(newState)
    cachedState = newState
    playdate.datastore.write(cachedState, "sync/state")
end

-- ── PIN-/UID-Generierung (research.md R7, R10) ────────────────────────────
--
-- WICHTIG: Das SDK bietet KEINE Geräte-Seriennummer/eindeutige Hardware-ID
-- für Lua-Spiele (verifiziert gegen CoreLibs/__stub.lua — kein
-- getDeviceUniqueIdentifier() o.ä. vorhanden). FR-001s ursprüngliche Annahme
-- "UID wird vom Playdate SDK bereitgestellt" war falsch. Die UID wird daher
-- wie die PIN lokal zufällig generiert und beim ersten Sync-Versuch
-- dauerhaft in sync/state gecacht (research.md R10).
--
-- Die PIN wird EXAKT EINMAL generiert und danach für die gesamte Lebens-
-- dauer der App-Installation unverändert wiederverwendet (research.md R12)
-- — auch für jeden weiteren Upload wird nur noch die gecachte PIN verwendet,
-- nie erneut abgefragt oder neu generiert.

local function ensureSeeded()
    if not pinSeeded then
        math.randomseed(playdate.getSecondsSinceEpoch() + playdate.getCurrentTimeMilliseconds())
        pinSeeded = true
    end
end

function SyncService:generatePin()
    ensureSeeded()
    return string.format("%04d", math.random(0, 9999))
end

local HEX_CHARS = "0123456789abcdef"

function SyncService:generateUid()
    ensureSeeded()
    local chars = {}
    for i = 1, 16 do
        local idx = math.random(1, #HEX_CHARS)
        chars[i] = HEX_CHARS:sub(idx, idx)
    end
    return "pd-" .. table.concat(chars)
end

-- Liefert die lokal gecachte UID, generiert und persistiert bei Bedarf eine neue.
function SyncService:getOrCreateUid()
    local st = SyncService:getState()
    if not st.uid then
        st.uid = SyncService:generateUid()
        SyncService:saveState(st)
    end
    return st.uid
end

-- ── Crank-Hinweis: nur bis zur ersten tatsächlichen Kurbel-Nutzung ────────
--
-- Nutzer-Feedback: der "crank to sync"-Hinweis soll nicht dauerhaft bei
-- jeder Bildauswahl erscheinen, sobald der Nutzer die Geste einmal
-- ausgeführt hat. Persistiert in sync/state (wie uid/pin), damit der
-- Hinweis auch nach einem App-Neustart nicht wieder auftaucht.
function SyncService:hasUsedCrank()
    return SyncService:getState().crankUsed == true
end

function SyncService:markCrankUsed()
    local st = SyncService:getState()
    if not st.crankUsed then
        st.crankUsed = true
        SyncService:saveState(st)
    end
end

-- ── QR-Code (research.md R3) ──────────────────────────────────────────────

-- Erzeugt/cached den QR-Code für die Ansichts-URL dieser UID (zeigt nach
-- erfolgreichem Upload).
--
-- Asynchron (generateQRCode statt generateQRCodeSync, siehe Kommentar am
-- Dateianfang): liefert nil, solange die Generierung noch läuft. Wird
-- bereits bei SyncService:startSync() angestoßen (uid ist rein lokal, ohne
-- Netzwerk-Roundtrip bekannt) — die eigentlich langsame, frameweise verteilte
-- QR-Erzeugung läuft dadurch PARALLEL zum Pairing/Login/Upload-Netzwerk-
-- Roundtrip, statt sich als zusätzliche sichtbare Wartezeit erst danach
-- anzuschließen.
function SyncService:getQrImage(uid)
    if qrImage and qrForUid == uid then
        return qrImage
    end
    if qrPendingForUid == uid then
        return nil
    end
    qrPendingForUid = uid
    local startMs = playdate.getCurrentTimeMilliseconds()
    logSync("QR: generating for uid=%s ...", uid)
    local url = BACKEND_URL .. "/?uid=" .. uid
    gfx.generateQRCode(url, 128, function(img, err)
        if qrPendingForUid == uid then
            qrPendingForUid = nil
        end
        local elapsedMs = playdate.getCurrentTimeMilliseconds() - startMs
        if img then
            qrImage = img
            qrForUid = uid
            logSync("QR: done for uid=%s in %dms", uid, elapsedMs)
        else
            logSync("QR: FAILED for uid=%s after %dms: %s", uid, elapsedMs, tostring(err))
        end
    end)
    return nil
end

-- ── URL-Encoding (minimal, für uid/pin im Login-Body) ────────────────────

local function urlEncode(value)
    value = tostring(value or "")
    return (value:gsub("[^%w%-%.%_%~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

-- ── Roher HTTP-Request als Coroutine-Baustein (research.md R4) ───────────
--
-- MUSS aus einer via playdate.update() getriebenen Coroutine aufgerufen
-- werden (http.new() nutzt intern coroutine.yield() für den Permission-
-- Dialog). Nicht-blockierend: wartet callback-getrieben, niemals über
-- connection:read() mit SDK-internem Timeout (das würde den Frame blockieren).
--
-- Gibt (statusCode, bodyString) oder (nil, nil, errorMessage) zurück.
--
-- host/method sind parametrisiert (statt fest auf BACKEND_HOST/POST), damit
-- devTestNetworkProbe (weiter unten) exakt denselben Verbindungsaufbau/
-- Wartepfad gegen einen bekannt funktionierenden externen Host abfeuern
-- kann — das einzige, was zwischen "Backend erreichbar" und "gar nichts
-- erreichbar" unterscheidet (R19).
local function httpAndWait(host, path, headers, body, phaseLabel, method)
    local startMs = playdate.getCurrentTimeMilliseconds()
    logSync("HTTP: %s %s%s ...", method, host, path)

    -- Port EXPLIZIT 443 statt nil (siehe R20): eine Live-Socket-Aufzeichnung
    -- zeigte den Simulator-Prozess mindestens einmal tatsächlich auf Port 80
    -- statt 443 verbunden, obwohl usessl=true gesetzt ist — das offizielle
    -- SDK-Beispiel übergibt in JEDEM gezeigten Aufruf einen expliziten Port,
    -- nie nil+usessl=true. Verlässt sich also nicht auf denselben
    -- undokumentierten Port-Default, der hier offenbar fehlerhaft ist.
    local connection, connErr = playdate.network.http.new(host, 443, true, "Hans Dither Sync")
    if not connection then
        logSync("HTTP: %s %s%s could not open connection: %s", method, host, path, tostring(connErr))
        return nil, nil, connErr or "Connection failed"
    end

    -- Explizit statt auf einen undokumentierten SDK-Default zu vertrauen —
    -- so im offiziellen Lua-Beispiel (SDK Examples/Networking/.../main.lua:
    -- "http_conn:setConnectTimeout(2)"). Ändert nichts an EINER tatsächlichen
    -- Netzwerkstörung, macht das Verhalten aber deterministisch/dokumentiert
    -- statt vom SDK-internen Default abhängig zu sein (research.md R18).
    connection:setConnectTimeout(8)

    local done = false
    local status = nil
    local responseBody = ""
    local requestErr = nil

    connection:setHeadersReadCallback(function()
        status = connection:getResponseStatus()
    end)
    connection:setRequestCallback(function()
        local avail = connection:getBytesAvailable()
        if avail and avail > 0 then
            local chunk = connection:read(avail)
            if chunk then
                responseBody = responseBody .. chunk
            end
        end
    end)
    connection:setRequestCompleteCallback(function()
        done = true
    end)
    connection:setConnectionClosedCallback(function()
        done = true
    end)

    local ok, postErr
    if method == "GET" then
        ok, postErr = connection:get(path, headers)
    else
        ok, postErr = connection:post(path, headers, body)
    end
    if not ok then
        connection:close()
        logSync("HTTP: %s %s%s could not be sent: %s", method, host, path, tostring(postErr))
        return nil, nil, postErr or "Request could not be sent"
    end

    while not done do
        coroutine.yield(phaseLabel)
    end

    requestErr = connection:getError()
    connection:close()

    local elapsedMs = playdate.getCurrentTimeMilliseconds() - startMs

    -- status 0 ist KEIN echter HTTP-Statuscode (die kleinste reale Antwort
    -- ist 100) — er bedeutet, dass getResponseStatus() nie eine tatsächliche
    -- Server-Antwort gesehen hat (z. B. DNS/TLS/Verbindungsfehler). Ohne
    -- diese Unterscheidung wurde 0 bisher stillschweigend wie ein regulärer
    -- HTTP-Status behandelt und landete in login()/pair() im generischen
    -- "unauthorized"/"invalid"-Zweig — das täuschte einen Business-Logik-
    -- Fehler (falsche PIN) vor, wo tatsächlich gar keine Antwort ankam, und
    -- löste fälschlich einen Auto-Pair-Versuch aus (der aus demselben Grund
    -- ebenfalls scheiterte). Nutzer-Feedback nach echtem Simulator-Log.
    if status == nil or status == 0 then
        logSync("HTTP: %s %s%s NO RESPONSE after %dms (connection error: %s)",
            method, host, path, elapsedMs, tostring(requestErr or "unknown"))
        return nil, nil, requestErr or "No response from server"
    end

    logSync("HTTP: %s %s%s -> %s (%dms, %d bytes)", method, host, path, tostring(status), elapsedMs, #responseBody)
    return status, responseBody, nil
end

local function httpPostAndWait(path, headers, body, phaseLabel)
    return httpAndWait(BACKEND_HOST, path, headers, body, phaseLabel, "POST")
end

-- ── Schritt A: Pair (contracts/sync-protocol.md Abschnitt 2) ─────────────
--
-- Registriert uid+pin autonom beim Backend — derselbe Endpunkt, den bisher
-- nur das Web-Formular aufrief (backend/public/index.php). Wird NUR nach
-- einem gescheiterten Login aufgerufen (siehe ensurePairedAndLoggedIn),
-- daher kein Overhead im Normalfall (bereits verknüpftes Gerät). Gibt
-- zurück:
--   { ok = true }                                                      (201)
--   { ok = false, reason = "uid_taken" }                               (409, konfirmierte UID gehört einem anderen Gerät)
--   { ok = false, reason = "invalid", detail = "..." }                 (400, sollte bei gültig generierter uid/pin nie auftreten)
--   { ok = false, reason = "network", detail = "..." }                 (Fehler)
local function pair(uid, pin)
    local body = "uid=" .. urlEncode(uid) .. "&pin=" .. urlEncode(pin)
    local headers = { ["Content-Type"] = "application/x-www-form-urlencoded" }

    local status, respBody, err = httpPostAndWait("/pair", headers, body, "Registering...")

    if err then
        logSync("pair: network error: %s", tostring(err))
        return { ok = false, reason = "network", detail = err }
    end

    if status == 201 then
        logSync("pair: ok (uid=%s)", uid)
        return { ok = true }
    elseif status == 409 then
        logSync("pair: uid_taken (409) - uid=%s already confirmed to another device", uid)
        return { ok = false, reason = "uid_taken" }
    else
        logSync("pair: invalid (status=%s)", tostring(status))
        return { ok = false, reason = "invalid", detail = respBody }
    end
end

-- ── Schritt B: Login (contracts/sync-protocol.md Abschnitt 2) ────────────
--
-- Liefert bei Erfolg das Session-Token fürs Upload. Gibt zurück:
--   { ok = true, sessionToken = "...", expiresAt = "..." }             (200)
--   { ok = false, reason = "not_paired" }                              (404)
--   { ok = false, reason = "unauthorized" }                            (400)
--   { ok = false, reason = "locked" }                                  (429)
--   { ok = false, reason = "network", detail = "..." }                 (Fehler)
local function login(uid, pin)
    local body = "uid=" .. urlEncode(uid) .. "&pin=" .. urlEncode(pin)
    local headers = { ["Content-Type"] = "application/x-www-form-urlencoded" }

    local status, respBody, err = httpPostAndWait("/login", headers, body, "Logging in...")

    if err then
        logSync("login: network error: %s", tostring(err))
        return { ok = false, reason = "network", detail = err }
    end

    if status == 200 then
        local decoded = json.decode(respBody)
        if not decoded or not decoded.session_token then
            logSync("login: 200 but invalid response body")
            return { ok = false, reason = "network", detail = "Invalid response" }
        end
        logSync("login: ok, session token received")
        return { ok = true, sessionToken = decoded.session_token, expiresAt = decoded.expires_at }
    elseif status == 404 then
        logSync("login: not_paired (404)")
        return { ok = false, reason = "not_paired" }
    elseif status == 429 then
        logSync("login: locked (429) - rate limited")
        return { ok = false, reason = "locked" }
    else
        logSync("login: unauthorized (status=%s)", tostring(status))
        return { ok = false, reason = "unauthorized" }
    end
end

-- Kombiniert Login + autonomes (Re-)Pairing zu einem einzigen Ergebnis.
-- Erst wird ganz normal eingeloggt (Normalfall: bereits verknüpftes Gerät,
-- ein einziger Request). Schlägt das mit "not_paired" (UID unbekannt) ODER
-- "unauthorized" (UID bekannt, aber pin_hash passt nicht — z. B. eine
-- Altlast aus einem früheren, inzwischen abgeschafften Web-Pairing-Schritt)
-- fehl, registriert das Gerät sich selbst per pair() mit der lokal
-- gecachten PIN und versucht den Login danach genau einmal erneut. pair()
-- überschreibt pin_hash nur, solange die UID noch nie erfolgreich
-- eingeloggt war (confirmed_at IS NULL, siehe Auth::pair()/research.md
-- R12) — der Self-Heal ist also nur für tatsächlich unbestätigte UIDs
-- wirksam, eine fremde bereits bestätigte UID bleibt geschützt (409 ->
-- "uid_taken", praktisch unerreichbar bei 2^64 zufälligen UIDs).
local function ensurePairedAndLoggedIn(uid, pin)
    logSync("auth: uid=%s", uid)
    local loginResult = login(uid, pin)
    if loginResult.ok then
        return loginResult
    end
    if loginResult.reason ~= "not_paired" and loginResult.reason ~= "unauthorized" then
        logSync("auth: login failed (%s), no auto-pair (not eligible)", loginResult.reason)
        return loginResult
    end

    logSync("auth: login failed (%s), attempting auto-pair", loginResult.reason)
    local pairResult = pair(uid, pin)
    if not pairResult.ok then
        local reason = (pairResult.reason == "uid_taken") and "uid_taken" or loginResult.reason
        logSync("auth: auto-pair failed (%s)", pairResult.reason)
        return { ok = false, reason = reason, detail = pairResult.detail }
    end

    logSync("auth: auto-pair ok, retrying login")
    return login(uid, pin)
end

-- ── Rohes Datei-Lesen (T017) ──────────────────────────────────────────────
--
-- NICHT über playdate.datastore.read() — das würde die JSON-Datei zu einer
-- Lua-Tabelle deserialisieren statt die Rohbytes für den Multipart-Body zu
-- liefern (data-model.md).
function SyncService:readFileBytes(path)
    local size = playdate.file.getSize(path)
    if not size or size <= 0 then
        return nil
    end
    local f = playdate.file.open(path, playdate.file.kFileRead)
    if not f then
        return nil
    end
    local data = f:read(size)
    f:close()
    return data
end

-- ── Multipart-Body-Konstruktion (T018, contracts/sync-protocol.md) ───────
--
-- playdate.network.http liefert keinen Multipart-Encoder (research.md R4),
-- daher String-Konkatenation. Boundary-Kollision mit PDI-Binärdaten ist ein
-- akzeptiertes Restrisiko (siehe plan.md, Security-Review).
local function generateBoundary()
    ensureSeeded()
    local chars = {}
    for i = 1, 24 do
        local idx = math.random(1, #HEX_CHARS)
        chars[i] = HEX_CHARS:sub(idx, idx)
    end
    return "----HansDitherSync" .. table.concat(chars)
end

local function multipartField(boundary, name, value)
    return "--" .. boundary .. "\r\n"
        .. 'Content-Disposition: form-data; name="' .. name .. '"\r\n\r\n'
        .. tostring(value) .. "\r\n"
end

local function multipartFile(boundary, name, filename, contentType, bytes)
    return "--" .. boundary .. "\r\n"
        .. 'Content-Disposition: form-data; name="' .. name .. '"; filename="' .. filename .. '"\r\n'
        .. 'Content-Type: ' .. contentType .. '\r\n\r\n'
        .. bytes .. "\r\n"
end

function SyncService:buildMultipartBody(boundary, uid, token, imageId, pdiBytes, jsonBytes)
    return multipartField(boundary, "uid", uid)
        .. multipartField(boundary, "token", token)
        .. multipartField(boundary, "image_id", imageId)
        .. multipartFile(boundary, "pdi", imageId .. ".pdi", "application/octet-stream", pdiBytes)
        .. multipartFile(boundary, "json", imageId .. ".json", "application/json", jsonBytes)
        .. "--" .. boundary .. "--\r\n"
end

-- ── Schritt C: Upload (T019, contracts/sync-protocol.md Abschnitt 2) ─────
--
-- Ein Versuch: ensurePairedAndLoggedIn() (liefert session_token, pairt bei
-- Bedarf autonom nach) + Multipart-POST /upload. Gibt zurück:
--   { ok = true }                                                      (201)
--   { ok = false, reason = "not_paired"|"unauthorized"|"locked"|"uid_taken" } (Auth schlug fehl)
--   { ok = false, reason = "token_expired" }                           (401 beim Upload)
--   { ok = false, reason = "too_large" }                               (413)
--   { ok = false, reason = "local_read_error" }                        (sheet/frames.json fehlt)
--   { ok = false, reason = "network", detail = "..." }
--   { ok = false, reason = "upload_failed", detail = "..." }
local function attemptUpload(imageId)
    logSync("upload: attempt imageId=%s", imageId)
    local st = SyncService:getState()
    local authResult = ensurePairedAndLoggedIn(st.uid, st.pin)
    if not authResult.ok then
        logSync("upload: aborted, auth failed (%s)", authResult.reason)
        return { ok = false, reason = authResult.reason, detail = authResult.detail }
    end

    if not st.paired then
        st.paired = true
        SyncService:saveState(st)
    end

    local pdiBytes = SyncService:readFileBytes("saves/" .. imageId .. "/sheet")
    local jsonBytes = SyncService:readFileBytes("saves/" .. imageId .. "/frames.json")
    if not pdiBytes or not jsonBytes then
        logSync("upload: local_read_error (pdi=%s json=%s)", tostring(pdiBytes ~= nil), tostring(jsonBytes ~= nil))
        return { ok = false, reason = "local_read_error" }
    end
    logSync("upload: read %d bytes pdi, %d bytes json", #pdiBytes, #jsonBytes)

    local boundary = generateBoundary()
    local body = SyncService:buildMultipartBody(boundary, st.uid, authResult.sessionToken, imageId, pdiBytes, jsonBytes)
    local headers = { ["Content-Type"] = "multipart/form-data; boundary=" .. boundary }

    local status, respBody, err = httpPostAndWait("/upload", headers, body, "Uploading...")

    if err then
        logSync("upload: network error: %s", tostring(err))
        return { ok = false, reason = "network", detail = err }
    elseif status == 201 then
        logSync("upload: ok")
        return { ok = true }
    elseif status == 401 then
        logSync("upload: token_expired (401)")
        return { ok = false, reason = "token_expired" }
    elseif status == 413 then
        logSync("upload: too_large (413)")
        return { ok = false, reason = "too_large" }
    else
        logSync("upload: upload_failed (status=%s)", tostring(status))
        return { ok = false, reason = "upload_failed", detail = respBody }
    end
end

-- T022: 401 (abgelaufenes Token) -> genau ein Retry mit frischem Login.
-- Alle anderen Fehler werden nicht automatisch wiederholt.
local function uploadWithRetry(imageId)
    local result = attemptUpload(imageId)
    if not result.ok and result.reason == "token_expired" then
        logSync("upload: token expired, retrying once with fresh login")
        result = attemptUpload(imageId)
    end
    return result
end

-- ── Statusanzeige (FR-012) ────────────────────────────────────────────────
--
-- ASCII-only: der Playdate-System-Font ersetzt Umlaute/Em-Dash/Ellipsis
-- durch ein Ersatzzeichen ("�") statt sie darzustellen — auf echtem Gerät
-- sichtbar geworden (Nutzer-Screenshot), von den SDK-Mocks der Testsuite
-- nicht erkennbar. Alle Sync-UI-Strings sind daher bewusst Englisch (wie
-- der Rest der App-UI) und ASCII-only.

local function showStatus(text, durationMs)
    statusMessage = text
    statusUntilMs = playdate.getCurrentTimeMilliseconds() + (durationMs or 3000)
end

function SyncService:getStatusText()
    local st = SyncService:getState()
    if st.paired then
        return "linked to " .. BACKEND_HOST
    end
    return "not linked yet"
end

function SyncService:getTransientStatusMessage()
    if statusMessage and playdate.getCurrentTimeMilliseconds() > statusUntilMs then
        statusMessage = nil
    end
    return statusMessage
end

-- ── QR+PIN-Ergebnisscreen (Vollbild, nach erfolgreichem Upload) ──────────

function SyncService:isShowingQrOverlay()
    return resultModalActive
end

-- B-Taste: aktives Ergebnis-Overlay schließen (SelectionRoom ruft das aus
-- ihrem B-Handler auf, bevor sie ihre eigene B-Logik ausführt).
function SyncService:dismissQrOverlay()
    if resultModalActive then
        resultModalActive = false
        return true
    end
    return false
end

-- ── Betriebszustand (SelectionRoom fragt das für needsRedraw/Crank-Drain ab) ──

function SyncService:isBusy()
    return operation ~= nil
end

-- Von SelectionRoom jeden Frame aufgerufen: treibt eine laufende
-- RoomOperation (Pairing+Login+Upload-Kette, MIT loadingBar-Overlay) weiter.
function SyncService:tick()
    if operation == nil then
        return
    end
    operation:resume(function(err)
        operation = nil
        logSync("chain CRASHED: %s", tostring(err))
        showStatus("Error: " .. tostring(err))
    end)
end

function SyncService:draw()
    overlay:draw()
    if resultModalActive then
        SyncService:drawResultModal()
    end
end

-- Vollbild statt kleiner Box (Nutzer-Feedback: eine schwebende Box ließ das
-- Kreisraster im Hintergrund durchscheinen und wirkte unaufgeräumt) —
-- deckt zusätzlich Statuszeile/Crank-Hinweis darunter vollständig ab.
function SyncService:drawResultModal()
    local st = SyncService:getState()
    if not st.uid then return end

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 0, 400, 240)

    local qr = SyncService:getQrImage(st.uid)
    if qr then
        local qrW, qrH = qr:getSize()
        qr:draw((400 - qrW) // 2, 24)
    else
        gfx.setColor(gfx.kColorBlack)
        gfx.drawTextAligned("Generating QR code...", 200, 90, kTextAlignment.center)
    end

    gfx.setColor(gfx.kColorBlack)
    gfx.drawTextAligned("Uploaded! PIN: " .. st.pin, 200, 190, kTextAlignment.center)
    gfx.drawTextAligned("Scan to view on " .. BACKEND_HOST, 200, 208, kTextAlignment.center)
    gfx.drawTextAligned("(B) close", 200, 224, kTextAlignment.center)
end

-- ── Sync-Einstieg (von SelectionRoom bei Crank-Schwelle aufgerufen) ──────

-- Gemeinsames Gerüst für alle RoomOperation-Vorgänge (Haupt-Kette UND die
-- Dev-Testtrigger weiter unten) — vermeidet doppelten RoomOperation/operation-
-- Boilerplate.
local function runOperation(title, phaseText, coroutineFn, onDone)
    local op = RoomOperation.new(overlay)
    operation = op
    op:start(title, phaseText, coroutineFn, function(result)
        operation = nil
        onDone(result)
    end)
end

-- Pairing+Login+Upload-Kette (T020): läuft immer als EIN Vorgang, ohne auf
-- eine externe Website-Bestätigung zu warten (siehe Kommentar am
-- Dateianfang) — der Nutzer cranked einmal, das Bild landet am Ende beim
-- Backend, ohne zweite Geste oder Wartezeit.
local function startUpload(imageId)
    local chainStartMs = playdate.getCurrentTimeMilliseconds()
    runOperation("Sync", "Logging in...", function()
        return coroutine.create(function()
            return uploadWithRetry(imageId)
        end)
    end, function(result)
        local elapsedMs = playdate.getCurrentTimeMilliseconds() - chainStartMs
        logSync("chain finished in %dms: ok=%s reason=%s", elapsedMs, tostring(result.ok), tostring(result.reason))

        local st = SyncService:getState()

        if result.ok then
            if st.pendingUpload and st.pendingUpload.imageId == imageId then
                st.pendingUpload = nil
                SyncService:saveState(st)
            end
            resultModalActive = true
        elseif result.reason == "locked" then
            showStatus("Too many attempts - wait 5 min", 5000)
        elseif result.reason == "uid_taken" then
            showStatus("Device ID conflict - reinstall app", 5000)
        elseif result.reason == "not_paired" or result.reason == "unauthorized" then
            showStatus("Pairing failed - try again", 4000)
        elseif result.reason == "too_large" then
            showStatus("File too large to upload")
        elseif result.reason == "local_read_error" then
            showStatus("Could not read image data")
        elseif result.reason == "network" then
            st.pendingUpload = { imageId = imageId, attemptedAt = playdate.getCurrentTimeMilliseconds() }
            SyncService:saveState(st)
            showStatus("Network error - try again later")
        else
            showStatus("Upload failed")
        end
    end)
end

-- Haupt-Einstiegspunkt: von SelectionRoom bei erreichter Crank-Schwelle
-- (≥720°) für das aktuell selektierte Bild aufgerufen.
function SyncService:startSync(imageId)
    if SyncService:isBusy() then
        logSync("startSync: ignored, chain already running")
        return
    end

    local uid = SyncService:getOrCreateUid()
    local st = SyncService:getState()

    if not st.pin then
        st.pin = SyncService:generatePin()
        SyncService:saveState(st)
    end

    logSync("startSync: imageId=%s uid=%s paired=%s", imageId, uid, tostring(st.paired == true))

    -- QR hängt nur von der (lokal bereits bekannten) uid ab -> parallel zum
    -- Netzwerk-Roundtrip anstoßen, siehe Kommentar bei getQrImage.
    SyncService:getQrImage(uid)

    startUpload(imageId)
end

-- ── Dev-Testtrigger (Nutzer-Feedback: Roundtrip modular im Simulator
-- abfeuern können) ─────────────────────────────────────────────────────
--
-- playdate.keyPressed wird laut SDK-Dokumentation NUR im Simulator
-- aufgerufen, nie auf echtem Gerät — kein zusätzliches isSimulator-Gate
-- nötig, dieser ganze Block ist auf dem Gerät automatisch totes Gewicht.
-- Tastenbelegung (nur wirksam, während SelectionRoom aktiv ist, da nur
-- deren update() SyncService:tick() antreibt, genau wie beim Crank-Pfad):
--   1  nur Login (aktuell gecachte uid/pin)
--   2  nur Pair (aktuell gecachte uid/pin)
--   3  voller Roundtrip (Login/Pair/Upload) für das erste gespeicherte Bild
--   4  aktuellen sync/state-Inhalt ins Log ausgeben
--   0  lokalen Pairing-Zustand löschen (simuliert eine frische Installation)
--   5  Netzwerk-Sonde gegen example.com (R19) — unterscheidet "Simulator
--      erreicht GAR KEIN HTTPS" von "nur unser Backend nicht erreichbar"
function SyncService:devTestLogin()
    if SyncService:isBusy() then
        logSync("dev[1]: busy, ignoring")
        return
    end
    local uid = SyncService:getOrCreateUid()
    local st = SyncService:getState()
    if not st.pin then
        st.pin = SyncService:generatePin()
        SyncService:saveState(st)
    end
    logSync("dev[1]: TEST login only (uid=%s)", uid)
    runOperation("Sync", "Logging in...", function()
        return coroutine.create(function() return login(uid, st.pin) end)
    end, function(result)
        logSync("dev[1]: result ok=%s reason=%s", tostring(result.ok), tostring(result.reason))
        showStatus(result.ok and "TEST: login OK" or ("TEST: login failed - " .. tostring(result.reason)))
    end)
end

function SyncService:devTestPair()
    if SyncService:isBusy() then
        logSync("dev[2]: busy, ignoring")
        return
    end
    local uid = SyncService:getOrCreateUid()
    local st = SyncService:getState()
    if not st.pin then
        st.pin = SyncService:generatePin()
        SyncService:saveState(st)
    end
    logSync("dev[2]: TEST pair only (uid=%s)", uid)
    runOperation("Sync", "Registering...", function()
        return coroutine.create(function() return pair(uid, st.pin) end)
    end, function(result)
        logSync("dev[2]: result ok=%s reason=%s", tostring(result.ok), tostring(result.reason))
        showStatus(result.ok and "TEST: pair OK" or ("TEST: pair failed - " .. tostring(result.reason)))
    end)
end

function SyncService:devTestFullRoundtrip()
    if SyncService:isBusy() then
        logSync("dev[3]: busy, ignoring")
        return
    end
    local images = ImageStore.listImages() or {}
    if #images == 0 then
        logSync("dev[3]: no saved images to test upload with - create one first")
        return
    end
    local entry = images[1]
    logSync("dev[3]: TEST full roundtrip (imageId=%s name=%s)", entry.id, tostring(entry.name))
    SyncService:startSync(entry.id)
end

function SyncService:devDumpState()
    local st = SyncService:getState()
    logSync(
        "dev[4]: state uid=%s pin=%s paired=%s pendingUpload=%s",
        tostring(st.uid), tostring(st.pin), tostring(st.paired == true),
        (st.pendingUpload and st.pendingUpload.imageId) or "nil"
    )
end

-- R19: das Backend liefert "NO RESPONSE" nach ~3.4s ohne PDNetErr, obwohl
-- curl/Python vom selben Rechner aus sofort erfolgreich sind — der einzige
-- Unterschied ist der Prozess (Simulator bringt sein eigenes libcurl/OpenSSL
-- mit, siehe research.md R19). Diese Sonde fährt EXAKT denselben Verbindungs-
-- code gegen einen bekannt funktionierenden Drittanbieter-Host statt gegen
-- BACKEND_HOST — schlägt sie GENAUSO fehl, liegt das Problem am Simulator-
-- Prozess/Netzwerkpfad selbst (z. B. eine prozessspezifische Filterung),
-- nicht am Backend. Kommt sie durch, ist es host-spezifisch (z. B. TLS-
-- Zertifikatskette/CA-Bundle, siehe R19).
function SyncService:devTestNetworkProbe()
    if SyncService:isBusy() then
        logSync("dev[5]: busy, ignoring")
        return
    end
    logSync("dev[5]: TEST network probe against example.com (isolates simulator-wide vs. backend-specific failure)")
    runOperation("Sync", "Probing...", function()
        return coroutine.create(function()
            local status, _, err = httpAndWait("example.com", "/", nil, nil, "Probing...", "GET")
            return { status = status, err = err }
        end)
    end, function(result)
        logSync("dev[5]: probe result status=%s err=%s", tostring(result.status), tostring(result.err))
        showStatus(result.status and ("TEST: probe OK (" .. tostring(result.status) .. ")") or ("TEST: probe failed - " .. tostring(result.err)))
    end)
end

function SyncService:devResetPairing()
    if SyncService:isBusy() then
        logSync("dev[0]: busy, ignoring")
        return
    end
    SyncService:saveState({})
    logSync("dev[0]: local pairing state cleared - next sync generates a fresh uid/pin")
end

function playdate.keyPressed(key)
    if key == "1" then
        SyncService:devTestLogin()
    elseif key == "2" then
        SyncService:devTestPair()
    elseif key == "3" then
        SyncService:devTestFullRoundtrip()
    elseif key == "4" then
        SyncService:devDumpState()
    elseif key == "5" then
        SyncService:devTestNetworkProbe()
    elseif key == "0" then
        SyncService:devResetPairing()
    end
end

return SyncService
