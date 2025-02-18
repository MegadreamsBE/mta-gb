-----------------------------------
-- * Constants
-----------------------------------

local RENDER = true
local LOG_TRACE = false
local LOG_GPU_FRAMES = false
local SCREEN_WIDTH, SCREEN_HEIGHT = guiGetScreenSize()
local WINDOW_SCALE = math.min((SCREEN_WIDTH / 1920), (SCREEN_HEIGHT / 1080))

local DEBUGGER_WIDTH, DEBUGGER_HEIGHT = 500, 768

local DEBUGGER_REGISTERS = {
    {"a", "f"},
    {"b", "c"},
    {"d", "e"},
    {"h", "l"},
    "sp", "pc"
}

local DEBUGGER_REGISTER_MAPPING = {
    ['a'] = register1, 
    ['b'] = register2, 
    ['c'] = register3, 
    ['d'] = register4, 
    ['e'] = register5, 
    ['h'] = register6, 
    ['l'] = register7, 
    ['sp'] = stackPointer, 
    ['pc'] = programCounter
}

-----------------------------------
-- * Locals
-----------------------------------

local _getTickCount = getTickCount
local _bitExtract = bitExtract
local _bitLShift = bitLShift
local _bitOr = bitOr
local _bitAnd = bitAnd
local _math_floor = math.floor
local _string_format = string.format

local _fps = 0
local _fpsNextTick = 0
local _debugFramesPassed = 0

local _lastRender = 0
local _frameLogged = false

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

local _debuggingBios = true

local _breakpoints = {}
local _debuggerInducedPause = false
local _passthrough = false

local _memoryPointerMemory = {}

local _currentMenu = 0
local _debugMemoryPointer = -1

local _traceFile = nil
local _nextStepTick = -1

local _renderTarget = false
local _lastPC = -1

-----------------------------------
-- * Functions
-----------------------------------

function setupDebugger()
    _debuggingBios = true

    _breakpoints = {}
    _debuggerInducedPause = false
    _passthrough = false

    _memoryPointerMemory = {}

    _currentMenu = 0
    _debugMemoryPointer = -1

    _traceFile = nil
    _nextStepTick = -1

    _renderTarget = dxCreateRenderTarget(SCREEN_WIDTH, SCREEN_HEIGHT, true)

    addEventHandler("onClientPreRender", root, function(delta)
        local now = _getTickCount()

        if (now >= _fpsNextTick) then
            _fps = (1 / delta) * 1000
            _fpsNextTick = now + 1000
        end
    end)

    addEventHandler("onClientRender", root, function()
        dxDrawText(math.floor(_fps), SCREEN_WIDTH - (((200 * WINDOW_SCALE) / 2)), 
            (((30 * WINDOW_SCALE) / 2)), 0, 0, tocolor(255, 255, 255), (((6 * WINDOW_SCALE) / 2)),
            "default-bold")
    end)
end

