ByteStream = Class()

-----------------------------------
-- * Locals (for perfomance)
-----------------------------------

local _utf8_char = utf8.char

-----------------------------------
-- * Functions
-----------------------------------

function ByteStream:create(path)
    self.position = 0

    local file = File.open(path, true)

    if (not file) then
        Log.error("ByteStream", "Unable to open file %s", path)
        return false
    end

    self.file = file
end

function ByteStream:setPos(position)
    self.file:setPos(position)
    self.position = self.file:getPos()

    return (position == self.position)
end

function ByteStream:setOffset(offset)
    return self:setPos(self:getPos() + offset)
end

function ByteStream:getPos()
    return self.file:getPos()
end

function ByteStream:isEOF()
    return self.file:isEOF()
end

function ByteStream:readByte()
    return self.file:read(1)
end

function ByteStream:writeByte(byte)
    return self.file:write(byte)
end

function ByteStream:close()
    self.file:close()
end
