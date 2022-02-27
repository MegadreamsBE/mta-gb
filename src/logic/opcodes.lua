-----------------------------------
-- * Locals & Constants
-----------------------------------

local _math_abs = math.abs
local _math_floor = math.floor
local _math_log = math.log

local _bitOr = bitOr
local _bitAnd = bitAnd
local _bitXor = bitXor
local _bitNot = bitNot
local _bitExtract = bitExtract
local _bitReplace = bitReplace
local _bitLShift = bitLShift

local _string_format = string.format

local helper_inc = function(value)
    registers.f[3] = (_bitAnd(value, 0x0f) == 0x0f) -- FLAG_HALFCARRY

    value = (value + 1) % 0x100

    registers.f[1] = (value == 0) and true or false -- FLAG_ZERO
    registers.f[2] = false -- FLAG_SUBSTRACT

    return value
end

local helper_inc16 = function(value)
    return (value + 1) % 0x10000
end

local helper_dec = function(value)
    registers.f[3] = (_bitAnd(value, 0x0f) == 0x00) -- FLAG_HALFCARRY

    value = (value - 1) % 0x100

    registers.f[1] = (value == 0) and true or false -- FLAG_ZERO
    registers.f[2] = true -- FLAG_SUBSTRACT

    return value
end

local helper_dec16 = function(value)
    return (value - 1) % 0x10000
end

local helper_add = function(value, add)
    result = (value + add) % 0x100

    registers.f[3] = (_bitAnd(_bitXor(_bitXor(value, add), result), 0x10) == 0x10) -- FLAG_HALFCARRY
    registers.f[4] = (value + add > 0xFF)  -- FLAG_CARRY

    registers.f[1] = (result == 0) and true or false -- FLAG_ZERO
    registers.f[2] = false -- FLAG_SUBSTRACT

    return result
end

local helper_adc = function(value, add)
    local carry = registers.f[4] and 1 or 0

    result = (value + add + carry) % 0x100

    registers.f[3] = (_bitAnd(_bitXor(_bitXor(value, add), result), 0x10) == 0x10) -- FLAG_HALFCARRY
    registers.f[4] = (value + add + carry > 0xFF) -- FLAG_CARRY

    registers.f[1] = (result == 0) and true or false -- FLAG_ZERO
    registers.f[2] = false -- FLAG_SUBSTRACT

    return result
end

local helper_add_sp = function(value, add)
    result = (value + add) % 0x10000

    registers.f[3] = (_bitAnd(_bitXor(_bitXor(value, add), result), 0x10) == 0x10) -- FLAG_HALFCARRY
    registers.f[4] = (_bitAnd(_bitXor(_bitXor(value, add), result), 0x100) == 0x100) -- FLAG_CARRY

    registers.f[1] = false -- FLAG_ZERO
    registers.f[2] = false -- FLAG_SUBSTRACT

    return result
end

local helper_add16 = function(value, add)
    result = (value + add) % 0x10000

    registers.f[3] = (_bitAnd(_bitXor(_bitXor(value, add), result), 0x1000) == 0x1000) -- FLAG_HALFCARRY
    registers.f[4] = (value + add > 0xFFFF) -- FLAG_CARRY

    --registers.f[1] = (result == 0) and true or false -- FLAG_ZERO
    registers.f[2] = false -- FLAG_SUBSTRACT

    return result
end

local helper_sub = function(value, sub)
    result = value - sub

    registers.f[3] = (_bitAnd(_bitXor(_bitXor(value, sub), result), 0x10) ~= 0) -- FLAG_HALFCARRY
    registers.f[4] = (_bitAnd(_bitXor(_bitXor(value, sub), result), 0x100) ~= 0) -- FLAG_CARRY

    result = result % 0x100

    registers.f[1] = (result == 0) and true or false -- FLAG_ZERO
    registers.f[2] = true -- FLAG_SUBSTRACT

    return result
end

local helper_sbc = function(value, sub)
    local carry = registers.f[4] and 1 or 0
    result = value - sub - carry

    registers.f[3] = ((_bitAnd(value, 0x0F) - _bitAnd(sub, 0x0F) - carry) < 0) -- FLAG_HALFCARRY
    registers.f[4] = (result < 0) -- FLAG_CARRY

    result = result % 0x100

    registers.f[1] = (result == 0) and true or false -- FLAG_ZERO
    registers.f[2] = true -- FLAG_SUBSTRACT

    return result
end

local helper_and = function(value1, value2)
    local value = _bitAnd(value1, value2)

    registers.f[1] = (value == 0) and true or false -- FLAG_ZERO
    registers.f[2] = false -- FLAG_SUBSTRACT
    registers.f[3] = true -- FLAG_HALFCARRY
    registers.f[4] = false -- FLAG_CARRY

    return value
end

local helper_or = function(value1, value2)
    local value = _bitOr(value1, value2)

    registers.f[1] = (value == 0) and true or false -- FLAG_ZERO
    registers.f[2] = false -- FLAG_SUBSTRACT
    registers.f[3] = false -- FLAG_HALFCARRY
    registers.f[4] = false -- FLAG_CARRY

    return value
end

local helper_xor = function(value1, value2)
    local value = _bitXor(value1, value2)

    registers.f[1] = (value == 0) and true or false -- FLAG_ZERO
    registers.f[2] = false -- FLAG_SUBSTRACT
    registers.f[3] = false -- FLAG_HALFCARRY
    registers.f[4] = false -- FLAG_CARRY

    return value
end

local helper_lshift = function(value, bitSize)
    value = value * 2
    value = _bitReplace(value, 0, 0, 1)

    local bits = _math_floor(_math_log(value) / _math_log(2)) + 1

    if (bits < 0) then
        bits = 0
    end

    if (bits > bitSize) then
        value = _bitReplace(value, 0, bits - 1, (bits - bitSize))
    end

    return value
end

local helper_rshift = function(value, bitSize)
    value = _math_floor(value / 2)
    value = _bitReplace(value, 0, bitSize - 1, 1)

    local bits = _math_floor(_math_log(value) / _math_log(2)) + 1

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

    value = value * 2
    value = _bitReplace(value, bit, 0, 1)

    local bits = _math_floor(_math_log(value) / _math_log(2)) + 1

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

    value = _math_floor(value / 2)
    value = _bitReplace(value, bit, bitSize - 1, 1)

    local bits = _math_floor(_math_log(value) / _math_log(2)) + 1

    if (bits < 0) then
        bits = 0
    end

    if (bits > bitSize) then
        value = _bitReplace(value, 0, bits - 1, (bits - bitSize))
    end

    return value
end

local helper_rl = function(value, bitSize)
    local carry = registers.f[4] and 1 or 0

    registers.f[4] = (_bitAnd(value, 0x80) ~= 0) -- FLAG_CARRY

    local result = helper_lshift(value, bitSize)
    result = _bitOr(result, carry)

    registers.f[1] = (result == 0) and true or false -- FLAG_ZERO
    registers.f[2] = false -- FLAG_SUBSTRACT
    registers.f[3] = false -- FLAG_HALFCARRY

    return result
end

local helper_rlc = function(value, bitSize)
    registers.f[4] = (_bitAnd(value, 0x80) ~= 0) -- FLAG_CARRY

    local result = helper_lrotate(value, bitSize)

    registers.f[1] = (result == 0) and true or false -- FLAG_ZERO
    registers.f[2] = false -- FLAG_SUBSTRACT
    registers.f[3] = false -- FLAG_HALFCARRY

    return result
end

local helper_rr = function(value, bitSize)
    local carry = registers.f[4] and 0x80 or 0

    registers.f[4] = (_bitAnd(value, 0x01) ~= 0) -- FLAG_CARRY

    local result = helper_rshift(value, bitSize)
    result = _bitOr(result, carry)

    registers.f[1] = (result == 0) and true or false -- FLAG_ZERO
    registers.f[2] = false -- FLAG_SUBSTRACT
    registers.f[3] = false -- FLAG_HALFCARRY

    return result
end

