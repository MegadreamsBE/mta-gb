vram = {}
oam = {}

scanLine = 0

-----------------------------------
-- * Locals
-----------------------------------

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

-----------------------------------
-- * Functions
-----------------------------------

function setupGPU()
    vram = {}
    _vram = vram

    oam = {}
    _oam = oam

    for i=1, 0xF000 do
        _vram[i] = 0
    end

    _mode = 0
    _modeClock = 0

    scanLine = 0

    _tileSet = {}
    _screen = dxCreateTexture(160, 144)
    _screenPixels = dxGetTexturePixels(_screen)

    _screenEnabled = true

    for i=0, 159 do
        for a=0, 143 do
            dxSetPixelColor(_screenPixels, i, a, 255, 255, 255)
        end
    end

    dxSetTexturePixels(_screen, _screenPixels)

    addEventHandler("onClientRender", root, function()
        dxDrawImage(0, 0, 320, 288, _screen)
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

    _screenEnabled = true

    local lcdStatus = mmuReadByte(0xFF41)

    lcdStatus = _bitReplace(lcdStatus, 1, 1, 1)
    lcdStatus = _bitReplace(lcdStatus, 0, 0, 1)

    mmuWriteByte(0xFF41, lcdStatus)
end

function renderTiles()
    local usingWindow = false

    local scrollY = mmuReadSignedByte(0xFF42)
    local scrollX = mmuReadSignedByte(0xFF43)
    local windowY = mmuReadByte(0xFF4A)
    local windowX = mmuReadByte(0xFF4B) - 7

    if (_bitExtract(mmuReadByte(0xFF40), 5, 1) == 1) then
       if (windowY <= mmuReadByte(0xFF44)) then
           usingWindow = true
       end
    end

    local unsigned = true

    local tileData = 0x8000
    local backgroundMemory = 0x9C00

    if (_bitExtract(mmuReadByte(0xFF40), 4, 1) == 1) then
        tileData = 0x8000
    else
        tileData = 0x8800
        unsigned = false
    end

    if (not usingWindow) then
        if (_bitExtract(mmuReadByte(0xFF40), 3, 1) == 1) then
            backgroundMemory = 0x9C00
        else
            backgroundMemory = 0x9800
        end
    else
        if (_bitExtract(mmuReadByte(0xFF40), 6, 1) == 1) then
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

        if (unsigned) then
            tileNum = mmuReadByte(tileAddress)
        else
            tileNum = mmuReadSignedByte(tileAddress)
        end

        local tileLocation = tileData

        if (unsigned) then
            tileLocation = tileLocation + tileNum * 16
        else
            tileLocation = tileLocation + (tileNum + 128) * 16
        end

        local line = (yPos % 8) * 2
        local byte1 = mmuReadByte(tileLocation + line)
        local byte2 = mmuReadByte(tileLocation + line + 1)

        local colorBit = ((xPos % 8) - 7) * -1
        local colorNum = _bitLShift(_bitExtract(byte2, colorBit, 1), 1)
        colorNum = _bitOr(colorNum, _bitExtract(byte1, colorBit, 1))

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

        if (scanLine >= 0 and scanLine <= 143 and i >= 0 and i <= 159) then
            dxSetPixelColor(_screenPixels, pixel, scanLine, COLORS[color + 1][1], COLORS[color + 1][2], COLORS[color + 1][3], 255)
        end
    end
end

function renderSprites()
    local is8x16 = false
    local lcdControl = mmuReadByte(0xFF40)

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

            local yFlip = (_bitExtract(attributes, 6, 1) == 1)
            local xFlip = (_bitExtract(attributes, 5, 1) == 1)
            local line = scanLine - yPos

            if (yFlip) then
                line = line - ySize
                line = line * -1
            end

            line = line * 2
            
            local address = (0x8000 + (tile* 16)) + line
            local byte1 = mmuReadByte(address)
            local byte2 = mmuReadByte(address + 1)

            for tilePixel=7,0,-1 do
                local colorBit = tilePixel

                if (xFlip) then
                    colorBit = colorBit - 7
                    colorBit = colorBit * -1
                end

                local colorId = _bitExtract(byte2, colorBit, 1)

                local colorNum = _bitLShift(_bitExtract(byte2, colorBit, 1), 1)
                colorNum = _bitOr(colorNum, _bitExtract(byte1, colorBit, 1))

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

                local xPixel = (-tilePixel) + 7
                local pixel = xPos + xPixel

                if (scanLine >= 0 and scanLine <= 143 and pixel >= 0 and pixel <= 159) then
                    local bgColorR, bgColorG, bgColorB, _ = dxGetPixelColor(_screenPixels, pixel, scanLine)
                    local avoidRender = false

                    if (spritePriorityData[pixel] ~= nil) then
                        if (spritePriorityData[pixel] <= xPos) then
                            avoidRender = true
                        end
                    end

                    if (not avoidRender and colorNum ~= 0) then
                        if ((_bitExtract(attributes, 7, 1) == 0) or 
                            ((_bitExtract(attributes, 7, 1) == 1) and (bgColorR == COLORS[1][1] and bgColorG == COLORS[1][2] and bgColorB == COLORS[1][3]))) then
                            spritePriorityData[pixel] = xPos

                            dxSetPixelColor(_screenPixels, pixel, scanLine, COLORS[color + 1][1], COLORS[color + 1][2], COLORS[color + 1][3], 255)
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

function gpuStep(ticks)
    if (not _screenEnabled) then
        return
    end

    local lcdStatus = mmuReadByte(0xFF41)

    if (_bitExtract(mmuReadByte(0xFF40), 7) ~= 1) then
        mmuWriteByte(0xFF41, 0)

        lcdStatus = _bitAnd(lcdStatus, 0xFC)
        lcdStatus = _bitReplace(lcdStatus, 1, 0, 1)

        mmuWriteByte(0xFF41, lcdStatus)
        return
    end

    _modeClock = _modeClock + ticks

    local lastMode = _mode
    local requireInterrupt = false

    if (_mode == 0) then
        if (_modeClock >= 51) then
            _modeClock = _modeClock - 51
            scanLine = scanLine + 1

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

            if (_screenEnabled) then
                renderScan()
            end
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

    mmuWriteByte(0xFF41, lcdStatus)
end

function enableScreen()
    if (screenEnabled) then
        return
    end

    _screenEnabled = true
    _mode = 1

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