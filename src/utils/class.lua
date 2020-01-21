-----------------------------------
-- * Variables
-----------------------------------

Class = {}
Class = setmetatable({}, {
    __call = function(_, ...) return Class:create(...) end
})

-----------------------------------
-- * Functions
-----------------------------------

function Class:create()
    local _class = {}
    _class.__index = _class

    setmetatable(_class, {
        __call = function(_, ...)
            if (_class.create ~= nil) then
                _class:create(...)
            end

            return _class
        end
    })

    return _class
end
