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
end

function MMU:reset()
    self.memory = setmetatable({}, {__len = function() return MEMORY_SIZE end})
end

function MMU:loadRom(romData)
    for index, byte in pairs(romData) do
        self.memory[index] = byte
    end
end

function MMU:writeByte(address, value)
    self.memory[address + 1] = value
end

function MMU:readByte(address)
    return self.memory[address + 1]
end

function MMU:readUInt16(address)
    local value = 0

    for i=0, 1 do
        value = value + bitLShift(self:readByte(address + i), 8 * (1 - i))
    end

    return value
end

function MMU:readInt16(address)
    local value = self:readUInt16(address)

    if (bitTest(value, 0x8000)) then
        value = -((0xFFFF - value) + 1)
    end

    return value
end
