-- LayerModel.lua
-- Spec 010 (Foundational, data-model.md "Entity: Layer/Frame"): zentrale
-- Hilfsfunktionen fuer das per-Frame-Layer-Datenmodell, geteilt von
-- ImageStoreCodec, EditorRoom, ZoomRoom, LayerView und AnimationLayerView.
--
-- Anpassung an die reale Codebasis (data-model.md/contracts wurden vor
-- Kenntnis der echten Dateien geschrieben und gehen von Klassen unter
-- Source/Models/ aus, die es nicht gibt): statt Klassen mit Gettern/Settern
-- arbeitet dieses Modul mit reinen Lua-Tabellen ("frame layer entry"):
--
--   entry = {
--     duration = 100,                 -- optional, Default 100ms
--     layers = {                       -- 1..3 Eintraege, LAUFZEIT 1-basiert
--       [1] = { layerIndex=0, name="Layer 1", positions={375}, visible=true },
--       [2] = { layerIndex=1, ... },   -- optional
--       [3] = { layerIndex=2, ... },   -- optional
--     }
--   }
--
-- Abweichungen von data-model.md / contracts/save-format.md, bewusst und
-- dokumentiert (siehe auch specs/010.../data-model.md-Update dieser Spec):
--
--  * KEIN 375er "transparency"-Array je Layer. Der Nutzer setzt Transparenz
--    laut Klarstellung ausschliesslich pro Pixel im PixelRoom; sie lebt als
--    kColorClear direkt im 16x16-Tile-Bild und wird ueber den 3-Zustands-
--    Hash (ImageStoreCodec.hashTile) getrennt dedupliziert (spec.md:104).
--  * "positions" nutzt (wie der restliche Code) 1-basierte Tile-Indizes.
--    ZUSAETZLICH bedeutet positions[cell] == 0: "diese Ebene traegt an dieser
--    Zelle nichts bei" (fuer duenn besetzte obere Ebenen). Die verpflichtende
--    Basisebene (layerIndex 0) fuellt jede Zelle (>= 1).
--  * KEIN persistierter "activeLayerIndex". Die aktive Ebene ist reiner
--    Editor-Sitzungszustand (EditorRoom haelt einen 1-basierten Index, der
--    beim Frame-Wechsel gegen die Ebenenanzahl geklemmt wird, data-model.md
--    "State Machine: Active Layer").

import "CoreLibs/graphics"
import "PixelTransparency"

LayerModel = {}

-- Spec 010 (Third Round): jedes Frame hat GENAU 3 Ebenen, immer — eine feste
-- Struktur wie die 12-Frame-Grenze. Kein Hinzufuegen/Loeschen von Ebenen.
LayerModel.LAYER_COUNT = 3
LayerModel.MAX_LAYERS = 3   -- Alias (Rueckwaertskompatibilitaet im Code)
LayerModel.POSITIONS = 375
LayerModel.GRID_COLS = 25
LayerModel.GRID_ROWS = 15
LayerModel.TILE_PX = 16
LayerModel.WHITE_TILE = 1   -- ImageStoreCodec-Invariante: Index 1 = Voll-Weiss
LayerModel.ABSENT = 0       -- positions[cell] == 0 -> Ebene traegt nichts bei

-- ── Basis-Arrays ────────────────────────────────────────────────────────────

function LayerModel.fillArray(n, value)
    local arr = {}
    for i = 1, n do arr[i] = value end
    return arr
end

function LayerModel.copyArray(arr)
    local out = {}
    for i = 1, #arr do out[i] = arr[i] end
    return out
end

-- ── Layer/Frame-Konstruktion ───────────────────────────────────────────────

