GPU = Class()

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

-----------------------------------
-- * Functions
-----------------------------------

function GPU:create(gameboy)
    self.gameboy = gameboy

    self.vram = {}
    self.oam = {}

    for i=1, 0xF000 do
        self.vram[i] = 0
    end

    self.mode = 0
    self.modeclock = 0
    self.line = 0

    self.tileset = {}
    self.screen = dxCreateTexture(160, 144)
    self.screenPixels = dxGetTexturePixels(self.screen)

    self.screenEnabled = true
    self.delayCyclesLeft = 0

    for i=0, 159 do
        for a=0, 143 do
            dxSetPixelColor(self.screenPixels, i, a, 255, 255, 255)
        end
    end

    dxSetTexturePixels(self.screen, self.screenPixels)

    addEventHandler("onClientRender", root, function()
        dxDrawImage(0, 0, 320, 288, self.screen)
    end)
end

function GPU:reset()
    self.tileset = {}

    for i=1, 512 do
        self.tileset[i] = {}

        for a=1, 8 do
            self.tileset[i][a] = {0, 0, 0, 0, 0, 0, 0, 0}
        end
    end

    self.mode = 1
    self.modeclock = 0
    self.line = 0

    self.screenEnabled = true
    self.delayCyclesLeft = 0
end

function GPU:renderTiles()
    local mmu = self.gameboy.cpu.mmu

    local unsigned = true
    local usingWindow = false

    local tileData = 0x8000
    local backgroundMemory = 0x9C00

    local scanLine = self.line
    local scrollY = mmu:readByte(0xFF42)
    local scrollX = mmu:readByte(0xFF43)
    local windowY = mmu:readByte(0xFF4A)
    local windowX = mmu:readByte(0xFF4B) - 7

    if (_bitExtract(mmu:readByte(0xFF40), 5, 1) == 1) then
       if (windowY <= mmu:readByte(0xFF44)) then
           usingWindow = true
       end
    end

    if (_bitExtract(mmu:readByte(0xFF40), 4, 1) == 1) then
        tileData = 0x8000
    else
        tileData = 0x8800
        unsigned = false
    end

    if (not usingWindow) then
        if (_bitExtract(mmu:readByte(0xFF40), 3, 1) == 1) then
            backgroundMemory = 0x9C00
        else
            backgroundMemory = 0x9800
        end
    else
        if (_bitExtract(mmu:readByte(0xFF40), 6, 1) == 1) then
            backgroundMemory = 0x9C00
        else
            backgroundMemory = 0x9800
        end
    end

    local yPos = 0

    if (not usingWindow) then
        yPos = scrollY + self.line
    else
        yPos = self.line - windowY
    end

    local row = math.floor(yPos / 8) * 32

    for i=0, 159 do
        local xPos = i + scrollX

        if (usingWindow) then
            if (i >= windowX) then
                xPos = i - windowX
            end
        end

        local column = math.floor(xPos / 8)
        local tileNum = 0

        local tileAddress = backgroundMemory + row + column

        if (unsigned) then
            tileNum = mmu:readByte(tileAddress)
        else
            tileNum = mmu:readSignedByte(tileAddress)
        end

        local tileLocation = tileData

        if (unsigned) then
            tileLocation = tileLocation + tileNum * 16
        else
            tileLocation = tileLocation + (tileNum + 128) * 16
        end

        local line = (yPos % 8) * 2
        local byte1 = mmu:readByte(tileLocation + line)
        local byte2 = mmu:readByte(tileLocation + line + 1)

        local colorBit = ((xPos % 8) - 7) * -1
        local colorNum = _bitLShift(_bitExtract(byte2, colorBit, 1), 1)
        colorNum = _bitOr(colorNum, _bitExtract(byte1, colorBit, 1))

        local palette = mmu:readByte(0xFF47)

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
            dxSetPixelColor(self.screenPixels, i, scanLine, COLORS[color + 1][1], COLORS[color + 1][2], COLORS[color + 1][3], 255)
        end
    end
end

function GPU:renderSprites()
    local mmu = self.gameboy.cpu.mmu
    local is8x16 = false
    local lcdStatus = mmu:readByte(0xFF41)

    if (_bitExtract(lcdStatus, 2, 1) == 1) then
        is8x16 = true
    end

    local scanLine = self.line

    for i=0, 39 do
        local index = i * 4
        local yPos = mmu:readByte(0xFE00 + index) - 16
        local xPos = mmu:readByte(0xFE00 + index + 1) - 8
        local tile = mmu:readByte(0xFE00 + index + 2)
        local attributes = mmu:readByte(0xFE00 + index + 3)

        local yFlip = (_bitExtract(attributes, 6, 1) == 1)
        local xFlip = (_bitExtract(attributes, 5, 1) == 1)

        local ySize = (is8x16) and 16 or 8

        if (scanLine >= yPos and scanLine < (yPos + ySize)) then
            local line = scanLine - yPos

            if (yFlip) then
                line = line - ySize
                line = line * -1
            end

            line = line * 2
            
            local address = (0x8000 + (tile* 16)) + line
            local byte1 = mmu:readByte(address)
            local byte2 = mmu:readByte(address + 1)

            for tilePixel=7,0,-1 do
                local colorBit = tilePixel

                if (xFlip) then
                    colorBit = colorBit - 7
                    colorBit = colorBit * -1
                end

                local colorId = _bitExtract(byte2, colorBit, 1)

                local colorNum = _bitLShift(_bitExtract(byte2, colorBit, 1), 1)
                colorNum = _bitOr(colorNum, _bitExtract(byte1, colorBit, 1))

                local palette = mmu:readByte((_bitExtract(attributes, 4, 1) == 1) and 0xFF49 or 0xFF48)

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

                if (color ~= 0) then
                    local xPixel = (-tilePixel) + 7
                    local pixel = xPos + xPixel

                    if (scanLine >= 0 and scanLine <= 143 and pixel >= 0 and pixel <= 159) then
                        dxSetPixelColor(self.screenPixels, pixel, scanLine, COLORS[color + 1][1], COLORS[color + 1][2], COLORS[color + 1][3], 255)
                    end
                end
            end
        end
    end
