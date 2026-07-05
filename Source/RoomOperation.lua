-- RoomOperation.lua — frameweise abgearbeitete Hintergrund-Operation.
--
-- Playdate hat keine Threads: Lange Arbeiten (Laden/Speichern) laufen als
-- Lua-Coroutine, die der Raum in jedem update() genau ein Stück weiterdreht
-- (coroutine.resume). Die Coroutine yieldet zwischen Phasen ihren Phasennamen;
-- der landet als Detailtext im Overlay (loadingBar). So bleibt die UI
-- responsiv und der Fortschritt sichtbar.
RoomOperation = {}

-- overlay: loadingBar-Instanz; onStateChanged: optionaler Hook (z.B. Redraw)
function RoomOperation.new(overlay, onStateChanged)
    local operation = {
        overlay = overlay,
        onStateChanged = onStateChanged,
        current = nil
    }

    function operation:isActive()
        return self.current ~= nil
    end

    function operation:start(title, detail, coroutineFactory, onComplete)
        if self.current ~= nil then
            return false
        end

        self.overlay:show(title, detail)
        self.current = {
            co = coroutineFactory(),
            onComplete = onComplete
        }

        if self.onStateChanged then
            self.onStateChanged()
        end

        return true
    end

    function operation:resume(onError)
        if self.current == nil then
            return
        end

        -- value ist bei yield der Phasenname, beim letzten Resume der Rückgabewert der Coroutine
        local ok, value = coroutine.resume(self.current.co)
        if not ok then
            local failure = value
            self.current = nil
            self.overlay:fail(failure)
            if self.onStateChanged then
                self.onStateChanged()
            end
            if onError then
                onError(failure)
            end
            return
        end

        if coroutine.status(self.current.co) == "dead" then
            local onComplete = self.current.onComplete
            self.current = nil
            self.overlay:finish()
            if self.onStateChanged then
                self.onStateChanged()
            end
            if onComplete then
                onComplete(value)
            end
        else
            if value ~= nil then
                self.overlay:setDetail(value)
            end
        end
    end

    return operation
end

return RoomOperation