vramBank = 1
vram = {}

scanLine = 0
windowLine = 0
renderWindowThisLine = 0

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

local _upscaleShader = false

local _vram = vram

local _mode = 0
local _modeClock = 0
local _screen = false
local _screenPixels = false
local _screenEnabled = true
local _screenDelay = 0

local _backgroundPalettes = createFilledTable(8)
local _spritePalettes = createFilledTable(8)
local _backgroundPriority = createFilledTable(160)

debugBackground = {createFilledTable(0x10000), createFilledTable(0x10000)}

local _readByteSwitch = false
local _writeByteSwitch = false
local _mmuReadByte = false
local _mmuReadSignedByte = false
local _mmuWriteByte = false

cacheAttributes = createFilledTable(0xFFFF, {})
local _cacheAttributes = cacheAttributes
local _colorBitCache = createFilledTable(8, createFilledTable(0x100, -1))
local _pixels = createFilledTable(160, createFilledTable(144, {false, 255, 255, 255}))

local _frameSkips = 0

-----------------------------------
-- * Functions
-----------------------------------

function setupGPU()
    vram = {
        createFilledTable(0x10000), createFilledTable(0x10000)
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

    _screen = dxCreateTexture(160, 144)
    _screenPixels = dxGetTexturePixels(_screen)

    _screenEnabled = true
    _backgroundPriority = createFilledTable(160)
    _upscaleShader = dxCreateShader("shaders/upscale.fx")

    for i=0, 159 do
        _backgroundPriority[i + 1] = createFilledTable(144)

        for a=0, 143 do
            _dxSetPixelColor(_screenPixels, i, a, 255, 255, 255)

            local pixels = _pixels[i + 1][a + 1]
            pixels[1] = false
            pixels[2] = 255
            pixels[3] = 255
            pixels[4] = 255

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
        local debuggerEnabled = isDebuggerEnabled()

        local width = (debuggerEnabled and 800 or 1200) * math.min((SCREEN_WIDTH / 1920), (SCREEN_HEIGHT / 1080))
        local height = width * 0.9

        local scaleW, scaleH = width / 160, height / 144

        dxSetShaderValue(_upscaleShader, "tex", _screen)
        dxSetShaderValue(_upscaleShader, "scale", {scaleW, scaleH})

        dxDrawImageSection((SCREEN_WIDTH / 2) - (width / 2), (SCREEN_HEIGHT / 2) - (height / 2), width, height, 0, 0, 160 * scaleW, 144 * scaleH, _upscaleShader)
    
        --[[if (debuggerEnabled) then
            for i=0, 19 do
                dxDrawLine((SCREEN_WIDTH / 2) - (width / 2) + ((i * 8) * scaleW), (SCREEN_HEIGHT / 2) - (height / 2), (SCREEN_WIDTH / 2) - (width / 2) + ((i * 8) * scaleW), (SCREEN_HEIGHT / 2) - (height / 2) + (144 * scaleH), tocolor(0, 0, 0, 255), 1)
            
                for a=0, 17 do
                    dxDrawLine((SCREEN_WIDTH / 2) - (width / 2), (SCREEN_HEIGHT / 2) - (height / 2) + ((a * 8) * scaleH), (SCREEN_WIDTH / 2) - (width / 2) + (160 * scaleW), (SCREEN_HEIGHT / 2) - (height / 2) + ((a * 8) * scaleH), tocolor(0, 0, 0, 255), 1)
                end
            end
        end]]

        --[[if (debuggerEnabled) then
            local lcdControl = _readByteSwitch[0xFF40](0xFF40)
            local windowY = _readByteSwitch[0xFF4A](0xFF4A)
            local windowX = _readByteSwitch[0xFF4B](0xFF4B) - 7

            if (_bitExtract(lcdControl, 5, 1) ~= 1) then
                return
            end

            dxDrawRectangle(
                (SCREEN_WIDTH / 2) - (width / 2) + windowX * scaleW, 
                (SCREEN_HEIGHT / 2) - (height / 2) + windowY * scaleH, 
                (160 - windowX) * scaleW, 
                (144 - windowY) * scaleH, tocolor(255, 0, 0, 100)) ]]
        --end
    end)
end

