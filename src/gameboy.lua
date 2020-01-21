GameBoy = Class()

-----------------------------------
-- * Constants
-----------------------------------

local ROM_PATH = "data/cpu_instrs.gb"

-----------------------------------
-- * Functions
-----------------------------------

function GameBoy:create()
    self.debugger = Debugger(self)
    self.gpu = GPU(self)
    self.cpu = CPU(self)

    if (not self:load(ROM_PATH)) then
        return Log.error("GameBoy", "Unable to load ROM.")
    end

    self:start()
    self.debugger:start()
    self.debugger:breakpoint(0x0B1A)
end

function GameBoy:load(romPath)
    self.rom = Rom(romPath)
    return self.rom:load()
end

function GameBoy:start()
    self.gpu:reset()
    self.cpu:reset()
    self.cpu:loadRom(self.rom)
    self.cpu:run()
end

-----------------------------------
-- * Events
-----------------------------------

addEventHandler("onClientResourceStart", resourceRoot, function()
    GameBoy()
end)
