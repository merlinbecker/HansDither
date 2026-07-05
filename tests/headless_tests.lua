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
    }, { __index = function() return noop end }),
    ui = { gridview = { new = newGridview } },
    keyboard = keyboard,
    kButtonA = "A", kButtonB = "B",
    kButtonUp = "up", kButtonDown = "down",
    kButtonLeft = "left", kButtonRight = "right",
    buttonIsPressed = function(b) return heldButtons[b] == true end,
    getCurrentTimeMilliseconds = function() return 0 end,
    timer = { updateTimers = noop },
    getSystemMenu = function()
        return strictTable("systemMenu", {
            removeAllMenuItems = noop,
            addMenuItem = noop,
            addCheckmarkMenuItem = noop,
        })
    end,
}

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
