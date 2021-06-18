-----------------------------------
-- * Locals
-----------------------------------

local _bitExtract = bitExtract
local _bitReplace = bitReplace
local _bitLShift = bitLShift
local _bitRShift = bitRShift
local _bitOr = bitOr
local _bitAnd = bitAnd

local _clockEnabled = false
local _counter = 1024
local _dividerCounter = 0

-----------------------------------
-- * Functions
-----------------------------------

timerClockFrequency = 0
timerDividerRegister = 0

function setupTimer()
    _clockEnabled = false
    _counter = 1024
    _dividerCounter = 0

    timerClockFrequency = 0
    timerDividerRegister = 0
end

function resetTimer()
    _clockEnabled = false
    _counter = 1024
    _dividerCounter = 0

    timerClockFrequency = 0
    timerDividerRegister = 0
end

function resetTimerClockFrequency(frequency)
    timerClockFrequency = frequency

    if (frequency == 0) then
        _counter = 1024
    elseif (frequency == 1) then
        _counter = 16
    elseif (frequency == 2) then
        _counter = 64
    elseif (frequency == 3) then
        _counter = 256
    end
end

function timerStep(ticks)
    _dividerCounter = _dividerCounter + ticks

    if (_dividerCounter >= 0xff) then
        _dividerCounter = 0
        timerDividerRegister = (timerDividerRegister + 1) % 0x100
    end

    if (_clockEnabled) then
        _counter = _counter - ticks

        if (_counter < 0) then
            resetTimerClockFrequency(timerClockFrequency)

            if (mmuReadByte(0xFF05) == 0xff) then
                mmuWriteByte(0xFF05, mmuReadByte(0xFF06))
                requestInterrupt(2)
            else
                mmuWriteByte(0xFF05, mmuReadByte(0xFF05) + 1)
            end
        end
    end
end