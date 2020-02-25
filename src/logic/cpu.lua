CPU = Class()

-----------------------------------
-- * Locals
-----------------------------------

local opcodes = GameBoy.opcodes

local _bitAnd = bitAnd
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
        a = 0,
        b = 0,
        c = 0,
        d = 0,
        e = 0,
        h = 0,
        l = 0,
        f = {
            false, false, false, false
        },
        pc = 0,
        sp = 0,
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

    self.registers.a = 0
    self.registers.b = 0
    self.registers.c = 0
    self.registers.d = 0
    self.registers.e = 0
    self.registers.h = 0
    self.registers.l = 0
    self.registers.f = { false, false, false, false }
    self.registers.sp = 0
    self.registers.pc = 0

    if (self.stepCallback) then
        removeEventHandler("onClientPreRender", root, self.stepCallback)
        self.stepCallback = nil
    end
end

function CPU:pause()
    self.paused = true
end

function CPU:step()
    if (self.gameboy.debugger and not self.gameboy.debugger:step()) then
        return
    end

    local nextOpcode = self.mmu:readByte(self.registers.pc)

    self.registers.pc = self.registers.pc + 1

    local opcode = opcodes[nextOpcode]

    if (opcode == nil) then
        self:pause()
        self.registers.pc = self.registers.pc - 1
        return Log.error("CPU", "Unknown opcode: 0x%s at 0x%s", string.format("%.2x", nextOpcode), string.format("%.2x", self.registers.pc))
    end

    opcode(self)

    self.clock.m = self.clock.m + self.registers.clock.m
    self.clock.t = self.clock.t + self.registers.clock.t

    self.gameboy.gpu:step()
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
        self.registers.f[1] = (((value / (2 ^ 7)) % 2) > 1)
        self.registers.f[2] = (((value / (2 ^ 6)) % 2) > 1)
        self.registers.f[3] = (((value / (2 ^ 5)) % 2) > 1)
        self.registers.f[4] = (((value / (2 ^ 4)) % 2) > 1)
    else
        self.registers[r2] = _bitAnd(0x00FF, value)
    end
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
            end
        end
    end

    addEventHandler("onClientPreRender", root, self.stepCallback)
end
