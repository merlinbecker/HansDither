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

-- Spec 006: alle fillRect-Aufrufe direkt auf den "Bildschirm" (ausserhalb
-- pushContext), von Tests lesbar/zuruecksetzbar (siehe fillRect-Mock unten)
mockScreenFillCalls = {}

local function newMockImage(w, h, bgcolor)
    return {
        width = w, height = h,
        pixels = {},
        fill = (bgcolor == "black") and "black" or "white",
        draw = noop,
        drawFaded = noop,
        -- Spec 006 US5: Tile-Vorschau-Zeichnungen in der Pause-Ansicht
        -- beobachtbar (mockDrawScaledCalls), fuer die 120-Tile-Truncation
        drawScaled = function(self, x, y, scale, yscale)
            table.insert(mockDrawScaledCalls, { x = x, y = y, scale = scale })
        end,
        -- Spec 006 US6 (revidiert): SelectionRoom maskiert das Schwenk-
        -- Thumbnail des selektierten Eintrags ueber setMaskImage()
        setMaskImage = noop,
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
        -- Spec 006: alle drawText-Aufrufe beobachtbar (mockDrawTextCalls),
        -- fuer US5-Pause-Ansicht (Tiles/Frames-Text) und Bauchbinde-Assertions
        drawText = function(text, x, y) table.insert(mockDrawTextCalls, { text = text, x = x, y = y }) end,
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
            -- Spec 006 R2: direkte Bildschirm-Fills (ausserhalb pushContext,
            -- z.B. ZoomRoom:drawGrid()) sind sonst nicht beobachtbar
            table.insert(mockScreenFillCalls, { x = x, y = y, w = w, h = h, color = currentColor })
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
        -- Spec 006: EditorRoom haelt sein Frame-Rendering ueber ein Tilemap-
        -- Objekt; fuer Logik-Tests genuegen No-op-Methoden ohne echte Grafik
        -- setTiles() zeichnet lastFrame in mockLastTilemap auf — der einzige
        -- von aussen beobachtbare Hinweis darauf, welcher Frame gerade aktiv
        -- ist (EditorRoom exponiert currentFrame sonst nicht öffentlich)
        tilemap = {
            new = function()
                local tm = {
                    lastFrame = nil,
                    setImageTable = noop,
                    setSize = noop,
                    setTiles = function(self, frame, cols) self.lastFrame = frame end,
                    setTileAtPosition = noop,
                    draw = noop,
                }
                mockLastTilemap = tm
                return tm
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
    timer = {
        updateTimers = noop,
        -- Spec 006: SDK feuert den Callback laut Doku SOFORT einmal, dann
        -- verzoegert/wiederholend — fuer Tests genuegt der Sofort-Aufruf
        keyRepeatTimerWithDelay = function(delayAfterInitial, delayAfterSecond, callback, ...)
            if callback then callback(...) end
            return { remove = noop }
        end,
    },
    -- Spec 006/008: registrierte Menü-Labels + Callbacks beobachtbar
    -- (mockMenuItemLabels/mockMenuItemCallbacks), damit Tests pruefen koennen,
    -- welche Menüpunkte vorhanden/entfernt sind (z.B. "clear screen" statt
    -- "reset frame", AD-037) UND den Menüpunkt wie eine echte Auswahl ausloesen
    getSystemMenu = function()
        return strictTable("systemMenu", {
            removeAllMenuItems = function(self)
                mockMenuItemLabels = {}
                mockMenuItemCallbacks = {}
            end,
            -- self ist der erste Parameter (EditorRoom ruft ueber menu:addMenuItem(...) —
            -- Doppelpunkt-Syntax reicht das Menu-Objekt implizit als erstes Argument durch)
            addMenuItem = function(self, title, callback)
                table.insert(mockMenuItemLabels, title)
                mockMenuItemCallbacks[title] = callback
                return { title = title, _callback = callback }
            end,
            addCheckmarkMenuItem = function(self, title, checked, callback)
                table.insert(mockMenuItemLabels, title)
                mockMenuItemCallbacks[title] = callback
                return { title = title, _callback = callback }
            end,
        })
    end,
    -- Spec 006 R4: letztes an setMenuImage() uebergebenes Bild beobachtbar
    -- (mockLastMenuImage), fuer US5-Tests
    setMenuImage = function(image, xOffset) mockLastMenuImage = image end,
    -- Spec 004: Crank-Rotationsmessung — testbar über die Modulvariable
    -- crankChangeValue (siehe unten), wie im echten SDK zustandsbehaftet
    -- ("seit dem letzten Aufruf") aber hier einfach test-gesteuert
    getCrankChange = function() return crankChangeValue end,
    isCrankDocked = function() return crankDockedValue end,
    -- Spec 006: absolute Tick-Grenzen fuer die UNVERAENDERTE B+Crank-Zoomkette
    -- (CR-01) — separat von crankChangeValue, testbar ueber crankTicksValue
    getCrankTicks = function(ticksPerRevolution) return crankTicksValue end,
}

-- Von Tests gesetzt, um Crank-Rotation/-Dock-Zustand zu simulieren
-- (siehe playdate.getCrankChange/isCrankDocked oben)
crankChangeValue = 0
crankDockedValue = false
crankTicksValue = 0

-- Spec 006: von getSystemMenu()/setMenuImage() befuellt (siehe oben), von
-- Tests gelesen
mockMenuItemLabels = {}
mockMenuItemCallbacks = {}
mockLastMenuImage = nil
mockLastTilemap = nil
mockDrawTextCalls = {}
mockDrawScaledCalls = {}

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
-- Spec 006: separates Backing Store fuer readImage() (ImageStoreCodec.newLoadOperation
-- Phase 2), von Tests mit newMockImage(...)-Objekten befuellt
local datastoreImages = {}
playdate.datastore = strictTable("datastore", {
    write = function(tbl, filename) datastoreFiles[filename] = tbl end,
    read = function(filename) return datastoreFiles[filename] end,
    delete = function(filename) datastoreFiles[filename] = nil end,
    readImage = function(filename) return datastoreImages[filename] end,
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
-- Spec 006 US6: SelectionRoom laedt bei jeder Selektion (auch der ERSTEN, aus
-- entered()->setSelectedIndex(1)) per ImageStoreCodec.newLoadOperation() die
-- vollen Bilddaten nach — muss daher VOR SelectionRoom.lua verfuegbar sein
-- (dofile ist idempotent, die spaetere ImageStoreCodec-eigene Testsektion
-- dofile't dieselbe Datei zusätzlich erneut, das ist unschädlich)
dofile("Source/ImageStoreCodec.lua")
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

section("SyncService: Upload-Limit erreicht (403) zeigt eindeutige Meldung statt generischem Fehler (Spec 007, R6)")
SyncService:dismissQrOverlay()
SyncService:saveState({ uid = SyncService:getState().uid, pin = SyncService:getState().pin, paired = true })
mockRawFiles["saves/bild3/sheet"] = "X"
mockRawFiles["saves/bild3/frames.json"] = "{}"

SyncService:startSync("bild3")
SyncService:tick()  -- Login-Yield
simulateHttpResponse(200, json.encode({ status = "success", session_token = "tok-d", expires_at = "2026-01-01T00:00:00Z" }))
SyncService:tick()  -- Upload-POST-Yield
simulateHttpResponse(403, "")
SyncService:tick()  -- 403 erkannt -> kein Retry, sofortige Statusanzeige
check(not SyncService:isBusy(), "403 beendet die Operation ohne Retry (anders als 401)")
check(SyncService:getTransientStatusMessage() == "Upload limit reached (12 images)",
    "403 zeigt eine von 'Upload failed' unterscheidbare Meldung, nicht den generischen else-Zweig")

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

-- ── PixelRoom: Rotation per Crank-Volldrehung (Spec 008 US2, AD-036) ────────

section("PixelRoom: volle Kurbelumdrehung rotiert das Tile exakt um 90 Grad")

local rotatedReceivedTile = nil
local zoomMock2 = {
    setNewTile = function(self, t) rotatedReceivedTile = t end,
    updateExistingTile = function(self, t) rotatedReceivedTile = t end,
}
PixelRoom:init(noop, zoomMock2)

-- Asymmetrisches Testmuster: genau ein schwarzes Pixel oben links (0,0)
local cornerTile = newMockImage(16, 16, "white")
cornerTile.pixels["0,0"] = true
PixelRoom:setCurrentTile(cornerTile, 1)
PixelRoom:entered()

heldButtons[playdate.kButtonB] = false
crankChangeValue = 0
crankTicksValue = 0

-- Teildrehung (270 Grad) darf noch keine Rotation ausloesen (FR-007)
crankChangeValue = 270
PixelRoom:update()
crankChangeValue = 0
PixelRoom:commitForTerminate()
check(rotatedReceivedTile.pixels["0,0"] == true, "270 Grad (Teildrehung): Bild unveraendert (FR-007)")

-- Weitere 90 Grad (360 gesamt) -> genau eine 90-Grad-Drehung im Uhrzeigersinn
crankChangeValue = 90
PixelRoom:update()
crankChangeValue = 0
PixelRoom:commitForTerminate()
check(rotatedReceivedTile.pixels["15,0"] == true, "Volle Umdrehung vorwaerts: oben-links wandert nach oben-rechts (FR-005)")
check(rotatedReceivedTile.pixels["0,0"] == nil, "Urspruengliche Position ist nicht mehr schwarz")

-- Drei weitere volle Umdrehungen vorwaerts (insgesamt 4 seit Start) ergeben
-- wieder exakt das Ausgangsbild (Rundlauf ueber 360 Grad, SC-004)
for i = 1, 3 do
    crankChangeValue = 360
    PixelRoom:update()
    crankChangeValue = 0
end
PixelRoom:commitForTerminate()
check(rotatedReceivedTile.pixels["0,0"] == true, "Vier volle Umdrehungen vorwaerts: wieder exakt das Ausgangsbild (SC-004)")

-- Volle Rueckwaertsdrehung rotiert symmetrisch gegen den Uhrzeigersinn (FR-006)
crankChangeValue = -360
PixelRoom:update()
crankChangeValue = 0
PixelRoom:commitForTerminate()
check(rotatedReceivedTile.pixels["0,15"] == true, "Volle Rueckwaertsdrehung: oben-links wandert nach unten-links (FR-006)")

crankChangeValue = 0
crankTicksValue = 0

-- Regressionsschutz: B+Crank-Zoomkette bleibt unveraendert funktionsfaehig
-- (Contract PR-01 - pro update() genau eine Crank-Lese-API)
local switchedTo = nil
PixelRoom:init(function(room) switchedTo = room end, zoomMock2)
PixelRoom:setCurrentTile(cornerTile, 1)
PixelRoom:entered()
heldButtons[playdate.kButtonB] = true
crankTicksValue = -4
PixelRoom:update()
check(switchedTo == zoomMock2, "B+Crank (-4 Ticks): Zoom-Out weiterhin ausgeloest (Contract PR-01 Regressionsschutz)")
crankTicksValue = 0
heldButtons[playdate.kButtonB] = false

-- ── ZoomRoom: Subpixel-Rendering unbearbeiteter Zellen (Spec 006 US1, R2) ────

section("ZoomRoom: unbearbeitete Zelle zeigt vier echte Subpixel-Werte")
dofile("Source/PencilCursor.lua")
dofile("Source/ZoomRoom.lua")

ZoomRoom:init(noop, {}, { applyTileEdits = noop })

-- Gemischtes 2x2-Quellmuster an der Cursor-Zelle (12,12 -> Slot (2,2),
-- lokale Zelle (4,4) -> Pixel (6,6)): schwarz/weiss diagonal
local mixedTile = newMockImage(16, 16, "white")
mixedTile.pixels["6,6"] = true
mixedTile.pixels["7,7"] = true

local ctxSlots = {}
for sr = 1, 3 do
    ctxSlots[sr] = {}
    for sc = 1, 3 do
        if sr == 2 and sc == 2 then
            ctxSlots[sr][sc] = { oob = false, originalImage = mixedTile }
        else
            ctxSlots[sr][sc] = { oob = true }
        end
    end
end
local ctxGridState = {}
for r = 1, 24 do
    ctxGridState[r] = {}
    for c = 1, 24 do
        ctxGridState[r][c] = false
    end
end

ZoomRoom:setFromEditorContext({ slots = ctxSlots, gridState = ctxGridState, showGrid = true, imageData = {} })

local function fillColorAt(x, y, w, h)
    local color = nil
    for _, f in ipairs(mockScreenFillCalls) do
        if f.x == x and f.y == y and f.w == w and f.h == h then color = f.color end
    end
    return color
end

mockScreenFillCalls = {}
ZoomRoom:update()  -- needsRedraw ist nach setFromEditorContext true -> drawGrid()

-- Bildschirmzelle (12,12): x = OFFSET_X(80) + 11*CELL_SIZE(10) = 190, y = 110
check(fillColorAt(190, 110, 5, 5) == "black", "Subpixel oben-links (Quellpixel 6,6) ist schwarz")
check(fillColorAt(195, 110, 5, 5) == "white", "Subpixel oben-rechts (Quellpixel 7,6) ist weiss")
check(fillColorAt(190, 115, 5, 5) == "white", "Subpixel unten-links (Quellpixel 6,7) ist weiss")
check(fillColorAt(195, 115, 5, 5) == "black", "Subpixel unten-rechts (Quellpixel 7,7) ist schwarz")

-- Nach einem simulierten Malstrich auf derselben Zelle wird sie einfarbig
-- (kein Rueckfall in die Quadranten-Darstellung, FR-008)
local zoomHandler = ZoomRoom:inputHandler()
zoomHandler.AButtonDown()
zoomHandler.AButtonUp()

mockScreenFillCalls = {}
ZoomRoom:update()

check(fillColorAt(190, 110, 5, 5) == nil, "Nach Bearbeitung: keine 5x5-Subpixel-Fills mehr an der Zelle")
check(fillColorAt(190, 110, 10, 10) ~= nil, "Nach Bearbeitung: Zelle ist ein einzelner 10x10-Block")

-- ── ZoomRoom: Hintergrund-Cache statt Vollbild-Neuzeichnung (Spec 008 US1, AD-035) ──

section("ZoomRoom: Redraw-Cache invalidiert sich nur bei Kontextwechsel, nicht bei Cursorbewegung")

local zoomHandler2 = ZoomRoom:inputHandler()

-- Sauberer Ausgangszustand: frischer Kontextwechsel setzt gridState komplett
-- zurueck (kein Uebertrag der Bearbeitung aus der vorherigen Testsektion)
-- und erzwingt einen vollen Cache-Rebuild.
ZoomRoom:setFromEditorContext({ slots = ctxSlots, gridState = ctxGridState, showGrid = true, imageData = {} })
mockScreenFillCalls = {}
ZoomRoom:update()

-- Reine Cursorbewegung ohne Malen darf KEINE einzige Zell-Neuzeichnung
-- ausloesen - der Cache wurde gerade eben frisch gebaut, nichts ist editiert.
mockScreenFillCalls = {}
zoomHandler2.rightButtonDown()
zoomHandler2.rightButtonUp()
ZoomRoom:update()
check(#mockScreenFillCalls == 0, "Reine Cursorbewegung ohne jede Bearbeitung loest keine einzige Zell-Neuzeichnung aus (FR-002/003)")

-- Ein Malstrich redrawt genau die eine betroffene Zelle (changedCells-Overlay,
-- FR-002) statt das gesamte 24x24-Raster neu zu berechnen.
mockScreenFillCalls = {}
zoomHandler2.AButtonDown()
zoomHandler2.AButtonUp()
ZoomRoom:update()
check(#mockScreenFillCalls == 1, "Malstrich loest genau EINEN Fill-Aufruf aus - nur die geaenderte Zelle, nicht das gesamte Raster (AD-035)")

-- Regressionstest fuer den gemeldeten Bug: ein WEITERER Redraw OHNE neues
-- Malen (z.B. reine Cursorbewegung) darf die bereits gemalte Zelle NICHT
-- wieder auf den (veralteten) Cache-Stand zurueckfallen lassen. Vorher wurde
-- changedCells faelschlich nach JEDEM Redraw geleert, obwohl der Cache selbst
-- die Aenderung nie erfahren hat - die Zelle verschwand beim naechsten
-- Redraw wieder, bis man den Zoom Room verliess und neu betrat.
mockScreenFillCalls = {}
zoomHandler2.leftButtonDown()
zoomHandler2.leftButtonUp()
ZoomRoom:update()
check(fillColorAt(200, 110, 10, 10) ~= nil, "Bereits gemalte Zelle bleibt auch bei einem SPAETEREN Redraw ohne neues Malen sichtbar (Bugfix Redraw-Cache)")
check(fillColorAt(200, 110, 5, 5) == nil, "...und faellt dabei nicht zurueck in die unbearbeitete Subpixel-Darstellung")

-- setNewTile() (Rueckkehr aus dem PixelRoom) MUSS den Cache invalidieren -
-- der naechste Redraw baut wieder das volle Raster (>100 statt 1 Fill-Aufruf).
mockScreenFillCalls = {}
ZoomRoom:setNewTile(newMockImage(16, 16, "white"))
ZoomRoom:update()
check(#mockScreenFillCalls > 100, "setNewTile() invalidiert den Hintergrund-Cache und erzwingt einen vollstaendigen Neuaufbau (Contract ZR-02)")

-- ── EditorRoom: Setup-Helfer (Spec 006 US2-US5) ──────────────────────────────

dofile("Source/EditorRoom.lua")

local editorSwitchedTo = nil
EditorRoom:init(function(room) editorSwitchedTo = room end, ZoomRoom, {})

section("EditorRoom: buildPauseMenuImage() liefert nil ohne geladenes Bild")
check(EditorRoom:buildPauseMenuImage() == nil, "Kein imageData geladen -> nil (Contract Abschnitt 4)")

local function makeFrame(fillIndex)
    local frame = {}
    for i = 1, 375 do frame[i] = fillIndex end
    return frame
end

-- Treibt setImage()+entered()+update()-Kette bis zum fertigen Laden synchron
-- durch: ImageStoreCodec.newLoadOperation hat 4 Yields + finalen Return, also
-- GENAU 5 RoomOperation:resume()-Aufrufe (= 5 EditorRoom:update()). Bewusst
-- KEIN "getImageData() ~= nil"-Abbruch: bei einem zweiten/dritten Laden in
-- derselben Testsuite ist imageData vom VORHERIGEN Bild bereits nicht-nil,
-- bevor der neue Ladevorgang ueberhaupt gestartet wurde — das wuerde die
-- Schleife sofort verlassen, ohne den neuen Ladevorgang je zu resumen.
local function loadEditorImageForTest(id, framesArray, tileCount, name)
    datastoreFiles["saves/" .. id .. "/frames"] = { frames = framesArray, tileCount = tileCount, name = name }
    datastoreImages["saves/" .. id .. "/sheet"] = newMockImage(16, 16, "white")
    EditorRoom:setImage(id)
    EditorRoom:entered()
    for _ = 1, 5 do
        EditorRoom:update()
    end
end

-- ── US2: Crank-Volldrehung (T005, research.md R1, Contract CR-01) ───────────

section("EditorRoom: Frame-Wechsel erst bei 360 Grad Netto-Kurbeldrehung (Spec 006 US2, R1)")
loadEditorImageForTest("crankTest", { makeFrame(1), makeFrame(2), makeFrame(3) }, 3, "crank-test")
check(EditorRoom:getImageData() ~= nil, "Vorbedingung: Bild mit 3 Frames geladen")
check(mockLastTilemap.lastFrame[1] == 1, "Vorbedingung: Frame 1 aktiv")

crankChangeValue = 270
EditorRoom:update()
check(mockLastTilemap.lastFrame[1] == 1, "AS1: 270 Grad -> Frame 1 bleibt aktiv (kein Wechsel)")

crankChangeValue = 90
EditorRoom:update()
check(mockLastTilemap.lastFrame[1] == 2, "AS2/AS3: weitere 90 Grad (360 gesamt) -> genau ein Wechsel zu Frame 2")

crankChangeValue = 270
EditorRoom:update()
crankChangeValue = -90
EditorRoom:update()
check(mockLastTilemap.lastFrame[1] == 2, "Edge Case: 270+(-90)=180 Grad netto -> kein Wechsel (bleibt Frame 2)")

crankChangeValue = 180
EditorRoom:update()
check(mockLastTilemap.lastFrame[1] == 3, "Restwert bleibt erhalten: weitere 180 Grad (360 seit letztem Wechsel) -> Frame 3")
crankChangeValue = 0

-- Regressionsschutz (CR-01): B+Crank-Zoomkette bleibt unveraendert
heldButtons[playdate.kButtonB] = true
crankTicksValue = 4  -- ZOOM_TICK_THRESHOLD
editorSwitchedTo = nil
EditorRoom:update()
check(editorSwitchedTo == ZoomRoom, "B+Crank (4 Ticks): Zoomkette weiterhin ausgeloest (CR-01 Regressionsschutz)")
heldButtons[playdate.kButtonB] = false
crankTicksValue = 0

-- ── US3: Bauchbinde-Sichtbarkeit/-Seite (T009, research.md R3, CR-02/CR-03) ──

section("EditorRoom: Bauchbinde blendet nach 5s Inaktivitaet aus und weicht dem Cursor aus (Spec 006 US3, R3)")
mockTimeMs = 1000

local function bandFillEntry()
    for _, f in ipairs(mockScreenFillCalls) do
        if f.h == 22 then return f end
    end
    return nil
end

-- Reset VOR dem Laden: der letzte der 5 Lade-Updates zeichnet bereits die
-- (sichtbare) Bauchbinde, ein weiterer update()-Aufruf ohne Zustandsaenderung
-- wuerde wegen needsRedraw==false gar nicht mehr neu zeichnen.
mockScreenFillCalls = {}
loadEditorImageForTest("bauchbindeTest", { makeFrame(1) }, 2, "bb-test")
check(bandFillEntry() ~= nil, "Direkt nach dem Laden: Bauchbinde sichtbar")
check(bandFillEntry().x == 348, "Cursor links (Start x=1): Bauchbinde rechts (CR-03)")

mockTimeMs = mockTimeMs + 5001
mockScreenFillCalls = {}
EditorRoom:update()
check(bandFillEntry() == nil, "Nach 5s Inaktivitaet ohne jede Eingabe: Bauchbinde ausgeblendet (FR-001)")

local editorHandler = EditorRoom:inputHandler()
editorHandler.AButtonDown()
editorHandler.AButtonUp()
mockScreenFillCalls = {}
EditorRoom:update()
check(bandFillEntry() ~= nil, "Nach Eingabe (A-Druck): Bauchbinde sofort wieder sichtbar (FR-002)")

for _ = 1, 24 do
    editorHandler.rightButtonDown()
end
mockScreenFillCalls = {}
EditorRoom:update()
check(bandFillEntry().x == 4, "Cursor rechts (x=25): Bauchbinde links (CR-03, invers zur Cursorposition)")

-- Regressionstest (T029-Architektur-Review, CR-02): B-Druck ALLEIN (ohne
-- Crank-Bewegung, ohne Release) muss ebenfalls als Aktivitaet zaehlen —
-- sonst wuerde langes B-Halten ohne Kurbelbewegung die Bauchbinde faelschlich
-- ausblenden lassen, obwohl pipette() (B-Release) noch gar nicht gelaufen ist
mockTimeMs = mockTimeMs + 5001
mockScreenFillCalls = {}
EditorRoom:update()
check(bandFillEntry() == nil, "Vorbedingung: erneut 5s ohne Eingabe -> Bauchbinde wieder ausgeblendet")

editorHandler.BButtonDown()
mockScreenFillCalls = {}
EditorRoom:update()
check(bandFillEntry() ~= nil, "B-Druck ALLEIN (kein Release, keine Kurbel) zaehlt bereits als Aktivitaet (CR-02)")
editorHandler.BButtonUp()

-- ── US3 (Spec 008): "Clear Screen" ersetzt "Reset Frame" (T014, AD-037, EM-01..03) ──

section("EditorRoom: 'Clear Screen' leert den aktiven Frame vollstaendig; Menue zeigt 'clear screen' statt 'reset frame'")
loadEditorImageForTest("clearTest", { makeFrame(5), makeFrame(9) }, 10, "clear-test")

local hasClear, hasReset = false, false
for _, label in ipairs(mockMenuItemLabels) do
    if label == "clear screen" then hasClear = true end
    if label == "reset frame" then hasReset = true end
end
check(hasClear, "Systemmenue enthaelt 'clear screen' (EM-01)")
check(not hasReset, "Systemmenue enthaelt NICHT mehr 'reset frame' (AD-037, FR-011)")

-- Zu Frame 2 wechseln (Vorbedingung: gefuellt mit Tile-Index 9, nicht 1)
crankChangeValue = 360
EditorRoom:update()
crankChangeValue = 0
check(mockLastTilemap.lastFrame[1] == 9, "Vorbedingung: Frame 2 aktiv, gefuellt mit Tile-Index 9")

mockMenuItemCallbacks["clear screen"]()
local frames = EditorRoom:getImageData().frames
local frame2AllWhite = true
for i = 1, #frames[2] do
    if frames[2][i] ~= 1 then frame2AllWhite = false end
end
check(frame2AllWhite, "'clear screen' setzt alle 375 Indizes des aktiven Frames auf Basis-Index 1 (Voll-Weiss, FR-012)")
check(mockLastTilemap.lastFrame[1] == 1, "Tilemap zeigt den geleerten Frame sofort an")

local frame1Untouched = true
for i = 1, #frames[1] do
    if frames[1][i] ~= 5 then frame1Untouched = false end
end
check(frame1Untouched, "Anderer Frame (Frame 1) bleibt unveraendert (FR-013)")

-- Idempotenz: erneutes 'clear screen' auf bereits leerem Frame aendert nichts
mockMenuItemCallbacks["clear screen"]()
local stillAllWhite = true
for i = 1, #frames[2] do
    if frames[2][i] ~= 1 then stillAllWhite = false end
end
check(stillAllWhite, "'clear screen' auf bereits leerem Frame ist idempotent (kein Fehler, keine Aenderung)")

-- ── US5: Kontext-/Pause-Ansicht (T017, research.md R4, CR-06/CR-07) ─────────

section("EditorRoom: Pause-Ansicht zaehlt tatsaechlich referenzierte Tiles, nicht imagetable:getLength() (Spec 006 US5)")

local mixedFrame = {}
for i = 1, 375 do mixedFrame[i] = (i % 5) + 1 end  -- referenziert Tile-Indizes 1..5
-- tileCount=10 -> imagetable haette 10 Slots; tatsaechlich referenziert werden nur 5 (CR-06)
loadEditorImageForTest("pauseSmall", { makeFrame(1), mixedFrame }, 10, "pause-small")

local function drawTextContains(expected)
    for _, c in ipairs(mockDrawTextCalls) do
        if c.text == expected then return true end
    end
    return false
end

mockDrawTextCalls = {}
mockDrawScaledCalls = {}
local pauseImg = EditorRoom:buildPauseMenuImage()
check(pauseImg ~= nil, "buildPauseMenuImage() liefert ein Bild bei geladenem imageData")
check(drawTextContains("Tiles: 5"), "Gesamtzahl basiert auf tatsaechlich referenzierten Indizes (5), nicht imagetable:getLength() (10, CR-06)")
check(drawTextContains("Frames: 2"), "Frame-Anzahl als Metainformation (FR-012)")
check(#mockDrawScaledCalls == 5, "5 Tile-Vorschauen gezeichnet (<=120, keine Truncation noetig)")

-- >120 unterschiedliche Tiles: Raster zeigt nur 120, Gesamtzahl bleibt korrekt
local bigFrame = {}
for i = 1, 375 do bigFrame[i] = ((i - 1) % 150) + 1 end  -- referenziert 1..150
loadEditorImageForTest("pauseBig", { bigFrame }, 150, "pause-big")

mockDrawTextCalls = {}
mockDrawScaledCalls = {}
EditorRoom:buildPauseMenuImage()
check(drawTextContains("Tiles: 150"), "Gesamtzahl bleibt trotz Truncation vollstaendig korrekt (FR-013)")
check(#mockDrawScaledCalls == 120, "Raster zeigt nur die ersten 120 Vorschauen (CR-07)")

-- ── SelectionRoom: Kreis-Schwenk des selektierten Eintrags (Spec 006 US6, ───
-- revidiert) ──────────────────────────────────────────────────────────────

section("SelectionRoom: selektierter Eintrag bleibt kreisförmig maskiert und schwenkt den Bildausschnitt über die Zeit, nicht selektierte Einträge bleiben unverändert zentriert")

table.insert(storedImages, { id = "panimg", name = "panimg", frameCount = 1, lastEdited = 2 })

local panPreview = newMockImage(400, 240, "white")
local previewsById = { panimg = panPreview, bild1 = newMockImage(400, 240, "white") }
ImageStore.getPreviewImage = function(id) return previewsById[id] end

SelectionRoom:entered()  -- baut Eintraege neu (inkl. panimg)

local function indexOfEntryId(targetId)
    for i, img in ipairs(storedImages) do
        if img.id == targetId then return i end
    end
    return nil
end

local idxPanImg = indexOfEntryId("panimg")
SelectionRoom:setSelectedIndex(idxPanImg)

mockTimeMs = 0
SelectionRoom:update()

-- Der Schwenk-Ausschnitt aendert sich mit der Zeit: getPanningThumbnail()
-- liefert an zwei verschiedenen Zeitpunkten unterschiedliche, aber jeweils
-- gueltige (72x72, maskierte) Thumbnails.
local thumbA = SelectionRoom:getPanningThumbnail("panimg")
mockTimeMs = 1000  -- Viertelperiode von PAN_PERIOD_MS=4000 -> anderer Ausschnitt
local thumbB = SelectionRoom:getPanningThumbnail("panimg")
check(thumbA ~= nil and thumbB ~= nil, "Schwenk-Thumbnail wird zu beiden Zeitpunkten erzeugt")
local thumbAWidth = thumbA:getSize()
check(thumbAWidth == 72, "Schwenk-Thumbnail bleibt auf Kreisdurchmesser (72px) begrenzt, unabhaengig vom Ausschnitt")

-- Nicht selektierte Einträge bleiben unverändert: bild1 ist NICHT selektiert,
-- getThumbnail() liefert weiterhin den gecachten, zentrierten Ausschnitt.
local nonSelectedThumb1 = SelectionRoom:getThumbnail("bild1")
local nonSelectedThumb2 = SelectionRoom:getThumbnail("bild1")
check(nonSelectedThumb1 == nonSelectedThumb2, "Thumbnail nicht selektierter Einträge bleibt gecacht (kein Schwenk)")

check(true, "update() mit selektiertem Bild-Eintrag laeuft ohne Fehler durch")

-- ── Ergebnis ──────────────────────────────────────────────────────────────────

print("")
if #failures > 0 then
    print(#failures .. " TEST(S) FEHLGESCHLAGEN:")
    for _, msg in ipairs(failures) do print("  - " .. msg) end
    os.exit(1)
else
    print("ALLE TESTS BESTANDEN")
end
