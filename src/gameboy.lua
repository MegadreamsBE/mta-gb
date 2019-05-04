GameBoy = Class()

-----------------------------------
-- * Constants
-----------------------------------

local ROM_PATH = "data/Tetris.gb"

-----------------------------------
-- * Functions
-----------------------------------

function GameBoy:create()
    self.cpu = CPU()

    if (not self:load(ROM_PATH)) then
        return Log.error("GameBoy", "Unable to load ROM.")
    end

    self:start()
end

function GameBoy:load(romPath)
    self.rom = Rom(romPath)
    return self.rom:load()
end

function GameBoy:start()
    self.cpu:reset()
    self.cpu:loadRom(self.rom:getData())
    self.cpu:run()
end

-----------------------------------
-- * Events
-----------------------------------

addEventHandler("onClientResourceStart", resourceRoot, function()
    GameBoy()
end)
