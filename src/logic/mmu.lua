MMU = Class()

-----------------------------------
-- * Constants
-----------------------------------

local MEMORY_SIZE = 65536
local BIOS = {
    0x31, 0xFE, 0xFF, 0xAF, 0x21, 0xFF, 0x9F, 0x32, 0xCB, 0x7C, 0x20, 0xFB, 0x21, 0x26, 0xFF, 0x0E,
    0x11, 0x3E, 0x80, 0x32, 0xE2, 0x0C, 0x3E, 0xF3, 0xE2, 0x32, 0x3E, 0x77, 0x77, 0x3E, 0xFC, 0xE0,
    0x47, 0x11, 0x04, 0x01, 0x21, 0x10, 0x80, 0x1A, 0xCD, 0x95, 0x00, 0xCD, 0x96, 0x00, 0x13, 0x7B,
    0xFE, 0x34, 0x20, 0xF3, 0x11, 0xD8, 0x00, 0x06, 0x08, 0x1A, 0x13, 0x22, 0x23, 0x05, 0x20, 0xF9,
    0x3E, 0x19, 0xEA, 0x10, 0x99, 0x21, 0x2F, 0x99, 0x0E, 0x0C, 0x3D, 0x28, 0x08, 0x32, 0x0D, 0x20,
    0xF9, 0x2E, 0x0F, 0x18, 0xF3, 0x67, 0x3E, 0x64, 0x57, 0xE0, 0x42, 0x3E, 0x91, 0xE0, 0x40, 0x04,
    0x1E, 0x02, 0x0E, 0x0C, 0xF0, 0x44, 0xFE, 0x90, 0x20, 0xFA, 0x0D, 0x20, 0xF7, 0x1D, 0x20, 0xF2,
    0x0E, 0x13, 0x24, 0x7C, 0x1E, 0x83, 0xFE, 0x62, 0x28, 0x06, 0x1E, 0xC1, 0xFE, 0x64, 0x20, 0x06,
    0x7B, 0xE2, 0x0C, 0x3E, 0x87, 0xF2, 0xF0, 0x42, 0x90, 0xE0, 0x42, 0x15, 0x20, 0xD2, 0x05, 0x20,
    0x4F, 0x16, 0x20, 0x18, 0xCB, 0x4F, 0x06, 0x04, 0xC5, 0xCB, 0x11, 0x17, 0xC1, 0xCB, 0x11, 0x17,
    0x05, 0x20, 0xF5, 0x22, 0x23, 0x22, 0x23, 0xC9, 0xCE, 0xED, 0x66, 0x66, 0xCC, 0x0D, 0x00, 0x0B,
    0x03, 0x73, 0x00, 0x83, 0x00, 0x0C, 0x00, 0x0D, 0x00, 0x08, 0x11, 0x1F, 0x88, 0x89, 0x00, 0x0E,
    0xDC, 0xCC, 0x6E, 0xE6, 0xDD, 0xDD, 0xD9, 0x99, 0xBB, 0xBB, 0x67, 0x63, 0x6E, 0x0E, 0xEC, 0xCC,
    0xDD, 0xDC, 0x99, 0x9F, 0xBB, 0xB9, 0x33, 0x3E, 0x3c, 0x42, 0xB9, 0xA5, 0xB9, 0xA5, 0x42, 0x4C,
    0x21, 0x04, 0x01, 0x11, 0xA8, 0x00, 0x1A, 0x13, 0xBE, 0x20, 0xFE, 0x23, 0x7D, 0xFE, 0x34, 0x20,
    0xF5, 0x06, 0x19, 0x78, 0x86, 0x23, 0x05, 0x20, 0xFB, 0x86, 0x20, 0xFE, 0x3E, 0x01, 0xE0, 0x50
}

MMU.MEMORY_SIZE = MEMORY_SIZE
MMU.BIOS = BIOS

-----------------------------------
-- * Locals
-----------------------------------

local memoryViolation = function(address, pc)
    Log.error("MMU", "Illegal memory access violation at 0x%s (0x%s).",
        string.format("%.4x", address),
        string.format("%.2x", pc))

    return 0
