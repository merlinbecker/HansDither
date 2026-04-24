import "Bauchbinde"

TileRoomEditor = {}
TileRoomEditor.__index = TileRoomEditor

function TileRoomEditor.new(config)
    return setmetatable({
        config = config,
        bauchbinde = Bauchbinde.new(config.gfx, {
            margin = config.winMargin,
            height = config.winSize,
            paddingX = 4
        })
    }, TileRoomEditor)
end

function TileRoomEditor:drawCell(section, row, column, selected, x, y, width, height)
    local cfg = self.config
    local selSection, selRow, selCol = cfg.gridView:getSelection()
    local isCursor = (section == selSection and row == selRow and column == selCol)
    if isCursor and cfg.cursorBlinker.on then
        local tileIndex = cfg.tilemap:getTileAtPosition(column, row)
        local tile = cfg.getCellImagetable():getImage(tileIndex)
        local centerPixel = tile and tile:sample(cfg.cellSize // 2, cfg.cellSize // 2) or cfg.gfx.kColorWhite
        if centerPixel == cfg.gfx.kColorBlack then
            cfg.gfx.setColor(cfg.gfx.kColorWhite)
        else
            cfg.gfx.setColor(cfg.gfx.kColorBlack)
        end
        cfg.gfx.fillCircleAtPoint(x + width / 2, y + height / 2, 2)
    end
end

function TileRoomEditor:drawTilePickerWindow()
    if not self.config.getTilePickerVisible() then return end

    local _, _, selCol = self.config.gridView:getSelection()
    local px
    if selCol <= self.config.gridCols / 2 then
        px = self.config.screenW - self.config.winSize - self.config.winMargin
    else
        px = self.config.winMargin
    end
    local py = self.config.winMargin

    self.config.gfx.setColor(self.config.gfx.kColorWhite)
    self.config.gfx.fillRect(px, py, self.config.winSize, self.config.winSize)
    self.config.gfx.setColor(self.config.gfx.kColorBlack)
    self.config.gfx.drawRect(px, py, self.config.winSize, self.config.winSize)
    local tile = self.config.getCellImagetable():getImage(self.config.getTilePickerIndex())
    if tile then
           tile:drawScaled(px + 6, py + 6, 4.0)
    end

    self:drawBauchbinde("tilePicker", px)
end

function TileRoomEditor:drawBauchbinde(text, pickerX)
    if not text or text == "" then return end

    -- Bauchbinde immer auf die gegenueberliegende Seite des Picker-Fensters setzen.
    local pickerIsLeft = pickerX <= (self.config.screenW // 2)
    local side
    if pickerIsLeft then
        side = "right"
    else
        side = "left"
    end

    self.bauchbinde:drawBottom(text, side, self.config.screenW, self.config.screenH)
end

function TileRoomEditor:drawModeBauchbinde(text, side)
    if not text or text == "" then return end
    self.bauchbinde:drawBottom(text, side or "left", self.config.screenW, self.config.screenH)
end

function TileRoomEditor:getBackgroundTile()
    return self.config.getShowGrid() and 1 or 2
end

function TileRoomEditor:toggleCurrentCell()
    local _, row, col = self.config.gridView:getSelection()
    if row and col then
        local current = self.config.tilemap:getTileAtPosition(col, row)
        if current == self.config.getTilePickerIndex() then
            self.config.tilemap:setTileAtPosition(col, row, self:getBackgroundTile())
        else
            self.config.tilemap:setTileAtPosition(col, row, self.config.getTilePickerIndex())
        end
        self.config.markDirty()
    end
end

function TileRoomEditor:paintCurrentCell()
    local _, row, col = self.config.gridView:getSelection()
    if row and col and self.config.tilemap:getTileAtPosition(col, row) ~= self.config.getTilePickerIndex() then
        self.config.tilemap:setTileAtPosition(col, row, self.config.getTilePickerIndex())
        self.config.markDirty()
    end
end

function TileRoomEditor:moveCursor(direction)
    local _, oldRow, oldCol = self.config.gridView:getSelection()
    if direction == "up" then
        self.config.gridView:selectPreviousRow(false, true, false)
    elseif direction == "down" then
        self.config.gridView:selectNextRow(false, true, false)
    elseif direction == "left" then
        self.config.gridView:selectPreviousColumn(false, true, false)
    elseif direction == "right" then
        self.config.gridView:selectNextColumn(false, true, false)
    else
        return
    end

    local _, newRow, newCol = self.config.gridView:getSelection()
    if oldRow ~= newRow or oldCol ~= newCol then
        if playdate.buttonIsPressed(playdate.kButtonA) then
            self:paintCurrentCell()
        end
        self.config.markDirty()
    end
end

function TileRoomEditor:startDirectionHold(direction)
    local state = self.config.directionHold[direction]
    if not state then return end
    self:moveCursor(direction)
    state.active = true
    state.nextMs = playdate.getCurrentTimeMilliseconds() + self.config.holdInitialDelayMs
end

function TileRoomEditor:stopDirectionHold(direction)
    local state = self.config.directionHold[direction]
    if not state then return end
    state.active = false
end

function TileRoomEditor:clearDirectionHold()
    for _, state in pairs(self.config.directionHold) do
        state.active = false
    end
end

function TileRoomEditor:processDirectionHold()
    local nowMs = playdate.getCurrentTimeMilliseconds()
    local buttonByDirection = {
        up = playdate.kButtonUp,
        down = playdate.kButtonDown,
        left = playdate.kButtonLeft,
        right = playdate.kButtonRight
    }
    for direction, state in pairs(self.config.directionHold) do
        if state.active then
            local button = buttonByDirection[direction]
            if not playdate.buttonIsPressed(button) then
                state.active = false
            elseif nowMs >= state.nextMs then
                self:moveCursor(direction)
                state.nextMs = nowMs + self.config.holdRepeatMs
            end
        end
    end
end

function TileRoomEditor:buildInputHandler(isOperationActive)
    return {
        upButtonDown = function()
            if isOperationActive() then return end
            self:startDirectionHold("up")
        end,
        upButtonUp = function()
            if isOperationActive() then return end
            self:stopDirectionHold("up")
        end,
        downButtonDown = function()
            if isOperationActive() then return end
            self:startDirectionHold("down")
        end,
        downButtonUp = function()
            if isOperationActive() then return end
            self:stopDirectionHold("down")
        end,
        leftButtonDown = function()
            if isOperationActive() then return end
            self:startDirectionHold("left")
        end,
        leftButtonUp = function()
            if isOperationActive() then return end
            self:stopDirectionHold("left")
        end,
        rightButtonDown = function()
            if isOperationActive() then return end
            self:startDirectionHold("right")
        end,
        rightButtonUp = function()
            if isOperationActive() then return end
            self:stopDirectionHold("right")
        end,
        AButtonDown = function()
            if isOperationActive() then return end
            self:toggleCurrentCell()
        end
    }
end

return TileRoomEditor