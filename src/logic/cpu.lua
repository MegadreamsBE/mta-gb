-----------------------------------
-- * Locals
-----------------------------------

local LOG_TWO = math.log(2)

local _math_abs = math.abs
local _math_log = math.log
local _math_floor = math.floor
local _bitOr = bitOr
local _bitAnd = bitAnd
local _bitXor = bitXor
local _bitNot = bitNot
local _bitExtract = bitExtract
local _bitReplace = bitReplace
local _bitLShift = bitLShift

local _string_format = string.format

local _readTwoRegisters = false
local _writeTwoRegisters = false

local _readByteSwitch = false
local _writeByteSwitch = false
local _mmuReadByte = false
local _mmuWriteByte = false
local _mmuReadUInt16 = false
local _mmuReadSignedByte = false
local _mmuPushStack = false
local _mmuPopStack = false

local _opcodes = false

local _bitAnd = bitAnd
local _bitReplace = bitReplace

local _getTickCount = getTickCount

local _clock = {
    m = 0,
    t = 0
}

local _paused = false
local _pausedUntilInterrupts = false
local _interrupts = false
local _triggerHaltBug = false

local _queuedEnableInterrupts = false
local _queuedDisableInterrupts = false
local _queueChangeActive = false
local _stepCallback = nil

local _interruptDelay = 0

local _mmuPushStack = false
local _mmuReadByte = false
local _readByteSwitch = false
local _writeByteSwitch = false

local _gpuStep = false
local _timerStep = false

local _handleInterrupts = false
local _rom = {}

-----------------------------------
-- * Functions
-----------------------------------

register1 = 0
register2 = 0
register3 = 0
register4 = 0
register5 = 0
register6 = 0
register7 = 0

flagZero = false
flagSubstract = false
flagHalfCarry = false
flagCarry = false

lastProgramCounter = 0
programCounter = 0

stackPointer = 0xfffe

clockT = 0
clockM = 0

registers = {
    0x0, -- register a
    0x0, -- register b
    0x0, -- register c
    0x0, -- register d
    0x0, -- register e
    0x0, -- register h
    0x0, -- register l
    { -- register f
        -- FLAG_ZERO, FLAG_SUBSTRACT, FLAG_HALFCARRY, FLAG_CARRY
        false, false, false, false
    },
    0x0, -- last pc
    0x0, -- pc
    0xfffe, -- sp
    { -- clock
        0, -- m
        0 -- t
    }
}

local _registers = registers

function setupCPU()
    _clock = {
        m = 0,
        t = 0
    }

    registers = {
        0x0, -- register a
        0x0, -- register b
        0x0, -- register c
        0x0, -- register d
        0x0, -- register e
        0x0, -- register h
        0x0, -- register l
        { -- register f
            -- FLAG_ZERO, FLAG_SUBSTRACT, FLAG_HALFCARRY, FLAG_CARRY
            false, false, false, false
        },
        0x0, -- last pc
        0x0, -- pc
        0xfffe, -- sp
        { -- clock
            0, -- m
            0 -- t
        }
    }

    register1 = 0
    register2 = 0
    register3 = 0
    register4 = 0
    register5 = 0
    register6 = 0
    register7 = 0

    flagZero = false
    flagSubstract = false
    flagHalfCarry = false
    flagCarry = false

    stackPointer = 0xfffe

    lastProgramCounter = 0
    programCounter = 0

    clockT = 0
    clockM = 0

    _registers = registers

    setupMMU()
end

function cpuLoadRom(romData)
    _rom = romData
    mmuLoadRom(romData)
end

function resetCPU()
    resetGPU()
    resetMMU()

    _interrupts = true
    _queuedEnableInterrupts = false
    _queuedDisableInterrupts = false
    _interruptDelay = 0

    -- If we have a BIOS we want to ensure all registers are zeroed out.
    if (isBiosLoaded()) then
        registers = {
            0x0, -- register a
            0x0, -- register b
            0x0, -- register c
            0x0, -- register d
            0x0, -- register e
            0x0, -- register h
            0x0, -- register l
            { -- register f
                -- FLAG_ZERO, FLAG_SUBSTRACT, FLAG_HALFCARRY, FLAG_CARRY
                false, false, false, false
            },
            0x0, -- last pc
            0x0, -- pc
            0xfffe, -- sp
            { -- clock
                0, -- m
                0 -- t
            }
        }

        register1 = 0
        register2 = 0
        register3 = 0
        register4 = 0
        register5 = 0
        register6 = 0
        register7 = 0

        flagZero = false
        flagSubstract = false
        flagHalfCarry = false
        flagCarry = false

        stackPointer = 0xfffe

        lastProgramCounter = 0
        programCounter = 0

        clockT = 0
        clockM = 0
    else
        if (isGameBoyColor) then
            registers = {
                0x11, -- register a
                0x0, -- register b
                0x0, -- register c
                0xff, -- register d
                0x56, -- register e
                0x0, -- register h
                0xd, -- register l
                { -- register f
                    -- FLAG_ZERO, FLAG_SUBSTRACT, FLAG_HALFCARRY, FLAG_CARRY
                    false, false, false, false
                },
                0x0, -- last pc
                0x100, -- pc
                0xfffe, -- sp
                { -- clock
                    0, -- m
                    0 -- t
                }
            }

            register1 = 0x11
            register2 = 0
            register3 = 0
            register4 = 0xff
            register5 = 0x56
            register6 = 0
            register7 = 0xd

            flagZero = false
            flagSubstract = false
            flagHalfCarry = false
            flagCarry = false

            stackPointer = 0xfffe

            lastProgramCounter = 0
            programCounter = 0x100

            clockT = 0
            clockM = 0
        else
            registers = {
                0x01, -- register a
                0x0, -- register b
                0x13, -- register c
                0x0, -- register d
                0xd8, -- register e
                0x01, -- register h
                0x4d, -- register l
                { -- register f
                    -- FLAG_ZERO, FLAG_SUBSTRACT, FLAG_HALFCARRY, FLAG_CARRY
                    false, false, false, false
                },
                0x0, -- last pc
                0x100, -- pc
                0xfffe, -- sp
                { -- clock
                    0, -- m
                    0 -- t
                }
            }

            register1 = 0x01
            register2 = 0
            register3 = 0x13
            register4 = 0
            register5 = 0xd8
            register6 = 0x01
            register7 = 0x4d

            flagZero = false
            flagSubstract = false
            flagHalfCarry = false
            flagCarry = false

            stackPointer = 0xfffe

            lastProgramCounter = 0
            programCounter = 0x100

            clockT = 0
            clockM = 0
        end
    end

    _registers = registers

    if (_stepCallback) then
        removeEventHandler("onClientPreRender", root, _stepCallback)
        _stepCallback = nil
    end

    triggerEvent("gb:cpu:reset", root)
end

function pauseCPU()
    _paused = true
end

function resumeCPU()
    if (not _pausedUntilInterrupts) then
        _paused = false
    end
end

function isCPUPaused()
    return _paused
end

function stopCPU()
    if (cgbPrepareSpeedChange) then
        cgbDoubleSpeed = not cgbDoubleSpeed
        
        _writeByteSwitch[0xFF4D](0xFF4D, _bitReplace(_bitReplace(_readByteSwitch[0xFF4D](0xFF4D), cgbDoubleSpeed and 1 or 0, 7, 1), 0, 0, 1))
    end
end

function haltCPU()
    if (not _interrupts) then
        _interruptDelay = 0

        if (interruptFlags ~= 0) then
            _paused = true
            _pausedUntilInterrupts = true

            _handleInterrupts()
            
            _paused = false
            _pausedUntilInterrupts = false
            _triggerHaltBug = true
        else
            _paused = true
            _pausedUntilInterrupts = true
        end
    else
        _paused = true
        _pausedUntilInterrupts = true
    end
end

function enableInterrupts()
    _queuedEnableInterrupts = true
    _queuedDisableInterrupts = false
end

function disableInterrupts()
    _queuedDisableInterrupts = true
    _queuedEnableInterrupts = false
end

function resetInterrupts()
    _interrupts = false
end

function setInterrupts()
    _interrupts = true
end

function readTwoRegisters(r1, r2)
    local register1Value = 0
    local register2Value = 0

    if r1 == 1 then
        register1Value = register1
    elseif r1 == 2 then
        register1Value = register2
    elseif r1 == 3 then
        register1Value = register3
    elseif r1 == 4 then
        register1Value = register4
    elseif r1 == 5 then
        register1Value = register5
    elseif r1 == 6 then
        register1Value = register6
    elseif r1 == 7 then
        register1Value = register7
    end

    if (r2 == 8) then
        return register1Value * 256 + (
            ((flagZero) and 128 or 0) +
            ((flagSubstract) and 64 or 0) +
            ((flagHalfCarry) and 32 or 0) +
            ((flagCarry) and 16 or 0)
        )
    end

    if r2 == 1 then
        register2Value = register1
    elseif r2 == 2 then
        register2Value = register2
    elseif r2 == 3 then
        register2Value = register3
    elseif r2 == 4 then
        register2Value = register4
    elseif r2 == 5 then
        register2Value = register5
    elseif r2 == 6 then
        register2Value = register6
    elseif r2 == 7 then
        register2Value = register7
    end

    return register1Value * 256 + register2Value