local helper_rrc = function(value, bitSize)
    registers.f[4] = (_bitAnd(value, 0x01) ~= 0) -- FLAG_CARRY

    local result = helper_rrotate(value, bitSize)

    registers.f[1] = (result == 0) and true or false -- FLAG_ZERO
    registers.f[2] = false -- FLAG_SUBSTRACT
    registers.f[3] = false -- FLAG_HALFCARRY

    return result
end

local helper_sla = function(value, bitSize)
    registers.f[4] = (_bitAnd(value, 0x80) ~= 0) -- FLAG_CARRY

    local result = helper_lshift(value, bitSize)

    registers.f[1] = (result == 0) and true or false -- FLAG_ZERO
    registers.f[2] = false -- FLAG_SUBSTRACT
    registers.f[3] = false -- FLAG_HALFCARRY

    return result
end

local helper_sra = function(value, bitSize)
    registers.f[4] = (_bitAnd(value, 0x01) ~= 0) -- FLAG_CARRY

    local result = helper_rshift(value, bitSize)

    if ((_bitAnd(value, 0x80) ~= 0)) then
        result = _bitOr(result, 0x80)
    end

    registers.f[1] = (result == 0) and true or false -- FLAG_ZERO
    registers.f[2] = false -- FLAG_SUBSTRACT
    registers.f[3] = false -- FLAG_HALFCARRY

    return result
end

local helper_srl = function(value, bitSize)
    registers.f[4] = (_bitAnd(value, 0x01) ~= 0) -- FLAG_CARRY

    local result = helper_rshift(value, bitSize)

    registers.f[1] = (result == 0) and true or false -- FLAG_ZERO
    registers.f[2] = false -- FLAG_SUBSTRACT
    registers.f[3] = false -- FLAG_HALFCARRY

    return result
end

local helper_cp = function(value, cmp)
    registers.f[1] = (value == cmp) and true or false -- FLAG_ZERO
    registers.f[2] = true -- FLAG_SUBSTRACT
    registers.f[3] = (_bitAnd(_math_abs(cmp), 0x0f) > (_bitAnd(value, 0x0f))) -- FLAG_HALFCARRY
    registers.f[4] = (value < cmp) and true or false -- FLAG_CARRY
end

local helper_swap = function(value)
    local upperNibble = _bitAnd(value, 0xF0) / 16
    local lowerNibble = _bitAnd(value, 0x0F)

    value = (lowerNibble * 16) + upperNibble

    registers.f[1] = (value == 0) -- FLAG_ZERO
    registers.f[2] = false -- FLAG_SUBSTRACT
    registers.f[3] = false -- FLAG_HALFCARRY
    registers.f[4] = false -- FLAG_CARRY

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
    registers.f[1] = (bitExtract(value, bit, 1) == 0) -- FLAG_ZERO
    registers.f[2] = false -- FLAG_SUBSTRACT
    registers.f[3] = true -- FLAG_HALFCARRY
end

local helper_set = function(bit, value)
    return bitReplace(value, 1, bit, 1)
end

local helper_reset = function(bit, value)
    return bitReplace(value, 0, bit, 1)
end

local ldn_nn = function(reg1, reg2, value16)
    if (reg1 == 's') then
        registers.sp = value16
        return
    end

    writeTwoRegisters(reg1, reg2, value16)
end