function startDebugger()
    disassemble()
    _lastPC = -1

    if (LOG_TRACE) then
        if (_traceFile) then
            fileClose(_traceFile)
        end

        if (fileExists("trace.txt")) then
            fileDelete("trace.txt")
        end

        _traceFile = fileCreate("trace.txt")
    end

    if (RENDER) then
        addEventHandler("onClientPreRender", root, function(delta)
            local now = _getTickCount()

            if (now >= _fpsNextTick) then
                _fps = (1 / delta) * 1000
                _fpsNextTick = now + 1000
            end
        end)

        addEventHandler("onClientRender", root, function()
            renderDebugger()
        end)

        addCommandHandler("breakpoint", function(_, address)
            address = tonumber(address, 16)

            if (_breakpoints[address]) then
                removeBreakpoint(address)
            else
                breakpoint(address)
            end
        end)

        bindKey("f3", "down", function()
            _nextStepTick = getTickCount() + 500
            _lastRender = 0
        end)

        bindKey("f3", "up", function()
            debuggerSingleStep()
            _debugMemoryPointer = -1
            _nextStepTick = -1
            _lastRender = 0
        end)

        bindKey("f4", "up", function()
            _debuggerInducedPause = true
            _debugMemoryPointer = -1

            pauseCPU()

            _lastRender = 0
        end)

        bindKey("f5", "up", function()
            _debuggerInducedPause = false

            resumeCPU()

            _debugMemoryPointer = -1
            _passthrough = true
            _lastRender = 0
        end)

        bindKey("arrow_u", "up", function()
            if (not isCPUPaused()) then
                return
            end

            if (_debugMemoryPointer == -1) then
                _debugMemoryPointer = programCounter
            end

            _debugMemoryPointer = _debugMemoryPointer - 1

            if (_debugMemoryPointer < 0) then
                _debugMemoryPointer = 0
            end

            _lastRender = 0
        end)

        bindKey("arrow_d", "up", function()
            if (not isCPUPaused()) then
                return
            end

            if (_debugMemoryPointer == -1) then
                _debugMemoryPointer = programCounter
            end

            _debugMemoryPointer = _debugMemoryPointer + 1

            if (_debugMemoryPointer > MMU_MEMORY_SIZE) then
                _debugMemoryPointer = MMU_MEMORY_SIZE
            end

            _lastRender = 0
        end)

        bindKey("arrow_l", "up", function()
            if (_debugMemoryPointer == -1 or not isCPUPaused()) then
                return
            end

            _memoryPointerMemory[_currentMenu] = _debugMemoryPointer
            _currentMenu = _currentMenu - 1

            if (_currentMenu < 0) then
                _currentMenu = 0
            end

            if (_memoryPointerMemory[_currentMenu] ~= nil) then
                _debugMemoryPointer = _memoryPointerMemory[_currentMenu]
            else
                _debugMemoryPointer = programCounter
            end

            _lastRender = 0
        end)

        bindKey("arrow_r", "up", function()
            if (_debugMemoryPointer == -1 or not isCPUPaused()) then
                return
            end

            _memoryPointerMemory[_currentMenu] = _debugMemoryPointer
            _currentMenu = _currentMenu + 1

            if (_currentMenu > 1) then
                _currentMenu = 1
            end

            if (_memoryPointerMemory[_currentMenu] ~= nil) then
                _debugMemoryPointer = _memoryPointerMemory[_currentMenu]
            else
                _debugMemoryPointer = programCounter
            end

            _lastRender = 0
        end)
    end
end

function debuggerStep()
    if (_debuggerInducedPause) then
        pauseCPU()
    end

    if (LOG_TRACE and _traceFile) then
        local flags = ""

        flags = flags..((flagZero) and "Z" or "-")
        flags = flags..((flagSubstract) and "N" or "-")
        flags = flags..((flagHalfCarry) and "H" or "-")
        flags = flags..((flagCarry) and "C" or "-")

        disassembleSingleInstruction(programCounter)

        local instruction = "[??]0x"..string.format("%.4x", programCounter)..": "
        local opcode = mmuReadByte(programCounter)
        local instructionBytes = ""
        local opcodeLen = getOpcodeLength(opcode + 1)

        for i=1, opcodeLen do
            instructionBytes = instructionBytes..string.format("%.2x", mmuReadByte(programCounter + (i - 1))):lower().." "
        end

        instruction = instruction..string.format("%-09s", instructionBytes)
        instruction = instruction.." "..(disassembledData[programCounter + 1] or "unknown"):lower()

        fileWrite(_traceFile, 
            "A:"..string.format("%.2x", register1):upper()..
            " F:"..flags..
            " BC:"..string.format("%.4x", readTwoRegisters(2, 3)):lower()..
            " DE:"..string.format("%.4x", readTwoRegisters(4, 5)):lower()..
            " HL:"..string.format("%.4x", readTwoRegisters(6, 7)):lower()..
            " SP:"..string.format("%.4x", stackPointer)..
            " PC:"..string.format("%.4x", programCounter)..
            " (cy: "..getCPUClock().t..")"..
            " ppu:"..((isScreenEnabled()) and "+" or "-")..getGPUMode()..
            " |"..instruction..
            " {"..string.format("%.2x", mmuReadByte(0xFF44))..", "..getGPUModeClock().."}"..
            "\n")
    end

    if (LOG_GPU_FRAMES) then
        local maskedFlags = _bitAnd(getInterrupts(), getInterruptFlags())

        if (_bitAnd(maskedFlags, 0x01) ~= 0) then
            if (not _frameLogged) then
                local convertedPixels = dxConvertPixels(getScreenPixels(), 'jpeg')

                if (fileExists("data/frames/".._debugFramesPassed..".jpg")) then
                    fileDelete("data/frames/".._debugFramesPassed..".jpg")
                end

                local file = fileCreate("data/frames/".._debugFramesPassed..".jpg")
                fileWrite(file, convertedPixels)
                fileClose(file)

                _debugFramesPassed = _debugFramesPassed + 1
                _frameLogged = true
            end
        else
            _frameLogged = false
        end
    end

    if (_breakpoints[programCounter] and not _debuggerInducedPause
        and not _passthrough) then
        pauseCPU()
        _debuggerInducedPause = true
        return false
    end

    _passthrough = false

    return true
