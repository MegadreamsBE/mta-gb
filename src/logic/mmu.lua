MMU = {}
MMU.__index = MMU

-----------------------------------
-- * Constants
-----------------------------------

local MEMORY_SIZE = 0xFFFFFF

MMU_MEMORY_SIZE = MEMORY_SIZE

-----------------------------------
-- * Locals
-----------------------------------

local _bitAnd = bitAnd
local _bitOr = bitOr
local _bitTest = bitTest
local _bitExtract = bitExtract
local _bitReplace = bitReplace
local _bitLShift = bitLShift
local _bitRShift = bitRShift
local _string_format = string.format
local _table_insert = table.insert
local _table_remove = table.remove
local _math_floor = math.floor

local _memoryViolation = function(address, pc)
    Log.error("MMU", "Illegal memory access violation at 0x%s (0x%s).",
        _string_format("%.4x", address),
        _string_format("%.2x", pc))

    return 0
end

local _mbc = {
    {},
    {
        rombank = 0,
        rambank = 0,
        ramon = 0,
        mode = 0
    }
}

bios = {}
interrupts = 0x0
interruptFlags = 0x0
stackDebug = {}

local _hdma = {}
local _hdmaSource = 0x0
local _hdmaDestination = 0x0
local _hdmaBytes = 0x0

hdmaEnabled = false

eramUpdated = false
eramLastUpdated = -1

local _romOffset = 0x4000
local _ramOffset = 0x0000
local _cartridgeType = 0
local _romBankCount = 0
local _ramBankCount = 0

local _vram = {}
local _eram = {}
local _mram = {}
local _zram = {}
local _wram = {}
local _ram = {}
local _rom = nil

local _wramBank = 1

for i=1, 0xF000 do
    _mram[i] = 0
    _zram[i] = 0
    _ram[i] = 0
end

local _inBios = true

-----------------------------------
-- * Functions
-----------------------------------

function setupMMU()

end

function resetMMU()
    _mbc = {
        createFilledTable(0xFFFF),
        {
            rombank = 0,
            rambank = 0,
            ramon = 0,
            mode = 0
        }
    }

    _wram = {
        createFilledTable(0xFFFF), 
        createFilledTable(0xFFFF), 
        createFilledTable(0xFFFF), 
        createFilledTable(0xFFFF), 
        createFilledTable(0xFFFF), 
        createFilledTable(0xFFFF), 
        createFilledTable(0xFFFF), 
        createFilledTable(0xFFFF)
    }

    _wramBank = 1

    _romOffset = 0x4000
    _ramOffset = 0x0000

    _inBios = isBiosLoaded()

    if (not isBiosLoaded()) then
        mmuWriteByte(0xFF00, 0xFF)
        mmuWriteByte(0xFF05, 0x00)
        mmuWriteByte(0xFF06, 0x00)
        mmuWriteByte(0xFF07, 0x00)
        mmuWriteByte(0xFF10, 0x80)
        mmuWriteByte(0xFF11, 0xBF)
        mmuWriteByte(0xFF12, 0xF3)
        mmuWriteByte(0xFF14, 0xBF)
        mmuWriteByte(0xFF16, 0x3F)
        mmuWriteByte(0xFF17, 0x00)
        mmuWriteByte(0xFF19, 0xBF)
        mmuWriteByte(0xFF1A, 0x7F)
        mmuWriteByte(0xFF1B, 0xFF)
        mmuWriteByte(0xFF1C, 0x9F)
        mmuWriteByte(0xFF1E, 0xBF)
        mmuWriteByte(0xFF20, 0xFF)
        mmuWriteByte(0xFF21, 0x00)
        mmuWriteByte(0xFF22, 0x00)
        mmuWriteByte(0xFF23, 0xBF)
        mmuWriteByte(0xFF24, 0x77)
        mmuWriteByte(0xFF25, 0xF3)
        mmuWriteByte(0xFF26, 0xF1)
        mmuWriteByte(0xFF40, 0x91)
        mmuWriteByte(0xFF42, 0x00)
        mmuWriteByte(0xFF43, 0x00)
        mmuWriteByte(0xFF45, 0x00)
        mmuWriteByte(0xFF47, 0xFC)
        mmuWriteByte(0xFF48, 0xFF)
        mmuWriteByte(0xFF49, 0xFF)
        mmuWriteByte(0xFF4A, 0x00)
        mmuWriteByte(0xFF4B, 0x00)
        mmuWriteByte(0xFFFF, 0x00)
    end

    for i=1, 5 do
        _hdma[i] = 0
    end

    mmuLinkVideoRam(vram or {})
