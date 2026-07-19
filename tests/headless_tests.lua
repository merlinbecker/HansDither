-- headless_tests.lua — SDK-freie Tests für Hans Dither.
--
-- Ausführen (vom Repo-Root, benötigt nur einen normalen Lua-Interpreter):
--   lua tests/headless_tests.lua
--
-- Idee: Die echten Source-Dateien werden mit strikten Playdate-Mocks geladen.
-- Jeder Zugriff auf eine NICHT existierende SDK-Methode wirft sofort einen
-- Fehler — das fängt die Fehlerklasse "erfundene SDK-API" (setSelectedCell,
-- gfx.drawImage, keyboard.setCommitCallback, …), die auf dem Gerät erst zur
-- Laufzeit crasht.

local failures = {}
local function check(cond, msg)
    if cond then
        print("  OK   " .. msg)
    else
        table.insert(failures, msg)
        print("  FAIL " .. msg)
    end
end

local function section(title)
    print("\n== " .. title .. " ==")
end

-- ── Playdate-Mocks ────────────────────────────────────────────────────────────

-- pdc-"import" neutralisieren (im echten Build eine Compile-Direktive)
import = function() end

local function strictTable(name, methods)
    return setmetatable(methods, {
        __index = function(_, key)
            error(name .. "." .. tostring(key) .. " existiert nicht (erfundene SDK-API?)", 2)
        end
    })
end

-- Gridview-Mock mit der echten SDK-Oberfläche (Subset) inkl. Selektions-Zustand
local gridviewCalls = {}
local function newGridview(cellWidth, cellHeight)
    local gv = {
        _sel = { 1, 1, 1 },
        setNumberOfColumns = function(self, n) self._cols = n end,
        setNumberOfRows = function(self, n) self._rows = n end,
        setNumberOfSections = function(self, n) end,
        setNumberOfRowsInSection = function(self, section, n) self._rows = n end,
        setSelection = function(self, s, r, c)
            self._sel = { s, r, c }
            table.insert(gridviewCalls, { "setSelection", s, r, c })
        end,
        getSelection = function(self)
            return self._sel[1], self._sel[2], self._sel[3]
        end,
        selectNextRow = function(self)
            self._sel[2] = math.min(self._sel[2] + 1, self._rows or 99)
        end,
        selectPreviousRow = function(self)
            self._sel[2] = math.max(self._sel[2] - 1, 1)
        end,
        selectNextColumn = function(self)
            self._sel[3] = math.min(self._sel[3] + 1, self._cols or 99)
        end,
        selectPreviousColumn = function(self)
            self._sel[3] = math.max(self._sel[3] - 1, 1)
        end,
        scrollToCell = function(self, s, r, c, animated)
            table.insert(gridviewCalls, { "scrollToCell", s, r, c })
        end,
        drawInRect = function(self, x, y, w, h) end,
    }
    return setmetatable(gv, {
        __newindex = rawset,
        __index = function(_, key)
            if key == "drawCell" or key == "changeRowOnColumnWrap" then return nil end
            error("gridview:" .. tostring(key) .. " existiert nicht (erfundene SDK-API?)", 2)
        end
    })
end

local noop = function() end
-- Keyboard-Mock mit echtem Sichtbarkeits-Zustand: show() öffnet, hide()
-- schließt. So lässt sich testen, dass der Commit AUFGESCHOBEN wird,
-- solange das Keyboard noch sichtbar ist (Animations-Phase).
-- Die Callback-FELDER des echten SDK dürfen nil sein und sind daher
-- vom Strikt-Check ausgenommen.
local keyboardCallbackFields = {
    keyboardWillHideCallback = true,
    keyboardDidShowCallback = true,
    keyboardDidHideCallback = true,
    keyboardAnimatingCallback = true,
    textChangedCallback = true,
}
local keyboard
keyboard = setmetatable({
    _visible = false,
    show = function() keyboard._visible = true end,
    hide = function() keyboard._visible = false end,
    isVisible = function() return keyboard._visible end,
    text = "",
}, {
    __index = function(_, key)
        if keyboardCallbackFields[key] then return nil end
        error("playdate.keyboard." .. tostring(key) .. " existiert nicht (erfundene SDK-API?)", 2)
    end
})

-- Zeichen-Kontext: gfx.image.new liefert Bilder, die drawPixel/fillRect
-- aufzeichnen und per sample() abfragbar sind — so lässt sich das Ergebnis
-- eines Mal-Strichs oder eines erzeugten Tiles pruefen.
local drawContext = nil
local currentColor = "white"
local heldButtons = {}

local function newMockImage(w, h, bgcolor)
    return {
        width = w, height = h,
        pixels = {},
        fill = (bgcolor == "black") and "black" or "white",
        draw = noop,
        getSize = function(self) return self.width, self.height end,
        sample = function(self, x, y)
            if self.pixels[x .. "," .. y] then return "black" end
            return self.fill
        end,
    }
end