local cbOpcodes = {
    -- Opcode: 0x00
    [0x01] = function()
        registers.b = helper_rlc(registers.b, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x01
    [0x02] = function()
        registers.c = helper_rlc(registers.c, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x02
    [0x03] = function()
        registers.d = helper_rlc(registers.d, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x03
    [0x04] = function()
        registers.e = helper_rlc(registers.e, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x04
    [0x05] = function()
        registers.h = helper_rlc(registers.h, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x05
    [0x06] = function()
        registers.l = helper_rlc(registers.l, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x06
    [0x07] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_rlc(mmuReadByte(address), 8))
    
        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0x07
    [0x08] = function()
        registers.a = helper_rlc(registers.a, 8)
    
        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x08
    [0x09] = function()
        registers.b = helper_rrc(registers.b, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x09
    [0x0a] = function()
        registers.c = helper_rrc(registers.c, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x0a
    [0x0b] = function()
        registers.d = helper_rrc(registers.d, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x0b
    [0x0c] = function()
        registers.e = helper_rrc(registers.e, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x0c
    [0x0d] = function()
        registers.h = helper_rrc(registers.h, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x0d
    [0x0e] = function()
        registers.l = helper_rrc(registers.l, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x0e
    [0x0f] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_rrc(mmuReadByte(address), 8))
    
        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0x0f
    [0x10] = function()
        registers.a = helper_rrc(registers.a, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x10
    [0x11] = function()
        registers.b = helper_rl(registers.b, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x11
    [0x12] = function()
        registers.c = helper_rl(registers.c, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x12
    [0x13] = function()
        registers.d = helper_rl(registers.d, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x13
    [0x14] = function()
        registers.e = helper_rl(registers.e, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x14
    [0x15] = function()
        registers.h = helper_rl(registers.h, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x15
    [0x16] = function()
        registers.l = helper_rl(registers.l, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x16
    [0x17] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_rl(mmuReadByte(address), 8))
    
        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0x17
    [0x18] = function()
        registers.a = helper_rl(registers.a, 8)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x18
    [0x19] = function()
        registers.b = helper_rr(registers.b, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x19
    [0x1a] = function()
        registers.c = helper_rr(registers.c, 8)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x1a
    [0x1b] = function()
        registers.d = helper_rr(registers.d, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x1b
    [0x1c] = function()
        registers.e = helper_rr(registers.e, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x1c
    [0x1d] = function()
        registers.h = helper_rr(registers.h, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x1d
    [0x1e] = function()
        registers.l = helper_rr(registers.l, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x1e
    [0x1f] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_rr(mmuReadByte(address), 8))
    
        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0x1f
    [0x20] = function()
        registers.a = helper_rr(registers.a, 8)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x20
    [0x21] = function()
        registers.b = helper_sla(registers.b, 8)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x21
    [0x22] = function()
        registers.c = helper_sla(registers.c, 8)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x22
    [0x23] = function()
        registers.d = helper_sla(registers.d, 8)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x23
    [0x24] = function()
        registers.e = helper_sla(registers.e, 8)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x24
    [0x25] = function()
        registers.h = helper_sla(registers.h, 8)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x25
    [0x26] = function()
        registers.l = helper_sla(registers.l, 8)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x26
    [0x27] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_sla(mmuReadByte(address), 8))

        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0x27
    [0x28] = function()
        registers.a = helper_sla(registers.a, 8)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x28
    [0x29] = function()
        registers.b = helper_sra(registers.b, 8)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x29
    [0x2a] = function()
        registers.c = helper_sra(registers.c, 8)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x2a
    [0x2b] = function()
        registers.d = helper_sra(registers.d, 8)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x2b
    [0x2c] = function()
        registers.e = helper_sra(registers.e, 8)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x2c
    [0x2d] = function()
        registers.h = helper_sra(registers.h, 8)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x2d
    [0x2e] = function()
        registers.l = helper_sra(registers.l, 8)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x2e
    [0x2f] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_sra(mmuReadByte(address), 8))

        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0x2f
    [0x30] = function()
        registers.a = helper_sra(registers.a, 8)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x30
    [0x31] = function()
        registers.b = helper_swap(registers.b)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x31
    [0x32] = function()
        registers.c = helper_swap(registers.c)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x32
    [0x33] = function()
        registers.d = helper_swap(registers.d)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x33
    [0x34] = function()
        registers.e = helper_swap(registers.e)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x34
    [0x35] = function()
        registers.h = helper_swap(registers.h)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x35
    [0x36] = function()
        registers.l = helper_swap(registers.l)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x36
    [0x37] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_swap(mmuReadByte(address), 8))

        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0x37
    [0x38] = function()
        registers.a = helper_swap(registers.a)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x38
    [0x39] = function()
        registers.b = helper_srl(registers.b, 8)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x39
    [0x3a] = function()
        registers.c = helper_srl(registers.c, 8)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x3a
    [0x3b] = function()
        registers.d = helper_srl(registers.d, 8)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x3b
    [0x3c] = function()
        registers.e = helper_srl(registers.e, 8)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x3c
    [0x3d] = function()
        registers.h = helper_srl(registers.h, 8)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x3d
    [0x3e] = function()
        registers.l = helper_srl(registers.l, 8)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x3e
    [0x3f] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_srl(mmuReadByte(address), 8))

        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0x3f
    [0x40] = function()
        registers.a = helper_srl(registers.a, 8)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x40
    [0x41] = function()
        helper_test(0, registers.b)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x41
    [0x42] = function()
        helper_test(0, registers.c)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x42
    [0x43] = function()
        helper_test(0, registers.d)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x43
    [0x44] = function()
        helper_test(0, registers.e)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x44
    [0x45] = function()
        helper_test(0, registers.h)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x45
    [0x46] = function()
        helper_test(0, registers.l)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x46
    [0x47] = function()
        local address = readTwoRegisters('h', 'l')
        helper_test(0, mmuReadByte(address))

        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0x47
    [0x48] = function()
        helper_test(0, registers.a)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x48
    [0x49] = function()
        helper_test(1, registers.b)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x49
    [0x4a] = function()
        helper_test(1, registers.c)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x4a
    [0x4b] = function()
        helper_test(1, registers.d)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x4b
    [0x4c] = function()
        helper_test(1, registers.e)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x4c
    [0x4d] = function()
        helper_test(1, registers.h)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x4d
    [0x4e] = function()
        helper_test(1, registers.l)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x4e
    [0x4f] = function()
        local address = readTwoRegisters('h', 'l')
        helper_test(1, mmuReadByte(address))

        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0x4f
    [0x50] = function()
        helper_test(1, registers.a)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x50
    [0x51] = function()
        helper_test(2, registers.b)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x51
    [0x52] = function()
        helper_test(2, registers.c)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x52
    [0x53] = function()
        helper_test(2, registers.d)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x53
    [0x54] = function()
        helper_test(2, registers.e)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x54
    [0x55] = function()
        helper_test(2, registers.h)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x55
    [0x56] = function()
        helper_test(2, registers.l)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x56
    [0x57] = function()
        local address = readTwoRegisters('h', 'l')
        helper_test(2, mmuReadByte(address))

        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0x57
    [0x58] = function()
        helper_test(2, registers.a)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x58
    [0x59] = function()
        helper_test(3, registers.b)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x59
    [0x5a] = function()
        helper_test(3, registers.c)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x5a
    [0x5b] = function()
        helper_test(3, registers.d)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x5b
    [0x5c] = function()
        helper_test(3, registers.e)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x5c
    [0x5d] = function()
        helper_test(3, registers.h)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x5d
    [0x5e] = function()
        helper_test(3, registers.l)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x5e
    [0x5f] = function()
        local address = readTwoRegisters('h', 'l')
        helper_test(3, mmuReadByte(address))

        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0x5f
    [0x60] = function()
        helper_test(3, registers.a)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x60
    [0x61] = function()
        helper_test(4, registers.b)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x61
    [0x62] = function()
        helper_test(4, registers.c)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x62
    [0x63] = function()
        helper_test(4, registers.d)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x63
    [0x64] = function()
        helper_test(4, registers.e)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x64
    [0x65] = function()
        helper_test(4, registers.h)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x65
    [0x66] = function()
        helper_test(4, registers.l)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x66
    [0x67] = function()
        local address = readTwoRegisters('h', 'l')
        helper_test(4, mmuReadByte(address))

        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0x67
    [0x68] = function()
        helper_test(4, registers.a)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x68
    [0x69] = function()
        helper_test(5, registers.b)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x69
    [0x6a] = function()
        helper_test(5, registers.c)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x6a
    [0x6b] = function()
        helper_test(5, registers.d)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x6b
    [0x6c] = function()
        helper_test(5, registers.e)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x6c
    [0x6d] = function()
        helper_test(5, registers.h)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x6d
    [0x6e] = function()
        helper_test(5, registers.l)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x6e
    [0x6f] = function()
        local address = readTwoRegisters('h', 'l')
        helper_test(5, mmuReadByte(address))

        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0x6f
    [0x70] = function()
        helper_test(5, registers.a)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x70
    [0x71] = function()
        helper_test(6, registers.b)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x71
    [0x72] = function()
        helper_test(6, registers.c)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x72
    [0x73] = function()
        helper_test(6, registers.d)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x73
    [0x74] = function()
        helper_test(6, registers.e)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x74
    [0x75] = function()
        helper_test(6, registers.h)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x75
    [0x76] = function()
        helper_test(6, registers.l)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x76
    [0x77] = function()
        local address = readTwoRegisters('h', 'l')
        helper_test(6, mmuReadByte(address))

        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0x77
    [0x78] = function()
        helper_test(6, registers.a)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x78
    [0x79] = function()
        helper_test(7, registers.b)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x79
    [0x7a] = function()
        helper_test(7, registers.c)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x7a
    [0x7b] = function()
        helper_test(7, registers.d)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x7b
    [0x7c] = function()
        helper_test(7, registers.e)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x7c
    [0x7d] = function()
        helper_test(7, registers.h)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x7d
    [0x7e] = function()
        helper_test(7, registers.l)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x7e
    [0x7f] = function()
        local address = readTwoRegisters('h', 'l')
        helper_test(7, mmuReadByte(address))

        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0x7f
    [0x80] = function()
        helper_test(7, registers.a)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x80
    [0x81] = function()
        registers.b = helper_reset(0, registers.b)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x81
    [0x82] = function()
        registers.c = helper_reset(0, registers.c)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x82
    [0x83] = function()
        registers.d = helper_reset(0, registers.d)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x83
    [0x84] = function()
        registers.e = helper_reset(0, registers.e)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x84
    [0x85] = function()
        registers.h = helper_reset(0, registers.h)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x85
    [0x86] = function()
        registers.l = helper_reset(0, registers.l)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x86
    [0x87] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_reset(0, mmuReadByte(address)))

        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0x87
    [0x88] = function()
        registers.a = helper_reset(0, registers.a)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x88
    [0x89] = function()
        registers.b = helper_reset(1, registers.b)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x89
    [0x8a] = function()
        registers.c = helper_reset(1, registers.c)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x8a
    [0x8b] = function()
        registers.d = helper_reset(1, registers.d)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x8b
    [0x8c] = function()
        registers.e = helper_reset(1, registers.e)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x8c
    [0x8d] = function()
        registers.h = helper_reset(1, registers.h)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x8d
    [0x8e] = function()
        registers.l = helper_reset(1, registers.l)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x8e
    [0x8f] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_reset(1, mmuReadByte(address)))

        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0x8f
    [0x90] = function()
        registers.a = helper_reset(1, registers.a)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x90
    [0x91] = function()
        registers.b = helper_reset(2, registers.b)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x91
    [0x92] = function()
        registers.c = helper_reset(2, registers.c)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x92
    [0x93] = function()
        registers.d = helper_reset(2, registers.d)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x93
    [0x94] = function()
        registers.e = helper_reset(2, registers.e)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x94
    [0x95] = function()
        registers.h = helper_reset(2, registers.h)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x95
    [0x96] = function()
        registers.l = helper_reset(2, registers.l)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x96
    [0x97] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_reset(2, mmuReadByte(address)))
    
        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0x97
    [0x98] = function()
        registers.a = helper_reset(2, registers.a)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x98
    [0x99] = function()
        registers.b = helper_reset(3, registers.b)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x99
    [0x9a] = function()
        registers.c = helper_reset(3, registers.c)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x9a
    [0x9b] = function()
        registers.d = helper_reset(3, registers.d)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x9b
    [0x9c] = function()
        registers.e = helper_reset(3, registers.e)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x9c
    [0x9d] = function()
        registers.h = helper_reset(3, registers.h)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x9d
    [0x9e] = function()
        registers.l = helper_reset(3, registers.l)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x9e
    [0x9f] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_reset(3, mmuReadByte(address)))
    
        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0x9f
    [0xa0] = function()
        registers.a = helper_reset(3, registers.a)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xa0
    [0xa1] = function()
        registers.b = helper_reset(4, registers.b)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xa1
    [0xa2] = function()
        registers.c = helper_reset(4, registers.c)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xa2
    [0xa3] = function()
        registers.d = helper_reset(4, registers.d)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xa3
    [0xa4] = function()
        registers.e = helper_reset(4, registers.e)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xa4
    [0xa5] = function()
        registers.h = helper_reset(4, registers.h)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xa5
    [0xa6] = function()
        registers.l = helper_reset(4, registers.l)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xa6
    [0xa7] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_reset(4, mmuReadByte(address)))
    
        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0xa7
    [0xa8] = function()
        registers.a = helper_reset(4, registers.a)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xa8
    [0xa9] = function()
        registers.b = helper_reset(5, registers.b)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xa9
    [0xaa] = function()
        registers.c = helper_reset(5, registers.c)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xaa
    [0xab] = function()
        registers.d = helper_reset(5, registers.d)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xab
    [0xac] = function()
        registers.e = helper_reset(5, registers.e)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xac
    [0xad] = function()
        registers.h = helper_reset(5, registers.h)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xad
    [0xae] = function()
        registers.l = helper_reset(5, registers.l)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xae
    [0xaf] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_reset(5, mmuReadByte(address)))
    
        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0xaf
    [0xb0] = function()
        registers.a = helper_reset(5, registers.a)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xb0
    [0xb1] = function()
        registers.b = helper_reset(6, registers.b)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xb1
    [0xb2] = function()
        registers.c = helper_reset(6, registers.c)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xb2
    [0xb3] = function()
        registers.d = helper_reset(6, registers.d)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xb3
    [0xb4] = function()
        registers.e = helper_reset(6, registers.e)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xb4
    [0xb5] = function()
        registers.h = helper_reset(6, registers.h)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xb5
    [0xb6] = function()
        registers.l = helper_reset(6, registers.l)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xb6
    [0xb7] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_reset(6, mmuReadByte(address)))
    
        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0xb7
    [0xb8] = function()
        registers.a = helper_reset(6, registers.a)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xb8
    [0xb9] = function()
        registers.b = helper_reset(7, registers.b)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xb9
    [0xba] = function()
        registers.c = helper_reset(7, registers.c)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xba
    [0xbb] = function()
        registers.d = helper_reset(7, registers.d)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xbb
    [0xbc] = function()
        registers.e = helper_reset(7, registers.e)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xbc
    [0xbd] = function()
        registers.h = helper_reset(7, registers.h)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xbd
    [0xbe] = function()
        registers.l = helper_reset(7, registers.l)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xbe
    [0xbf] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_reset(7, mmuReadByte(address)))
    
        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0xbf
    [0xc0] = function()
        registers.a = helper_reset(7, registers.a)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xc0
    [0xc1] = function()
        registers.b = helper_set(0, registers.b)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xc1
    [0xc2] = function()
        registers.c = helper_set(0, registers.c)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xc2
    [0xc3] = function()
        registers.d = helper_set(0, registers.d)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xc3
    [0xc4] = function()
        registers.e = helper_set(0, registers.e)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xc4
    [0xc5] = function()
        registers.h = helper_set(0, registers.h)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xc5
    [0xc6] = function()
        registers.l = helper_set(0, registers.l)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xc6
    [0xc7] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_set(0, mmuReadByte(address)))

        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0xc7
    [0xc8] = function()
        registers.a = helper_set(0, registers.a)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xc8
    [0xc9] = function()
        registers.b = helper_set(1, registers.b)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xc9
    [0xca] = function()
        registers.c = helper_set(1, registers.c)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xca
    [0xcb] = function()
        registers.d = helper_set(1, registers.d)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xcb
    [0xcc] = function()
        registers.e = helper_set(1, registers.e)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xcc
    [0xcd] = function()
        registers.h = helper_set(1, registers.h)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xcd
    [0xce] = function()
        registers.l = helper_set(1, registers.l)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xce
    [0xcf] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_set(1, mmuReadByte(address)))
    
        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0xcf
    [0xd0] = function()
        registers.a = helper_set(1, registers.a)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xd0
    [0xd1] = function()
        registers.b = helper_set(2, registers.b)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xd1
    [0xd2] = function()
        registers.c = helper_set(2, registers.c)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xd2
    [0xd3] = function()
        registers.d = helper_set(2, registers.d)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xd3
    [0xd4] = function()
        registers.e = helper_set(2, registers.e)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xd4
    [0xd5] = function()
        registers.h = helper_set(2, registers.h)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xd5
    [0xd6] = function()
        registers.l = helper_set(2, registers.l)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xd6
    [0xd7] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_set(2, mmuReadByte(address)))
    
        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0xd7
    [0xd8] = function()
        registers.a = helper_set(2, registers.a)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xd8
    [0xd9] = function()
        registers.b = helper_set(3, registers.b)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xd9
    [0xda] = function()
        registers.c = helper_set(3, registers.c)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xda
    [0xdb] = function()
        registers.d = helper_set(3, registers.d)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xdb
    [0xdc] = function()
        registers.e = helper_set(3, registers.e)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xdc
    [0xdd] = function()
        registers.h = helper_set(3, registers.h)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xdd
    [0xde] = function()
        registers.l = helper_set(3, registers.l)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xde
    [0xdf] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_set(3, mmuReadByte(address)))
    
        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0xdf
    [0xe0] = function()
        registers.a = helper_set(3, registers.a)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xe0
    [0xe1] = function()
        registers.b = helper_set(4, registers.b)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xe1
    [0xe2] = function()
        registers.c = helper_set(4, registers.c)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xe2
    [0xe3] = function()
        registers.d = helper_set(4, registers.d)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xe3
    [0xe4] = function()
        registers.e = helper_set(4, registers.e)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xe4
    [0xe5] = function()
        registers.h = helper_set(4, registers.h)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xe5
    [0xe6] = function()
        registers.l = helper_set(4, registers.l)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xe6
    [0xe7] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_set(4, mmuReadByte(address)))
    
        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0xe7
    [0xe8] = function()
        registers.a = helper_set(4, registers.a)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xe8
    [0xe9] = function()
        registers.b = helper_set(5, registers.b)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xe9
    [0xea] = function()
        registers.c = helper_set(5, registers.c)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xea
    [0xeb] = function()
        registers.d = helper_set(5, registers.d)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xeb
    [0xec] = function()
        registers.e = helper_set(5, registers.e)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xec
    [0xed] = function()
        registers.h = helper_set(5, registers.h)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xed
    [0xee] = function()
        registers.l = helper_set(5, registers.l)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xee
    [0xef] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_set(5, mmuReadByte(address)))
    
        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0xef
    [0xf0] = function()
        registers.a = helper_set(5, registers.a)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xf0
    [0xf1] = function()
        registers.b = helper_set(6, registers.b)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xf1
    [0xf2] = function()
        registers.c = helper_set(6, registers.c)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xf2
    [0xf3] = function()
        registers.d = helper_set(6, registers.d)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xf3
    [0xf4] = function()
        registers.e = helper_set(6, registers.e)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xf4
    [0xf5] = function()
        registers.h = helper_set(6, registers.h)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xf5
    [0xf6] = function()
        registers.l = helper_set(6, registers.l)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xf6
    [0xf7] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_set(6, mmuReadByte(address)))
    
        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0xf7
    [0xf8] = function()
        registers.a = helper_set(6, registers.a)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xf8
    [0xf9] = function()
        registers.b = helper_set(7, registers.b)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xf9
    [0xfa] = function()
        registers.c = helper_set(7, registers.c)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xfa
    [0xfb] = function()
        registers.d = helper_set(7, registers.d)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xfb
    [0xfc] = function()
        registers.e = helper_set(7, registers.e)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xfc
    [0xfd] = function()
        registers.h = helper_set(7, registers.h)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xfd
    [0xfe] = function()
        registers.l = helper_set(7, registers.l)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xfe
    [0xff] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_set(7, mmuReadByte(address)))
    
        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0xff
    [0x100] = function()
        registers.a = helper_set(7, registers.a)
    
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
}