end

function mmuLinkVideoRam(vram)
    _vram = vram
end

function mmuLoadRom(rom)
    _rom = rom
    _cartridgeType = _rom[0x0147 + 1]
    
    local romSize = _rom[0x0148 + 1]

    if (romSize == 0x01) then
        _romBankCount = 4
    elseif (romSize == 0x02) then
        _romBankCount = 8
    elseif (romSize == 0x03) then
        _romBankCount = 16
    elseif (romSize == 0x04) then
        _romBankCount = 32
    elseif (romSize == 0x05) then
        _romBankCount = 64
    elseif (romSize == 0x06) then
        _romBankCount = 128
    elseif (romSize == 0x07) then
        _romBankCount = 256
    elseif (romSize == 0x08) then
        _romBankCount = 512
    else
        _romBankCount = 2
    end

    local ramSize = _rom[0x0149 + 1]


    if (ramSize == 0x01) then
        _ramBankCount = 0
    elseif (ramSize == 0x02) then
        _ramBankCount = 1
    elseif (ramSize == 0x03) then
        _ramBankCount = 4
    elseif (ramSize == 0x04) then
        _ramBankCount = 16
    elseif (ramSize == 0x05) then
        _ramBankCount = 8
    else
        _ramBankCount = 0
    end
end

function mmuWriteByte(address, value, onlyWrite)
    onlyWrite = onlyWrite or false

    if (address >= 0x0000 and address < 0x2000) then
        if ((_cartridgeType == 2 or _cartridgeType == 3) or (_cartridgeType >= 15 and _cartridgeType <= 19)
            or (_cartridgeType >= 25 and _cartridgeType <= 30)) then
            _mbc[2].ramon = ((_bitAnd(value, 0x0F) == 0x0A) and 1 or 0)
        end
    elseif (address >= 0x2000 and address < 0x4000) then
        if (_cartridgeType >= 1 and _cartridgeType <= 3) then
            value = _bitAnd(value, 0x1F)

            if (value == 0) then
                value = 1
            end

            _mbc[2].rombank = _bitAnd(_mbc[2].rombank, 0x60) + value
            _romOffset = _mbc[2].rombank * 0x4000
        elseif (_cartridgeType >= 15 and _cartridgeType <= 19) then
            value = _bitAnd(value, 0x7F)

            if (value == 0) then
                value = 1
            end

            _mbc[2].rombank = value
            _mbc[2].rombank = _bitAnd(_mbc[2].rombank, _romBankCount - 1)
            _romOffset = _mbc[2].rombank * 0x4000
        elseif (_cartridgeType >= 25 and _cartridgeType <= 30) then
            local romBankValue = _mbc[2].rombank

            if (address <= 0x2FFF) then
                romBankValue = _bitOr(value, _bitAnd(romBankValue, 0x100))
            else
                local shiftValue = _bitAnd(value, 0x01)
                
                if (shiftValue > 0) then
                    shiftValue = _bitLShift(shiftValue, 8)
                end

                romBankValue = _bitOr(_bitAnd(romBankValue, 0xFF), shiftValue)
            end

            _mbc[2].rombank = romBankValue
            _mbc[2].rombank = _bitAnd(_mbc[2].rombank, _romBankCount - 1)
            _romOffset = _mbc[2].rombank * 0x4000
        end
    elseif (address >= 0x4000 and address < 0x6000) then
        if (_cartridgeType >= 1 and _cartridgeType <= 3) then
            if (_mbc[2].mode == 1) then
                _mbc[2].rambank = _bitAnd(value, 0x03)
                _ramOffset = _mbc[2].rambank * 0x2000
            else
                _mbc[2].rombank = _bitAnd(_mbc[2].rombank, 0x1F)
                    + (_bitLShift(_bitAnd(value, 0x03), 5) % 0x10000)

                _romOffset = _mbc[2].rombank * 0x4000
            end
        elseif (_cartridgeType >= 15 and _cartridgeType <= 19) then
            if (value <= 0x03) then
                _mbc[2].rambank = value
                _mbc[2].rambank = _bitAnd(_mbc[2].rambank, _ramBankCount - 1)
                _ramOffset = _mbc[2].rambank * 0x2000
            end
        elseif (_cartridgeType >= 25 and _cartridgeType <= 30) then
            _mbc[2].rambank = _bitAnd(value, 0x0F)
            _mbc[2].rambank = _bitAnd(_mbc[2].rambank, _ramBankCount - 1)
            _ramOffset = _mbc[2].rambank * 0x2000
        end
    elseif (address >= 0x6000 and address < 0x8000) then
        if (_cartridgeType == 2 or _cartridgeType == 3) then
            _mbc[2].mode = _bitAnd(value, 0x01)
        end
    elseif (address >= 0x8000 and address < 0xA000) then
        _vram[vramBank][(address - 0x8000) + 1] = value
    elseif (address >= 0xA000 and address < 0xC000) then
        if (_mbc[2].ramon) then
            eramUpdated = true
            _eram[_ramOffset + (address - 0xA000) + 1] = value
        end
    elseif (address >= 0xC000 and address < 0xF000) then
        if (isGameBoyColor()) then
            if (address >= 0xC000 and address <= 0xCFFF) then
                address = address - 0xC000
                _wram[1][address + 1] = value
                return
            elseif (address >= 0xD000 and address <= 0xDFFF) then
                address = address - 0xC000
                _wram[_wramBank + 1][address + 1] = value
                return
            end
        end

        address = address - 0xC000
        _wram[1][address + 1] = value
    elseif (address == 0xFF4F) then
        if (isGameBoyColor()) then
            value = _bitAnd(value, 0x01)
            vramBank = (value == 1) and 2 or 1
        end

        _ram[address + 1] = value
    elseif (address == 0xFF51) then
        if (isGameBoyColor()) then
            if (value > 0x7f and value < 0xa0) then
                value = 0
            end

            _hdmaSource = _bitOr(_bitAnd(_bitLShift(value, 8), 0xFFFF), _bitAnd(_hdmaSource, 0xF0))
            _hdma[1] = value;
        else
            _ram[address + 1] = value
        end
    elseif (address == 0xFF52) then
        if (isGameBoyColor()) then
            value = _bitAnd(value, 0xF0)
            _hdmaSource = _bitOr(_bitAnd(_hdmaSource, 0xFF00), value)
            _hdma[2] = value;
        else
            _ram[address + 1] = value
        end
    elseif (address == 0xFF53) then
        if (isGameBoyColor()) then
            value = _bitAnd(value, 0x1F)
            _hdmaDestination = _bitOr(_bitOr(_bitAnd(_bitLShift(value, 8), 0xFFFF), _bitAnd(_hdmaDestination, 0xF0)), 0x8000)
            _hdma[3] = value;
        else
            _ram[address + 1] = value
        end
    elseif (address == 0xFF54) then
        if (isGameBoyColor()) then
            value = _bitAnd(value, 0xF0)
            _hdmaDestination = _bitOr(_bitOr(_bitAnd(_hdmaDestination, 0x1F00), value), 0x8000)
            _hdma[4] = value;
        else
            _ram[address + 1] = value
        end
    elseif (address == 0xFF55) then
        if (isGameBoyColor()) then
            _hdmaBytes = 16 + (_bitAnd(value, 0x7F) * 16)

            if (hdmaEnabled) then
                if (_bitExtract(value, 7, 1) == 1) then
                    _hdma[5] = _bitAnd(value, 0x7F)
                else
                    _hdma[5] = 0xFF
                    hdmaEnabled = false
                end
            else
                if (_bitExtract(value, 7, 1) == 1) then
                    hdmaEnabled = true
                    _hdma[5] = _bitAnd(value, 0x7F)

                    if (getGPUMode() == 0) then
                        local clockCycles = mmuPerformHDMA()

                        registers.clock.m = registers.clock.m + clockCycles
                        registers.clock.t = registers.clock.t + (clockCycles * 4)
                    end
                else
                    mmuPerformGDMA(value)
                end
            end
        else
            _ram[address + 1] = value
        end
    elseif (address == 0xFF68) then
        _ram[address + 1] = value

        if (isGameBoyColor()) then
            if (not onlyWrite) then
                updatePaletteSpec(false, value)
            end
        end
    elseif (address == 0xFF69) then
        _ram[address + 1] = value

        if (isGameBoyColor()) then
            if (not onlyWrite) then
                setColorPalette(false, value)
            end
        end
    elseif (address == 0xFF6A) then
        _ram[address + 1] = value

        if (isGameBoyColor()) then
            if (not onlyWrite) then
                updatePaletteSpec(true, value)
            end
        end
    elseif (address == 0xFF6B) then
        _ram[address + 1] = value

        if (isGameBoyColor()) then
            if (not onlyWrite) then
                setColorPalette(true, value)
            end
        end
    elseif (address == 0xFF70) then
        if (isGameBoyColor()) then
            value = _bitAnd(value, 0x07)
            _wramBank = value

            if (_wramBank == 0) then
                _wramBank = 1
            end
        end

        _ram[address + 1] = value
    elseif (address >= 0xF000) then
        local innerAddress = _bitAnd(address, 0x0F00)

        if (innerAddress >= 0x0 and innerAddress <= 0xD00) then
            _ram[address + 1] = value
        elseif (innerAddress == 0xE00) then
            if (_bitAnd(address, 0xFF) < 0xA0) then
                address = address - 0xFE00
                oam[address + 1] = value
            end
        elseif (innerAddress == 0xF00) then
            if (address == 0xFFFF) then
                interrupts = value
            elseif (address > 0xFF7F) then
                _zram[address + 1] = value
            else
                local case = _bitAnd(address, 0xF0)

                if (case == 0x0) then
                    local internalCase = _bitAnd(address, 0xF)

                    if (internalCase == 0) then
                        writeKeypad(value)
                    elseif (internalCase == 2) then
                        --print(utf8.char(mmuReadByte(0xFF01)))
                        value = 0x00
                    elseif (internalCase == 4) then
                        resetTimerDivider()
                    elseif (internalCase > 4 and internalCase < 7) then
                        _ram[address + 1] = value
                    elseif (internalCase == 7) then
                        _ram[address + 1] = value

                        local wasClockEnabled = timerClockEnabled

                        timerClockEnabled = (_bitExtract(value, 2, 1) == 1)

                        local newFrequency = _bitAnd(value, 0x03)
                        
                        handleTACGlitch(wasClockEnabled, timerClockEnabled, timerClockFrequency, newFrequency)

                        if (timerClockFrequency ~= newFrequency) then
                            resetTimerClockFrequency(newFrequency)
                        end
                    elseif (internalCase == 15) then
                        interruptFlags = value
                    else
                        _ram[address + 1] = value
                    end
                elseif (case == 0x10 or case == 0x20 or case == 0x30) then
                    return 0
                elseif (case == 0x40 or case == 0x50 or case == 0x60 or case == 0x70) then
                    if (address == 0xFF40) then
                        if (_bitExtract(value, 7, 1) == 1) then
                            enableScreen()
                        else
                            disableScreen()
                        end
                    elseif (address == 0xFF44) then
                        return
                    elseif (address == 0xFF46) then
                        local dmaAddress = _bitLShift(value, 8)

                        if (dmaAddress >= 0x8000 and dmaAddress < 0xE000) then
                            for i=1, 0xA0 do
                                mmuWriteByte(0xFE00 + (i - 1), mmuReadByte(dmaAddress + (i - 1)))
                            end
                        end
                    end

                    _ram[address + 1] = value
                end
            end
        end
    else
        return _memoryViolation(address, registers.lastPC)
    end
