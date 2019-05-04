Core = Class()

-----------------------------------
-- * Constants
-----------------------------------

ROM_PATH = "data/Tetris.gb"

-----------------------------------
-- * Functions
-----------------------------------

function Core.load()
    local rom = ByteStream(ROM_PATH)
end

-----------------------------------
-- * Events
-----------------------------------

addEventHandler("onClientResourceStart", resourceRoot, Core.load)