-- Neue Ebene. Die Basisebene (index0 == 0) fuellt jede Zelle mit dem Weiss-
-- Tile; optionale obere Ebenen starten komplett "absent" (0), damit die
-- Basisebene ueberall durchscheint (data-model.md "Created: Layer initialized
-- with empty positions").
function LayerModel.newLayer(index0, name)
    local fillValue = (index0 == 0) and LayerModel.WHITE_TILE or LayerModel.ABSENT
    return {
        layerIndex = index0,
        name = name or ("Layer " .. tostring(index0 + 1)),
        positions = LayerModel.fillArray(LayerModel.POSITIONS, fillValue),
        visible = true,
    }
end

-- Stellt sicher, dass ein Frame-Layer-Entry GENAU 3 Ebenen hat: fehlende
-- obere Ebenen werden leer ("absent") ergaenzt, ueberzaehlige verworfen,
-- layerIndex/Name normalisiert. Beim Laden nach dem Parsen aufgerufen
-- (data-model.md "pad every frame to 3 layers").
function LayerModel.padTo3(entry)
    entry.layers = entry.layers or {}
    for i = 1, LayerModel.LAYER_COUNT do
        local layer = entry.layers[i]
        if type(layer) ~= "table" or type(layer.positions) ~= "table"
            or #layer.positions ~= LayerModel.POSITIONS then
            entry.layers[i] = LayerModel.newLayer(i - 1)
        else
            layer.layerIndex = i - 1
            layer.name = layer.name or ("Layer " .. i)
            if layer.visible == nil then layer.visible = true end
        end
    end
    for i = LayerModel.LAYER_COUNT + 1, #entry.layers do
        entry.layers[i] = nil
    end
    entry.duration = entry.duration or 100
    return entry
end

-- Wandelt ein flaches Spec-009-Frame (375 Tile-Indizes) in ein Frame-Layer-
-- Entry mit GENAU 3 Ebenen um (Basis aus den flachen Positionen, Ebenen 2-3
-- leer) — Grundlage fuer neue Bilder (ImageStore.createImage) UND fuer das
-- v1.0->v1.1-Upgrade beim Laden (contracts/save-format.md).
function LayerModel.newFrameLayersFromFlat(flatPositions, duration, name)
    local positions = LayerModel.copyArray(flatPositions or {})
    for i = 1, LayerModel.POSITIONS do
        if positions[i] == nil then positions[i] = LayerModel.WHITE_TILE end
    end
    local entry = {
        duration = duration or 100,
        layers = {
            [1] = {
                layerIndex = 0,
                name = name or "Layer 1",
                positions = positions,
                visible = true,
            },
        },
    }
    return LayerModel.padTo3(entry)
end

-- Tiefe Kopie eines Frame-Layer-Entry (Frame-Duplikation bei tickForward()).
function LayerModel.cloneFrameLayers(entry)
    local newLayers = {}
    for i = 1, #entry.layers do
        local layer = entry.layers[i]
        newLayers[i] = {
            layerIndex = layer.layerIndex,
            name = layer.name,
            positions = LayerModel.copyArray(layer.positions),
            visible = layer.visible,
        }
    end
    return { duration = entry.duration or 100, layers = newLayers }
end

-- ── Validierung (contracts/save-format.md "Validation on Load") ─────────────

-- Gueltig ist ein In-Memory-Frame-Layer-Entry mit GENAU 3 Ebenen
-- (layerIndex 0..2), je 375 nicht-negative Ganzzahl-Positionen; die
-- Basisebene (Ebene 1) hat keine "absent" (0) Zellen.
function LayerModel.validate(entry)
    if type(entry) ~= "table" or type(entry.layers) ~= "table" then return false end
    if #entry.layers ~= LayerModel.LAYER_COUNT then return false end
    for i = 1, LayerModel.LAYER_COUNT do
        local layer = entry.layers[i]
        if type(layer) ~= "table" then return false end
        if layer.layerIndex ~= (i - 1) then return false end
        if type(layer.positions) ~= "table" or #layer.positions ~= LayerModel.POSITIONS then return false end
        for _, p in ipairs(layer.positions) do
            if type(p) ~= "number" or p < 0 or p ~= math.floor(p) then return false end
            if i == 1 and p < 1 then return false end  -- Basisebene: kein "absent"
        end
    end
    return true
end

-- ── Aktive Ebene (US3, data-model.md "State Machine") ─────────────────────
--
-- Es gibt kein Hinzufuegen/Loeschen von Ebenen (Spec 010 Third Round). Die
-- aktive Ebene ist ein reiner 1..3-Sitzungscursor.

function LayerModel.layerCount(entry)
    return entry and entry.layers and #entry.layers or LayerModel.LAYER_COUNT
end

-- 1-basierter Zugriff; ausserhalb des Bereichs -> Basisebene.
function LayerModel.getLayer(entry, active1)
    return entry.layers[active1] or entry.layers[1]
end

-- Klemmt einen 1-basierten aktiven Index auf 1..3. Da jedes Frame immer 3
-- Ebenen hat, greift das praktisch nur bei defekten Daten.
function LayerModel.clampActive(entry, active1)
    local count = LayerModel.layerCount(entry)
    if not active1 or active1 < 1 or active1 > count then
        return 1
    end
    return active1
end

-- Zyklus um delta Schritte mit Wrap in beide Richtungen (FR-013/014/017).
function LayerModel.cycleActive(entry, active1, delta)
    local count = LayerModel.layerCount(entry)
    local zero = (active1 - 1 + delta) % count
    if zero < 0 then zero = zero + count end
    return zero + 1
end

-- ── Compositing (US3, data-model.md "Example: Three-Layer Frame") ──────────

-- Sammelt die von unten nach oben sichtbar beitragenden Ebenen-Tile-Indizes
-- an Zelle pos (Basisebene traegt praktisch immer bei, obere Ebenen nur bei
-- Nicht-"absent"). Gemeinsame Grundlage fuer compositeCellTile/compositeBelow.
local function contributingStack(entry, pos, uptoLayer1)
    local stack = {}
    local limit = uptoLayer1 or #entry.layers
    for i = 1, limit do
        local layer = entry.layers[i]
        if layer and layer.visible ~= false and layer.positions[pos] and layer.positions[pos] ~= LayerModel.ABSENT then
            stack[#stack + 1] = layer.positions[pos]
        end
    end
    return stack
end

-- Prueft, ob ein 16x16-Tile-Bild VOLLSTAENDIG opak ist (kein einziges
-- kColorClear-Pixel). Ein vollstaendig opakes oberstes Tile deckt jede
-- tiefere Ebene komplett ab — das Ergebnis ist dann exakt dieses Tile selbst,
-- ein Zusammenfuehren waere unnoetig (und wuerde nur ein ueberfluessiges
-- Duplikat-Tile registrieren).
local function isFullyOpaque(img)
    if not img then return false end
    local gfx = playdate.graphics
    local tilePx = LayerModel.TILE_PX
    for y = 0, tilePx - 1 do
        for x = 0, tilePx - 1 do
            if img:sample(x, y) == gfx.kColorClear then
                return false
            end
        end
    end
    return true
end

-- Kompositiert GENAU EINE Zelle pixelgenau (WYSIWYG, research.md R3): traegt
-- nur eine Ebene bei, bleibt der Tile-Index unveraendert (kein neues Tile);
-- ist das oberste beitragende Tile bereits vollstaendig opak, deckt es alles
-- darunter ohnehin komplett ab -> ebenfalls kein neues Tile noetig, dessen
-- Index bleibt unveraendert. Erst wenn das oberste Tile selbst transparente
-- Pixel enthaelt UND mehrere Ebenen beitragen, wird ein zusammengefuehrtes
-- 16x16-Tile gebaut (untere Ebene zuerst, daraufliegende nicht-transparente
-- Pixel der oberen Ebenen ueberdecken sie — kColorClear-Pixel lassen die
-- untere Ebene durchscheinen, SDK: image:draw() respektiert die Maske).
-- getTile(index)->image, registerTile(image)->dedupliziert 1-basierter Index
-- werden vom Aufrufer (EditorRoom/ImageStoreCodec) injiziert.
function LayerModel.compositeCellTile(entry, pos, getTile, registerTile)
    local stack = contributingStack(entry, pos)
    if #stack == 0 then
        return LayerModel.WHITE_TILE
    elseif #stack == 1 then
        return stack[1]
    elseif isFullyOpaque(getTile(stack[#stack])) then
        return stack[#stack]
    else
        local gfx = playdate.graphics
        local tilePx = LayerModel.TILE_PX
        local merged = gfx.image.new(tilePx, tilePx, gfx.kColorClear)
        gfx.pushContext(merged)
            for s = 1, #stack do
                local img = getTile(stack[s])
                if img then
                    img:draw(0, 0)
                end
            end
        gfx.popContext()
        return registerTile(merged)
    end
end

-- Guenstiges Compositing auf Tile-Zellen-Ebene: von oben nach unten gewinnt
-- die erste Ebene mit positions[pos] ~= 0 (und visible). Traegt keine Ebene
-- etwas bei, faellt die Zelle auf das Weiss-Tile zurueck. NICHT pixelgenau —
-- nur fuer Kontexte ohne getTile/registerTile (z.B. reine Zellen-Zaehlung).
-- Fuer WYSIWYG-Rendering siehe compositeCellTile()/compositeToTiles().
function LayerModel.compositeAt(entry, pos)
    local layers = entry.layers
    for i = #layers, 1, -1 do
        local layer = layers[i]
        if layer.visible ~= false and layer.positions[pos] and layer.positions[pos] ~= LayerModel.ABSENT then
            return layer.positions[pos]
        end
    end
    return LayerModel.WHITE_TILE
end

-- Kompositiert alle 375 Positionen in ein flaches Array (Tilemap-Rendering,
-- Vorschau, Pause-Ansicht — exakt das Format, das der Rest der Codebasis vor
-- Spec 010 ueberall erwartet hat). NICHT pixelgenau (siehe compositeAt) —
-- nur fuer Kontexte ohne getTile/registerTile. Fuer WYSIWYG siehe
-- compositeToTiles().
function LayerModel.compositeToFlat(entry)
    local out = {}
    for pos = 1, LayerModel.POSITIONS do
        out[pos] = LayerModel.compositeAt(entry, pos)
    end
    return out
end

-- WYSIWYG-Compositing mit pixelgenauer Ueberblendung (research.md R3, Task
-- T053 — jetzt in den Renderpfad verdrahtet: EditorRoom.recompositeCell/
-- recompositeCurrentFrame und der v1.1-Ladepfad nutzen dies statt der
-- zellenweisen Einzel-Tile-Auswahl aus compositeToFlat, damit transparente
-- Pixel einer oberen Ebene die darunterliegende Ebene wirklich durchscheinen
-- lassen statt nur den Leerzustand der Tilemap-Zelle zu zeigen). Fuer jede
-- Zelle, an der MEHRERE sichtbare Ebenen beitragen, wird ein
-- zusammengefuehrtes 16x16-Tile gebaut; Zellen mit nur EINER beitragenden
-- Ebene bleiben unveraendert bei deren Tile-Index (kein neues Tile).
function LayerModel.compositeToTiles(entry, getTile, registerTile)
    local out = {}
    for pos = 1, LayerModel.POSITIONS do
        out[pos] = LayerModel.compositeCellTile(entry, pos, getTile, registerTile)
    end
    return out
end

-- Onion-Skin-Hintergrund fuer die Zoom-View-Anzeige (rein visuell, NICHT
-- persistiert/dedupliziert): kompositiert pixelgenau alle sichtbaren Ebenen
-- STRIKT UNTERHALB der 1-basierten aktiven Ebene activeLayer1 an Zelle pos,
-- damit die aktive Ebene beim Bearbeiten ueber den darunterliegenden Ebenen
-- angezeigt werden kann (spec.md "Layer Rendering Order": transparente Pixel
-- lassen tiefere Ebenen durchscheinen). Liefert nil, wenn activeLayer1 <= 1
-- (die Basisebene hat nichts darunter) oder keine tiefere Ebene an dieser
-- Zelle etwas beitraegt — der Aufrufer faellt dann auf Weiss zurueck.
-- getTile(index)->image wird vom Aufrufer injiziert; KEIN registerTile, das
-- Ergebnisbild wird nie in die Imagetable geschrieben.
function LayerModel.compositeBelow(entry, pos, activeLayer1, getTile)
    if not activeLayer1 or activeLayer1 <= 1 then return nil end
    local stack = contributingStack(entry, pos, activeLayer1 - 1)
    if #stack == 0 then
        return nil
    elseif #stack == 1 then
        return getTile(stack[1])
    else
        local gfx = playdate.graphics
        local tilePx = LayerModel.TILE_PX
        local merged = gfx.image.new(tilePx, tilePx, gfx.kColorClear)
        gfx.pushContext(merged)
            for s = 1, #stack do
                local img = getTile(stack[s])
                if img then
                    img:draw(0, 0)
                end
            end
        gfx.popContext()
        return merged
    end
end

-- ── Pixel-Verschiebung EINES Tiles (US1, revidiert 2026-09-01) ─────────────
--
-- Einschraenkung aus dem Hardware-Test (ADR-043): B + Pfeiltaste verschiebt
-- den Inhalt der Zelle unter dem Cursor um 1 nativen Pixel, NICHT den
-- gesamten Screen. Der Inhalt wandert dabei in die Nachbarzelle in
-- Schieberichtung und bleibt dort: Ausgangszelle UND dieser eine Nachbar
-- bilden fuer den Schritt einen gemeinsamen 2-Tile-Streifen (32x16 bzw.
-- 16x32), der als Ganzes um 1px verschoben wird. Die von der Schieberichtung
-- abgewandte Randkante der Ausgangszelle wird mit dem ebenenabhaengigen
-- "Nicht-Tinte"-Zustand gefuellt (weiss auf der Basisebene, transparent auf
-- den oberen Ebenen); die abgewandte Randkante des Nachbarn faellt weg (KEIN
-- Wrap, KEIN Weiterreichen an eine dritte Zelle). Liegt die Ausgangszelle am
-- Rand des 25x15-Rasters, faellt der austretende Streifen weg und nur die
-- Ausgangszelle aendert sich.
--
-- Die Operation ist lokal (max. 2 Tiles je Tastendruck, ~2500 Ops) und
-- braucht die frueher noetige aufgeschobene Ganz-Ebenen-Materialisierung
-- (ADR-043, erste Fassung) nicht mehr.

-- Richtung -> (dx,dy) fuer einen 1-Pixel-Schritt. nil bei ungueltiger Richtung.
function LayerModel.shiftDelta(direction)
    if direction == "up" then return 0, -1
    elseif direction == "down" then return 0, 1
    elseif direction == "left" then return -1, 0
    elseif direction == "right" then return 1, 0
    end
    return nil
end

-- Verschiebt den Inhalt der Zelle cellIdx (1-basiert, 1..375) der aktiven
-- Ebene um genau 1 nativen Pixel in Richtung "up"|"down"|"left"|"right".
--
-- getTile(index)->image (16x16 der Imagetable), registerTile(image)->
-- dedupter 1-basierter Index. "absent" (0) Zellen zaehlen als voll-clear.
-- Rueckgabe: sortierte Liste der tatsaechlich geaenderten Zell-Indizes
-- (1 oder 2 Eintraege), oder nil bei ungueltiger Eingabe.
function LayerModel.shiftTileContent(entry, active1, cellIdx, direction, getTile, registerTile)
    local layer = LayerModel.getLayer(entry, active1)
    if not layer then return nil end
    local dx, dy = LayerModel.shiftDelta(direction)
    if not dx then return nil end
    local cols, rows, tilePx = LayerModel.GRID_COLS, LayerModel.GRID_ROWS, LayerModel.TILE_PX
    if type(cellIdx) ~= "number" or cellIdx < 1 or cellIdx > cols * rows then return nil end

    local gfx = playdate.graphics
    local offState = (layer.layerIndex == 0) and PixelTransparency.EMPTY or PixelTransparency.TRANSPARENT
    local last = tilePx - 1

    -- Nachbarzelle in Schieberichtung (0-basierte Zell-Koordinaten).
    local cx, cy = (cellIdx - 1) % cols, (cellIdx - 1) // cols
    local nx, ny = cx + dx, cy + dy
    local neighborIdx = (nx >= 0 and nx < cols and ny >= 0 and ny < rows)
        and (ny * cols + nx + 1) or nil

    -- 16x16-Raster einer Zelle als 3-Zustands-Codes ("absent" -> voll clear).
    local function decodeCell(idx)
        local tileIndex = layer.positions[idx]
        local img = (tileIndex and tileIndex ~= LayerModel.ABSENT) and getTile(tileIndex) or nil
        local g = {}
        for py = 0, last do
            g[py] = {}
            for px = 0, last do
                g[py][px] = img and PixelTransparency.sampleState(img, px, py)
                    or PixelTransparency.TRANSPARENT
            end
        end
        return g
    end

    -- 16x16-Raster als (dedupliziertes) Tile in layer.positions[idx] schreiben;
    -- komplett transparent auf oberen Ebenen -> "absent" (0).
    local function writeCell(idx, g)
        local img = gfx.image.new(tilePx, tilePx, gfx.kColorClear)
        local allTransparent = true
        gfx.pushContext(img)
            for py = 0, last do
                for px = 0, last do
                    local state = g[py][px]
                    if state ~= PixelTransparency.TRANSPARENT then
                        allTransparent = false
                        gfx.setColor(PixelTransparency.toColor(state))
                        gfx.drawPixel(px, py)
                    end
                end
            end
        gfx.popContext()
        if allTransparent and layer.layerIndex ~= 0 then
            layer.positions[idx] = LayerModel.ABSENT
        else
            layer.positions[idx] = registerTile(img)
        end
    end

    local cur = decodeCell(cellIdx)

    -- Ausgangszelle: um 1px verschoben, die von der Schieberichtung abgewandte
    -- Randkante wird mit offState gefuellt.
    local newCur = {}
    for py = 0, last do
        newCur[py] = {}
        for px = 0, last do
            local sx, sy = px - dx, py - dy
            if sx >= 0 and sx <= last and sy >= 0 and sy <= last then
                newCur[py][px] = cur[sy][sx]
            else
                newCur[py][px] = offState
            end
        end
    end
    writeCell(cellIdx, newCur)
    local changed = { cellIdx }

    if neighborIdx then
        -- Nachbar = zweite Haelfte des 2-Tile-Streifens: sein der Ausgangszelle
        -- zugewandter Rand bekommt den austretenden Streifen der Ausgangszelle,
        -- der Rest schiebt in dieselbe Richtung mit, der abgewandte Rand faellt
        -- weg. edgeX/edgeY zeigen auf die austretende Kante der Ausgangszelle.
        local edgeX, edgeY
        if dx == 1 then edgeX = last elseif dx == -1 then edgeX = 0 end
        if dy == 1 then edgeY = last elseif dy == -1 then edgeY = 0 end
        local nb = decodeCell(neighborIdx)
        local newNb = {}
        for py = 0, last do
            newNb[py] = {}
            for px = 0, last do
                local sx, sy = px - dx, py - dy
                if sx >= 0 and sx <= last and sy >= 0 and sy <= last then
                    newNb[py][px] = nb[sy][sx]
                else
                    -- 0 ist in Lua truthy, daher deckt "edgeX or px" den Fall
                    -- edgeX == 0 korrekt ab (edgeX ist nil nur auf der NICHT-
                    -- Schiebeachse).
                    newNb[py][px] = cur[edgeY or py][edgeX or px]
                end
            end
        end
        writeCell(neighborIdx, newNb)
        changed[#changed + 1] = neighborIdx
    end

    table.sort(changed)
    return changed
end

return LayerModel
