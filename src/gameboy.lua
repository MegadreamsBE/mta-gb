-----------------------------------
-- * Locals
-----------------------------------

local _bitAnd = bitAnd
local _bitOr = bitOr

-----------------------------------
-- * Constants
-----------------------------------

local ROM_PATH = "data/Crystalis (USA).gbc"

-----------------------------------
-- * Locals
-----------------------------------

local _keypad = {}
local _onClientKeyHandler = false
local _debuggerEnabled = false
local _isGameBoyColor = false
local _isControlDown = false
local _isShiftDown = false

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

    local cgbValue = _rom[0x0143 + 1]

    if (cgbValue == 0x80 or cgbValue == 0xC0) then
        setGameBoyColorMode(true)
        return 1
    end
    
    setGameBoyColorMode(false)

    return 0
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
    elseif (key == "lctrl" or key == "rctrl") then
        _isControlDown = true
    elseif (key == "lshift" or key == "rshift") then
        _isShiftDown = true
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
    elseif (key == "lctrl" or key == "rctrl") then
        _isControlDown = false
    elseif (key == "lshift" or key == "rshift") then
        _isShiftDown = false
    elseif (key == "f1" or key == "F1") then
        if (_isShiftDown) then
            loadState(1)
            pauseCPU()

            local frameRendered = false
            local mode3Passed = false

            while (not frameRendered) do
                local lastScanLine = getScanLine()
                gpuStep(1)

                if (getScanLine() == 144 and getGPUMode() == 1 and mode3Passed and getFrameSkips() == 0) then
                    frameRendered = true
                end

                if (getGPUMode() == 3 and getFrameSkips() == 0) then
                    mode3Passed = true
                end
            end
        elseif (_isControlDown) then
            saveState(1)
        end
    elseif (key == "f2" or key == "F2") then
        if (_isShiftDown) then
            loadState(2)
            pauseCPU()

            local frameRendered = false
            local mode3Passed = false

            while (not frameRendered) do
                local lastScanLine = getScanLine()
                gpuStep(1)

                if (getScanLine() == 144 and getGPUMode() == 1 and mode3Passed and getFrameSkips() == 0) then
                    frameRendered = true
                end

                if (getGPUMode() == 3 and getFrameSkips() == 0) then
                    mode3Passed = true
                end
            end
        elseif (_isControlDown) then
            saveState(2)
        end
    elseif (key == "f3" or key == "F3") then
        if (_isShiftDown) then
            loadState(3)
            pauseCPU()

            local frameRendered = false
            local mode3Passed = false

            while (not frameRendered) do
                local lastScanLine = getScanLine()
                gpuStep(1)

                if (getScanLine() == 144 and getGPUMode() == 1 and mode3Passed and getFrameSkips() == 0) then
                    frameRendered = true
                end

                if (getGPUMode() == 3 and getFrameSkips() == 0) then
                    mode3Passed = true
                end
            end
        elseif (_isControlDown) then
            saveState(3)
        end
    elseif (key == "f4" or key == "F4") then
        if (_isShiftDown) then
            loadState(4)
            pauseCPU()

            local frameRendered = false
            local mode3Passed = false

            while (not frameRendered) do
                local lastScanLine = getScanLine()
                gpuStep(1)

                if (getScanLine() == 144 and getGPUMode() == 1 and mode3Passed and getFrameSkips() == 0) then
                    frameRendered = true
                end

                if (getGPUMode() == 3 and getFrameSkips() == 0) then
                    mode3Passed = true
                end
            end
        elseif (_isControlDown) then
            saveState(4)
        end
    end
end

function setGameBoyColorMode(toggle)
    _isGameBoyColor = toggle
end

function isGameBoyColor()
    return _isGameBoyColor
end

function saveState(slot)
    local state = {
        bios = bios,
        cpu = saveCPUState(),
        gpu = saveGPUState(),
        timer = saveTimerState(),
        mmu = saveMMUState(),
        romPath = getRomPath(),
    }

    local file = fileCreate("data/state_" .. slot .. ".dat")

    if (file) then
        fileWrite(file, serialize(state))
        fileClose(file)
    end
end

function loadState(slot)
    local file = fileOpen("data/state_" .. slot .. ".dat", true)

    if (file) then
        local data = fileRead(file, fileGetSize(file))
        local state = unserialize(data)
        fileClose(file)

        if (state) then
            bios = state.bios
            loadCPUState(state.cpu)
            loadMMUState(state.mmu)
            loadGPUState(state.gpu)
            loadTimerState(state.timer)
            setRomPath(state.romPath)
        end
    end
end

function serialize(tbl)
    local data = inspect(tbl)

    data = data:gsub("<[0-9]*>", "")

    return data
end

function unserialize(str)
    local func, error = loadstring("return " .. str)

    if (func) then
        return func()
    end

    return nil
end

-----------------------------------
-- * Events
-----------------------------------

addEventHandler("onClientResourceStart", resourceRoot, function()
    debug.sethook(nil)
    setupGameBoy()
    setupDebugger()

    if (gameBoyLoadRom(ROM_PATH)) then
        if (isGameBoyColor()) then
            gameBoyLoadBios("data/gbc_bios.bin")
        else
            --gameBoyLoadBios("data/bios.gb")
        end
    end
    
    startGameBoy()
    --enableDebugger()
end, true, "low-1")

addEvent("gb:cpu:reset", false)