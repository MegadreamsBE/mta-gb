CPU = Class()

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
        f = 0,
        pc = 0x100, -- Skipping boot
        sp = 0,
        clock = {
            m = 0,
            t = 0
        }
    }

    self.gameboy = gameboy
    self.mmu = MMU()

    self.paused = false
end

function CPU:loadRom(romData)
    self.mmu:loadRom(romData)
end

function CPU:reset()
    self.mmu:reset()

    if (self.stepCallback) then
        removeEventHandler("onClientRender", root, self.stepCallback)
        self.stepCallback = nil
    end
end

function CPU:pause()
    self.paused = true
end

function CPU:step()
    local nextOpcode = self.mmu:readByte(self.registers.pc)

    self.registers.pc = self.registers.pc + 1

    local opcode = GameBoy.opcodes[nextOpcode]

    if (opcode == nil) then
        self:pause()
        return Log.error("CPU", "Unknown opcode: 0x%s at 0x%s", string.format("%x", nextOpcode), string.format("%x", self.registers.pc))
    end

    Log.info("CPU", "Running opcode 0x%s at 0x%s", string.format("%x", nextOpcode), string.format("%x", self.registers.pc))

    opcode(self)
end

function CPU:run()
    if (self.stepCallback) then
        removeEventHandler("onClientRender", root, self.stepCallback)
        self.stepCallback = nil
    end

    self.stepCallback = function()
        if (not self.paused) then
            self:step()
        end
    end

    addEventHandler("onClientRender", root, self.stepCallback)
end
