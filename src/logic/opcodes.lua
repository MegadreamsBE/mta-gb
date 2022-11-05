-----------------------------------
-- * Locals & Constants
-----------------------------------

local LOG_TWO = math.log(2)

local _math_abs = math.abs
local _math_log = math.log
local _bitOr = bitOr
local _bitAnd = bitAnd
local _bitXor = bitXor
local _bitNot = bitNot
local _bitExtract = bitExtract
local _bitReplace = bitReplace
local _bitLShift = bitLShift

local _string_format = string.format

local _readTwoRegisters = readTwoRegisters
local _writeTwoRegisters = writeTwoRegisters

local _mmuReadByte = false
local _mmuWriteByte = false
local _mmuReadUInt16 = false
local _mmuReadSignedByte = false
local _mmuPushStack = false
local _mmuPopStack = false

local _registers = false

local helper_inc = function(value)
    _registers[8][3] = (_bitAnd(value, 0x0f) == 0x0f) -- FLAG_HALFCARRY

    value = (value + 1) % 0x100

    _registers[8][1] = (value == 0) and true or false -- FLAG_ZERO
    _registers[8][2] = false -- FLAG_SUBSTRACT

    return value
end

local helper_inc16 = function(value)
    return (value + 1) % 0x10000
end

local helper_dec = function(value)
    _registers[8][3] = (_bitAnd(value, 0x0f) == 0x00) -- FLAG_HALFCARRY

    value = (value - 1) % 0x100

    _registers[8][1] = (value == 0) and true or false -- FLAG_ZERO
    _registers[8][2] = true -- FLAG_SUBSTRACT

    return value
end

local helper_dec16 = function(value)
    return (value - 1) % 0x10000
end

local helper_add = function(value, add)
    result = (value + add) % 0x100

    _registers[8][3] = (_bitAnd(_bitXor(_bitXor(value, add), result), 0x10) == 0x10) -- FLAG_HALFCARRY
    _registers[8][4] = (value + add > 0xFF)  -- FLAG_CARRY

    _registers[8][1] = (result == 0) and true or false -- FLAG_ZERO
    _registers[8][2] = false -- FLAG_SUBSTRACT

    return result
end

local helper_adc = function(value, add)
    local carry = _registers[8][4] and 1 or 0

    result = (value + add + carry) % 0x100

    _registers[8][3] = (_bitAnd(_bitXor(_bitXor(value, add), result), 0x10) == 0x10) -- FLAG_HALFCARRY
    _registers[8][4] = (value + add + carry > 0xFF) -- FLAG_CARRY

    _registers[8][1] = (result == 0) and true or false -- FLAG_ZERO
    _registers[8][2] = false -- FLAG_SUBSTRACT

    return result
end

local helper_add_sp = function(value, add)
    result = (value + add) % 0x10000

    _registers[8][3] = (_bitAnd(_bitXor(_bitXor(value, add), result), 0x10) == 0x10) -- FLAG_HALFCARRY
    _registers[8][4] = (_bitAnd(_bitXor(_bitXor(value, add), result), 0x100) == 0x100) -- FLAG_CARRY

    _registers[8][1] = false -- FLAG_ZERO
    _registers[8][2] = false -- FLAG_SUBSTRACT

    return result
end

local helper_add16 = function(value, add)
    result = (value + add) % 0x10000

    _registers[8][3] = (_bitAnd(_bitXor(_bitXor(value, add), result), 0x1000) == 0x1000) -- FLAG_HALFCARRY
    _registers[8][4] = (value + add > 0xFFFF) -- FLAG_CARRY

    --_registers[8][1] = (result == 0) and true or false -- FLAG_ZERO
    _registers[8][2] = false -- FLAG_SUBSTRACT

    return result
end

local helper_sub = function(value, sub)
    result = value - sub

    _registers[8][3] = (_bitAnd(_bitXor(_bitXor(value, sub), result), 0x10) ~= 0) -- FLAG_HALFCARRY
    _registers[8][4] = (_bitAnd(_bitXor(_bitXor(value, sub), result), 0x100) ~= 0) -- FLAG_CARRY

    result = result % 0x100

    _registers[8][1] = (result == 0) and true or false -- FLAG_ZERO
    _registers[8][2] = true -- FLAG_SUBSTRACT

    return result
end

local helper_sbc = function(value, sub)
    local carry = _registers[8][4] and 1 or 0
    result = value - sub - carry

    _registers[8][3] = ((_bitAnd(value, 0x0F) - _bitAnd(sub, 0x0F) - carry) < 0) -- FLAG_HALFCARRY
    _registers[8][4] = (result < 0) -- FLAG_CARRY

    result = result % 0x100

    _registers[8][1] = (result == 0) and true or false -- FLAG_ZERO
    _registers[8][2] = true -- FLAG_SUBSTRACT

    return result
end

local helper_and = function(value1, value2)
    local value = _bitAnd(value1, value2)

    _registers[8][1] = (value == 0) and true or false -- FLAG_ZERO
    _registers[8][2] = false -- FLAG_SUBSTRACT
    _registers[8][3] = true -- FLAG_HALFCARRY
    _registers[8][4] = false -- FLAG_CARRY

    return value
end

local helper_or = function(value1, value2)
    local value = _bitOr(value1, value2)

    _registers[8][1] = (value == 0) and true or false -- FLAG_ZERO
    _registers[8][2] = false -- FLAG_SUBSTRACT
    _registers[8][3] = false -- FLAG_HALFCARRY
    _registers[8][4] = false -- FLAG_CARRY

    return value
end

local helper_xor = function(value1, value2)
    local value = _bitXor(value1, value2)

    _registers[8][1] = (value == 0) and true or false -- FLAG_ZERO
    _registers[8][2] = false -- FLAG_SUBSTRACT
    _registers[8][3] = false -- FLAG_HALFCARRY
    _registers[8][4] = false -- FLAG_CARRY

    return value
end

local helper_lshift = function(value, bitSize)
    value = _bitReplace(value * 2, 0, 0, 1)

    local bitsCalculated = _math_log(value) / LOG_TWO
    local bits = (bitsCalculated - (bitsCalculated % 1)) + 1

    if (bits < 0) then
        bits = 0
    end

    if (bits > bitSize) then
        value = _bitReplace(value, 0, bits - 1, (bits - bitSize))
    end

    return value
end

local helper_rshift = function(value, bitSize)
    value = _bitReplace((value / 2) - ((value / 2) % 1), 0, bitSize - 1, 1)

    local bitsCalculated = _math_log(value) / LOG_TWO
    local bits = (bitsCalculated - (bitsCalculated % 1)) + 1

    if (bits < 0) then
        bits = 0
    end

    if (bits > bitSize) then
        value = _bitReplace(value, 0, bits - 1, (bits - bitSize))
    end

    return value
end

local helper_lrotate = function(value, bitSize)
    local bit = ((value / (2 ^ (bitSize - 1))) % 2 >= 1) and 1 or 0

    value = _bitReplace(value * 2, bit, 0, 1)

    local bitsCalculated = _math_log(value) / LOG_TWO
    local bits = (bitsCalculated - (bitsCalculated % 1)) + 1

    if (bits < 0) then
        bits = 0
    end

    if (bits > bitSize) then
        value = _bitReplace(value, 0, bits - 1, (bits - bitSize))
    end

    return value
end

local helper_rrotate = function(value, bitSize)
    local bit = ((value / (2 ^ 0)) % 2 >= 1) and 1 or 0

    value = _bitReplace((value / 2) - ((value / 2) % 1), bit, bitSize - 1, 1)

    local bitsCalculated = _math_log(value) / LOG_TWO
    local bits = (bitsCalculated - (bitsCalculated % 1)) + 1

    if (bits < 0) then
        bits = 0
    end

    if (bits > bitSize) then
        value = _bitReplace(value, 0, bits - 1, (bits - bitSize))
    end

    return value
