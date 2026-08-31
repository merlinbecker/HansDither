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
        -- Spec 010: "clear" (kColorClear) bleibt erhalten — ImageStoreCodec.hashTile
        -- unterscheidet seit Spec 010 drei Zustaende (schwarz/weiss/transparent).
        fill = (bgcolor == "black") and "black" or (bgcolor == "clear") and "clear" or "white",
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
        -- sample() liefert die je Pixel gespeicherte Farbe. Spec 010: der
        -- drawPixel-Mock legt weisse/transparente Pixel als "white"/"clear"
        -- ab, schwarze weiterhin als `true` (Alt-Tests pruefen `pixels[k] == true`
        -- direkt). Ungezeichnete Pixel fallen auf die Hintergrundfarbe zurueck.
        sample = function(self, x, y)
            local p = self.pixels[x .. "," .. y]
            if p == true then return "black" end
            if p ~= nil then return p end
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
                -- Spec 010: Farbe je Pixel festhalten. Schwarz bleibt `true`
                -- (Alt-Tests: `pixels[k] == true`), weiss/transparent als
                -- "white"/"clear" — sonst laesst sich ein zu Weiss radierter
                -- oder transparent gemalter Pixel nicht vom Hintergrund
                -- unterscheiden (buildTileImage/shiftLayerContent lesen zurueck).
                drawContext.pixels[x .. "," .. y] = (currentColor == "black") and true or currentColor
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
    -- Spec 009: Gegenstueck zu readImage, noetig um newSaveOperation() bis
    -- zum Ende durchzutreiben (Phase "Bilddaten" schreibt sheet.pdi)
    writeImage = function(img, filename) datastoreImages[filename] = img end,
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
    -- Spec 009: ImageStoreCodec.newSaveOperation() legt den saves/<id>-Ordner
    -- an, bevor frames.json geschrieben wird — reicht als No-op, da die
    -- Mock-Backing-Stores (datastoreFiles/datastoreImages) keine echte
    -- Verzeichnisstruktur kennen
    mkdir = noop,
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
    -- Spec 009: ImageStoreCodec.updateIndexAfterSave() (letzte Phase von
    -- newSaveOperation()) braucht beide Methoden, um den vollstaendigen
    -- Save-Coroutine-Durchlauf zu ermoeglichen
    getIndex = function() return { images = {} } end,
    writeIndex = noop,
})

-- Spec 010: Foundational-Module — muessen VOR ImageStoreCodec/EditorRoom/
-- ZoomRoom/PixelRoom geladen sein (import "..." ist im Headless-Harness ein
-- No-op, siehe oben; die Globals LayerModel/PixelTransparency entstehen nur
-- ueber diese dofile-Aufrufe).
dofile("Source/PixelTransparency.lua")
dofile("Source/LayerModel.lua")

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

section("ImageStoreCodec: Tile-Bereinigung beim Speichern (Spec 009, FR-001..004)")

-- Baut eine Mock-Imagetable mit n unterscheidbaren Tiles — jedes Tile
-- traegt einen eigenen "Fingerabdruck" (tag), damit sich nach dem Remap
-- pruefen laesst, ob wirklich derselbe Inhalt an der neuen Position liegt
-- (image:draw() ist in diesem Mock ein No-op, echte Pixelkopien sind daher
-- nicht beobachtbar — tag ist das mock-taugliche Aequivalent)
local function buildTaggedImagetable(n)
    local it = playdate.graphics.imagetable.new(n)
    for i = 1, n do
        local img = newMockImage(16, 16, "white")
        img.tag = i
        it:setImage(i, img)
    end
    return it
end

-- Fall 1: Ein in keinem Frame mehr referenziertes Tile (Index 4) wird
-- entfernt; verbleibende Positionen zeigen nach dem Remap weiterhin auf
-- denselben Inhalt (data-model.md Abschnitt 1, Beispieltabelle)
do
    local it = buildTaggedImagetable(5) -- 1=Weiss,2=Schwarz,3,4,5
    local frames = { { 1, 3, 5, 1 } } -- Tile 4 wird nirgends referenziert
    local newIt, newFrames, newCount = ImageStoreCodec.pruneUnusedTiles(it, frames, 5)
    check(newCount == 4, "Ungenutztes Tile entfernt -> 4 statt 5 verbleibende Tiles")
    check(newIt:getImage(1).tag == 1, "Index 1 (Weiss) bleibt an Position 1")
    check(newIt:getImage(2).tag == 2, "Index 2 (Schwarz) bleibt an Position 2")
    check(newIt:getImage(3).tag == 3, "Tile 3 bleibt an Position 3")
    check(newIt:getImage(4).tag == 5, "Tile 5 rueckt auf Position 4 (Index 4 entfaellt)")
    check(newFrames[1][2] == 3, "Frame-Position zeigt weiterhin auf Tile 3 (unveraenderter Index)")
    check(newFrames[1][3] == 4, "Frame-Position auf vormals Tile 5 zeigt jetzt auf den neuen Index 4")
end

-- Fall 2: Ein Bild, das ausschliesslich Weiss/Schwarz nutzt, behaelt
-- trotzdem genau 2 Tiles (Basistiles werden nie entfernt)
do
    local it = buildTaggedImagetable(2)
    local frames = { { 1, 1, 1, 2 } }
    local _, _, newCount = ImageStoreCodec.pruneUnusedTiles(it, frames, 2)
    check(newCount == 2, "Nur Basistiles genutzt -> bleibt bei 2 Tiles")
end

-- Fall 2b: Selbst wenn KEIN Frame jemals Schwarz referenziert, bleibt das
-- Schwarz-Basistile (Index 2) erhalten
do
    local it = buildTaggedImagetable(2)
    local frames = { { 1, 1, 1, 1 } }
    local newIt, _, newCount = ImageStoreCodec.pruneUnusedTiles(it, frames, 2)
    check(newCount == 2, "Basistile Schwarz bleibt erhalten, auch wenn nirgends referenziert")
    check(newIt:getImage(2) ~= nil, "Schwarz-Basistile (Index 2) weiterhin vorhanden")
end

-- Fall 3: Regressionstest gegen ImageStore.createImage()s Neubild-Muster
-- (1 Frame, alle 375 Positionen = Index 1, tileCount = 2) — die Invariante
-- tileCount >= 2 darf NICHT auf 1 kollabieren (research.md R2)
do
    local it = buildTaggedImagetable(2)
    local frameData = {}
    for i = 1, 375 do frameData[i] = 1 end
    local _, _, newCount = ImageStoreCodec.pruneUnusedTiles(it, { frameData }, 2)
    check(newCount == 2, "Neubild-Muster (nur Index 1 referenziert) liefert tileCount=2, nicht 1")
end

-- Fall 4: Integrations-Round-Trip ueber die echte newSaveOperation()-
-- Coroutine (nicht nur die reine Funktion) — verifiziert, dass Phase 1
-- ("Dedup") tatsaechlich in den nachfolgenden Phasen ankommt: die
-- geschriebene frames.json traegt den bereinigten tileCount und die
-- remappten Indizes. Echte Pixel-Rekonstruktion ueber Sheet-Compose ->
-- PDI-Schreiben -> Slicing ist mit diesem Mock nicht sinnvoll pruefbar
-- (image:draw() ist ueberall in dieser Datei ein No-op) — das betrifft
-- alle Tests dieser Datei, nicht nur diesen, daher wird hier bewusst auf
-- Metadaten-Ebene (tileCount + Frame-Indizes) geprueft.
do
    local it = buildTaggedImagetable(5)
    local frameData = {}
    for i = 1, 375 do frameData[i] = 1 end
    frameData[1] = 3 -- referenziert Tile 3
    frameData[2] = 5 -- referenziert Tile 5 (Tile 4 bleibt ungenutzt)
    local imageData = {
        id = "prune-roundtrip-test",
        name = "prune-roundtrip-test",
        imagetable = it,
        frames = { frameData },
        hashIndex = {},
    }

    local co = ImageStoreCodec.newSaveOperation(imageData)
    while coroutine.status(co) ~= "dead" do
        local ok, err = coroutine.resume(co)
        check(ok, "newSaveOperation() laeuft ohne Fehler durch: " .. tostring(err))
    end

    -- Spec 010: newSaveOperation() schreibt jetzt v1.1 (verschachtelte Ebenen).
    -- Ein flach uebergebenes imageData.frames wird je Frame zur Basisebene
    -- "Layer 1" gewrappt; die Positionen liegen in frames[f].layers[1].positions.
    local saved = datastoreFiles["saves/prune-roundtrip-test/frames"]
    check(saved ~= nil, "frames.json wurde geschrieben")
    check(saved and saved.version == "1.1", "frames.json traegt version 1.1 (Spec 010)")
    check(saved and saved.tileCount == 4, "gespeicherter tileCount spiegelt die Bereinigung wider (4 statt 5)")
    local baseLayer = saved and saved.frames[1] and saved.frames[1].layers[1]
    check(baseLayer ~= nil and #baseLayer.positions == 375,
        "Frame 1 hat genau eine Basisebene mit 375 Positionen")
    check(baseLayer and baseLayer.positions[1] == 3, "Position 1 zeigt weiterhin auf Tile 3 (unveraenderter Index)")
    check(baseLayer and baseLayer.positions[2] == 4, "Position 2 zeigt jetzt auf den neuen Index 4 (vormals Tile 5)")
    check(datastoreImages["saves/prune-roundtrip-test/sheet"] ~= nil, "sheet.pdi wurde geschrieben (Bilddaten-Phase erreicht)")
end

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

-- ── PixelRoom: Transparenz (Spec 010, US2) ─────────────────────────────────

