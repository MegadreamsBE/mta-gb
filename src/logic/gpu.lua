vramBank = 1
vram = {}

scanLine = 0

-----------------------------------
-- * Locals
-----------------------------------

local SCREEN_WIDTH, SCREEN_HEIGHT = guiGetScreenSize()

local _dxGetPixelColor = dxGetPixelColor
local _dxSetPixelColor = dxSetPixelColor

local _bitExtract = bitExtract
local _bitReplace = bitReplace
local _bitLShift = bitLShift
local _bitRShift = bitRShift
local _bitOr = bitOr
local _bitAnd = bitAnd

local _dxSetTexturePixels = dxSetTexturePixels

local COLORS = {
    {255, 255, 255},
    {192, 192, 192},
    {92, 92, 92},
    {0, 0, 0}
}

_COLORS = COLORS

local _vram = vram

local _mode = 0
local _modeClock = 0
local _tileSet = createFilledTable(512)
local _screen = false
local _screenPixels = false
local _screenEnabled = true

local _backgroundPalettes = createFilledTable(8)
local _spritePalettes = createFilledTable(8)
local _backgroundPriority = createFilledTable(160)

debugBackground = {createFilledTable(0xFFFF), createFilledTable(0xFFFF)}

local _mmuReadByte = false
local _mmuReadSignedByte = false
local _mmuWriteByte = false

cacheAttributes = createFilledTable(0xFFFF, {})
local _cacheAttributes = cacheAttributes

local _frameSkips = 0

-----------------------------------
-- * Functions
-----------------------------------

function setupGPU()
    vram = {
        createFilledTable(0xFFFF), createFilledTable(0xFFFF)
    }

    _vram = vram
    mmuLinkVideoRam(vram)

    vramBank = 1

    for i=1, 0x3000 do
        _vram[1][i] = 0
        _vram[2][i] = 0
    end

    _mode = 0
    _modeClock = 0

    scanLine = 0

    _tileSet = createFilledTable(0xFFFF)
    _screen = dxCreateTexture(160, 144)
    _screenPixels = dxGetTexturePixels(_screen)

    _screenEnabled = true
    _backgroundPriority = createFilledTable(160)

    for i=0, 159 do
        _backgroundPriority[i + 1] = createFilledTable(144)

        for a=0, 143 do
            _dxSetPixelColor(_screenPixels, i, a, 255, 255, 255)
            _backgroundPriority[i + 1][a + 1] = {false, 0}
        end
    end

    for i=1, 8 do
        _backgroundPalettes[i] = createFilledTable(4)
        _spritePalettes[i] = createFilledTable(4)

        for j=1, 4 do
            _backgroundPalettes[i][j] = {
                0x0, {255, 255, 255}
            }

            _spritePalettes[i][j] = {
                0x0, {255, 255, 255}
            }
        end
    end

    _dxSetTexturePixels(_screen, _screenPixels)

    addEventHandler("onClientRender", root, function()
        local width, height = 320 * (1920 / SCREEN_WIDTH), 288 * (1920 / SCREEN_WIDTH)
        dxDrawImage((SCREEN_WIDTH / 2) - (width / 2), (SCREEN_HEIGHT / 2) - (height / 2), width, height, _screen)
    end)
end