end

function writeTwoRegisters(r1, r2, value)
    local register1Value = 0
    local register2Value = 0

    if r1 == 1 then
        register1Value = register1
    elseif r1 == 2 then
        register1Value = register2
    elseif r1 == 3 then
        register1Value = register3
    elseif r1 == 4 then
        register1Value = register4
    elseif r1 == 5 then
        register1Value = register5
    elseif r1 == 6 then
        register1Value = register6
    elseif r1 == 7 then
        register1Value = register7
    end

    register1Value = _bitAnd(0xFF00, value) / 256

    if (r1 == 1) then
        register1 = register1Value
    elseif (r1 == 2) then
        register2 = register1Value
    elseif (r1 == 3) then
        register3 = register1Value
    elseif (r1 == 4) then
        register4 = register1Value
    elseif (r1 == 5) then
        register5 = register1Value
    elseif (r1 == 6) then
        register6 = register1Value
    elseif (r1 == 7) then
        register7 = register1Value
    end

    if (r2 == 8) then
        flagZero = (_bitAnd(value, 0x80) > 0)
        flagSubstract = (_bitAnd(value, 0x40) > 0)
        flagHalfCarry = (_bitAnd(value, 0x20) > 0)
        flagCarry = (_bitAnd(value, 0x10) > 0)
    else
        if r2 == 1 then
            register2Value = register1
        elseif r2 == 2 then
            register2Value = register2
        elseif r2 == 3 then
            register2Value = register3
        elseif r2 == 4 then
            register2Value = register4
        elseif r2 == 5 then
            register2Value = register5
        elseif r2 == 6 then
            register2Value = register6
        elseif r2 == 7 then
            register2Value = register7
        end

        register2Value = _bitAnd(0x00FF, value)

        if (r2 == 1) then
            register1 = register2Value
        elseif (r2 == 2) then
            register2 = register2Value
        elseif (r2 == 3) then
            register3 = register2Value
        elseif (r2 == 4) then
            register4 = register2Value
        elseif (r2 == 5) then
            register5 = register2Value
        elseif (r2 == 6) then
            register6 = register2Value
        elseif (r2 == 7) then
            register7 = register2Value
        end
    end
end

function requestInterrupt(interrupt)
    --print("Interrupt: "..interrupt)
    --print("Before: "..interruptFlags)
    interruptFlags = _bitReplace(interruptFlags, 1, interrupt, 1)
    _interruptDelay = 4
    --print("After: "..interruptFlags)
end

function hasIncomingInterrupt()
    return (_bitAnd(_bitAnd(interruptFlags, interrupts), 0x1F) ~= 0)
end

function handleInterrupts()
    local maskedFlags = _bitAnd(interrupts, interruptFlags)

    if (((_interrupts or _pausedUntilInterrupts) and maskedFlags ~= 0 and _interruptDelay <= 0)) then
        if (_bitAnd(maskedFlags, 0x01) ~= 0) then
            if (_interrupts) then
                interruptFlags = _bitAnd(interruptFlags, 0xFE)

                _mmuPushStack(programCounter)

                programCounter = 0x40

                clockM = 5
                clockT = 20
            end

            _interrupts = false
        elseif (_bitAnd(maskedFlags, 0x02) ~= 0) then
            if (_interrupts) then
                interruptFlags = _bitAnd(interruptFlags, 0xFD)

                if (isScreenEnabled()) then
                    _mmuPushStack(programCounter)

                    programCounter = 0x48

                    clockM = 5
                    clockT = 20
                end
            end

            _interrupts = false
        elseif (_bitAnd(maskedFlags, 0x04) ~= 0) then
            if (_interrupts) then
                interruptFlags = _bitAnd(interruptFlags, 0xFB)

                _mmuPushStack(programCounter)

                programCounter = 0x50

                clockM = 5
                clockT = 20
            end

            _interrupts = false
        elseif (_bitAnd(maskedFlags, 0x08) ~= 0) then
            if (_interrupts) then
                interruptFlags = _bitAnd(interruptFlags, 0xF7)

                _mmuPushStack(programCounter)

                programCounter = 0x58

                clockM = 5
                clockT = 20
            end

            _interrupts = false
        elseif (_bitAnd(maskedFlags, 0x16) ~= 0) then
            if (_interrupts) then
                interruptFlags = _bitAnd(interruptFlags, 0xEF)

                _mmuPushStack(programCounter)

                programCounter = 0x60

                clockM = 5
                clockT = 20
            end

            _interrupts = false
        end

        _interruptDelay = 0

        if (_pausedUntilInterrupts) then
            _pausedUntilInterrupts = false
            _paused = false
        end
    elseif (_interruptDelay > 0) then
        _interruptDelay = _interruptDelay - clockT
    end
end

local currentCycles = 0
local nextOpcode = 0

function runCPU()
    if (_stepCallback) then
        removeEventHandler("onClientPreRender", root, _stepCallback)
        _stepCallback = nil
    end

    local gameBoyColor = isGameBoyColor
    local biosLoaded = isBiosLoaded()

    local parsedBios = {}
    local parsedRom = {}

    for i = 1, #_rom do
        parsedRom[i] = _opcodes[_rom[i] + 1]
    end

    if (biosLoaded) then
        for i = 1, #bios do
            parsedBios[i] = _opcodes[bios[i] + 1]
        end
    end

    local cyclesToRun = 69905

    _stepCallback = function(delta)
        local debuggerEnabled = isDebuggerEnabled()

        if (not _paused or _pausedUntilInterrupts) then
            currentCycles = 0
            cyclesToRun = 69905

            if (cgbDoubleSpeed) then
                cyclesToRun = cyclesToRun * 2
            end

            while(currentCycles < cyclesToRun) do
                if (_paused and not _pausedUntilInterrupts) then
                    break
                end

                if (_queuedEnableInterrupts and _queueChangeActive) then
                    _queuedEnableInterrupts = false
                    _queuedDisableInterrupts = false
                    _queueChangeActive = false
                    _interrupts = true
                end

                if (_queuedDisableInterrupts and _queueChangeActive) then
                    _queuedEnableInterrupts = false
                    _queuedDisableInterrupts = false
                    _queueChangeActive = false
                    _interrupts = false
                end

                if ((_queuedEnableInterrupts or _queuedDisableInterrupts) and not _queueChangeActive) then
                    _queueChangeActive = true
                end

                if (not _paused and (not debuggerEnabled or debuggerStep())) then
                    local pc = programCounter + 1
                    
                    lastProgramCounter = pc - 1
                
                    clockM = 0
                    clockT = 0
                    programCounter = pc
                
                    if (pc < 0x1000) then
                        if (biosLoaded) then
                            if (gameBoyColor) then
                                if (pc < 0x900 and (pc < 0x100 or pc >= 0x200)) then
                                    parsedBios[pc]()
                                elseif (pc >= 0x100 and pc < 0x200) then
                                    bios = nil
                                    biosLoaded = false
                                end
                            else
                                if (pc < 0x100) then
                                    parsedBios[pc]()
                                elseif (pc >= 0x100) then
                                    bios = nil
                                    biosLoaded = false
                                end
                            end
                        else
                            parsedRom[pc]()
                        end
                    else
                        _opcodes[_mmuReadByte(pc - 1) + 1]()
                    end
                
                    _clock.m = _clock.m + clockM
                    _clock.t = _clock.t + clockT
                end

                if (_triggerHaltBug and not _paused) then
                    _triggerHaltBug = false
                    programCounter = programCounter - 1
                end

                local ticks = clockT


                if (_paused) then
                    _timerStep(4)
                    _gpuStep(1)
                else
                    _timerStep(ticks)

                    if (cgbDoubleSpeed) then
                        _gpuStep(clockM / 2)
                    else
                        _gpuStep(clockM)
                    end
                end

                _handleInterrupts()

                currentCycles = currentCycles + ticks
            end
        end

        if (eramUpdated and (_getTickCount() - eramLastUpdated) > 1000) then
            mmuSaveExternalRam()
        end
    end

    addEventHandler("onClientPreRender", root, _stepCallback)
end

function getCPUClock()
    return _clock
end

function getInterrupts()
    return interrupts
end

function getInterruptFlags()
    return interruptFlags
end

function saveCPUState()
    return {
        clock = _clock,
        paused = _paused,
        pausedUntilInterrupts = _pausedUntilInterrupts,
        interrupts = _interrupts,
        triggerHaltBug = _triggerHaltBug,
        queuedEnableInterrupts = _queuedEnableInterrupts,
        queuedDisableInterrupts = _queuedDisableInterrupts,
        queueChangeActive = _queueChangeActive,
        interruptDelay = _interruptDelay,
        register1 = register1,
        register2 = register2,
        register3 = register3,
        register4 = register4,
        register5 = register5,
        register6 = register6,
        register7 = register7,
        flagZero = flagZero,
        flagSubstract = flagSubstract,
        flagHalfCarry = flagHalfCarry,
        flagCarry = flagCarry,
        lastProgramCounter = lastProgramCounter,
        programCounter = programCounter,
        stackPointer = stackPointer,
        clockT = clockT,
        clockM = clockM
    }
