-----------------------------------
-- * Locals
-----------------------------------

local _bitExtract = bitExtract
local _bitReplace = bitReplace
local _bitLShift = bitLShift
local _bitRShift = bitRShift
local _bitOr = bitOr
local _bitAnd = bitAnd

local _counter = 0

-----------------------------------
-- * Functions
-----------------------------------

timerClockEnabled = false
timerClockFrequency = 0
timerDelayTicks = 0
timerDividerRegister = 0

function setupTimer()
    timerClockEnabled = false
    _counter = 0

    timerClockFrequency = 3
    timerDelayTicks = 0
    timerDividerRegister = 0
end

function resetTimer()
    timerClockEnabled = false
    _doRequestInterrupt = false
    _counter = 0
    timerDelayTicks = 0
 
    timerClockFrequency = 3
    timerDividerRegister = 0
end

function getCounterFromFrequency(frequency)
    if (frequency == 0) then
        return 1024
    elseif (frequency == 1) then
        return 16
    elseif (frequency == 2) then
        return 64
    elseif (frequency == 3) then
        return 256
    end

    return 256
end

function resetTimerClockFrequency(frequency)
    timerClockFrequency = frequency
end

function resetTimerDivider()
    if (timerClockEnabled) then
        if (timerDividerRegister == 1) then
            mmuWriteByte(0xFF05, mmuReadByte(0xFF05) + 1)
        end
    end

    timerDividerRegister = 0
    _counter = 0
end

function handleTACGlitch(oldState, newState, oldFrequency, newFrequency)
    local glitch = false

    if (oldState) then
        if (newState) then
            glitch = ((_bitAnd(_counter, getCounterFromFrequency(oldFrequency) / 2) ~= 0) and (_bitAnd(_counter, getCounterFromFrequency(newFrequency) / 2) == 0))
        else
            glitch = (_bitAnd(_counter, getCounterFromFrequency(oldFrequency) / 2) ~= 0)
        end
    end
            
    if (glitch) then
        mmuWriteByte(0xFF05, mmuReadByte(0xFF05) + 1)

        if (mmuReadByte(0xFF05) == 0xff) then
            mmuWriteByte(0xFF05, mmuReadByte(0xFF06))
            requestInterrupt(2)
        end
    end
end

function timerStep(ticks)
    _counter = _counter + ticks

    if (_counter > 0xffff) then
        _counter = _counter - 0xffff
    end

    if (_counter > 0 and (_counter % 0xff) < ticks) then
        timerDividerRegister = (timerDividerRegister + 1) % 0x100
    end

    if (timerClockEnabled) then
        if (_counter > 0 and (_counter % getCounterFromFrequency(timerClockFrequency)) < ticks) then
            mmuWriteByte(0xFF05, mmuReadByte(0xFF05) + 1)

            if (mmuReadByte(0xFF05) == 0xff) then
                mmuWriteByte(0xFF05, mmuReadByte(0xFF06))
                requestInterrupt(2)
            end
        end
    end
end