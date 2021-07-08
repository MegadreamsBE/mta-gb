-----------------------------------
-- * Locals
-----------------------------------

local _opcodes = opcodes

local _bitAnd = bitAnd
local _bitReplace = bitReplace
local _math_floor = math.floor

local _clock = {
    m = 0,
    t= 0
}

local _paused = false
local _pausedUntilInterrupts = false
local _interrupts = false

local _queuedEnableInterrupts = false
local _queuedDisableInterrupts = false
local _queueChangeActive = false
local _stepCallback = nil

local _interruptDelay = 0

-----------------------------------
-- * Functions
-----------------------------------

registers = {
    a = 0x0,
    b = 0x0,
    c = 0x0,
    d = 0x0,
    e = 0x0,
    h = 0x0,
    l = 0x0,
    f = {
        -- FLAG_ZERO, FLAG_SUBSTRACT, FLAG_HALFCARRY, FLAG_CARRY
        false, false, false, false
    },
    lastPC = 0x0,
    pc = 0x0,
    sp = 0xfffe,
    clock = {
        m = 0,
        t = 0
    }
}

local _registers = registers

function setupCPU()
    _clock = {
        m = 0,
        t = 0
    }

    registers = {
        a = 0x0,
        b = 0x0,
        c = 0x0,
        d = 0x0,
        e = 0x0,
        h = 0x0,
        l = 0x0,
        f = {
            -- FLAG_ZERO, FLAG_SUBSTRACT, FLAG_HALFCARRY, FLAG_CARRY
            false, false, false, false
        },
        pc = 0x0,
        sp = 0xfffe,
        clock = {
            m = 0,
            t = 0
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
            a = 0x0,
            b = 0x0,
            c = 0x0,
            d = 0x0,
            e = 0x0,
            h = 0x0,
            l = 0x0,
            f = {
                -- FLAG_ZERO, FLAG_SUBSTRACT, FLAG_HALFCARRY, FLAG_CARRY
                false, false, false, false
            },
            pc = 0x0,
            sp = 0xfffe,
            clock = {
                m = 0,
                t = 0
            }
        }
    else
        registers = {
            a = (isGameBoyColor()) and 0x11 or 0x01,
            b = 0x00,
            c = 0x13,
            d = 0x00,
            e = 0xd8,
            h = 0x01,
            l = 0x4d,
            f = {
                -- FLAG_ZERO, FLAG_SUBSTRACT, FLAG_HALFCARRY, FLAG_CARRY
                true, false, true, true
            },
            pc = 0x100,
            sp = 0xfffe,
            clock = {
                m = 0,
                t = 0
            }
        }
    end

    _registers = registers

    if (_stepCallback) then
        removeEventHandler("onClientPreRender", root, _stepCallback)
        _stepCallback = nil
    end
end

function pauseCPU()
    _paused = true
end

function resumeCPU()
    _paused = false
    _pausedUntilInterrupts = false
end

function isCPUPaused()
    return _paused
end

function haltCPU(haltScreen)
    _paused = true
    _pausedUntilInterrupts = true
end

function enableInterrupts()
    _queuedEnableInterrupts = true
end

function disableInterrupts()
    _queuedDisableInterrupts = true
end

function resetInterrupts()
    _interrupts = false
end

function setInterrupts()
    _interrupts = true
end

function cpuStep()
    if (isDebuggerEnabled() and not debuggerStep()) then
        return
    end

    local nextOpcode = mmuReadByte(_registers.pc)

    _registers.lastPC = _registers.pc

    _registers.clock.m = 0
    _registers.clock.t = 0
    _registers.pc = _registers.pc + 1

    local opcode = _opcodes[nextOpcode + 1]

    if (opcode == nil) then
        pauseCPU()
        _registers.pc = _registers.pc - 1
        return Log.error("CPU", "Unknown opcode 0x%s at 0x%s", string.format("%.2x", nextOpcode), string.format("%.2x", _registers.pc))
    end

    opcode()

    _clock.m = _clock.m + _registers.clock.m
    _clock.t = _clock.t + _registers.clock.t
end

function readTwoRegisters(r1, r2)
    local value = _registers[r1]
    value = value * 256

    if (r2 == "f") then
        value = value + (
            ((_registers.f[1]) and 1 or 0) * 128 +
            ((_registers.f[2]) and 1 or 0) * 64 +
            ((_registers.f[3]) and 1 or 0) * 32 +
            ((_registers.f[4]) and 1 or 0) * 16
        )
    else
        value = value + _registers[r2]
    end

    return value
end

function writeTwoRegisters(r1, r2, value)
    _registers[r1] = _math_floor(_bitAnd(0xFF00, value) / 256)

    if (r2 == "f") then
        _registers.f[1] = (_bitAnd(value, 0x80) > 0)
        _registers.f[2] = (_bitAnd(value, 0x40) > 0)
        _registers.f[3] = (_bitAnd(value, 0x20) > 0)
        _registers.f[4] = (_bitAnd(value, 0x10) > 0)
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

function runCPU()
    if (_stepCallback) then
        removeEventHandler("onClientPreRender", root, _stepCallback)
        _stepCallback = nil
    end

    _stepCallback = function(delta)
        if (not _paused) then
            local currentCycles = 0

            --while(currentCycles < 1000) do
            while(currentCycles < 69905) do
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

                if (not _paused) then
                    cpuStep()
                end

                local ticks = _registers.clock.m

                if (_paused) then
                    ticks = 1
                end

                timerStep(ticks)
                gpuStep(ticks)

                if ((_interrupts and interrupts and interruptFlags and _interruptDelay <= 0) and not _pausedUntilInterrupts) then
                    local maskedFlags = _bitAnd(interrupts, interruptFlags)

                    if (_bitAnd(maskedFlags, 0x01) ~= 0) then
                        _interrupts = false
                        interruptFlags = _bitAnd(interruptFlags, 0xFE)
                        mmuPushStack(_registers.pc)

                        _registers.pc = 0x40

                        _registers.clock.m = 5
                        _registers.clock.t = 20
                    elseif (_bitAnd(maskedFlags, 0x02) ~= 0) then
                        _interrupts = false
                        interruptFlags = _bitAnd(interruptFlags, 0xFD)
                        mmuPushStack(_registers.pc)

                        _registers.pc = 0x48

                        _registers.clock.m = 5
                        _registers.clock.t = 20
                    elseif (_bitAnd(maskedFlags, 0x04) ~= 0) then
                        _interrupts = false
                        interruptFlags = _bitAnd(interruptFlags, 0xFB)
                        mmuPushStack(_registers.pc)

                        _registers.pc = 0x50

                        _registers.clock.m = 5
                        _registers.clock.t = 20
                    elseif (_bitAnd(maskedFlags, 0x08) ~= 0) then
                        _interrupts = false
                        interruptFlags = _bitAnd(interruptFlags, 0xF7)
                        mmuPushStack(_registers.pc)

                        _registers.pc = 0x58

                        _registers.clock.m = 5
                        _registers.clock.t = 20
                    elseif (_bitAnd(maskedFlags, 0x16) ~= 0) then
                        _interrupts = false
                        interruptFlags = _bitAnd(interruptFlags, 0xEF)
                        mmuPushStack(_registers.pc)

                        _registers.pc = 0x60

                        _registers.clock.m = 5
                        _registers.clock.t = 20
                    end

                    _interruptDelay = 0
                elseif (interrupts and interruptFlags and _pausedUntilInterrupts) then
                    _pausedUntilInterrupts = false
                    _paused = false
                elseif (_interruptDelay > 0) then
                    _interruptDelay = _interruptDelay - _registers.clock.t
                end

                currentCycles = currentCycles + _registers.clock.t
            end
        end

        if (eramUpdated and (getTickCount() - eramLastUpdated) > 1000) then
            mmuSaveExternalRam()
        end
    end

    addEventHandler("onClientPreRender", root, _stepCallback)
end

function getCPUClock()
    return _clock
end