end

function loadCPUState(state)
    _clock = state.clock
    _paused = state.paused
    _pausedUntilInterrupts = state.pausedUntilInterrupts
    _interrupts = state.interrupts
    _triggerHaltBug = state.triggerHaltBug
    _queuedEnableInterrupts = state.queuedEnableInterrupts
    _queuedDisableInterrupts = state.queuedDisableInterrupts
    _queueChangeActive = state.queueChangeActive
    _interruptDelay = state.interruptDelay
    register1 = state.register1
    register2 = state.register2
    register3 = state.register3
    register4 = state.register4
    register5 = state.register5
    register6 = state.register6
    register7 = state.register7
    flagZero = state.flagZero
    flagSubstract = state.flagSubstract
    flagHalfCarry = state.flagHalfCarry
    flagCarry = state.flagCarry
    lastProgramCounter = state.lastProgramCounter
    programCounter = state.programCounter
    stackPointer = state.stackPointer
    clockT = state.clockT
    clockM = state.clockM
    
    clock = _clock

    triggerEvent("gb:cpu:reset", root)
end

local helper_inc = function(value)
    flagHalfCarry = (_bitAnd(value, 0x0f) == 0x0f) -- FLAG_HALFCARRY

    value = (value + 1) % 0x100

    flagZero = (value == 0) and true or false -- FLAG_ZERO
    flagSubstract = false -- FLAG_SUBSTRACT

    return value
end

local helper_inc16 = function(value)
    return (value + 1) % 0x10000
end

local helper_dec = function(value)
    flagHalfCarry = (_bitAnd(value, 0x0f) == 0x00) -- FLAG_HALFCARRY

    value = (value - 1) % 0x100

    flagZero = (value == 0) and true or false -- FLAG_ZERO
    flagSubstract = true -- FLAG_SUBSTRACT

    return value
end

local helper_dec16 = function(value)
    return (value - 1) % 0x10000
end

local helper_add = function(value, add)
    result = (value + add) % 0x100

    flagHalfCarry = (_bitAnd(_bitXor(_bitXor(value, add), result), 0x10) == 0x10) -- FLAG_HALFCARRY
    flagCarry = (value + add > 0xFF)  -- FLAG_CARRY

    flagZero = (result == 0) and true or false -- FLAG_ZERO
    flagSubstract = false -- FLAG_SUBSTRACT

    return result
end

local helper_adc = function(value, add)
    local carry = flagCarry and 1 or 0

    result = (value + add + carry) % 0x100

    flagHalfCarry = (_bitAnd(_bitXor(_bitXor(value, add), result), 0x10) == 0x10) -- FLAG_HALFCARRY
    flagCarry = (value + add + carry > 0xFF) -- FLAG_CARRY

    flagZero = (result == 0) and true or false -- FLAG_ZERO
    flagSubstract = false -- FLAG_SUBSTRACT

    return result
end

local helper_add_sp = function(value, add)
    result = (value + add) % 0x10000

    flagHalfCarry = (_bitAnd(_bitXor(_bitXor(value, add), result), 0x10) == 0x10) -- FLAG_HALFCARRY
    flagCarry = (_bitAnd(_bitXor(_bitXor(value, add), result), 0x100) == 0x100) -- FLAG_CARRY

    flagZero = false -- FLAG_ZERO
    flagSubstract = false -- FLAG_SUBSTRACT

    return result
end

local helper_add16 = function(value, add)
    result = (value + add) % 0x10000

    flagHalfCarry = (_bitAnd(_bitXor(_bitXor(value, add), result), 0x1000) == 0x1000) -- FLAG_HALFCARRY
    flagCarry = (value + add > 0xFFFF) -- FLAG_CARRY

    --flagZero = (result == 0) and true or false -- FLAG_ZERO
    flagSubstract = false -- FLAG_SUBSTRACT

    return result
end

local helper_sub = function(value, sub)
    result = value - sub

    flagHalfCarry = (_bitAnd(_bitXor(_bitXor(value, sub), result), 0x10) ~= 0) -- FLAG_HALFCARRY
    flagCarry = (_bitAnd(_bitXor(_bitXor(value, sub), result), 0x100) ~= 0) -- FLAG_CARRY

    result = result % 0x100

    flagZero = (result == 0) and true or false -- FLAG_ZERO
    flagSubstract = true -- FLAG_SUBSTRACT

    return result
end

local helper_sbc = function(value, sub)
    local carry = flagCarry and 1 or 0
    result = value - sub - carry

    flagHalfCarry = ((_bitAnd(value, 0x0F) - _bitAnd(sub, 0x0F) - carry) < 0) -- FLAG_HALFCARRY
    flagCarry = (result < 0) -- FLAG_CARRY

    result = result % 0x100

    flagZero = (result == 0) and true or false -- FLAG_ZERO
    flagSubstract = true -- FLAG_SUBSTRACT

    return result
end

local helper_and = function(value1, value2)
    local value = _bitAnd(value1, value2)

    flagZero = (value == 0) and true or false -- FLAG_ZERO
    flagSubstract = false -- FLAG_SUBSTRACT
    flagHalfCarry = true -- FLAG_HALFCARRY
    flagCarry = false -- FLAG_CARRY

    return value
end

local helper_or = function(value1, value2)
    local value = _bitOr(value1, value2)

    flagZero = (value == 0) and true or false -- FLAG_ZERO
    flagSubstract = false -- FLAG_SUBSTRACT
    flagHalfCarry = false -- FLAG_HALFCARRY
    flagCarry = false -- FLAG_CARRY

    return value
end

local helper_xor = function(value1, value2)
    local value = _bitXor(value1, value2)

    flagZero = (value == 0) and true or false -- FLAG_ZERO
    flagSubstract = false -- FLAG_SUBSTRACT
    flagHalfCarry = false -- FLAG_HALFCARRY
    flagCarry = false -- FLAG_CARRY

    return value
end

local helper_rl = function(value)
    local carry = flagCarry and 1 or 0

    flagCarry = (_bitAnd(value, 0x80) ~= 0) -- FLAG_CARRY

    local result = _bitOr(_bitAnd(_bitReplace(value * 2, 0, 0, 1), 0xFF), carry)

    flagZero = (result == 0) and true or false -- FLAG_ZERO
    flagSubstract = false -- FLAG_SUBSTRACT
    flagHalfCarry = false -- FLAG_HALFCARRY

    return result
end

local helper_rlc = function(value)
    flagCarry = (_bitAnd(value, 0x80) ~= 0) -- FLAG_CARRY

    local result = _bitAnd(_bitReplace(value * 2, ((value / (2 ^ 7)) % 2 >= 1) and 1 or 0, 0, 1), 0xFF)

    flagZero = (result == 0) and true or false -- FLAG_ZERO
    flagSubstract = false -- FLAG_SUBSTRACT
    flagHalfCarry = false -- FLAG_HALFCARRY

    return result
end

local helper_rr = function(value)
    local carry = flagCarry and 0x80 or 0

    flagCarry = (_bitAnd(value, 0x01) ~= 0) -- FLAG_CARRY

    local result = _bitOr(_bitAnd(_bitReplace((value / 2) - ((value / 2) % 1), 0, 7, 1), 0xFF), carry)

    flagZero = (result == 0) and true or false -- FLAG_ZERO
    flagSubstract = false -- FLAG_SUBSTRACT
    flagHalfCarry = false -- FLAG_HALFCARRY

    return result
end

local helper_rrc = function(value)
    flagCarry = (_bitAnd(value, 0x01) ~= 0) -- FLAG_CARRY

    local result = _bitAnd(_bitReplace((value / 2) - ((value / 2) % 1), ((value / (2 ^ 0)) % 2 >= 1) and 1 or 0, 7, 1), 0xFF)

    flagZero = (result == 0) and true or false -- FLAG_ZERO
    flagSubstract = false -- FLAG_SUBSTRACT
    flagHalfCarry = false -- FLAG_HALFCARRY

    return result
end

local helper_sla = function(value)
    flagCarry = (_bitAnd(value, 0x80) ~= 0) -- FLAG_CARRY

    local result = _bitAnd(_bitReplace(value * 2, 0, 0, 1), 0xFF)

    flagZero = (result == 0) and true or false -- FLAG_ZERO
    flagSubstract = false -- FLAG_SUBSTRACT
    flagHalfCarry = false -- FLAG_HALFCARRY

    return result
end