function resetGPU()
    vram = {
        createFilledTable(0xFFFF), createFilledTable(0xFFFF)
    }

    _vram = vram
    mmuLinkVideoRam(vram)

    vramBank = 1

    for i=1, 0x3000 do
        _vram[1][i] = 0
        _vram[2][i] = 0
    end

    _mode = 0
    _modeClock = 0

    scanLine = 0

    if (not isBiosLoaded()) then
        scanLine = 0x90
    end

    _tileSet = createFilledTable(0xFFFF)
    _screen = dxCreateTexture(160, 144)
    _screenPixels = dxGetTexturePixels(_screen)

    _screenEnabled = true
    _backgroundPriority = createFilledTable(160)

    for i=0, 159 do
        _backgroundPriority[i + 1] = createFilledTable(144)

        for a=0, 143 do
            _dxSetPixelColor(_screenPixels, i, a, 255, 255, 255)
            _backgroundPriority[i + 1][a + 1] = {false, 0}
        end
    end

    for i=1, 8 do
        _backgroundPalettes[i] = createFilledTable(4)
        _spritePalettes[i] = createFilledTable(4)

        for j=1, 4 do
            _backgroundPalettes[i][j] = {
                0x0, {255, 255, 255}
            }

            _spritePalettes[i][j] = {
                0x0, {255, 255, 255}
            }
        end
    end

    if (_screenEnabled) then
        local lcdStatus = _mmuReadByte(0xFF41)

        lcdStatus = _bitReplace(lcdStatus, 1, 1, 1)
        lcdStatus = _bitReplace(lcdStatus, 0, 0, 1)

        _mmuWriteByte(0xFF41, lcdStatus)
    end

    cacheAttributes = createFilledTable(0xFFFF, {})
    _cacheAttributes = cacheAttributes

    mmuLinkCache(cacheAttributes)
end

function renderTiles()
    local usingWindow = false
    local isCGB = isGameBoyColor()
    local bank = vramBank
    local debuggerEnabled = isDebuggerEnabled()

    local lcdControl = _mmuReadByte(0xFF40)
    local scrollY = _mmuReadSignedByte(0xFF42)
    local scrollX = _mmuReadSignedByte(0xFF43)
    local windowY = _mmuReadByte(0xFF4A)
    local windowX = _mmuReadByte(0xFF4B) - 7

    if (_bitExtract(lcdControl, 5, 1) == 1) then
       if (windowY <= _mmuReadByte(0xFF44)) then
           usingWindow = true
       end
    end

    local unsigned = true

    local tileData = 0x8000
    local backgroundMemory = 0x9C00

    if (_bitExtract(lcdControl, 4, 1) == 1) then
        tileData = 0x8000
    else
        tileData = 0x8800
        unsigned = false
    end

    if (not usingWindow) then
        if (_bitExtract(lcdControl, 3, 1) ~= 1) then
            backgroundMemory = 0x9800
        end
    else
        if (_bitExtract(lcdControl, 6, 1) ~= 1) then
            backgroundMemory = 0x9800
        end
    end

    local yPos = 0

    if (not usingWindow) then
        yPos = scrollY + scanLine
    else
        yPos = scanLine - windowY
    end

    if (yPos < 0) then
        yPos = yPos + 0xff
    elseif (yPos > 0xff) then
        yPos = yPos - 0xff
    end

    local line = (yPos % 8) * 2
    local row = ((yPos / 8) - ((yPos / 8) % 1)) * 32

    local cgbAttributes = 0
    local cgbPalette = 0
    local cgbBank = 1
    local cgbPriority = false
    local cgbFlipX = false
    local cgbFlipY = false
    local palette = _mmuReadByte(0xFF47)

    local i = 0

    while (i < 160) do
        local xPos = i + scrollX

        if (usingWindow) then
            if (i >= windowX) then
                xPos = i - windowX
            end
        end

        if (xPos < 0) then
            xPos = xPos + 0xff
        elseif (xPos > 0xff) then
            xPos = xPos - 0xff
        end

        local tileAddress = backgroundMemory + row + ((xPos / 8) - ((xPos / 8) % 1))

        if (isCGB) then
            local adjustedAddress = (tileAddress - 0x8000) + 1
            local attributes = _cacheAttributes[adjustedAddress]

            if (attributes[1] == nil) then
                cgbAttributes = _vram[2][adjustedAddress]

                cgbPalette = _bitAnd(cgbAttributes, 0x07)
                cgbBank = (_bitAnd(cgbAttributes, 0x08) > 1) and 2 or 1
                cgbPriority = _bitAnd(cgbAttributes, 0x80) > 1
                cgbFlipX = _bitAnd(cgbAttributes, 0x20) > 1
                cgbFlipY = _bitAnd(cgbAttributes, 0x40) > 1

                attributes[1] = cgbPalette
                attributes[2] = cgbBank
                attributes[3] = cgbPriority
                attributes[4] = cgbFlipX
                attributes[5] = cgbFlipY

                _cacheAttributes[adjustedAddress] = attributes
            else
                cgbPalette = attributes[1]
                cgbBank = attributes[2]
                cgbPriority = attributes[3]
                cgbFlipX = attributes[4]
                cgbFlipY = attributes[5]
            end
        end

        local tileNum = _vram[1][(tileAddress - 0x8000) + 1]
        
        if (not unsigned and tileNum >= 0x80) then
            tileNum = -((0xFF - tileNum) + 1)
        end

        local tileLocation = 0

        if (unsigned) then
            tileLocation = tileData + tileNum * 16
        else
            tileLocation = tileData + (tileNum + 128) * 16
        end

        local lineWithFlip = line

        if (cgbFlipY) then
            lineWithFlip = (lineWithFlip - 8) * -1
        end

        local colorBit = ((xPos % 8) - 7) * -1

        if (cgbFlipX) then
            colorBit = (colorBit - 8) * -1
        end

        local colorNum = _bitOr(
            _bitExtract(_vram[cgbBank][(tileLocation - 0x8000) + 2 + lineWithFlip], colorBit, 1) * 2, 
            _bitExtract(_vram[cgbBank][(tileLocation - 0x8000) + 1 + lineWithFlip], colorBit, 1)
        )

        local bgPriority = _backgroundPriority[i + 1][scanLine + 1]

        bgPriority[1] = cgbPriority
        bgPriority[2] = colorNum

        if (isCGB) then
            local color = _backgroundPalettes[cgbPalette + 1][colorNum + 1][2] or {255, 255, 255}

            if (debuggerEnabled) then
                debugBackground[(cgbBank) and 2 or bank][tileLocation] = cgbPalette
            end
            
            _dxSetPixelColor(_screenPixels, i, scanLine, color[1], color[2], color[3], 255)
        else
            local color = _bitOr(_bitLShift(_bitExtract(palette, (colorNum * 2) + 1, 1), 1), _bitExtract(palette, (colorNum * 2), 1))

            _dxSetPixelColor(_screenPixels, i, scanLine, COLORS[color + 1][1], COLORS[color + 1][2], COLORS[color + 1][3], 255)
        end

        i = i + 1
    end
