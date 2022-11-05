-----------------------------------
-- * Locals
-----------------------------------

local _opcodes = opcodes

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

local _gpuStep = false
local _timerStep = false

local _handleInterrupts = false

-----------------------------------
-- * Functions
-----------------------------------

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

    _registers = registers

    setupMMU()
end

function cpuLoadRom(romData)
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
    else
        if (isGameBoyColor()) then
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
        
        mmuWriteByte(0xFF4D, _bitReplace(_bitReplace(_mmuReadByte(0xFF4D), cgbDoubleSpeed and 1 or 0, 7, 1), 0, 0, 1))
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
    local value = _registers[r1]
    value = value * 256

    if (r2 == 8) then
        value = value + (
            ((_registers[8][1]) and 1 or 0) * 128 +
            ((_registers[8][2]) and 1 or 0) * 64 +
            ((_registers[8][3]) and 1 or 0) * 32 +
            ((_registers[8][4]) and 1 or 0) * 16
        )
    else
        value = value + _registers[r2]
    end

    return value
end

function writeTwoRegisters(r1, r2, value)
    local reg1 = _bitAnd(0xFF00, value) / 256
    _registers[r1] = reg1 - (reg1 % 1)

    if (r2 == 8) then
        _registers[8][1] = (_bitAnd(value, 0x80) > 0)
        _registers[8][2] = (_bitAnd(value, 0x40) > 0)
        _registers[8][3] = (_bitAnd(value, 0x20) > 0)
        _registers[8][4] = (_bitAnd(value, 0x10) > 0)
    else
        _registers[r2] = _bitAnd(0x00FF, value)
    end
end

function requestInterrupt(interrupt)
    interruptFlags = _bitReplace(interruptFlags, 1, interrupt, 1)
    _interruptDelay = 4
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

                _mmuPushStack(_registers[10])

                _registers[10] = 0x40

                _registers[12].m = 5
                _registers[12].t = 20
            end

            _interrupts = false
        elseif (_bitAnd(maskedFlags, 0x02) ~= 0) then
            if (_interrupts) then
                interruptFlags = _bitAnd(interruptFlags, 0xFD)

                _mmuPushStack(_registers[10])

                _registers[10] = 0x48

                _registers[12].m = 5
                _registers[12].t = 20
            end

            _interrupts = false
        elseif (_bitAnd(maskedFlags, 0x04) ~= 0) then
            if (_interrupts) then
                interruptFlags = _bitAnd(interruptFlags, 0xFB)

                _mmuPushStack(_registers[10])

                _registers[10] = 0x50

                _registers[12].m = 5
                _registers[12].t = 20
            end

            _interrupts = false
        elseif (_bitAnd(maskedFlags, 0x08) ~= 0) then
            if (_interrupts) then
                interruptFlags = _bitAnd(interruptFlags, 0xF7)

                _mmuPushStack(_registers[10])

                _registers[10] = 0x58

                _registers[12].m = 5
                _registers[12].t = 20
            end

            _interrupts = false
        elseif (_bitAnd(maskedFlags, 0x16) ~= 0) then
            if (_interrupts) then
                interruptFlags = _bitAnd(interruptFlags, 0xEF)

                _mmuPushStack(_registers[10])

                _registers[10] = 0x60

                _registers[12].m = 5
                _registers[12].t = 20
            end

            _interrupts = false
        end

        _interruptDelay = 0

        if (_pausedUntilInterrupts) then
            _pausedUntilInterrupts = false
            _paused = false
        end
    elseif (_interruptDelay > 0) then
        _interruptDelay = _interruptDelay - _registers[12].t
    end
end

local currentCycles = 0
local nextOpcode = 0

function runCPU()
    if (_stepCallback) then
        removeEventHandler("onClientPreRender", root, _stepCallback)
        _stepCallback = nil
    end

    local debuggerEnabled = isDebuggerEnabled()

    _stepCallback = function(delta)
        if (not _paused or _pausedUntilInterrupts) then
            currentCycles = 0

            local cyclesToRun = 69905

            if (isGameBoyColor() and cgbDoubleSpeed) then
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
                    _registers[9] = _registers[10]
                
                    _registers[12].m = 0
                    _registers[12].t = 0
                    _registers[10] = _registers[10] + 1
                
                    _opcodes[_mmuReadByte(_registers[10] - 1) + 1]()
                
                    _clock.m = _clock.m + _registers[12].m
                    _clock.t = _clock.t + _registers[12].t
                end

                if (_triggerHaltBug and not _paused) then
                    _triggerHaltBug = false
                    _registers[10] = _registers[10] - 1
                end

                local ticks = _registers[12].t

                if (_paused) then
                    _timerStep(4)
                    _gpuStep(1)
                else
                    _timerStep(ticks)

                    if (isGameBoyColor() and cgbDoubleSpeed) then
                        _gpuStep(_registers[12].m / 2)
                    else
                        _gpuStep(_registers[12].m)
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
        registers = _registers
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
    registers = state.registers

    _registers = registers
    clock = _clock
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    _mmuPushStack = mmuPushStack
    _mmuReadByte = mmuReadByte

    _gpuStep = gpuStep
    _timerStep = timerStep

    _handleInterrupts = handleInterrupts
end, true, "high")