local helper_sra = function(value)
    flagCarry = (_bitAnd(value, 0x01) ~= 0) -- FLAG_CARRY

    local result = _bitAnd(_bitReplace((value / 2) - ((value / 2) % 1), 0, 7, 1), 0xFF)

    if ((_bitAnd(value, 0x80) ~= 0)) then
        result = _bitOr(result, 0x80)
    end

    flagZero = (result == 0) and true or false -- FLAG_ZERO
    flagSubstract = false -- FLAG_SUBSTRACT
    flagHalfCarry = false -- FLAG_HALFCARRY

    return result
end

local helper_srl = function(value)
    flagCarry = (_bitAnd(value, 0x01) ~= 0) -- FLAG_CARRY

    local result = _bitAnd(_bitReplace((value / 2) - ((value / 2) % 1), 0, 7, 1), 0xFF)

    flagZero = (result == 0) and true or false -- FLAG_ZERO
    flagSubstract = false -- FLAG_SUBSTRACT
    flagHalfCarry = false -- FLAG_HALFCARRY

    return result
end

local helper_cp = function(value, cmp)
    flagZero = (value == cmp) and true or false -- FLAG_ZERO
    flagSubstract = true -- FLAG_SUBSTRACT
    flagHalfCarry = (_bitAnd(_math_abs(cmp), 0x0f) > (_bitAnd(value, 0x0f))) -- FLAG_HALFCARRY
    flagCarry = (value < cmp) and true or false -- FLAG_CARRY
end

local helper_swap = function(value)
    local upperNibble = _bitAnd(value, 0xF0) / 16
    local lowerNibble = _bitAnd(value, 0x0F)

    value = (lowerNibble * 16) + upperNibble

    flagZero = (value == 0) -- FLAG_ZERO
    flagSubstract = false -- FLAG_SUBSTRACT
    flagHalfCarry = false -- FLAG_HALFCARRY
    flagCarry = false -- FLAG_CARRY

    return value
end

local helper_not = function(value)
    value = _bitNot(value)

    if (value > 0xff) then
        value = _bitAnd(value, 0xFF)
    end

    return value
end

local helper_test = function(bit, value)
    flagZero = ((_math_floor(value / (2^bit)) % 2) == 0) -- FLAG_ZERO
    flagSubstract = false -- FLAG_SUBSTRACT
    flagHalfCarry = true -- FLAG_HALFCARRY
end

local helper_set = function(bit, value)
    return _bitReplace(value, 1, bit, 1)
end

local helper_reset = function(bit, value)
    return _bitReplace(value, 0, bit, 1)
end

local ldn_nn = function(reg1, reg2, value16)
    if (reg1 == 's') then
        stackPointer = value16
        return
    end

    _writeTwoRegisters(reg1, reg2, value16)
end