opcodes = {
    -- Opcode: 0x00
    [0x01] = function()
        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x01
    [0x02] = function()
        writeTwoRegisters('b', 'c', mmuReadUInt16(registers.pc))

        registers.pc = registers.pc + 2
        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0x02
    [0x03] = function()
        mmuWriteByte(readTwoRegisters('b', 'c'), registers.a)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x03
    [0x04] = function()
        writeTwoRegisters('b', 'c', helper_inc16(readTwoRegisters('b', 'c')))

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x04
    [0x05] = function()
        registers.b = helper_inc(registers.b)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x05
    [0x06] = function()
        registers.b = helper_dec(registers.b)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x06
    [0x07] = function()
        registers.b = mmuReadByte(registers.pc)

        registers.pc = registers.pc + 1
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x07
    [0x08] = function()
        registers.a = helper_rlc(registers.a, 8)
        registers.f[1] = false

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x08
    [0x09] = function()
        mmuWriteShort(mmuReadUInt16(registers.pc), registers.sp)

        registers.pc = registers.pc + 2
        registers.clock = {
            m = 5,
            t = 20
        }
    end,
    -- Opcode: 0x09
    [0x0a] = function()
        writeTwoRegisters('h', 'l', helper_add16(readTwoRegisters('h', 'l'), readTwoRegisters('b', 'c')))

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x0a
    [0x0b] = function()
        registers.a = mmuReadByte(readTwoRegisters('b', 'c'))

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x0b
    [0x0c] = function()
        writeTwoRegisters('b', 'c', helper_dec16(readTwoRegisters('b', 'c')))

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x0c
    [0x0d] = function()
        registers.c = helper_inc(registers.c)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x0d
    [0x0e] = function()
        registers.c = helper_dec(registers.c)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x0e
    [0x0f] = function()
        registers.c = mmuReadByte(registers.pc)

        registers.pc = registers.pc + 1
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x0f
    [0x10] = function()
        registers.a = helper_rrc(registers.a, 8)
        registers.f[1] = false
    
        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x10
    [0x11] = function()
        -- TODO
        --haltCPU()

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x11
    [0x12] = function()
        writeTwoRegisters('d', 'e', mmuReadUInt16(registers.pc))

        registers.pc = registers.pc + 2
        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0x12
    [0x13] = function()
        mmuWriteByte(readTwoRegisters('d', 'e'), registers.a)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x13
    [0x14] = function()
        writeTwoRegisters('d', 'e', helper_inc16(readTwoRegisters('d', 'e')))

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x14
    [0x15] = function()
        registers.d = helper_inc(registers.d)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x15
    [0x16] = function()
        registers.d = helper_dec(registers.d)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x16
    [0x17] = function()
        registers.d = mmuReadByte(registers.pc)

        registers.pc = registers.pc + 1
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x17
    [0x18] = function()
        registers.a = helper_rl(registers.a, 8)
        registers.f[1] = false

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x18
    [0x19] = function()
        local addition = mmuReadSignedByte(registers.pc)

        registers.pc = registers.pc + addition + 1

        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0x19
    [0x1a] = function()
        writeTwoRegisters('h', 'l', helper_add16(readTwoRegisters('h', 'l'), readTwoRegisters('d', 'e')))

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x1a
    [0x1b] = function()
        registers.a = mmuReadByte(readTwoRegisters('d', 'e'))

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x1b
    [0x1c] = function()
        writeTwoRegisters('d', 'e', helper_dec16(readTwoRegisters('d', 'e')))

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x1c
    [0x1d] = function()
        registers.e = helper_inc(registers.e)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x1d
    [0x1e] = function()
        registers.e = helper_dec(registers.e)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x1e
    [0x1f] = function()
        registers.e = mmuReadByte(registers.pc)

        registers.pc = registers.pc + 1
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x1f
    [0x20] = function()
        registers.a = helper_rr(registers.a, 8)
    
        registers.f[1] = false -- FLAG_ZERO

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x20
    [0x21] = function()
        if (not registers.f[1]) then
            registers.pc = registers.pc + mmuReadSignedByte(registers.pc) + 1

            registers.clock = {
            m = 3,
            t = 12
        }
        else
            registers.pc = registers.pc + 1

            registers.clock = {
            m = 2,
            t = 8
        }
        end
    end,
    -- Opcode: 0x21
    [0x22] = function()
        writeTwoRegisters('h', 'l', mmuReadUInt16(registers.pc))

        registers.pc = registers.pc + 2
        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0x22
    [0x23] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, registers.a)

        if (address == 0xff) then
            writeTwoRegisters('h', 'l', 0)
        else
            writeTwoRegisters('h', 'l', address + 1)
        end

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x23
    [0x24] = function()
        writeTwoRegisters('h', 'l', helper_inc16(readTwoRegisters('h', 'l')))

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x24
    [0x25] = function()
        registers.h = helper_inc(registers.h)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x25
    [0x26] = function()
        registers.h = helper_dec(registers.h)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x26
    [0x27] = function()
        registers.h = mmuReadByte(registers.pc)

        registers.pc = registers.pc + 1
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x27
    [0x28] = function()
        local registerA = registers.a

        if (not registers.f[2]) then -- FLAG_SUBSTRACT
            if (registers.f[4] or registerA > 0x99) then -- FLAG_CARRY
                registerA = registerA + 0x60
                registers.f[4] = true -- FLAG_CARRY
            end

            if (registers.f[3] or _bitAnd(registerA, 0x0f) > 0x09) then -- FLAG_HALFCARRY
                registerA = registerA + 0x6
            end
        else
            if (registers.f[4]) then -- FLAG_CARRY
                registerA = registerA - 0x60
            end

            if (registers.f[3]) then -- FLAG_HALFCARRY
                registerA = registerA - 0x6
            end
        end

        registerA = registerA % 0x100

        registers.f[1] = (registerA == 0) and true or false -- FLAG_ZERO
        registers.f[3] = false -- FLAG_HALFCARRY
        registers.a = registerA

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x28
    [0x29] = function()
        if (registers.f[1]) then
            registers.pc = registers.pc + mmuReadSignedByte(registers.pc) + 1

            registers.clock = {
                m = 3,
                t = 12
            }
        else
            registers.pc = registers.pc + 1

            registers.clock = {
                m = 2,
                t = 8
            }
        end
    end,
    -- Opcode: 0x29
    [0x2a] = function()
        local value = readTwoRegisters('h', 'l')
        writeTwoRegisters('h', 'l', helper_add16(value, value))

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x2a
    [0x2b] = function()
        local address = readTwoRegisters('h', 'l')
        registers.a = mmuReadByte(address)

        if (address == 0xff) then
            writeTwoRegisters('h', 'l', 0)
        else
            writeTwoRegisters('h', 'l', address + 1)
        end

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x2b
    [0x2c] = function()
        writeTwoRegisters('h', 'l', helper_dec16(readTwoRegisters('h', 'l')))

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x2c
    [0x2d] = function()
        registers.l = helper_inc(registers.l)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x2d
    [0x2e] = function()
        registers.l = helper_dec(registers.l)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x2e
    [0x2f] = function()
        registers.l = mmuReadByte(registers.pc)

        registers.pc = registers.pc + 1
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x2f
    [0x30] = function()
        registers.a = helper_not(registers.a)

        registers.f[2] = true -- FLAG_SUBSTRACT
        registers.f[3] = true -- FLAG_HALFCARRY

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x30
    [0x31] = function()
        if (not registers.f[4]) then
            registers.pc = registers.pc + mmuReadSignedByte(registers.pc) + 1

            registers.clock = {
                m = 3,
                t = 12
            }
        else
            registers.pc = registers.pc + 1

            registers.clock = {
            m = 2,
            t = 8
        }
        end
    end,
    -- Opcode: 0x31
    [0x32] = function()
        registers.sp = mmuReadUInt16(registers.pc)

        registers.pc = registers.pc + 2
        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0x32
    [0x33] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, registers.a)

        if (address == 0) then
            writeTwoRegisters('h', 'l', 0xff)
        else
            writeTwoRegisters('h', 'l', address - 1)
        end

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x33
    [0x34] = function()
        registers.sp = helper_inc16(registers.sp)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x34
    [0x35] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_inc(mmuReadByte(address)))

        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0x35
    [0x36] = function()
        local address = readTwoRegisters('h', 'l')
        mmuWriteByte(address, helper_dec(mmuReadByte(address)))

        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0x36
    [0x37] = function()
        mmuWriteByte(readTwoRegisters('h', 'l'), mmuReadByte(registers.pc))

        registers.pc = registers.pc + 1
        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0x37
    [0x38] = function()
        registers.f[2] = false -- FLAG_SUBSTRACT
        registers.f[3] = false -- FLAG_HALFCARRY
        registers.f[4] = true

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x38
    [0x39] = function()
        if (registers.f[4]) then
            registers.pc = registers.pc + mmuReadSignedByte(registers.pc) + 1
        else
            registers.pc = registers.pc + 1
        end

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x39
    [0x3a] = function()
        writeTwoRegisters('h', 'l', helper_add16(readTwoRegisters('h', 'l'), registers.sp))

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x3a
    [0x3b] = function()
        local address = readTwoRegisters('h', 'l')
        registers.a = mmuReadByte(address)

        if (address == 0) then
            writeTwoRegisters('h', 'l', 0xff)
        else
            writeTwoRegisters('h', 'l', address - 1)
        end

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x3b
    [0x3c] = function()
        registers.sp = helper_dec16(registers.sp)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x3c
    [0x3d] = function()
        registers.a = helper_inc(registers.a)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x3d
    [0x3e] = function()
        registers.a = helper_dec(registers.a)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x3e
    [0x3f] = function()
        registers.a = mmuReadByte(registers.pc)

        registers.pc = registers.pc + 1
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x3f
    [0x40] = function()
        registers.f[2] = false -- FLAG_SUBSTRACT
        registers.f[3] = false -- FLAG_HALFCARRY
        registers.f[4] = not registers.f[4] -- FLAG_CARRY

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x40
    [0x41] = function()
        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x41
    [0x42] = function()
        registers.b = registers.c

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x42
    [0x43] = function()
        registers.b = registers.d

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x43
    [0x44] = function()
        registers.b = registers.e

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x44
    [0x45] = function()
        registers.b = registers.h

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x45
    [0x46] = function()
        registers.b = registers.l

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x46
    [0x47] = function()
        registers.b = mmuReadByte(readTwoRegisters('h', 'l'))

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x47
    [0x48] = function()
        registers.b = registers.a

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x48
    [0x49] = function()
        registers.c = registers.b

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x49
    [0x4a] = function()
        registers.c = registers.c

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x4a
    [0x4b] = function()
        registers.c = registers.d

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x4b
    [0x4c] = function()
        registers.c = registers.e

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x4c
    [0x4d] = function()
        registers.c = registers.h

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x4d
    [0x4e] = function()
        registers.c = registers.l

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x4e
    [0x4f] = function()
        registers.c = mmuReadByte(readTwoRegisters('h', 'l'))

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x4f
    [0x50] = function()
        registers.c = registers.a

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x50
    [0x51] = function()
        registers.d = registers.b

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x51
    [0x52] = function()
        registers.d = registers.c

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x52
    [0x53] = function()
        registers.d = registers.d

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x53
    [0x54] = function()
        registers.d = registers.e

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x54
    [0x55] = function()
        registers.d = registers.h

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x55
    [0x56] = function()
        registers.d = registers.l

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x56
    [0x57] = function()
        registers.d = mmuReadByte(readTwoRegisters('h', 'l'))

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x57
    [0x58] = function()
        registers.d = registers.a

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x58
    [0x59] = function()
        registers.e = registers.b

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x59
    [0x5a] = function()
        registers.e = registers.c

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x5a
    [0x5b] = function()
        registers.e = registers.d

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x5b
    [0x5c] = function()
        registers.e = registers.e

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x5c
    [0x5d] = function()
        registers.e = registers.h

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x5d
    [0x5e] = function()
        registers.e = registers.l

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x5e
    [0x5f] = function()
        registers.e = mmuReadByte(readTwoRegisters('h', 'l'))

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x5f
    [0x60] = function()
        registers.e = registers.a

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x60
    [0x61] = function()
        registers.h = registers.b

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x61
    [0x62] = function()
        registers.h = registers.c

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x62
    [0x63] = function()
        registers.h = registers.d

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x63
    [0x64] = function()
        registers.h = registers.e

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x64
    [0x65] = function()
        registers.h = registers.h

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x65
    [0x66] = function()
        registers.h = registers.l

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x66
    [0x67] = function()
        registers.h = mmuReadByte(readTwoRegisters('h', 'l'))

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x67
    [0x68] = function()
        registers.h = registers.a

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x68
    [0x69] = function()
        registers.l = registers.b

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x69
    [0x6a] = function()
        registers.l = registers.c

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x6a
    [0x6b] = function()
        registers.l = registers.d

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x6b
    [0x6c] = function()
        registers.l = registers.e

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x6c
    [0x6d] = function()
        registers.l = registers.h

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x6d
    [0x6e] = function()
        registers.l = registers.l

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x6e
    [0x6f] = function()
        registers.l = mmuReadByte(readTwoRegisters('h', 'l'))

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x6f
    [0x70] = function()
        registers.l = registers.a

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x70
    [0x71] = function()
        mmuWriteByte(readTwoRegisters('h', 'l'), registers.b)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x71
    [0x72] = function()
        mmuWriteByte(readTwoRegisters('h', 'l'), registers.c)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x72
    [0x73] = function()
        mmuWriteByte(readTwoRegisters('h', 'l'), registers.d)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x73
    [0x74] = function()
        mmuWriteByte(readTwoRegisters('h', 'l'), registers.e)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x74
    [0x75] = function()
        mmuWriteByte(readTwoRegisters('h', 'l'), registers.h)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x75
    [0x76] = function()
        mmuWriteByte(readTwoRegisters('h', 'l'), registers.l)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x76
    [0x77] = function()
        haltCPU()

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x77
    [0x78] = function()
        mmuWriteByte(readTwoRegisters('h', 'l'), registers.a)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x78
    [0x79] = function()
        registers.a = registers.b

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x79
    [0x7a] = function()
        registers.a = registers.c

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x7a
    [0x7b] = function()
        registers.a = registers.d

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x7b
    [0x7c] = function()
        registers.a = registers.e

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x7c
    [0x7d] = function()
        registers.a = registers.h

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x7d
    [0x7e] = function()
        registers.a = registers.l

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x7e
    [0x7f] = function()
        registers.a = mmuReadByte(readTwoRegisters('h', 'l'))

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x7f
    [0x80] = function()
        registers.a = registers.a

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x80
    [0x81] = function()
        registers.a = helper_add(registers.a, registers.b)

        registers.f[2] = false
        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x81
    [0x82] = function()
        registers.a = helper_add(registers.a, registers.c)

        registers.f[2] = false
        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x82
    [0x83] = function()
        registers.a = helper_add(registers.a, registers.d)

        registers.f[2] = false
        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x83
    [0x84] = function()
        registers.a = helper_add(registers.a, registers.e)

        registers.f[2] = false
        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x84
    [0x85] = function()
        registers.a = helper_add(registers.a, registers.h)

        registers.f[2] = false
        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x85
    [0x86] = function()
        registers.a = helper_add(registers.a, registers.l)

        registers.f[2] = false
        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x86
    [0x87] = function()
        registers.a = helper_add(registers.a,
            mmuReadByte(readTwoRegisters('h', 'l')))

        registers.f[2] = false
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x87
    [0x88] = function()
        registers.a = helper_add(registers.a, registers.a)

        registers.f[2] = false
        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x88
    [0x89] = function()
        registers.a = helper_adc(registers.a, registers.b)

        registers.f[2] = false
        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x89
    [0x8a] = function()
        registers.a = helper_adc(registers.a, registers.c)

        registers.f[2] = false
        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x8a
    [0x8b] = function()
        registers.a = helper_adc(registers.a, registers.d)

        registers.f[2] = false
        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x8b
    [0x8c] = function()
        registers.a = helper_adc(registers.a, registers.e)

        registers.f[2] = false
        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x8c
    [0x8d] = function()
        registers.a = helper_adc(registers.a, registers.h)

        registers.f[2] = false
        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x8d
    [0x8e] = function()
        registers.a = helper_adc(registers.a, registers.l)

        registers.f[2] = false
        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x8e
    [0x8f] = function()
        registers.a = helper_adc(registers.a,
            mmuReadByte(readTwoRegisters('h', 'l')))

        registers.f[2] = false
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x8f
    [0x90] = function()
        registers.a = helper_adc(registers.a, registers.a)

        registers.f[2] = false
        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x90
    [0x91] = function()
        registers.a = helper_sub(registers.a, registers.b)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x91
    [0x92] = function()
        registers.a = helper_sub(registers.a, registers.c)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x92
    [0x93] = function()
        registers.a = helper_sub(registers.a, registers.d)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x93
    [0x94] = function()
        registers.a = helper_sub(registers.a, registers.e)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x94
    [0x95] = function()
        registers.a = helper_sub(registers.a, registers.h)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x95
    [0x96] = function()
        registers.a = helper_sub(registers.a, registers.l)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x96
    [0x97] = function()
        registers.a = helper_sub(registers.a,
            mmuReadByte(readTwoRegisters('h', 'l')))

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x97
    [0x98] = function()
        registers.a = helper_sub(registers.a, registers.a)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x98
    [0x99] = function()
        registers.a = helper_sbc(registers.a, registers.b)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x99
    [0x9a] = function()
        registers.a = helper_sbc(registers.a, registers.c)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x9a
    [0x9b] = function()
        registers.a = helper_sbc(registers.a, registers.d)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x9b
    [0x9c] = function()
        registers.a = helper_sbc(registers.a, registers.e)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x9c
    [0x9d] = function()
        registers.a = helper_sbc(registers.a, registers.h)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x9d
    [0x9e] = function()
        registers.a = helper_sbc(registers.a, registers.l)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0x9e
    [0x9f] = function()
        registers.a = helper_sbc(registers.a, mmuReadByte(readTwoRegisters('h', 'l')))

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0x9f
    [0xa0] = function()
        registers.a = helper_sbc(registers.a, registers.a)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xa0
    [0xa1] = function()
        registers.a = helper_and(registers.a, registers.b)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xa1
    [0xa2] = function()
        registers.a = helper_and(registers.a, registers.c)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xa2
    [0xa3] = function()
        registers.a = helper_and(registers.a, registers.d)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xa3
    [0xa4] = function()
        registers.a = helper_and(registers.a, registers.e)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xa4
    [0xa5] = function()
        registers.a = helper_and(registers.a, registers.h)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xa5
    [0xa6] = function()
        registers.a = helper_and(registers.a, registers.l)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xa6
    [0xa7] = function()
        registers.a = helper_and(registers.a, mmuReadByte(
            readTwoRegisters('h', 'l'))
        )

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xa7
    [0xa8] = function()
        registers.a = helper_and(registers.a, registers.a)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xa8
    [0xa9] = function()
        registers.a = helper_xor(registers.a, registers.b)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xa9
    [0xaa] = function()
        registers.a = helper_xor(registers.a, registers.c)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xaa
    [0xab] = function()
        registers.a = helper_xor(registers.a, registers.d)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xab
    [0xac] = function()
        registers.a = helper_xor(registers.a, registers.e)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xac
    [0xad] = function()
        registers.a = helper_xor(registers.a, registers.h)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xad
    [0xae] = function()
        registers.a = helper_xor(registers.a, registers.l)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xae
    [0xaf] = function()
        registers.a = helper_xor(registers.a, mmuReadByte(
            readTwoRegisters('h', 'l'))
        )

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xaf
    [0xb0] = function()
        registers.a = helper_xor(registers.a, registers.a)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xb0
    [0xb1] = function()
        registers.a = helper_or(registers.a, registers.b)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xb1
    [0xb2] = function()
        registers.a = helper_or(registers.a, registers.c)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xb2
    [0xb3] = function()
        registers.a = helper_or(registers.a, registers.d)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xb3
    [0xb4] = function()
        registers.a = helper_or(registers.a, registers.e)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xb4
    [0xb5] = function()
        registers.a = helper_or(registers.a, registers.h)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xb5
    [0xb6] = function()
        registers.a = helper_or(registers.a, registers.l)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xb6
    [0xb7] = function()
        registers.a = helper_or(registers.a, mmuReadByte(
            readTwoRegisters('h', 'l'))
        )

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xb7
    [0xb8] = function()
        registers.a = helper_or(registers.a, registers.a)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xb8
    [0xb9] = function()
        helper_cp(registers.a, registers.b)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xb9
    [0xba] = function()
        helper_cp(registers.a, registers.c)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xba
    [0xbb] = function()
        helper_cp(registers.a, registers.d)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xbb
    [0xbc] = function()
        helper_cp(registers.a, registers.e)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xbc
    [0xbd] = function()
        helper_cp(registers.a, registers.h)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xbd
    [0xbe] = function()
        helper_cp(registers.a, registers.l)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xbe
    [0xbf] = function()
        helper_cp(registers.a, mmuReadByte(
            readTwoRegisters('h', 'l'))
        )

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xbf
    [0xc0] = function()
        helper_cp(registers.a, registers.a)

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xc0
    [0xc1] = function()
        if (not registers.f[1]) then
            registers.pc = mmuPopStack()
        end

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xc1
    [0xc2] = function()
        writeTwoRegisters('b', 'c', mmuPopStack())

        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0xc2
    [0xc3] = function()
        if (not registers.f[1]) then
            registers.pc = mmuReadUInt16(registers.pc)
        else
            registers.pc = registers.pc + 2
        end

        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0xc3
    [0xc4] = function()
        registers.pc = mmuReadUInt16(registers.pc)

        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0xc4
    [0xc5] = function()
        if (not registers.f[1]) then
            mmuPushStack(registers.pc + 2)
            registers.pc = mmuReadUInt16(registers.pc)

            registers.clock = {
                m = 6,
                t = 24
            }
        else
            registers.pc = registers.pc + 2

            registers.clock = {
            m = 3,
            t = 12
        }
        end
    end,
    -- Opcode: 0xc5
    [0xc6] = function()
        mmuPushStack(readTwoRegisters('b', 'c'))

        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0xc6
    [0xc7] = function()
        registers.a = helper_add(registers.a,
            mmuReadByte(registers.pc))

        registers.f[2] = false
        registers.pc = registers.pc + 1
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xc7
    [0xc8] = function()
        mmuPushStack(registers.pc)
        registers.pc = 0x0

        registers.clock = {
            m = 8,
            t = 32
        }
    end,
    -- Opcode: 0xc8
    [0xc9] = function()
        if (registers.f[1]) then
            registers.pc = mmuPopStack()

            registers.clock = {
                m = 5,
                t = 20
            }
        else
            registers.clock = {
                m = 2,
                t = 8
            }
        end
    end,
    -- Opcode: 0xc9
    [0xca] = function()
        registers.pc = mmuPopStack()

        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0xca
    [0xcb] = function()
        if (registers.f[1]) then
            registers.pc = mmuReadUInt16(registers.pc)
        else
            registers.pc = registers.pc + 2
        end

        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0xcb
    [0xcc] = function()
        local opcode1 = mmuReadByte(registers.pc)
        registers.pc = registers.pc + 1

        if (not cbOpcodes[opcode1 + 1]) then
            pauseCPU()
            Log.error("CPU CB", "Unknown opcode: 0x%s at 0x%s", _string_format("%.2x", opcode1), _string_format("%.2x", registers.pc - 2))
            return
        end

        cbOpcodes[opcode1 + 1]()
    end,
    -- Opcode: 0xcc
    [0xcd] = function()
        if (registers.f[1]) then
            mmuPushStack(registers.pc + 2)
            registers.pc = mmuReadUInt16(registers.pc)

            registers.clock = {
                m = 6,
                t = 24
            }
        else
            registers.pc = registers.pc + 2

            registers.clock = {
                m = 3,
                t = 12
            }
        end
    end,
    -- Opcode: 0xcd
    [0xce] = function()
        local value = mmuReadUInt16(registers.pc)

        mmuPushStack(registers.pc + 2)
        registers.pc = value

        registers.clock = {
            m = 6,
            t = 24
        }
    end,
    -- Opcode: 0xce
    [0xcf] = function()
        registers.a = helper_adc(registers.a,
            mmuReadByte(registers.pc))

        registers.pc = registers.pc + 1
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xcf
    [0xd0] = function()
        mmuPushStack(registers.pc)
        registers.pc = 0x08

        registers.clock = {
            m = 8,
            t = 32
        }
    end,
    -- Opcode: 0xd0
    [0xd1] = function()
        if (not registers.f[4]) then
            registers.pc = mmuPopStack()

            registers.clock = {
                m = 5,
                t = 20
            }
        else
            registers.clock = {
                m = 2,
                t = 8
            }
        end
    end,
    -- Opcode: 0xd1
    [0xd2] = function()
        writeTwoRegisters('d', 'e', mmuPopStack())

        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0xd2
    [0xd3] = function()
        if (not registers.f[4]) then
            registers.pc = mmuReadUInt16(registers.pc)
        else
            registers.pc = registers.pc + 2
        end

        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0xd3
    [0xd4] = function() end,
    -- Opcode: 0xd4
    [0xd5] = function()
        if (not registers.f[4]) then
            mmuPushStack(registers.pc + 2)
            registers.pc = mmuReadUInt16(registers.pc)

            registers.clock = {
                m = 6,
                t = 24
            }
        else
            registers.pc = registers.pc + 2

            registers.clock = {
                m = 3,
                t = 12
            }
        end
    end,
    -- Opcode: 0xd5
    [0xd6] = function()
        mmuPushStack(readTwoRegisters('d', 'e'))

        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0xd6
    [0xd7] = function()
        registers.a = helper_sub(registers.a, mmuReadByte(registers.pc))

        registers.pc = registers.pc + 1
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xd7
    [0xd8] = function()
        mmuPushStack(registers.pc)
        registers.pc = 0x10

        registers.clock = {
            m = 8,
            t = 32
        }
    end,
    -- Opcode: 0xd8
    [0xd9] = function()
        if (registers.f[4]) then
            registers.pc = mmuPopStack()
        end

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xd9
    [0xda] = function()
        registers.pc = mmuPopStack()
        setInterrupts()

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xda
    [0xdb] = function()
        if (registers.f[4]) then
            registers.pc = mmuReadUInt16(registers.pc)
        else
            registers.pc = registers.pc + 2
        end

        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0xdb
    [0xdc] = function() end,
    -- Opcode: 0xdc
    [0xdd] = function()
        if (registers.f[4]) then
            mmuPushStack(registers.pc + 2)
            registers.pc = mmuReadUInt16(registers.pc)

            registers.clock = {
                m = 6,
                t = 24
            }
        else
            registers.pc = registers.pc + 2

            registers.clock = {
                m = 3,
                t = 12
            }
        end
    end,
    -- Opcode: 0xdd
    [0xde] = function() end,
    -- Opcode: 0xde
    [0xdf] = function()
        registers.a = helper_sbc(registers.a, mmuReadByte(registers.pc))

        registers.pc = registers.pc + 1
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xdf
    [0xe0] = function()
        mmuPushStack(registers.pc)
        registers.pc = 0x18

        registers.clock = {
            m = 8,
            t = 32
        }
    end,
    -- Opcode: 0xe0
    [0xe1] = function()
        mmuWriteByte(0xFF00 + mmuReadByte(registers.pc), registers.a)

        registers.pc = registers.pc + 1
        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0xe1
    [0xe2] = function()
        writeTwoRegisters('h', 'l', mmuPopStack())

        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0xe2
    [0xe3] = function()
        mmuWriteByte(0xFF00 + registers.c, registers.a)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xe3
    [0xe4] = function() end,
    -- Opcode: 0xe4
    [0xe5] = function() end,
    -- Opcode: 0xe5
    [0xe6] = function()
        mmuPushStack(readTwoRegisters('h', 'l'))

        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0xe6
    [0xe7] = function()
        registers.a = helper_and(registers.a, mmuReadByte(registers.pc))

        registers.pc = registers.pc + 1
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xe7
    [0xe8] = function()
        mmuPushStack(registers.pc)
        registers.pc = 0x20

        registers.clock = {
            m = 8,
            t = 32
        }
    end,
    -- Opcode: 0xe8
    [0xe9] = function()
        registers.sp = helper_add_sp(registers.sp,
            mmuReadSignedByte(registers.pc))

        registers.pc = registers.pc + 1
        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0xe9
    [0xea] = function()
        registers.pc = readTwoRegisters('h', 'l')

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xea
    [0xeb] = function()
        mmuWriteByte(mmuReadUInt16(registers.pc), registers.a)

        registers.pc = registers.pc + 2
        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0xeb
    [0xec] = function() end,
    -- Opcode: 0xec
    [0xed] = function() end,
    -- Opcode: 0xed
    [0xee] = function() end,
    -- Opcode: 0xee
    [0xef] = function()
        registers.a = helper_xor(registers.a, mmuReadByte(registers.pc))

        registers.pc = registers.pc + 1
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xef
    [0xf0] = function()
        mmuPushStack(registers.pc)
        registers.pc = 0x28

        registers.clock = {
            m = 8,
            t = 32
        }
    end,
    -- Opcode: 0xf0
    [0xf1] = function()
        registers.a = mmuReadByte(0xFF00 + mmuReadByte(registers.pc))

        registers.pc = registers.pc + 1
        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0xf1
    [0xf2] = function()
        writeTwoRegisters('a', 'f', mmuPopStack())

        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0xf2
    [0xf3] = function()
        registers.a = mmuReadByte(0xFF00 + registers.c)

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xf3
    [0xf4] = function()
        disableInterrupts()

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xf4
    [0xf5] = function() end,
    -- Opcode: 0xf5
    [0xf6] = function()
        mmuPushStack(readTwoRegisters('a', 'f'))

        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0xf6
    [0xf7] = function()
        registers.a = helper_or(registers.a, mmuReadByte(registers.pc))

        registers.pc = registers.pc + 1
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xf7
    [0xf8] = function()
        mmuPushStack(registers.pc)
        registers.pc = 0x30

        registers.clock = {
            m = 8,
            t = 32
        }
    end,
    -- Opcode: 0xf8
    [0xf9] = function()
        local address = registers.sp
        local value = mmuReadSignedByte(registers.pc)

        writeTwoRegisters('h', 'l', helper_add_sp(address, value))

        registers.pc = registers.pc + 1
        registers.clock = {
            m = 3,
            t = 12
        }
    end,
    -- Opcode: 0xf9
    [0xfa] = function()
        registers.sp = readTwoRegisters('h', 'l')

        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xfa
    [0xfb] = function()
        registers.a = mmuReadByte(mmuReadUInt16(registers.pc))

        registers.pc = registers.pc + 2
        registers.clock = {
            m = 4,
            t = 16
        }
    end,
    -- Opcode: 0xfb
    [0xfc] = function()
        enableInterrupts()

        registers.clock = {
            m = 1,
            t = 4
        }
    end,
    -- Opcode: 0xfc
    [0xfd] = function() end,
    -- Opcode: 0xfd
    [0xfe] = function() end,
    -- Opcode: 0xfe
    [0xff] = function()
        helper_cp(registers.a, mmuReadByte(registers.pc))

        registers.pc = registers.pc + 1
        registers.clock = {
            m = 2,
            t = 8
        }
    end,
    -- Opcode: 0xff
    [0x100] = function()
        mmuPushStack(registers.pc)
        registers.pc = 0x38

        registers.clock = {
            m = 4,
            t = 16
        }
    end,
}