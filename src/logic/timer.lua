-----------------------------------
-- * Locals
-----------------------------------

local _bitExtract = bitExtract
local _bitReplace = bitReplace
local _bitLShift = bitLShift
local _bitRShift = bitRShift
local _bitAnd = bitAnd

local _counter = 0
local _dividerCounter = 0

local _mmuReadByte = false
local _mmuWriteByte = false

local getCounterFromFrequency = function(frequency)
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

    if (not isBiosLoaded()) then
        timerDividerRegister = 0x20
    end
end

function resetTimerClockFrequency(frequency)
    timerClockFrequency = frequency
end

function resetTimerDivider()
    if (timerClockEnabled) then
        if (timerDividerRegister == 1) then
            _mmuWriteByte(0xFF05, _mmuReadByte(0xFF05) + 1)
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
        _mmuWriteByte(0xFF05, _mmuReadByte(0xFF05) + 1)

        if (_mmuReadByte(0xFF05) == 0xff) then
            _mmuWriteByte(0xFF05, _mmuReadByte(0xFF06))
            requestInterrupt(2)
        end
    end
end

function timerStep(ticks)
    _dividerCounter = _dividerCounter + ticks

    if (_dividerCounter > 4096) then
        timerDividerRegister = (timerDividerRegister + 1) % 0x100
        _dividerCounter = _dividerCounter - 4096
    end

    _counter = _counter + ticks

    if (timerClockEnabled) then
        local frequency = getCounterFromFrequency(timerClockFrequency)

        while (_counter >= frequency) do
            _counter = _counter - frequency

            local tima = _mmuReadByte(0xFF05) + 1

            _mmuWriteByte(0xFF05, tima)

            if (tima == 0xff) then
                _mmuWriteByte(0xFF05, _mmuReadByte(0xFF06))
                requestInterrupt(2)
            end
        end
    end

    if (_counter > 0xffff) then
        _counter = _counter - 0xffff
    end
end

function saveTimerState()
    return {
        counter = _counter,
        timerClockEnabled = timerClockEnabled,
        timerClockFrequency = timerClockFrequency,
        timerDelayTicks = timerDelayTicks,
        timerDividerRegister = timerDividerRegister,
    }
end

function loadTimerState(state)
    _counter = state.counter
    timerClockEnabled = state.timerClockEnabled
    timerClockFrequency = state.timerClockFrequency
    timerDelayTicks = state.timerDelayTicks
    timerDividerRegister = state.timerDividerRegister
end

addEventHandler("onClientResourceStart", resourceRoot,
    function()
        _mmuReadByte = mmuReadByte
        _mmuWriteByte = mmuWriteByte
    end
)