local cbOpcodes = {
    -- Opcode: 0x00
    function()
        register2 = helper_rlc(register2)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x01
    function()
        register3 = helper_rlc(register3)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x02
    function()
        register4 = helper_rlc(register4)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x03
    function()
        register5 = helper_rlc(register5)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x04
    function()
        register6 = helper_rlc(register6)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x05
    function()
        register7 = helper_rlc(register7)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x06
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_rlc(_readByteSwitch[address](address)))
    
        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0x07
    function()
        register1 = helper_rlc(register1)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x08
    function()
        register2 = helper_rrc(register2)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x09
    function()
        register3 = helper_rrc(register3)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x0a
    function()
        register4 = helper_rrc(register4)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x0b
    function()
        register5 = helper_rrc(register5)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x0c
    function()
        register6 = helper_rrc(register6)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x0d
    function()
        register7 = helper_rrc(register7)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x0e
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_rrc(_readByteSwitch[address](address)))
    
        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0x0f
    function()
        register1 = helper_rrc(register1)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x10
    function()
        register2 = helper_rl(register2)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x11
    function()
        register3 = helper_rl(register3)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x12
    function()
        register4 = helper_rl(register4)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x13
    function()
        register5 = helper_rl(register5)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x14
    function()
        register6 = helper_rl(register6)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x15
    function()
        register7 = helper_rl(register7)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x16
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_rl(_readByteSwitch[address](address)))
    
        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0x17
    function()
        register1 = helper_rl(register1)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x18
    function()
        register2 = helper_rr(register2)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x19
    function()
        register3 = helper_rr(register3)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x1a
    function()
        register4 = helper_rr(register4)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x1b
    function()
        register5 = helper_rr(register5)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x1c
    function()
        register6 = helper_rr(register6)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x1d
    function()
        register7 = helper_rr(register7)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x1e
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_rr(_readByteSwitch[address](address)))
    
        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0x1f
    function()
        register1 = helper_rr(register1)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x20
    function()
        register2 = helper_sla(register2)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x21
    function()
        register3 = helper_sla(register3)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x22
    function()
        register4 = helper_sla(register4)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x23
    function()
        register5 = helper_sla(register5)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x24
    function()
        register6 = helper_sla(register6)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x25
    function()
        register7 = helper_sla(register7)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x26
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_sla(_readByteSwitch[address](address)))

        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0x27
    function()
        register1 = helper_sla(register1)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x28
    function()
        register2 = helper_sra(register2)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x29
    function()
        register3 = helper_sra(register3)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x2a
    function()
        register4 = helper_sra(register4)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x2b
    function()
        register5 = helper_sra(register5)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x2c
    function()
        register6 = helper_sra(register6)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x2d
    function()
        register7 = helper_sra(register7)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x2e
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_sra(_readByteSwitch[address](address)))

        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0x2f
    function()
        register1 = helper_sra(register1)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x30
    function()
        register2 = helper_swap(register2)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x31
    function()
        register3 = helper_swap(register3)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x32
    function()
        register4 = helper_swap(register4)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x33
    function()
        register5 = helper_swap(register5)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x34
    function()
        register6 = helper_swap(register6)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x35
    function()
        register7 = helper_swap(register7)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x36
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_swap(_readByteSwitch[address](address)))

        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0x37
    function()
        register1 = helper_swap(register1)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x38
    function()
        register2 = helper_srl(register2)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x39
    function()
        register3 = helper_srl(register3)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x3a
    function()
        register4 = helper_srl(register4)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x3b
    function()
        register5 = helper_srl(register5)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x3c
    function()
        register6 = helper_srl(register6)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x3d
    function()
        register7 = helper_srl(register7)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x3e
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_srl(_readByteSwitch[address](address)))

        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0x3f
    function()
        register1 = helper_srl(register1)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x40
    function()
        helper_test(0, register2)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x41
    function()
        helper_test(0, register3)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x42
    function()
        helper_test(0, register4)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x43
    function()
        helper_test(0, register5)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x44
    function()
        helper_test(0, register6)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x45
    function()
        helper_test(0, register7)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x46
    function()
        helper_test(0, _mmuReadByte(_readTwoRegisters(6, 7)))

        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0x47
    function()
        helper_test(0, register1)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x48
    function()
        helper_test(1, register2)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x49
    function()
        helper_test(1, register3)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x4a
    function()
        helper_test(1, register4)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x4b
    function()
        helper_test(1, register5)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x4c
    function()
        helper_test(1, register6)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x4d
    function()
        helper_test(1, register7)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x4e
    function()
        local address = _readTwoRegisters(6, 7)
        helper_test(1, _readByteSwitch[address](address))

        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0x4f
    function()
        helper_test(1, register1)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x50
    function()
        helper_test(2, register2)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x51
    function()
        helper_test(2, register3)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x52
    function()
        helper_test(2, register4)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x53
    function()
        helper_test(2, register5)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x54
    function()
        helper_test(2, register6)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x55
    function()
        helper_test(2, register7)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x56
    function()
        local address = _readTwoRegisters(6, 7)
        helper_test(2, _readByteSwitch[address](address))

        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0x57
    function()
        helper_test(2, register1)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x58
    function()
        helper_test(3, register2)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x59
    function()
        helper_test(3, register3)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x5a
    function()
        helper_test(3, register4)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x5b
    function()
        helper_test(3, register5)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x5c
    function()
        helper_test(3, register6)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x5d
    function()
        helper_test(3, register7)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x5e
    function()
        local address = _readTwoRegisters(6, 7)
        helper_test(3, _readByteSwitch[address](address))

        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0x5f
    function()
        helper_test(3, register1)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x60
    function()
        helper_test(4, register2)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x61
    function()
        helper_test(4, register3)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x62
    function()
        helper_test(4, register4)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x63
    function()
        helper_test(4, register5)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x64
    function()
        helper_test(4, register6)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x65
    function()
        helper_test(4, register7)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x66
    function()
        local address = _readTwoRegisters(6, 7)
        helper_test(4, _readByteSwitch[address](address))

        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0x67
    function()
        helper_test(4, register1)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x68
    function()
        helper_test(5, register2)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x69
    function()
        helper_test(5, register3)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x6a
    function()
        helper_test(5, register4)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x6b
    function()
        helper_test(5, register5)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x6c
    function()
        helper_test(5, register6)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x6d
    function()
        helper_test(5, register7)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x6e
    function()
        local address = _readTwoRegisters(6, 7)
        helper_test(5, _readByteSwitch[address](address))

        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0x6f
    function()
        helper_test(5, register1)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x70
    function()
        helper_test(6, register2)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x71
    function()
        helper_test(6, register3)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x72
    function()
        helper_test(6, register4)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x73
    function()
        helper_test(6, register5)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x74
    function()
        helper_test(6, register6)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x75
    function()
        helper_test(6, register7)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x76
    function()
        local address = _readTwoRegisters(6, 7)
        helper_test(6, _readByteSwitch[address](address))

        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0x77
    function()
        helper_test(6, register1)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x78
    function()
        helper_test(7, register2)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x79
    function()
        helper_test(7, register3)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x7a
    function()
        helper_test(7, register4)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x7b
    function()
        helper_test(7, register5)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x7c
    function()
        helper_test(7, register6)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x7d
    function()
        helper_test(7, register7)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x7e
    function()
        local address = _readTwoRegisters(6, 7)
        helper_test(7, _readByteSwitch[address](address))

        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0x7f
    function()
        helper_test(7, register1)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x80
    function()
        register2 = helper_reset(0, register2)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x81
    function()
        register3 = helper_reset(0, register3)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x82
    function()
        register4 = helper_reset(0, register4)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x83
    function()
        register5 = helper_reset(0, register5)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x84
    function()
        register6 = helper_reset(0, register6)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x85
    function()
        register7 = helper_reset(0, register7)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x86
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_reset(0, _readByteSwitch[address](address)))

        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0x87
    function()
        register1 = helper_reset(0, register1)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x88
    function()
        register2 = helper_reset(1, register2)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x89
    function()
        register3 = helper_reset(1, register3)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x8a
    function()
        register4 = helper_reset(1, register4)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x8b
    function()
        register5 = helper_reset(1, register5)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x8c
    function()
        register6 = helper_reset(1, register6)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x8d
    function()
        register7 = helper_reset(1, register7)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x8e
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_reset(1, _readByteSwitch[address](address)))

        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0x8f
    function()
        register1 = helper_reset(1, register1)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x90
    function()
        register2 = helper_reset(2, register2)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x91
    function()
        register3 = helper_reset(2, register3)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x92
    function()
        register4 = helper_reset(2, register4)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x93
    function()
        register5 = helper_reset(2, register5)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x94
    function()
        register6 = helper_reset(2, register6)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x95
    function()
        register7 = helper_reset(2, register7)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x96
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_reset(2, _readByteSwitch[address](address)))
    
        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0x97
    function()
        register1 = helper_reset(2, register1)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x98
    function()
        register2 = helper_reset(3, register2)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x99
    function()
        register3 = helper_reset(3, register3)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x9a
    function()
        register4 = helper_reset(3, register4)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x9b
    function()
        register5 = helper_reset(3, register5)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x9c
    function()
        register6 = helper_reset(3, register6)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x9d
    function()
        register7 = helper_reset(3, register7)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x9e
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_reset(3, _readByteSwitch[address](address)))
    
        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0x9f
    function()
        register1 = helper_reset(3, register1)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xa0
    function()
        register2 = helper_reset(4, register2)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xa1
    function()
        register3 = helper_reset(4, register3)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xa2
    function()
        register4 = helper_reset(4, register4)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xa3
    function()
        register5 = helper_reset(4, register5)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xa4
    function()
        register6 = helper_reset(4, register6)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xa5
    function()
        register7 = helper_reset(4, register7)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xa6
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_reset(4, _readByteSwitch[address](address)))
    
        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0xa7
    function()
        register1 = helper_reset(4, register1)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xa8
    function()
        register2 = helper_reset(5, register2)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xa9
    function()
        register3 = helper_reset(5, register3)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xaa
    function()
        register4 = helper_reset(5, register4)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xab
    function()
        register5 = helper_reset(5, register5)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xac
    function()
        register6 = helper_reset(5, register6)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xad
    function()
        register7 = helper_reset(5, register7)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xae
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_reset(5, _readByteSwitch[address](address)))
    
        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0xaf
    function()
        register1 = helper_reset(5, register1)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xb0
    function()
        register2 = helper_reset(6, register2)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xb1
    function()
        register3 = helper_reset(6, register3)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xb2
    function()
        register4 = helper_reset(6, register4)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xb3
    function()
        register5 = helper_reset(6, register5)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xb4
    function()
        register6 = helper_reset(6, register6)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xb5
    function()
        register7 = helper_reset(6, register7)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xb6
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_reset(6, _readByteSwitch[address](address)))
    
        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0xb7
    function()
        register1 = helper_reset(6, register1)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xb8
    function()
        register2 = helper_reset(7, register2)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xb9
    function()
        register3 = helper_reset(7, register3)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xba
    function()
        register4 = helper_reset(7, register4)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xbb
    function()
        register5 = helper_reset(7, register5)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xbc
    function()
        register6 = helper_reset(7, register6)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xbd
    function()
        register7 = helper_reset(7, register7)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xbe
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_reset(7, _readByteSwitch[address](address)))
    
        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0xbf
    function()
        register1 = helper_reset(7, register1)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xc0
    function()
        register2 = helper_set(0, register2)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xc1
    function()
        register3 = helper_set(0, register3)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xc2
    function()
        register4 = helper_set(0, register4)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xc3
    function()
        register5 = helper_set(0, register5)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xc4
    function()
        register6 = helper_set(0, register6)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xc5
    function()
        register7 = helper_set(0, register7)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xc6
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_set(0, _readByteSwitch[address](address)))

        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0xc7
    function()
        register1 = helper_set(0, register1)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xc8
    function()
        register2 = helper_set(1, register2)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xc9
    function()
        register3 = helper_set(1, register3)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xca
    function()
        register4 = helper_set(1, register4)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xcb
    function()
        register5 = helper_set(1, register5)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xcc
    function()
        register6 = helper_set(1, register6)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xcd
    function()
        register7 = helper_set(1, register7)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xce
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_set(1, _readByteSwitch[address](address)))
    
        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0xcf
    function()
        register1 = helper_set(1, register1)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xd0
    function()
        register2 = helper_set(2, register2)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xd1
    function()
        register3 = helper_set(2, register3)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xd2
    function()
        register4 = helper_set(2, register4)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xd3
    function()
        register5 = helper_set(2, register5)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xd4
    function()
        register6 = helper_set(2, register6)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xd5
    function()
        register7 = helper_set(2, register7)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xd6
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_set(2, _readByteSwitch[address](address)))
    
        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0xd7
    function()
        register1 = helper_set(2, register1)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xd8
    function()
        register2 = helper_set(3, register2)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xd9
    function()
        register3 = helper_set(3, register3)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xda
    function()
        register4 = helper_set(3, register4)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xdb
    function()
        register5 = helper_set(3, register5)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xdc
    function()
        register6 = helper_set(3, register6)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xdd
    function()
        register7 = helper_set(3, register7)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xde
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_set(3, _readByteSwitch[address](address)))
    
        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0xdf
    function()
        register1 = helper_set(3, register1)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xe0
    function()
        register2 = helper_set(4, register2)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xe1
    function()
        register3 = helper_set(4, register3)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xe2
    function()
        register4 = helper_set(4, register4)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xe3
    function()
        register5 = helper_set(4, register5)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xe4
    function()
        register6 = helper_set(4, register6)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xe5
    function()
        register7 = helper_set(4, register7)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xe6
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_set(4, _readByteSwitch[address](address)))
    
        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0xe7
    function()
        register1 = helper_set(4, register1)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xe8
    function()
        register2 = helper_set(5, register2)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xe9
    function()
        register3 = helper_set(5, register3)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xea
    function()
        register4 = helper_set(5, register4)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xeb
    function()
        register5 = helper_set(5, register5)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xec
    function()
        register6 = helper_set(5, register6)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xed
    function()
        register7 = helper_set(5, register7)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xee
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_set(5, _readByteSwitch[address](address)))
    
        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0xef
    function()
        register1 = helper_set(5, register1)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xf0
    function()
        register2 = helper_set(6, register2)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xf1
    function()
        register3 = helper_set(6, register3)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xf2
    function()
        register4 = helper_set(6, register4)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xf3
    function()
        register5 = helper_set(6, register5)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xf4
    function()
        register6 = helper_set(6, register6)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xf5
    function()
        register7 = helper_set(6, register7)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xf6
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_set(6, _readByteSwitch[address](address)))
    
        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0xf7
    function()
        register1 = helper_set(6, register1)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xf8
    function()
        register2 = helper_set(7, register2)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xf9
    function()
        register3 = helper_set(7, register3)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xfa
    function()
        register4 = helper_set(7, register4)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xfb
    function()
        register5 = helper_set(7, register5)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xfc
    function()
        register6 = helper_set(7, register6)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xfd
    function()
        register7 = helper_set(7, register7)
    
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xfe
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_set(7, _readByteSwitch[address](address)))
    
        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0xff
    function()
        register1 = helper_set(7, register1)
    
        clockM = 2
        clockT = 8
    end,
}