end

local helper_rl = function(value, bitSize)
    local carry = _registers[8][4] and 1 or 0

    _registers[8][4] = (_bitAnd(value, 0x80) ~= 0) -- FLAG_CARRY

    local result = _bitOr(helper_lshift(value, bitSize), carry)

    _registers[8][1] = (result == 0) and true or false -- FLAG_ZERO
    _registers[8][2] = false -- FLAG_SUBSTRACT
    _registers[8][3] = false -- FLAG_HALFCARRY

    return result
end

local helper_rlc = function(value, bitSize)
    _registers[8][4] = (_bitAnd(value, 0x80) ~= 0) -- FLAG_CARRY

    local result = helper_lrotate(value, bitSize)

    _registers[8][1] = (result == 0) and true or false -- FLAG_ZERO
    _registers[8][2] = false -- FLAG_SUBSTRACT
    _registers[8][3] = false -- FLAG_HALFCARRY

    return result
end

local helper_rr = function(value, bitSize)
    local carry = _registers[8][4] and 0x80 or 0

    _registers[8][4] = (_bitAnd(value, 0x01) ~= 0) -- FLAG_CARRY

    local result = _bitOr(helper_rshift(value, bitSize), carry)

    _registers[8][1] = (result == 0) and true or false -- FLAG_ZERO
    _registers[8][2] = false -- FLAG_SUBSTRACT
    _registers[8][3] = false -- FLAG_HALFCARRY

    return result
end

local helper_rrc = function(value, bitSize)
    _registers[8][4] = (_bitAnd(value, 0x01) ~= 0) -- FLAG_CARRY

    local result = helper_rrotate(value, bitSize)

    _registers[8][1] = (result == 0) and true or false -- FLAG_ZERO
    _registers[8][2] = false -- FLAG_SUBSTRACT
    _registers[8][3] = false -- FLAG_HALFCARRY

    return result
end

local helper_sla = function(value, bitSize)
    _registers[8][4] = (_bitAnd(value, 0x80) ~= 0) -- FLAG_CARRY

    local result = helper_lshift(value, bitSize)

    _registers[8][1] = (result == 0) and true or false -- FLAG_ZERO
    _registers[8][2] = false -- FLAG_SUBSTRACT
    _registers[8][3] = false -- FLAG_HALFCARRY

    return result
end

local helper_sra = function(value, bitSize)
    _registers[8][4] = (_bitAnd(value, 0x01) ~= 0) -- FLAG_CARRY

    local result = helper_rshift(value, bitSize)

    if ((_bitAnd(value, 0x80) ~= 0)) then
        result = _bitOr(result, 0x80)
    end

    _registers[8][1] = (result == 0) and true or false -- FLAG_ZERO
    _registers[8][2] = false -- FLAG_SUBSTRACT
    _registers[8][3] = false -- FLAG_HALFCARRY

    return result
end

local helper_srl = function(value, bitSize)
    _registers[8][4] = (_bitAnd(value, 0x01) ~= 0) -- FLAG_CARRY

    local result = helper_rshift(value, bitSize)

    _registers[8][1] = (result == 0) and true or false -- FLAG_ZERO
    _registers[8][2] = false -- FLAG_SUBSTRACT
    _registers[8][3] = false -- FLAG_HALFCARRY

    return result
end

local helper_cp = function(value, cmp)
    _registers[8][1] = (value == cmp) and true or false -- FLAG_ZERO
    _registers[8][2] = true -- FLAG_SUBSTRACT
    _registers[8][3] = (_bitAnd(_math_abs(cmp), 0x0f) > (_bitAnd(value, 0x0f))) -- FLAG_HALFCARRY
    _registers[8][4] = (value < cmp) and true or false -- FLAG_CARRY
end

local helper_swap = function(value)
    local upperNibble = _bitAnd(value, 0xF0) / 16
    local lowerNibble = _bitAnd(value, 0x0F)

    value = (lowerNibble * 16) + upperNibble

    _registers[8][1] = (value == 0) -- FLAG_ZERO
    _registers[8][2] = false -- FLAG_SUBSTRACT
    _registers[8][3] = false -- FLAG_HALFCARRY
    _registers[8][4] = false -- FLAG_CARRY

    return value
end

local helper_not = function(value)
    value = _bitNot(value)

    if (value > 0xff) then
        value = _bitAnd(value, 0xFF)
    end

    return value
end

local helper_test = function(bit, value)
    _registers[8][1] = (_bitExtract(value, bit, 1) == 0) -- FLAG_ZERO
    _registers[8][2] = false -- FLAG_SUBSTRACT
    _registers[8][3] = true -- FLAG_HALFCARRY
end

local helper_set = function(bit, value)
    return _bitReplace(value, 1, bit, 1)
end

local helper_reset = function(bit, value)
    return _bitReplace(value, 0, bit, 1)
end

local ldn_nn = function(reg1, reg2, value16)
    if (reg1 == 's') then
        _registers[11] = value16
        return
    end

    _writeTwoRegisters(reg1, reg2, value16)
end