end

function mmuWriteShort(address, value)
    mmuWriteByte(address, _bitAnd(0x00FF, value))
    mmuWriteByte(address + 1, _math_floor(_bitAnd(0xFF00, value) / 256))
end

function mmuPushStack(value)
    registers.sp = registers.sp - 2
    mmuWriteShort(registers.sp, value)
    _table_insert(stackDebug, 1, value)
end

function mmuPopStack()
    local value = mmuReadUInt16(registers.sp)
    registers.sp = registers.sp + 2
    _table_remove(stackDebug, 1)

    return value
end

function mmuPerformHDMA()
    local source = _bitAnd(_hdmaSource, 0xFFF0)
    local destination = _bitOr(_bitAnd(_hdmaDestination, 0x1FF0), 0x8000)

    for i=1, 0x10 do
        mmuWriteByte(destination + (i - 1), mmuReadByte(source + (i - 1)))
    end

    _hdmaDestination = _hdmaDestination + 0x10

    if (_hdmaDestination > 0xFFFF) then
        _hdmaDestination = _hdmaDestination - 0xFFFF
    end

    if (_hdmaDestination == 0xA000) then
        _hdmaDestination = 0x8000
    end

    _hdmaSource = _hdmaSource + 0x10

    if (_hdmaSource > 0xFFFF) then
        _hdmaSource = _hdmaSource - 0xFFFF
    end

    if (_hdmaSource == 0x8000) then
        _hdmaSource = 0xA000
    end

    _hdma[2] = _bitAnd(_hdmaSource, 0xFF)
    _hdma[1] = _bitRShift(_hdmaSource, 8)

    _hdma[4] = _bitAnd(_hdmaDestination, 0xFF)
    _hdma[3] = _bitRShift(_hdmaDestination, 8)

    _hdmaBytes = _hdmaBytes - 0x10
    _hdma[5] = _hdma[5] - 1

    if (_hdma[5] < 0) then
        _hdma[5] = _hdma[5] + 0xFF
    end

    if (_hdma[5] == 0xFF) then
        hdmaEnabled = false
    end

    --@TODO: support CGB double speed
    return 9
