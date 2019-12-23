GPU = Class()

-----------------------------------
-- * Functions
-----------------------------------

function GPU:create(gameboy)
    self.gameboy = gameboy
    self.vram = {}
end