playdate = {
    -- getTextSize muss Zahlen liefern (Bauchbinde rechnet damit);
    -- alles andere darf ein No-op sein
    graphics = setmetatable({
        kColorBlack = "black", kColorWhite = "white", kColorClear = "clear",
        getTextSize = function() return 40, 16 end,
        setColor = function(c) currentColor = c end,
        pushContext = function(img) drawContext = img end,
        popContext = function() drawContext = nil end,
        drawPixel = function(x, y)
            if drawContext and drawContext.pixels then
                drawContext.pixels[x .. "," .. y] = true
            end
        end,
        fillRect = function(x, y, w, h)
            if drawContext then drawContext.fill = currentColor end
        end,
        image = { new = newMockImage },
        imagetable = {
            new = function(count)
                return {
                    _imgs = {},
                    setImage = function(self, i, img) self._imgs[i] = img end,
                    getImage = function(self, i) return self._imgs[i] end,
                    getLength = function(self) return #self._imgs end,
                }
            end,
        },
        -- Spec 004: liefert asynchron ein Mock-Bild statt echter QR-Kodierung
        -- (Produktivcode nutzt generateQRCode, nicht generateQRCodeSync — die
        -- Sync-Variante ist im echten SDK v3.0.6 wegen eines Scoping-Bugs in
        -- CoreLibs/qrcode.lua defekt, siehe SyncService.lua-Kommentar). Der
        -- Mock ruft den Callback synchron auf; ein echter playdate.timer-Loop
        -- ist für die Tests nicht nötig. desiredEdgeDimension wird ignoriert.
        generateQRCode = function(stringToEncode, desiredEdgeDimension, callback)
            callback(newMockImage(desiredEdgeDimension or 100, desiredEdgeDimension or 100))
        end,
    }, { __index = function() return noop end }),
    ui = {
        gridview = { new = newGridview },
        -- Spec 004: SDK-Crank-Hinweis-Icon — Zeichnen ist ein No-op,
        -- Aufrufe werden für Testzwecke gezählt
        crankIndicator = setmetatable({ drawCount = 0 }, {
            __index = function(t, key)
                if key == "draw" then
                    return function(self) self.drawCount = self.drawCount + 1 end
                end
                if key == "getBounds" then
                    -- Feste Mock-Geometrie (Werte irrelevant für Tests, nur
                    -- damit SelectionRoom die Positionierung berechnen kann)
                    return function(self) return 300, 150, 90, 50 end
                end
                error("crankIndicator." .. tostring(key) .. " existiert nicht (erfundene SDK-API?)", 2)
            end
        }),
    },
    keyboard = keyboard,
    kButtonA = "A", kButtonB = "B",
    kButtonUp = "up", kButtonDown = "down",
    kButtonLeft = "left", kButtonRight = "right",
    buttonIsPressed = function(b) return heldButtons[b] == true end,
    -- Spec 004: Auto-Polling (SyncService:tick()) braucht eine vorwärts
    -- bewegbare Uhr — testbar über die Modulvariable mockTimeMs (siehe unten)
    getCurrentTimeMilliseconds = function() return mockTimeMs end,
    getSecondsSinceEpoch = function() return 1700000000 end,
    timer = { updateTimers = noop },
    getSystemMenu = function()
        return strictTable("systemMenu", {
            removeAllMenuItems = noop,
            addMenuItem = noop,
            addCheckmarkMenuItem = noop,
        })
    end,
    -- Spec 004: Crank-Rotationsmessung — testbar über die Modulvariable
    -- crankChangeValue (siehe unten), wie im echten SDK zustandsbehaftet
    -- ("seit dem letzten Aufruf") aber hier einfach test-gesteuert
    getCrankChange = function() return crankChangeValue end,
    isCrankDocked = function() return crankDockedValue end,
}

-- Von Tests gesetzt, um Crank-Rotation/-Dock-Zustand zu simulieren
-- (siehe playdate.getCrankChange/isCrankDocked oben)
crankChangeValue = 0
crankDockedValue = false

-- Von Tests vorwärts bewegt, um Auto-Polling-Intervalle/Timeouts zu simulieren
-- (siehe playdate.getCurrentTimeMilliseconds oben)
mockTimeMs = 0

-- Bare globale SDK-Konstante (kein playdate.*-Feld im echten SDK)
kTextAlignment = { left = "left", center = "center", right = "right" }

-- ── Spec 004: Netzwerk-Mock (playdate.network.http) ──────────────────────────
--
-- Simuliert eine HTTP-Verbindung mit vollständig test-gesteuerter,
-- callback-basierter Antwort (kein echtes I/O). Tests rufen
-- simulateHttpResponse() auf, um Status/Body für die zuletzt erzeugte
-- Verbindung "eintreffen" zu lassen, und treiben die Coroutine danach per
-- SyncService:tick() weiter.
local mockConnections = {}

local function newMockHttpConnection(server, port, usessl, reason)
    local conn
    conn = strictTable("httpConnection", {
        -- Zustandsfelder vorab belegen (nicht nil!) — strictTable wirft sonst
        -- schon beim ERSTEN Lesen eines Feldes, das noch nie geschrieben wurde
        -- (z. B. getError() vor jedem Fehlerfall), auch wenn "nil" der
        -- korrekte SDK-Rueckgabewert waere.
        status = false,
        bytesAvailable = 0,
        pendingBody = "",
        errorMsg = false,
        post = function(self, path, headers, data)
            self.lastPath = path
            self.lastHeaders = headers
            self.lastBody = data
            return true
        end,
        setHeadersReadCallback = function(self, fn) self.onHeaders = fn end,
        setRequestCallback = function(self, fn) self.onData = fn end,
        setRequestCompleteCallback = function(self, fn) self.onComplete = fn end,
        setConnectionClosedCallback = function(self, fn) self.onClosed = fn end,
        setConnectTimeout = noop,
        getResponseStatus = function(self) return self.status end,
        getBytesAvailable = function(self) return self.bytesAvailable or 0 end,
        read = function(self, n)
            local body = self.pendingBody
            self.pendingBody = nil
            self.bytesAvailable = 0
            return body
        end,
        getError = function(self) return self.errorMsg end,
        close = noop,
    })
    table.insert(mockConnections, conn)
    return conn