local cbOpcodes = {
    -- Opcode: 0x00
    function()
        _registers[2] = helper_rlc(_registers[2], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x01
    function()
        _registers[3] = helper_rlc(_registers[3], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x02
    function()
        _registers[4] = helper_rlc(_registers[4], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x03
    function()
        _registers[5] = helper_rlc(_registers[5], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x04
    function()
        _registers[6] = helper_rlc(_registers[6], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x05
    function()
        _registers[7] = helper_rlc(_registers[7], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x06
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_rlc(_mmuReadByte(address), 8))
    
        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0x07
    function()
        _registers[1] = helper_rlc(_registers[1], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x08
    function()
        _registers[2] = helper_rrc(_registers[2], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x09
    function()
        _registers[3] = helper_rrc(_registers[3], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x0a
    function()
        _registers[4] = helper_rrc(_registers[4], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x0b
    function()
        _registers[5] = helper_rrc(_registers[5], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x0c
    function()
        _registers[6] = helper_rrc(_registers[6], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x0d
    function()
        _registers[7] = helper_rrc(_registers[7], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x0e
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_rrc(_mmuReadByte(address), 8))
    
        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0x0f
    function()
        _registers[1] = helper_rrc(_registers[1], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x10
    function()
        _registers[2] = helper_rl(_registers[2], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x11
    function()
        _registers[3] = helper_rl(_registers[3], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x12
    function()
        _registers[4] = helper_rl(_registers[4], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x13
    function()
        _registers[5] = helper_rl(_registers[5], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x14
    function()
        _registers[6] = helper_rl(_registers[6], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x15
    function()
        _registers[7] = helper_rl(_registers[7], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x16
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_rl(_mmuReadByte(address), 8))
    
        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0x17
    function()
        _registers[1] = helper_rl(_registers[1], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x18
    function()
        _registers[2] = helper_rr(_registers[2], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x19
    function()
        _registers[3] = helper_rr(_registers[3], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x1a
    function()
        _registers[4] = helper_rr(_registers[4], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x1b
    function()
        _registers[5] = helper_rr(_registers[5], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x1c
    function()
        _registers[6] = helper_rr(_registers[6], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x1d
    function()
        _registers[7] = helper_rr(_registers[7], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x1e
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_rr(_mmuReadByte(address), 8))
    
        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0x1f
    function()
        _registers[1] = helper_rr(_registers[1], 8)
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x20
    function()
        _registers[2] = helper_sla(_registers[2], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x21
    function()
        _registers[3] = helper_sla(_registers[3], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x22
    function()
        _registers[4] = helper_sla(_registers[4], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x23
    function()
        _registers[5] = helper_sla(_registers[5], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x24
    function()
        _registers[6] = helper_sla(_registers[6], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x25
    function()
        _registers[7] = helper_sla(_registers[7], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x26
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_sla(_mmuReadByte(address), 8))

        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0x27
    function()
        _registers[1] = helper_sla(_registers[1], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x28
    function()
        _registers[2] = helper_sra(_registers[2], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x29
    function()
        _registers[3] = helper_sra(_registers[3], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x2a
    function()
        _registers[4] = helper_sra(_registers[4], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x2b
    function()
        _registers[5] = helper_sra(_registers[5], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x2c
    function()
        _registers[6] = helper_sra(_registers[6], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x2d
    function()
        _registers[7] = helper_sra(_registers[7], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x2e
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_sra(_mmuReadByte(address), 8))

        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0x2f
    function()
        _registers[1] = helper_sra(_registers[1], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x30
    function()
        _registers[2] = helper_swap(_registers[2])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x31
    function()
        _registers[3] = helper_swap(_registers[3])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x32
    function()
        _registers[4] = helper_swap(_registers[4])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x33
    function()
        _registers[5] = helper_swap(_registers[5])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x34
    function()
        _registers[6] = helper_swap(_registers[6])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x35
    function()
        _registers[7] = helper_swap(_registers[7])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x36
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_swap(_mmuReadByte(address), 8))

        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0x37
    function()
        _registers[1] = helper_swap(_registers[1])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x38
    function()
        _registers[2] = helper_srl(_registers[2], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x39
    function()
        _registers[3] = helper_srl(_registers[3], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x3a
    function()
        _registers[4] = helper_srl(_registers[4], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x3b
    function()
        _registers[5] = helper_srl(_registers[5], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x3c
    function()
        _registers[6] = helper_srl(_registers[6], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x3d
    function()
        _registers[7] = helper_srl(_registers[7], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x3e
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_srl(_mmuReadByte(address), 8))

        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0x3f
    function()
        _registers[1] = helper_srl(_registers[1], 8)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x40
    function()
        helper_test(0, _registers[2])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x41
    function()
        helper_test(0, _registers[3])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x42
    function()
        helper_test(0, _registers[4])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x43
    function()
        helper_test(0, _registers[5])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x44
    function()
        helper_test(0, _registers[6])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x45
    function()
        helper_test(0, _registers[7])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x46
    function()
        local address = _readTwoRegisters(6, 7)
        helper_test(0, _mmuReadByte(address))

        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0x47
    function()
        helper_test(0, _registers[1])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x48
    function()
        helper_test(1, _registers[2])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x49
    function()
        helper_test(1, _registers[3])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x4a
    function()
        helper_test(1, _registers[4])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x4b
    function()
        helper_test(1, _registers[5])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x4c
    function()
        helper_test(1, _registers[6])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x4d
    function()
        helper_test(1, _registers[7])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x4e
    function()
        local address = _readTwoRegisters(6, 7)
        helper_test(1, _mmuReadByte(address))

        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0x4f
    function()
        helper_test(1, _registers[1])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x50
    function()
        helper_test(2, _registers[2])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x51
    function()
        helper_test(2, _registers[3])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x52
    function()
        helper_test(2, _registers[4])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x53
    function()
        helper_test(2, _registers[5])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x54
    function()
        helper_test(2, _registers[6])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x55
    function()
        helper_test(2, _registers[7])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x56
    function()
        local address = _readTwoRegisters(6, 7)
        helper_test(2, _mmuReadByte(address))

        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0x57
    function()
        helper_test(2, _registers[1])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x58
    function()
        helper_test(3, _registers[2])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x59
    function()
        helper_test(3, _registers[3])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x5a
    function()
        helper_test(3, _registers[4])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x5b
    function()
        helper_test(3, _registers[5])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x5c
    function()
        helper_test(3, _registers[6])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x5d
    function()
        helper_test(3, _registers[7])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x5e
    function()
        local address = _readTwoRegisters(6, 7)
        helper_test(3, _mmuReadByte(address))

        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0x5f
    function()
        helper_test(3, _registers[1])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x60
    function()
        helper_test(4, _registers[2])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x61
    function()
        helper_test(4, _registers[3])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x62
    function()
        helper_test(4, _registers[4])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x63
    function()
        helper_test(4, _registers[5])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x64
    function()
        helper_test(4, _registers[6])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x65
    function()
        helper_test(4, _registers[7])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x66
    function()
        local address = _readTwoRegisters(6, 7)
        helper_test(4, _mmuReadByte(address))

        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0x67
    function()
        helper_test(4, _registers[1])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x68
    function()
        helper_test(5, _registers[2])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x69
    function()
        helper_test(5, _registers[3])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x6a
    function()
        helper_test(5, _registers[4])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x6b
    function()
        helper_test(5, _registers[5])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x6c
    function()
        helper_test(5, _registers[6])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x6d
    function()
        helper_test(5, _registers[7])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x6e
    function()
        local address = _readTwoRegisters(6, 7)
        helper_test(5, _mmuReadByte(address))

        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0x6f
    function()
        helper_test(5, _registers[1])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x70
    function()
        helper_test(6, _registers[2])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x71
    function()
        helper_test(6, _registers[3])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x72
    function()
        helper_test(6, _registers[4])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x73
    function()
        helper_test(6, _registers[5])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x74
    function()
        helper_test(6, _registers[6])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x75
    function()
        helper_test(6, _registers[7])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x76
    function()
        local address = _readTwoRegisters(6, 7)
        helper_test(6, _mmuReadByte(address))

        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0x77
    function()
        helper_test(6, _registers[1])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x78
    function()
        helper_test(7, _registers[2])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x79
    function()
        helper_test(7, _registers[3])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x7a
    function()
        helper_test(7, _registers[4])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x7b
    function()
        helper_test(7, _registers[5])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x7c
    function()
        helper_test(7, _registers[6])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x7d
    function()
        helper_test(7, _registers[7])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x7e
    function()
        local address = _readTwoRegisters(6, 7)
        helper_test(7, _mmuReadByte(address))

        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0x7f
    function()
        helper_test(7, _registers[1])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x80
    function()
        _registers[2] = helper_reset(0, _registers[2])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x81
    function()
        _registers[3] = helper_reset(0, _registers[3])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x82
    function()
        _registers[4] = helper_reset(0, _registers[4])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x83
    function()
        _registers[5] = helper_reset(0, _registers[5])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x84
    function()
        _registers[6] = helper_reset(0, _registers[6])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x85
    function()
        _registers[7] = helper_reset(0, _registers[7])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x86
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_reset(0, _mmuReadByte(address)))

        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0x87
    function()
        _registers[1] = helper_reset(0, _registers[1])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x88
    function()
        _registers[2] = helper_reset(1, _registers[2])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x89
    function()
        _registers[3] = helper_reset(1, _registers[3])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x8a
    function()
        _registers[4] = helper_reset(1, _registers[4])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x8b
    function()
        _registers[5] = helper_reset(1, _registers[5])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x8c
    function()
        _registers[6] = helper_reset(1, _registers[6])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x8d
    function()
        _registers[7] = helper_reset(1, _registers[7])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x8e
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_reset(1, _mmuReadByte(address)))

        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0x8f
    function()
        _registers[1] = helper_reset(1, _registers[1])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x90
    function()
        _registers[2] = helper_reset(2, _registers[2])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x91
    function()
        _registers[3] = helper_reset(2, _registers[3])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x92
    function()
        _registers[4] = helper_reset(2, _registers[4])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x93
    function()
        _registers[5] = helper_reset(2, _registers[5])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x94
    function()
        _registers[6] = helper_reset(2, _registers[6])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x95
    function()
        _registers[7] = helper_reset(2, _registers[7])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x96
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_reset(2, _mmuReadByte(address)))
    
        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0x97
    function()
        _registers[1] = helper_reset(2, _registers[1])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x98
    function()
        _registers[2] = helper_reset(3, _registers[2])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x99
    function()
        _registers[3] = helper_reset(3, _registers[3])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x9a
    function()
        _registers[4] = helper_reset(3, _registers[4])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x9b
    function()
        _registers[5] = helper_reset(3, _registers[5])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x9c
    function()
        _registers[6] = helper_reset(3, _registers[6])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x9d
    function()
        _registers[7] = helper_reset(3, _registers[7])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x9e
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_reset(3, _mmuReadByte(address)))
    
        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0x9f
    function()
        _registers[1] = helper_reset(3, _registers[1])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xa0
    function()
        _registers[2] = helper_reset(4, _registers[2])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xa1
    function()
        _registers[3] = helper_reset(4, _registers[3])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xa2
    function()
        _registers[4] = helper_reset(4, _registers[4])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xa3
    function()
        _registers[5] = helper_reset(4, _registers[5])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xa4
    function()
        _registers[6] = helper_reset(4, _registers[6])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xa5
    function()
        _registers[7] = helper_reset(4, _registers[7])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xa6
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_reset(4, _mmuReadByte(address)))
    
        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0xa7
    function()
        _registers[1] = helper_reset(4, _registers[1])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xa8
    function()
        _registers[2] = helper_reset(5, _registers[2])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xa9
    function()
        _registers[3] = helper_reset(5, _registers[3])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xaa
    function()
        _registers[4] = helper_reset(5, _registers[4])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xab
    function()
        _registers[5] = helper_reset(5, _registers[5])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xac
    function()
        _registers[6] = helper_reset(5, _registers[6])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xad
    function()
        _registers[7] = helper_reset(5, _registers[7])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xae
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_reset(5, _mmuReadByte(address)))
    
        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0xaf
    function()
        _registers[1] = helper_reset(5, _registers[1])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xb0
    function()
        _registers[2] = helper_reset(6, _registers[2])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xb1
    function()
        _registers[3] = helper_reset(6, _registers[3])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xb2
    function()
        _registers[4] = helper_reset(6, _registers[4])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xb3
    function()
        _registers[5] = helper_reset(6, _registers[5])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xb4
    function()
        _registers[6] = helper_reset(6, _registers[6])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xb5
    function()
        _registers[7] = helper_reset(6, _registers[7])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xb6
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_reset(6, _mmuReadByte(address)))
    
        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0xb7
    function()
        _registers[1] = helper_reset(6, _registers[1])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xb8
    function()
        _registers[2] = helper_reset(7, _registers[2])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xb9
    function()
        _registers[3] = helper_reset(7, _registers[3])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xba
    function()
        _registers[4] = helper_reset(7, _registers[4])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xbb
    function()
        _registers[5] = helper_reset(7, _registers[5])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xbc
    function()
        _registers[6] = helper_reset(7, _registers[6])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xbd
    function()
        _registers[7] = helper_reset(7, _registers[7])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xbe
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_reset(7, _mmuReadByte(address)))
    
        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0xbf
    function()
        _registers[1] = helper_reset(7, _registers[1])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xc0
    function()
        _registers[2] = helper_set(0, _registers[2])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xc1
    function()
        _registers[3] = helper_set(0, _registers[3])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xc2
    function()
        _registers[4] = helper_set(0, _registers[4])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xc3
    function()
        _registers[5] = helper_set(0, _registers[5])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xc4
    function()
        _registers[6] = helper_set(0, _registers[6])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xc5
    function()
        _registers[7] = helper_set(0, _registers[7])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xc6
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_set(0, _mmuReadByte(address)))

        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0xc7
    function()
        _registers[1] = helper_set(0, _registers[1])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xc8
    function()
        _registers[2] = helper_set(1, _registers[2])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xc9
    function()
        _registers[3] = helper_set(1, _registers[3])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xca
    function()
        _registers[4] = helper_set(1, _registers[4])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xcb
    function()
        _registers[5] = helper_set(1, _registers[5])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xcc
    function()
        _registers[6] = helper_set(1, _registers[6])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xcd
    function()
        _registers[7] = helper_set(1, _registers[7])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xce
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_set(1, _mmuReadByte(address)))
    
        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0xcf
    function()
        _registers[1] = helper_set(1, _registers[1])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xd0
    function()
        _registers[2] = helper_set(2, _registers[2])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xd1
    function()
        _registers[3] = helper_set(2, _registers[3])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xd2
    function()
        _registers[4] = helper_set(2, _registers[4])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xd3
    function()
        _registers[5] = helper_set(2, _registers[5])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xd4
    function()
        _registers[6] = helper_set(2, _registers[6])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xd5
    function()
        _registers[7] = helper_set(2, _registers[7])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xd6
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_set(2, _mmuReadByte(address)))
    
        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0xd7
    function()
        _registers[1] = helper_set(2, _registers[1])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xd8
    function()
        _registers[2] = helper_set(3, _registers[2])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xd9
    function()
        _registers[3] = helper_set(3, _registers[3])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xda
    function()
        _registers[4] = helper_set(3, _registers[4])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xdb
    function()
        _registers[5] = helper_set(3, _registers[5])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xdc
    function()
        _registers[6] = helper_set(3, _registers[6])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xdd
    function()
        _registers[7] = helper_set(3, _registers[7])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xde
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_set(3, _mmuReadByte(address)))
    
        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0xdf
    function()
        _registers[1] = helper_set(3, _registers[1])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xe0
    function()
        _registers[2] = helper_set(4, _registers[2])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xe1
    function()
        _registers[3] = helper_set(4, _registers[3])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xe2
    function()
        _registers[4] = helper_set(4, _registers[4])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xe3
    function()
        _registers[5] = helper_set(4, _registers[5])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xe4
    function()
        _registers[6] = helper_set(4, _registers[6])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xe5
    function()
        _registers[7] = helper_set(4, _registers[7])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xe6
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_set(4, _mmuReadByte(address)))
    
        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0xe7
    function()
        _registers[1] = helper_set(4, _registers[1])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xe8
    function()
        _registers[2] = helper_set(5, _registers[2])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xe9
    function()
        _registers[3] = helper_set(5, _registers[3])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xea
    function()
        _registers[4] = helper_set(5, _registers[4])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xeb
    function()
        _registers[5] = helper_set(5, _registers[5])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xec
    function()
        _registers[6] = helper_set(5, _registers[6])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xed
    function()
        _registers[7] = helper_set(5, _registers[7])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xee
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_set(5, _mmuReadByte(address)))
    
        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0xef
    function()
        _registers[1] = helper_set(5, _registers[1])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xf0
    function()
        _registers[2] = helper_set(6, _registers[2])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xf1
    function()
        _registers[3] = helper_set(6, _registers[3])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xf2
    function()
        _registers[4] = helper_set(6, _registers[4])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xf3
    function()
        _registers[5] = helper_set(6, _registers[5])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xf4
    function()
        _registers[6] = helper_set(6, _registers[6])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xf5
    function()
        _registers[7] = helper_set(6, _registers[7])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xf6
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_set(6, _mmuReadByte(address)))
    
        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0xf7
    function()
        _registers[1] = helper_set(6, _registers[1])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xf8
    function()
        _registers[2] = helper_set(7, _registers[2])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xf9
    function()
        _registers[3] = helper_set(7, _registers[3])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xfa
    function()
        _registers[4] = helper_set(7, _registers[4])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xfb
    function()
        _registers[5] = helper_set(7, _registers[5])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xfc
    function()
        _registers[6] = helper_set(7, _registers[6])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xfd
    function()
        _registers[7] = helper_set(7, _registers[7])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xfe
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_set(7, _mmuReadByte(address)))
    
        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0xff
    function()
        _registers[1] = helper_set(7, _registers[1])
    
        _registers[12].m = 2
        _registers[12].t = 8
    end,
}

opcodes = {
    -- Opcode: 0x00
    function()
        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x01
    function()
        _writeTwoRegisters(2, 3, _mmuReadUInt16(_registers[10]))

        _registers[10] = _registers[10] + 2
        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0x02
    function()
        _mmuWriteByte(_readTwoRegisters(2, 3), _registers[1])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x03
    function()
        _writeTwoRegisters(2, 3, helper_inc16(_readTwoRegisters(2, 3)))

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x04
    function()
        _registers[2] = helper_inc(_registers[2])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x05
    function()
        _registers[2] = helper_dec(_registers[2])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x06
    function()
        _registers[2] = _mmuReadByte(_registers[10])

        _registers[10] = _registers[10] + 1
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x07
    function()
        _registers[1] = helper_rlc(_registers[1], 8)
        _registers[8][1] = false

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x08
    function()
        mmuWriteShort(_mmuReadUInt16(_registers[10]), _registers[11])

        _registers[10] = _registers[10] + 2
        _registers[12].m = 5
        _registers[12].t = 20
    end,
    -- Opcode: 0x09
    function()
        _writeTwoRegisters(6, 7, helper_add16(_readTwoRegisters(6, 7), _readTwoRegisters(2, 3)))

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x0a
    function()
        _registers[1] = _mmuReadByte(_readTwoRegisters(2, 3))

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x0b
    function()
        _writeTwoRegisters(2, 3, helper_dec16(_readTwoRegisters(2, 3)))

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x0c
    function()
        _registers[3] = helper_inc(_registers[3])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x0d
    function()
        _registers[3] = helper_dec(_registers[3])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x0e
    function()
        _registers[3] = _mmuReadByte(_registers[10])

        _registers[10] = _registers[10] + 1
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x0f
    function()
        _registers[1] = helper_rrc(_registers[1], 8)
        _registers[8][1] = false
    
        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x10
    function()
        stopCPU()

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x11
    function()
        _writeTwoRegisters(4, 5, _mmuReadUInt16(_registers[10]))

        _registers[10] = _registers[10] + 2
        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0x12
    function()
        _mmuWriteByte(_readTwoRegisters(4, 5), _registers[1])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x13
    function()
        _writeTwoRegisters(4, 5, helper_inc16(_readTwoRegisters(4, 5)))

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x14
    function()
        _registers[4] = helper_inc(_registers[4])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x15
    function()
        _registers[4] = helper_dec(_registers[4])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x16
    function()
        _registers[4] = _mmuReadByte(_registers[10])

        _registers[10] = _registers[10] + 1
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x17
    function()
        _registers[1] = helper_rl(_registers[1], 8)
        _registers[8][1] = false

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x18
    function()
        local addition = _mmuReadSignedByte(_registers[10])

        _registers[10] = _registers[10] + addition + 1

        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0x19
    function()
        _writeTwoRegisters(6, 7, helper_add16(_readTwoRegisters(6, 7), _readTwoRegisters(4, 5)))

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x1a
    function()
        _registers[1] = _mmuReadByte(_readTwoRegisters(4, 5))

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x1b
    function()
        _writeTwoRegisters(4, 5, helper_dec16(_readTwoRegisters(4, 5)))

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x1c
    function()
        _registers[5] = helper_inc(_registers[5])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x1d
    function()
        _registers[5] = helper_dec(_registers[5])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x1e
    function()
        _registers[5] = _mmuReadByte(_registers[10])

        _registers[10] = _registers[10] + 1
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x1f
    function()
        _registers[1] = helper_rr(_registers[1], 8)
    
        _registers[8][1] = false -- FLAG_ZERO

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x20
    function()
        if (not _registers[8][1]) then
            _registers[10] = _registers[10] + _mmuReadSignedByte(_registers[10]) + 1

            _registers[12].m = 3
            _registers[12].t = 12
        else
            _registers[10] = _registers[10] + 1

            _registers[12].m = 2
            _registers[12].t = 8
        end
    end,
    -- Opcode: 0x21
    function()
        _writeTwoRegisters(6, 7, _mmuReadUInt16(_registers[10]))

        _registers[10] = _registers[10] + 2
        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0x22
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, _registers[1])

        if (address == 0xff) then
            _writeTwoRegisters(6, 7, 0)
        else
            _writeTwoRegisters(6, 7, address + 1)
        end

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x23
    function()
        _writeTwoRegisters(6, 7, helper_inc16(_readTwoRegisters(6, 7)))

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x24
    function()
        _registers[6] = helper_inc(_registers[6])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x25
    function()
        _registers[6] = helper_dec(_registers[6])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x26
    function()
        _registers[6] = _mmuReadByte(_registers[10])

        _registers[10] = _registers[10] + 1
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x27
    function()
        local registerA = _registers[1]

        if (not _registers[8][2]) then -- FLAG_SUBSTRACT
            if (_registers[8][4] or registerA > 0x99) then -- FLAG_CARRY
                registerA = registerA + 0x60
                _registers[8][4] = true -- FLAG_CARRY
            end

            if (_registers[8][3] or _bitAnd(registerA, 0x0f) > 0x09) then -- FLAG_HALFCARRY
                registerA = registerA + 0x6
            end
        else
            if (_registers[8][4]) then -- FLAG_CARRY
                registerA = registerA - 0x60
            end

            if (_registers[8][3]) then -- FLAG_HALFCARRY
                registerA = registerA - 0x6
            end
        end

        registerA = registerA % 0x100

        _registers[8][1] = (registerA == 0) and true or false -- FLAG_ZERO
        _registers[8][3] = false -- FLAG_HALFCARRY
        _registers[1] = registerA

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x28
    function()
        if (_registers[8][1]) then
            _registers[10] = _registers[10] + _mmuReadSignedByte(_registers[10]) + 1

            _registers[12].m = 3
            _registers[12].t = 12
        else
            _registers[10] = _registers[10] + 1

            _registers[12].m = 2
            _registers[12].t = 8
        end
    end,
    -- Opcode: 0x29
    function()
        local value = _readTwoRegisters(6, 7)
        _writeTwoRegisters(6, 7, helper_add16(value, value))

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x2a
    function()
        local address = _readTwoRegisters(6, 7)
        _registers[1] = _mmuReadByte(address)

        if (address == 0xff) then
            _writeTwoRegisters(6, 7, 0)
        else
            _writeTwoRegisters(6, 7, address + 1)
        end

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x2b
    function()
        _writeTwoRegisters(6, 7, helper_dec16(_readTwoRegisters(6, 7)))

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x2c
    function()
        _registers[7] = helper_inc(_registers[7])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x2d
    function()
        _registers[7] = helper_dec(_registers[7])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x2e
    function()
        _registers[7] = _mmuReadByte(_registers[10])

        _registers[10] = _registers[10] + 1
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x2f
    function()
        _registers[1] = helper_not(_registers[1])

        _registers[8][2] = true -- FLAG_SUBSTRACT
        _registers[8][3] = true -- FLAG_HALFCARRY

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x30
    function()
        if (not _registers[8][4]) then
            _registers[10] = _registers[10] + _mmuReadSignedByte(_registers[10]) + 1

            _registers[12].m = 3
            _registers[12].t = 12
        else
            _registers[10] = _registers[10] + 1

            _registers[12].m = 2
            _registers[12].t = 8
        end
    end,
    -- Opcode: 0x31
    function()
        _registers[11] = _mmuReadUInt16(_registers[10])

        _registers[10] = _registers[10] + 2
        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0x32
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, _registers[1])

        if (address == 0) then
            _writeTwoRegisters(6, 7, 0xff)
        else
            _writeTwoRegisters(6, 7, address - 1)
        end

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x33
    function()
        _registers[11] = helper_inc16(_registers[11])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x34
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_inc(_mmuReadByte(address)))

        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0x35
    function()
        local address = _readTwoRegisters(6, 7)
        _mmuWriteByte(address, helper_dec(_mmuReadByte(address)))

        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0x36
    function()
        _mmuWriteByte(_readTwoRegisters(6, 7), _mmuReadByte(_registers[10]))

        _registers[10] = _registers[10] + 1
        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0x37
    function()
        _registers[8][2] = false -- FLAG_SUBSTRACT
        _registers[8][3] = false -- FLAG_HALFCARRY
        _registers[8][4] = true

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x38
    function()
        if (_registers[8][4]) then
            _registers[10] = _registers[10] + _mmuReadSignedByte(_registers[10]) + 1

            _registers[12].m = 2
            _registers[12].t = 12
        else
            _registers[10] = _registers[10] + 1

            _registers[12].m = 2
            _registers[12].t = 8
        end
    end,
    -- Opcode: 0x39
    function()
        _writeTwoRegisters(6, 7, helper_add16(_readTwoRegisters(6, 7), _registers[11]))

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x3a
    function()
        local address = _readTwoRegisters(6, 7)
        _registers[1] = _mmuReadByte(address)

        if (address == 0) then
            _writeTwoRegisters(6, 7, 0xff)
        else
            _writeTwoRegisters(6, 7, address - 1)
        end

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x3b
    function()
        _registers[11] = helper_dec16(_registers[11])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x3c
    function()
        _registers[1] = helper_inc(_registers[1])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x3d
    function()
        _registers[1] = helper_dec(_registers[1])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x3e
    function()
        _registers[1] = _mmuReadByte(_registers[10])

        _registers[10] = _registers[10] + 1
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x3f
    function()
        _registers[8][2] = false -- FLAG_SUBSTRACT
        _registers[8][3] = false -- FLAG_HALFCARRY
        _registers[8][4] = not _registers[8][4] -- FLAG_CARRY

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x40
    function()
        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x41
    function()
        _registers[2] = _registers[3]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x42
    function()
        _registers[2] = _registers[4]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x43
    function()
        _registers[2] = _registers[5]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x44
    function()
        _registers[2] = _registers[6]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x45
    function()
        _registers[2] = _registers[7]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x46
    function()
        _registers[2] = _mmuReadByte(_readTwoRegisters(6, 7))

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x47
    function()
        _registers[2] = _registers[1]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x48
    function()
        _registers[3] = _registers[2]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x49
    function()
        _registers[3] = _registers[3]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x4a
    function()
        _registers[3] = _registers[4]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x4b
    function()
        _registers[3] = _registers[5]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x4c
    function()
        _registers[3] = _registers[6]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x4d
    function()
        _registers[3] = _registers[7]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x4e
    function()
        _registers[3] = _mmuReadByte(_readTwoRegisters(6, 7))

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x4f
    function()
        _registers[3] = _registers[1]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x50
    function()
        _registers[4] = _registers[2]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x51
    function()
        _registers[4] = _registers[3]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x52
    function()
        _registers[4] = _registers[4]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x53
    function()
        _registers[4] = _registers[5]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x54
    function()
        _registers[4] = _registers[6]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x55
    function()
        _registers[4] = _registers[7]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x56
    function()
        _registers[4] = _mmuReadByte(_readTwoRegisters(6, 7))

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x57
    function()
        _registers[4] = _registers[1]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x58
    function()
        _registers[5] = _registers[2]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x59
    function()
        _registers[5] = _registers[3]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x5a
    function()
        _registers[5] = _registers[4]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x5b
    function()
        _registers[5] = _registers[5]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x5c
    function()
        _registers[5] = _registers[6]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x5d
    function()
        _registers[5] = _registers[7]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x5e
    function()
        _registers[5] = _mmuReadByte(_readTwoRegisters(6, 7))

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x5f
    function()
        _registers[5] = _registers[1]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x60
    function()
        _registers[6] = _registers[2]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x61
    function()
        _registers[6] = _registers[3]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x62
    function()
        _registers[6] = _registers[4]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x63
    function()
        _registers[6] = _registers[5]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x64
    function()
        _registers[6] = _registers[6]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x65
    function()
        _registers[6] = _registers[7]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x66
    function()
        _registers[6] = _mmuReadByte(_readTwoRegisters(6, 7))

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x67
    function()
        _registers[6] = _registers[1]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x68
    function()
        _registers[7] = _registers[2]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x69
    function()
        _registers[7] = _registers[3]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x6a
    function()
        _registers[7] = _registers[4]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x6b
    function()
        _registers[7] = _registers[5]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x6c
    function()
        _registers[7] = _registers[6]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x6d
    function()
        _registers[7] = _registers[7]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x6e
    function()
        _registers[7] = _mmuReadByte(_readTwoRegisters(6, 7))

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x6f
    function()
        _registers[7] = _registers[1]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x70
    function()
        _mmuWriteByte(_readTwoRegisters(6, 7), _registers[2])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x71
    function()
        _mmuWriteByte(_readTwoRegisters(6, 7), _registers[3])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x72
    function()
        _mmuWriteByte(_readTwoRegisters(6, 7), _registers[4])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x73
    function()
        _mmuWriteByte(_readTwoRegisters(6, 7), _registers[5])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x74
    function()
        _mmuWriteByte(_readTwoRegisters(6, 7), _registers[6])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x75
    function()
        _mmuWriteByte(_readTwoRegisters(6, 7), _registers[7])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x76
    function()
        haltCPU()

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x77
    function()
        _mmuWriteByte(_readTwoRegisters(6, 7), _registers[1])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x78
    function()
        _registers[1] = _registers[2]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x79
    function()
        _registers[1] = _registers[3]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x7a
    function()
        _registers[1] = _registers[4]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x7b
    function()
        _registers[1] = _registers[5]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x7c
    function()
        _registers[1] = _registers[6]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x7d
    function()
        _registers[1] = _registers[7]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x7e
    function()
        _registers[1] = _mmuReadByte(_readTwoRegisters(6, 7))

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x7f
    function()
        _registers[1] = _registers[1]

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x80
    function()
        _registers[1] = helper_add(_registers[1], _registers[2])

        _registers[8][2] = false
        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x81
    function()
        _registers[1] = helper_add(_registers[1], _registers[3])

        _registers[8][2] = false
        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x82
    function()
        _registers[1] = helper_add(_registers[1], _registers[4])

        _registers[8][2] = false
        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x83
    function()
        _registers[1] = helper_add(_registers[1], _registers[5])

        _registers[8][2] = false
        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x84
    function()
        _registers[1] = helper_add(_registers[1], _registers[6])

        _registers[8][2] = false
        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x85
    function()
        _registers[1] = helper_add(_registers[1], _registers[7])

        _registers[8][2] = false
        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x86
    function()
        _registers[1] = helper_add(_registers[1],
            _mmuReadByte(_readTwoRegisters(6, 7)))

        _registers[8][2] = false
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x87
    function()
        _registers[1] = helper_add(_registers[1], _registers[1])

        _registers[8][2] = false
        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x88
    function()
        _registers[1] = helper_adc(_registers[1], _registers[2])

        _registers[8][2] = false
        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x89
    function()
        _registers[1] = helper_adc(_registers[1], _registers[3])

        _registers[8][2] = false
        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x8a
    function()
        _registers[1] = helper_adc(_registers[1], _registers[4])

        _registers[8][2] = false
        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x8b
    function()
        _registers[1] = helper_adc(_registers[1], _registers[5])

        _registers[8][2] = false
        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x8c
    function()
        _registers[1] = helper_adc(_registers[1], _registers[6])

        _registers[8][2] = false
        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x8d
    function()
        _registers[1] = helper_adc(_registers[1], _registers[7])

        _registers[8][2] = false
        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x8e
    function()
        _registers[1] = helper_adc(_registers[1],
            _mmuReadByte(_readTwoRegisters(6, 7)))

        _registers[8][2] = false
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x8f
    function()
        _registers[1] = helper_adc(_registers[1], _registers[1])

        _registers[8][2] = false
        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x90
    function()
        _registers[1] = helper_sub(_registers[1], _registers[2])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x91
    function()
        _registers[1] = helper_sub(_registers[1], _registers[3])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x92
    function()
        _registers[1] = helper_sub(_registers[1], _registers[4])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x93
    function()
        _registers[1] = helper_sub(_registers[1], _registers[5])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x94
    function()
        _registers[1] = helper_sub(_registers[1], _registers[6])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x95
    function()
        _registers[1] = helper_sub(_registers[1], _registers[7])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x96
    function()
        _registers[1] = helper_sub(_registers[1],
            _mmuReadByte(_readTwoRegisters(6, 7)))

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x97
    function()
        _registers[1] = helper_sub(_registers[1], _registers[1])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x98
    function()
        _registers[1] = helper_sbc(_registers[1], _registers[2])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x99
    function()
        _registers[1] = helper_sbc(_registers[1], _registers[3])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x9a
    function()
        _registers[1] = helper_sbc(_registers[1], _registers[4])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x9b
    function()
        _registers[1] = helper_sbc(_registers[1], _registers[5])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x9c
    function()
        _registers[1] = helper_sbc(_registers[1], _registers[6])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x9d
    function()
        _registers[1] = helper_sbc(_registers[1], _registers[7])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0x9e
    function()
        _registers[1] = helper_sbc(_registers[1], _mmuReadByte(_readTwoRegisters(6, 7)))

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0x9f
    function()
        _registers[1] = helper_sbc(_registers[1], _registers[1])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xa0
    function()
        _registers[1] = helper_and(_registers[1], _registers[2])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xa1
    function()
        _registers[1] = helper_and(_registers[1], _registers[3])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xa2
    function()
        _registers[1] = helper_and(_registers[1], _registers[4])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xa3
    function()
        _registers[1] = helper_and(_registers[1], _registers[5])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xa4
    function()
        _registers[1] = helper_and(_registers[1], _registers[6])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xa5
    function()
        _registers[1] = helper_and(_registers[1], _registers[7])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xa6
    function()
        _registers[1] = helper_and(_registers[1], _mmuReadByte(
            _readTwoRegisters(6, 7))
        )

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xa7
    function()
        _registers[1] = helper_and(_registers[1], _registers[1])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xa8
    function()
        _registers[1] = helper_xor(_registers[1], _registers[2])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xa9
    function()
        _registers[1] = helper_xor(_registers[1], _registers[3])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xaa
    function()
        _registers[1] = helper_xor(_registers[1], _registers[4])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xab
    function()
        _registers[1] = helper_xor(_registers[1], _registers[5])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xac
    function()
        _registers[1] = helper_xor(_registers[1], _registers[6])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xad
    function()
        _registers[1] = helper_xor(_registers[1], _registers[7])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xae
    function()
        _registers[1] = helper_xor(_registers[1], _mmuReadByte(
            _readTwoRegisters(6, 7))
        )

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xaf
    function()
        _registers[1] = helper_xor(_registers[1], _registers[1])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xb0
    function()
        _registers[1] = helper_or(_registers[1], _registers[2])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xb1
    function()
        _registers[1] = helper_or(_registers[1], _registers[3])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xb2
    function()
        _registers[1] = helper_or(_registers[1], _registers[4])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xb3
    function()
        _registers[1] = helper_or(_registers[1], _registers[5])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xb4
    function()
        _registers[1] = helper_or(_registers[1], _registers[6])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xb5
    function()
        _registers[1] = helper_or(_registers[1], _registers[7])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xb6
    function()
        _registers[1] = helper_or(_registers[1], _mmuReadByte(
            _readTwoRegisters(6, 7))
        )

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xb7
    function()
        _registers[1] = helper_or(_registers[1], _registers[1])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xb8
    function()
        helper_cp(_registers[1], _registers[2])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xb9
    function()
        helper_cp(_registers[1], _registers[3])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xba
    function()
        helper_cp(_registers[1], _registers[4])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xbb
    function()
        helper_cp(_registers[1], _registers[5])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xbc
    function()
        helper_cp(_registers[1], _registers[6])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xbd
    function()
        helper_cp(_registers[1], _registers[7])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xbe
    function()
        helper_cp(_registers[1], _mmuReadByte(
            _readTwoRegisters(6, 7))
        )

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xbf
    function()
        helper_cp(_registers[1], _registers[1])

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xc0
    function()
        if (not _registers[8][1]) then
            _registers[10] = _mmuPopStack()

            _registers[12].m = 2
            _registers[12].t = 20
            return
        end

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xc1
    function()
        _writeTwoRegisters(2, 3, _mmuPopStack())

        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0xc2
    function()
        if (not _registers[8][1]) then
            _registers[10] = _mmuReadUInt16(_registers[10])

            _registers[12].m = 3
            _registers[12].t = 16
        else
            _registers[10] = _registers[10] + 2

            _registers[12].m = 3
            _registers[12].t = 12
        end
    end,
    -- Opcode: 0xc3
    function()
        _registers[10] = _mmuReadUInt16(_registers[10])

        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0xc4
    function()
        if (not _registers[8][1]) then
            _mmuPushStack(_registers[10] + 2)
            _registers[10] = _mmuReadUInt16(_registers[10])

            _registers[12].m = 6
            _registers[12].t = 24
        else
            _registers[10] = _registers[10] + 2

            _registers[12].m = 3
            _registers[12].t = 12
        end
    end,
    -- Opcode: 0xc5
    function()
        _mmuPushStack(_readTwoRegisters(2, 3))

        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0xc6
    function()
        _registers[1] = helper_add(_registers[1],
            _mmuReadByte(_registers[10]))

        _registers[8][2] = false
        _registers[10] = _registers[10] + 1
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xc7
    function()
        _mmuPushStack(_registers[10])
        _registers[10] = 0x0

        _registers[12].m = 1
        _registers[12].t = 16
    end,
    -- Opcode: 0xc8
    function()
        if (_registers[8][1]) then
            _registers[10] = _mmuPopStack()

            _registers[12].m = 5
            _registers[12].t = 20
        else
            _registers[12].m = 2
            _registers[12].t = 8
        end
    end,
    -- Opcode: 0xc9
    function()
        _registers[10] = _mmuPopStack()

        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0xca
    function()
        if (_registers[8][1]) then
            _registers[10] = _mmuReadUInt16(_registers[10])

            _registers[12].m = 3
            _registers[12].t = 16
        else
            _registers[10] = _registers[10] + 2

            _registers[12].m = 3
            _registers[12].t = 12
        end
    end,
    -- Opcode: 0xcb
    function()
        _registers[10] = _registers[10] + 1
        cbOpcodes[mmuReadByte(_registers[10] - 1) + 1]()
    end,
    -- Opcode: 0xcc
    function()
        if (_registers[8][1]) then
            _mmuPushStack(_registers[10] + 2)
            _registers[10] = _mmuReadUInt16(_registers[10])

            _registers[12].m = 6
            _registers[12].t = 24
        else
            _registers[10] = _registers[10] + 2

            _registers[12].m = 3
            _registers[12].t = 12
        end
    end,
    -- Opcode: 0xcd
    function()
        local value = _mmuReadUInt16(_registers[10])

        _mmuPushStack(_registers[10] + 2)
        _registers[10] = value

        _registers[12].m = 6
        _registers[12].t = 24
    end,
    -- Opcode: 0xce
    function()
        _registers[1] = helper_adc(_registers[1],
            _mmuReadByte(_registers[10]))

        _registers[10] = _registers[10] + 1
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xcf
    function()
        _mmuPushStack(_registers[10])
        _registers[10] = 0x08

        _registers[12].m = 1
        _registers[12].t = 16
    end,
    -- Opcode: 0xd0
    function()
        if (not _registers[8][4]) then
            _registers[10] = _mmuPopStack()

            _registers[12].m = 5
            _registers[12].t = 20
        else
            _registers[12].m = 2
            _registers[12].t = 8
        end
    end,
    -- Opcode: 0xd1
    function()
        _writeTwoRegisters(4, 5, _mmuPopStack())

        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0xd2
    function()
        if (not _registers[8][4]) then
            _registers[10] = _mmuReadUInt16(_registers[10])

            _registers[12].m = 3
            _registers[12].t = 16
        else
            _registers[10] = _registers[10] + 2

            _registers[12].m = 3
            _registers[12].t = 12
        end
    end,
    -- Opcode: 0xd3
    function() end,
    -- Opcode: 0xd4
    function()
        if (not _registers[8][4]) then
            _mmuPushStack(_registers[10] + 2)
            _registers[10] = _mmuReadUInt16(_registers[10])

            _registers[12].m = 6
            _registers[12].t = 24
        else
            _registers[10] = _registers[10] + 2

            _registers[12].m = 3
            _registers[12].t = 12
        end
    end,
    -- Opcode: 0xd5
    function()
        _mmuPushStack(_readTwoRegisters(4, 5))

        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0xd6
    function()
        _registers[1] = helper_sub(_registers[1], _mmuReadByte(_registers[10]))

        _registers[10] = _registers[10] + 1
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xd7
    function()
        _mmuPushStack(_registers[10])
        _registers[10] = 0x10

        _registers[12].m = 1
        _registers[12].t = 16
    end,
    -- Opcode: 0xd8
    function()
        if (_registers[8][4]) then
            _registers[10] = _mmuPopStack()

            _registers[12].m = 1
            _registers[12].t = 20

            return
        end

        _registers[12].m = 1
        _registers[12].t = 8
    end,
    -- Opcode: 0xd9
    function()
        _registers[10] = _mmuPopStack()
        setInterrupts()

        _registers[12].m = 1
        _registers[12].t = 16
    end,
    -- Opcode: 0xda
    function()
        if (_registers[8][4]) then
            _registers[10] = _mmuReadUInt16(_registers[10])

            _registers[12].m = 3
            _registers[12].t = 16
        else
            _registers[10] = _registers[10] + 2

            _registers[12].m = 3
            _registers[12].t = 12
        end
    end,
    -- Opcode: 0xdb
    function() end,
    -- Opcode: 0xdc
    function()
        if (_registers[8][4]) then
            _mmuPushStack(_registers[10] + 2)
            _registers[10] = _mmuReadUInt16(_registers[10])

            _registers[12].m = 6
            _registers[12].t = 24
        else
            _registers[10] = _registers[10] + 2

            _registers[12].m = 3
            _registers[12].t = 12
        end
    end,
    -- Opcode: 0xdd
    function() end,
    -- Opcode: 0xde
    function()
        _registers[1] = helper_sbc(_registers[1], _mmuReadByte(_registers[10]))

        _registers[10] = _registers[10] + 1
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xdf
    function()
        _mmuPushStack(_registers[10])
        _registers[10] = 0x18

        _registers[12].m = 1
        _registers[12].t = 16
    end,
    -- Opcode: 0xe0
    function()
        _mmuWriteByte(0xFF00 + _mmuReadByte(_registers[10]), _registers[1])

        _registers[10] = _registers[10] + 1
        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0xe1
    function()
        _writeTwoRegisters(6, 7, _mmuPopStack())

        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0xe2
    function()
        _mmuWriteByte(0xFF00 + _registers[3], _registers[1])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xe3
    function() end,
    -- Opcode: 0xe4
    function() end,
    -- Opcode: 0xe5
    function()
        _mmuPushStack(_readTwoRegisters(6, 7))

        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0xe6
    function()
        _registers[1] = helper_and(_registers[1], _mmuReadByte(_registers[10]))

        _registers[10] = _registers[10] + 1
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xe7
    function()
        _mmuPushStack(_registers[10])
        _registers[10] = 0x20

        _registers[12].m = 1
        _registers[12].t = 16
    end,
    -- Opcode: 0xe8
    function()
        _registers[11] = helper_add_sp(_registers[11],
            _mmuReadSignedByte(_registers[10]))

        _registers[10] = _registers[10] + 1
        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0xe9
    function()
        _registers[10] = _readTwoRegisters(6, 7)

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xea
    function()
        _mmuWriteByte(_mmuReadUInt16(_registers[10]), _registers[1])

        _registers[10] = _registers[10] + 2
        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0xeb
    function() end,
    -- Opcode: 0xec
    function() end,
    -- Opcode: 0xed
    function() end,
    -- Opcode: 0xee
    function()
        _registers[1] = helper_xor(_registers[1], _mmuReadByte(_registers[10]))

        _registers[10] = _registers[10] + 1
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xef
    function()
        _mmuPushStack(_registers[10])
        _registers[10] = 0x28

        _registers[12].m = 1
        _registers[12].t = 16
    end,
    -- Opcode: 0xf0
    function()
        _registers[1] = _mmuReadByte(0xFF00 + _mmuReadByte(_registers[10]))

        _registers[10] = _registers[10] + 1
        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0xf1
    function()
        _writeTwoRegisters(1, 8, _mmuPopStack())

        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0xf2
    function()
        _registers[1] = _mmuReadByte(0xFF00 + _registers[3])

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xf3
    function()
        disableInterrupts()

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xf4
    function() end,
    -- Opcode: 0xf5
    function()
        _mmuPushStack(_readTwoRegisters(1, 8))

        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0xf6
    function()
        _registers[1] = helper_or(_registers[1], _mmuReadByte(_registers[10]))

        _registers[10] = _registers[10] + 1
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xf7
    function()
        _mmuPushStack(_registers[10])
        _registers[10] = 0x30

        _registers[12].m = 1
        _registers[12].t = 16
    end,
    -- Opcode: 0xf8
    function()
        local address = _registers[11]
        local value = _mmuReadSignedByte(_registers[10])

        _writeTwoRegisters(6, 7, helper_add_sp(address, value))

        _registers[10] = _registers[10] + 1
        _registers[12].m = 3
        _registers[12].t = 12
    end,
    -- Opcode: 0xf9
    function()
        _registers[11] = _readTwoRegisters(6, 7)

        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xfa
    function()
        _registers[1] = _mmuReadByte(_mmuReadUInt16(_registers[10]))

        _registers[10] = _registers[10] + 2
        _registers[12].m = 4
        _registers[12].t = 16
    end,
    -- Opcode: 0xfb
    function()
        enableInterrupts()

        _registers[12].m = 1
        _registers[12].t = 4
    end,
    -- Opcode: 0xfc
    function() end,
    -- Opcode: 0xfd
    function() end,
    -- Opcode: 0xfe
    function()
        helper_cp(_registers[1], _mmuReadByte(_registers[10]))

        _registers[10] = _registers[10] + 1
        _registers[12].m = 2
        _registers[12].t = 8
    end,
    -- Opcode: 0xff
    function()
        _mmuPushStack(_registers[10])
        _registers[10] = 0x38

        _registers[12].m = 4
        _registers[12].t = 16
    end,
}

addEventHandler("onClientResourceStart", resourceRoot, function()
    _readTwoRegisters = readTwoRegisters
    _writeTwoRegisters = writeTwoRegisters

    _mmuReadByte = mmuReadByte
    _mmuWriteByte = mmuWriteByte
    _mmuReadUInt16 = mmuReadUInt16
    _mmuReadSignedByte = mmuReadSignedByte
    _mmuPushStack = mmuPushStack
    _mmuPopStack = mmuPopStack
    --_registers = registers
end, true, "high")

addEventHandler("gb:cpu:reset", root,
    function()
        _registers = registers
    end
)