end

function renderSprites()
    local is8x16 = false
    local lcdControl = _mmuReadByte(0xFF40)
    local isCGB = isGameBoyColor()
    local bank = vramBank

    if (_bitExtract(lcdControl, 2, 1) == 1) then
        is8x16 = true
    end

    local spritesRendered = 0
    local spritePriorityData = {}

    local i = 0

    while (i < 40) do
        local index = i * 4
        local yPos = _mmuReadByte(0xFE00 + index) - 16
        local xPos = _mmuReadByte(0xFE00 + index + 1) - 8

        local ySize = (is8x16) and 16 or 8

        if (scanLine >= yPos and scanLine < (yPos + ySize)) then
            spritesRendered = spritesRendered + 1

            local tile = _mmuReadByte(0xFE00 + index + 2)
            local attributes = _mmuReadByte(0xFE00 + index + 3)

            local yFlip = false
            local xFlip = false
            local line = scanLine - yPos

            local cgbPalette = 0
            local cgbBank = false

            if (isCGB) then
                cgbPalette = _bitAnd(attributes, 0x07)
                cgbBank = _bitAnd(attributes, 0x08) > 1
                xFlip = _bitAnd(attributes, 0x20) > 1
                yFlip = _bitAnd(attributes, 0x40) > 1
            else
                xFlip = _bitAnd(attributes, 0x20) > 1
                yFlip = _bitAnd(attributes, 0x40) > 1
            end

            if (yFlip) then
                line = line - ySize
                line = line * -1
            end

            local address = (0x8000 + (tile* 16)) + (line * 2)
            local byte1 = 0
            local byte2 = 0

            if (isCGB and cgbBank) then
                vramBank = 2
                byte1 = _mmuReadByte(address)
                byte2 = _mmuReadByte(address + 1)
                vramBank = bank
            else
                vramBank = 1
                byte1 = _mmuReadByte(address)
                byte2 = _mmuReadByte(address + 1)
                vramBank = bank
            end

            local palette = _mmuReadByte((_bitExtract(attributes, 4, 1) == 1) and 0xFF49 or 0xFF48)
            local tilePixel = 7

            while (tilePixel > -1) do
                local xPixel = (-tilePixel) + 7
                local pixel = xPos + xPixel

                if (scanLine >= 0 and scanLine <= 143 and pixel >= 0 and pixel <= 159) then
                    local colorBit = tilePixel

                    if (xFlip) then
                        colorBit = colorBit - 7
                        colorBit = colorBit * -1
                    end

                    local colorNum = _bitOr(_bitExtract(byte2, colorBit, 1) * 2, _bitExtract(byte1, colorBit, 1))

                    if (isCGB) then
                        local avoidRender = false

                        if (_backgroundPriority[pixel + 1][scanLine + 1][1] or spritePriorityData[pixel + 1] ~= nil) then
                            avoidRender = true
                        end

                        if (not avoidRender and colorNum ~= 0) then
                            if ((_bitExtract(attributes, 7, 1) == 0) or 
                                ((_bitExtract(attributes, 7, 1) == 1) and _backgroundPriority[pixel + 1][scanLine + 1][2] == 0)) then
                                spritePriorityData[pixel + 1] = true

                                local color = _spritePalettes[cgbPalette + 1][colorNum + 1][2] or {255, 255, 255}
                
                                _dxSetPixelColor(_screenPixels, pixel, scanLine, color[1], color[2], color[3], 255)
                            end
                        end
                    else
                        local color = _bitOr(_bitLShift(_bitExtract(palette, (colorNum * 2) + 1, 1), 1), _bitExtract(palette, (colorNum * 2), 1))

                        local bgColorR, bgColorG, bgColorB, _ = _dxGetPixelColor(_screenPixels, pixel, scanLine)
                        local avoidRender = false

                        if (spritePriorityData[pixel + 1] ~= nil) then
                            if (spritePriorityData[pixel + 1] <= xPos) then
                                avoidRender = true
                            end
                        end

                        if (not avoidRender and colorNum ~= 0) then
                            if ((_bitExtract(attributes, 7, 1) == 0) or 
                                ((_bitExtract(attributes, 7, 1) == 1) and _backgroundPriority[pixel + 1][scanLine + 1][2] == 0)) then
                                spritePriorityData[pixel + 1] = xPos

                                _dxSetPixelColor(_screenPixels, pixel, scanLine, COLORS[color + 1][1], COLORS[color + 1][2], COLORS[color + 1][3], 255)
                            end
                        end
                    end
                end

                tilePixel = tilePixel - 1
            end
        end

        if (spritesRendered == 10) then
            break
        end

        i = i + 1
    end
