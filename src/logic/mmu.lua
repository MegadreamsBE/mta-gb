MMU = Class()

-----------------------------------
-- * Constants
-----------------------------------

local MEMORY_SIZE = 0xFFFFFF

MMU.MEMORY_SIZE = MEMORY_SIZE
MMU.BIOS = {}

-----------------------------------
-- * Locals
-----------------------------------

local _bitAnd = bitAnd
local _bitTest = bitTest
local _bitExtract = bitExtract
local _bitReplace = bitReplace
local _bitLShift = bitLShift
local _string_format = string.format
local _table_insert = table.insert
local _table_remove = table.remove
local _math_floor = math.floor

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

    self.mbc = {
        {},
        {
            rombank = 0,
            rambank = 0,
            ramon = 0,
            mode = 0
        }
    }

    self.interrupts = 0x0
    self.interruptFlags = 0x0

    self.romOffset = 0x4000
    self.ramOffset = 0x0000
    self.cartridgeType = 0

    self.eram = {}
    self.mram = {}
    self.zram = {}
    self.ram = {}
    self.rom = nil

    for i=1, 0xF000 do
        self.eram[i] = 0
        self.mram[i] = 0
        self.zram[i] = 0
        self.ram[i] = 0
    end

    self.inBios = true
    self.stackDebug = {}
end

function MMU:reset()
    self.mbc = {
        {},
        {
            rombank = 0,
            rambank = 0,
            ramon = 0,
            mode = 0
        }
    }

    self.romOffset = 0x4000
    self.ramOffset = 0x0000

    self:writeByte(0xFF00, 0xFF)
    self:writeByte(0xFF04, 0x0)
    self:writeByte(0xFF05, 0x0)
    self:writeByte(0xFF06, 0x0)
    self:writeByte(0xFF07, 0x0)
    self:writeByte(0xFF40, 0x91)
    self:writeByte(0xFF42, 0x0)
    self:writeByte(0xFF43, 0x0)
    self:writeByte(0xFF44, 0x0)
    self:writeByte(0xFF45, 0x0)
    self:writeByte(0xFF47, 0xFC)
    self:writeByte(0xFF48, 0xFF)
    self:writeByte(0xFF49, 0xFF)
    self:writeByte(0xFF4A, 0x0)
    self:writeByte(0xFF4B, 0x0)
end

function MMU:loadRom(rom)
    self.rom = rom:getData()
    self.cartridgeType = self.rom[0x0147 + 1]
end

function MMU:writeByte(address, value)
    if (address >= 0x0000 and address < 0x2000) then
        if (self.cartridgeType == 2 or self.cartridgeType == 3) then
            self.mbc[2].ramon = (_bitAnd(value, 0x0F) == 0x0A)
        end
    elseif (address >= 0x2000 and address < 0x4000) then
        if (self.cartridgeType >= 1 and self.cartridgeType <= 3) then
            value = _bitAnd(value, 0x1F)

            if (value == 0) then
                value = 1
            end

            self.mbc[2].rombank = _bitAnd(self.mbc[2].rombank, 0x60) + value
            self.romOffset = self.mbc[2].rombank * 0x4000
        end
    elseif (address >= 0x4000 and address < 0x6000) then
        if (self.cartridgeType >= 1 and self.cartridgeType <= 3) then
            if (self.mbc[2].mode == 1) then
                self.mbc[2].rambank = _bitAnd(value, 0x03)
                self.ramOffset = self.mbc[2].rambank * 0x2000
            else
                self.mbc[2].rombank = _bitAnd(self.mbc[2].rombank, 0x1F)
                    + _bitLShift(_bitAnd(value, 0x03), 5)

                self.romOffset = self.mbc[2].rombank * 0x4000
            end
        end
    elseif (address >= 0x6000 and address < 0x8000) then
        if (self.cartridgeType == 2 or self.cartridgeType == 3) then
            self.mbc[2].mode = _bitAnd(value, 0x01)
        end
    elseif (address >= 0x8000 and address < 0xA000) then
        address = address - 0x8000
        self.gpu.vram[address + 1] = value
    elseif (address >= 0xA000 and address < 0xC000) then
        self.eram[self.ramOffset + (address - 0xA000)] = value
    elseif (address >= 0xC000 and address < 0xF000) then
        address = address - 0xC000
        self.ram[address + 1] = value
    elseif (address >= 0xF000) then
        local innerAddress = _bitAnd(address, 0x0F00)

        if (innerAddress >= 0x0 and innerAddress <= 0xD00) then
            self.ram[_bitAnd(address, 0x1FFF) + 1] = value
        elseif (innerAddress == 0xE00) then
            if (_bitAnd(address, 0xFF) < 0xA0) then
                address = address - 0xFE00
                self.gpu.oam[address + 1] = value
            end
        elseif (innerAddress == 0xF00) then
            if (address == 0xFFFF) then
                self.interrupts = value
            elseif (address > 0xFF7F) then
                self.zram[_bitAnd(address, 0x7F) + 1] = value
            else
                local case = _bitAnd(address, 0xF0)

                if (case == 0x0) then
                    local internalCase = _bitAnd(address, 0xF)

                    if (internalCase == 0) then
                        self.cpu.gameboy:writeKeypad(value)
                    elseif (internalCase == 2) then
                        outputDebugString("SERIAL ("..string.format("%.4x", self.cpu.registers.pc):upper()..") ("..self:readByte(0xFF01).."): "..utf8.char(self:readByte(0xFF01)))
                        value = 0x00
                    elseif (internalCase >= 4 and internalCase <= 7) then
                        return 0
                    elseif (internalCase == 15) then
                        self.interruptFlags = value
                    else
                        self.ram[address + 1] = value
                    end
                elseif (case == 0x10 or case == 0x20 or case == 0x30) then
                    return 0
                elseif (case == 0x40 or case == 0x50 or case == 0x60 or case == 0x70) then
                    if (address == 0xFF40) then
                        if (_bitExtract(value, 7, 1) == 1) then
                            self.gpu:enableScreen()
                        else
                            self.gpu:disableScreen()
                        end
                    elseif (address == 0xFF46) then
                        local dmaAddress = _bitLShift(value, 8)

                        if (dmaAddress >= 0x8000 and dmaAddress < 0xE000) then
                            for i=1, 0xA0 do
                                self:writeByte(0xFE00 + (i - 1), self:readByte(dmaAddress + (i - 1)))
                            end
                        end
                    end

                    address = address - 0x8000
                    self.gpu.vram[address + 1] = value
                end
            end
        end
    else
        return memoryViolation(address, self.cpu.registers.pc)
    end
