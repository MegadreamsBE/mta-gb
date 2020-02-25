GameBoy = Class()

-----------------------------------
-- * Constants
-----------------------------------

local ROM_PATH = "data/cpu_instrs.gb"

-----------------------------------
-- * Functions
-----------------------------------

function GameBoy:create()
    self.gpu = GPU(self)
    self.cpu = CPU(self)
end

function GameBoy:load(romPath)
    self.rom = Rom(romPath)

    if (not self.rom:load()) then
        Log.error("GameBoy", "Unable to load ROM.")
    end
end

function GameBoy:start()
    self.gpu:reset()
    self.cpu:reset()

    if (self.rom ~= nil) then
        self.cpu:loadRom(self.rom)
    end

    self.cpu:run()
end

function GameBoy:pause()
    self.cpu:pause()
end

function GameBoy:stop()
    self:pause()
    self.gpu:reset()
    self.cpu:reset()
end

function GameBoy:attachDebugger(debugger)
    self.debugger = debugger
    self.debugger:start(self)
end

-----------------------------------
-- * Events
-----------------------------------

addEventHandler("onClientResourceStart", resourceRoot, function()
    local gameboy = GameBoy()
    local debugger = Debugger()

    --debugger:breakpoint(0x1d)

    gameboy:load(ROM_PATH)
    gameboy:attachDebugger(debugger)
    gameboy:start()
end)
