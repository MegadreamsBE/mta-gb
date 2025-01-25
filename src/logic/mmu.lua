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

local _memoryViolation = function(address, pc)
    Log.error("MMU", "Illegal memory access violation at 0x%s (0x%s).",
        _string_format("%.4x", address),
        _string_format("%.2x", pc))

    return 0
end

local _mbc = {
    rombank = 0,
    rombankHigh = 0,
    rambank = 0,
    ramon = 0,
    mode = 0
}

bios = {}
interrupts = 0x0
interruptFlags = 0x0
stackDebug = {}
cgbDoubleSpeed = false
cgbPrepareSpeedChange = false

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
local _oam = {}

oam = _oam

local _wramBank = 1

for i=1, 0xFFFF do
    _mram[i] = 0
    _zram[i] = 0
    _ram[i] = 0
end

local _cacheAttributes = false

-----------------------------------
-- * Functions
-----------------------------------

function setupMMU()

end

function resetMMU()
    for i=1, 0xFFFF do
        _mram[i] = 0
        _zram[i] = 0
        _ram[i] = 0
    end

    _mbc = {
        rombank = 0,
        rombankHigh = 0,
        rambank = 0,
        ramon = 0,
        mode = 0
    }

    _wram = {
        createFilledTable(0x10000), 
        createFilledTable(0x10000), 
        createFilledTable(0x10000), 
        createFilledTable(0x10000), 
        createFilledTable(0x10000), 
        createFilledTable(0x10000), 
        createFilledTable(0x10000), 
        createFilledTable(0x10000)
    }

    _wramBank = 1

    _romOffset = 0x4000
    _ramOffset = 0x0000

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
        mmuWriteByte(0xFF44, 0x90)
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

    _oam = createFilledTable(0x10000)
    oam = _oam

    mmuLinkVideoRam(vram or {})
end

function mmuLinkVideoRam(vram)
    _vram = vram
end

function mmuLinkCache(cacheAttribute)
    _cacheAttributes = cacheAttribute
end

function mmuLoadRom(rom)
    _rom = rom
    _cartridgeType = _rom[0x0147 + 1]

    print("Cartridge type: "..string.format("%.2x", _cartridgeType))

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

local _statSignal = 0