-- Bewegt den PixelRoom-Cursor deterministisch nach oben-links (Zelle 1,1 ->
-- Pixel "0,0"); der Selektionszustand des gridView ueberlebt sonst aus
-- vorherigen Testabschnitten.
local function pixelCursorToOrigin(h)
    for _ = 1, 16 do h.leftButtonDown(); h.leftButtonUp() end
    for _ = 1, 16 do h.upButtonDown(); h.upButtonUp() end
end

section("PixelRoom: 'Nicht-Tinte'-Zustand ist ebenenabhaengig (Spec 010, US2, Third Round)")
local tpTile = nil
local tpZoom = { setNewTile = function(_, t) tpTile = t end, updateExistingTile = function(_, t) tpTile = t end }
local T = PixelTransparency.TRANSPARENT

-- OBERE Ebene: offState = TRANSPARENT. B malt transparent, A radiert nach transparent.
PixelRoom:init(noop, tpZoom)
PixelRoom:setCurrentTile({ sample = function() return "white" end }, 1, T)
PixelRoom:entered()
local tph = PixelRoom:inputHandler()
for b in pairs(heldButtons) do heldButtons[b] = nil end
crankChangeValue = 0; crankTicksValue = 0
pixelCursorToOrigin(tph)

tph.BButtonDown(); tph.BButtonUp()
PixelRoom:commitForTerminate()
check(tpTile:sample(0, 0) == "clear", "obere Ebene: B-Druck malt einen transparenten Pixel (FR-007)")

tph.AButtonDown(); tph.AButtonUp()
PixelRoom:commitForTerminate()
check(tpTile:sample(0, 0) == "black", "obere Ebene: A auf transparentem Pixel -> Tinte (AS2)")

tph.AButtonDown(); tph.AButtonUp()
PixelRoom:commitForTerminate()
check(tpTile:sample(0, 0) == "clear", "obere Ebene: A auf Tinte -> radiert nach transparent (nicht weiss!)")

-- BASISEBENE: offState = EMPTY (Default). B malt WEISS, A radiert nach weiss.
PixelRoom:setCurrentTile({ sample = function() return "white" end }, 1)  -- kein offStateCode -> EMPTY
PixelRoom:entered()
local bh = PixelRoom:inputHandler()
pixelCursorToOrigin(bh)
bh.BButtonDown(); bh.BButtonUp()
PixelRoom:commitForTerminate()
check(tpTile:sample(0, 0) == "white", "Basisebene: B-Druck = weiss (identisch zum Radierer, kein Transparent)")
bh.AButtonDown(); bh.AButtonUp()   -- weiss -> Tinte
bh.AButtonDown(); bh.AButtonUp()   -- Tinte -> weiss
PixelRoom:commitForTerminate()
check(tpTile:sample(0, 0) == "white", "Basisebene: A toggelt Tinte <-> weiss")

section("PixelRoom: transparenter Strich + Ruecklesen aus dem Tile (Spec 010, US2)")
local strokeTile = nil
local strokeZoom = { setNewTile = function(_, t) strokeTile = t end, updateExistingTile = function(_, t) strokeTile = t end }
PixelRoom:init(noop, strokeZoom)
PixelRoom:setCurrentTile({ sample = function() return "white" end }, 1, T)   -- obere Ebene
PixelRoom:entered()
local sh = PixelRoom:inputHandler()
for b in pairs(heldButtons) do heldButtons[b] = nil end
pixelCursorToOrigin(sh)

-- Erst Tinte ueber 3 Zellen, dann B-Strich radiert sie nach transparent zurueck.
heldButtons[playdate.kButtonA] = true
sh.AButtonDown()
sh.rightButtonDown(); sh.rightButtonUp()
sh.rightButtonDown(); sh.rightButtonUp()
sh.AButtonUp()
heldButtons[playdate.kButtonA] = false
PixelRoom:commitForTerminate()
check(strokeTile:sample(0, 0) == "black" and strokeTile:sample(1, 0) == "black"
    and strokeTile:sample(2, 0) == "black", "A gehalten + Bewegung malt einen Tinten-Strich")

pixelCursorToOrigin(sh)
heldButtons[playdate.kButtonB] = true
sh.BButtonDown()
sh.rightButtonDown(); sh.rightButtonUp()
sh.rightButtonDown(); sh.rightButtonUp()
sh.BButtonUp()
heldButtons[playdate.kButtonB] = false
PixelRoom:commitForTerminate()
check(strokeTile:sample(0, 0) == "clear" and strokeTile:sample(1, 0) == "clear"
    and strokeTile:sample(2, 0) == "clear", "B gehalten + Bewegung radiert den Strich nach transparent")

-- Ruecklesen: ein Tile mit transparentem Pixel laedt als TRANSPARENT-Zelle
local reload = newMockImage(16, 16, "white")
reload.pixels["3,3"] = "clear"
PixelRoom:setCurrentTile(reload, 1, T)
PixelRoom:commitForTerminate()
check(strokeTile:sample(3, 3) == "clear", "setCurrentTile liest kColorClear als transparente Zelle zurueck (Round-Trip)")

-- Dedup: opakes vs. transparentes Tile hashen unterschiedlich (spec.md:104)
local opaqueOnly = newMockImage(16, 16, "white"); opaqueOnly.pixels["0,0"] = true
local transpToo = newMockImage(16, 16, "white"); transpToo.pixels["0,0"] = true; transpToo.pixels["1,1"] = "clear"
check(ImageStoreCodec.hashTile(opaqueOnly) ~= ImageStoreCodec.hashTile(transpToo),
    "Tile mit zusaetzlichem transparentem Pixel dedupliziert getrennt")

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

-- ── Steuerungs-Redesign (Spec 010): Frame-Wechsel via B + Links/Rechts ─────

section("EditorRoom: Frame-Wechsel via B + Links/Rechts, NICHT mehr per Crank (Spec 010)")
loadEditorImageForTest("crankTest", { makeFrame(1), makeFrame(2), makeFrame(3) }, 3, "crank-test")
check(EditorRoom:getImageData() ~= nil, "Vorbedingung: Bild mit 3 Frames geladen")
check(mockLastTilemap.lastFrame[1] == 1, "Vorbedingung: Frame 1 aktiv")

local crankNavH = EditorRoom:inputHandler()

-- Kurbel OHNE B wechselt keinen Frame mehr (jetzt Tile-Picker)
crankChangeValue = 720
EditorRoom:update()
crankChangeValue = 0
check(mockLastTilemap.lastFrame[1] == 1, "zwei Kurbelumdrehungen ohne B -> Frame unveraendert (kein Frame-Cyclen per Crank)")

heldButtons[playdate.kButtonB] = true
crankNavH.rightButtonDown(); crankNavH.rightButtonUp()
check(mockLastTilemap.lastFrame[1] == 2, "B + Rechts -> Frame 2")
crankNavH.rightButtonDown(); crankNavH.rightButtonUp()
check(mockLastTilemap.lastFrame[1] == 3, "B + Rechts nochmal -> Frame 3")
crankNavH.leftButtonDown(); crankNavH.leftButtonUp()
check(mockLastTilemap.lastFrame[1] == 2, "B + Links -> zurueck zu Frame 2")