end

function GPU:renderScan()
    local lcdControl = self.gameboy.cpu.mmu:readByte(0xFF40)

    if (_bitExtract(lcdControl, 0) == 1) then
        self:renderTiles()
    end

    if (_bitExtract(lcdControl, 1) == 1) then
        self:renderSprites()
    end
end

function GPU:step()
    local mmu = self.gameboy.cpu.mmu
    local modeclock = self.modeclock
    local mode = self.mode

    if (not self.screenEnabled) then
        return
    end

    --[[if (not self.screenEnabled) then
        if (self.delayCyclesLeft > 0) then
            self.delayCyclesLeft = self.delayCyclesLeft - self.gameboy.cpu.registers.clock.t

            if (self.delayCyclesLeft <= 0) then
                self.screenEnabled = true

                self.mode = 0
                self.modeclock = 0
                self.line = 0
                self.delayCyclesLeft = 0

                return
            end
        end

        return
    end]]

    local lcdStatus = mmu:readByte(0xFF41)

    modeclock = modeclock + self.gameboy.cpu.registers.clock.m

    local lastMode = self.mode
    local requireInterrupt = false

    if (mode == 0) then
        if (modeclock >= 51) then
            modeclock = modeclock - 51
            self.line = self.line + 1

            if (self.line == 144) then
                self.mode = 1

                lcdStatus = _bitReplace(lcdStatus, 1, 0, 1)
                lcdStatus = _bitReplace(lcdStatus, 0, 1, 1)
                requireInterrupt = (_bitExtract(lcdStatus, 4, 1) == 1)

                dxSetTexturePixels(self.screen, self.screenPixels)

                self.gameboy.cpu:requestInterrupt(0)
            else
                self.mode = 2

                lcdStatus = _bitReplace(lcdStatus, 1, 1, 1)
                lcdStatus = _bitReplace(lcdStatus, 0, 0, 1)
                requireInterrupt = (_bitExtract(lcdStatus, 5, 1) == 1)
            end
        end
    elseif (mode == 1) then
        if (modeclock >= 114) then
            modeclock = modeclock - 114
            self.line = self.line + 1

            if (self.line >= 154) then
                self.mode = 2

                lcdStatus = _bitReplace(lcdStatus, 1, 1, 1)
                lcdStatus = _bitReplace(lcdStatus, 0, 0, 1)
                requireInterrupt = (_bitExtract(lcdStatus, 5, 1) == 1)

                self.line = 0
            end
        end
    elseif (mode == 2) then
        if (modeclock >= 20) then
            modeclock = modeclock - 20

            lcdStatus = _bitReplace(lcdStatus, 1, 1, 1)
            lcdStatus = _bitReplace(lcdStatus, 1, 0, 1)

            self.mode = 3
        end
    elseif (mode == 3) then
        if (modeclock >= 43) then
            modeclock = modeclock - 43
            self.mode = 0

            lcdStatus = _bitReplace(lcdStatus, 0, 1, 1)
            lcdStatus = _bitReplace(lcdStatus, 0, 0, 1)
            requireInterrupt = (_bitExtract(lcdStatus, 3, 1) == 1)

            if (self.screenEnabled) then
                self:renderScan()
            end
        end
    end

    if (requireInterrupt and (self.mode ~= lastMode)) then
        self.gameboy.cpu:requestInterrupt(1)
    end

    if (self.line == mmu:readByte(0xFF45)) then
        lcdStatus = _bitReplace(lcdStatus, 0, 2, 1)
        
        if (_bitExtract(lcdStatus, 6, 1) == 1) then
            self.gameboy.cpu:requestInterrupt(1)
        end
    end

    mmu:writeByte(0xFF41, lcdStatus)

    self.modeclock = modeclock
end

function GPU:enableScreen()
    if (self.screenEnabled) then
        return
    end

    self.screenEnabled = true
end

function GPU:disableScreen()
    if (not self.screenEnabled) then
        return
    end

    self.screenEnabled = false

    self.mode = 1
    self.modeclock = 0
    self.line = 0
    self.delayCyclesLeft = 0

    local lcdStatus = self.gameboy.cpu.mmu:readByte(0xFF41)

    lcdStatus = _bitReplace(lcdStatus, 1, 1, 1)
    lcdStatus = _bitReplace(lcdStatus, 0, 0, 1)

    self.gameboy.cpu.mmu:writeByte(0xFF41, lcdStatus)
    self.gameboy.cpu.mmu:writeByte(0xFF44, self.line)
end