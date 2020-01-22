MMU = Class()

-----------------------------------
-- * Constants
-----------------------------------

local MEMORY_SIZE = 0xFFFFFF
local BIOS = {
    0x31, 0xFE, 0xFF, 0xAF, 0x21, 0xFF, 0x9F, 0x32, 0xCB, 0x7C, 0x20, 0xFB, 0x21, 0x26, 0xFF, 0x0E,
    0x11, 0x3E, 0x80, 0x32, 0xE2, 0x0C, 0x3E, 0xF3, 0xE2, 0x32, 0x3E, 0x77, 0x77, 0x3E, 0xFC, 0xE0,
    0x47, 0x11, 0x04, 0x01, 0x21, 0x10, 0x80, 0x1A, 0xCD, 0x95, 0x00, 0xCD, 0x96, 0x00, 0x13, 0x7B,
    0xFE, 0x34, 0x20, 0xF3, 0x11, 0xD8, 0x00, 0x06, 0x08, 0x1A, 0x13, 0x22, 0x23, 0x05, 0x20, 0xF9,
    0x3E, 0x19, 0xEA, 0x10, 0x99, 0x21, 0x2F, 0x99, 0x0E, 0x0C, 0x3D, 0x28, 0x08, 0x32, 0x0D, 0x20,
    0xF9, 0x2E, 0x0F, 0x18, 0xF3, 0x67, 0x3E, 0x64, 0x57, 0xE0, 0x42, 0x3E, 0x91, 0xE0, 0x40, 0x04,
    0x1E, 0x02, 0x0E, 0x0C, 0xF0, 0x44, 0xFE, 0x90, 0x20, 0xFA, 0x0D, 0x20, 0xF7, 0x1D, 0x20, 0xF2,
    0x0E, 0x13, 0x24, 0x7C, 0x1E, 0x83, 0xFE, 0x62, 0x28, 0x06, 0x1E, 0xC1, 0xFE, 0x64, 0x20, 0x06,
    0x7B, 0xE2, 0x0C, 0x3E, 0x87, 0xE2, 0xF0, 0x42, 0x90, 0xE0, 0x42, 0x15, 0x20, 0xD2, 0x05, 0x20,
    0x4F, 0x16, 0x20, 0x18, 0xCB, 0x4F, 0x06, 0x04, 0xC5, 0xCB, 0x11, 0x17, 0xC1, 0xCB, 0x11, 0x17,
    0x05, 0x20, 0xF5, 0x22, 0x23, 0x22, 0x23, 0xC9, 0xCE, 0xED, 0x66, 0x66, 0xCC, 0x0D, 0x00, 0x0B,
    0x03, 0x73, 0x00, 0x83, 0x00, 0x0C, 0x00, 0x0D, 0x00, 0x08, 0x11, 0x1F, 0x88, 0x89, 0x00, 0x0E,
    0xDC, 0xCC, 0x6E, 0xE6, 0xDD, 0xDD, 0xD9, 0x99, 0xBB, 0xBB, 0x67, 0x63, 0x6E, 0x0E, 0xEC, 0xCC,
    0xDD, 0xDC, 0x99, 0x9F, 0xBB, 0xB9, 0x33, 0x3E, 0x3C, 0x42, 0xB9, 0xA5, 0xB9, 0xA5, 0x42, 0x3C,
    0x21, 0x04, 0x01, 0x11, 0xA8, 0x00, 0x1A, 0x13, 0xBE, 0x20, 0xFE, 0x23, 0x7D, 0xFE, 0x34, 0x20,
    0xF5, 0x06, 0x19, 0x78, 0x86, 0x23, 0x05, 0x20, 0xFB, 0x86, 0x20, 0xFE, 0x3E, 0x01, 0xE0, 0x50
}

MMU.MEMORY_SIZE = MEMORY_SIZE
MMU.BIOS = BIOS

-----------------------------------
-- * Locals
-----------------------------------

local _bitAnd = bitAnd
local _bitRShift = bitRShift
local _bitTest = bitTest
local _string_format = string.format

local memoryViolation = function(address, pc)
    Log.error("MMU", "Illegal memory access violation at 0x%s (0x%s).",
        _string_format("%.4x", address),
        _string_format("%.2x", pc))

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
    self.ram = {}
    self.rom = nil

    for i=1, 0xF000 do
        self.mram[i] = 0
        self.zram[i] = 0
        self.ram[i] = 0
    end

    self.inBios = true
    self.stackDebug = {}
end

function MMU:reset()

end

function MMU:loadRom(rom)
    self.rom = rom:getData()
end