function resetGPU()
    vram = {
        createFilledTable(0x10000), createFilledTable(0x10000)
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

    _screen = dxCreateTexture(160, 144)
    _screenPixels = dxGetTexturePixels(_screen)

    _screenEnabled = true
    _backgroundPriority = createFilledTable(160)

    for i=0, 159 do
        _backgroundPriority[i + 1] = createFilledTable(144)

        for a=0, 143 do
            _dxSetPixelColor(_screenPixels, i, a, 255, 255, 255)

            local pixels = _pixels[i + 1][a + 1]
            pixels[1] = false
            pixels[2] = 255
            pixels[3] = 255
            pixels[4] = 255
            
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
        local lcdStatus = _readByteSwitch[0xFF41](0xFF41)

        lcdStatus = _bitReplace(lcdStatus, 1, 1, 1)
        lcdStatus = _bitReplace(lcdStatus, 0, 0, 1)

        _writeByteSwitch[0xFF41](0xFF41, lcdStatus, true)
    end

    cacheAttributes = createFilledTable(0xFFFF, {})
    _cacheAttributes = cacheAttributes

    mmuLinkCache(cacheAttributes)

    if (not isBiosLoaded()) then
        disableScreen()
        enableScreen()
    end
end

function renderWindow(lcdControl, windowX)
    local isCGB = isGameBoyColor
    local bank = vramBank
    local debuggerEnabled = isDebuggerEnabled()

    local unsigned = true

    local tileData = 0x8000

    if (_bitExtract(lcdControl, 4, 1) == 1) then
        tileData = 0x8000
    else
        tileData = 0x8800
        unsigned = false
    end

    local windowTileMapArea = _bitExtract(lcdControl, 6, 1)

    local backgroundMemory = 0x9C00

    if (windowTileMapArea ~= 1) then
        backgroundMemory = 0x9800
    end

    local yPos = windowLine
    
    if (yPos < 0) then
        yPos = yPos + 0x100
    elseif (yPos > 0xff) then
        yPos = yPos - 0x100
    end

    local line = (yPos % 8) * 2
    local row = ((yPos / 8) - ((yPos / 8) % 1)) * 32

    local cgbAttributes = 0
    local cgbPalette = 0
    local cgbBank = 1
    local cgbPriority = false
    local cgbFlipX = false
    local cgbFlipY = false
    local palette = _readByteSwitch[0xFF47](0xFF47)

    local i = windowX
    local lastTileAddress = 0
    local colorNum = 0

    local xPos = 0

    while (i < 160) do
        xPos = i - windowX

        if (xPos < 0) then
            xPos = xPos + 0x100
        elseif (xPos > 0xff) then
            xPos = xPos - 0x100
        end

        local tileAddress = backgroundMemory + row + ((xPos / 8) - ((xPos / 8) % 1))

        if (lastTileAddress ~= tileAddress) then
            local adjustedAddress = (tileAddress - 0x8000) + 1

            if (isCGB) then
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

            local tileNum = _vram[1][adjustedAddress]
            
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
                lineWithFlip = (16 - -(0 - lineWithFlip)) - 2
            end

            local colorBit = ((xPos % 8) - 7) * -1

            if (cgbFlipX) then
                colorBit = (colorBit - 7) * -1
            end

            local bitCache = _colorBitCache[colorBit + 1]
            local bit1Value = _vram[cgbBank][(tileLocation - 0x8000) + 2 + lineWithFlip]
            local bit2Value = _vram[cgbBank][(tileLocation - 0x8000) + 1 + lineWithFlip]

            local bit1 = bitCache[bit1Value + 1]
            local bit2 = bitCache[bit2Value + 1]

            if (bit1 == -1) then
                bit1 = _bitExtract(bit1Value, colorBit, 1)
                bitCache[bit1Value + 1] = bit1
            end

            if (bit2 == -1) then
                bit2 = _bitExtract(bit2Value, colorBit, 1)
                bitCache[bit2Value + 1] = bit2
            end

            colorNum = bit1 * 2 + bit2
        end

        local bgPriority = _backgroundPriority[i + 1][scanLine + 1]

        bgPriority[1] = cgbPriority
        bgPriority[2] = colorNum
        
        if (isCGB) then
            local color = _backgroundPalettes[cgbPalette + 1][colorNum + 1][2]

            if (debuggerEnabled) then
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

                if (debuggerEnabled) then
                    debugBackground[bank][tileLocation] = cgbPalette
                end
            end
            
            local pixels = _pixels[i + 1][scanLine + 1]

            if (color[1] ~= pixels[2] or color[2] ~= pixels[3] or color[3] ~= pixels[4]) then
                pixels[1] = true
                pixels[2] = color[1]
                pixels[3] = color[2]
                pixels[4] = color[3]
            end
        else
            local color = _bitOr(_bitLShift(_bitExtract(palette, (colorNum * 2) + 1, 1), 1), _bitExtract(palette, (colorNum * 2), 1))

            local pixels = _pixels[i + 1][scanLine + 1]

            if (COLORS[color + 1][1] ~= pixels[2] or COLORS[color + 1][2] ~= pixels[3] or COLORS[color + 1][3] ~= pixels[4]) then
                pixels[1] = true
                pixels[2] = COLORS[color + 1][1]
                pixels[3] = COLORS[color + 1][2]
                pixels[4] = COLORS[color + 1][3]
            end
        end

        i = i + 1
    end

    windowLine = windowLine + 1
end

function renderBackground(lcdControl, maxWidth)
    if (scanLine >= 144) then
        return
    end

    local isCGB = isGameBoyColor
    local bank = vramBank
    local debuggerEnabled = isDebuggerEnabled()

    local scrollY = _mmuReadSignedByte(0xFF42)
    local scrollX = _mmuReadSignedByte(0xFF43)
    
    local unsigned = true
    local tileData = 0x8000

    if (_bitExtract(lcdControl, 4, 1) == 0) then
        tileData = 0x8800
        unsigned = false
    end

    local yPos = 0
    local bgTileMapArea = _bitExtract(lcdControl, 3, 1)

    local backgroundMemory = 0x9C00

    if (bgTileMapArea ~= 1) then
        backgroundMemory = 0x9800
    end
    
    yPos = scrollY + scanLine

    if (yPos < 0) then
        yPos = yPos + 0x100
    elseif (yPos > 0xff) then
        yPos = yPos - 0x100
    end

    local line = (yPos % 8) * 2
    local row = ((yPos / 8) - ((yPos / 8) % 1)) * 32

    local cgbAttributes = 0
    local cgbPalette = 0
    local cgbBank = 1
    local cgbPriority = false
    local cgbFlipX = false
    local cgbFlipY = false
    local palette = _readByteSwitch[0xFF47](0xFF47)

    local i = 0
    local lastTileAddress = 0
    local colorNum = 0

    local xPos = 0

    while (i < maxWidth) do
        xPos = i + scrollX

        if (xPos < 0) then
            xPos = xPos + 0x100
        elseif (xPos > 0xff) then
            xPos = xPos - 0x100
        end

        local tileAddress = backgroundMemory + row + ((xPos / 8) - ((xPos / 8) % 1))

        if (lastTileAddress ~= tileAddress) then
            local adjustedAddress = (tileAddress - 0x8000) + 1

            if (isCGB) then
                local attributes = _cacheAttributes[adjustedAddress]

                if (attributes[1] == nil) then
                    cgbAttributes = _vram[2][adjustedAddress]

                    cgbPalette = _bitAnd(cgbAttributes, 0x07)
                    cgbBank = (_bitAnd(cgbAttributes, 0x08) >= 1) and 2 or 1
                    cgbPriority = _bitAnd(cgbAttributes, 0x80) >= 1
                    cgbFlipX = _bitAnd(cgbAttributes, 0x20) >= 1
                    cgbFlipY = _bitAnd(cgbAttributes, 0x40) >= 1

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

            local tileNum = _vram[1][adjustedAddress]
            
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
                lineWithFlip = (16 - -(0 - lineWithFlip)) - 2
            end

            local colorBit = ((xPos % 8) - 7) * -1

            if (cgbFlipX) then
                colorBit = ((colorBit - 7) * -1)
            end

            local bitCache = _colorBitCache[colorBit + 1]
            local bit1Value = _vram[cgbBank][(tileLocation - 0x8000) + 2 + lineWithFlip]
            local bit2Value = _vram[cgbBank][(tileLocation - 0x8000) + 1 + lineWithFlip]

            local bit1 = bitCache[bit1Value + 1]
            local bit2 = bitCache[bit2Value + 1]

            if (bit1 == -1) then
                bit1 = _bitExtract(bit1Value, colorBit, 1)
                bitCache[bit1Value + 1] = bit1
            end

            if (bit2 == -1) then
                bit2 = _bitExtract(bit2Value, colorBit, 1)
                bitCache[bit2Value + 1] = bit2
            end

            colorNum = bit1 * 2 + bit2
        end

        local bgPriority = _backgroundPriority[i + 1][scanLine + 1]

        bgPriority[1] = cgbPriority
        bgPriority[2] = colorNum

        if (isCGB) then
            local color = _backgroundPalettes[cgbPalette + 1][colorNum + 1][2]

            if (debuggerEnabled) then
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

                if (debuggerEnabled) then
                    debugBackground[bank][tileLocation] = cgbPalette
                end
            end

            local pixels = _pixels[i + 1][scanLine + 1]

            if (color[1] ~= pixels[2] or color[2] ~= pixels[3] or color[3] ~= pixels[4]) then
                pixels[1] = true
                pixels[2] = color[1]
                pixels[3] = color[2]
                pixels[4] = color[3]
            end
        else
            local color = _bitOr(_bitLShift(_bitExtract(palette, (colorNum * 2) + 1, 1), 1), _bitExtract(palette, (colorNum * 2), 1))

            local pixels = _pixels[i + 1][scanLine + 1]

            if (1~=2 or COLORS[color + 1][1] ~= pixels[2] or COLORS[color + 1][2] ~= pixels[3] or COLORS[color + 1][3] ~= pixels[4]) then
                pixels[1] = true
                pixels[2] = COLORS[color + 1][1]
                pixels[3] = COLORS[color + 1][2]
                pixels[4] = COLORS[color + 1][3]

                if (i == 56 and scanLine == 40) then
                    pixels[2] = 255
                    pixels[3] = 0
                    pixels[4] = 0

                    print("Color: " .. color)
                    print("ColorNum: " .. colorNum)
                    print("Palette: " .. palette)
                    print("lcdControl: " .. lcdControl)
                end
            end
        end

        i = i + 1
    end
end

function renderSprites(lcdControl)
    local ySize = 8
    local isCGB = isGameBoyColor
    local bank = vramBank

    if (_bitExtract(lcdControl, 2, 1) == 1) then
        ySize = 16
    end

    local spritesRendered = 0
    local spritePriorityData = {}

    local i = 0

    while (i < 40) do
        local index = i * 4
        local yPos = _mmuReadByte(0xFE00 + index) - 16
        local xPos = _mmuReadByte(0xFE00 + index + 1) - 8

        if (scanLine >= yPos and scanLine < (yPos + ySize)) then
            spritesRendered = spritesRendered + 1

            local tile = _mmuReadByte(0xFE00 + index + 2)
            local attributes = _mmuReadByte(0xFE00 + index + 3)

            if (ySize == 16) then
                tile = _bitAnd(tile, 0xFE)
            end

            local yFlip = false
            local xFlip = false
            local line = scanLine - yPos

            local cgbPalette = 0
            local cgbBank = false
            local cgbPriority = false

            if (isCGB) then
                cgbPalette = _bitAnd(attributes, 0x07)
                cgbBank = _bitAnd(attributes, 0x08) > 1
                xFlip = _bitAnd(attributes, 0x20) > 1
                yFlip = _bitAnd(attributes, 0x40) > 1
                cgbPriority = _bitAnd(attributes, 0x80) >= 1
            else
                xFlip = _bitAnd(attributes, 0x20) > 1
                yFlip = _bitAnd(attributes, 0x40) > 1
            end

            if (yFlip) then
                line = (ySize - 1) - line
            end

            local address = (0x8000 + (tile * 16)) + (line * 2)
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
                        colorBit = 7 - colorBit
                    end

                    local bitCache = _colorBitCache[colorBit + 1]

                    local bit1 = bitCache[byte2 + 1]
                    local bit2 = bitCache[byte1 + 1]

                    if (bit1 == -1) then
                        bit1 = _bitExtract(byte2, colorBit, 1)
                        bitCache[byte2 + 1] = bit1
                    end

                    if (bit2 == -1) then
                        bit2 = _bitExtract(byte1, colorBit, 1)
                        bitCache[byte1 + 1] = bit2
                    end

                    colorNum = bit1 * 2 + bit2

                    if (isCGB) then
                        local avoidRender = false

                        if ((_backgroundPriority[pixel + 1][scanLine + 1][1] and _backgroundPriority[pixel + 1][scanLine + 1][2] > 0 and 
                            _bitExtract(lcdControl, 0, 1) == 1) or spritePriorityData[pixel + 1] ~= nil) then
                            avoidRender = true
                        end

                        if (not avoidRender and colorNum ~= 0) then
                            if (not cgbPriority or 
                                (cgbPriority and _backgroundPriority[pixel + 1][scanLine + 1][2] == 0)) then
                                spritePriorityData[pixel + 1] = true

                                local color = _spritePalettes[cgbPalette + 1][colorNum + 1][2] or {255, 255, 255}

                                local pixels = _pixels[pixel + 1][scanLine + 1]

                                if (color[1] ~= pixels[2] or color[2] ~= pixels[3] or color[3] ~= pixels[4]) then
                                    pixels[1] = true
                                    pixels[2] = color[1]
                                    pixels[3] = color[2]
                                    pixels[4] = color[3]
                                end
                            end
                        end
                    else
                        local color = _bitOr(_bitLShift(_bitExtract(palette, (colorNum * 2) + 1, 1), 1), _bitExtract(palette, (colorNum * 2), 1))

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

                                local pixels = _pixels[pixel + 1][scanLine + 1]

                                if (COLORS[color + 1][1] ~= pixels[2] or COLORS[color + 1][2] ~= pixels[3] or COLORS[color + 1][3] ~= pixels[4]) then
                                    pixels[1] = true
                                    pixels[2] = COLORS[color + 1][1]
                                    pixels[3] = COLORS[color + 1][2]
                                    pixels[4] = COLORS[color + 1][3]
                                end
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
    local lcdControl = _readByteSwitch[0xFF40](0xFF40)

    if (_bitAnd(lcdControl, 0x1) > 0 or isGameBoyColor) then
        local windowX = _readByteSwitch[0xFF4B](0xFF4B) - 7

        if (not renderWindowThisLine or _bitExtract(lcdControl, 5, 1) == 0 or windowX > 160) then
            renderBackground(lcdControl, 160)
        else

            renderBackground(lcdControl, windowX)
            renderWindow(lcdControl, windowX)
        end
    end

    if (_bitAnd(lcdControl, 0x2) > 0) then
        renderSprites(lcdControl)
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
    local spec = (isSprites) and _readByteSwitch[0xFF6A](0xFF6A) or _readByteSwitch[0xFF68](0xFF68)
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
    local lcdStatus = _readByteSwitch[0xFF41](0xFF41)

    if (not _screenEnabled) then
        lcdStatus = _bitOr(_bitAnd(lcdStatus, 0xFC), _bitAnd(_mode, 0x03))
        _writeByteSwitch[0xFF41](0xFF41, lcdStatus, true)
    end

    _modeClock = _modeClock + ticks

    if (_screenEnabled and _screenDelay > 0) then
        _screenDelay = _screenDelay - ticks

        if (_screenDelay <= 0) then
            _screenDelay = 0

            if (_bitExtract(lcdStatus, 5, 1) == 1) then
                requestInterrupt(1)
            end

            if (scanLine == _readByteSwitch[0xFF45](0xFF45)) then
                lcdStatus = _bitReplace(lcdStatus, 1, 2, 1)
                
                if (_bitExtract(lcdStatus, 6, 1) == 1) then
                    requestInterrupt(1)
                end
            else
                lcdStatus = _bitReplace(lcdStatus, 0, 2, 1)
            end
        end
        
        return
    end

    local lastMode = _mode
    local requireInterrupt = false

    if (_screenEnabled and _screenDelay == 0) then
        if (_mode == 0) then
            if (_modeClock >= 51) then
                _modeClock = _modeClock - 51
                scanLine = scanLine + 1

                if (isGameBoyColor and hdmaEnabled and (not isCPUPaused() or hasIncomingInterrupt())) then
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
                        for i = 0, 159 do
                            for a = 0, 143 do
                                local color = _pixels[i + 1][a + 1]

                                if (color[1] == true) then
                                    color[1] = false
                                    _dxSetPixelColor(_screenPixels, i, a, color[2], color[3], color[4])
                                end
                            end
                        end

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

                if (scanLine == 153) then
                    _mode = 2

                    lcdStatus = _bitReplace(_bitReplace(lcdStatus, 1, 1, 1), 0, 0, 1)
                    requireInterrupt = (_bitExtract(lcdStatus, 5, 1) == 1)

                    scanLine = 0
                    windowLine = 0
                    renderWindowThisLine = false

                    if (isDebuggerEnabled() and isGameBoyColor and _frameSkips == 0) then
                        debugBackground = {debugBackground[1], debugBackground[2]}
                    end
                end
            end
        elseif (_mode == 2) then
            renderWindowThisLine = (renderWindowThisLine or _readByteSwitch[0xFF4A](0xFF4A) == scanLine)

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

        if (scanLine == _readByteSwitch[0xFF45](0xFF45)) then
            lcdStatus = _bitReplace(lcdStatus, 1, 2, 1)
            
            if (_bitExtract(lcdStatus, 6, 1) == 1) then
                requestInterrupt(1)
            end
        else
            lcdStatus = _bitReplace(lcdStatus, 0, 2, 1)
        end
    end

    _writeByteSwitch[0xFF41](0xFF41, lcdStatus, true)
end

function enableScreen()
    if (_screenEnabled) then
        return
    end

    _screenEnabled = true
    _mode = 0
    _modeClock = 0
    scanLine = 0
    windowLine = 0
    _screenDelay = 110

    local lcdStatus = _readByteSwitch[0xFF41](0xFF41)

    lcdStatus = _bitReplace(lcdStatus, 1, 0, 1)
    lcdStatus = _bitReplace(lcdStatus, 0, 0, 1)

    if (scanLine == _readByteSwitch[0xFF45](0xFF45)) then
        lcdStatus = _bitReplace(lcdStatus, 1, 2, 1)

        requestInterrupt(1)
    else
        lcdStatus = _bitReplace(lcdStatus, 0, 2, 1)
    end

    _writeByteSwitch[0xFF41](0xFF41, lcdStatus, true)
end

function disableScreen()
    if (not _screenEnabled) then
        return
    end

    _screenEnabled = false

    _mode = 0
    _modeClock = 0
    scanLine = 0
    windowLine = 0

    local i = 0

    while (i < 160) do
        local a = 0

        while (a < 144) do
            _dxSetPixelColor(_screenPixels, i, a, 255, 255, 255)

            local pixels = _pixels[i + 1][a + 1]
            pixels[1] = true
            a = a + 1
        end

        i = i + 1
    end

    _dxSetTexturePixels(_screen, _screenPixels)

    _writeByteSwitch[0xFF41](0xFF41, _bitAnd(_readByteSwitch[0xFF41](0xFF41), 0x7C), true)
end

function gpuResize(width, height)
    SCREEN_WIDTH = width
    SCREEN_HEIGHT = height
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

function getScanLine()
    return scanLine
end

function getFrameSkips()
    return _frameSkips
end

function getBackgroundPalettes()
    return _backgroundPalettes
end

function getSpritePalettes()
    return _spritePalettes
end

function getScreenPixels()
    return _screenPixels
end

function saveGPUState()
    return {
        vramBank = vramBank,
        vram = _vram,
        scanLine = scanLine,
        colors = COLORS,
        mode = _mode,
        modeClock = _modeClock,
        screenEnabled = _screenEnabled,
        backgroundPalettes = _backgroundPalettes,
        spritePalettes = _spritePalettes,
        backgroundPriority = _backgroundPriority,
        frameSkips = _frameSkips
    }
end

function loadGPUState(state)
    resetGPU()

    vramBank = state.vramBank
    vram = state.vram
    scanLine = state.scanLine
    COLORS = state.colors
    _mode = state.mode
    _modeClock = state.modeClock
    _screenEnabled = state.screenEnabled
    _backgroundPalettes = state.backgroundPalettes
    _spritePalettes = state.spritePalettes
    _backgroundPriority = state.backgroundPriority
    _frameSkips = state.frameSkips

    _screen = dxCreateTexture(160, 144, "dxt1")
    _screenPixels = dxGetTexturePixels(_screen)

    _COLORS = COLORS
    _vram = vram

    mmuLinkVideoRam(vram)
    mmuLinkCache(_cacheAttributes)
end

addEventHandler("onClientResourceStart", resourceRoot,
    function()
        _mmuReadByte = mmuReadByte
        _mmuReadSignedByte = mmuReadSignedByte
        _mmuWriteByte = mmuWriteByte
        _readByteSwitch = readByteSwitch
        _writeByteSwitch = writeByteSwitch
    end
)