end

-----------------------------------
-- * Functions
-----------------------------------

function MMU:create(cpu, gpu)
    self.cpu = cpu
    self.gpu = gpu

    self.mram = {}
    self.zram = {}
    self.rom = nil

    self.inBios = true
    self.stackDebug = {}
end

function MMU:reset()
    self.memory = setmetatable({}, {__len = function() return MEMORY_SIZE end})
end

function MMU:loadRom(rom)
    self.rom = rom
end

function MMU:writeByte(address, value)
    local set = function(location)
        location[address + 1] = value
    end

    switch(bitAnd(address, 0xF000))
        .case(0x1000)
        .case(0x2000)
        .case(0x3000)
        .case(0x4000)
        .case(0x5000)
        .case(0x6000)
        .case(0x7000, function()
            set(self.rom:getData())
        end)
        .case(0x8000)
        .case(0x9000, function()
            set(self.gpu.vram)
        end)
        .case(0xF000, function()
            if (address >= 0xFF80) then
                set(self.zram)
            elseif (address >= 0xFF40) then
                return
            else
                return
            end
        end)
        .default(function()
            return memoryViolation(address, self.cpu.registers.pc)
        end)()
end

function MMU:writeShort(address, value)
    local set = function(location)
        location[address + 1] = bitRShift(bitAnd(0xFF00, value), 8)
        location[address] = bitAnd(0x00FF, value)
    end

    switch(bitAnd(address, 0xF000))
        .case(0x1000)
        .case(0x2000)
        .case(0x3000)
        .case(0x4000)
        .case(0x5000)
        .case(0x6000)
        .case(0x7000, function()
            set(self.rom:getData())
        end)
        .case(0x8000)
        .case(0x9000, function()
            set(self.gpu.vram)
        end)
        .case(0xF000, function()
            if (address >= 0xFF80) then
                set(self.zram)
            elseif (address >= 0xFF40) then
                return
            else
                return
            end
        end)
        .default(function()
            return memoryViolation(address, self.cpu.registers.pc)
        end)()
end

function MMU:pushStack(value)
    self.cpu.registers.sp = self.cpu.registers.sp - 2
    self:writeShort(self.cpu.registers.sp, value)
    table.insert(self.stackDebug, 1, value)
end

function MMU:popStack()
    local value = self:readInt16(self.cpu.registers.sp)
    self.cpu.registers.sp = self.cpu.registers.sp + 2
    table.remove(self.stackDebug, 1)
    
    return value
end

function MMU:readByte(address)
    return switch(bitAnd(address, 0xF000))
        .case(0x0, function()
            if (self.inBios) then
                if (address < 0x100) then
                    return BIOS[address + 1] or 0
                elseif (self.cpu.registers.pc == 0x100) then
                    self.inBios = false
                end
            end

            return self.rom:getData()[address + 1] or 0
        end)
        .case(0x1000)
        .case(0x2000)
        .case(0x3000)
        .case(0x4000)
        .case(0x5000)
        .case(0x6000)
        .case(0x7000, function()
            return self.rom:getData()[address + 1] or 0
        end)
        .case(0x8000)
        .case(0x9000, function()
            return self.gpu.vram[address + 1] or 0
        end)
        .case(0xF000, function()
            if (address >= 0xFF80) then
                return self.zram[address] or 0
            elseif (address >= 0xFF40) then
                return 0
            else
                if (bitAnd(address, 0x3F) == 0x00) then
                    return 0
                else
                    return 0
                end
            end
        end)
        .default(function()
            return memoryViolation(address, self.cpu.registers.pc)
        end)()
end

function MMU:readUInt16(address)
    local value = 0

    for i=0, 1 do
        value = value + bitLShift(self:readByte(address + i), 8 * i)
    end

    return bitAnd(value, 0xFFFF)
end

function MMU:readInt16(address)
    local value = self:readUInt16(address)

    if (bitTest(value, 0x8000)) then
        value = -((0xFFFF - value) + 1)
    end

    return bitAnd(value, 0xFFFF)
end
