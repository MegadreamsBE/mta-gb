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

local _bitExtract = bitExtract
local _math_floor = math.floor
local _string_format = string.format

local binaryFormat = function(value, minLen)
    local binaryFormat = ""
    local num = value
    local bits = {}

    if (num == 0) then
        bits = {0, 0, 0, 0}
    end

    while num > 0 do
        local rest = num % 2
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

function Debugger:create()
    self.gameboy = nil
    self.debuggingBios = true
    self.disassembler = Disassembler()

    self.breakpoints = {}
    self.debuggerInducedPause = false

    self.memoryPointerMemory = {}

    self.currentMenu = 0
    self.debugMemoryPointer = -1
end

function Debugger:start(gameboy)
    self.gameboy = gameboy
    self.disassembler:load(self.gameboy.cpu.mmu.BIOS)

    if (RENDER) then
        addEventHandler("onClientRender", root, function()
            self:render()
        end)

        bindKey("f3", "up", function()
            self:performStep()
            self.debugMemoryPointer = -1
        end)

        bindKey("f4", "up", function()
            self.debuggerInducedPause = true
            self.debugMemoryPointer = -1
            self.gameboy.cpu:pause()
        end)

        bindKey("f5", "up", function()
            self.debuggerInducedPause = false
            self.gameboy.cpu.paused = false
            self.debugMemoryPointer = -1
        end)

        bindKey("arrow_u", "up", function()
            if (not self.gameboy.cpu.paused) then
                return
            end

            if (self.debugMemoryPointer == -1) then
                self.debugMemoryPointer = self.gameboy.cpu.registers.pc
            end

            self.debugMemoryPointer = self.debugMemoryPointer - 1

            if (self.debugMemoryPointer < 0) then
                self.debugMemoryPointer = 0
            end
        end)

        bindKey("arrow_d", "up", function()
            if (not self.gameboy.cpu.paused) then
                return
            end

            if (self.debugMemoryPointer == -1) then
                self.debugMemoryPointer = self.gameboy.cpu.registers.pc
            end

            self.debugMemoryPointer = self.debugMemoryPointer + 1

            if (self.debugMemoryPointer > self.gameboy.cpu.mmu.MEMORY_SIZE) then
                self.debugMemoryPointer = self.gameboy.cpu.mmu.MEMORY_SIZE
            end
        end)

        bindKey("arrow_l", "up", function()
            if (self.debugMemoryPointer == -1 or not self.gameboy.cpu.paused) then
                return
            end

            self.memoryPointerMemory[self.currentMenu] = self.debugMemoryPointer
            self.currentMenu = self.currentMenu - 1

            if (self.currentMenu < 0) then
                self.currentMenu = 0
            end

            if (self.memoryPointerMemory[self.currentMenu] ~= nil) then
                self.debugMemoryPointer = self.memoryPointerMemory[self.currentMenu]
            else
                self.debugMemoryPointer = self.gameboy.cpu.registers.pc
            end
        end)

        bindKey("arrow_r", "up", function()
            if (self.debugMemoryPointer == -1 or not self.gameboy.cpu.paused) then
                return
            end

            self.memoryPointerMemory[self.currentMenu] = self.debugMemoryPointer
            self.currentMenu = self.currentMenu + 1

            if (self.currentMenu > 1) then
                self.currentMenu = 1
            end

            if (self.memoryPointerMemory[self.currentMenu] ~= nil) then
                self.debugMemoryPointer = self.memoryPointerMemory[self.currentMenu]
            else
                self.debugMemoryPointer = self.gameboy.cpu.registers.pc
            end
        end)
    end
end

function Debugger:step()
    if (self.gameboy == nil) then
        return true
    end

    if (self.breakpoints[self.gameboy.cpu.registers.pc] and not self.debuggerInducedPause) then
        self.gameboy.cpu:pause()
        self.debuggerInducedPause = true
        return false
    end

    if (self.debuggingBios and (not self.gameboy.cpu.mmu.inBios
        or self.gameboy.cpu.registers.pc == 0x100)) then
        self.debuggingBios = false
        self.disassembler:load(self.gameboy.rom:getData())
    end

    return true
end

function Debugger:performStep()
    if (self.debuggerInducedPause) then
        self.gameboy.cpu:step()
        self.gameboy.cpu:pause() -- Ensuring we are still paused
    end
end

