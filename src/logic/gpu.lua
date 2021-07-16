vramBank = 1
vram = {}
oam = {}

scanLine = 0

-----------------------------------
-- * Locals
-----------------------------------

local SCREEN_WIDTH, SCREEN_HEIGHT = guiGetScreenSize()

local _bitExtract = bitExtract
local _bitReplace = bitReplace
local _bitLShift = bitLShift
local _bitRShift = bitRShift
local _bitOr = bitOr
local _bitAnd = bitAnd

local COLORS = {
    {255, 255, 255},
    {192, 192, 192},
    {92, 92, 92},
    {0, 0, 0}
}

_COLORS = COLORS

local _vram = vram
local _oam = oam

local _mode = 0
local _modeClock = 0
local _tileSet = {}
local _screen = false
local _screenPixels = false
local _screenEnabled = true

local _backgroundPalettes = {}
local _spritePalettes = {}
local _backgroundPriority = {}

debugBackground = {{}, {}}

-----------------------------------
-- * Functions
-----------------------------------

function setupGPU()
    vram = {
        {}, {}
    }

    _vram = vram
    vramBank = 1

    oam = {}
    _oam = oam

    for i=1, 0x3000 do
        _vram[1][i] = 0
        _vram[2][i] = 0
    end

    _mode = 0
    _modeClock = 0

    scanLine = 0

    _tileSet = {}
    _screen = dxCreateTexture(160, 144)
    _screenPixels = dxGetTexturePixels(_screen)

    _screenEnabled = true
    _backgroundPriority = {}

    for i=0, 159 do
        _backgroundPriority[i + 1] = {}

        for a=0, 143 do
            dxSetPixelColor(_screenPixels, i, a, 255, 255, 255)
            _backgroundPriority[i + 1][a + 1] = {false, 0}
        end
    end

    for i=1, 8 do
        _backgroundPalettes[i] = {}
        _spritePalettes[i] = {}

        for j=1, 4 do
            _backgroundPalettes[i][j] = {
                0x0, {255, 255, 255}
            }

            _spritePalettes[i][j] = {
                0x0, {255, 255, 255}
            }
        end
    end

    dxSetTexturePixels(_screen, _screenPixels)

    addEventHandler("onClientRender", root, function()
        local width, height = 320 * (1920 / SCREEN_WIDTH), 288 * (1920 / SCREEN_WIDTH)
        dxDrawImage((SCREEN_WIDTH / 2) - (width / 2), (SCREEN_HEIGHT / 2) - (height / 2), width, height, _screen)
    end)
end

function resetGPU()
    _tileset = {}

    for i=1, 512 do
        _tileset[i] = {}

        for a=1, 8 do
            _tileset[i][a] = {0, 0, 0, 0, 0, 0, 0, 0}
        end
    end

    _mode = 1
    _modeClock = 0
    scanLine = 0

    vram = {
        {}, {}
    }

    _vram = vram
    vramBank = 1

    oam = {}
    _oam = oam

    for i=1, 0xF000 do
        _vram[1][i] = 0
        _vram[2][i] = 0
    end

    _screenEnabled = not isBiosLoaded()
    _backgroundPriority = {}

    for i=0, 159 do
        _backgroundPriority[i + 1] = {}

        for a=0, 143 do
            dxSetPixelColor(_screenPixels, i, a, 255, 255, 255)
            _backgroundPriority[i + 1][a + 1] = false
        end
    end

    if (_screenEnabled) then
        local lcdStatus = mmuReadByte(0xFF41)

        lcdStatus = _bitReplace(lcdStatus, 1, 1, 1)
        lcdStatus = _bitReplace(lcdStatus, 0, 0, 1)

        mmuWriteByte(0xFF41, lcdStatus)
    end
end