local _writeByteSwitch = switch()
    .caseRange(0x0, 0x1FFF, function(address, value, onlyWrite)
        if ((_cartridgeType == 2 or _cartridgeType == 3) or (_cartridgeType >= 15 and _cartridgeType <= 19)
            or (_cartridgeType >= 25 and _cartridgeType <= 30)) then
            _mbc.ramon = ((_bitAnd(value, 0x0F) == 0x0A) and 1 or 0)
        end
    end)
    .caseRange(0x2000, 0x3FFF, function(address, value, onlyWrite)
        if (_cartridgeType >= 1 and _cartridgeType <= 3) then
            if (_mbc.mode == 0) then
                _mbc.rombank = _bitOr(_bitAnd(value, 0x1F), _bitLShift(_mbc.rombankHigh, 5))
            else
                _mbc.rombank = _bitAnd(value, 0x1F)
            end

            if (_mbc.rombank == 0x0 or _mbc.rombank == 0x20 or _mbc.rombank == 0x40 or _mbc.rombank == 0x60) then
                _mbc.rombank = _mbc.rombank + 1
            end

            _mbc.rombank = _bitAnd(_mbc.rombank, _romBankCount - 1)
            _romOffset = _mbc.rombank * 0x4000
        elseif (_cartridgeType >= 15 and _cartridgeType <= 19) then
            value = _bitAnd(value, 0x7F)

            if (value == 0) then
                value = 1
            end

            _mbc.rombank = _bitAnd(value, _romBankCount - 1)
            _romOffset = _mbc.rombank * 0x4000
        elseif (_cartridgeType >= 25 and _cartridgeType <= 30) then
            if (address <= 0x2FFF) then
                _mbc.rombank = _bitOr(value, _bitLShift(_mbc.rombankHigh, 8))
            else
                _mbc.rombankHigh = _bitAnd(value, 0x01)
                _mbc.rombank = _bitOr(_bitAnd(_mbc.rombank, 0xFF), _bitLShift(_mbc.rombankHigh, 8))
            end

            _mbc.rombank = _bitAnd(_mbc.rombank, _romBankCount - 1)
            _romOffset = _mbc.rombank * 0x4000
        end
    end)
    .caseRange(0x4000, 0x5FFF, function(address, value, onlyWrite)
        if (_cartridgeType >= 1 and _cartridgeType <= 3) then
            if (_mbc.mode == 1) then
                _mbc.rambank = _bitAnd(value, 0x03)
                _mbc.rambank = _bitAnd(_mbc.rambank, _ramBankCount - 1)
                _ramOffset = _mbc.rambank * 0x2000
            else
                _mbc.rombankHigh = _bitAnd(value, 0x03)
                _mbc.rombank = _bitOr(_bitAnd(_mbc.rombank, 0x1F), _bitLShift(_mbc.rombankHigh, 5))

                _mbc.rombank = _bitAnd(_mbc.rombank, _romBankCount - 1)
                _romOffset = _mbc.rombank * 0x4000
            end
        elseif (_cartridgeType >= 15 and _cartridgeType <= 19) then
            if (value <= 0x03) then
                _mbc.rambank = _bitAnd(value, _ramBankCount - 1)
                _ramOffset = _mbc.rambank * 0x2000
            end
        elseif (_cartridgeType >= 25 and _cartridgeType <= 30) then
            _mbc.rambank = _bitAnd(value, 0x0F)
            _mbc.rambank = _bitAnd(_mbc.rambank, _ramBankCount - 1)
            _ramOffset = _mbc.rambank * 0x2000
        end
    end)
    .caseRange(0x6000, 0x7FFF, function(address, value, onlyWrite)
        if (_cartridgeType == 2 or _cartridgeType == 3) then
            _mbc.mode = _bitAnd(value, 0x01)
        end
    end)
    .caseRange(0x8000, 0x9FFF, function(address, value, onlyWrite)
        if (vramBank == 2) then
            _cacheAttributes[address - 0x7FFF] = {}
        end

        _vram[vramBank][address - 0x7FFF] = value
    end)
    .caseRange(0xA000, 0xBFFF, function(address, value, onlyWrite)
        if (_mbc.ramon == 1) then
            eramUpdated = true

            if (_cartridgeType == 2 or _cartridgeType == 3) then
                if (_mbc.mode == 0) then
                    _eram[(address - 0xA000) + 1] = value
                    return
                end
            end

            _eram[_ramOffset + ((address - 0xA000) + 1)] = value
        end
    end)
    .caseRange(0xC000, 0xEFFF, function(address, value, onlyWrite)
        if (isGameBoyColor) then
            if (address >= 0xC000 and address <= 0xCFFF) then
                _wram[1][address - 0xBFFF] = value
                return
            elseif (address >= 0xD000 and address <= 0xDFFF) then
                _wram[_wramBank + 1][address - 0xBFFF] = value
                return
            end
        end

        _wram[1][address - 0xBFFF] = value
    end)
    .case(0xFF41, function(address, value, onlyWrite)
        if (onlyWrite) then
            _ram[address + 1] = _bitOr(value, 0x80)
            return
        end

        local newStat = _bitOr(_bitAnd(value, 0x78), _bitAnd(_ram[0xFF42], 0x07))

        local lcdc = mmuReadByte(0xFF40)
        local mode = getGPUMode()

        _statSignal = _bitAnd(_bitRShift(newStat, 3), 0x0F)

        if (_bitExtract(lcdc, 7) == 1) then
            if (mode == 0 and _bitExtract(newStat, 3) == 1) then
                if (_statSignal == 0) then
                    requestInterrupt(1)
                end

                _statSignal = _bitReplace(_statSignal, 0, 1)
            elseif (mode == 1 and _bitExtract(newStat, 4) == 1) then
                if (_statSignal == 0) then
                    requestInterrupt(1)
                end

                _statSignal = _bitReplace(_statSignal, 1, 1)
            elseif (mode == 2 and _bitExtract(newStat, 5) == 1) then
                if (_statSignal == 0) then
                    requestInterrupt(1)
                end

                _statSignal = _bitReplace(_statSignal, 2, 1)
            end
        end

        if (isScreenEnabled()) then
            local lyc = mmuReadByte(0xFF45)
 
            if (lyc == getScanLine()) then
                newStat = _bitOr(newStat, 0x04)

                if (_bitExtract(newStat, 6) == 1 and _statSignal == 0) then
                    requestInterrupt(1)
                end

                _statSignal = _bitReplace(_statSignal, 3, 1)
            else
                newStat = _bitAnd(newStat, 0xFB)
                _statSignal = _bitReplace(_statSignal, 3, 0)
            end

            _ram[address + 1] = _bitOr(newStat, 0x80)
        else
            _ram[address + 1] = _bitOr(newStat, 0x80)
        end
    end)
    .case(0xFF4D, function(address, value, onlyWrite)
        if (isGameBoyColor) then
            if (_bitExtract(value, 0, 1) == 1 and _bitExtract(_ram[address + 1] or 0, 0, 1) == 0) then
                cgbPrepareSpeedChange = true
            end
        end

        _ram[0xFF4E] = value
    end)
    .case(0xFF4F, function(address, value, onlyWrite)
        if (isGameBoyColor) then
            value = _bitAnd(value, 0x01)
            vramBank = (value == 1) and 2 or 1
        end

        _ram[0xFF50] = value
    end)
    .case(0xFF51, function(address, value, onlyWrite)
        if (isGameBoyColor) then
            if (value > 0x7f and value < 0xa0) then
                value = 0
            end

            _hdmaSource = _bitOr(_bitAnd(_bitLShift(value, 8), 0xFFFF), _bitAnd(_hdmaSource, 0xF0))
            _hdma[1] = value;
        else
            _ram[address + 1] = value
        end
    end)
    .case(0xFF52, function(address, value, onlyWrite)
        if (isGameBoyColor) then
            value = _bitAnd(value, 0xF0)
            _hdmaSource = _bitOr(_bitAnd(_hdmaSource, 0xFF00), value)
            _hdma[2] = value;
        else
            _ram[address + 1] = value
        end
    end)
    .case(0xFF53, function(address, value, onlyWrite)
        if (isGameBoyColor) then
            value = _bitAnd(value, 0x1F)
            _hdmaDestination = _bitOr(_bitOr(_bitAnd(_bitLShift(value, 8), 0xFFFF), _bitAnd(_hdmaDestination, 0xF0)), 0x8000)
            _hdma[3] = value;
        else
            _ram[address + 1] = value
        end
    end)
    .case(0xFF54, function(address, value, onlyWrite)
        if (isGameBoyColor) then
            value = _bitAnd(value, 0xF0)
            _hdmaDestination = _bitOr(_bitOr(_bitAnd(_hdmaDestination, 0x1F00), value), 0x8000)
            _hdma[4] = value;
        else
            _ram[address + 1] = value
        end
    end)
    .case(0xFF55, function(address, value, onlyWrite)
        if (isGameBoyColor) then
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
    
                        clockM = clockM + clockCycles
                        clockT = clockT + (clockCycles * 4)
                    end
                else
                    mmuPerformGDMA(value)
                end
            end
        else
            _ram[address + 1] = value
        end
    end)
    .case(0xFF68, function(address, value, onlyWrite)
        _ram[address + 1] = value
    
        if (isGameBoyColor and not onlyWrite) then
            updatePaletteSpec(false, value)
        end
    end)
    .case(0xFF69, function(address, value, onlyWrite)
        _ram[address + 1] = value
    
        if (isGameBoyColor and not onlyWrite) then
            setColorPalette(false, value)
        end
    end)
    .case(0xFF6A, function(address, value, onlyWrite)
        _ram[address + 1] = value
    
        if (isGameBoyColor and not onlyWrite) then
            updatePaletteSpec(true, value)
        end
    end)
    .case(0xFF6B, function(address, value, onlyWrite)
        _ram[address + 1] = value
    
        if (isGameBoyColor and not onlyWrite) then
            setColorPalette(true, value)
        end
    end)
    .case(0xFF70, function(address, value, onlyWrite)
        if (isGameBoyColor) then
            _wramBank = _bitAnd(value, 0x07)
    
            if (_wramBank == 0) then
                _wramBank = 1
            end
        end
    
        _ram[address + 1] = value
    end)
    .caseRange(0xF000, 0xFDFF, function(address, value, onlyWrite)
        _ram[address + 1] = value
    end)
    .caseRange(0xFE00, 0xFEFF, function(address, value, onlyWrite)
        _oam[address + 1] = value
    end)
    .case(0xFF00, function(address, value, onlyWrite)
        writeKeypad(value)
    end)
    .case(0xFF01, function(address, value, onlyWrite)
        writeKeypad(value)
    end)
    .case(0xFF02, function(address, value, onlyWrite)
        --print(utf8.char(mmuReadByte(0xFF01)))
        value = 0x00
    end)
    .case(0xFF04, function(address, value, onlyWrite)
        resetTimerDivider()
    end)
    .case(0xFF05, function(address, value, onlyWrite)
        tima = value
    end)
    .case(0xFF06, function(address, value, onlyWrite)
        tma = value
    end)
    .case(0xFF07, function(address, value, onlyWrite)
        local wasClockEnabled = timerClockEnabled

        timerClockEnabled = (_bitExtract(value, 2, 1) == 1)

        local newFrequency = _bitAnd(value, 0x03)
        
        handleTACGlitch(wasClockEnabled, timerClockEnabled, timerClockFrequency, newFrequency)

        if (timerClockFrequency ~= newFrequency) then
            resetTimerClockFrequency(newFrequency)
        end
    end)
    .case(0xFF0F, function(address, value, onlyWrite)
        interruptFlags = value
    end)
    .caseRange(0xFF10, 0xFF3F, function(address, value, onlyWrite)
        _ram[address + 1] = value
    end)
    .case(0xFF40, function(address, value, onlyWrite)
        if (_bitExtract(value, 7, 1) == 1) then
            enableScreen()
        else
            disableScreen()
        end

        if (not isGameBoyColor and _bitExtract(value, 0, 1) == 0) then
            value = _bitAnd(value, 0xDF)
        end

        _ram[0xFF41] = value
    end)
    .case(0xFF44, function(address, value, onlyWrite)
        return
    end)
    .case(0xFF46, function(address, value, onlyWrite)
        local dmaAddress = _bitLShift(value, 8)

        if (dmaAddress >= 0x8000 and dmaAddress < 0xE000) then
            local i = 0

            while (i < 0xA0) do
                mmuWriteByte(0xFE00 + i, mmuReadByte(dmaAddress + i))
                i = i + 1
            end
        end
    end)
    .caseRange(0xFF00, 0xFF7F, function(address, value, onlyWrite)
        _ram[address + 1] = value
    end)
    .caseRange(0xFF80, 0xFFFE, function(address, value, onlyWrite)
        _zram[address + 1] = value
    end)
    .case(0xFFFF, function(address, value, onlyWrite)
        interrupts = value
    end)
    .default(function(address)
        return _memoryViolation(address, lastProgramCounter)
    end)
    .assemble()