end

function renderScan()
    local lcdControl = _mmuReadByte(0xFF40)

    if (_bitExtract(lcdControl, 0) == 1) then
        renderTiles()
    end

    if (_bitExtract(lcdControl, 1) == 1) then
        renderSprites()
    end
end

function updatePaletteSpec(isSprites, value)
    local index = _bitAnd(_bitRShift(value, 1), 0x03)
    local palette = _bitAnd(_bitRShift(value, 3), 0x07)
    local color = (isSprites) and _spritePalettes[palette + 1][index + 1][1] or _backgroundPalettes[palette + 1][index + 1][1]

    if (_bitExtract(value, 0, 1) == 1) then
        _mmuWriteByte((isSprites) and 0xFF6B or 0xFF69, _bitAnd(_bitRShift(color, 8), 0xFF), true)
    else
        _mmuWriteByte((isSprites) and 0xFF6B or 0xFF69, _bitAnd(color, 0xFF), true)
    end
end

function setColorPalette(isSprites, value)
    local spec = (isSprites) and _mmuReadByte(0xFF6A) or _mmuReadByte(0xFF68)
    local index = _bitAnd(_bitRShift(spec, 1), 0x03)
    local palette = _bitAnd(_bitRShift(spec, 3), 0x07)
    local autoIncrement = (_bitExtract(spec, 7, 1) == 1)
    local hl = (_bitExtract(spec, 0, 1) == 1)

    if (autoIncrement) then
        local address = _bitAnd(spec, 0x3F)

        address = _bitAnd(address + 1, 0x3F)
        spec = _bitOr(_bitAnd(spec, 0x80), address)

        _mmuWriteByte((isSprites) and 0xFF6A or 0xFF68, spec, true)
        updatePaletteSpec(isSprites, spec)
    end

    local paletteColor = (isSprites) and _spritePalettes[palette + 1][index + 1][1] or _backgroundPalettes[palette + 1][index + 1][1]
    local paletteColorFinal = (isSprites) and _spritePalettes[palette + 1][index + 1][2] or _backgroundPalettes[palette + 1][index + 1][2]

    if (hl) then
        paletteColor = _bitOr(_bitAnd(paletteColor, 0x00FF), _bitAnd(_bitLShift(value, 8), 0xFFFF))
    else
        paletteColor = _bitOr(_bitAnd(paletteColor, 0xFF00), value)
    end

    paletteColorFinal[1] = _bitExtract(paletteColor, 0, 5) * 8
    paletteColorFinal[2] = _bitExtract(paletteColor, 5, 5) * 8
    paletteColorFinal[3] = _bitExtract(paletteColor, 10, 5) * 8

    if (isSprites) then
        _spritePalettes[palette + 1][index + 1][1] = paletteColor
        _spritePalettes[palette + 1][index + 1][2] = paletteColorFinal
    else
        _backgroundPalettes[palette + 1][index + 1][1] = paletteColor
        _backgroundPalettes[palette + 1][index + 1][2] = paletteColorFinal
    end