function renderTiles()
    local usingWindow = false
    local isCGB = isGameBoyColor()
    local bank = vramBank

    local lcdControl = mmuReadByte(0xFF40)
    local scrollY = mmuReadSignedByte(0xFF42)
    local scrollX = mmuReadSignedByte(0xFF43)
    local windowY = mmuReadByte(0xFF4A)
    local windowX = mmuReadByte(0xFF4B) - 7

    if (_bitExtract(lcdControl, 5, 1) == 1) then
       if (windowY <= mmuReadByte(0xFF44)) then
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
        if (_bitExtract(lcdControl, 3, 1) == 1) then
            backgroundMemory = 0x9C00
        else
            backgroundMemory = 0x9800
        end
    else
        if (_bitExtract(lcdControl, 6, 1) == 1) then
            backgroundMemory = 0x9C00
        else
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

    local row = math.floor(yPos / 8) * 32

    for i=0, 159 do
        if (scanLine >= 0 and scanLine <= 143 and i >= 0 and i <= 159) then
            local pixel = i
            local xPos = pixel + scrollX

            if (usingWindow) then
                if (pixel >= windowX) then
                    xPos = pixel - windowX
                end
            end

            if (xPos < 0) then
                xPos = xPos + 0xff
            elseif (xPos > 0xff) then
                xPos = xPos - 0xff
            end

            local column = math.floor(xPos / 8)
            local tileNum = 0

            local tileAddress = backgroundMemory + row + column

            local cgbAttributes = 0
            local cgbPalette = 0
            local cgbBank = false
            local cgbPriority = false
            local cgbFlipX = false
            local cgbFlipY = false

            if (isCGB) then
                vramBank = 2
                cgbAttributes = mmuReadByte(tileAddress)
                cgbPalette = _bitAnd(cgbAttributes, 0x07)
                cgbBank = (_bitExtract(cgbAttributes, 3, 1) == 1)
                cgbPriority = (_bitExtract(cgbAttributes, 7, 1) == 1)
                cgbFlipX = (_bitExtract(cgbAttributes, 5, 1) == 1)
                cgbFlipY = (_bitExtract(cgbAttributes, 6, 1) == 1)
                vramBank = bank
            end

            vramBank = 1
            if (unsigned) then
                tileNum = mmuReadByte(tileAddress)
            else
                tileNum = mmuReadSignedByte(tileAddress)
            end
            vramBank = bank

            local tileLocation = tileData

            if (unsigned) then
                tileLocation = tileLocation + tileNum * 16
            else
                tileLocation = tileLocation + (tileNum + 128) * 16
            end

            local line = (yPos % 8) * 2

            if (cgbFlipY) then
                line = line - 8
                line = line * -1
            end

            local byte1 = 0
            local byte2 = 0

            if (isCGB and cgbBank) then
                vramBank = 2
                byte1 = mmuReadByte(tileLocation + line)
                byte2 = mmuReadByte(tileLocation + line + 1)
                vramBank = bank
            else
                vramBank = 1
                byte1 = mmuReadByte(tileLocation + line)
                byte2 = mmuReadByte(tileLocation + line + 1)
                vramBank = bank
            end

            local colorBit = ((xPos % 8) - 7) * -1

            if (cgbFlipX) then
                colorBit = colorBit - 8
                colorBit = colorBit * -1
            end

            local colorNum = _bitLShift(_bitExtract(byte2, colorBit, 1), 1)
            colorNum = _bitOr(colorNum, _bitExtract(byte1, colorBit, 1))

            _backgroundPriority[pixel + 1][scanLine + 1] = {cgbPriority, colorNum}

            if (isCGB) then
                local color = _backgroundPalettes[cgbPalette + 1][colorNum + 1][2] or {255, 255, 255}

                if (isDebuggerEnabled() and isCGB) then
                    debugBackground[(cgbBank) and 2 or vramBank][tileLocation] = cgbPalette
                end

                dxSetPixelColor(_screenPixels, pixel, scanLine, color[1], color[2], color[3], 255)
            else
                local palette = mmuReadByte(0xFF47)

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

                dxSetPixelColor(_screenPixels, pixel, scanLine, COLORS[color + 1][1], COLORS[color + 1][2], COLORS[color + 1][3], 255)
            end
        end
    end
end

