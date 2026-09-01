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

-- Guenstiges Compositing auf Tile-Zellen-Ebene: von oben nach unten gewinnt
-- die erste Ebene mit positions[pos] ~= 0 (und visible). Traegt keine Ebene
-- etwas bei, faellt die Zelle auf das Weiss-Tile zurueck. Fuer WYSIWYG mit
-- Pixel-genauer Ueberblendung siehe compositeToTiles().
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
-- Spec 010 ueberall erwartet hat).
function LayerModel.compositeToFlat(entry)
    local out = {}
    for pos = 1, LayerModel.POSITIONS do
        out[pos] = LayerModel.compositeAt(entry, pos)
    end
    return out
end

-- WYSIWYG-Compositing mit pixelgenauer Ueberblendung (research.md R3): fuer
-- jede Zelle, an der MEHRERE sichtbare Ebenen beitragen, wird ein
-- zusammengefuehrtes 16x16-Tile gebaut (untere Ebene zuerst, daraufliegende
-- nicht-transparente Pixel der oberen Ebenen). Zellen mit nur EINER
-- beitragenden Ebene bleiben unveraendert bei deren Tile-Index (kein neues
-- Tile). getTile(index)->image, registerTile(image)->dedupter 1-basierter
-- Index werden vom Aufrufer (EditorRoom/ImageStoreCodec) injiziert.
--
-- ACHTUNG (noch NICHT im Renderpfad verdrahtet, Task T053): die Basisebene
-- traegt immer bei, daher merged diese Funktion JEDE Zelle mit oberer-Ebenen-
-- Inhalt und registriert dafuer ein Tile. Vor dem Verdrahten ist die
-- Merge-Rate zu druecken (z.B. nur mergen, wenn das obere Tile wirklich
-- kColorClear-Pixel enthaelt; ein voll deckendes oberes Tile occludet und
-- braucht keinen Merge). compositeToFlat() ist der aktuelle Renderpfad.
function LayerModel.compositeToTiles(entry, getTile, registerTile)
    local gfx = playdate.graphics
    local tilePx = LayerModel.TILE_PX
    local out = {}
    for pos = 1, LayerModel.POSITIONS do
        -- Von unten nach oben beitragende Ebenen sammeln
        local stack = {}
        for i = 1, #entry.layers do
            local layer = entry.layers[i]
            if layer.visible ~= false and layer.positions[pos] and layer.positions[pos] ~= LayerModel.ABSENT then
                stack[#stack + 1] = layer.positions[pos]
            end
        end
        if #stack == 0 then
            out[pos] = LayerModel.WHITE_TILE
        elseif #stack == 1 then
            out[pos] = stack[1]
        else
            local merged = gfx.image.new(tilePx, tilePx, gfx.kColorClear)
            gfx.pushContext(merged)
                for s = 1, #stack do
                    local img = getTile(stack[s])
                    if img then
                        -- kColorClear-Pixel der oberen Ebene lassen die
                        -- untere durch (SDK: image:draw respektiert die Maske)
                        img:draw(0, 0)
                    end
                end
            gfx.popContext()
            out[pos] = registerTile(merged)
        end
    end
    return out
end

-- ── Pixel-Verschiebung (US1, contracts/layer-api.md "Layer:shift") ─────────
--
-- Design-Entscheidung (spec.md Edge Cases nennt "wraps or clips gracefully
-- (no data loss)" — beides zugleich ist nicht moeglich): WRAP-AROUND, weil
-- nur das garantiert, dass wirklich KEIN Bildinhalt verloren geht (analog
-- PixelRoom-Crank-Rotation).
--
-- Perf-Nachtrag (Review nach Hardware-Test, 2026-09-01, ADR-043): urspruenglich
-- eine einzige Funktion (dekodieren -> verschobenes Zweitraster bauen ->
-- alle 375 Tiles neu aufbauen), gemessen ~192.000 image:sample()-Aufrufe +
-- 375 image.new() FUER EINEN 1px-Schritt. In drei Bausteine zerlegt, damit
-- EditorRoom.shiftActiveLayer den Decode nur EINMAL pro Verschiebe-Sitzung
-- zahlt (siehe dort) und wiederholte Tastendruecke bloss den Lese-Versatz
-- verschieben, statt ein zweites 96000-Zellen-Raster zu kopieren:
--
--   decodeLayerGrid(layer, getTile)                 -- einmal: Pixel lesen
--   materializeShiftedGrid(layer, grid, offX, offY, registerTile)  -- einmal: Tiles bauen
--   imageFromGrid(grid, offX, offY, tileCol0, tileRow0)            -- Live-Vorschau, 1 Tile
--
-- shiftLayerContent bleibt als synchroner Einzelschritt (bestehende Aufrufer/
-- Tests bleiben unveraendert gueltig) — nur ein duenner Wrapper der drei.

-- Richtung -> (dx,dy) fuer einen 1-Pixel-Schritt. nil bei ungueltiger Richtung.
function LayerModel.shiftDelta(direction)
    if direction == "up" then return 0, -1
    elseif direction == "down" then return 0, 1
    elseif direction == "left" then return -1, 0
    elseif direction == "right" then return 1, 0
    end
    return nil
end

-- Dekodiert den vollen 400x240-Pixelinhalt einer Ebene als 3-Zustands-Codes
-- (grid[gy][gx]). "absent" (0) Zellen zaehlen als voll-transparent. Reiner
-- Lesevorgang, mutiert weder layer noch die Imagetable.
function LayerModel.decodeLayerGrid(layer, getTile)
    local cols, rows, tilePx = LayerModel.GRID_COLS, LayerModel.GRID_ROWS, LayerModel.TILE_PX
    local grid = {}
    for gy = 0, rows * tilePx - 1 do grid[gy] = {} end
    for ty = 0, rows - 1 do
        for tx = 0, cols - 1 do
            local pos = ty * cols + tx + 1
            local tileIndex = layer.positions[pos]
            local img = (tileIndex and tileIndex ~= LayerModel.ABSENT) and getTile(tileIndex) or nil
            for py = 0, tilePx - 1 do
                for px = 0, tilePx - 1 do
                    local gx = tx * tilePx + px
                    local gy2 = ty * tilePx + py
                    grid[gy2][gx] = img and PixelTransparency.sampleState(img, px, py)
                        or PixelTransparency.TRANSPARENT
                end
            end
        end
    end
    return grid
end

-- Baut alle 375 Tiles der Ebene aus einem dekodierten Pixelraster (siehe
-- decodeLayerGrid) neu auf, GELESEN durch einen Wrap-Versatz (offX,offY) —
-- das Verschieben selbst ist also nur eine Indexverschiebung beim Lesen,
-- keine zweite 96000-Zellen-Kopie (spart das fruehere "shifted"-Zweitraster
-- auch im synchronen Einzelschritt-Fall). Schreibt layer.positions; komplett
-- transparente Tiles werden auf oberen Ebenen als "absent" (0) abgelegt.
function LayerModel.materializeShiftedGrid(layer, grid, offX, offY, registerTile)
    local gfx = playdate.graphics
    local cols, rows, tilePx = LayerModel.GRID_COLS, LayerModel.GRID_ROWS, LayerModel.TILE_PX
    local width, height = cols * tilePx, rows * tilePx

    for ty = 0, rows - 1 do
        for tx = 0, cols - 1 do
            local pos = ty * cols + tx + 1
            local img = gfx.image.new(tilePx, tilePx, gfx.kColorClear)
            local allTransparent = true
            gfx.pushContext(img)
                for py = 0, tilePx - 1 do
                    for px = 0, tilePx - 1 do
                        local gx = (tx * tilePx + px - offX) % width
                        local gy = (ty * tilePx + py - offY) % height
                        local state = grid[gy][gx]
                        if state ~= PixelTransparency.TRANSPARENT then
                            allTransparent = false
                            gfx.setColor(PixelTransparency.toColor(state))
                            gfx.drawPixel(px, py)
                        end
                    end
                end
            gfx.popContext()

            if allTransparent and layer.layerIndex ~= 0 then
                layer.positions[pos] = LayerModel.ABSENT
            else
                layer.positions[pos] = registerTile(img)
            end
        end
    end
end

-- Synthetisiert EIN 16x16-Tile-Bild direkt aus einem dekodierten Pixelraster
-- an Kachelposition (tileCol0,tileRow0) (0-basiert), gelesen durch denselben
-- Wrap-Versatz wie materializeShiftedGrid — fuer eine Live-Vorschau, WAEHREND
-- eine Verschiebe-Sitzung noch offen ist, ohne alle 375 Tiles neu zu
-- bauen/hashen (EditorRoom.buildZoomContext).
function LayerModel.imageFromGrid(grid, offX, offY, tileCol0, tileRow0)
    local gfx = playdate.graphics
    local tilePx = LayerModel.TILE_PX
    local width, height = LayerModel.GRID_COLS * tilePx, LayerModel.GRID_ROWS * tilePx
    local img = gfx.image.new(tilePx, tilePx, gfx.kColorClear)
    gfx.pushContext(img)
        for py = 0, tilePx - 1 do
            for px = 0, tilePx - 1 do
                local gx = (tileCol0 * tilePx + px - offX) % width
                local gy = (tileRow0 * tilePx + py - offY) % height
                local state = grid[gy][gx]
                if state ~= PixelTransparency.TRANSPARENT then
                    gfx.setColor(PixelTransparency.toColor(state))
                    gfx.drawPixel(px, py)
                end
            end
        end
    gfx.popContext()
    return img
end

-- Verschiebt den gesamten 400x240-Pixelinhalt der Ebene active1 um genau 1
-- nativen Pixel in Richtung "up"|"down"|"left"|"right" und baut alle 375
-- Tiles der Ebene neu auf (synchroner Einzelschritt — siehe Perf-Nachtrag
-- oben; EditorRoom.shiftActiveLayer nutzt fuer Mehrfach-Schritte stattdessen
-- decodeLayerGrid/materializeShiftedGrid direkt).
--
-- getTile(index)->image (16x16 der Imagetable), registerTile(image)->
-- dedupter 1-basierter Index. "absent" (0) Zellen zaehlen als voll-clear.
function LayerModel.shiftLayerContent(entry, active1, direction, getTile, registerTile)
    local layer = LayerModel.getLayer(entry, active1)
    if not layer then return false end
    local dx, dy = LayerModel.shiftDelta(direction)
    if not dx then return false end
    local grid = LayerModel.decodeLayerGrid(layer, getTile)
    LayerModel.materializeShiftedGrid(layer, grid, dx, dy, registerTile)
    return true
end

return LayerModel
