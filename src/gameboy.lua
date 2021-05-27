GameBoy = Class()

-----------------------------------
-- * Locals
-----------------------------------

local _bitAnd = bitAnd
local _bitOr = bitOr

-----------------------------------
-- * Constants
-----------------------------------

local ROM_PATH = "data/Tetris.gb"

-----------------------------------
-- * Functions
-----------------------------------

function GameBoy:create()
    self.gpu = GPU(self)
    self.cpu = CPU(self)
    self.keypad = {
        keys = {0x0f, 0x0f},
        column = 0
    }

    self.onClientKeyHandler = false
end

function GameBoy:load(romPath)
    self.rom = Rom(romPath)

    if (not self.rom:load()) then
        Log.error("GameBoy", "Unable to load ROM.")
    end
end

function GameBoy:start()
    self.gpu:reset()
    self.cpu:reset()

    if (self.rom ~= nil) then
        self.cpu:loadRom(self.rom)
    end

    self.cpu:run()

    self.onClientKeyHandler = function(key, pressed)
        if (pressed) then
            self:onKeyDown(key)
        else
            self:onKeyUp(key)
        end
    end

    addEventHandler("onClientKey", root, self.onClientKeyHandler)
end

function GameBoy:pause()
    self.cpu:pause()
end

function GameBoy:stop()
    self:pause()
    self.gpu:reset()
    self.cpu:reset()

    removeEventHandler("onClientKey", root, self.onClientKeyHandler)
end

function GameBoy:attachDebugger(debugger)
    self.debugger = debugger
    self.debugger:start(self)
end

function GameBoy:readKeypad()
    if (self.keypad.column == 0x10) then
        return self.keypad.keys[1]
    elseif (self.keypad.column == 0x20) then
        return self.keypad.keys[2]
    end

    return 0x0
end

function GameBoy:writeKeypad(value)
    self.keypad.column = _bitAnd(value, 0x30)
end

function GameBoy:onKeyDown(key)
    if (key == "arrow_r") then
        self.keypad.keys[2] = _bitAnd(self.keypad.keys[2], 0xE)
        self.cpu:requestInterrupt(4)
    elseif (key == "arrow_l") then
        self.keypad.keys[2] = _bitAnd(self.keypad.keys[2], 0xD)
        self.cpu:requestInterrupt(4)
    elseif (key == "arrow_u") then
        self.keypad.keys[2] = _bitAnd(self.keypad.keys[2], 0xB)
        self.cpu:requestInterrupt(4)
    elseif (key == "arrow_d") then
        self.keypad.keys[2] = _bitAnd(self.keypad.keys[2], 0x7)
        self.cpu:requestInterrupt(4)
    elseif (key == "z") then
        self.keypad.keys[1] = _bitAnd(self.keypad.keys[1], 0xE)
        self.cpu:requestInterrupt(4)
    elseif (key == "x") then
        self.keypad.keys[1] = _bitAnd(self.keypad.keys[1], 0xD)
        self.cpu:requestInterrupt(4)
    elseif (key == "space") then
        self.keypad.keys[1] = _bitAnd(self.keypad.keys[1], 0xB)
        self.cpu:requestInterrupt(4)
    elseif (key == "enter") then
        self.keypad.keys[1] = _bitAnd(self.keypad.keys[1], 0x7)
        self.cpu:requestInterrupt(4)
    end
end

function GameBoy:onKeyUp(key)
    if (key == "arrow_r") then
        self.keypad.keys[2] = _bitOr(self.keypad.keys[2], 0x1)
    elseif (key == "arrow_l") then
        self.keypad.keys[2] = _bitOr(self.keypad.keys[2], 0x2)
    elseif (key == "arrow_u") then
        self.keypad.keys[2] = _bitOr(self.keypad.keys[2], 0x4)
    elseif (key == "arrow_d") then
        self.keypad.keys[2] = _bitOr(self.keypad.keys[2], 0x8)
    elseif (key == "z") then
        self.keypad.keys[1] = _bitOr(self.keypad.keys[1], 0x1)
    elseif (key == "x") then
        self.keypad.keys[1] = _bitOr(self.keypad.keys[1], 0x2)
    elseif (key == "space") then
        self.keypad.keys[1] = _bitOr(self.keypad.keys[1], 0x4)
    elseif (key == "enter") then
        self.keypad.keys[1] = _bitOr(self.keypad.keys[1], 0x8)
    end
end

-----------------------------------
-- * Events
-----------------------------------

addEventHandler("onClientResourceStart", resourceRoot, function()
    local gameboy = GameBoy()
    local debugger = Debugger()

    --debugger:breakpoint(0x0B90)

    gameboy:load(ROM_PATH)
    gameboy:start()
    gameboy:attachDebugger(debugger)
end)