end

function mmuPerformGDMA(value)
    local source = _bitAnd(_hdmaSource, 0xFFF0)
    local destination = _bitOr(_bitAnd(_hdmaDestination, 0x1FF0), 0x8000)

    for i=1, _hdmaBytes do
        mmuWriteByte(destination + (i - 1), mmuReadByte(source + (i - 1)))
    end

    _hdmaDestination = _hdmaDestination + _hdmaBytes

    if (_hdmaDestination > 0xFFFF) then
        _hdmaDestination = _hdmaDestination - 0xFFFF
    end

    _hdmaSource = _hdmaSource + _hdmaBytes

    if (_hdmaSource > 0xFFFF) then
        _hdmaSource = _hdmaSource - 0xFFFF
    end

    for i=1, 5 do
        _hdma[i] = 0xFF
    end

    --@TODO: add double speed support
    local clockCycles = 1 + 8 * (_bitAnd(value, 0x7F) + 1)

    registers.clock.m = registers.clock.m + clockCycles
    registers.clock.t = registers.clock.t + (clockCycles * 4)
end

function mmuReadByte(address)
    if (address >= 0x0 and address < 0x1000) then
        if (_inBios) then
            if (isGameBoyColor()) then
                if (address < 0x900 and (address < 0x100 or address >= 0x200)) then
                    return bios[address + 1] or 0
                elseif (registers.pc == 0x100) then
                    _inBios = false
                end
            else
                if (address < 0x100) then
                    return bios[address + 1] or 0
                elseif (registers.pc == 0x100) then
                    _inBios = false
                end
            end
        end

        return _rom[address + 1] or 0
    elseif (address >= 0x1000 and address < 0x4000) then
        return _rom[address + 1] or 0
    elseif (address >= 0x4000 and address < 0x8000) then
        return _rom[_romOffset + ((address - 0x4000) + 1)] or 0
    elseif (address >= 0x8000 and address < 0xA000) then
        return _vram[vramBank][(address - 0x8000) + 1] or 0
    elseif (address >= 0xA000 and address < 0xC000) then
        return _eram[_ramOffset + (address - 0xA000) + 1] or 0
    elseif (address >= 0xC000 and address < 0xF000) then
        if (isGameBoyColor()) then
            if (address >= 0xC000 and address <= 0xCFFF) then
                address = address - 0xC000
                return _wram[1][address + 1] or 0
            elseif (address >= 0xD000 and address <= 0xDFFF) then
                address = address - 0xC000
                return _wram[_wramBank + 1][address + 1] or 0
            end
        end

        address = address - 0xC000
        return _wram[1][address + 1] or 0
    elseif (address == 0xFF4F) then
        return _bitOr(_ram[address + 1] or 0, 0xFE)
    elseif (address == 0xFF51) then
        if (isGameBoyColor()) then
            return _hdma[1]
        end

        return _ram[address + 1] or 0
    elseif (address == 0xFF52) then
        if (isGameBoyColor()) then
            return _hdma[2]
        end

        return _ram[address + 1] or 0
    elseif (address == 0xFF53) then
        if (isGameBoyColor()) then
            return _hdma[3]
        end

        return _ram[address + 1] or 0
    elseif (address == 0xFF54) then
        if (isGameBoyColor()) then
            return _hdma[4]
        end

        return _ram[address + 1] or 0
    elseif (address == 0xFF55) then
        if (isGameBoyColor()) then
            return _hdma[5]
        end

        return _ram[address + 1] or 0
    elseif (address == 0xFF70) then
        if (isGameBoyColor()) then
            return _bitOr(_ram[address + 1] or 0, 0xF8)
        end

        return 0xFF
    elseif (address >= 0xF000) then
        local innerAddress = _bitAnd(address, 0x0F00)

        if (innerAddress >= 0x0 and innerAddress <= 0xD00) then
            return _ram[address + 1] or 0
        elseif (innerAddress == 0xE00) then
            if (_bitAnd(address, 0x0FF) < 0xA0) then 
                address = address - 0xFE00
                return oam[address + 1] or 0
            end
            
            return 0
        elseif (innerAddress == 0xF00) then
            if (address == 0xFFFF) then
                return interrupts
            elseif (address > 0xFF7F) then
                return _zram[address + 1] or 0
            else
                local case = _bitAnd(address, 0xF0)

                if (case == 0x0) then
                    local internalCase = _bitAnd(address, 0xF)

                    if (internalCase == 0) then
                        return readKeypad()
                    elseif (internalCase == 4) then
                        return timerDividerRegister
                    elseif (internalCase >= 4 and internalCase <= 7) then
                        return _ram[address + 1] or 0
                    elseif (internalCase == 15) then
                        return interruptFlags
                    else
                        return _ram[address + 1] or 0
                    end
                elseif (case == 0x10 or case == 0x20 or case == 0x30) then
                    return _ram[address + 1] or 0
                elseif (case == 0x40 or case == 0x50 or case == 0x60 or case == 0x70) then
                    if (address == 0xFF44) then
                        return scanLine
                    end

                    local value = _ram[address + 1] or 0

                    if (address == 0xFF41) then
                        value = _bitOr(value, 0x80)
                    end

                    return value
                end
            end
        end
    else
        return _memoryViolation(address, registers.lastPC)
    end