function renderSprites()
    local is8x16 = false
    local lcdControl = mmuReadByte(0xFF40)
    local isCGB = isGameBoyColor()
    local bank = vramBank

    if (_bitExtract(lcdControl, 2, 1) == 1) then
        is8x16 = true
    end

    local spritesRendered = 0
    local spritePriorityData = {}

    for i=0,39 do
        local index = i * 4
        local yPos = mmuReadByte(0xFE00 + index) - 16
        local xPos = mmuReadByte(0xFE00 + index + 1) - 8

        local ySize = (is8x16) and 16 or 8

        if (scanLine >= yPos and scanLine < (yPos + ySize)) then
            spritesRendered = spritesRendered + 1

            local tile = mmuReadByte(0xFE00 + index + 2)
            local attributes = mmuReadByte(0xFE00 + index + 3)

            local yFlip = false
            local xFlip = false
            local line = scanLine - yPos

            local cgbPalette = 0
            local cgbBank = false

            if (isCGB) then
                vramBank = 2
                cgbPalette = _bitAnd(attributes, 0x07)
                cgbBank = (_bitExtract(attributes, 3, 1) == 1)
                yFlip = (_bitExtract(attributes, 6, 1) == 1)
                xFlip = (_bitExtract(attributes, 5, 1) == 1)
                vramBank = bank
            else
                yFlip = (_bitExtract(attributes, 6, 1) == 1)
                xFlip = (_bitExtract(attributes, 5, 1) == 1)
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
                byte1 = mmuReadByte(address)
                byte2 = mmuReadByte(address + 1)
                vramBank = bank
            else
                vramBank = 1
                byte1 = mmuReadByte(address)
                byte2 = mmuReadByte(address + 1)
                vramBank = bank
            end

            for tilePixel=7,0,-1 do
                local xPixel = (-tilePixel) + 7
                local pixel = xPos + xPixel

                if (scanLine >= 0 and scanLine <= 143 and pixel >= 0 and pixel <= 159) then
                    local colorBit = tilePixel

                    if (xFlip) then
                        colorBit = colorBit - 7
                        colorBit = colorBit * -1
                    end

                    local colorNum = _bitLShift(_bitExtract(byte2, colorBit, 1), 1)
                    colorNum = _bitOr(colorNum, _bitExtract(byte1, colorBit, 1))

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
                
                                dxSetPixelColor(_screenPixels, pixel, scanLine, color[1], color[2], color[3], 255)
                            end
                        end
                    else
                        local palette = mmuReadByte((_bitExtract(attributes, 4, 1) == 1) and 0xFF49 or 0xFF48)

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

                        local bgColorR, bgColorG, bgColorB, _ = dxGetPixelColor(_screenPixels, pixel, scanLine)
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

                                dxSetPixelColor(_screenPixels, pixel, scanLine, COLORS[color + 1][1], COLORS[color + 1][2], COLORS[color + 1][3], 255)
                            end
                        end
                    end
                end
            end
        end

        if (spritesRendered == 10) then
            break
        end
    end
end

function renderScan()
    local lcdControl = mmuReadByte(0xFF40)

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
        mmuWriteByte((isSprites) and 0xFF6B or 0xFF69, _bitAnd(_bitRShift(color, 8), 0xFF), true)
    else
        mmuWriteByte((isSprites) and 0xFF6B or 0xFF69, _bitAnd(color, 0xFF), true)
    end
end

function setColorPalette(isSprites, value)
    local spec = (isSprites) and mmuReadByte(0xFF6A) or mmuReadByte(0xFF68)
    local index = _bitAnd(_bitRShift(spec, 1), 0x03)
    local palette = _bitAnd(_bitRShift(spec, 3), 0x07)
    local autoIncrement = (_bitExtract(spec, 7, 1) == 1)
    local hl = (_bitExtract(spec, 0, 1) == 1)

    if (autoIncrement) then
        local address = _bitAnd(spec, 0x3F)

        address = _bitAnd(address + 1, 0x3F)
        spec = _bitOr(_bitAnd(spec, 0x80), address)

        mmuWriteByte((isSprites) and 0xFF6A or 0xFF68, spec, true)
        updatePaletteSpec(isSprites, spec)
    end

    local paletteColor = (isSprites) and _spritePalettes[palette + 1][index + 1][1] or _backgroundPalettes[palette + 1][index + 1][1]
    local paletteColorFinal = (isSprites) and _spritePalettes[palette + 1][index + 1][2] or _backgroundPalettes[palette + 1][index + 1][2]

    if (hl) then
        paletteColor = _bitOr(_bitAnd(paletteColor, 0x00FF), _bitAnd(_bitLShift(value, 8), 0xFFFF))
    else
        paletteColor = _bitOr(_bitAnd(paletteColor, 0xFF00), value)
    end

    local redBit = _bitExtract(paletteColor, 0, 5) * 8
    local greenBit = _bitExtract(paletteColor, 5, 5) * 8
    local blueBit = _bitExtract(paletteColor, 10, 5) * 8

    paletteColorFinal = {redBit, greenBit, blueBit}

    if (isSprites) then
        _spritePalettes[palette + 1][index + 1][1] = paletteColor
        _spritePalettes[palette + 1][index + 1][2] = paletteColorFinal
    else
        _backgroundPalettes[palette + 1][index + 1][1] = paletteColor
        _backgroundPalettes[palette + 1][index + 1][2] = paletteColorFinal
    end
