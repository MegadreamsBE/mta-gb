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

function Class:create(extendsClass)
    local _class = {}
    _class.__index = _class

    if (extendsClass ~= nil) then
        _class.__index = extendsClass
    end

    setmetatable(_class, {
        __call = function(_, ...)
            local _object = setmetatable({}, _class)

            if (_object.create ~= nil) then
                _object:create(...)
            end

            return _object
        end
    })

    return _class
end
