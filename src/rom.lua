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
        local fileData = fileRead(file, 10800)

        if (fileData) then
            for i=1, #fileData do
                data[#data + 1] = string.byte(fileData:sub(i, i))
            end
        end
    end

    fileClose(file)

    return data
end

function setRomPath(path)
    romPath = path
end

function getRomPath()
    return romPath
end