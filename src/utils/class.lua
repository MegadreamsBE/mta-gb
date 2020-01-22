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
            local object = setmetatable({}, {
                __index = _class
            })

            if (object.create ~= nil) then
                object:create(...)
            end

            return object
        end
    })

    return _class
end
