package.path = "./?.lua;" .. package.path

require "overrides"

local tickPeriod = 1/60
local accumulator = 0.0
local timeSinceLastFrame = 0.0

function love.load(args)
    love.window.setMode(1920, 1080)

    package.path = "../../?.lua;"..package.path

    require "src/utils/log"
    require "src/utils/utils"
    require "src/utils/switch"

    require "src/logic/opcodes"
    require "src/logic/cpu"
    require "src/logic/gpu"
    require "src/logic/timer"
    require "src/logic/debugger"
    require "src/logic/disassembler"
    require "src/logic/mmu"

    triggerEvent("onClientResourceStart")

    require "src/gameboy"
    require "src/rom"

    setupGameBoy()
    setupDebugger()

    if (gameBoyLoadRom(args[1])) then
        if (isGameBoyColor()) then
            --gameBoyLoadBios("data/gbc_bios.bin")
        else
            --gameBoyLoadBios("data/bios.gb")
        end
    end

    startGameBoy()
    --enableDebugger()

    Log.log = log
end

function love.update(dt)
    accumulator = accumulator + dt
    timeSinceLastFrame = timeSinceLastFrame + dt
end

function love.draw()
    if accumulator >= tickPeriod then
        love.graphics.clear()
        triggerEvent("onClientPreRender", timeSinceLastFrame * 1000)
        triggerEvent("onClientRender")
        acumulator = accumulator - tickPeriod
        timeSinceLastFrame = 0
    end
end

function love.keypressed(key)
    if (key == "up") then
        key = "arrow_u"
    elseif (key == "down") then
        key = "arrow_d"
    elseif (key == "left") then
        key = "arrow_l"
    elseif (key == "right") then
        key = "arrow_r"
    elseif (key == "return" or key == "kpenter") then
        key = "enter"
    end

    triggerKeyEvent(key, "down")
    triggerEvent("onClientKey", key, true)    
end
 
function love.keyreleased(key)
    if (key == "up") then
        key = "arrow_u"
    elseif (key == "down") then
        key = "arrow_d"
    elseif (key == "left") then
        key = "arrow_l"
    elseif (key == "right") then
        key = "arrow_r"
    elseif (key == "return" or key == "kpenter") then
        key = "enter"
    end

    triggerKeyEvent(key, "up")
    triggerEvent("onClientKey", key, false)    
end