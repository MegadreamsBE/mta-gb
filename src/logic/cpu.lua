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
        l = 0,
        f = 0,
        pc = 0,
        sp = 0,
        clock = {
            m = 0,
            t = 0
        }
    }

    self.gameboy = gameboy
    self.mmu = MMU()
end

function CPU:loadRom(romData)
    self.mmu:loadRom(romData)
end

function CPU:reset()
    self.mmu:reset()
end