_opcodes = {
    -- Opcode: 0x00
    function()
        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x01
    function()
        _writeTwoRegisters(2, 3, _mmuReadUInt16(programCounter))

        programCounter = programCounter + 2
        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0x02
    function()
        _mmuWriteByte(_readTwoRegisters(2, 3), register1)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x03
    function()
        _writeTwoRegisters(2, 3, helper_inc16(_readTwoRegisters(2, 3)))

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x04
    function()
        register2 = helper_inc(register2)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x05
    function()
        register2 = helper_dec(register2)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x06
    function()
        register2 = _readByteSwitch[programCounter](programCounter)

        programCounter = programCounter + 1
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x07
    function()
        register1 = helper_rlc(register1)
        flagZero = false

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x08
    function()
        mmuWriteShort(_mmuReadUInt16(programCounter), stackPointer)

        programCounter = programCounter + 2
        clockM = 5
        clockT = 20
    end,
    -- Opcode: 0x09
    function()
        _writeTwoRegisters(6, 7, helper_add16(_readTwoRegisters(6, 7), _readTwoRegisters(2, 3)))

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x0a
    function()
        register1 = _mmuReadByte(_readTwoRegisters(2, 3))

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x0b
    function()
        _writeTwoRegisters(2, 3, helper_dec16(_readTwoRegisters(2, 3)))

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x0c
    function()
        register3 = helper_inc(register3)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x0d
    function()
        register3 = helper_dec(register3)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x0e
    function()
        register3 = _readByteSwitch[programCounter](programCounter)

        programCounter = programCounter + 1
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x0f
    function()
        register1 = helper_rrc(register1)
        flagZero = false
    
        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x10
    function()
        stopCPU()

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x11
    function()
        _writeTwoRegisters(4, 5, _mmuReadUInt16(programCounter))

        programCounter = programCounter + 2
        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0x12
    function()
        _mmuWriteByte(_readTwoRegisters(4, 5), register1)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x13
    function()
        _writeTwoRegisters(4, 5, helper_inc16(_readTwoRegisters(4, 5)))

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x14
    function()
        register4 = helper_inc(register4)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x15
    function()
        register4 = helper_dec(register4)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x16
    function()
        register4 = _readByteSwitch[programCounter](programCounter)

        programCounter = programCounter + 1
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x17
    function()
        register1 = helper_rl(register1)
        flagZero = false

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x18
    function()
        local addition = _mmuReadSignedByte(programCounter)

        programCounter = programCounter + addition + 1

        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0x19
    function()
        _writeTwoRegisters(6, 7, helper_add16(_readTwoRegisters(6, 7), _readTwoRegisters(4, 5)))

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x1a
    function()
        register1 = _mmuReadByte(_readTwoRegisters(4, 5))

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x1b
    function()
        _writeTwoRegisters(4, 5, helper_dec16(_readTwoRegisters(4, 5)))

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x1c
    function()
        register5 = helper_inc(register5)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x1d
    function()
        register5 = helper_dec(register5)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x1e
    function()
        register5 = _readByteSwitch[programCounter](programCounter)

        programCounter = programCounter + 1
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x1f
    function()
        register1 = helper_rr(register1)
    
        flagZero = false -- FLAG_ZERO

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x20
    function()
        if (not flagZero) then
            programCounter = programCounter + _mmuReadSignedByte(programCounter) + 1

            clockM = 3
            clockT = 12
        else
            programCounter = programCounter + 1

            clockM = 2
            clockT = 8
        end
    end,
    -- Opcode: 0x21
    function()
        _writeTwoRegisters(6, 7, _mmuReadUInt16(programCounter))

        programCounter = programCounter + 2
        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0x22
    function()
        local address = _readTwoRegisters(6, 7)
        _writeByteSwitch[address](address, register1)

        if (address == 0xff) then
            _writeTwoRegisters(6, 7, 0)
        else
            _writeTwoRegisters(6, 7, address + 1)
        end

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x23
    function()
        _writeTwoRegisters(6, 7, helper_inc16(_readTwoRegisters(6, 7)))

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x24
    function()
        register6 = helper_inc(register6)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x25
    function()
        register6 = helper_dec(register6)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x26
    function()
        register6 = _readByteSwitch[programCounter](programCounter)

        programCounter = programCounter + 1
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x27
    function()
        local registerA = register1

        if (not flagSubstract) then -- FLAG_SUBSTRACT
            if (flagCarry or registerA > 0x99) then -- FLAG_CARRY
                registerA = registerA + 0x60
                flagCarry = true -- FLAG_CARRY
            end

            if (flagHalfCarry or _bitAnd(registerA, 0x0f) > 0x09) then -- FLAG_HALFCARRY
                registerA = registerA + 0x6
            end
        else
            if (flagCarry) then -- FLAG_CARRY
                registerA = registerA - 0x60
            end

            if (flagHalfCarry) then -- FLAG_HALFCARRY
                registerA = registerA - 0x6
            end
        end

        registerA = registerA % 0x100

        flagZero = (registerA == 0) and true or false -- FLAG_ZERO
        flagHalfCarry = false -- FLAG_HALFCARRY
        register1 = registerA

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x28
    function()
        if (flagZero) then
            programCounter = programCounter + _mmuReadSignedByte(programCounter) + 1

            clockM = 3
            clockT = 12
        else
            programCounter = programCounter + 1

            clockM = 2
            clockT = 8
        end
    end,
    -- Opcode: 0x29
    function()
        local value = _readTwoRegisters(6, 7)
        _writeTwoRegisters(6, 7, helper_add16(value, value))

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x2a
    function()
        local address = _readTwoRegisters(6, 7)
        register1 = _readByteSwitch[address](address)

        if (address == 0xff) then
            _writeTwoRegisters(6, 7, 0)
        else
            _writeTwoRegisters(6, 7, address + 1)
        end

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x2b
    function()
        _writeTwoRegisters(6, 7, helper_dec16(_readTwoRegisters(6, 7)))

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x2c
    function()
        register7 = helper_inc(register7)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x2d
    function()
        register7 = helper_dec(register7)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x2e
    function()
        register7 = _readByteSwitch[programCounter](programCounter)

        programCounter = programCounter + 1
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x2f
    function()
        register1 = helper_not(register1)

        flagSubstract = true -- FLAG_SUBSTRACT
        flagHalfCarry = true -- FLAG_HALFCARRY

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x30
    function()
        if (not flagCarry) then
            programCounter = programCounter + _mmuReadSignedByte(programCounter) + 1

            clockM = 3
            clockT = 12
        else
            programCounter = programCounter + 1

            clockM = 2
            clockT = 8
        end
    end,
    -- Opcode: 0x31
    function()
        stackPointer = _mmuReadUInt16(programCounter)

        programCounter = programCounter + 2
        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0x32
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, register1)

        if (address == 0) then
            _writeTwoRegisters(6, 7, 0xff)
        else
            _writeTwoRegisters(6, 7, address - 1)
        end

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x33
    function()
        stackPointer = helper_inc16(stackPointer)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x34
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_inc(_readByteSwitch[address](address)))

        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0x35
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_dec(_readByteSwitch[address](address)))

        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0x36
    function()
        _mmuWriteByte(_readTwoRegisters(6, 7), _readByteSwitch[programCounter](programCounter))

        programCounter = programCounter + 1
        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0x37
    function()
        flagSubstract = false -- FLAG_SUBSTRACT
        flagHalfCarry = false -- FLAG_HALFCARRY
        flagCarry = true

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x38
    function()
        if (flagCarry) then
            programCounter = programCounter + _mmuReadSignedByte(programCounter) + 1

            clockM = 2
            clockT = 12
        else
            programCounter = programCounter + 1

            clockM = 2
            clockT = 8
        end
    end,
    -- Opcode: 0x39
    function()
        _writeTwoRegisters(6, 7, helper_add16(_readTwoRegisters(6, 7), stackPointer))

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x3a
    function()
        local address = _readTwoRegisters(6, 7)
        register1 = _readByteSwitch[address](address)

        if (address == 0) then
            _writeTwoRegisters(6, 7, 0xff)
        else
            _writeTwoRegisters(6, 7, address - 1)
        end

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x3b
    function()
        stackPointer = helper_dec16(stackPointer)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x3c
    function()
        register1 = helper_inc(register1)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x3d
    function()
        register1 = helper_dec(register1)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x3e
    function()
        register1 = _readByteSwitch[programCounter](programCounter)

        programCounter = programCounter + 1
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x3f
    function()
        flagSubstract = false -- FLAG_SUBSTRACT
        flagHalfCarry = false -- FLAG_HALFCARRY
        flagCarry = not flagCarry -- FLAG_CARRY

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x40
    function()
        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x41
    function()
        register2 = register3

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x42
    function()
        register2 = register4

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x43
    function()
        register2 = register5

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x44
    function()
        register2 = register6

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x45
    function()
        register2 = register7

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x46
    function()
        register2 = _mmuReadByte(_readTwoRegisters(6, 7))

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x47
    function()
        register2 = register1

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x48
    function()
        register3 = register2

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x49
    function()
        register3 = register3

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x4a
    function()
        register3 = register4

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x4b
    function()
        register3 = register5

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x4c
    function()
        register3 = register6

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x4d
    function()
        register3 = register7

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x4e
    function()
        register3 = _mmuReadByte(_readTwoRegisters(6, 7))

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x4f
    function()
        register3 = register1

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x50
    function()
        register4 = register2

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x51
    function()
        register4 = register3

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x52
    function()
        register4 = register4

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x53
    function()
        register4 = register5

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x54
    function()
        register4 = register6

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x55
    function()
        register4 = register7

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x56
    function()
        register4 = _mmuReadByte(_readTwoRegisters(6, 7))

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x57
    function()
        register4 = register1

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x58
    function()
        register5 = register2

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x59
    function()
        register5 = register3

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x5a
    function()
        register5 = register4

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x5b
    function()
        register5 = register5

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x5c
    function()
        register5 = register6

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x5d
    function()
        register5 = register7

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x5e
    function()
        register5 = _mmuReadByte(_readTwoRegisters(6, 7))

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x5f
    function()
        register5 = register1

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x60
    function()
        register6 = register2

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x61
    function()
        register6 = register3

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x62
    function()
        register6 = register4

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x63
    function()
        register6 = register5

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x64
    function()
        register6 = register6

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x65
    function()
        register6 = register7

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x66
    function()
        register6 = _mmuReadByte(_readTwoRegisters(6, 7))

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x67
    function()
        register6 = register1

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x68
    function()
        register7 = register2

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x69
    function()
        register7 = register3

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x6a
    function()
        register7 = register4

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x6b
    function()
        register7 = register5

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x6c
    function()
        register7 = register6

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x6d
    function()
        register7 = register7

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x6e
    function()
        register7 = _mmuReadByte(_readTwoRegisters(6, 7))

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x6f
    function()
        register7 = register1

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x70
    function()
        _mmuWriteByte(_readTwoRegisters(6, 7), register2)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x71
    function()
        _mmuWriteByte(_readTwoRegisters(6, 7), register3)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x72
    function()
        _mmuWriteByte(_readTwoRegisters(6, 7), register4)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x73
    function()
        _mmuWriteByte(_readTwoRegisters(6, 7), register5)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x74
    function()
        _mmuWriteByte(_readTwoRegisters(6, 7), register6)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x75
    function()
        _mmuWriteByte(_readTwoRegisters(6, 7), register7)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x76
    function()
        haltCPU()

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x77
    function()
        _mmuWriteByte(_readTwoRegisters(6, 7), register1)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x78
    function()
        register1 = register2

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x79
    function()
        register1 = register3

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x7a
    function()
        register1 = register4

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x7b
    function()
        register1 = register5

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x7c
    function()
        register1 = register6

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x7d
    function()
        register1 = register7

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x7e
    function()
        register1 = _mmuReadByte(_readTwoRegisters(6, 7))

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x7f
    function()
        register1 = register1

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x80
    function()
        register1 = helper_add(register1, register2)

        flagSubstract = false
        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x81
    function()
        register1 = helper_add(register1, register3)

        flagSubstract = false
        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x82
    function()
        register1 = helper_add(register1, register4)

        flagSubstract = false
        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x83
    function()
        register1 = helper_add(register1, register5)

        flagSubstract = false
        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x84
    function()
        register1 = helper_add(register1, register6)

        flagSubstract = false
        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x85
    function()
        register1 = helper_add(register1, register7)

        flagSubstract = false
        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x86
    function()
        register1 = helper_add(register1,
            _mmuReadByte(_readTwoRegisters(6, 7)))

        flagSubstract = false
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x87
    function()
        register1 = helper_add(register1, register1)

        flagSubstract = false
        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x88
    function()
        register1 = helper_adc(register1, register2)

        flagSubstract = false
        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x89
    function()
        register1 = helper_adc(register1, register3)

        flagSubstract = false
        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x8a
    function()
        register1 = helper_adc(register1, register4)

        flagSubstract = false
        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x8b
    function()
        register1 = helper_adc(register1, register5)

        flagSubstract = false
        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x8c
    function()
        register1 = helper_adc(register1, register6)

        flagSubstract = false
        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x8d
    function()
        register1 = helper_adc(register1, register7)

        flagSubstract = false
        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x8e
    function()
        register1 = helper_adc(register1,
            _mmuReadByte(_readTwoRegisters(6, 7)))

        flagSubstract = false
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x8f
    function()
        register1 = helper_adc(register1, register1)

        flagSubstract = false
        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x90
    function()
        register1 = helper_sub(register1, register2)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x91
    function()
        register1 = helper_sub(register1, register3)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x92
    function()
        register1 = helper_sub(register1, register4)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x93
    function()
        register1 = helper_sub(register1, register5)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x94
    function()
        register1 = helper_sub(register1, register6)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x95
    function()
        register1 = helper_sub(register1, register7)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x96
    function()
        register1 = helper_sub(register1,
            _mmuReadByte(_readTwoRegisters(6, 7)))

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x97
    function()
        register1 = helper_sub(register1, register1)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x98
    function()
        register1 = helper_sbc(register1, register2)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x99
    function()
        register1 = helper_sbc(register1, register3)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x9a
    function()
        register1 = helper_sbc(register1, register4)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x9b
    function()
        register1 = helper_sbc(register1, register5)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x9c
    function()
        register1 = helper_sbc(register1, register6)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x9d
    function()
        register1 = helper_sbc(register1, register7)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0x9e
    function()
        register1 = helper_sbc(register1, _mmuReadByte(_readTwoRegisters(6, 7)))

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0x9f
    function()
        register1 = helper_sbc(register1, register1)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xa0
    function()
        register1 = helper_and(register1, register2)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xa1
    function()
        register1 = helper_and(register1, register3)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xa2
    function()
        register1 = helper_and(register1, register4)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xa3
    function()
        register1 = helper_and(register1, register5)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xa4
    function()
        register1 = helper_and(register1, register6)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xa5
    function()
        register1 = helper_and(register1, register7)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xa6
    function()
        register1 = helper_and(register1, _mmuReadByte(
            _readTwoRegisters(6, 7))
        )

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xa7
    function()
        register1 = helper_and(register1, register1)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xa8
    function()
        register1 = helper_xor(register1, register2)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xa9
    function()
        register1 = helper_xor(register1, register3)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xaa
    function()
        register1 = helper_xor(register1, register4)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xab
    function()
        register1 = helper_xor(register1, register5)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xac
    function()
        register1 = helper_xor(register1, register6)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xad
    function()
        register1 = helper_xor(register1, register7)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xae
    function()
        register1 = helper_xor(register1, _mmuReadByte(
            _readTwoRegisters(6, 7))
        )

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xaf
    function()
        register1 = helper_xor(register1, register1)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xb0
    function()
        register1 = helper_or(register1, register2)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xb1
    function()
        register1 = helper_or(register1, register3)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xb2
    function()
        register1 = helper_or(register1, register4)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xb3
    function()
        register1 = helper_or(register1, register5)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xb4
    function()
        register1 = helper_or(register1, register6)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xb5
    function()
        register1 = helper_or(register1, register7)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xb6
    function()
        register1 = helper_or(register1, _mmuReadByte(
            _readTwoRegisters(6, 7))
        )

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xb7
    function()
        register1 = helper_or(register1, register1)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xb8
    function()
        helper_cp(register1, register2)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xb9
    function()
        helper_cp(register1, register3)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xba
    function()
        helper_cp(register1, register4)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xbb
    function()
        helper_cp(register1, register5)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xbc
    function()
        helper_cp(register1, register6)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xbd
    function()
        helper_cp(register1, register7)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xbe
    function()
        helper_cp(register1, _mmuReadByte(
            _readTwoRegisters(6, 7))
        )

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xbf
    function()
        helper_cp(register1, register1)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xc0
    function()
        if (not flagZero) then
            programCounter = _mmuPopStack()

            clockM = 2
            clockT = 20
            return
        end

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xc1
    function()
        _writeTwoRegisters(2, 3, _mmuPopStack())

        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0xc2
    function()
        if (not flagZero) then
            programCounter = _mmuReadUInt16(programCounter)

            clockM = 3
            clockT = 16
        else
            programCounter = programCounter + 2

            clockM = 3
            clockT = 12
        end
    end,
    -- Opcode: 0xc3
    function()
        programCounter = _mmuReadUInt16(programCounter)

        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0xc4
    function()
        if (not flagZero) then
            _mmuPushStack(programCounter + 2)
            programCounter = _mmuReadUInt16(programCounter)

            clockM = 6
            clockT = 24
        else
            programCounter = programCounter + 2

            clockM = 3
            clockT = 12
        end
    end,
    -- Opcode: 0xc5
    function()
        _mmuPushStack(_readTwoRegisters(2, 3))

        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0xc6
    function()
        register1 = helper_add(register1,
            _readByteSwitch[programCounter](programCounter))

        flagSubstract = false
        programCounter = programCounter + 1
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xc7
    function()
        _mmuPushStack(programCounter)
        programCounter = 0x0

        clockM = 1
        clockT = 16
    end,
    -- Opcode: 0xc8
    function()
        if (flagZero) then
            programCounter = _mmuPopStack()

            clockM = 5
            clockT = 20
        else
            clockM = 2
            clockT = 8
        end
    end,
    -- Opcode: 0xc9
    function()
        programCounter = _mmuPopStack()

        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0xca
    function()
        if (flagZero) then
            programCounter = _mmuReadUInt16(programCounter)

            clockM = 3
            clockT = 16
        else
            programCounter = programCounter + 2

            clockM = 3
            clockT = 12
        end
    end,
    -- Opcode: 0xcb
    function()
        programCounter = programCounter + 1
        cbOpcodes[mmuReadByte(programCounter - 1) + 1]()
    end,
    -- Opcode: 0xcc
    function()
        if (flagZero) then
            _mmuPushStack(programCounter + 2)
            programCounter = _mmuReadUInt16(programCounter)

            clockM = 6
            clockT = 24
        else
            programCounter = programCounter + 2

            clockM = 3
            clockT = 12
        end
    end,
    -- Opcode: 0xcd
    function()
        local value = _mmuReadUInt16(programCounter)

        _mmuPushStack(programCounter + 2)
        programCounter = value

        clockM = 6
        clockT = 24
    end,
    -- Opcode: 0xce
    function()
        register1 = helper_adc(register1,
            _readByteSwitch[programCounter](programCounter))

        programCounter = programCounter + 1
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xcf
    function()
        _mmuPushStack(programCounter)
        programCounter = 0x08

        clockM = 1
        clockT = 16
    end,
    -- Opcode: 0xd0
    function()
        if (not flagCarry) then
            programCounter = _mmuPopStack()

            clockM = 5
            clockT = 20
        else
            clockM = 2
            clockT = 8
        end
    end,
    -- Opcode: 0xd1
    function()
        _writeTwoRegisters(4, 5, _mmuPopStack())

        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0xd2
    function()
        if (not flagCarry) then
            programCounter = _mmuReadUInt16(programCounter)

            clockM = 3
            clockT = 16
        else
            programCounter = programCounter + 2

            clockM = 3
            clockT = 12
        end
    end,
    -- Opcode: 0xd3
    function() end,
    -- Opcode: 0xd4
    function()
        if (not flagCarry) then
            _mmuPushStack(programCounter + 2)
            programCounter = _mmuReadUInt16(programCounter)

            clockM = 6
            clockT = 24
        else
            programCounter = programCounter + 2

            clockM = 3
            clockT = 12
        end
    end,
    -- Opcode: 0xd5
    function()
        _mmuPushStack(_readTwoRegisters(4, 5))

        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0xd6
    function()
        register1 = helper_sub(register1, _readByteSwitch[programCounter](programCounter))

        programCounter = programCounter + 1
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xd7
    function()
        _mmuPushStack(programCounter)
        programCounter = 0x10

        clockM = 1
        clockT = 16
    end,
    -- Opcode: 0xd8
    function()
        if (flagCarry) then
            programCounter = _mmuPopStack()

            clockM = 1
            clockT = 20

            return
        end

        clockM = 1
        clockT = 8
    end,
    -- Opcode: 0xd9
    function()
        programCounter = _mmuPopStack()
        setInterrupts()

        clockM = 1
        clockT = 16
    end,
    -- Opcode: 0xda
    function()
        if (flagCarry) then
            programCounter = _mmuReadUInt16(programCounter)

            clockM = 3
            clockT = 16
        else
            programCounter = programCounter + 2

            clockM = 3
            clockT = 12
        end
    end,
    -- Opcode: 0xdb
    function() end,
    -- Opcode: 0xdc
    function()
        if (flagCarry) then
            _mmuPushStack(programCounter + 2)
            programCounter = _mmuReadUInt16(programCounter)

            clockM = 6
            clockT = 24
        else
            programCounter = programCounter + 2

            clockM = 3
            clockT = 12
        end
    end,
    -- Opcode: 0xdd
    function() end,
    -- Opcode: 0xde
    function()
        register1 = helper_sbc(register1, _readByteSwitch[programCounter](programCounter))

        programCounter = programCounter + 1
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xdf
    function()
        _mmuPushStack(programCounter)
        programCounter = 0x18

        clockM = 1
        clockT = 16
    end,
    -- Opcode: 0xe0
    function()
        _mmuWriteByte(0xFF00 + _readByteSwitch[programCounter](programCounter), register1)

        programCounter = programCounter + 1
        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0xe1
    function()
        _writeTwoRegisters(6, 7, _mmuPopStack())

        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0xe2
    function()
        _mmuWriteByte(0xFF00 + register3, register1)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xe3
    function() end,
    -- Opcode: 0xe4
    function() end,
    -- Opcode: 0xe5
    function()
        _mmuPushStack(_readTwoRegisters(6, 7))

        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0xe6
    function()
        register1 = helper_and(register1, _readByteSwitch[programCounter](programCounter))

        programCounter = programCounter + 1
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xe7
    function()
        _mmuPushStack(programCounter)
        programCounter = 0x20

        clockM = 1
        clockT = 16
    end,
    -- Opcode: 0xe8
    function()
        stackPointer = helper_add_sp(stackPointer,
            _mmuReadSignedByte(programCounter))

        programCounter = programCounter + 1
        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0xe9
    function()
        programCounter = _readTwoRegisters(6, 7)

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xea
    function()
        _mmuWriteByte(_mmuReadUInt16(programCounter), register1)

        programCounter = programCounter + 2
        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0xeb
    function() end,
    -- Opcode: 0xec
    function() end,
    -- Opcode: 0xed
    function() end,
    -- Opcode: 0xee
    function()
        register1 = helper_xor(register1, _readByteSwitch[programCounter](programCounter))

        programCounter = programCounter + 1
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xef
    function()
        _mmuPushStack(programCounter)
        programCounter = 0x28

        clockM = 1
        clockT = 16
    end,
    -- Opcode: 0xf0
    function()
        register1 = _mmuReadByte(0xFF00 + _readByteSwitch[programCounter](programCounter))

        programCounter = programCounter + 1
        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0xf1
    function()
        _writeTwoRegisters(1, 8, _mmuPopStack())

        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0xf2
    function()
        register1 = _mmuReadByte(0xFF00 + register3)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xf3
    function()
        disableInterrupts()

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xf4
    function() end,
    -- Opcode: 0xf5
    function()
        _mmuPushStack(_readTwoRegisters(1, 8))

        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0xf6
    function()
        register1 = helper_or(register1, _readByteSwitch[programCounter](programCounter))

        programCounter = programCounter + 1
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xf7
    function()
        _mmuPushStack(programCounter)
        programCounter = 0x30

        clockM = 1
        clockT = 16
    end,
    -- Opcode: 0xf8
    function()
        local address = stackPointer
        local value = _mmuReadSignedByte(programCounter)

        _writeTwoRegisters(6, 7, helper_add_sp(address, value))

        programCounter = programCounter + 1
        clockM = 3
        clockT = 12
    end,
    -- Opcode: 0xf9
    function()
        stackPointer = _readTwoRegisters(6, 7)

        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xfa
    function()
        register1 = _mmuReadByte(_mmuReadUInt16(programCounter))

        programCounter = programCounter + 2
        clockM = 4
        clockT = 16
    end,
    -- Opcode: 0xfb
    function()
        enableInterrupts()

        clockM = 1
        clockT = 4
    end,
    -- Opcode: 0xfc
    function() end,
    -- Opcode: 0xfd
    function() end,
    -- Opcode: 0xfe
    function()
        helper_cp(register1, _readByteSwitch[programCounter](programCounter))

        programCounter = programCounter + 1
        clockM = 2
        clockT = 8
    end,
    -- Opcode: 0xff
    function()
        _mmuPushStack(programCounter)
        programCounter = 0x38

        clockM = 4
        clockT = 16
    end,
}

addEventHandler("onClientResourceStart", resourceRoot, function()
    _readTwoRegisters = readTwoRegisters
    _writeTwoRegisters = writeTwoRegisters

    _readByteSwitch = readByteSwitch
    _writeByteSwitch = writeByteSwitch

    _mmuReadByte = mmuReadByte
    _mmuWriteByte = mmuWriteByte
    _mmuReadUInt16 = mmuReadUInt16
    _mmuReadSignedByte = mmuReadSignedByte
    _mmuPushStack = mmuPushStack
    _mmuPopStack = mmuPopStack

    _gpuStep = gpuStep
    _timerStep = timerStep

    _handleInterrupts = handleInterrupts
end, true, "high")

addEventHandler("gb:cpu:reset", root,
    function()
        _registers = registers
    end
)

_readTwoRegisters = readTwoRegisters
_writeTwoRegisters = writeTwoRegisters