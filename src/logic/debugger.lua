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
-- * Locals
-----------------------------------

local binaryFormat = function(value, minLen)
    local binaryFormat = ""
    local num = value
    local bits = {}

    if (num == 0) then
        bits = {0, 0, 0, 0}
    end

    while num > 0 do
        local rest = math.fmod(num, 2)
        bits[#bits + 1] = rest
        num = (num - rest) / 2
    end

    while (#bits < minLen) do
        bits[#bits + 1] = 0
    end

    for index, bit in pairs(bits) do
        binaryFormat = bit..binaryFormat

        if (index % 4 == 0) then
            binaryFormat = " "..binaryFormat
        end
    end

    return binaryFormat
end

-----------------------------------
-- * Functions
-----------------------------------

function Debugger:create(gameboy)
    self.gameboy = gameboy
    self.debuggingBios = true
    self.disassembler = Disassembler()

    self.breakpoints = {}
    self.debuggerInducedPause = false
end

function Debugger:start()
    self.disassembler:load(self.gameboy.cpu.mmu.BIOS)

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

    if (self.debuggingBios and not self.gameboy.cpu.mmu.inBios) then
        self.debuggingBios = false
        self.disassembler:load(self.gameboy.rom)
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

    local romMemoryWindowStartX = screenStartX + (50 * (1920 / SCREEN_WIDTH))
    local romMemoryWindowStartY = screenStartY + (50 * (1920 / SCREEN_WIDTH))

    local romMemoryWindowWidth = 75
    local romMemoryWindowHeight = ((DEBUGGER_HEIGHT - 100) * (1920 / SCREEN_WIDTH))

    dxDrawRectangle(romMemoryWindowStartX, romMemoryWindowStartY, romMemoryWindowWidth, romMemoryWindowHeight,
        tocolor(255, 196, 196, 150))

    local cpu = self.gameboy.cpu

    local yPadding = (20 * (1920 / SCREEN_WIDTH))

    if (cpu) then
        local romMemory = cpu.mmu.rom:getData()

        if (cpu.mmu.inBios) then
            romMemory = cpu.mmu.BIOS
        end

        local romMemoryX = romMemoryWindowStartX + (10 * (1920 / SCREEN_WIDTH))
        local romMemoryY = romMemoryWindowStartY + (yPadding / 2)
        local renderLineCount = (romMemoryWindowHeight / dxGetFontHeight(1, "default-bold"))

        local romMemorySize = #romMemory
        local startValue = math.floor(cpu.registers.pc - (renderLineCount * 0.5))

        if (startValue < 0) then
            startValue = 0
        end

        for i=startValue, romMemorySize do
            local romMemoryValue = romMemory[i + 1] or 0x0
            local r, g, b = 255, 255, 255

            if (i == cpu.registers.pc) then
                r, g, b = 11, 51, 255
            end

            dxDrawText(string.format("%.4x", i):upper()..": "..string.format("%.2x", romMemoryValue):upper()
                , romMemoryX, romMemoryY,
                romMemoryWindowStartX + romMemoryWindowWidth - (10 * (1920 / SCREEN_WIDTH)), 0, tocolor(r, g, b), 1, "default-bold")

            romMemoryY = romMemoryY + yPadding

            if (romMemoryY > (romMemoryWindowStartY + romMemoryWindowHeight - yPadding)) then
                break
            end
        end
    end

    local romWindowStartX = romMemoryWindowStartX + romMemoryWindowWidth
    local romWindowStartY = romMemoryWindowStartY

    local romWindowWidth = ((DEBUGGER_WIDTH * 0.70) * (1920 / SCREEN_WIDTH)) - romMemoryWindowWidth
    local romWindowHeight = romMemoryWindowHeight

    dxDrawRectangle(romWindowStartX, romWindowStartY
        , romWindowWidth, romWindowHeight,
        tocolor(255, 255, 255, 150))

    if (self.disassembler and cpu) then
        local rom = self.disassembler:getData()

        local romX = romWindowStartX + (10 * (1920 / SCREEN_WIDTH))
        local romY = romWindowStartY + (yPadding / 2)
        local renderLineCount = (romWindowHeight / dxGetFontHeight(1, "default-bold"))

        local romSize = #rom
        local startValue = math.floor(cpu.registers.pc - (renderLineCount * 0.5))

        if (startValue < 0) then
            startValue = 0
        end

        for i=startValue, cpu.mmu.MEMORY_SIZE do
            local romValue = rom[i + 1]

            if (romValue ~= nil) then
                local r, g, b = 255, 255, 255

                if (i == cpu.registers.pc) then
                    r, g, b = 11, 51, 255
                end

                dxDrawText(string.format("%.4x", i):upper()..": "..romValue, romX, romY,
                    romWindowStartX + romWindowWidth - (10 * (1920 / SCREEN_WIDTH)),
                    0, tocolor(r, g, b), 1, "default-bold")

                romY = romY + yPadding

                if (romY > (romWindowStartY + romWindowHeight - yPadding)) then
                    break
                end
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
                    .." = "..string.format("%.4x", value):upper()
                    .. " | "..binaryFormat(value, 16), registersX, registersY,
                    registersWindowStartX + registersWindowWidth - (10 * (1920 / SCREEN_WIDTH)), 0, tocolor(0, 0, 0), 1, "default-bold")
            else
                local value = cpu.registers[registerPair]

                dxDrawText(registerPair:upper()
                    .." = "..string.format("%.4x", value):upper()
                    .. " | "..binaryFormat(value, 16), registersX, registersY,
                    registersWindowStartX + registersWindowWidth - (10 * (1920 / SCREEN_WIDTH)), 0, tocolor(0, 0, 0), 1, "default-bold")
            end

            registersY = registersY + yPadding
        end

        registersY = registersY + yPadding

        dxDrawText("Stack: ", registersX, registersY,
            registersWindowStartX + registersWindowWidth -
            (10 * (1920 / SCREEN_WIDTH)), 0, tocolor(0, 0, 0), 1, "default-bold")

        registersY = registersY + yPadding

        for _, address in pairs(cpu.mmu.stackDebug) do
            dxDrawText("0x"..string.format("%.8x", address):upper(), registersX, registersY,
                registersWindowStartX + registersWindowWidth -
                (10 * (1920 / SCREEN_WIDTH)), 0, tocolor(0, 0, 0), 1, "default-bold")

            registersY = registersY + yPadding
        end
    end
end

function Debugger:breakpoint(address)
    self.breakpoints[address] = true
end