end

function debuggerSingleStep()
    if (_debuggerInducedPause) then
        resumeCPU()
    end
end

function renderDebugger(delta)
    if (_nextStepTick ~= -1 and _getTickCount() > _nextStepTick) then
        debuggerSingleStep()
        _nextStepTick = _getTickCount() + 50
        _lastRender = 0
    end

    if ((_getTickCount() - _lastRender) > 1000 or not _renderTarget) then
        disassemble()

        dxSetRenderTarget(_renderTarget, true)
        dxSetBlendMode("modulate_add")

        local screenStartX = 0
        local screenStartY = (SCREEN_HEIGHT / 2) - ((DEBUGGER_HEIGHT * WINDOW_SCALE) / 2)

        local screenWidth = DEBUGGER_WIDTH * WINDOW_SCALE
        local screenHeight = DEBUGGER_HEIGHT * WINDOW_SCALE

        dxDrawRectangle(screenStartX, screenStartY, screenWidth, screenHeight
            , tocolor(0, 0, 0, 200))

        local romMemoryWindowStartX = screenStartX
        local romMemoryWindowStartY = screenStartY

        local romMemoryWindowWidth = (75 * WINDOW_SCALE)
        local romMemoryWindowHeight = DEBUGGER_HEIGHT * WINDOW_SCALE

        dxDrawRectangle(romMemoryWindowStartX, romMemoryWindowStartY, romMemoryWindowWidth, romMemoryWindowHeight,
            tocolor(255, 196, 196, 150))

        local yPadding = (20 * WINDOW_SCALE)

        local romMemoryX = romMemoryWindowStartX + (10 * WINDOW_SCALE)
        local romMemoryY = romMemoryWindowStartY + (yPadding / 2)
        local renderLineCount = (romMemoryWindowHeight / dxGetFontHeight(1 * WINDOW_SCALE, "default-bold"))

        local romMemorySize = MMU_MEMORY_SIZE
        local startValue = _math_floor(programCounter - (renderLineCount * 0.5))

        if (startValue < 0) then
            startValue = 0
        end

        if (_debugMemoryPointer ~= -1 and _currentMenu == 0) then
            startValue = _math_floor(_debugMemoryPointer - (renderLineCount * 0.5))
        end

        for i=startValue, romMemorySize do
            local romMemoryValue = mmuReadByte(i)
            local r, g, b = 255, 255, 255

            if (i == programCounter) then
                r, g, b = 11, 51, 255
            elseif (i == _debugMemoryPointer and _currentMenu == 0) then
                r, g, b = 255, 51, 11
            end

            dxDrawText(_string_format("%.4x", i):upper()..": ".._string_format("%.2x", romMemoryValue):upper()
                , romMemoryX, romMemoryY,
                romMemoryWindowStartX + romMemoryWindowWidth - (10 * WINDOW_SCALE), 0, tocolor(r, g, b), 1 * WINDOW_SCALE, "default-bold")

            romMemoryY = romMemoryY + yPadding

            if (romMemoryY > (romMemoryWindowStartY + romMemoryWindowHeight - yPadding)) then
                break
            end
        end

        local romWindowStartX = romMemoryWindowStartX + romMemoryWindowWidth
        local romWindowStartY = romMemoryWindowStartY

        local romWindowWidth = ((DEBUGGER_WIDTH * WINDOW_SCALE) - (200 * WINDOW_SCALE)) - romMemoryWindowWidth
        local romWindowHeight = romMemoryWindowHeight

        dxDrawRectangle(romWindowStartX, romWindowStartY
            , romWindowWidth, romWindowHeight,
            tocolor(255, 255, 255, 150))

        local rom = disassembledData

        local romX = romWindowStartX + (10 * WINDOW_SCALE)
        local romY = romWindowStartY + (yPadding / 2)
        local renderLineCount = (romWindowHeight / dxGetFontHeight(1 * WINDOW_SCALE, "default-bold"))

        local romSize = #rom
        local startValue = _math_floor(programCounter - (renderLineCount * 0.5))

        if (_debugMemoryPointer ~= -1 and _currentMenu == 1) then
            startValue = _math_floor(_debugMemoryPointer - (renderLineCount * 0.5))
        end

        if (startValue < 0) then
            startValue = 0
        end

        for i=startValue, MMU_MEMORY_SIZE do
            local romValue = rom[i + 1]

            if (romValue ~= nil) then
                local r, g, b = 255, 255, 255

                if (i == programCounter) then
                    r, g, b = 11, 51, 255
                elseif (i == _debugMemoryPointer and _currentMenu == 1) then
                    r, g, b = 255, 51, 11
                end

                if (_breakpoints[i]) then
                    dxDrawText("X", romX, romY,
                        romWindowStartX + romWindowWidth - (10 * WINDOW_SCALE),
                        0, tocolor(255, 0, 0), 1 * WINDOW_SCALE, "default-bold")

                    romX = romX + (15 * WINDOW_SCALE)
                end

                dxDrawText(_string_format("%.4x", i):upper()..": "..romValue, romX, romY,
                    romWindowStartX + romWindowWidth - (10 * WINDOW_SCALE),
                    0, tocolor(r, g, b), 1 * WINDOW_SCALE, "default-bold")

                romX = romWindowStartX + (10 * WINDOW_SCALE)
                romY = romY + yPadding

                if (romY > (romWindowStartY + romWindowHeight - yPadding)) then
                    break
                end
            end
        end

        local registersWindowStartX = (romWindowStartX + romWindowWidth) + (10 * WINDOW_SCALE)
        local registersWindowStartY = screenStartY + WINDOW_SCALE

        local registersWindowWidth = ((DEBUGGER_WIDTH * WINDOW_SCALE) - (registersWindowStartX - screenStartX)) - (50 * WINDOW_SCALE)
        local registersWindowHeight = DEBUGGER_HEIGHT * WINDOW_SCALE

        dxDrawRectangle(registersWindowStartX, registersWindowStartY, registersWindowWidth, registersWindowHeight,
            tocolor(255, 255, 255, 150))

        local registersX = registersWindowStartX + (10 * WINDOW_SCALE)
        local registersY = registersWindowStartY + (yPadding / 2)

        for _, registerPair in pairs(DEBUGGER_REGISTERS) do
            if (type(registerPair) == "table") then
                local value = DEBUGGER_REGISTER_MAPPING[registerPair[1]] * 256

                if (registerPair[2] == 'f') then
                    value = value + (
                        ((flagZero) and 1 or 0) * 128 +
                        ((flagSubstract) and 1 or 0) * 64 +
                        ((flagHalfCarry) and 1 or 0) * 32 +
                        ((flagCarry) and 1 or 0) * 16
                    )
                else
                    value = value + DEBUGGER_REGISTER_MAPPING[registerPair[2]]
                end

                dxDrawText(registerPair[1]:upper()..registerPair[2]:upper()
                    .." = ".._string_format("%.4x", value):upper(), registersX, registersY,
                    registersWindowStartX + registersWindowWidth - (10 * WINDOW_SCALE), 0, tocolor(0, 0, 0), 1 * WINDOW_SCALE, "default-bold")
            else
                local value = DEBUGGER_REGISTER_MAPPING[registerPair]

                dxDrawText(registerPair:upper()
                    .." = ".._string_format("%.4x", value):upper(), registersX, registersY,
                    registersWindowStartX + registersWindowWidth - (10 * WINDOW_SCALE), 0, tocolor(0, 0, 0), 1 * WINDOW_SCALE, "default-bold")
            end

            registersY = registersY + yPadding
        end

        dxDrawText("LY".." = ".._string_format("%.2x", scanLine):upper(), registersX, registersY,
            registersWindowStartX + registersWindowWidth - (10 * WINDOW_SCALE), 0, tocolor(0, 0, 0), 1 * WINDOW_SCALE, "default-bold")

        registersY = registersY + yPadding
        registersY = registersY + yPadding

        for i=0xFF40, 0xFF52 do
            dxDrawText("0x".._string_format("%.4x", i):upper()..": "
                .._string_format("%.2x", mmuReadByte(i)):upper(), registersX, registersY,
                registersWindowStartX + registersWindowWidth -
                (10 * WINDOW_SCALE), 0, tocolor(0, 0, 0), WINDOW_SCALE, "default-bold")

            registersY = registersY + yPadding
        end

        dxDrawText("Stack: ", registersX, registersY,
            registersWindowStartX + registersWindowWidth -
            (10 * WINDOW_SCALE), 0, tocolor(0, 0, 0), WINDOW_SCALE, "default-bold")

        registersY = registersY + yPadding

        for _, address in pairs(stackDebug) do
            dxDrawText("0x".._string_format("%.4x", address):upper(), registersX, registersY,
                registersWindowStartX + registersWindowWidth -
                (10 * WINDOW_SCALE), 0, tocolor(0, 0, 0), WINDOW_SCALE, "default-bold")

            registersY = registersY + yPadding
        end

        local isCGB = isGameBoyColor
        local bank = vramBank

        local lcdControl = mmuReadByte(0xFF40)
        local is8x16 = false

        if (_bitExtract(lcdControl, 2, 1) == 1) then
            is8x16 = true
        end

        local size = 2 * WINDOW_SCALE
        local palette = mmuReadByte(0xFF47)

        if (isCGB) then
            palette = 0xFC
        end

        local tileRenderStart = SCREEN_WIDTH - (16 * ((8 * size) + (2 * WINDOW_SCALE)))

        local currentX = tileRenderStart
        local currentY = (SCREEN_HEIGHT / 2) - ((((math.ceil((384 * (((isCGB) and 2 or 1))) / 16) + 1) * 
            ((8 * size) + (2 * WINDOW_SCALE))) + (20 * WINDOW_SCALE) +
            ((math.ceil(39 / 16) + 1) * (8 * size) + (2 * WINDOW_SCALE))) / 2)

        local backgroundPalettes = getBackgroundPalettes()

        for renderBank=1, ((isCGB) and 2 or 1) do
            vramBank = renderBank

            for tile=0, 383 do
                local address = 0x8000 + (tile * 16)

                local cgbPalette = nil
                
                if (isCGB) then
                    cgbPalette = debugBackground[renderBank][address]
                end

                for row=1, 8 do
                    byte1 = mmuReadByte(address)
                    byte2 = mmuReadByte(address + 1)

                    for column=1, 8 do
                        local colorBit = ((column % 8) - 7) * -1

                        local colorNum = _bitLShift(_bitExtract(byte2, colorBit, 1), 1)
                        colorNum = _bitOr(colorNum, _bitExtract(byte1, colorBit, 1))

                        if (isCGB and cgbPalette ~= nil and cgbPalette ~= false) then
                            local color = backgroundPalettes[cgbPalette + 1][colorNum + 1][2] or {255, 255, 255}
                
                            dxDrawRectangle(currentX + column * size, currentY + row * size, size, size,
                                tocolor(color[1], color[2], color[3], 255))
                        else
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
                    end

                    address = address + 2
                end

                currentX = currentX + (8 * size) + 2 * WINDOW_SCALE

                if (((384 * (renderBank - 1)) + (tile + 1)) % 16 == 0) then
                    currentX = tileRenderStart
                    currentY = currentY + (8 * size) + (2 * WINDOW_SCALE)
                end
            end

            vramBank = bank
        end

        currentY = currentY + ((8 * WINDOW_SCALE) * size) + (2 * WINDOW_SCALE) + (20 * WINDOW_SCALE)

        local currentX = tileRenderStart
        local currentY = currentY + (10 * WINDOW_SCALE)

        local size = 2 * WINDOW_SCALE
        local spritePalettes = getSpritePalettes()

        for oam=0, 39 do
            local y = mmuReadByte(0xFE00 + (oam * 4))
            local x = mmuReadByte(0xFE00 + (oam * 4) + 1)
            local tile = mmuReadByte(0xFE00 + (oam * 4) + 2)
            local options = mmuReadByte(0xFE00 + (oam * 4) + 3)

            palette = mmuReadByte((_bitExtract(options, 4, 1) == 1) and 0xFF49 or 0xFF48)

            local cgbPalette = 0
            local cgbBank = false

            if (isCGB) then
                vramBank = 2
                cgbPalette = _bitAnd(options, 0x07)
                cgbBank = (_bitExtract(options, 3, 1) == 1)
                vramBank = bank
            end

            local address = 0x8000 + (tile * 16)

            for row=1, ((is8x16) and 16 or 8) do
                local line = row

                local byte1 = 0
                local byte2 = 0

                if (isCGB and cgbBank) then
                    vramBank = 2
                    byte1 = mmuReadByte(address)
                    byte2 = mmuReadByte(address + 1)
                    vramBank = bank
                else
                    byte1 = mmuReadByte(address)
                    byte2 = mmuReadByte(address + 1)
                end

                for column=1, 8 do
                    local colorBit = ((column % 8) - 7) * -1

                    local colorNum = _bitLShift(_bitExtract(byte2, colorBit, 1), 1)
                    colorNum = _bitOr(colorNum, _bitExtract(byte1, colorBit, 1))

                    if (isCGB) then
                        local color = spritePalettes[cgbPalette + 1][colorNum + 1][2] or {255, 255, 255}
                
                        dxDrawRectangle(currentX + column * size, currentY + row * size, size, size,
                            tocolor(color[1], color[2], color[3], 255))
                    else
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
                end

                address = address + 2
            end

            currentX = currentX + (8 * size) + 2 * WINDOW_SCALE

            if ((oam + 1) % 16 == 0) then
                currentX = tileRenderStart
                currentY = currentY + (8 * size) + (2 * WINDOW_SCALE)
            end
        end

        dxSetBlendMode("blend")
        dxSetRenderTarget()

        _lastRender = _getTickCount()
    end

    dxSetBlendMode("add")
    dxDrawImage(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, _renderTarget)
    dxSetBlendMode("blend")
end

function breakpoint(address)
    _breakpoints[address] = true
end

function removeBreakpoint(address)
    _breakpoints[address] = false
end

function debuggerResize(width, height)
    SCREEN_WIDTH = width
    SCREEN_HEIGHT = height

    WINDOW_SCALE = math.min((SCREEN_WIDTH / 1920), (SCREEN_HEIGHT / 1080))

    if (isElement(_renderTarget)) then
        destroyElement(_renderTarget)
    end

    _renderTarget = dxCreateRenderTarget(SCREEN_WIDTH, SCREEN_HEIGHT, true)
end