end

function gpuStep(ticks)
    local lcdStatus = _mmuReadByte(0xFF41)

    if (not _screenEnabled) then
        lcdStatus = _bitReplace(_bitAnd(lcdStatus, 0xFC), 1, 0, 1)

        _mmuWriteByte(0xFF41, lcdStatus)
    end

    _modeClock = _modeClock + ticks

    local lastMode = _mode
    local requireInterrupt = false

    if (_screenEnabled) then
        if (_mode == 0) then
            if (_modeClock >= 51) then
                _modeClock = _modeClock - 51
                scanLine = scanLine + 1

                if (isGameBoyColor() and hdmaEnabled and (not isCPUPaused() or hasIncomingInterrupt())) then
                    local clockCycles = mmuPerformHDMA()
                    _modeClock = _modeClock + clockCycles

                    registers[12].m = registers[12].m + clockCycles
                    registers[12].t = registers[12].t + (clockCycles * 4)
                end

                if (scanLine == 144) then
                    _mode = 1

                    lcdStatus = _bitReplace(_bitReplace(lcdStatus, 1, 0, 1), 0, 1, 1)
                    requireInterrupt = (_bitExtract(lcdStatus, 4, 1) == 1)

                    _frameSkips = _frameSkips + 1

                    if (_frameSkips >= 2) then
                        _dxSetTexturePixels(_screen, _screenPixels)
                        _frameSkips = 0
                    end

                    requestInterrupt(0)
                else
                    _mode = 2

                    lcdStatus = _bitReplace(_bitReplace(lcdStatus, 1, 1, 1), 0, 0, 1)
                    requireInterrupt = (_bitExtract(lcdStatus, 5, 1) == 1)
                end
            end
        elseif (_mode == 1) then
            if (_modeClock >= 114) then
                _modeClock = _modeClock - 114
                scanLine = scanLine + 1

                if (scanLine >= 154) then
                    _mode = 2

                    lcdStatus = _bitReplace(_bitReplace(lcdStatus, 1, 1, 1), 0, 0, 1)
                    requireInterrupt = (_bitExtract(lcdStatus, 5, 1) == 1)

                    scanLine = 0

                    if (isDebuggerEnabled() and isGameBoyColor()) then
                        cachedDebugBackground = {debugBackground[1], debugBackground[2]}
                        debugBackground = {{}, {}}
                    end
                end
            end
        elseif (_mode == 2) then
            if (_modeClock >= 20) then
                _modeClock = _modeClock - 20
                lcdStatus = _bitReplace(_bitReplace(lcdStatus, 1, 1, 1), 1, 0, 1)
                _mode = 3
            end
        elseif (_mode == 3) then
            if (_modeClock >= 43) then
                _modeClock = _modeClock - 43
                _mode = 0

                lcdStatus = _bitReplace(_bitReplace(lcdStatus, 0, 1, 1), 0, 0, 1)
                requireInterrupt = (_bitExtract(lcdStatus, 3, 1) == 1)

                if (_frameSkips == 0) then
                    renderScan()
                end
            end
        end

        if (requireInterrupt and (_mode ~= lastMode)) then
            requestInterrupt(1)
        end

        if (scanLine == _mmuReadByte(0xFF45)) then
            lcdStatus = _bitReplace(lcdStatus, 1, 2, 1)
            
            if (_bitExtract(lcdStatus, 6, 1) == 1) then
                requestInterrupt(1)
            end
        else
            lcdStatus = _bitReplace(lcdStatus, 0, 2, 1)
        end
    end

    _mmuWriteByte(0xFF41, lcdStatus)
