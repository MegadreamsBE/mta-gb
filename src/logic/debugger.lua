Debugger = Class()

-----------------------------------
-- * Constants
-----------------------------------

local RENDER = true
local SCREEN_WIDTH, SCREEN_HEIGHT = guiGetScreenSize()

local DEBUGGER_WIDTH, DEBUGGER_HEIGHT = 1280, 768

local DEBUGGER_REGISTERS = {
    {"a", "f"},
    {"b", "c"},
    {"d", "e"},
    {"h", "l"},
    "sp", "pc"
}

-----------------------------------
-- * Functions
-----------------------------------

function Debugger:create(gameboy)
    self.gameboy = gameboy

    self.breakpoints = {}
    self.debuggerInducedPause = false

    if (RENDER) then
        addEventHandler("onClientRender", root, function()
            self:render()
        end)

        bindKey("f3", "down", function()
            self:performStep()
        end)
    end
end

function Debugger:step()
    if (self.breakpoints[self.gameboy.cpu.registers.pc]) then
        self.gameboy.cpu:pause()
        self.debuggerInducedPause = true
    end
end

function Debugger:performStep()
    if (self.debuggerInducedPause) then
        self.gameboy.cpu:step()
        self.gameboy.cpu:pause() -- Ensuring we are still paused
    end
end

function Debugger:render()
    local screenStartX = (SCREEN_WIDTH / 2) - ((DEBUGGER_WIDTH * (1920 / SCREEN_WIDTH)) / 2)
    local screenStartY = (SCREEN_HEIGHT / 2) - ((DEBUGGER_HEIGHT * (1920 / SCREEN_WIDTH)) / 2)

    local screenWidth = DEBUGGER_WIDTH * (1920 / SCREEN_WIDTH)
    local screenHeight = DEBUGGER_HEIGHT * (1920 / SCREEN_WIDTH)

    dxDrawRectangle(screenStartX, screenStartY, screenWidth, screenHeight
        , tocolor(0, 0, 0, 200))

    local romWindowStartX = screenStartX + (50 * (1920 / SCREEN_WIDTH))
    local romWindowStartY = screenStartY + (50 * (1920 / SCREEN_WIDTH))

    local romWindowWidth = ((DEBUGGER_WIDTH * 0.70) * (1920 / SCREEN_WIDTH))
    local romWindowHeight = ((DEBUGGER_HEIGHT - 100) * (1920 / SCREEN_WIDTH))

    dxDrawRectangle(romWindowStartX, romWindowStartY, romWindowWidth, romWindowHeight,
        tocolor(255, 255, 255, 150))

    local cpu = self.gameboy.cpu

    local yPadding = (20 * (1920 / SCREEN_WIDTH))

    if (cpu) then
        local memory = cpu.mmu.memory

        local memoryX = romWindowStartX + (10 * (1920 / SCREEN_WIDTH))
        local memoryY = romWindowStartY + (yPadding / 2)
        local renderLineCount = (romWindowHeight / dxGetFontHeight(1, "default"))

        local memorySize = #memory
        local startValue = math.floor(cpu.registers.pc - (renderLineCount * 0.5))

        if (startValue < 0) then
            startValue = 0
        end

        for i=startValue, memorySize do
            local memoryValue = memory[i + 1] or 0x0
            local r, g, b = 0, 0, 0

            if (i == cpu.registers.pc) then
                r, g, b = 11, 51, 86
            end

            dxDrawText(string.format("%.4x", i):upper()..": "..string.format("%.2x", memoryValue):upper()
                , memoryX, memoryY,
                romWindowStartX + romWindowWidth - (10 * (1920 / SCREEN_WIDTH)), 0, tocolor(r, g, b), 1, "default")

            memoryY = memoryY + yPadding

            if (memoryY > (romWindowStartY + romWindowHeight - yPadding)) then
                break
            end
        end
    end

    local registersWindowStartX = (romWindowStartX + romWindowWidth) + (10 * (1920 / SCREEN_WIDTH))
    local registersWindowStartY = screenStartY + (50 * (1920 / SCREEN_WIDTH))

    local registersWindowWidth = (DEBUGGER_WIDTH - (registersWindowStartX - screenStartX)) - (50 * (1920 / SCREEN_WIDTH))
    local registersWindowHeight = ((DEBUGGER_HEIGHT - 100) * (1920 / SCREEN_WIDTH))

    dxDrawRectangle(registersWindowStartX, registersWindowStartY, registersWindowWidth, registersWindowHeight,
        tocolor(255, 255, 255, 150))

    if (cpu) then
        local registersX = registersWindowStartX + (10 * (1920 / SCREEN_WIDTH))
        local registersY = registersWindowStartY + (yPadding / 2)

        for _, registerPair in pairs(DEBUGGER_REGISTERS) do
            if (type(registerPair) == "table") then
                local value = cpu.registers[registerPair[2]]
                value = value + bitLShift(cpu.registers[registerPair[1]], 8)

                dxDrawText(registerPair[1]:upper()..registerPair[2]:upper()
                    .." = "..string.format("%.4x", value):upper(), registersX, registersY,
                    registersWindowStartX + registersWindowWidth - (10 * (1920 / SCREEN_WIDTH)), 0, tocolor(0, 0, 0), 1, "default")
            else
                local value = cpu.registers[registerPair]

                dxDrawText(registerPair:upper()
                    .." = "..string.format("%.4x", value):upper(), registersX, registersY,
                    registersWindowStartX + registersWindowWidth - (10 * (1920 / SCREEN_WIDTH)), 0, tocolor(0, 0, 0), 1, "default")
            end

            registersY = registersY + yPadding
        end
    end
end

function Debugger:breakpoint(address)
    self.breakpoints[address] = true
end