local _writeByteSwitchLen = #_writeByteSwitch
    
function mmuWriteByte(address, value, onlyWrite)
    return _writeByteSwitch[address](address, value, onlyWrite or false)
end

function mmuWriteShort(address, value)
    _writeByteSwitch[address](address, _bitAnd(0x00FF, value))
    _writeByteSwitch[address + 1](address + 1, _bitAnd(0xFF00, value) / 256)
end

function mmuPushStack(value)
    stackPointer = stackPointer - 2

    mmuWriteShort(stackPointer, value)

    if (isDebuggerEnabled()) then
        _table_insert(stackDebug, 1, value)
    end
end

function mmuPopStack()
    local value = mmuReadUInt16(stackPointer)

    stackPointer = stackPointer + 2

    if (isDebuggerEnabled()) then
        _table_remove(stackDebug, 1)
    end

    return value
end

function mmuPerformHDMA()
    local source = _bitAnd(_hdmaSource, 0xFFF0)
    local destination = _bitOr(_bitAnd(_hdmaDestination, 0x1FF0), 0x8000)

    local i = 0
    
    while (i < 0x10) do
        mmuWriteByte(destination + i, mmuReadByte(source + i))
        i = i + 1
    end

    _hdmaDestination = _hdmaDestination + 0x10

    if (_hdmaDestination > 0xFFFF) then
        _hdmaDestination = _hdmaDestination - 0x10000
    end

    if (_hdmaDestination == 0xA000) then
        _hdmaDestination = 0x8000
    end

    _hdmaSource = _hdmaSource + 0x10

    if (_hdmaSource > 0xFFFF) then
        _hdmaSource = _hdmaSource - 0x10000
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
        _hdma[5] = _hdma[5] + 0x100
    end
    if (_hdma[5] == 0xFF) then
        hdmaEnabled = false
    end

    return ((cgbDoubleSpeed) and 17 or 9) * 4