end

function enableScreen()
    if (screenEnabled) then
        return
    end

    _screenEnabled = true
    _mode = 1
    _modeClock = 0
    scanLine = 0

    local lcdStatus = _mmuReadByte(0xFF41)

    lcdStatus = _bitReplace(lcdStatus, 1, 0, 1)
    lcdStatus = _bitReplace(lcdStatus, 0, 0, 1)

    _mmuWriteByte(0xFF41, lcdStatus)
end

function disableScreen()
    if (not _screenEnabled) then
        return
    end

    _screenEnabled = false

    _mode = 1
    _modeClock = 0
    scanLine = 0

    local i = 0

    while (i < 160) do
        local a = 0

        while (a < 144) do
            _dxSetPixelColor(_screenPixels, i, a, 255, 255, 255)
            a = a + 1
        end

        i = i + 1
    end

    _dxSetTexturePixels(_screen, _screenPixels)

    _mmuWriteByte(0xFF41, _bitReplace(_bitReplace(_bitAnd(_mmuReadByte(0xFF41), 0x7C), 1, 0, 1), 0, 0, 1))
    _mmuWriteByte(0xFF44, scanLine)
end

function isScreenEnabled()
    return _screenEnabled
end

function getGPUMode()
    return _mode
end

function getGPUModeClock()
    return _modeClock
end

function getBackgroundPalettes()
    return _backgroundPalettes
end

function getSpritePalettes()
    return _spritePalettes
end

function saveGPUState()
    return {
        vramBank = vramBank,
        vram = _vram,
        scanLine = scanLine,
        colors = COLORS,
        mode = _mode,
        modeClock = _modeClock,
        tileSet = _tileSet,
        screenEnabled = _screenEnabled,
        backgroundPalettes = _backgroundPalettes,
        spritePalettes = _spritePalettes,
        backgroundPriority = _backgroundPriority
    }
end

function loadGPUState(state)
    vramBank = state.vramBank
    vram = state.vram
    scanLine = state.scanLine
    COLORS = state.colors
    _mode = state.mode
    _modeClock = state.modeClock
    _tileSet = state.tileSet
    _screenEnabled = state.screenEnabled
    _backgroundPalettes = state.backgroundPalettes
    _spritePalettes = state.spritePalettes
    _backgroundPriority = state.backgroundPriority

    _screen = dxCreateTexture(160, 144)
    _screenPixels = dxGetTexturePixels(_screen)

    _COLORS = COLORS
    _vram = vram

    mmuLinkVideoRam(vram)
end

addEventHandler("onClientResourceStart", resourceRoot,
    function()
        _mmuReadByte = mmuReadByte
        _mmuReadSignedByte = mmuReadSignedByte
        _mmuWriteByte = mmuWriteByte
    end
)