end

function mmuReadSignedByte(address)
    local value = mmuReadByte(address)

    if (value >= 0x80) then
        value = -((0xFF - value) + 1)
    end

    return value
end

function mmuReadUInt16(address)
    local value = mmuReadByte(address + 1) or 0

    value = value * 256
    value = value + (mmuReadByte(address) or 0)

    return value
end

function mmuReadInt16(address)
    local value = mmuReadByte(address + 1)

    value = value * 256
    value = value + mmuReadByte(address)

    if (value >= 0x8000) then
        value = -((0xFFFF - value) + 1)
    end

    return value
end

function mmuSaveExternalRam()
    local savePath = getRomPath():match("(.+)%..+$")..".sav"

    if (fileExists(savePath)) then
        fileDelete(savePath)
    end

    local saveFile = fileCreate(savePath)

    if (saveFile) then
        local ramBanks = 4

        for i=1, 0x2000 * ramBanks do
            local value = _eram[i] or 0

            if (value < 0) then
                value = -value
            end

            fileWrite(saveFile, string.char(value))
        end

        fileClose(saveFile)
    end

    eramUpdated = false
    eramLastUpdated = getTickCount()
end

function mmuLoadExternalRam()
    local savePath = getRomPath():match("(.+)%..+$")..".sav"

    if (fileExists(savePath)) then
        local saveFile = fileOpen(savePath, true)

        if (saveFile) then
            local ramBanks = 4
            local fileData = fileRead(saveFile, 0x2000 * ramBanks)

            if (fileData) then
                for i=1, 0x2000 * ramBanks do
                    _eram[i] = string.byte(fileData:sub(i, i) or 0)
                end
            end

            fileClose(saveFile)
        end
    end
end

function mmuIsInBios()
    return _inBios
end