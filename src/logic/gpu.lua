GPU = Class()

-----------------------------------
-- * Functions
-----------------------------------

function GPU:create(gameboy)
    self.gameboy = gameboy
    self.vram = {}
    self.renderTarget = dxCreateRenderTarget(160, 140, true)
end


function GPU:step()
    
end
