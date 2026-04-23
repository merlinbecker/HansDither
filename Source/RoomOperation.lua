RoomOperation = {}

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

        local ok, err = coroutine.resume(self.current.co)
        if not ok then
            local failure = err
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
                onComplete()
            end
        end
    end
end

return RoomOperation