-- B + Rechts am letzten Frame haengt einen neuen Frame an (einzige Anlage-Geste)
crankNavH.rightButtonDown(); crankNavH.rightButtonUp()   -- -> Frame 3
crankNavH.rightButtonDown(); crankNavH.rightButtonUp()   -- -> neuer Frame 4 (Kopie)
check(#EditorRoom:getImageData().frameLayers == 4, "B + Rechts am Ende legt einen neuen Frame an")
heldButtons[playdate.kButtonB] = false

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
do
    local h = EditorRoom:inputHandler()
    heldButtons[playdate.kButtonB] = true
    h.rightButtonDown(); h.rightButtonUp()   -- Spec 010: B + Rechts statt Crank
    heldButtons[playdate.kButtonB] = false
end
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

-- ── EditorRoom: Ebenen-Verdrahtung (Spec 010, Phase 3) ─────────────────────
--
-- Nachweis, dass ALLE Editier-Pfade des EditorRoom auf die AKTIVE Ebene
-- wirken und der flache imageData.frames-Cache nach jeder Mutation neu
-- kompositiert wird (sonst gingen Mehr-Ebenen-Edits beim Speichern verloren,
-- weil newSaveOperation nur frameLayers liest).

local function pos375(fill, overrides)
    local p = {}
    for i = 1, 375 do p[i] = fill end
    for k, v in pairs(overrides or {}) do p[k] = v end
    return p
end

local function loadEditorV11(id, framesJson, tileCount)
    datastoreFiles["saves/" .. id .. "/frames"] =
        { version = "1.1", name = id, tileCount = tileCount, frames = framesJson }
    datastoreImages["saves/" .. id .. "/sheet"] = newMockImage(400, 240, "white")
    crankChangeValue = 0
    crankTicksValue = 0
    for b in pairs(heldButtons) do heldButtons[b] = nil end
    EditorRoom:setImage(id)
    EditorRoom:entered()
    for _ = 1, 5 do EditorRoom:update() end
end

section("EditorRoom: Malen wirkt auf die aktive Ebene, Composite-Cache folgt (Spec 010, US3)")
loadEditorV11("edit2layer", {
    { frameIndex = 0, duration = 100, layers = {
        { layerIndex = 0, name = "Background", positions = pos375(1), visible = true },
        { layerIndex = 1, name = "Character", positions = pos375(0), visible = true },
    } },
}, 3)
local data = EditorRoom:getImageData()
check(data ~= nil and #data.frameLayers[1].layers == 3, "Frame hat immer 3 Ebenen (geladen, obere leer ergaenzt)")
check(data.activeLayer == 1, "aktive Ebene startet bei 1")

data.activeLayer = 2
local eh = EditorRoom:inputHandler()
eh.AButtonDown(); eh.AButtonUp()                       -- malt Zelle 1 (Cursor 1,1)
check(data.frameLayers[1].layers[2].positions[1] == 2, "A-Strich landet auf Ebene 2 (Tile 2 / schwarz)")
check(data.frameLayers[1].layers[1].positions[1] == 1, "Ebene 1 (Basis) an Zelle 1 unveraendert")
check(data.frames[1][1] == 2, "Composite-Cache an Zelle 1 zeigt die oberste beitragende Ebene (2)")
check(mockLastTilemap.lastFrame[1] == 2, "Tilemap zeigt den kompositierten Wert")

eh.rightButtonDown()                                    -- Cursor -> Zelle 2
eh.AButtonDown(); eh.AButtonUp()
check(data.frameLayers[1].layers[2].positions[2] == 2, "zweite Zelle ebenfalls auf Ebene 2")
check(data.frameLayers[1].layers[1].positions[2] == 1, "Ebene 1 an Zelle 2 unveraendert")

-- Radierer auf oberer Ebene: A erneut auf der jetzt opaken Zelle 2 -> die
-- Ebene wird dort wieder "absent" (0), NICHT opak-weiss (Tile 1) — sonst
-- gaebe es keinen Rueckweg zu "durchsichtig" (Advisor-Fund).
eh.AButtonDown(); eh.AButtonUp()
check(data.frameLayers[1].layers[2].positions[2] == 0,
    "A erneut (Radierer) auf oberer Ebene -> Zelle wieder 'absent' (0), nicht opak-weiss")
check(data.frames[1][2] == 1, "Composite faellt an Zelle 2 auf die Basisebene (Tile 1) zurueck")
check(data.frameLayers[1].layers[1].positions[2] == 1, "Basisebene an Zelle 2 weiterhin unveraendert")

section("EditorRoom: Mehr-Ebenen-Edit ueberlebt Speichern + Laden (Spec 010, T031)")
data.id = "edit2layer-rt"
local rtco = ImageStoreCodec.newSaveOperation(data)
while coroutine.status(rtco) ~= "dead" do
    local okrt = coroutine.resume(rtco)
    check(okrt, "newSaveOperation(EditorRoom-imageData) laeuft durch")
end
local rtSaved = datastoreFiles["saves/edit2layer-rt/frames"]
check(rtSaved and #rtSaved.frames[1].layers == 2, "gespeichert: 2 Ebenen")
check(rtSaved and rtSaved.frames[1].layers[2].positions[1] == 2, "gespeichert: Ebene-2-Edit an Zelle 1")
check(rtSaved and rtSaved.frames[1].layers[1].positions[1] == 1, "gespeichert: Ebene 1 unveraendert")
local rtlco = ImageStoreCodec.newLoadOperation("edit2layer-rt")
local reloaded
while coroutine.status(rtlco) ~= "dead" do
    local okl, res = coroutine.resume(rtlco)
    if okl and res then reloaded = res end
end
check(reloaded and reloaded.frameLayers[1].layers[2].positions[1] == 2,
    "neu geladen: Ebene-2-Edit an Zelle 1 erhalten")
check(reloaded and reloaded.frameLayers[1].layers[2].positions[2] == 0,
    "neu geladen: radierte obere Zelle 2 bleibt 'absent' (0)")
check(reloaded and reloaded.frameLayers[1].layers[1].positions[1] == 1,
    "neu geladen: Ebene 1 unveraendert")

section("EditorRoom: Frame-Duplizierung kopiert alle Ebenen tief (Spec 010, tickForward)")
loadEditorV11("dup2layer", {
    { frameIndex = 0, duration = 100, layers = {
        { layerIndex = 0, name = "Background", positions = pos375(1), visible = true },
        { layerIndex = 1, name = "Character", positions = pos375(0, { [10] = 2 }), visible = true },
    } },
}, 3)
local dup = EditorRoom:getImageData()
check(#dup.frameLayers == 1, "Vorbedingung: 1 Frame")
do
    local h = EditorRoom:inputHandler()
    heldButtons[playdate.kButtonB] = true
    h.rightButtonDown(); h.rightButtonUp()              -- Spec 010: B + Rechts am Ende -> neuer Frame 2 (Kopie)
    heldButtons[playdate.kButtonB] = false
end
check(#dup.frameLayers == 2, "B + Rechts am Ende -> Frame 2 angelegt")
check(#dup.frameLayers[2].layers == 3, "Frame 2 hat alle 3 Ebenen der tiefen Kopie")
check(dup.frameLayers[2].layers[2].positions[10] == 2, "Ebene-2-Inhalt in die Kopie uebernommen")
check(dup.frameLayers[2].layers[2].positions ~= dup.frameLayers[1].layers[2].positions,
    "tiefe Kopie: eigene positions-Tabelle je Frame")
dup.frameLayers[2].layers[2].positions[10] = 3
check(dup.frameLayers[1].layers[2].positions[10] == 2, "Aenderung an Frame 2 laesst Frame 1 unberuehrt")
check(#dup.frames == 2 and #dup.frames[2] == 375, "flacher Composite-Cache fuer Frame 2 ebenfalls angelegt")

section("EditorRoom: 'clear screen' leert nur die aktive Ebene (Spec 010)")
loadEditorV11("clear2layer", {
    { frameIndex = 0, duration = 100, layers = {
        { layerIndex = 0, name = "Background", positions = pos375(1), visible = true },
        { layerIndex = 1, name = "Character", positions = pos375(0, { [5] = 2, [6] = 2 }), visible = true },
    } },
}, 3)
local clr = EditorRoom:getImageData()
clr.activeLayer = 2
check(mockMenuItemCallbacks["clear screen"] ~= nil, "'clear screen'-Menuepunkt vorhanden")
mockMenuItemCallbacks["clear screen"]()
check(clr.frameLayers[1].layers[2].positions[5] == 0 and clr.frameLayers[1].layers[2].positions[6] == 0,
    "aktive obere Ebene komplett auf 'absent' (0) geleert")
check(clr.frameLayers[1].layers[1].positions[1] == 1, "Basisebene (nicht aktiv) unveraendert")
clr.activeLayer = 1
mockMenuItemCallbacks["clear screen"]()
check(clr.frameLayers[1].layers[1].positions[1] == 1 and clr.frameLayers[1].layers[1].positions[375] == 1,
    "aktive Basisebene auf Voll-Weiss (1) geleert (Ein-Ebenen-Verhalten wie Spec 008)")

-- ── EditorRoom: Ebenen-/Frame-Wechsel per B + D-Pad (Spec 010, Steuerungs-Redesign) ──

local function threeLayerFrame(baseTile)
    return { frameIndex = 0, duration = 100, layers = {
        { layerIndex = 0, name = "Background", positions = pos375(baseTile or 1), visible = true },
        { layerIndex = 1, name = "Character",  positions = pos375(0), visible = true },
        { layerIndex = 2, name = "Effects",    positions = pos375(0), visible = true },
    } }
end

-- B halten + eine D-Pad-Taste (Down+Up). Hoch/Runter = aktive Ebene +1 / -1,
-- Links/Rechts = Frame vor / zurueck (Spec 010 Steuerungs-Redesign).
local function bDpad(btnDown, btnUp)
    local h = EditorRoom:inputHandler()
    heldButtons[playdate.kButtonB] = true
    h[btnDown](); h[btnUp]()
    heldButtons[playdate.kButtonB] = false
end

section("EditorRoom: B + Hoch/Runter zyklt die aktive Ebene mit Wrap (Spec 010, FR-013/014/017)")
loadEditorV11("cyc3", { threeLayerFrame(1) }, 3)
local cyc = EditorRoom:getImageData()
check(cyc.activeLayer == 1 and EditorRoom:getActiveLayerInfo().count == 3, "Start: Ebene 1 von 3")
check(EditorRoom:getActiveLayerInfo().name == "Background", "Indikator nennt den Ebenennamen (FR-015)")

bDpad("upButtonDown", "upButtonUp")
check(cyc.activeLayer == 2, "B + Hoch -> Ebene 2 (vorwaerts)")
bDpad("upButtonDown", "upButtonUp")
check(cyc.activeLayer == 3, "B + Hoch nochmal -> Ebene 3")
bDpad("upButtonDown", "upButtonUp")
check(cyc.activeLayer == 1, "B + Hoch nochmal -> Wrap zurueck auf Ebene 1 (FR-017)")

bDpad("downButtonDown", "downButtonUp")
check(cyc.activeLayer == 3, "B + Runter -> rueckwaerts auf Ebene 3 (Wrap)")
bDpad("downButtonDown", "downButtonUp")
check(cyc.activeLayer == 2, "B + Runter nochmal -> Ebene 2 rueckwaerts")

section("EditorRoom: Kurbel OHNE B wechselt keinen Frame mehr (Spec 010, Steuerungs-Redesign)")
check(mockLastTilemap.lastFrame ~= nil, "Vorbedingung: Tilemap gesetzt")
local framesBefore = #cyc.frameLayers
crankChangeValue = 720; EditorRoom:update(); crankChangeValue = 0
check(#cyc.frameLayers == framesBefore, "zwei volle Kurbelumdrehungen ohne B -> kein neuer Frame")

section("EditorRoom: B + Links/Rechts wechselt Frames; aktiver Ebenenindex bleibt erhalten (Spec 010)")
bDpad("upButtonDown", "upButtonUp")            -- Ebene 2 -> 3
check(cyc.activeLayer == 3, "Vorbedingung: aktive Ebene 3")
bDpad("rightButtonDown", "rightButtonUp")      -- am letzten Frame -> neuer Frame 2 (tiefe Kopie)
check(#cyc.frameLayers == 2, "B + Rechts am Ende -> neuer Frame")
check(cyc.activeLayer == 3, "Frame-Wechsel laesst den aktiven Ebenenindex unveraendert (jeder Frame hat 3 Ebenen)")
check(EditorRoom:getActiveLayerInfo().count == 3, "Indikator zeigt weiterhin 3 Ebenen")
bDpad("leftButtonDown", "leftButtonUp")        -- zurueck zu Frame 1
check(#cyc.frameLayers == 2 and cyc.activeLayer == 3,
    "B + Links: zurueck zu Frame 1, kein neuer Frame, Ebenenindex 3 bleibt")

section("EditorRoom: jeder Frame wird beim Laden auf 3 Ebenen aufgefuellt (Spec 010, Third Round)")
loadEditorV11("wrap2", {
    threeLayerFrame(1),
    { frameIndex = 1, duration = 100, layers = {
        { layerIndex = 0, name = "Only", positions = pos375(1), visible = true },
    } },
}, 3)
local wr = EditorRoom:getImageData()
check(#wr.frameLayers[2].layers == 3, "Frame 2 wurde beim Laden auf 3 Ebenen aufgefuellt")
wr.activeLayer = 3                                       -- auf Frame 1 Ebene 3
bDpad("rightButtonDown", "rightButtonUp")                -- -> Frame 2
check(wr.activeLayer == 3, "aktiver Index 3 bleibt beim Frame-Wechsel erhalten (Frame 2 hat auch 3 Ebenen)")
check(EditorRoom:getActiveLayerInfo().count == 3, "Indikator zeigt weiterhin 3 Ebenen")
bDpad("leftButtonDown", "leftButtonUp")                  -- zurueck zu Frame 1
check(#wr.frameLayers == 2, "wieder bei Frame 1 (kein neuer Frame angelegt)")

-- ── EditorRoom: Tile-Picker (Crank ohne B) + Pipetten-Meldung (Spec 010) ───

section("EditorRoom: Crank ohne B waehlt reihum eine Kachel; Overlay zeigt 'Tile N' (Spec 010)")
loadEditorV11("picker", {
    { frameIndex = 0, duration = 100, layers = {
        { layerIndex = 0, name = "Background", positions = pos375(1, { [1] = 2, [2] = 3, [3] = 4 }), visible = true },
        { layerIndex = 1, name = "Character",  positions = pos375(0), visible = true },
        { layerIndex = 2, name = "Effects",    positions = pos375(0), visible = true },
    } },
}, 4)

local function lastPickerLabel()
    local found = nil
    for _, c in ipairs(mockDrawTextCalls) do
        if type(c.text) == "string" and c.text:match("^Tile %d") then found = c.text end
    end
    return found
end

-- referenzierte Tiles = {1,2,3,4}; ohne Auswahl entspricht das Slot 1
mockDrawTextCalls = {}
crankChangeValue = 30; EditorRoom:update(); crankChangeValue = 0   -- ein Kachelschritt vorwaerts
check(lastPickerLabel() == "Tile 2", "30 Grad -> Kachel 2 gewaehlt, Overlay zeigt 'Tile 2'")

mockDrawTextCalls = {}
crankChangeValue = 60; EditorRoom:update(); crankChangeValue = 0   -- zwei weitere Schritte -> Kachel 4
check(lastPickerLabel() == "Tile 4", "weitere 60 Grad -> Kachel 4")

mockDrawTextCalls = {}
crankChangeValue = 30; EditorRoom:update(); crankChangeValue = 0   -- Wrap 4 -> 1
check(lastPickerLabel() == "Tile 1", "Wrap am Listenende: Kachel 4 -> Kachel 1 (= Abwahl)")

mockDrawTextCalls = {}
crankChangeValue = -30; EditorRoom:update(); crankChangeValue = 0  -- rueckwaerts 1 -> 4
check(lastPickerLabel() == "Tile 4", "rueckwaerts vom Anfang -> Kachel 4 (Wrap)")

mockDrawTextCalls = {}
mockTimeMs = mockTimeMs + 2000
EditorRoom:update()
check(lastPickerLabel() == nil, "nach 2s ohne Kurbel: Picker-Overlay ausgeblendet")

local pk = EditorRoom:getImageData()
check(#pk.frameLayers == 1 and pk.activeLayer == 1,
    "Kurbeln am Picker liess Frame-Anzahl und aktive Ebene unveraendert (weder Frame- noch Ebenen-Wechsel per Crank)")

section("EditorRoom: Pipette meldet kurz 'Tile N picked' in der Bauchbinde (Spec 010)")
local function lastBandLabel()
    local found = nil
    for _, c in ipairs(mockDrawTextCalls) do
        if type(c.text) == "string" then found = c.text end
    end
    return found
end
-- Cursor steht nach dem Laden auf Zelle 1 (1,1); Composite dort = Tile 2
mockDrawTextCalls = {}
local ph = EditorRoom:inputHandler()
ph.BButtonDown(); ph.BButtonUp()          -- kurzer B-Tipp = Pipette
EditorRoom:update()
check(lastBandLabel() == "Tile 2 picked",
    "B-Tipp auf Zelle 1 (Composite Tile 2) -> Bauchbinde zeigt 'Tile 2 picked'")

mockDrawTextCalls = {}
mockTimeMs = mockTimeMs + 2000
EditorRoom:update()
check((lastBandLabel() or ""):match("^Frame 1/1"),
    "nach 1.5s blendet die Meldung aus -> Bauchbinde zeigt wieder 'Frame 1/1 ...'")

section("EditorRoom: B + D-Pad-Navigation unterdrueckt die Pipette beim B-Release (Spec 010)")
loadEditorV11("nav-nopip", {
    { frameIndex = 0, duration = 100, layers = {
        { layerIndex = 0, name = "Background", positions = pos375(1, { [1] = 5 }), visible = true },
        { layerIndex = 1, name = "Character",  positions = pos375(0), visible = true },
        { layerIndex = 2, name = "Effects",    positions = pos375(0), visible = true },
    } },
}, 5)
local np = EditorRoom:getImageData()
local nh = EditorRoom:inputHandler()
heldButtons[playdate.kButtonB] = true
nh.BButtonDown()
nh.upButtonDown(); nh.upButtonUp()        -- B + Hoch -> Ebene 2 (bNavConsumed = true)
check(np.activeLayer == 2, "B + Hoch hat die Ebene gewechselt")
heldButtons[playdate.kButtonB] = false
nh.BButtonUp()                            -- KEINE Pipette, weil B fuer Navigation genutzt wurde
mockDrawTextCalls = {}
EditorRoom:update()
check(not (lastBandLabel() or ""):match("picked"),
    "B-Release nach B+D-Pad loest KEINE Pipette aus (bNavConsumed)")

section("EditorRoom: Tile-Picker erreicht auch verdeckte Kacheln (nur auf einer Ebene) (Spec 010)")
-- Der Picker liest die EBENEN-Positionen, nicht den flachen Composite-Cache:
-- eine Kachel, die nur auf einer verdeckten Ebene liegt, bleibt waehlbar und
-- verschwindet nicht mitten in der Sitzung, wenn eine hoehere Ebene die Zelle abdeckt.
loadEditorV11("picker-covered", {
    { frameIndex = 0, duration = 100, layers = {
        { layerIndex = 0, name = "Background", positions = pos375(1), visible = true },
        { layerIndex = 1, name = "Character",  positions = pos375(0, { [1] = 7 }), visible = true },  -- Tile 7 NUR hier
        { layerIndex = 2, name = "Effects",    positions = pos375(0, { [1] = 9 }), visible = true },  -- deckt Zelle 1 im Composite
    } },
}, 9)
check(EditorRoom:getImageData().frames[1][1] == 9,
    "Vorbedingung: Composite-Cache an Zelle 1 zeigt nur die oberste Ebene (Tile 9)")
mockDrawTextCalls = {}
crankChangeValue = 30; EditorRoom:update(); crankChangeValue = 0   -- referenziert = {1,7,9}; 1 -> 7
check(lastPickerLabel() == "Tile 7",
    "Picker erreicht Tile 7 (liegt nur auf der verdeckten Ebene 2, fehlt im Composite-Cache)")
mockDrawTextCalls = {}
crankChangeValue = 30; EditorRoom:update(); crankChangeValue = 0   -- 7 -> 9
check(lastPickerLabel() == "Tile 9", "weiter zu Tile 9")

-- Die Pause-/Kontext-Ansicht nutzt seit Spec 010 denselben Scan
-- (referencedTileIndices) -> die verdeckte Kachel 7 wird jetzt mitgezaehlt
-- (frueherer Composite-Cache-Scan hat sie uebersehen).
mockDrawTextCalls = {}
mockDrawScaledCalls = {}
EditorRoom:buildPauseMenuImage()
check(drawTextContains("Tiles: 3"),
    "Pause-Ansicht zaehlt {1,7,9} = 3 (inkl. der nur auf Ebene 2 liegenden Kachel 7) — gemeinsamer Scan mit dem Picker")
check(#mockDrawScaledCalls == 3, "3 Tile-Vorschauen gezeichnet (1, 7, 9)")

mockDrawTextCalls = {}
crankChangeValue = 30; EditorRoom:update(); crankChangeValue = 0   -- 9 -> Wrap -> 1 (Abwahl)
check(lastPickerLabel() == "Tile 1", "Wrap am Listenende zurueck auf Kachel 1")

-- Kachel 1 = echte Abwahl (activeTile == nil, Toggle-Modus): der A-Toggle auf
-- einer weissen Basis-Zelle malt Schwarz (Tile 2) — NICHT Weiss. Faengt den
-- Lua-Fallstrick `(picked == 1) and nil or picked` ab (der immer 1 ergibt).
local pcov = EditorRoom:inputHandler()
pcov.AButtonDown(); pcov.AButtonUp()          -- Zelle 1 / Ebene 1: Toggle Weiss -> Tile 2
local covId = EditorRoom:getImageData()
check(covId.frameLayers[1].layers[1].positions[1] == 2,
    "nach Kachel-1-Abwahl toggelt A auf Schwarz (Tile 2), nicht auf Weiss -> activeTile war nil")

-- ...und die frisch referenzierte Kachel 2 ist sofort im Picker (Cache
-- invalidiert durch recompositeCell).
mockDrawTextCalls = {}
crankChangeValue = 30; EditorRoom:update(); crankChangeValue = 0   -- referenziert jetzt {1,2,7,9}; 1 -> 2
check(lastPickerLabel() == "Tile 2",
    "frisch gemalte Kachel 2 ist sofort waehlbar (Picker-Cache invalidiert)")

section("EditorRoom: Bild ohne Zelle=1 — Pause-Anzahl faktisch, Picker haelt trotzdem den Abwahl-Slot (Spec 010)")
-- Basisebene komplett mit Tile 5 gefuellt; keine Zelle referenziert Tile 1.
loadEditorV11("nowhite", {
    { frameIndex = 0, duration = 100, layers = {
        { layerIndex = 0, name = "Background", positions = pos375(5), visible = true },
        { layerIndex = 1, name = "Character",  positions = pos375(0), visible = true },
        { layerIndex = 2, name = "Effects",    positions = pos375(0), visible = true },
    } },
}, 5)
mockDrawTextCalls = {}
mockDrawScaledCalls = {}
EditorRoom:buildPauseMenuImage()
check(drawTextContains("Tiles: 1"),
    "Pause-Ansicht zaehlt faktisch: nur Tile 5 referenziert -> 'Tiles: 1' (kein Phantom-Tile 1)")
check(#mockDrawScaledCalls == 1, "genau 1 Tile-Vorschau (Tile 5)")

-- Der Picker haengt den Abwahl-Slot (1) trotzdem an: Liste = {1, 5}.
mockDrawTextCalls = {}
crankChangeValue = 30; EditorRoom:update(); crankChangeValue = 0   -- Abwahl(1) -> 5
check(lastPickerLabel() == "Tile 5", "Picker: von der Abwahl vorwaerts auf Tile 5")
mockDrawTextCalls = {}
crankChangeValue = 30; EditorRoom:update(); crankChangeValue = 0   -- 5 -> Wrap -> Abwahl(1)
check(lastPickerLabel() == "Tile 1", "Picker: Wrap zurueck auf den Abwahl-Slot (nicht haengengeblieben)")

-- ── US1: Pixel-Shift (Spec 010) ───────────────────────────────────────────

section("LayerModel: shiftLayerContent verschiebt den Pixelinhalt um 1 Pixel (Spec 010, US1)")
do
    local it = playdate.graphics.imagetable.new(3)
    it:setImage(1, newMockImage(16, 16, "white"))
    it:setImage(2, newMockImage(16, 16, "black"))
    local corner = newMockImage(16, 16, "white"); corner.pixels["0,0"] = true
    it:setImage(3, corner)
    local reg, nextIdx = {}, 3
    local getT = function(i) return it:getImage(i) end
    local regT = function(img)
        local h = ImageStoreCodec.hashTile(img)
        if reg[h] then return reg[h] end
        nextIdx = nextIdx + 1; it:setImage(nextIdx, img); reg[h] = nextIdx
        return nextIdx
    end

    local e = LayerModel.newFrameLayersFromFlat(pos375(1))
    e.layers[1].positions[1] = 3  -- Zelle 1 (oben links) traegt das Eck-Pixel-Tile
    check(LayerModel.shiftLayerContent(e, 1, "right", getT, regT) == true, "'right' laeuft durch")
    local c1 = it:getImage(e.layers[1].positions[1])
    check(c1:sample(1, 0) == "black" and c1:sample(0, 0) ~= "black",
        "'right': schwarzes Pixel wandert (0,0) -> (1,0), Tiles neu berechnet (FR-002)")
    check(LayerModel.shiftLayerContent(e, 1, "left", getT, regT) == true, "'left' laeuft durch")
    check(it:getImage(e.layers[1].positions[1]):sample(0, 0) == "black", "'left' macht 'right' exakt rueckgaengig")
    check(LayerModel.shiftLayerContent(e, 1, "down", getT, regT) == true, "'down' laeuft durch")
    check(it:getImage(e.layers[1].positions[1]):sample(0, 1) == "black", "'down': Pixel wandert (0,0) -> (0,1)")

    -- Wrap-Around: Pixel am rechten Bildrand (Zelle 25) erscheint nach 'right'
    -- links in Zelle 1 wieder (kein Datenverlust, spec.md Edge Case / FR-005)
    local e2 = LayerModel.newFrameLayersFromFlat(pos375(1))
    local edge = newMockImage(16, 16, "white"); edge.pixels["15,0"] = true
    it:setImage(60, edge)
    e2.layers[1].positions[25] = 60
    LayerModel.shiftLayerContent(e2, 1, "right", getT, regT)
    check(it:getImage(e2.layers[1].positions[1]):sample(0, 0) == "black",
        "'right' Wrap: Randpixel aus Zelle 25 erscheint links in Zelle 1 (FR-005, kein Datenverlust)")
end

section("EditorRoom: shiftActiveLayer wirkt nur auf die aktive Ebene + aktuellen Frame (Spec 010, US1, FR-004)")
loadEditorV11("shift2l", {
    { frameIndex = 0, duration = 100, layers = {
        { layerIndex = 0, name = "Base", positions = pos375(1), visible = true },
        { layerIndex = 1, name = "Ink",  positions = pos375(0), visible = true },
    } },
    { frameIndex = 1, duration = 100, layers = {
        { layerIndex = 0, name = "Base", positions = pos375(1), visible = true },
    } },
}, 4)
local sd = EditorRoom:getImageData()
local corner = newMockImage(16, 16, "white"); corner.pixels["0,0"] = true
sd.imagetable:setImage(4, corner)
sd.frameLayers[1].layers[2].positions[1] = 4
sd.activeLayer = 2
local f2before = {}
for i = 1, 375 do f2before[i] = sd.frameLayers[2].layers[1].positions[i] end
check(EditorRoom:shiftActiveLayer("right") == true, "shiftActiveLayer('right') laeuft durch")
local shiftedTile = sd.imagetable:getImage(sd.frameLayers[1].layers[2].positions[1])
check(shiftedTile:sample(1, 0) == "black" and shiftedTile:sample(0, 0) ~= "black",
    "aktive Ebene 2: Inhalt um 1 nach rechts verschoben")
check(sd.frameLayers[1].layers[1].positions[1] == 1, "Basisebene (nicht aktiv) unveraendert")
local f2same = true
for i = 1, 375 do if sd.frameLayers[2].layers[1].positions[i] ~= f2before[i] then f2same = false end end
check(f2same, "Frame 2 vollstaendig unveraendert (FR-004)")
check(#sd.frames[1] == 375, "flacher Composite-Cache nach dem Shift neu aufgebaut")

-- Struktur ueberlebt Speichern + Laden (Pixel-Ebene: Simulator T058)
sd.id = "shift2l-rt"
local shco = ImageStoreCodec.newSaveOperation(sd)
while coroutine.status(shco) ~= "dead" do coroutine.resume(shco) end
local shrl
local shlco = ImageStoreCodec.newLoadOperation("shift2l-rt")
while coroutine.status(shlco) ~= "dead" do local ok, r = coroutine.resume(shlco); if ok and r then shrl = r end end
check(shrl and #shrl.frameLayers[1].layers == 3 and #shrl.frameLayers[1].layers[2].positions == 375,
    "nach Save+Reload: 3 Ebenen, 375 Positionen erhalten")
check(shrl and shrl.frameLayers[1].layers[1].positions[1] == 1, "nach Save+Reload: Basisebene unveraendert")

section("ZoomRoom: B + Pfeiltaste loest den Ebenen-Shift aus (Spec 010, US1, FR-001)")
local shiftCalls = {}
local edMock = {
    applyTileEdits = noop,
    shiftActiveLayer = function(_, dir) table.insert(shiftCalls, dir); return true end,
    currentZoomContext = function()
        return { slots = ctxSlots, gridState = ctxGridState, showGrid = true, imageData = {} }
    end,
}
ZoomRoom:init(noop, {}, edMock)
ZoomRoom:setFromEditorContext({ slots = ctxSlots, gridState = ctxGridState, showGrid = true, imageData = {} })
local zh = ZoomRoom:inputHandler()
for b in pairs(heldButtons) do heldButtons[b] = nil end
zh.upButtonDown()  -- ohne B -> nur Cursorbewegung
check(#shiftCalls == 0, "Pfeil ohne B verschiebt nichts (nur Cursor, Regressionsschutz)")
heldButtons[playdate.kButtonB] = true
zh.rightButtonDown()
zh.upButtonDown()
heldButtons[playdate.kButtonB] = false
check(shiftCalls[1] == "right" and shiftCalls[2] == "up",
    "B + Pfeil ruft editorRoom:shiftActiveLayer mit der Richtung auf (FR-001)")

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

-- ══════════════════════════════════════════════════════════════════════════════
--  Spec 010: Layer-Datenmodell, Transparenz & Speicherformat v1.1
-- ══════════════════════════════════════════════════════════════════════════════

-- ── PixelTransparency: 3-Zustands-Codec ─────────────────────────────────────

section("PixelTransparency: encode/decode + Praedikate (Spec 010, US2)")
check(PixelTransparency.encode("opaque") == 0 and PixelTransparency.encode("transparent") == 1
    and PixelTransparency.encode("empty") == 2, "encode bildet die drei Zustandsnamen auf 0/1/2 ab")
check(PixelTransparency.decode(0) == "opaque" and PixelTransparency.decode(1) == "transparent"
    and PixelTransparency.decode(2) == "empty", "decode ist die Umkehrung von encode")
check(PixelTransparency.encode("bloedsinn") == 0, "unbekannter Zustandsname faellt auf opaque zurueck")
check(PixelTransparency.isTransparent(1) and not PixelTransparency.isTransparent(0),
    "isTransparent nur fuer Code 1")
check(PixelTransparency.isOpaque(0) and PixelTransparency.isOpaque(nil) and not PixelTransparency.isOpaque(1),
    "isOpaque fuer 0 und nil (Alt-Tiles ohne Transparenzinfo)")
check(PixelTransparency.isEmpty(2) and not PixelTransparency.isEmpty(0), "isEmpty nur fuer Code 2")
check(PixelTransparency.sanitize(7) == 0 and PixelTransparency.sanitize(nil) == 0
    and PixelTransparency.sanitize(1) == 1, "sanitize klemmt Fremdwerte auf opaque, gueltige bleiben")
check(PixelTransparency.fromColor("black") == 0 and PixelTransparency.fromColor("clear") == 1
    and PixelTransparency.fromColor("white") == 2, "fromColor: schwarz->opaque, clear->transparent, weiss->empty")
check(PixelTransparency.toColor(0) == "black" and PixelTransparency.toColor(1) == "clear"
    and PixelTransparency.toColor(2) == "white", "toColor ist die Umkehrung von fromColor")

-- ── LayerModel: Konstruktion & Validierung ─────────────────────────────────

section("LayerModel: Konstruktion neuer Ebenen (Spec 010, Foundational)")
local baseLayer = LayerModel.newLayer(0, nil)
check(baseLayer.layerIndex == 0 and baseLayer.name == "Layer 1", "Basisebene: layerIndex 0, Default-Name 'Layer 1'")
check(#baseLayer.positions == 375, "Basisebene hat genau 375 Positionen")
check(baseLayer.positions[1] == 1 and baseLayer.positions[375] == 1,
    "Basisebene fuellt jede Zelle mit dem Weiss-Tile (Index 1)")
local upperLayer = LayerModel.newLayer(1, "Character")
check(upperLayer.layerIndex == 1 and upperLayer.name == "Character", "Obere Ebene uebernimmt Name")
check(upperLayer.positions[1] == 0 and upperLayer.positions[200] == 0,
    "Obere Ebene startet komplett 'absent' (0) -> Basisebene scheint durch")

local flat = {}
for i = 1, 375 do flat[i] = (i % 2 == 0) and 2 or 1 end
local entry = LayerModel.newFrameLayersFromFlat(flat, 150)
check(entry.duration == 150 and #entry.layers == 3,
    "newFrameLayersFromFlat: IMMER 3 Ebenen (Basis + 2 leere), uebernommene duration")
check(entry.layers[1].layerIndex == 0 and entry.layers[1].name == "Layer 1", "Ebene 1 ist die Basisebene")
check(entry.layers[1].positions[2] == 2 and entry.layers[1].positions[3] == 1,
    "flache Positionen werden 1:1 in die Basisebene uebernommen")
check(entry.layers[1].positions ~= flat, "Positionen werden kopiert, nicht referenziert")
check(entry.layers[2].positions[1] == 0 and entry.layers[3].positions[1] == 0,
    "Ebenen 2 + 3 starten komplett 'absent' (0)")
check(entry.layers[2].layerIndex == 1 and entry.layers[3].layerIndex == 2, "layerIndex fortlaufend 0..2")

section("LayerModel: validate() erzwingt genau 3 Ebenen (Spec 010, Third Round)")
check(LayerModel.validate(entry) == true, "3-Ebenen-Entry ist gueltig")
local badCount = LayerModel.cloneFrameLayers(entry)
badCount.layers[4] = LayerModel.newLayer(3, "L4")
check(LayerModel.validate(badCount) == false, "4 Ebenen -> ungueltig (feste Struktur = 3)")
local badCount2 = LayerModel.cloneFrameLayers(entry)
badCount2.layers[3] = nil
check(LayerModel.validate(badCount2) == false, "2 Ebenen -> ungueltig (feste Struktur = 3)")
local badIndex = LayerModel.cloneFrameLayers(entry)
badIndex.layers[2].layerIndex = 5
check(LayerModel.validate(badIndex) == false, "nicht fortlaufende layerIndex -> ungueltig")
local badLen = LayerModel.cloneFrameLayers(entry)
badLen.layers[1].positions = { 1, 2, 3 }
check(LayerModel.validate(badLen) == false, "positions != 375 -> ungueltig")
local badBase = LayerModel.cloneFrameLayers(entry)
badBase.layers[1].positions[1] = 0
check(LayerModel.validate(badBase) == false, "Basisebene mit 'absent' (0) -> ungueltig (Ebene 1 hat keine Transparenz)")

section("LayerModel: padTo3 fuellt fehlende obere Ebenen leer auf")
local one = { duration = 100, layers = { LayerModel.newLayer(0, "Layer 1") } }
LayerModel.padTo3(one)
check(#one.layers == 3, "1 Ebene -> auf 3 aufgefuellt")
check(one.layers[2].positions[1] == 0 and one.layers[3].positions[7] == 0, "ergaenzte Ebenen sind leer")
local four = LayerModel.cloneFrameLayers(entry)
four.layers[4] = LayerModel.newLayer(3, "L4")
LayerModel.padTo3(four)
check(#four.layers == 3, "4 Ebenen -> auf 3 gestutzt")

-- ── LayerModel: aktive Ebene / Wrap-Around (US3) ───────────────────────────

section("LayerModel: cycleActive/clampActive Wrap-Around (Spec 010, US3, FR-017)")
local cyc = LayerModel.newFrameLayersFromFlat(flat)
check(LayerModel.cycleActive(cyc, 1, 1) == 2 and LayerModel.cycleActive(cyc, 2, 1) == 3,
    "vorwaerts: 1 -> 2 -> 3")
check(LayerModel.cycleActive(cyc, 3, 1) == 1, "vorwaerts-Wrap: 3 -> 1")
check(LayerModel.cycleActive(cyc, 1, -1) == 3, "rueckwaerts-Wrap: 1 -> 3")
check(LayerModel.cycleActive(cyc, 2, -1) == 1, "rueckwaerts: 2 -> 1")
check(LayerModel.clampActive(cyc, 4) == 1, "Index ausserhalb 1..3 -> 1 (defensiv)")
check(LayerModel.clampActive(cyc, 2) == 2, "gueltiger Index bleibt erhalten")
check(LayerModel.clampActive(cyc, nil) == 1, "nil -> 1")

-- ── LayerModel: Compositing ────────────────────────────────────────────────

section("LayerModel: compositeToFlat stapelt Ebenen (Spec 010, US3, data-model 'Three-Layer Frame')")
local comp = LayerModel.newFrameLayersFromFlat(flat)          -- Basis: gerade Zellen = 2, Ebenen 2+3 leer
comp.layers[2].positions[1] = 9                               -- Character deckt Zelle 1
comp.layers[3].positions[1] = 15                              -- Effects deckt Zelle 1 (oberste gewinnt)
comp.layers[2].positions[4] = 7                               -- nur Character deckt Zelle 4
local flatComposite = LayerModel.compositeToFlat(comp)
check(flatComposite[1] == 15, "Zelle 1: oberste beitragende Ebene (Effects, Tile 15) gewinnt")
check(flatComposite[4] == 7, "Zelle 4: nur Character traegt bei -> Tile 7")
check(flatComposite[2] == 2, "Zelle 2: keine obere Ebene -> Basisebene (Tile 2)")
check(#flatComposite == 375, "Compositing liefert exakt 375 Positionen")
comp.layers[3].visible = false
check(LayerModel.compositeToFlat(comp)[1] == 9,
    "unsichtbare Ebene wird uebersprungen -> Character (Tile 9) gewinnt Zelle 1")

-- compositeToTiles: pixel-genaue Ueberblendung. Die Basisebene traegt IMMER
-- bei (nie "absent"), daher merged die Funktion jede Zelle, an der eine obere
-- Ebene Inhalt hat. Zellen mit nur der Basisebene bleiben unveraendert.
-- (Noch NICHT im Renderpfad verdrahtet, T053 — die Merge-Rate ist dort vor
-- dem Verdrahten zu druecken, z.B. nur bei tatsaechlich transparenten Pixeln
-- der oberen Ebene.)
do
    local c2 = LayerModel.newFrameLayersFromFlat(flat)  -- flat: gerade Zellen = Tile 2, ungerade = Tile 1
    c2.layers[2].positions[4] = 7     -- Zelle 4: Basis (2) + Character (7)
    c2.layers[2].positions[1] = 8     -- Zelle 1: Basis (1) + Character (8) +
    c2.layers[3].positions[1] = 9     -- Effects (9)
    local registered = 0
    local getT = function(i) return newMockImage(16, 16, "white") end
    local regT = function(img) registered = registered + 1; return 100 + registered end
    local out = LayerModel.compositeToTiles(c2, getT, regT)
    check(out[2] == 2, "Zelle 2 (nur Basisebene) -> Basistile-Index unveraendert, kein neues Tile")
    check(out[4] >= 101 and out[1] >= 101, "Zellen mit oberer Ebene -> zusammengefuehrtes Tile")
    check(registered == 2, "genau 2 Merges (Zelle 1 + Zelle 4), nicht pro leerer Zelle")
    check(#out == 375, "375 Positionen")
end

-- ── ImageStoreCodec: 3-Zustands-Hash & Vergleich (spec.md Edge Case Z.104) ──

section("ImageStoreCodec: hashTile/imagesVisiblyEqual unterscheiden 3 Zustaende (Spec 010)")
local whiteTile = newMockImage(16, 16, "white")
local clearTile = newMockImage(16, 16, "clear")
local whiteTile2 = newMockImage(16, 16, "white")
check(ImageStoreCodec.hashTile(whiteTile) ~= ImageStoreCodec.hashTile(clearTile),
    "voll-weisses und voll-transparentes Tile hashen unterschiedlich (Dedup trennt sie, spec.md:104)")
check(ImageStoreCodec.hashTile(whiteTile) == ImageStoreCodec.hashTile(whiteTile2),
    "zwei gleich aussehende Tiles hashen identisch")
check(ImageStoreCodec.imagesVisiblyEqual(whiteTile, whiteTile2) == true,
    "identische Tiles sind visuell gleich")
check(ImageStoreCodec.imagesVisiblyEqual(whiteTile, clearTile) == false,
    "weiss vs. transparent sind NICHT visuell gleich (3-Zustands-Vergleich)")
local blackOnWhite = newMockImage(16, 16, "white")
blackOnWhite.pixels["0,0"] = true
local blackOnClear = newMockImage(16, 16, "clear")
blackOnClear.pixels["0,0"] = true
check(ImageStoreCodec.hashTile(blackOnWhite) ~= ImageStoreCodec.hashTile(blackOnClear),
    "gleiches Schwarz-Muster, unterschiedlicher Hintergrund -> unterschiedlicher Hash")

-- ── ImageStoreCodec: createFramesTableV11 ──────────────────────────────────

section("ImageStoreCodec: createFramesTableV11 schreibt v1.1, laesst leere obere Ebenen weg (Spec 010, T005)")
-- 3-Ebenen-Entry, Ebene 2 hat Inhalt, Ebene 3 leer -> es werden 2 Eintraege geschrieben.
local twoLayerEntry = LayerModel.newFrameLayersFromFlat(flat)
twoLayerEntry.layers[2].name = "Character"
twoLayerEntry.layers[2].positions[1] = 3
local v11 = ImageStoreCodec.createFramesTableV11("demo", { twoLayerEntry }, 4)
check(v11.version == "1.1", "version-Feld ist der String '1.1'")
check(v11.tileCount == 4 and v11.gridWidth == 25 and v11.gridHeight == 15, "Metafelder wie gehabt")
check(#v11.frames == 1 and v11.frames[1].frameIndex == 0 and v11.frames[1].duration == 100,
    "Frame 0 mit Default-Dauer 100")
check(#v11.frames[1].layers == 2,
    "Ebene 3 ist leer -> nur 2 Ebeneneintraege geschrieben (leere obere Ebenen weggelassen)")
check(v11.frames[1].layers[1].layerIndex == 0 and v11.frames[1].layers[2].layerIndex == 1,
    "fortlaufender layerIndex")
check(v11.frames[1].layers[2].name == "Character" and v11.frames[1].layers[2].positions[1] == 3,
    "Ebenenname und -positionen werden uebernommen")
-- Alle oberen Ebenen leer -> nur Ebene 1 geschrieben.
local baseOnly = LayerModel.newFrameLayersFromFlat(flat)
local v11base = ImageStoreCodec.createFramesTableV11("demo", { baseOnly }, 4)
check(#v11base.frames[1].layers == 1, "nur Basisebene mit Inhalt -> 1 Ebeneneintrag auf Platte")
local badEntry = { duration = 100, layers = { { positions = { 1, 2, 3 } } } }
local v11bad = ImageStoreCodec.createFramesTableV11("demo", { badEntry }, 4)
check(#v11bad.frames == 0, "Frame mit positions-Laenge != 375 wird verworfen")

-- ── ImageStoreCodec: pruneUnusedTilesLayered ───────────────────────────────

section("ImageStoreCodec: pruneUnusedTilesLayered bereinigt ueber alle Ebenen (Spec 010, T009)")
do
    local it = buildTaggedImagetable(6)                       -- 1,2 Basis + 3,4,5,6
    local base = LayerModel.newLayer(0, "Layer 1")
    for i = 1, 375 do base.positions[i] = 1 end
    base.positions[1] = 3
    local upper = LayerModel.newLayer(1, "Character")         -- alles 0
    upper.positions[2] = 6                                    -- referenziert Tile 6
    local pruneEntry = { duration = 100, layers = { base, upper } }
    local newIt, newFL, newCount = ImageStoreCodec.pruneUnusedTilesLayered(it, { pruneEntry }, 6)
    check(newCount == 4, "genutzt: 1,2,3,6 -> 4 Tiles (4 und 5 entfallen)")
    check(newIt:getImage(4).tag == 6, "Tile 6 rueckt auf Index 4")
    check(newFL[1].layers[1].positions[1] == 3, "Basisebene: Tile 3 behaelt Index 3")
    check(newFL[1].layers[2].positions[2] == 4, "obere Ebene: vormals Tile 6 zeigt jetzt auf Index 4")
    check(newFL[1].layers[2].positions[1] == 0, "'absent' (0) bleibt 0 (obere Ebene traegt hier nichts bei)")
    check(#newFL[1].layers == 2, "Ebenenstruktur bleibt erhalten")
end

-- ── ImageStoreCodec: Round-Trip Speichern -> Laden (v1.1) ──────────────────

section("ImageStoreCodec: v1.1 Round-Trip erhaelt Ebenen + Transparenz-Metadaten (Spec 010, T006/T031)")
do
    local it = buildTaggedImagetable(5)
    local base = LayerModel.newLayer(0, "Background")
    for i = 1, 375 do base.positions[i] = 1 end
    base.positions[1] = 3
    local character = LayerModel.newLayer(1, "Character")
    character.positions[5] = 4
    local effects = LayerModel.newLayer(2, "Effects")
    effects.positions[9] = 5
    local imageData = {
        id = "layer-roundtrip",
        name = "layer-roundtrip",
        imagetable = it,
        frameLayers = { { duration = 120, layers = { base, character, effects } } },
        activeLayer = 1,
        hashIndex = {},
    }
    local co = ImageStoreCodec.newSaveOperation(imageData)
    while coroutine.status(co) ~= "dead" do
        local okr, errr = coroutine.resume(co)
        check(okr, "newSaveOperation (3 Ebenen) laeuft ohne Fehler durch: " .. tostring(errr))
    end
    local savedJson = datastoreFiles["saves/layer-roundtrip/frames"]
    check(savedJson and savedJson.version == "1.1", "frames.json v1.1 geschrieben")
    check(savedJson and #savedJson.frames[1].layers == 3, "3 Ebenen persistiert")
    check(savedJson and savedJson.frames[1].layers[2].name == "Character", "Ebenenname 'Character' persistiert")
    check(savedJson and savedJson.frames[1].duration == 120, "Frame-Dauer 120 persistiert")

    local lco = ImageStoreCodec.newLoadOperation("layer-roundtrip")
    local loaded
    while coroutine.status(lco) ~= "dead" do
        local okl, res = coroutine.resume(lco)
        check(okl, "newLoadOperation laeuft ohne Fehler durch: " .. tostring(res))
        if okl and res then loaded = res end
    end
    check(loaded and loaded.frameLayers and #loaded.frameLayers[1].layers == 3,
        "geladen: 3 Ebenen rekonstruiert")
    check(loaded and loaded.frameLayers[1].layers[3].name == "Effects", "Ebenenname 'Effects' rekonstruiert")
    check(loaded and loaded.frameLayers[1].layers[1].layerIndex == 0
        and loaded.frameLayers[1].layers[2].layerIndex == 1
        and loaded.frameLayers[1].layers[3].layerIndex == 2, "layerIndex fortlaufend 0..2")
    check(loaded and loaded.activeLayer == 1, "activeLayer startet bei 1 (Sitzungszustand, nicht persistiert)")
    check(loaded and #loaded.frames == 1 and #loaded.frames[1] == 375,
        "kompositiertes flaches frames-Array fuer Tilemap/Vorschau vorhanden")
end

-- ── ImageStoreCodec: Rueckwaertskompatibilitaet v1.0 -> v1.1 ───────────────

section("ImageStoreCodec: v1.0-Bild laedt als einzelne opake Ebene (Spec 010, US2 FR-010, T021)")
do
    local flatFrame = {}
    for i = 1, 375 do flatFrame[i] = 1 end
    flatFrame[1] = 2
    -- v1.0-Schema: flaches 375er-Array je Frame, KEIN layers-Feld, version = 1
    datastoreFiles["saves/legacy-v10/frames"] =
        { version = 1, name = "legacy", tileCount = 2, frames = { flatFrame } }
    datastoreImages["saves/legacy-v10/sheet"] = newMockImage(32, 16, "white")

    local lco = ImageStoreCodec.newLoadOperation("legacy-v10")
    local loaded
    while coroutine.status(lco) ~= "dead" do
        local okl, res = coroutine.resume(lco)
        if okl and res then loaded = res end
    end
    check(loaded ~= nil, "v1.0-Bild laedt ohne Fehler")
    check(loaded and #loaded.frameLayers[1].layers == 3,
        "Auto-Upgrade: Alt-Inhalt -> Ebene 1, Ebenen 2+3 leer ergaenzt (immer 3)")
    check(loaded and loaded.frameLayers[1].layers[1].name == "Layer 1", "Ebene 1 heisst 'Layer 1'")
    check(loaded and loaded.frameLayers[1].layers[1].positions[1] == 2
        and loaded.frameLayers[1].layers[1].positions[2] == 1, "Alt-Positionen 1:1 in Ebene 1")
    check(loaded and loaded.frameLayers[1].layers[2].positions[1] == 0
        and loaded.frameLayers[1].layers[3].positions[1] == 0, "Ebenen 2+3 komplett leer (0)")
    check(loaded and loaded.frames[1][1] == 2, "kompositiertes frames-Array entspricht der Basisebene")

    -- Re-Save schreibt v1.1, aber nur EINEN Ebeneneintrag (leere obere weggelassen)
    loaded.id = "legacy-v10"
    local sco = ImageStoreCodec.newSaveOperation(loaded)
    while coroutine.status(sco) ~= "dead" do coroutine.resume(sco) end
    local resaved = datastoreFiles["saves/legacy-v10/frames"]
    check(resaved.version == "1.1", "naechstes Speichern hebt die Datei auf v1.1")
    check(#resaved.frames[1].layers == 1,
        "Alt-Bild bleibt auf Platte kompakt: nur 1 Ebeneneintrag (leere Ebenen 2+3 weggelassen)")
end

section("ImageStoreCodec: Laden erzwingt das 3-Layer-Limit (Spec 010, FR-012b, T007)")
do
    local function layerObj(idx0, tile)
        local p = {}
        for i = 1, 375 do p[i] = (idx0 == 0) and 1 or 0 end
        p[1] = tile
        return { layerIndex = idx0, name = "L" .. idx0, positions = p, visible = true }
    end
    datastoreFiles["saves/toomany/frames"] = {
        version = "1.1", name = "toomany", tileCount = 6,
        frames = { { frameIndex = 0, duration = 100,
            layers = { layerObj(0, 3), layerObj(1, 4), layerObj(2, 5), layerObj(3, 6) } } },
    }
    datastoreImages["saves/toomany/sheet"] = newMockImage(112, 16, "white")
    local lco = ImageStoreCodec.newLoadOperation("toomany")
    local loaded
    while coroutine.status(lco) ~= "dead" do
        local okl, res = coroutine.resume(lco)
        if okl and res then loaded = res end
    end
    check(loaded and #loaded.frameLayers[1].layers == 3,
        "vierte Ebene wird beim Laden verworfen -> maximal 3 Ebenen")
end

-- ══════════════════════════════════════════════════════════════════════════════
--  Spec 010 US4: Frame Management View
-- ══════════════════════════════════════════════════════════════════════════════

dofile("Source/FrameManagementView.lua")

-- Baut ein imageData mit n unterscheidbaren Frames (Tile-Index i+10 an Zelle 1
-- der Basisebene UND im flachen Composite-Cache).
local function makeMultiFrameImageData(n)
    local fl, fr = {}, {}
    for i = 1, n do
        local e = LayerModel.newFrameLayersFromFlat(pos375(1))
        e.layers[1].positions[1] = i + 10
        fl[i] = e
        fr[i] = LayerModel.compositeToFlat(e)
    end
    return { id = "fmv", name = "fmv", imagetable = buildTaggedImagetable(2),
             frameLayers = fl, frames = fr, activeLayer = 1, hashIndex = {} }
end

section("FrameManagementView: Navigation, Markieren, Verschieben, Loeschen (Spec 010, US4)")
local fmvSwitchedTo = nil
local edStub = {}
FrameManagementView:init(function(r) fmvSwitchedTo = r end, edStub)

local fdata = makeMultiFrameImageData(4)
FrameManagementView:setImageData(fdata, 3)
local fh = FrameManagementView:inputHandler()
for b in pairs(heldButtons) do heldButtons[b] = nil end

-- Frame 3 markieren, nach links schieben -> Reihenfolge 1,3,2,4
fh.AButtonDown()                                   -- markiert Cursor (Frame 3)
fh.leftButtonDown()
check(fdata.frameLayers[2].layers[1].positions[1] == 13
    and fdata.frames[2][1] == 13, "Links: markierter Frame 3 wandert auf Position 2 (beide Arrays im Gleichschritt)")
check(fdata.frameLayers[3].layers[1].positions[1] == 12, "Frame 2 ist nun an Position 3")
fh.leftButtonDown()
check(fdata.frameLayers[1].layers[1].positions[1] == 13, "Links nochmal: jetzt an Position 1 (Reihenfolge 3,1,2,4)")
fh.leftButtonDown()
check(fdata.frameLayers[1].layers[1].positions[1] == 13, "Links am Anfang: No-op (geklemmt)")

-- Cursor bewegen hebt die Markierung auf
fh.downButtonDown()
fh.AButtonDown()                                   -- markiert erneut (jetzt Position 2)
-- Loeschen per zweitem A auf dem markierten Frame
fh.AButtonDown()
check(#fdata.frameLayers == 3 and #fdata.frames == 3, "zweiter A-Druck loescht den markierten Frame (4 -> 3)")

-- Bis auf 1 Frame loeschen -> letzter Loeschversuch abgelehnt
fh.AButtonDown(); fh.AButtonDown()                 -- markieren + loeschen (3 -> 2)
fh.AButtonDown(); fh.AButtonDown()                 -- markieren + loeschen (2 -> 1)
check(#fdata.frameLayers == 1, "auf 1 Frame heruntergeloescht")
fh.AButtonDown(); fh.AButtonDown()                 -- markieren + Loeschversuch
check(#fdata.frameLayers == 1, "letzter Frame kann NICHT geloescht werden (FR-020)")

-- B loslassen -> zurueck zum EditorRoom, returnFrame gesetzt
FrameManagementView:setImageData(makeMultiFrameImageData(3), 2)
heldButtons[playdate.kButtonB] = true
FrameManagementView:entered()                      -- bWasHeld = true (Eintritts-Geste)
heldButtons[playdate.kButtonB] = false
fmvSwitchedTo = nil
FrameManagementView:update()                       -- erkennt B-Release
check(fmvSwitchedTo == edStub, "B loslassen -> switchRoom(editorRoom)")

-- KEINE Sackgasse: kommt die letzte Kurbel-Tick der Eintrittsgeste erst NACH
-- dem B-Release an, ist bWasHeld beim entered() bereits false. Ein erneuter
-- B-Tipp muss trotzdem sauber herausfuehren.
FrameManagementView:setImageData(makeMultiFrameImageData(3), 2)
heldButtons[playdate.kButtonB] = false
FrameManagementView:entered()                      -- bWasHeld = false (B schon los)
fmvSwitchedTo = nil
FrameManagementView:update()                       -- kein Release-Wechsel -> bleibt
check(fmvSwitchedTo == nil, "B war beim Eintritt schon los -> kein sofortiger Ruecksprung")
heldButtons[playdate.kButtonB] = true
FrameManagementView:update()                       -- B erneut gedrueckt -> Ausgang scharf
heldButtons[playdate.kButtonB] = false
FrameManagementView:update()                       -- jetzt losgelassen -> zurueck
check(fmvSwitchedTo == edStub, "erneuter B-Tipp fuehrt trotzdem heraus (keine Sackgasse)")

section("EditorRoom: B + Kurbel rueckwaerts oeffnet die Frame Management View (Spec 010, US4, FR-018)")
local fmvMock = { _opened = false,
    setImageData = function(self, d, cf) self._opened = true; self._cf = cf end }
EditorRoom:init(function(room) editorSwitchedTo = room end, ZoomRoom, {}, fmvMock)
loadEditorV11("fmvgate", { threeLayerFrame(1), threeLayerFrame(2) }, 3)
editorSwitchedTo = nil
heldButtons[playdate.kButtonB] = true
crankTicksValue = -4                               -- B + Kurbel rueckwaerts (>= ZOOM_TICK_THRESHOLD)
EditorRoom:update()
check(fmvMock._opened == true, "FrameManagementView:setImageData wurde aufgerufen")
check(editorSwitchedTo == fmvMock, "switchRoom(frameManagementView) ausgeloest")
heldButtons[playdate.kButtonB] = false
crankTicksValue = 0

-- Rueckkehr: returnFrame klemmt currentFrame in die (evtl. kuerzere) Sequenz
local fg = EditorRoom:getImageData()
table.remove(fg.frameLayers, 2); table.remove(fg.frames, 2)   -- FMV hat Frame 2 geloescht
fg.returnFrame = 5                                            -- ausserhalb -> wird geklemmt
EditorRoom:entered()
check(fg.returnFrame == nil, "returnFrame wird nach dem Lesen zurueckgesetzt")
check(mockLastTilemap.lastFrame ~= nil, "Tilemap nach Rueckkehr aktualisiert (currentFrame geklemmt)")

-- Zurueck auf den echten Raum-Graphen fuer eventuelle Folgetests
EditorRoom:init(function(room) editorSwitchedTo = room end, ZoomRoom, {}, nil)

-- ── Ergebnis ──────────────────────────────────────────────────────────────────

print("")
if #failures > 0 then
    print(#failures .. " TEST(S) FEHLGESCHLAGEN:")
    for _, msg in ipairs(failures) do print("  - " .. msg) end
    os.exit(1)
else
    print("ALLE TESTS BESTANDEN")
end