end

function gpuStep(ticks)
    local lcdStatus = mmuReadByte(0xFF41)

    if (not _screenEnabled) then
        mmuWriteByte(0xFF41, 0)

        lcdStatus = _bitAnd(lcdStatus, 0xFC)
        lcdStatus = _bitReplace(lcdStatus, 1, 0, 1)

        mmuWriteByte(0xFF41, lcdStatus)
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

                    registers.clock.m = registers.clock.m + clockCycles
                    registers.clock.t = registers.clock.t + (clockCycles * 4)
                end

                if (scanLine == 144) then
                    _mode = 1

                    lcdStatus = _bitReplace(lcdStatus, 1, 0, 1)
                    lcdStatus = _bitReplace(lcdStatus, 0, 1, 1)
                    requireInterrupt = (_bitExtract(lcdStatus, 4, 1) == 1)

                    dxSetTexturePixels(_screen, _screenPixels)

                    requestInterrupt(0)
                else
                    _mode = 2

                    lcdStatus = _bitReplace(lcdStatus, 1, 1, 1)
                    lcdStatus = _bitReplace(lcdStatus, 0, 0, 1)
                    requireInterrupt = (_bitExtract(lcdStatus, 5, 1) == 1)
                end
            end
        elseif (_mode == 1) then
            if (_modeClock >= 114) then
                _modeClock = _modeClock - 114
                scanLine = scanLine + 1

                if (scanLine >= 154) then
                    _mode = 2

                    lcdStatus = _bitReplace(lcdStatus, 1, 1, 1)
                    lcdStatus = _bitReplace(lcdStatus, 0, 0, 1)
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

                lcdStatus = _bitReplace(lcdStatus, 1, 1, 1)
                lcdStatus = _bitReplace(lcdStatus, 1, 0, 1)

                _mode = 3
            end
        elseif (_mode == 3) then
            if (_modeClock >= 43) then
                _modeClock = _modeClock - 43
                _mode = 0

                lcdStatus = _bitReplace(lcdStatus, 0, 1, 1)
                lcdStatus = _bitReplace(lcdStatus, 0, 0, 1)
                requireInterrupt = (_bitExtract(lcdStatus, 3, 1) == 1)

                renderScan()
            end
        end

        if (requireInterrupt and (_mode ~= lastMode)) then
            requestInterrupt(1)
        end

        if (scanLine == mmuReadByte(0xFF45)) then
            lcdStatus = _bitReplace(lcdStatus, 1, 2, 1)
            
            if (_bitExtract(lcdStatus, 6, 1) == 1) then
                requestInterrupt(1)
            end
        else
            lcdStatus = _bitReplace(lcdStatus, 0, 2, 1)
        end
    end

    mmuWriteByte(0xFF41, lcdStatus)
end

function enableScreen()
    if (screenEnabled) then
        return
    end

    _screenEnabled = true
    _mode = 1
    _modeClock = 0
    scanLine = 0

    local lcdStatus = mmuReadByte(0xFF41)

    lcdStatus = _bitReplace(lcdStatus, 1, 0, 1)
    lcdStatus = _bitReplace(lcdStatus, 0, 0, 1)

    mmuWriteByte(0xFF41, lcdStatus)
end

function disableScreen()
    if (not _screenEnabled) then
        return
    end

    _screenEnabled = false

    _mode = 1
    _modeClock = 0
    scanLine = 0

    for i=0, 159 do
        for a=0, 143 do
            dxSetPixelColor(_screenPixels, i, a, 255, 255, 255)
        end
    end

    dxSetTexturePixels(_screen, _screenPixels)

    local lcdStatus = mmuReadByte(0xFF41)

    lcdStatus = _bitAnd(lcdStatus, 0x7C)
    lcdStatus = _bitReplace(lcdStatus, 1, 0, 1)
    lcdStatus = _bitReplace(lcdStatus, 0, 0, 1)

    mmuWriteByte(0xFF41, lcdStatus)
    mmuWriteByte(0xFF44, scanLine)
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