function Debugger:render()
    if (self.gameboy == nil) then
        return
    end

    local gpu = self.gameboy.gpu

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
        local romMemoryX = romMemoryWindowStartX + (10 * (1920 / SCREEN_WIDTH))
        local romMemoryY = romMemoryWindowStartY + (yPadding / 2)
        local renderLineCount = (romMemoryWindowHeight / dxGetFontHeight(1, "default-bold"))

        local romMemorySize = cpu.mmu.MEMORY_SIZE
        local startValue = _math_floor(cpu.registers.pc - (renderLineCount * 0.5))

        if (startValue < 0) then
            startValue = 0
        end

        if (self.debugMemoryPointer ~= -1 and self.currentMenu == 0) then
            startValue = _math_floor(self.debugMemoryPointer - (renderLineCount * 0.5))
        end

        for i=startValue, romMemorySize do
            local romMemoryValue = cpu.mmu:readByte(i)
            local r, g, b = 255, 255, 255

            if (i == cpu.registers.pc) then
                r, g, b = 11, 51, 255
            elseif (i == self.debugMemoryPointer and self.currentMenu == 0) then
                r, g, b = 255, 51, 11
            end

            dxDrawText(_string_format("%.4x", i):upper()..": ".._string_format("%.2x", romMemoryValue):upper()
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
        local startValue = _math_floor(cpu.registers.pc - (renderLineCount * 0.5))

        if (self.debugMemoryPointer ~= -1 and self.currentMenu == 1) then
            startValue = _math_floor(self.debugMemoryPointer - (renderLineCount * 0.5))
        end

        if (startValue < 0) then
            startValue = 0
        end

        for i=startValue, cpu.mmu.MEMORY_SIZE do
            local romValue = rom[i + 1]

            if (romValue ~= nil) then
                local r, g, b = 255, 255, 255

                if (i == cpu.registers.pc) then
                    r, g, b = 11, 51, 255
                elseif (i == self.debugMemoryPointer and self.currentMenu == 1) then
                    r, g, b = 255, 51, 11
                end

                dxDrawText(_string_format("%.4x", i):upper()..": "..romValue, romX, romY,
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
                local value = cpu.registers[registerPair[1]] * 128

                if (registerPair[2] == "f") then
                    value = value + (
                        ((cpu.registers.f[1]) and 1 or 0) * 128 +
                        ((cpu.registers.f[2]) and 1 or 0) * 64 +
                        ((cpu.registers.f[3]) and 1 or 0) * 32 +
                        ((cpu.registers.f[4]) and 1 or 0) * 16
                    )
                else
                    value = value + cpu.registers[registerPair[2]]
                end

                dxDrawText(registerPair[1]:upper()..registerPair[2]:upper()
                    .." = ".._string_format("%.4x", value):upper()
                    .. " | "..binaryFormat(value, 16), registersX, registersY,
                    registersWindowStartX + registersWindowWidth - (10 * (1920 / SCREEN_WIDTH)), 0, tocolor(0, 0, 0), 1, "default-bold")
            else
                local value = cpu.registers[registerPair]

                dxDrawText(registerPair:upper()
                    .." = ".._string_format("%.4x", value):upper()
                    .. " | "..binaryFormat(value, 16), registersX, registersY,
                    registersWindowStartX + registersWindowWidth - (10 * (1920 / SCREEN_WIDTH)), 0, tocolor(0, 0, 0), 1, "default-bold")
            end

            registersY = registersY + yPadding
        end

        registersY = registersY + yPadding

        for i=0xFF40, 0xFF52 do
        --for i=0x8010, 0x802F do
            dxDrawText("0x".._string_format("%.4x", i):upper()..": "
                .._string_format("%.2x", cpu.mmu:readByte(i)):upper(), registersX, registersY,
                registersWindowStartX + registersWindowWidth -
                (10 * (1920 / SCREEN_WIDTH)), 0, tocolor(0, 0, 0), 1, "default-bold")

            registersY = registersY + yPadding
        end

        dxDrawText("Stack: ", registersX, registersY,
            registersWindowStartX + registersWindowWidth -
            (10 * (1920 / SCREEN_WIDTH)), 0, tocolor(0, 0, 0), 1, "default-bold")

        registersY = registersY + yPadding

        for _, address in pairs(cpu.mmu.stackDebug) do
            dxDrawText("0x".._string_format("%.8x", address):upper(), registersX, registersY,
                registersWindowStartX + registersWindowWidth -
                (10 * (1920 / SCREEN_WIDTH)), 0, tocolor(0, 0, 0), 1, "default-bold")

            registersY = registersY + yPadding
        end
    end

    --[[local color =
        {{255, 255, 255}, {192, 192, 192}, {96, 96, 96}, {0, 0, 0}}

    local currentX = romMemoryWindowStartX
    local currentY = romMemoryWindowStartY + romMemoryWindowHeight

    local size = 2
    local palette = cpu.mmu:readByte(0xFF47)

    for tile=0, 384 do
        local address = 0x8000 + (tile * 16)

        for row=1, 8 do
            local byte1 = cpu.mmu:readByte(address)
            local byte2 = cpu.mmu:readByte(address + 1)

            for column=1, 8 do
                local paletteId = ((_bitExtract(byte2, 8 - column, 1) == 1) and 2 or 0)
                    + ((_bitExtract(byte1, 8 - column, 1) == 1) and 1 or 0)

                local colorIndex = _bitExtract(palette, 8 - (2 * paletteId), 2)
                columnColor = color[colorIndex + 1]

                dxDrawRectangle(currentX + column * size, currentY + row * size, size, size,
                    tocolor(columnColor[1], columnColor[2], columnColor[3]))
            end

            address = address + 2
        end

        currentX = currentX + (8 * size) + 2

        if (currentX > romMemoryWindowStartX + screenWidth) then
            currentX = romMemoryWindowStartX
            currentY = currentY + (8 * size) + 2
        end
    end]]
end

function Debugger:breakpoint(address)
    self.breakpoints[address] = true
end
