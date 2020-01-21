GPU = Class()

-----------------------------------
-- * Locals
-----------------------------------

local _bitExtract = bitExtract
local _bitReplace = bitReplace
local _bitLShift = bitLShift
local _bitOr = bitOr

-----------------------------------
-- * Functions
-----------------------------------

function GPU:create(gameboy)
    self.gameboy = gameboy

    self.vram = {}

    for i=1, 0xF000 do
        self.vram[i] = 0
    end

    self.mode = 0
    self.modeclock = 0
    self.line = 0

    self.tileset = {}
    self.screen = dxCreateTexture(160, 144)
    self.screenPixels = dxGetTexturePixels(self.screen)

    for i=0, 159 do
        for a=0, 143 do
            dxSetPixelColor(self.screenPixels, i, a, 255, 255, 255)
        end
    end

    dxSetTexturePixels(self.screen, self.screenPixels)

    --[[addEventHandler("onClientRender", root, function()
        dxDrawImage(0, 0, 320, 288, self.screen)
    end)]]
end

function GPU:reset()
    self.tileset = {}

    for i=1, 512 do
        self.tileset[i] = {}

        for a=1, 8 do
            self.tileset[i][a] = {0, 0, 0, 0, 0, 0, 0, 0}
        end
    end
end

function GPU:renderScan()
    --[[local mmu = self.gameboy.cpu.mmu

    local unsigned = true
    local usingWindow = false

    local tileData = 0x8000
    local backgroundMemory = 0x9C00

    local scrollY = mmu:readByte(0xFF42)
    local scrollX = mmu:readByte(0xFF43)
    local windowY = mmu:readByte(0xFF4A)
    local windowX = mmu:readByte(0xFF4B) - 7

    if (_bitExtract(mmu:readByte(0xFF40), 5, 1) == 1) then
       if (windowY <= mmu:readbyte(0xFF44)) then
           usingWindow = true
       end
    end

    if (_bitExtract(mmu:readByte(0xFF40), 4, 1) ~= 1) then
        tileData = 0x8800
        unsigned = false
    end

    if (not usingWindow) then
        if (_bitExtract(mmu:readByte(0xFF40), 3, 1) ~= 1) then
            backgroundMemory = 0x9800
        end
    else
        if (_bitExtract(mmu:readByte(0xFF40), 6, 1) ~= 1) then
            backgroundMemory = 0x9800
        end
    end

    local yPos = 0

    if (not usingWindow) then
        yPos = scrollY + mmu:readByte(0xFF44)
    else
        yPos = mmu:readByte(0xFF44) - windowY
    end

    local row = (yPos / 8) * 32

    for i=0, 159 do
        local xPos = i + scrollX

        if (usingWindow) then
            if (i >= windowX) then
                xPos = i - windowX
            end
        end

        local column = (xPos / 8)
        local tileNum = 0

        local tileAddress = backgroundMemory + row + column

        tileNum = mmu:readByte(tileAddress)

        local tileLocation = tileData + tileNum * 16

        local line = (yPos % 8) * 2
        local data1 = mmu:readByte(tileLocation + line)
        local data2 = mmu:readByte(tileLocation + line + 1)

        local colorBit = ((xPos % 8) - 7) * -1
        local colorNum = _bitLShift(_bitExtract(data2, colorBit, 1), 1)
        colorNum = _bitOr(colorNum, _bitExtract(data1, colorBit, 1))

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

        local r, g, b = 0, 0, 0

        if (color == 0) then
            r, g, b = 255, 255, 255
        elseif (color == 1) then
            r, g, b = 192, 192, 192
        elseif (color == 2) then
            r, g, b = 92, 92, 92
        end

        local finaly = mmu:readByte(0xFF44)

        if (finaly >= 0 and finaly <= 143 and i >= 0 and i <= 159) then
            dxSetPixelColor(self.screenPixels, i, finaly, r, g, b, 255)
        end
    end]]
end

function GPU:step()
    local mmu = self.gameboy.cpu.mmu
    local modeclock = self.modeclock
    local mode = self.mode
    local line = self.line

    local lcdStatus = mmu:readByte(0xFF41)

    lcdStatus = _bitReplace(lcdStatus, 0, 0, 2)

    if (mode == 2 or mode == 3) then
        lcdStatus = _bitReplace(lcdStatus, 1, 0, 1)
    elseif (mode == 1) then
        lcdStatus = _bitReplace(lcdStatus, 1, 1, 1)
    end

    mmu:writeByte(0xFF41, lcdStatus)

    if (_bitExtract(mmu:readByte(0xFF40), 7, 1) ~= 1) then
        return
    end

    modeclock = modeclock + self.gameboy.cpu.registers.clock.t
    mmu:writeByte(0xFF44, line)

    if (mode == 0) then
        if (modeclock >= 204) then
            self.modeclock = 0
            line = line + 1

            if (line == 143) then
                self.mode = 1
                dxSetTexturePixels(self.screen, self.screenPixels)
            else
                self.mode = 2
            end

            self.line = line
        end
    elseif (mode == 1) then
        if (modeclock >= 456) then
            self.modeclock = 0
            line = line + 1

            if (line > 153) then
                self.mode = 2
                line = 0
            end

            self.line = line
        end
    elseif (mode == 2) then
        if (modeclock >= 80) then
            self.modeclock = 0
            self.mode = 3
        end
    elseif (self.mode == 3) then
        if (self.modeclock >= 172) then
            self.modeclock = 0
            self.mode = 0

            self:renderScan()
        end
    end
end