function MMU:writeByte(address, value)
    if (address == 0xFF02 and value == 0x81) then
        outputDebugString(utf8.char(self:readByte(0xFF01)))
    end

    if ((address >= 0x1000 and address < 0x2000) or
        (address >= 0x2000 and address < 0x3000) or
        (address >= 0x3000 and address < 0x4000) or
        (address >= 0x4000 and address < 0x5000) or
        (address >= 0x5000 and address < 0x6000) or
        (address >= 0x6000 and address < 0x7000) or
        (address >= 0x7000 and address < 0x8000)) then
        self.rom[address + 1] = value
    elseif ((address >= 0x8000 and address < 0x9000) or
        (address >= 0x9000 and address < 0xA000)) then
        address = address - 0x8000
        self.gpu.vram[address + 1] = value
    elseif ((address >= 0xC000 and address < 0xD000) or
        (address >= 0xD000 and address < 0xF000)) then
        address = address - 0xC000
        self.ram[address + 1] = value
    elseif (address >= 0xF000) then
        if (address >= 0xFF80) then
            address = address - 0xFF80
            self.zram[address + 1] = value
        elseif (address >= 0xFF40) then
            address = address - 0x8000
            self.gpu.vram[address + 1] = value
        else
            return
        end
    else
        return memoryViolation(address, self.cpu.registers.pc)
    end
end

function MMU:writeShort(address, value)
    if ((address >= 0x1000 and address < 0x2000) or
        (address >= 0x2000 and address < 0x3000) or
        (address >= 0x3000 and address < 0x4000) or
        (address >= 0x4000 and address < 0x5000) or
        (address >= 0x5000 and address < 0x6000) or
        (address >= 0x6000 and address < 0x7000) or
        (address >= 0x7000 and address < 0x8000)) then
        self.rom[address + 2] = _bitRShift(_bitAnd(0xFF00, value), 8)
        self.rom[address + 1] = _bitAnd(0x00FF, value)
    elseif ((address >= 0x8000 and address < 0x9000) or
        (address >= 0x9000 and address < 0xA000)) then
        address = address - 0x8000
        self.gpu.vram[address + 2] = _bitRShift(_bitAnd(0xFF00, value), 8)
        self.gpu.vram[address + 1] = _bitAnd(0x00FF, value)
    elseif ((address >= 0xC000 and address < 0xD000) or
        (address >= 0xD000 and address < 0xF000)) then
        address = address - 0xC000
        self.ram[address + 2] = _bitRShift(_bitAnd(0xFF00, value), 8)
        self.ram[address + 1] = _bitAnd(0x00FF, value)
    elseif (address >= 0xF000) then
        if (address >= 0xFF80) then
            address = address - 0xFF80
            self.zram[address + 2] = _bitRShift(_bitAnd(0xFF00, value), 8)
            self.zram[address + 1] = _bitAnd(0x00FF, value)
        elseif (address >= 0xFF40) then
            address = address - 0x8000
            self.gpu.vram[address + 2] = _bitRShift(_bitAnd(0xFF00, value), 8)
            self.gpu.vram[address + 1] = _bitAnd(0x00FF, value)
        else
            return
        end
    else
        return memoryViolation(address, self.cpu.registers.pc)
    end
end

function MMU:pushStack(value)
    self.cpu.registers.sp = self.cpu.registers.sp - 2
    self:writeShort(self.cpu.registers.sp, value)
    --table.insert(self.stackDebug, 1, value)
end

function MMU:popStack()
    local value = self:readInt16(self.cpu.registers.sp)
    self.cpu.registers.sp = self.cpu.registers.sp + 2
    --table.remove(self.stackDebug, 1)

    return value
end

function MMU:readByte(address)
    if (address >= 0x0 and address < 0x1000) then
        if (self.inBios) then
            if (address < 0x100) then
                return BIOS[address + 1] or 0
            elseif (self.cpu.registers.pc == 0x100) then
                self.inBios = false
            end
        end

        return self.rom[address + 1] or 0
    elseif ((address >= 0x1000 and address < 0x2000) or
        (address >= 0x2000 and address < 0x3000) or
        (address >= 0x3000 and address < 0x4000) or
        (address >= 0x4000 and address < 0x5000) or
        (address >= 0x5000 and address < 0x6000) or
        (address >= 0x6000 and address < 0x7000) or
        (address >= 0x7000 and address < 0x8000)) then
        return self.rom[address + 1] or 0
    elseif ((address >= 0x8000 and address < 0x9000) or
        (address >= 0x9000 and address < 0xA000)) then
        address = address - 0x8000
        return self.gpu.vram[address + 1] or 0
    elseif ((address >= 0xC000 and address < 0xD000) or
        (address >= 0xD000 and address < 0xF000)) then
        address = address - 0xC000
        return self.ram[address + 1] or 0
    elseif (address >= 0xF000) then
        if (address >= 0xFF80) then
            address = address - 0xFF80
            return self.zram[address + 1] or 0
        elseif (address >= 0xFF40) then
            address = address - 0x8000
            return self.gpu.vram[address + 1] or 0
        else
            if (_bitAnd(address, 0x3F) == 0x00) then
                return 0
            else
                return 0
            end
        end
    else
        return memoryViolation(address, self.cpu.registers.pc)
    end
end

function MMU:readUInt16(address)
    local value = 0

    value = self:readByte(address + 1)

    value = value * 0xFF + value
    value = value + self:readByte(address)

    return value
end

function MMU:readInt16(address)
    local value = self:readUInt16(address)

    if (value >= 0x8000) then
        value = -((0xFFFF - value) + 1)
    end

    return value
end