end

function MMU:writeShort(address, value)
    self:writeByte(address, _bitAnd(0x00FF, value))
    self:writeByte(address + 1, _math_floor(_bitAnd(0xFF00, value) / 256))
end

function MMU:pushStack(value)
    self.cpu.registers.sp = self.cpu.registers.sp - 2
    self:writeShort(self.cpu.registers.sp, value)
    _table_insert(self.stackDebug, 1, value)
end

function MMU:popStack()
    local value = self:readUInt16(self.cpu.registers.sp)
    self.cpu.registers.sp = self.cpu.registers.sp + 2
    _table_remove(self.stackDebug, 1)

    return value
end

function MMU:readByte(address)
    if (address >= 0x0 and address < 0x1000) then
        if (self.inBios) then
            if (address < 0x100) then
                return self.BIOS[address + 1] or 0
            elseif (self.cpu.registers.pc == 0x100) then
                self.inBios = false
            end
        end

        return self.rom[address + 1] or 0
    elseif (address >= 0x1000 and address < 0x4000) then
        return self.rom[address + 1] or 0
    elseif (address >= 0x4000 and address < 0x8000) then
        --return self.rom[self.romOffset + (_bitAnd(address, 0x333F) + 1)] or 0
        return self.rom[address + 1] or 0
    elseif (address >= 0x8000 and address < 0xA000) then
        address = address - 0x8000
        return self.gpu.vram[address + 1] or 0
    elseif (address >= 0xA000 and address < 0xC000) then
        return self.eram[(self.ramOffset + (_bitAnd(address, 0x333F) + 1))
             - 0xA000] or 0
    elseif (address >= 0xC000 and address < 0xF000) then
        address = address - 0xC000
        return self.ram[address + 1] or 0
    elseif (address >= 0xF000) then
        local innerAddress = _bitAnd(address, 0x0F00)

        if (innerAddress >= 0x0 and innerAddress <= 0xD00) then
            return self.ram[_bitAnd(address, 0x1FFF) + 1] or 0
        elseif (innerAddress == 0xE00) then
            if (_bitAnd(address, 0x0FF) < 0xA0) then 
                address = address - 0xFE00
                return self.gpu.oam[address + 1] or 0
            end
            
            return 0
        elseif (innerAddress == 0xF00) then
            if (address == 0xFFFF) then
                return self.interrupts
            elseif (address > 0xFF7F) then
                return self.zram[_bitAnd(address, 0x7F) + 1]
            else
                local case = _bitAnd(address, 0xF0)

                if (case == 0x0) then
                    local internalCase = _bitAnd(address, 0xF)

                    if (internalCase == 0) then
                        return self.cpu.gameboy:readKeypad()
                    elseif (internalCase >= 4 and internalCase <= 7) then
                        return 0
                    elseif (internalCase == 15) then
                        return self.interruptFlags
                    else
                        return self.ram[address + 1] or 0
                    end
                elseif (case == 0x10 or case == 0x20 or case == 0x30) then
                    return 0
                elseif (case == 0x40 or case == 0x50 or case == 0x60 or case == 0x70) then
                    address = address - 0x8000
                    return self.gpu.vram[address + 1] or 0
                end
            end
        end
    else
        return memoryViolation(address, self.cpu.registers.pc)
    end
end

function MMU:readSignedByte(address)
    local value = self:readByte(address)

    if (value >= 0x80) then
        value = -((0xFF - value) + 1)
    end

    return value
end

function MMU:readUInt16(address)
    local value = self:readByte(address + 1)

    value = value * 256
    value = value + self:readByte(address)

    return value
end

function MMU:readInt16(address)
    local value = self:readByte(address + 1)

    value = value * 256
    value = value + self:readByte(address)

    if (value >= 0x8000) then
        value = -((0xFFFF - value) + 1)
    end

    return value
end
