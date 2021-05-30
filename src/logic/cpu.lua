CPU = Class()

-----------------------------------
-- * Locals
-----------------------------------

local opcodes = GameBoy.opcodes

local _bitAnd = bitAnd
local _bitReplace = bitReplace
local _math_floor = math.floor

-----------------------------------
-- * Functions
-----------------------------------

function CPU:create(gameboy)
    self.clock = {
        m = 0,
        t = 0
    }

    self.registers = {
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

    self.gameboy = gameboy
    self.mmu = MMU(self, gameboy.gpu)

    self.paused = false
    self.interrupts = false
end

function CPU:loadRom(rom)
    self.mmu:loadRom(rom)
end

function CPU:reset()
    self.mmu:reset()
    self.gameboy.gpu:reset()

    self.interrupts = true
    self.queuedEnableInterrupts = false
    self.queuedDisableInterrupts = false

    -- If we have a BIOS we want to ensure all registers are zeroed out.
    if (#self.mmu.bios > 0) then
        self.registers = {
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
        self.registers = {
            a = 0x01,
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

    if (self.stepCallback) then
        removeEventHandler("onClientPreRender", root, self.stepCallback)
        self.stepCallback = nil
    end
end

function CPU:pause()
    self.paused = true
end

function CPU:halt(haltScreen)

end

function CPU:enableInterrupts()
    self.queuedEnableInterrupts = true
end

function CPU:disableInterrupts()
    self.queuedDisableInterrupts = true
end

function CPU:step()
    if (self.gameboy.debugger and not self.gameboy.debugger:step()) then
        return
    end

    local nextOpcode = self.mmu:readByte(self.registers.pc)

    self.registers.clock.m = 0
    self.registers.clock.t = 0
    self.registers.pc = self.registers.pc + 1

    local opcode = opcodes[nextOpcode]

    if (opcode == nil) then
        self:pause()
        self.registers.pc = self.registers.pc - 1
        return Log.error("CPU", "Unknown opcode 0x%s at 0x%s", string.format("%.2x", nextOpcode), string.format("%.2x", self.registers.pc))
    end

    opcode(self)

    self.clock.m = self.clock.m + self.registers.clock.m
    self.clock.t = self.clock.t + self.registers.clock.t

    local ticks = self.registers.clock.m

    self.gameboy.timer:step(ticks)
    self.gameboy.gpu:step(ticks)

    if (self.queuedEnableInterrupts) then
        self.queuedEnableInterrupts = false
        self.queuedDisableInterrupts = false
        self.interrupts = true
    end

    if (self.queuedDisableInterrupts) then
        self.queuedEnableInterrupts = false
        self.queuedDisableInterrupts = false
        self.interrupts = false
    end
end

function CPU:readTwoRegisters(r1, r2)
    local value = self.registers[r1]
    value = value * 256

    if (r2 == "f") then
        value = value + (
            ((self.registers.f[1]) and 1 or 0) * 128 +
            ((self.registers.f[2]) and 1 or 0) * 64 +
            ((self.registers.f[3]) and 1 or 0) * 32 +
            ((self.registers.f[4]) and 1 or 0) * 16
        )
    else
        value = value + self.registers[r2]
    end

    return value
end

function CPU:writeTwoRegisters(r1, r2, value)
    self.registers[r1] = _math_floor(_bitAnd(0xFF00, value) / 256)

    if (r2 == "f") then
        self.registers.f[1] = (_bitAnd(value, 0x80) > 0)
        self.registers.f[2] = (_bitAnd(value, 0x40) > 0)
        self.registers.f[3] = (_bitAnd(value, 0x20) > 0)
        self.registers.f[4] = (_bitAnd(value, 0x10) > 0)
    else
        self.registers[r2] = _bitAnd(0x00FF, value)
    end
end

function CPU:requestInterrupt(interrupt)
    self.mmu.interruptFlags = _bitReplace(self.mmu.interruptFlags, 1, interrupt, 1)
end

function CPU:run()
    if (self.stepCallback) then
        removeEventHandler("onClientPreRender", root, self.stepCallback)
        self.stepCallback = nil
    end

    self.stepCallback = function(delta)
        if (not self.paused) then
            local currentCycles = 0

            --while(currentCycles < 1000) do
            while(currentCycles < 69905) do
                if (self.paused) then
                    break
                end

                self:step()
                currentCycles = currentCycles + self.registers.clock.t

                if (self.interrupts and self.mmu.interrupts and self.mmu.interruptFlags) then
                    local maskedFlags = _bitAnd(self.mmu.interrupts, self.mmu.interruptFlags)

                    if (_bitAnd(maskedFlags, 0x01) ~= 0) then
                        self.interrupts = false
                        self.mmu.interruptFlags = _bitAnd(self.mmu.interruptFlags, 0xFE)
                        self.mmu:pushStack(self.registers.pc)

                        self.registers.pc = 0x40

                        self.registers.clock.m = 3
                        self.registers.clock.t = 12
                    elseif (_bitAnd(maskedFlags, 0x02) ~= 0) then
                        self.interrupts = false
                        self.mmu.interruptFlags = _bitAnd(self.mmu.interruptFlags, 0xFD)
                        self.mmu:pushStack(self.registers.pc)

                        self.registers.pc = 0x48

                        self.registers.clock.m = 3
                        self.registers.clock.t = 12
                    elseif (_bitAnd(maskedFlags, 0x04) ~= 0) then
                        self.interrupts = false
                        self.mmu.interruptFlags = _bitAnd(self.mmu.interruptFlags, 0xFB)
                        self.mmu:pushStack(self.registers.pc)

                        self.registers.pc = 0x50

                        self.registers.clock.m = 3
                        self.registers.clock.t = 12
                    elseif (_bitAnd(maskedFlags, 0x08) ~= 0) then
                        self.interrupts = false
                        self.mmu.interruptFlags = _bitAnd(self.mmu.interruptFlags, 0xF7)
                        self.mmu:pushStack(self.registers.pc)

                        self.registers.pc = 0x58

                        self.registers.clock.m = 3
                        self.registers.clock.t = 12
                    elseif (_bitAnd(maskedFlags, 0x16) ~= 0) then
                        self.interrupts = false
                        self.mmu.interruptFlags = _bitAnd(self.mmu.interruptFlags, 0xEF)
                        self.mmu:pushStack(self.registers.pc)

                        self.registers.pc = 0x60

                        self.registers.clock.m = 3
                        self.registers.clock.t = 12
                    else
                        self.interrupts = true
                    end
                end
            end
        end
    end

    addEventHandler("onClientPreRender", root, self.stepCallback)
end
