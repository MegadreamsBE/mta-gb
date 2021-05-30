Timer = Class()

-----------------------------------
-- * Locals
-----------------------------------

local _bitExtract = bitExtract
local _bitReplace = bitReplace
local _bitLShift = bitLShift
local _bitRShift = bitRShift
local _bitOr = bitOr
local _bitAnd = bitAnd

-----------------------------------
-- * Functions
-----------------------------------

function Timer:create(gameboy)
    self.gameboy = gameboy

    self.clockEnabled = false
    self.clockFrequency = 0
    self.counter = 1024

    self.dividerRegister = 0
    self.dividerCounter = 0
end

function Timer:reset()
    self.clockEnabled = false
    self.clockFrequency = 0
    self.counter = 1024

    self.dividerRegister = 0
    self.dividerCounter = 0
end

function Timer:resetClockFrequency(frequency)
    self.clockFrequency = frequency

    if (frequency == 0) then
        self.counter = 1024
    elseif (frequency == 1) then
        self.counter = 16
    elseif (frequency == 2) then
        self.counter = 64
    elseif (frequency == 3) then
        self.counter = 256
    end
end

function Timer:step(ticks)
    self.dividerCounter = self.dividerCounter + ticks

    if (self.dividerCounter >= 0xff) then
        self.dividerCounter = 0
        self.dividerRegister = (self.dividerRegister + 1) % 0x100
    end

    if (self.clockEnabled) then
        self.counter = self.counter - ticks

        if (self.counter < 0) then
            local mmu = self.gameboy.cpu.mmu

            if (mmu:readByte(0xFF05) == 0xff) then
                mmu:writeByte(0xFF05, mmu:readByte(0xFF06))
                self.gameboy.cpu:requestInterrupt(2)
            else
                mmu:writeByte(0xFF05, mmu:readByte(0xFF05) + 1)
            end
        end
    end
end