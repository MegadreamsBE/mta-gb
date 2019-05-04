MMU = Class()

-----------------------------------
-- * Constants
-----------------------------------

local MEMORY_SIZE = 65536

-----------------------------------
-- * Functions
-----------------------------------

function MMU:create()
    self.memory = {}
    self.rom = {}
end

function MMU:reset()
    self.memory = setmetatable({}, {__len = function() return MEMORY_SIZE end})
end

function MMU:loadRom(romData)
    self.rom = romData
end

function MMU:getRom()
    return self.rom
end