end

function mmuPerformGDMA(value)
    local source = _bitAnd(_hdmaSource, 0xFFF0)
    local destination = _bitOr(_bitAnd(_hdmaDestination, 0x1FF0), 0x8000)

    local i = 0

    while (i < _hdmaBytes) do
        mmuWriteByte(destination + i, mmuReadByte(source + i))
        i = i + 1
    end
    
    _hdmaDestination = _hdmaDestination + _hdmaBytes

    if (_hdmaDestination > 0xFFFF) then
        _hdmaDestination = _hdmaDestination - 0x10000
    end

    _hdmaSource = _hdmaSource + _hdmaBytes

    if (_hdmaSource > 0xFFFF) then
        _hdmaSource = _hdmaSource - 0x10000
    end

    for i=1, 5 do
        _hdma[i] = 0xFF
    end
    
    local clockCycles = 0
    
    if (cgbDoubleSpeed) then
        clockCycles = 2 + 16 * (_bitAnd(value, 0x7F) + 1)
    else
        clockCycles = 1 + 8 * (_bitAnd(value, 0x7F) + 1)
    end

    clockM = clockM + clockCycles
    clockT = clockT + (clockCycles * 4)
end

local _readByteSwitch = switch()
    .caseRange(0x0, 0xFFF, function(address)
        if (isBiosLoaded()) then
            if (isGameBoyColor) then
                if (address < 0x900 and (address < 0x100 or address >= 0x200)) then
                    return bios[address + 1] or 0
                end
            else
                if (address < 0x100) then
                    return bios[address + 1] or 0
                end
            end
        end

        return _rom[address + 1] or 0
    end)
    .caseRange(0x1000, 0x3FFF, function(address)
        return _rom[address + 1] or 0
    end)
    .caseRange(0x4000, 0x7FFF, function(address)
        return _rom[_romOffset + ((address - 0x4000) + 1)] or 0
    end)
    .caseRange(0x8000, 0x9FFF, function(address)
        return _vram[vramBank][(address - 0x8000) + 1] or 0
    end)
    .caseRange(0xA000, 0xBFFF, function(address)
        if (_mbc.ramon == 0) then
            return 0xFF
        end

        if (_cartridgeType == 2 or _cartridgeType == 3) then
            if (_mbc.mode == 0) then
                return _eram[(address - 0xA000) + 1] or 0
            end
        end

        return _eram[_ramOffset + ((address - 0xA000) + 1)] or 0
    end)
    .caseRange(0xC000, 0xEFFF, function(address)
        if (isGameBoyColor) then
            if (address >= 0xC000 and address <= 0xCFFF) then
                return _wram[1][address - 0xBFFF] or 0
            elseif (address >= 0xD000 and address <= 0xDFFF) then
                return _wram[_wramBank + 1][address - 0xBFFF] or 0
            end
        end

        return _wram[1][address - 0xBFFF] or 0
    end)
    .case(0xFF4D, function(address)
        return _ram[0xFF4E] or 0
    end)
    .case(0xFF4F, function(address)
        return _bitOr(_ram[0xFF50] or 0, 0xFE)
    end)
    .case(0xFF51, function(_)
        if (isGameBoyColor) then
            return _hdma[1]
        end

        return _ram[0xFF52] or 0
    end)
    .case(0xFF52, function(_)
        if (isGameBoyColor) then
            return _hdma[2]
        end

        return _ram[0xFF53] or 0
    end)
    .case(0xFF53, function(_)
        if (isGameBoyColor) then
            return _hdma[3]
        end

        return _ram[0xFF54] or 0
    end)
    .case(0xFF54, function(_)
        if (isGameBoyColor) then
            return _hdma[4]
        end

        return _ram[0xFF55] or 0
    end)
    .case(0xFF55, function(_)
        if (isGameBoyColor) then
            return _hdma[5]
        end

        return _ram[0xFF56] or 0
    end)
    .case(0xFF70, function(_)
        if (isGameBoyColor) then
            return _bitOr(_ram[0xFF71] or 0, 0xF8)
        end

        return 0xFF
    end)
    .caseRange(0xF000, 0xFDFF, function(address)
        return _ram[address + 1] or 0
    end)
    .caseRange(0xFE00, 0xFE9F, function(address)
        if (getGPUMode() > 2 and isScreenEnabled()) then
            return 0xFF
        end

        return _oam[address + 1] or 0
    end)
    .case(0xFF00, function(_)
        return readKeypad()
    end)
    .caseRange(0xFF01, 0xFF03, function(address)
        return _ram[address + 1]
    end)
    .case(0xFF04, function(_)
        return timerDividerRegister
    end)
    .case(0xFF05, function(_)
        return tima
    end)
    .case(0xFF06, function(_)
        return tma
    end)
    .case(0xFF07, function(address)
        return _ram[address + 1] or 0
    end)
    .caseRange(0xFF08, 0xFF0D, function(address)
        return _ram[address + 1] or 0
    end)
    .case(0xFF0F, function(_)
        return interruptFlags
    end)
    .caseRange(0xFF10, 0xFF40, function(address)
        return _ram[address + 1]
    end)
    .case(0xFF41, function(_)
        return _ram[0xFF42]
    end)
    .caseRange(0xFF42, 0xFF43, function(address)
        return _ram[address + 1]
    end)
    .case(0xFF44, function(_)
        return scanLine
    end)
    .caseRange(0xFF45, 0xFF7F, function(address)
        return _ram[address + 1]
    end)
    .caseRange(0xFF80, 0xFFFE, function(address)
        return _zram[address + 1] or 0
    end)
    .case(0xFFFF, function(_)
        return interrupts
    end)
    .default(function(address)
        if (address <= 0xFFFF) then
            return _ram[address + 1] or 0
        end

        return _memoryViolation(address, lastProgramCounter)
    end)
    .assemble()

