Debugger = Class()

-----------------------------------
-- * Constants
-----------------------------------

local RENDER = true
local LOG_TRACE = false
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
local _bitLShift = bitLShift
local _bitOr = bitOr
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
    self.passthrough = false

    self.memoryPointerMemory = {}

    self.currentMenu = 0
    self.debugMemoryPointer = -1

    self.traceFile = nil
    self.nextStepTick = -1
end

function Debugger:start(gameboy)
    self.gameboy = gameboy
    self.disassembler:disassemble(self.gameboy.cpu.mmu)
    self.lastPC = -1

    if (LOG_TRACE) then
        if (self.traceFile) then
            fileClose(self.traceFile)
        end

        if (fileExists("trace.txt")) then
            fileDelete("trace.txt")
        end

        self.traceFile = fileCreate("trace.txt")
    end

    setTimer(function()
        self.disassembler:disassemble(self.gameboy.cpu.mmu)
    end, 1000, 0)

    if (RENDER) then
        addEventHandler("onClientRender", root, function()
            self:render()
        end)

        addCommandHandler("breakpoint", function(_, address)
            address = tonumber(address, 16)

            if (self.breakpoints[address]) then
                self:removeBreakpoint(address)
            else
                self:breakpoint(address)
            end
        end)

        bindKey("f3", "down", function()
            self.nextStepTick = getTickCount() + 500
        end)

        bindKey("f3", "up", function()
            self:performStep()
            self.debugMemoryPointer = -1
            self.nextStepTick = -1
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
            self.passthrough = true
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

    if (LOG_TRACE and self.traceFile) then
        local flags = ""

        flags = flags..((self.gameboy.cpu.registers.f[1]) and "Z" or "-")
        flags = flags..((self.gameboy.cpu.registers.f[2]) and "N" or "-")
        flags = flags..((self.gameboy.cpu.registers.f[3]) and "H" or "-")
        flags = flags..((self.gameboy.cpu.registers.f[4]) and "C" or "-")

        self.disassembler:singleInstruction(self.gameboy.cpu.mmu, self.gameboy.cpu.registers.pc)

        local instruction = "[??]0x"..string.format("%.4x", self.gameboy.cpu.registers.pc)..": "
        local opcode = self.gameboy.cpu.mmu:readByte(self.gameboy.cpu.registers.pc)
        local instructionBytes = ""
        local opcodeLen = self.disassembler:getOpcodeLength(opcode + 1)

        for i=1, opcodeLen do
            instructionBytes = instructionBytes..string.format("%.2x", self.gameboy.cpu.mmu:readByte(self.gameboy.cpu.registers.pc + (i - 1))):lower().." "
        end

        instruction = instruction..string.format("%-09s", instructionBytes)
        instruction = instruction.." "..(self.disassembler:getData()[self.gameboy.cpu.registers.pc + 1] or "unknown"):lower()

        fileWrite(self.traceFile, 
            "A:"..string.format("%.2x", self.gameboy.cpu.registers.a):upper()..
            " F:"..flags..
            " BC:"..string.format("%.4x", self.gameboy.cpu:readTwoRegisters('b', 'c')):lower()..
            " DE:"..string.format("%.4x", self.gameboy.cpu:readTwoRegisters('d', 'e')):lower()..
            " HL:"..string.format("%.4x", self.gameboy.cpu:readTwoRegisters('h', 'l')):lower()..
            " SP:"..string.format("%.4x", self.gameboy.cpu.registers.sp)..
            " PC:"..string.format("%.4x", self.gameboy.cpu.registers.pc)..
            " (cy: "..self.gameboy.cpu.clock.t..")"..
            " ppu:"..((self.gameboy.gpu.screenEnabled) and "+" or "-")..self.gameboy.gpu.mode..
            " |"..instruction..
            " {"..string.format("%.2x", self.gameboy.cpu.mmu:readByte(0xFF44))..", "..self.gameboy.gpu.modeclock.."}"..
            "\n")
    end

    if (self.breakpoints[self.gameboy.cpu.registers.pc] and not self.debuggerInducedPause
        and not self.passthrough) then
        self.gameboy.cpu:pause()
        self.debuggerInducedPause = true
        return false
    end

    self.passthrough = false

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

    if (self.nextStepTick ~= -1 and getTickCount() > self.nextStepTick) then
        self:performStep()
        self.nextStepTick = getTickCount() + 50
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

                if (self.breakpoints[i]) then
                    dxDrawText("X", romX, romY,
                        romWindowStartX + romWindowWidth - (10 * (1920 / SCREEN_WIDTH)),
                        0, tocolor(255, 0, 0), 1, "default-bold")

                    romX = romX + (15 * (1920 / SCREEN_WIDTH))
                end

                dxDrawText(_string_format("%.4x", i):upper()..": "..romValue, romX, romY,
                    romWindowStartX + romWindowWidth - (10 * (1920 / SCREEN_WIDTH)),
                    0, tocolor(r, g, b), 1, "default-bold")

                romX = romWindowStartX + (10 * (1920 / SCREEN_WIDTH))
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
                local value = cpu.registers[registerPair[1]] * 256

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

        dxDrawText("LY".." = ".._string_format("%.2x", self.gameboy.gpu.line):upper(), registersX, registersY,
            registersWindowStartX + registersWindowWidth - (10 * (1920 / SCREEN_WIDTH)), 0, tocolor(0, 0, 0), 1, "default-bold")

        registersY = registersY + yPadding
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
            dxDrawText("0x".._string_format("%.4x", address):upper(), registersX, registersY,
                registersWindowStartX + registersWindowWidth -
                (10 * (1920 / SCREEN_WIDTH)), 0, tocolor(0, 0, 0), 1, "default-bold")

            registersY = registersY + yPadding
        end
    end

    local currentX = romMemoryWindowStartX
    local currentY = romMemoryWindowStartY + romMemoryWindowHeight

    local size = (2 * (1920 / SCREEN_WIDTH))
    local palette = cpu.mmu:readByte(0xFF47)

    for tile=0, 384 do
        local address = 0x8000 + (tile * 16)

        for row=1, 8 do
            local byte1 = cpu.mmu:readByte(address)
            local byte2 = cpu.mmu:readByte(address + 1)

            for column=1, 8 do
                local colorBit = ((column % 8) - 7) * -1

                local colorNum = _bitLShift(_bitExtract(byte2, colorBit, 1), 1)
                colorNum = _bitOr(colorNum, _bitExtract(byte1, colorBit, 1))

                local hi = 0
                local lo = 0

                if (colorNum == 0) then
                    hi = 1
                    lo = 0
                elseif (colorNum == 1) then
                    hi = 3
                    lo = 2
                elseif (colorNum == 2) then
                    hi = 5
                    lo = 4
                elseif (colorNum == 3) then
                    hi = 7
                    lo = 6
                end

                local color = _bitLShift(_bitExtract(palette, hi, 1), 1)
                color = _bitOr(color, _bitExtract(palette, lo, 1))

                local columnColor = _COLORS[color + 1]

                dxDrawRectangle(currentX + column * size, currentY + row * size, size, size,
                    tocolor(columnColor[1], columnColor[2], columnColor[3]))
            end

            address = address + 2
        end

        currentX = currentX + (8 * size) + 2

        if (currentX > romMemoryWindowStartX +
            (screenWidth - ((romMemoryWindowStartX - screenStartX) * 2))) then
            currentX = romMemoryWindowStartX
            currentY = currentY + ((8 * (1920 / SCREEN_WIDTH)) * size) + (2 * (1920 / SCREEN_WIDTH))
        end
    end

    currentY = currentY + ((8 * (1920 / SCREEN_WIDTH)) * size) + (2 * (1920 / SCREEN_WIDTH))

    local currentX = romMemoryWindowStartX
    local currentY = currentY + (10 * (1920 / SCREEN_WIDTH))

    local size = 2

    for oam=0, 39 do
        local y = cpu.mmu:readByte(0xFE00 + (oam * 4))
        local x = cpu.mmu:readByte(0xFE00 + (oam * 4) + 1)
        local tile = cpu.mmu:readByte(0xFE00 + (oam * 4) + 2)
        local options = cpu.mmu:readByte(0xFE00 + (oam * 4) + 3)

        palette = cpu.mmu:readByte((_bitExtract(options, 4, 1) == 1) and 0xFF49 or 0xFF48)

        local address = 0x8000 + (tile * 16)

        for row=1, 8 do
            local byte1 = cpu.mmu:readByte(address)
            local byte2 = cpu.mmu:readByte(address + 1)

            for column=1, 8 do
                local colorBit = ((column % 8) - 7) * -1

                local colorNum = _bitLShift(_bitExtract(byte2, colorBit, 1), 1)
                colorNum = _bitOr(colorNum, _bitExtract(byte1, colorBit, 1))

                local hi = 0
                local lo = 0

                if (colorNum == 0) then
                    hi = 1
                    lo = 0
                elseif (colorNum == 1) then
                    hi = 3
                    lo = 2
                elseif (colorNum == 2) then
                    hi = 5
                    lo = 4
                elseif (colorNum == 3) then
                    hi = 7
                    lo = 6
                end

                local color = _bitLShift(_bitExtract(palette, hi, 1), 1)
                color = _bitOr(color, _bitExtract(palette, lo, 1))

                local columnColor = _COLORS[color + 1]

                dxDrawRectangle(currentX + column * size, currentY + row * size, size, size,
                    tocolor(columnColor[1], columnColor[2], columnColor[3]))
            end

            address = address + 2
        end

        currentX = currentX + (8 * size) + 2

        if (currentX > romMemoryWindowStartX +
            (screenWidth - ((romMemoryWindowStartX - screenStartX) * 2))) then
            currentX = romMemoryWindowStartX
            currentY = currentY + ((8 * (1920 / SCREEN_WIDTH)) * size) + (2 * (1920 / SCREEN_WIDTH))
        end
    end
end

function Debugger:breakpoint(address)
    self.breakpoints[address] = true
end

function Debugger:removeBreakpoint(address)
    self.breakpoints[address] = false
end