end

playdate.network = strictTable("network", {
    http = strictTable("http", {
        new = newMockHttpConnection,
    }),
})

-- Simuliert eine vollständige Server-Antwort auf der zuletzt erzeugten
-- Mock-Verbindung: Header gelesen -> Daten verfügbar -> Request komplett.
local function simulateHttpResponse(status, bodyString)
    local conn = mockConnections[#mockConnections]
    conn.status = status
    if conn.onHeaders then conn.onHeaders() end
    conn.pendingBody = bodyString or ""
    conn.bytesAvailable = #conn.pendingBody
    if conn.onData then conn.onData() end
    if conn.onComplete then conn.onComplete() end
end

-- ── Spec 004: Minimaler JSON-Mock (globales json, R21) ───────────────────────
--
-- NUR für Tests: einfacher Encoder/Decoder für flache Objekte
-- ({"key":"value"|zahl|true|false}), ausreichend für die /login-Antworten
-- dieser Testsuite. `json` ist laut SDK ein GLOBALER Name (kein Feld unter
-- playdate.*, kein CoreLibs-Import nötig — verifiziert gegen das offizielle
-- Beispiel Examples/Level 1-1/Source/levelLoader.lua: "json.decode(...)").
-- Produktivcode läuft unter demselben echten globalen json.
json = strictTable("json", {
    encode = function(tbl)
        local parts = {}
        for k, v in pairs(tbl) do
            local valueStr
            if type(v) == "string" then
                valueStr = string.format("%q", v)
            elseif type(v) == "boolean" then
                valueStr = tostring(v)
            else
                valueStr = tostring(v)
            end
            table.insert(parts, string.format('"%s":%s', k, valueStr))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end,
    decode = function(str)
        if not str or str == "" then return nil end
        local result = {}
        -- Lua-Patterns kennen KEINE Alternation (kein "|" wie in Regex) —
        -- daher wird der Rohwert bis zum naechsten "," oder "}" eingefangen
        -- und danach nach Typ unterschieden. Reicht fuer die flachen
        -- {"key":"value"|zahl|bool}-Antworten dieser Testsuite.
        for key, rawValue in str:gmatch('"([%w_]+)"%s*:%s*([^,}]+)') do
            rawValue = rawValue:match("^%s*(.-)%s*$")
            if rawValue:sub(1, 1) == '"' then
                result[key] = rawValue:sub(2, -2)
            elseif rawValue == "true" then
                result[key] = true
            elseif rawValue == "false" then
                result[key] = false
            elseif rawValue ~= "null" then
                result[key] = tonumber(rawValue)
            end
        end
        return result
    end,
})

-- ── Spec 004: Datastore-Mock (playdate.datastore) ────────────────────────────
--
-- Backing Store als einfache Lua-Tabelle, indiziert nach Dateipfad —
-- ausreichend, um sync/state-Persistenz-Roundtrips zu testen.
local datastoreFiles = {}
playdate.datastore = strictTable("datastore", {
    write = function(tbl, filename) datastoreFiles[filename] = tbl end,
    read = function(filename) return datastoreFiles[filename] end,
    delete = function(filename) datastoreFiles[filename] = nil end,
})

-- ── Spec 004: Datei-Mock (playdate.file) für rohes Bild-Lesen (T017) ─────────
--
-- Separates Backing Store von playdate.datastore — dort werden Lua-Tabellen
-- gespeichert, hier rohe Byte-Strings (genau der Unterschied, den
-- SyncService:readFileBytes bewusst ausnutzt, siehe data-model.md).
-- mockRawFiles wird von Tests befüllt, um "vorhandene" sheet.pdi/frames.json
-- zu simulieren; ein fehlender Pfad simuliert eine nicht gespeicherte Datei.
mockRawFiles = {}
playdate.file = strictTable("file", {
    kFileRead = "r",
    getSize = function(path)
        local data = mockRawFiles[path]
        return data and #data or nil
    end,
    open = function(path, mode)
        local data = mockRawFiles[path]
        if not data then return nil end
        local pos = 1
        return strictTable("fileHandle", {
            read = function(self, n)
                local chunk = data:sub(pos, pos + n - 1)
                pos = pos + n
                return chunk
            end,
            close = noop,
        })
    end,
})

-- ── ImageStore-Mock: steuerbarer Bild-Bestand ────────────────────────────────

local storedImages = { { id = "bild1", name = "bild1", frameCount = 1, lastEdited = 0 } }
local createdNames = {}

ImageStore = strictTable("ImageStore", {
    listImages = function()
        local copy = {}
        for i, img in ipairs(storedImages) do copy[i] = img end
        return copy
    end,
    getPreviewImage = function() return nil end,
    createImage = function(name)
        table.insert(createdNames, name)
        local id = string.lower(name)
        table.insert(storedImages, { id = id, name = name, frameCount = 1, lastEdited = 1 })
        return id
    end,
    isIdTaken = function() return false end,
    sanitizeName = function(name) return string.lower(name or "") end,
})

dofile("Source/Bauchbinde.lua")     -- Namenszeile des SelectionRoom
dofile("Source/RoomOperation.lua")  -- Coroutine-Antrieb für SyncService (Spec 004)
dofile("Source/loadingBar.lua")     -- Fortschritts-Overlay für SyncService (Spec 004)
dofile("Source/SyncService.lua")
dofile("Source/SelectionRoom.lua")

-- EditorRoom-Mock + Raumwechsel-Protokoll
local switchedTo = nil
local editorImageId = nil
local editorMock = {
    setImage = function(self, id) editorImageId = id end,
}
SelectionRoom:init(function(room) switchedTo = room end, editorMock)

-- Liest die zuletzt gesetzte Selektion aus den Gridview-Aufrufen
local function lastSelectedIndex()
    for i = #gridviewCalls, 1, -1 do
        local c = gridviewCalls[i]
        if c[1] == "setSelection" then
            return (c[3] - 1) * 3 + c[4]  -- (row-1)*3+col
        end
    end
    return nil
end

-- ── SelectionRoom: Navigation ────────────────────────────────────────────────

section("SelectionRoom: Navigation klemmt an vorhandenen Einträgen")
SelectionRoom:entered()  -- 1 Bild + Neu-Eintrag = 2 Einträge
check(lastSelectedIndex() == 1, "Start-Selektion ist Eintrag 1")

SelectionRoom:handleRightButton()
check(lastSelectedIndex() == 2, "Rechts wählt Eintrag 2 (Neu-Eintrag)")

SelectionRoom:handleRightButton()
check(lastSelectedIndex() <= 2, "Rechts auf leerer Zelle 3 bleibt <= 2")

SelectionRoom:handleDownButton()
check(lastSelectedIndex() <= 2, "Runter ohne zweite Zeile bleibt <= 2")

SelectionRoom:handleLeftButton()
SelectionRoom:handleLeftButton()
SelectionRoom:handleUpButton()
check(lastSelectedIndex() >= 1, "Selektion faellt nie unter 1")

SelectionRoom:update()
check(true, "update() laeuft ohne Fehler durch")

-- ── SelectionRoom: A-Taste öffnet Editor bzw. Keyboard ───────────────────────

section("SelectionRoom: A auf Bild oeffnet den Editor")
SelectionRoom:setSelectedIndex(1)
SelectionRoom:handleAButton()
check(editorImageId == "bild1", "EditorRoom:setImage erhaelt die Bild-ID")
check(switchedTo == editorMock, "switchRoom wechselt zum EditorRoom")

section("SelectionRoom: A auf Neu-Eintrag -> Keyboard-Commit legt Bild an")
switchedTo, editorImageId = nil, nil
SelectionRoom:entered()
SelectionRoom:setSelectedIndex(2)       -- Neu-Eintrag
SelectionRoom:handleAButton()            -- oeffnet Keyboard, setzt Callback
check(keyboard.isVisible(), "Keyboard ist nach A auf Neu-Eintrag sichtbar")
check(type(keyboard.keyboardWillHideCallback) == "function",
    "openKeyboard setzt keyboardWillHideCallback")

-- Nutzer drueckt OK: Callback feuert beim START der Zuklapp-Animation,
-- das Keyboard ist da noch sichtbar. Der Raumwechsel darf hier noch
-- NICHT passieren (Input-Handler-Stack gehoert noch dem Keyboard).
keyboard.text = "MeinBild"
local willHide = keyboard.keyboardWillHideCallback
willHide(true)
check(switchedTo == nil, "Commit waehrend Zuklapp-Animation ist aufgeschoben")
check(keyboard.keyboardWillHideCallback == nil, "Callback haengt sich nach Gebrauch selbst ab")

SelectionRoom:update()  -- Keyboard noch sichtbar -> weiter warten
check(switchedTo == nil, "update() wartet, solange Keyboard sichtbar ist")

keyboard._visible = false  -- Zuklapp-Animation fertig
SelectionRoom:update()
check(createdNames[#createdNames] == "MeinBild", "createImage mit getipptem Namen")
check(editorImageId == "meinbild", "neues Bild wird direkt im Editor geoeffnet")
check(switchedTo == editorMock, "Raumwechsel zum Editor erst nach Zuklappen")

section("SelectionRoom: Keyboard-Abbruch aendert nichts")
local imageCountBefore = #storedImages
SelectionRoom:entered()
SelectionRoom:setSelectedIndex(#storedImages + 1)  -- Neu-Eintrag ist letzter
SelectionRoom:handleAButton()
keyboard.keyboardWillHideCallback(false)           -- Nutzer bricht ab (B)
keyboard._visible = false
SelectionRoom:update()
check(#storedImages == imageCountBefore, "kein Bild angelegt nach Abbruch")

-- ── SyncService: PIN-/UID-Generierung und Persistenz (Spec 004) ──────────────

section("SyncService: PIN-/UID-Generierung")
local pin1 = SyncService:generatePin()
check(#pin1 == 4 and pin1:match("^%d%d%d%d$") ~= nil, "generatePin liefert genau 4 Ziffern")

local uid1 = SyncService:generateUid()
check(uid1:match("^pd%-[0-9a-f][0-9a-f]*$") ~= nil, "generateUid liefert pd-<hex>-Format")
check(#uid1 == 19, "generateUid: 'pd-' + 16 Hex-Zeichen (19 Zeichen gesamt)")

section("SyncService: sync/state Persistenz")
SyncService:saveState({})
local firstUid = SyncService:getOrCreateUid()
check(datastoreFiles["sync/state"] ~= nil, "saveState schreibt unter dem Pfad sync/state")
check(datastoreFiles["sync/state"].uid == firstUid, "getOrCreateUid persistiert die UID im Datastore")
local secondUid = SyncService:getOrCreateUid()
check(secondUid == firstUid, "getOrCreateUid liefert bei zweitem Aufruf dieselbe UID (kein Neu-Generieren)")

-- ── SelectionRoom: Crank-Sync-Geste (Spec 004, FR-002) ───────────────────────

section("SelectionRoom: Crank-Akkumulator loest SyncService.startSync bei 720 Grad aus")
SyncService:dismissQrOverlay()
local syncStartCalls = {}
local realStartSync = SyncService.startSync
SyncService.startSync = function(self, imageId) table.insert(syncStartCalls, imageId) end

SelectionRoom:entered()
SelectionRoom:setSelectedIndex(1)  -- erstes Bild (kind == "image")
crankChangeValue = 400
SelectionRoom:update()
check(#syncStartCalls == 0, "400 Grad allein loesen noch nichts aus")

crankChangeValue = 400
SelectionRoom:update()
check(#syncStartCalls == 1, "800 Grad kumuliert (>=720) loesen genau einen Sync-Start aus")

crankChangeValue = 0
SelectionRoom:update()
check(#syncStartCalls == 1, "Akkumulator wurde nach Ausloesen zurueckgesetzt (kein Doppel-Trigger)")

section("SelectionRoom: Crank ohne Bildauswahl bleibt wirkungslos")
syncStartCalls = {}
-- Nach "Entered SelectionRoom" mit 3 Eintraegen (bild1, meinbild, Neu-Eintrag):
-- Index 3 ist der "Neu"-Eintrag (kind == "new")
SelectionRoom:setSelectedIndex(3)
crankChangeValue = 800
SelectionRoom:update()
check(#syncStartCalls == 0, "Crank-Geste auf dem Neu-Eintrag loest keinen Sync aus")

section("SelectionRoom: Bildwechsel setzt den Akkumulator zurueck")
syncStartCalls = {}
SelectionRoom:setSelectedIndex(1)  -- bild1
crankChangeValue = 400
SelectionRoom:update()  -- accum = 400
SelectionRoom:setSelectedIndex(2)  -- meinbild (anderes Bild) -> Reset
crankChangeValue = 400
SelectionRoom:update()  -- accum = 400 (nicht 800!), kein Trigger
check(#syncStartCalls == 0, "Wechsel zwischen zwei Bildern verhindert Trigger unterhalb der Schwelle")

crankChangeValue = 0
SyncService.startSync = realStartSync

section("SyncService: Crank-Hinweis verschwindet dauerhaft nach erster tatsaechlicher Kurbel-Nutzung")
SyncService:saveState({})
SyncService:dismissQrOverlay()
SelectionRoom:entered()
SelectionRoom:setSelectedIndex(1)  -- Bild

crankChangeValue = 0
local drawCountBefore = playdate.ui.crankIndicator.drawCount
SelectionRoom:update()
check(playdate.ui.crankIndicator.drawCount > drawCountBefore, "Crank-Hinweis wird vor der ersten Nutzung gezeichnet")
check(not SyncService:hasUsedCrank(), "hasUsedCrank ist vor jeder Kurbel-Bewegung false")

crankChangeValue = 100  -- kleine Bewegung, weit unter der 720-Grad-Sync-Schwelle
SelectionRoom:update()
check(SyncService:hasUsedCrank(), "hasUsedCrank wird bereits durch eine kleine Bewegung true (nicht erst bei Schwelle)")

crankChangeValue = 0
local drawCountAfterUse = playdate.ui.crankIndicator.drawCount
SelectionRoom:update()
check(playdate.ui.crankIndicator.drawCount == drawCountAfterUse, "Crank-Hinweis wird nach der ersten Nutzung nicht mehr gezeichnet")

section("SyncService: hasUsedCrank bleibt nach App-Neustart erhalten (in sync/state persistiert)")
check(datastoreFiles["sync/state"].crankUsed == true, "crankUsed wird zusammen mit dem uebrigen Sync-Zustand persistiert")

crankChangeValue = 0

-- ── SyncService: Datei-Lesen und Multipart-Body (Spec 004, US2, T017/T018) ───

section("SyncService: readFileBytes liest rohe Bytes, nicht ueber datastore")
mockRawFiles["saves/testimg/sheet"] = "RAWSHEETDATA"
check(SyncService:readFileBytes("saves/testimg/sheet") == "RAWSHEETDATA", "readFileBytes liefert die rohen Bytes unveraendert")
check(SyncService:readFileBytes("saves/does-not-exist/sheet.pdi") == nil, "readFileBytes liefert nil fuer fehlende Datei")

section("SyncService: buildMultipartBody enthaelt alle erwarteten Teile")
local mpBody = SyncService:buildMultipartBody("BOUND123", "pd-uid1", "tok-1", "img-1", "RAWPDI", '{"a":1}')
check(mpBody:find('name="uid"', 1, true) ~= nil, "Body enthaelt uid-Feld")
check(mpBody:find("pd-uid1", 1, true) ~= nil, "Body enthaelt uid-Wert")
check(mpBody:find('name="token"', 1, true) ~= nil, "Body enthaelt token-Feld")
check(mpBody:find('name="image_id"', 1, true) ~= nil, "Body enthaelt image_id-Feld")
check(mpBody:find('filename="img-1.pdi"', 1, true) ~= nil, "Body enthaelt pdi-Dateiteil mit korrektem Dateinamen")
check(mpBody:find("RAWPDI", 1, true) ~= nil, "Body enthaelt die rohen PDI-Bytes")
check(mpBody:find('filename="img-1.json"', 1, true) ~= nil, "Body enthaelt json-Dateiteil mit korrektem Dateinamen")
check(mpBody:find("--BOUND123--", 1, true) ~= nil, "Body endet mit schliessendem Boundary")

-- ── SyncService: Pairing-Flow ueber die Mock-HTTP-Verbindung (Spec 004, US1) ──
--
-- research.md R13-Redesign: Es gibt keinen separaten, auf eine
-- Website-Bestaetigung wartenden Pairing-Schritt mehr. SyncService:startSync()
-- loest direkt Login -> bei Bedarf autonomes (Re-)Pair -> Login-Retry ->
-- Upload aus, alles in EINER RoomOperation-Kette. Das Ergebnis-Overlay
-- (QR+PIN) erscheint erst NACH erfolgreichem Upload, nicht mehr davor.

section("SyncService: Login 404 (unbekannte UID) pairt automatisch nach und laedt hoch (kein Website-Schritt noetig)")
SyncService:saveState({})
SyncService:dismissQrOverlay()
mockRawFiles["saves/bild1/sheet"] = "PDIRAWBYTES"
mockRawFiles["saves/bild1/frames.json"] = '{"frames":[]}'

SyncService:startSync("bild1")
SyncService:tick()  -- Login-Yield (Versuch 1, unbekannte UID)
simulateHttpResponse(404, "")
SyncService:tick()  -- 404 erkannt -> pair() gestartet, Yield
check(not SyncService:isShowingQrOverlay(), "Waehrend der Kette ist noch kein Ergebnis-Overlay sichtbar")
check(SyncService:isBusy(), "Die Pairing+Login+Upload-Kette laeuft weiter ohne Nutzerinteraktion")

local pairConn = mockConnections[#mockConnections]
check(pairConn.lastPath == "/pair", "Nach 404 wird automatisch /pair aufgerufen (autonomes Pairing)")
simulateHttpResponse(201, json.encode({ status = "success", uid = SyncService:getState().uid }))
SyncService:tick()  -- pair() fertig -> Login-Retry (Versuch 2), Yield
simulateHttpResponse(200, json.encode({
    status = "success", session_token = "tok-123", expires_at = "2026-01-01T00:00:00Z"
}))
SyncService:tick()  -- Login fertig -> Dateien lesen -> Multipart-POST /upload, Yield
simulateHttpResponse(201, json.encode({ status = "success", image_id = "srv-uuid-1" }))
SyncService:tick()  -- Upload abgeschlossen
check(not SyncService:isBusy(), "Kette ist nach erfolgreichem Upload beendet")
check(SyncService:getState().paired == true, "Erfolgreicher Upload markiert den Zustand als verknuepft")
check(SyncService:isShowingQrOverlay(), "Nach Upload zeigt SyncService das Ergebnis-Overlay (QR+PIN, FR-007a)")

local lastConn = mockConnections[#mockConnections]
check(lastConn.lastPath == "/upload", "Letzter Request ging an /upload")
check(lastConn.lastBody:find('name="image_id"', 1, true) ~= nil and lastConn.lastBody:find("bild1", 1, true) ~= nil,
    "Multipart-Body enthaelt die lokale Bild-ID")
check(lastConn.lastBody:find("PDIRAWBYTES", 1, true) ~= nil, "Multipart-Body enthaelt die rohen PDI-Bytes")

section("SyncService: bereits verknuepftes Geraet laedt mit einem einzigen Login hoch (kein /pair-Aufruf)")
SyncService:dismissQrOverlay()
mockRawFiles["saves/bild1/sheet"] = "PDIRAWBYTES"
mockRawFiles["saves/bild1/frames.json"] = '{"frames":[]}'

local connectionsBeforeUpload = #mockConnections
SyncService:startSync("bild1")
SyncService:tick()  -- Login-Yield
simulateHttpResponse(200, json.encode({
    status = "success", session_token = "tok-124", expires_at = "2026-01-01T00:00:00Z"
}))
SyncService:tick()  -- Login fertig -> Upload-POST, Yield
simulateHttpResponse(201, json.encode({ status = "success", image_id = "srv-uuid-1b" }))
SyncService:tick()
check(#mockConnections == connectionsBeforeUpload + 2, "Genau 2 Requests (Login + Upload), kein zusaetzlicher /pair-Aufruf")
check(SyncService:isShowingQrOverlay(), "Ergebnis-Overlay erscheint auch beim wiederholten Upload")

section("SyncService: Login 400 (PIN passt nicht, Altlast) heilt sich ueber autonomes Re-Pair selbst")
SyncService:dismissQrOverlay()
SyncService:startSync("bild1")
SyncService:tick()  -- Login-Yield (Versuch 1)
simulateHttpResponse(400, "")
SyncService:tick()  -- 400 erkannt -> pair() gestartet (Self-Heal, research.md R12), Yield
local rePairConn = mockConnections[#mockConnections]
check(rePairConn.lastPath == "/pair", "Nach 400 wird automatisch neu gepairt statt aufzugeben")
simulateHttpResponse(201, json.encode({ status = "success", uid = SyncService:getState().uid }))
SyncService:tick()  -- Re-Pair fertig -> Login-Retry, Yield
simulateHttpResponse(200, json.encode({
    status = "success", session_token = "tok-125", expires_at = "2026-01-01T00:00:00Z"
}))
SyncService:tick()  -- Login fertig -> Upload-POST, Yield
simulateHttpResponse(201, json.encode({ status = "success", image_id = "srv-uuid-1c" }))
SyncService:tick()
check(SyncService:isShowingQrOverlay(), "Nach Self-Heal + erfolgreichem Upload zeigt SyncService das Ergebnis-Overlay")

section("SyncService: Login 429 (gesperrt) versucht KEIN Re-Pair, zeigt sofort eine Fehlermeldung")
SyncService:dismissQrOverlay()
local connectionsBefore429 = #mockConnections
SyncService:startSync("bild1")
SyncService:tick()
simulateHttpResponse(429, "")
SyncService:tick()
check(#mockConnections == connectionsBefore429 + 1, "429 loest KEINEN automatischen /pair-Aufruf aus (Sperre wuerde nicht behoben)")
check(not SyncService:isShowingQrOverlay(), "429 -> kein Ergebnis-Overlay")
check(not SyncService:isBusy(), "Operation ist nach der Fehlermeldung beendet")
check(SyncService:getTransientStatusMessage() ~= nil, "429 -> Statusmeldung gesetzt (Sperre)")

section("SyncService: /pair liefert 409 (uid_taken) -> klare Fehlermeldung statt Endlosschleife")
SyncService:dismissQrOverlay()
SyncService:startSync("bild1")
SyncService:tick()
simulateHttpResponse(404, "")
SyncService:tick()  -- 404 -> pair() gestartet
simulateHttpResponse(409, "")
SyncService:tick()  -- pair() liefert 409 -> Kette bricht mit klarer Fehlermeldung ab, kein Login-Retry
check(not SyncService:isBusy(), "Operation endet nach 409, kein unendlicher Retry")
check(not SyncService:isShowingQrOverlay(), "409 -> kein Ergebnis-Overlay")
local conflictMsg = SyncService:getTransientStatusMessage()
check(conflictMsg ~= nil, "409 -> Statusmeldung gesetzt (Device-ID-Konflikt)")

section("SelectionRoom: B-Taste schliesst das Ergebnis-Overlay")
SyncService:dismissQrOverlay()
SyncService:startSync("bild1")
SyncService:tick()
simulateHttpResponse(200, json.encode({
    status = "success", session_token = "tok-126", expires_at = "2026-01-01T00:00:00Z"
}))
SyncService:tick()
simulateHttpResponse(201, json.encode({ status = "success", image_id = "srv-uuid-1d" }))
SyncService:tick()
check(SyncService:isShowingQrOverlay(), "Vorbedingung: Overlay ist sichtbar")
SelectionRoom:handleBButton()
check(not SyncService:isShowingQrOverlay(), "B schliesst das Overlay")

section("SyncService: Statusanzeige vor jeder Verknuepfung")
SyncService:saveState({})
check(SyncService:getStatusText() == "not linked yet", "getStatusText ohne Verknuepfung")

-- ── SyncService: Upload-Fehlerpfade (Spec 004, US2, T022) ────────────────────

section("SyncService: Upload mit abgelaufenem Token (401) macht genau einen Retry")
SyncService:dismissQrOverlay()
SyncService:saveState({ uid = SyncService:getState().uid or SyncService:generateUid(), pin = SyncService:getState().pin or SyncService:generatePin(), paired = true })
mockRawFiles["saves/bild1/sheet"] = "PDIRAWBYTES2"
mockRawFiles["saves/bild1/frames.json"] = '{"frames":[]}'

SyncService:startSync("bild1")  -- Login gelingt sofort (Versuch 1), kein Re-Pair noetig
SyncService:tick()  -- Login (Versuch 1) bis Yield
simulateHttpResponse(200, json.encode({ status = "success", session_token = "tok-a", expires_at = "2026-01-01T00:00:00Z" }))
SyncService:tick()  -- Login fertig -> Upload-POST (Versuch 1) bis Yield
simulateHttpResponse(401, "")
SyncService:tick()  -- 401 erkannt -> sofortiger Retry -> Login (Versuch 2) bis Yield
simulateHttpResponse(200, json.encode({ status = "success", session_token = "tok-b", expires_at = "2026-01-01T00:00:00Z" }))
SyncService:tick()  -- Login fertig -> Upload-POST (Versuch 2) bis Yield
simulateHttpResponse(201, json.encode({ status = "success", image_id = "srv-uuid-2" }))
SyncService:tick()  -- Upload (Versuch 2) erfolgreich
check(not SyncService:isBusy(), "Nach erfolgreichem Retry ist die Operation beendet")
check(SyncService:isShowingQrOverlay(), "Erfolgreicher Retry zeigt das Post-Upload-QR-Overlay")

section("SyncService: Netzwerkfehler beim Upload setzt pendingUpload")
SyncService:dismissQrOverlay()
SyncService:saveState({ uid = SyncService:getState().uid, pin = SyncService:getState().pin, paired = true })
mockRawFiles["saves/bild2/sheet"] = "X"
mockRawFiles["saves/bild2/frames.json"] = "{}"

SyncService:startSync("bild2")
SyncService:tick()  -- Login-Yield
simulateHttpResponse(200, json.encode({ status = "success", session_token = "tok-c", expires_at = "2026-01-01T00:00:00Z" }))
SyncService:tick()  -- Upload-POST-Yield
local abortedConn = mockConnections[#mockConnections]
abortedConn.errorMsg = "connection lost"
if abortedConn.onClosed then abortedConn.onClosed() end
SyncService:tick()
check(SyncService:getState().pendingUpload ~= nil, "Netzwerkfehler setzt pendingUpload (research.md R8)")
check(SyncService:getState().pendingUpload.imageId == "bild2", "pendingUpload verweist auf das betroffene Bild")

-- ── ImageStoreCodec: reine Helfer (kein gfx noetig) ──────────────────────────

section("ImageStoreCodec: Sheet-Geometrie")
dofile("Source/ImageStoreCodec.lua")

local x, y = ImageStoreCodec.tileIndexToPosition(1)
check(x == 0 and y == 0, "Tile 1 liegt bei (0,0)")
x, y = ImageStoreCodec.tileIndexToPosition(26)
check(x == 0 and y == 16, "Tile 26 beginnt Zeile 2 (0,16)")
check(ImageStoreCodec.positionToTileIndex(0, 16, 25) == 26, "positionToTileIndex ist Umkehrfunktion")

local w, h = ImageStoreCodec.getSheetDimensions(2)
check(w == 32 and h == 16, "2 Tiles -> 32x16-Sheet")
w, h = ImageStoreCodec.getSheetDimensions(26)
check(w == 400 and h == 32, "26 Tiles -> 400x32-Sheet (2 Zeilen)")

local ft = ImageStoreCodec.createFramesTable("name", { {} }, 2)
check(ft.version == 1 and ft.tileCount == 2 and #ft.frames == 0,
    "createFramesTable verwirft Frames mit falscher Laenge")

section("ImageStoreCodec: Basistiles (1=Weiss, 2=Schwarz) immer garantiert")
-- Extremfall: gar kein Sheet, tileCount 0 — Malen muss trotzdem moeglich sein
local it = ImageStoreCodec.sliceSheetToImagetable(nil, 0)
local t1, t2 = it:getImage(1), it:getImage(2)
check(t1 ~= nil and t1:sample(0, 0) ~= "black", "Index 1 ist ein weisses Tile")
check(t2 ~= nil and t2:sample(0, 0) == "black", "Index 2 ist ein schwarzes Tile")

-- Sheet kleiner als tileCount: fehlende Tiles fallen auf Weiss zurueck
local tinySheet = newMockImage(16, 16, "white")
local it2 = ImageStoreCodec.sliceSheetToImagetable(tinySheet, 5)
check(it2:getImage(2) ~= nil and it2:getImage(2):sample(0, 0) == "black",
    "Basistile Schwarz auch bei zu kleinem Sheet")
check(it2:getImage(5) ~= nil, "Luecken werden mit Weiss-Tiles gefuellt")

-- ── PixelRoom: Pencil-Strich (A toggelt Malen/Radieren) ─────────────────────

section("PixelRoom: A-Strich malt einen Wert statt zu invertieren")
dofile("Source/PixelRoom.lua")

local receivedTile = nil
local zoomMock = {
    setNewTile = function(self, t) receivedTile = t end,
    updateExistingTile = function(self, t) receivedTile = t end,
}
PixelRoom:init(noop, zoomMock)

-- weisses Ausgangs-Tile (sample liefert nie kColorBlack)
PixelRoom:setCurrentTile({ sample = function() return 0 end }, 1)
PixelRoom:entered()

local handler = PixelRoom:inputHandler()

-- Strich 1: A auf weissem Pixel (9,9) -> malt Schwarz; Bewegung mit
-- gehaltenem A malt (10,9) ebenfalls schwarz (kein Invertieren)
heldButtons[playdate.kButtonA] = true
handler.AButtonDown()
handler.rightButtonDown()
handler.rightButtonUp()
handler.AButtonUp()

-- Strich 2: A auf dem jetzt schwarzen Pixel (10,9) -> Radierer (Weiss)
handler.AButtonDown()
handler.AButtonUp()
heldButtons[playdate.kButtonA] = false

PixelRoom:commitForTerminate()
check(receivedTile ~= nil, "commit liefert ein Tile-Bild")
-- gridState[row][col] -> drawPixel(col-1, row-1); Start-Selektion ist (9,9)
check(receivedTile.pixels["8,8"] == true, "Pixel (9,9) ist schwarz gemalt")
check(receivedTile.pixels["9,8"] == nil, "Pixel (10,9) wurde vom 2. Strich radiert")

-- ── Ergebnis ──────────────────────────────────────────────────────────────────

print("")
if #failures > 0 then
    print(#failures .. " TEST(S) FEHLGESCHLAGEN:")
    for _, msg in ipairs(failures) do print("  - " .. msg) end
    os.exit(1)
else
    print("ALLE TESTS BESTANDEN")
end