local _readByteSwitchLen = #_readByteSwitch

function mmuReadByte(address)
    return _readByteSwitch[address](address)
end

function mmuReadSignedByte(address)
    local value = _readByteSwitch[address](address)

    if (value >= 0x80) then
        value = -((0xFF - value) + 1)
    end

    return value
end

function mmuReadUInt16(address)
    local value = _readByteSwitch[address + 1](address + 1) or 0

    value = (value * 256) + (_readByteSwitch[address](address) or 0)

    return value
end

function mmuReadInt16(address)
    local value = _readByteSwitch[address + 1](address + 1)

    value = (value * 256) + _readByteSwitch[address](address)

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

function saveMMUState()
    return {
        mbc = _mbc,
        interrupts = interrupts,
        interruptFlags = interruptFlags,
        stackDebug = stackDebug,
        hdma = _hdma,
        hdmaSource = _hdmaSource,
        hdmaDestination = _hdmaDestination,
        hdmaBytes = _hdmaBytes,
        hdmaEnabled = hdmaEnabled,
        eramUpdated = eramUpdated,
        eramLastUpdated = eramLastUpdated,
        romOffset = _romOffset,
        ramOffset = _ramOffset,
        cartridgeType = _cartridgeType,
        romBankCount = _romBankCount,
        ramBankCount = _ramBankCount,
        eram = _eram,
        mram = _mram,
        zram = _zram,
        wram = _wram,
        ram = _ram,
        oam = _oam,
        wramBank = _wramBank,
    }
end

function loadMMUState(state)
    _mbc = state.mbc
    interrupts = state.interrupts
    interruptFlags = state.interruptFlags
    stackDebug = state.stackDebug
    _hdma = state.hdma
    _hdmaSource = state.hdmaSource
    _hdmaDestination = state.hdmaDestination
    hdmaBytes = state.hdmaBytes
    hdmaEnabled = state.hdmaEnabled
    eramUpdated = state.eramUpdated
    eramLastUpdated = state.eramLastUpdated
    _romOffset = state.romOffset
    _ramOffset = state.ramOffset
    _cartridgeType = state.cartridgeType
    _romBankCount = state.romBankCount
    _ramBankCount = state.ramBankCount
    _eram = state.eram
    _mram = state.mram
    _zram = state.zram
    _wram = state.wram
    _ram = state.ram
    _wramBank = state.wramBank
    _oam = state.oam

    oam = _oam
end

addEventHandler("onClientResourceStart", resourceRoot,
    function()
        _cacheAttributes = cacheAttributes
    end
)

readByteSwitch = _readByteSwitch
writeByteSwitch = _writeByteSwitch