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
local _readByteSwitch = false
local _writeByteSwitch = false

local _frequencyToCounter = {
    [1] = 1024,
    [2] = 16,
    [3] = 64,
    [4] = 256,
}

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
            _writeByteSwitch[0xFF05](0xFF05, _readByteSwitch[0xFF05](0xFF05) + 1)
        end
    end

    timerDividerRegister = 0
    _counter = 0
end

function handleTACGlitch(oldState, newState, oldFrequency, newFrequency)
    local glitch = false

    if (oldState) then
        if (newState) then
            glitch = ((_bitAnd(_counter, _frequencyToCounter[oldFrequency + 1] / 2) ~= 0) and (_bitAnd(_counter, _frequencyToCounter[newFrequency + 1] / 2) == 0))
        else
            glitch = (_bitAnd(_counter, _frequencyToCounter[oldFrequency + 1] / 2) ~= 0)
        end
    end
            
    if (glitch) then
        _writeByteSwitch[0xFF05](0xFF05, _readByteSwitch[0xFF05](0xFF05) + 1)

        if (_readByteSwitch[0xFF05](0xFF05) == 0xff) then
            _writeByteSwitch[0xFF05](0xFF05, _readByteSwitch[0xFF06](0xFF06))
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
        local frequency = _frequencyToCounter[timerClockFrequency + 1]
        local tima = _readByteSwitch[0xFF05](0xFF05)

        while (_counter >= frequency) do
            _counter = _counter - frequency
            tima = tima + 1
            
            if (tima == 0xff) then
                tima = _readByteSwitch[0xFF06](0xFF06)
                requestInterrupt(2)
            end
        end

        _writeByteSwitch[0xFF05](0xFF05, tima)
    end

    if (_counter > 0xffff) then
        _counter = _counter - 0x10000
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
        _readByteSwitch = readByteSwitch
        _writeByteSwitch = writeByteSwitch
    end
)