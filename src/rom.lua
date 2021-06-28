-----------------------------------
-- * Functions
-----------------------------------

local romPath = false

function loadRom(path, isBios)
    if (not isBios) then
        romPath = path
    end

    local file = fileOpen(path, true)

    if (not file) then
        Log.error("Rom", "Unable to open file %s", path)
        return false
    end

    local data = {}

    while (not fileIsEOF(file)) do
         data[#data + 1] = utf8.byte(file:read(1))
    end

    fileClose(file)

    return data
end

function getRomPath()
    return romPath
end