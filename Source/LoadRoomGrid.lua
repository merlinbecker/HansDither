LoadRoomGrid = {}
LoadRoomGrid.__index = LoadRoomGrid

function LoadRoomGrid.new(config)
    local instance = {
        config = config,
        roomNames = {},
        previewCache = {},
        directionHold = {
            up = { active = false, nextMs = 0 },
            down = { active = false, nextMs = 0 },
            left = { active = false, nextMs = 0 },
            right = { active = false, nextMs = 0 }
        }
    }
    return setmetatable(instance, LoadRoomGrid)
end

function LoadRoomGrid:getRoomNames()
    return self.roomNames
end

function LoadRoomGrid:refreshRoomNames(gameData)
    self.roomNames = {}
    if not gameData or not gameData.rooms then return end
    for _, room in ipairs(gameData.rooms) do
        table.insert(self.roomNames, room.name or ("Room " .. (room.id + 1)))
    end
end

function LoadRoomGrid:loadRoomPreviews(gameData, gameName)
    self.previewCache = {}
    if not gameData or not gameData.rooms then return end
    for i, room in ipairs(gameData.rooms) do
        self.previewCache[i] = playdate.datastore.readImage("saves/" .. gameName .. "_room" .. room.id .. "_preview")
    end
end

function LoadRoomGrid:getGridRows()
    return math.max(1, math.ceil((1 + #self.roomNames) / self.config.gridCols))
end

function LoadRoomGrid:moveSelection(onSelectionChanged)
    if onSelectionChanged then
        onSelectionChanged()
    end
end

function LoadRoomGrid:moveDirection(direction, onSelectionChanged)
    local gridView = self.config.gridView
    if direction == "up" then
        gridView:selectPreviousRow(true, true, true)
    elseif direction == "down" then
        gridView:selectNextRow(true, true, true)
    elseif direction == "left" then
        gridView:selectPreviousColumn(true, true, true)
    elseif direction == "right" then
        gridView:selectNextColumn(true, true, true)
    else
        return
    end
    self:moveSelection(onSelectionChanged)
end

function LoadRoomGrid:startDirectionHold(direction, onSelectionChanged)
    local state = self.directionHold[direction]
    if not state then return end
    self:moveDirection(direction, onSelectionChanged)
    state.active = true
    state.nextMs = playdate.getCurrentTimeMilliseconds() + self.config.holdInitialDelayMs
end

function LoadRoomGrid:stopDirectionHold(direction)
    local state = self.directionHold[direction]
    if not state then return end
    state.active = false
end

function LoadRoomGrid:clearDirectionHold()
    for _, state in pairs(self.directionHold) do
        state.active = false
    end
end

function LoadRoomGrid:processDirectionHold(onSelectionChanged)
    local nowMs = playdate.getCurrentTimeMilliseconds()
    local buttonByDirection = {
        up = playdate.kButtonUp,
        down = playdate.kButtonDown,
        left = playdate.kButtonLeft,
        right = playdate.kButtonRight
    }
    for direction, state in pairs(self.directionHold) do
        if state.active then
            local button = buttonByDirection[direction]
            if not playdate.buttonIsPressed(button) then
                state.active = false
            elseif nowMs >= state.nextMs then
                self:moveDirection(direction, onSelectionChanged)
                state.nextMs = nowMs + self.config.holdRepeatMs
            end
        end
    end
end

function LoadRoomGrid:drawCell(section, row, column, selected, x, y, width, height)
    local gfx = self.config.gfx
    local linearIndex = (row - 1) * self.config.gridCols + column
    local totalCells = 1 + #self.roomNames
    if linearIndex > totalCells then return end

    if selected then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(x, y, width, height)
    else
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(x, y, width, height)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRect(x, y, width, height)
    end

    if linearIndex == 1 then
        gfx.setImageDrawMode(selected and gfx.kDrawModeFillWhite or gfx.kDrawModeCopy)
        gfx.drawTextAligned("+", x + width // 2, y + height // 2 - 5, kTextAlignment.center)
    else
        local roomIdx = linearIndex - 1
        if roomIdx <= #self.roomNames then
            local preview = self.previewCache[roomIdx]
            if preview then
                    local px = x + (width - 80) // 2
                    local py = y + (height - 48) // 2
                gfx.setImageDrawMode(selected and gfx.kDrawModeInverted or gfx.kDrawModeCopy)
                    preview:drawScaled(px, py, 0.4)
            else
                gfx.setColor(selected and gfx.kColorWhite or gfx.kColorBlack)
                    gfx.drawRect(x + (width - 60) // 2, y + (height - 36) // 2, 60, 36)
            end
        end
    end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function LoadRoomGrid:draw(gameName, keyboardVisible, keyboardText)
    local gfx = self.config.gfx
    gfx.clear(gfx.kColorWhite)
    gfx.drawText(gameName or "Hans-Dither", 4, 2)
    gfx.setColor(gfx.kColorBlack)
        gfx.drawLine(0, 24, 399, 24)
        self.config.gridView:drawInRect(1, 25, 398, 182)
        gfx.drawLine(0, 208, 399, 208)

    local infoText
    if keyboardVisible then
        infoText = "> " .. (keyboardText or "")
    else
        local _, row, col = self.config.gridView:getSelection()
        local idx = (row - 1) * self.config.gridCols + col
        if idx == 1 then
            if #self.roomNames >= self.config.maxRooms then
                infoText = "[Max. " .. self.config.maxRooms .. " Rooms reached]"
            else
                infoText = "[+ Neuer Room]"
            end
        else
            infoText = self.roomNames[idx - 1] or ""
        end
    end
        gfx.drawText(infoText, 4, 216)
end

return LoadRoomGrid