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
-- * Locals
-----------------------------------

local _keypad = {}
local _onClientKeyHandler = false
local _debuggerEnabled = false

local _rom = nil
bios = nil

-----------------------------------
-- * Functions
-----------------------------------

function setupGameBoy()
    setupTimer()
    setupGPU()
    setupCPU()

    _keypad = {
        keys = {0x0f, 0x0f},
        column = 0
    }

    _onClientKeyHandler = false
end

function gameBoyLoadRom(romPath)
    _rom = loadRom(romPath)

    if (not _rom) then
        Log.error("GameBoy", "Unable to load ROM.")
    end
end

function gameBoyLoadBios(biosPath)
    bios = loadRom(biosPath, true)

    if (not bios) then
        Log.error("GameBoy", "Unable to load BIOS.")
    end
end

function startGameBoy()
    resetTimer()
    resetGPU()
    resetCPU()

    if (_rom ~= nil) then
        cpuLoadRom(_rom)

        _rom = nil
    end

    mmuLoadExternalRam()

    runCPU()

    _onClientKeyHandler = function(key, pressed)
        if (pressed) then
            onKeyDown(key)
        else
            onKeyUp(key)
        end
    end

    addEventHandler("onClientKey", root, _onClientKeyHandler)
end

function pauseGameBoy()
    pauseCPU()
end

function stopGameBoy()
    pauseGameBoy()
    resetGPU()
    resetCPU()

    removeEventHandler("onClientKey", root, _onClientKeyHandler)
end

function enableDebugger()
    _debuggerEnabled = true

    startDebugger()
end

function isDebuggerEnabled()
    return _debuggerEnabled
end

function readKeypad()
    if (_keypad.column == 0x10) then
        return _keypad.keys[1]
    elseif (_keypad.column == 0x20) then
        return _keypad.keys[2]
    end

    return 0xFF
end

function isBiosLoaded()
    return (bios ~= nil and #bios > 0)
end

function writeKeypad(value)
    _keypad.column = _bitAnd(value, 0x30)
end

function onKeyDown(key)
    if (key == "arrow_r") then
        _keypad.keys[2] = _bitAnd(_keypad.keys[2], 0xE)
        requestInterrupt(4)
    elseif (key == "arrow_l") then
        _keypad.keys[2] = _bitAnd(_keypad.keys[2], 0xD)
        requestInterrupt(4)
    elseif (key == "arrow_u") then
        _keypad.keys[2] = _bitAnd(_keypad.keys[2], 0xB)
        requestInterrupt(4)
    elseif (key == "arrow_d") then
        _keypad.keys[2] = _bitAnd(_keypad.keys[2], 0x7)
        requestInterrupt(4)
    elseif (key == "z") then
        _keypad.keys[1] = _bitAnd(_keypad.keys[1], 0xE)
        requestInterrupt(4)
    elseif (key == "x") then
        _keypad.keys[1] = _bitAnd(_keypad.keys[1], 0xD)
        requestInterrupt(4)
    elseif (key == "space") then
        _keypad.keys[1] = _bitAnd(_keypad.keys[1], 0xB)
        requestInterrupt(4)
    elseif (key == "enter") then
        _keypad.keys[1] = _bitAnd(_keypad.keys[1], 0x7)
        requestInterrupt(4)
    end
end

function onKeyUp(key)
    if (key == "arrow_r") then
        _keypad.keys[2] = _bitOr(_keypad.keys[2], 0x1)
    elseif (key == "arrow_l") then
        _keypad.keys[2] = _bitOr(_keypad.keys[2], 0x2)
    elseif (key == "arrow_u") then
        _keypad.keys[2] = _bitOr(_keypad.keys[2], 0x4)
    elseif (key == "arrow_d") then
        _keypad.keys[2] = _bitOr(_keypad.keys[2], 0x8)
    elseif (key == "z") then
        _keypad.keys[1] = _bitOr(_keypad.keys[1], 0x1)
    elseif (key == "x") then
        _keypad.keys[1] = _bitOr(_keypad.keys[1], 0x2)
    elseif (key == "space") then
        _keypad.keys[1] = _bitOr(_keypad.keys[1], 0x4)
    elseif (key == "enter") then
        _keypad.keys[1] = _bitOr(_keypad.keys[1], 0x8)
    end
end

-----------------------------------
-- * Events
-----------------------------------

addEventHandler("onClientResourceStart", resourceRoot, function()
    setupGameBoy()
    setupDebugger()

    breakpoint(0x0373)

    --gameBoyLoadBios("data/bios.gb")
    gameBoyLoadRom(ROM_PATH)

    startGameBoy()
    enableDebugger()
end)
