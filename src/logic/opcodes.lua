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

local helper_inc = function(cpu, value)
    cpu.registers.f[3] = (_bitAnd(value, 0x0f) == 0x0f) -- FLAG_HALFCARRY

    value = (value + 1) % 0x100

    cpu.registers.f[1] = (value == 0) and true or false -- FLAG_ZERO
    cpu.registers.f[2] = false -- FLAG_SUBSTRACT

    return value
end

local helper_inc16 = function(cpu, value)
    return (value + 1) % 0x10000
end

local helper_dec = function(cpu, value)
    cpu.registers.f[3] = (_bitAnd(value, 0x0f) == 0x00) -- FLAG_HALFCARRY

    value = (value - 1) % 0x100

    cpu.registers.f[1] = (value == 0) and true or false -- FLAG_ZERO
    cpu.registers.f[2] = true -- FLAG_SUBSTRACT

    return value
end

local helper_dec16 = function(cpu, value)
    return (value - 1) % 0x10000
end

local helper_add = function(cpu, value, add)
    result = (value + add) % 0x100

    cpu.registers.f[3] = (_bitAnd(_bitXor(_bitXor(value, add), result), 0x10) == 0x10) -- FLAG_HALFCARRY
    cpu.registers.f[4] = (value + add > 0xFF)  -- FLAG_CARRY

    cpu.registers.f[1] = (result == 0) and true or false -- FLAG_ZERO
    cpu.registers.f[2] = false -- FLAG_SUBSTRACT

    return result
end

local helper_adc = function(cpu, value, add)
    local carry = cpu.registers.f[4] and 1 or 0

    result = (value + add + carry) % 0x100

    cpu.registers.f[3] = (_bitAnd(_bitXor(_bitXor(value, add), result), 0x10) == 0x10) -- FLAG_HALFCARRY
    cpu.registers.f[4] = (value + add + carry > 0xFF) -- FLAG_CARRY

    cpu.registers.f[1] = (result == 0) and true or false -- FLAG_ZERO
    cpu.registers.f[2] = false -- FLAG_SUBSTRACT

    return result
end

local helper_add_sp = function(cpu, value, add)
    result = (value + add) % 0x10000

    cpu.registers.f[3] = (_bitAnd(_bitXor(_bitXor(value, add), result), 0x1000) == 0x1000) -- FLAG_HALFCARRY
    cpu.registers.f[4] = (value + add > 0xFFFF) -- FLAG_CARRY

    cpu.registers.f[1] = false -- FLAG_ZERO
    cpu.registers.f[2] = false -- FLAG_SUBSTRACT

    return result
end

local helper_add16 = function(cpu, value, add)
    result = (value + add) % 0x10000

    cpu.registers.f[3] = (_bitAnd(_bitXor(_bitXor(value, add), result), 0x1000) == 0x1000) -- FLAG_HALFCARRY
    cpu.registers.f[4] = (value + add > 0xFFFF) -- FLAG_CARRY

    --cpu.registers.f[1] = (result == 0) and true or false -- FLAG_ZERO
    cpu.registers.f[2] = false -- FLAG_SUBSTRACT

    return result
end

local helper_sub = function(cpu, value, sub)
    result = (value - sub) % 0x100

    cpu.registers.f[3] = (_bitAnd(_bitXor(_bitXor(value, sub), result), 0x10) == 0x10) -- FLAG_HALFCARRY
    cpu.registers.f[4] = (sub > value) -- FLAG_CARRY

    cpu.registers.f[1] = (result == 0) and true or false -- FLAG_ZERO
    cpu.registers.f[2] = true -- FLAG_SUBSTRACT

    return result
end

local helper_and = function(cpu, value1, value2)
    local value = _bitAnd(value1, value2)

    cpu.registers.f[1] = (value == 0) and true or false -- FLAG_ZERO
    cpu.registers.f[2] = false -- FLAG_SUBSTRACT
    cpu.registers.f[3] = true -- FLAG_HALFCARRY
    cpu.registers.f[4] = false -- FLAG_CARRY

    return value
end

local helper_or = function(cpu, value1, value2)
    local value = _bitOr(value1, value2)

    cpu.registers.f[1] = (value == 0) and true or false -- FLAG_ZERO
    cpu.registers.f[2] = false -- FLAG_SUBSTRACT
    cpu.registers.f[3] = false -- FLAG_HALFCARRY
    cpu.registers.f[4] = false -- FLAG_CARRY

    return value
end

local helper_xor = function(cpu, value1, value2)
    local value = _bitXor(value1, value2)

    cpu.registers.f[1] = (value == 0) and true or false -- FLAG_ZERO
    cpu.registers.f[2] = false -- FLAG_SUBSTRACT
    cpu.registers.f[3] = false -- FLAG_HALFCARRY
    cpu.registers.f[4] = false -- FLAG_CARRY

    return value
end

local helper_lrotate = function(cpu, value, withCarry, bitSize)
    local oldCarry = cpu.registers.f[4]

    if (withCarry) then
        cpu.registers.f[4] = (_bitAnd(value, 0x80) ~= 0) -- FLAG_CARRY
    end

    value = value * 2

    if (withCarry) then
        value = _bitReplace(value, (oldCarry) and 1 or 0, 0, 1)
    else
        local bit = ((value / (2 ^ (bitSize - 1))) % 2 >= 1) and 1 or 0
        value = _bitReplace(value, bit, 0, 1)
    end

    local bits = _math_floor(_math_log(value) / _math_log(2)) + 1

    if (bits < 0) then
        bits = 0
    end

    if (bits > bitSize) then
        value = _bitReplace(value, 0, bits - 1, (bits - bitSize))
    end

    if (withCarry) then
        value = _bitOr(value, oldCarry and 1 or 0)
    end

    cpu.registers.f[1] = (value == 0) and true or false -- FLAG_ZERO
    cpu.registers.f[2] = false -- FLAG_SUBSTRACT
    cpu.registers.f[3] = false -- FLAG_HALFCARRY

    return value
end

local helper_rrotate = function(cpu, value, withCarry, bitSize)
    local oldCarry = cpu.registers.f[4]

    if (withCarry) then
        cpu.registers.f[4] = (_bitAnd(value, 0x01) ~= 0) -- FLAG_CARRY
    end

    value = value / 2

    if (withCarry) then
        value = _bitReplace(value, (oldCarry) and 1 or 0, bitSize - 1, 1)
    else
        local bit = ((value / (2 ^ 0)) % 2 >= 1) and 1 or 0
        value = _bitReplace(value, bit, bitSize - 1, 1)
    end

    local bits = _math_floor(_math_log(value) / _math_log(2)) + 1

    if (bits < 0) then
        bits = 0
    end

    if (bits > bitSize) then
        value = _bitReplace(value, 0, bits - 1, (bits - bitSize))
    end

    if (withCarry) then
        value = _bitOr(value, oldCarry and _bitLShift(1, 7) or 0)
    end

    cpu.registers.f[1] = (value == 0) and true or false -- FLAG_ZERO
    cpu.registers.f[2] = false -- FLAG_SUBSTRACT
    cpu.registers.f[3] = false -- FLAG_HALFCARRY

    return value
end

local helper_lshift = function(cpu, value, withCarry, bitSize)
    local oldCarry = cpu.registers.f[4]

    if (withCarry) then
        cpu.registers.f[4] = (_bitAnd(value, 0x80) ~= 0) -- FLAG_CARRY
    end

    value = value / 2
    value = _bitReplace(value, 0, 0, 1)

    local bits = _math_floor(_math_log(value) / _math_log(2)) + 1

    if (bits < 0) then
        bits = 0
    end

    if (bits > bitSize) then
        value = _bitReplace(value, 0, bits - 1, (bits - bitSize))
    end

    if (withCarry) then
        value = _bitOr(value, oldCarry and 1 or 0)
    end

    cpu.registers.f[1] = (value == 0) and true or false -- FLAG_ZERO
    cpu.registers.f[2] = false -- FLAG_SUBSTRACT
    cpu.registers.f[3] = false -- FLAG_HALFCARRY

    return value
end

local helper_rshift = function(cpu, value, withCarry, bitSize)
    local oldCarry = cpu.registers.f[4]

    if (withCarry) then
        cpu.registers.f[4] = (_bitAnd(value, 0x01) ~= 0) -- FLAG_CARRY
    end

    value = value / 2
    value = _bitReplace(value, 0, bitSize - 1, 1)

    local bits = _math_floor(_math_log(value) / _math_log(2)) + 1

    if (bits < 0) then
        bits = 0
    end

    if (bits > bitSize) then
        value = _bitReplace(value, 0, bits - 1, (bits - bitSize))
    end

    if (withCarry) then
        value = _bitOr(value, oldCarry and _bitLShift(1, 7) or 0)
    end

    cpu.registers.f[1] = (value == 0) and true or false -- FLAG_ZERO
    cpu.registers.f[2] = false -- FLAG_SUBSTRACT
    cpu.registers.f[3] = false -- FLAG_HALFCARRY

    return value
end

local helper_cp = function(cpu, value, cmp)
    cpu.registers.f[1] = (value == cmp) and true or false -- FLAG_ZERO
    cpu.registers.f[2] = true -- FLAG_SUBSTRACT
    cpu.registers.f[3] = (_bitAnd(_math_abs(cmp), 0x0f) > (_bitAnd(value, 0x0f))) -- FLAG_HALFCARRY
    cpu.registers.f[4] = (value < cmp) and true or false -- FLAG_CARRY
end

local helper_swap = function(cpu, value)
    local upperNible = _bitAnd(value, 0xF0) / 16
    local lowerNibble = _bitAnd(value, 0x0F)

    value = (lowerNibble * 16) + upperNible

    cpu.registers.f[1] = (value == 0) -- FLAG_ZERO
    cpu.registers.f[2] = false -- FLAG_SUBSTRACT
    cpu.registers.f[3] = false -- FLAG_HALFCARRY
    cpu.registers.f[4] = false -- FLAG_CARRY

    return value
end

local helper_not = function(cpu, value)
    value = _bitNot(value)

    if (value > 0xff) then
        value = _bitAnd(value, 0xFF)
    end

    return value
end

local helper_test = function(cpu, bit, value)
    cpu.registers.f[1] = (bitExtract(value, bit, 1) == 0) -- FLAG_ZERO
    cpu.registers.f[2] = false -- FLAG_SUBSTRACT
    cpu.registers.f[3] = true -- FLAG_HALFCARRY
end

local helper_set = function(cpu, bit, value)
    return bitReplace(value, 1, bit, 1)
end

local helper_reset = function(cpu, bit, value)
    return bitReplace(value, 0, bit, 1)
end

local ldn_nn = function(cpu, reg1, reg2, value16)
    if (reg1 == 's') then
        cpu.registers.sp = value16
        return
    end

    cpu:writeTwoRegisters(reg1, reg2, value16)
end

GameBoy.cbOpcodes = {
    [0x11] = function(cpu)
        cpu.registers.c = helper_lrotate(cpu, cpu.registers.c, true, 8)
    
        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x17] = function(cpu)
        cpu.registers.a = helper_lrotate(cpu, cpu.registers.a, true, 8)
    
        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x18] = function(cpu)
        cpu.registers.b = helper_rrotate(cpu, cpu.registers.b, true, 8)
    
        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x19] = function(cpu)
        cpu.registers.c = helper_rrotate(cpu, cpu.registers.c, true, 8)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x1a] = function(cpu)
        cpu.registers.d = helper_rrotate(cpu, cpu.registers.d, true, 8)
    
        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x1b] = function(cpu)
        cpu.registers.e = helper_rrotate(cpu, cpu.registers.e, true, 8)
    
        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x1c] = function(cpu)
        cpu.registers.h = helper_rrotate(cpu, cpu.registers.h, true, 8)
    
        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x1d] = function(cpu)
        cpu.registers.l = helper_rrotate(cpu, cpu.registers.l, true, 8)
    
        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x1e] = function(cpu)
        cpu:writeTwoRegisters('h', 'l', helper_rrotate(cpu, cpu:readTwoRegisters('h', 'l'), true, 16))
    
        cpu.registers.clock.m = cpu.registers.clock.m + 4
        cpu.registers.clock.t = cpu.registers.clock.t + 16
    end,
    [0x1f] = function(cpu)
        cpu.registers.a = helper_rrotate(cpu, cpu.registers.a, true, 8)
    
        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x27] = function(cpu)
        cpu.registers.c = helper_lshift(cpu, cpu.registers.c, true, 8)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x30] = function(cpu)
        cpu.registers.b = helper_swap(cpu, cpu.registers.b)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x31] = function(cpu)
        cpu.registers.c = helper_swap(cpu, cpu.registers.c)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x32] = function(cpu)
        cpu.registers.d = helper_swap(cpu, cpu.registers.d)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x33] = function(cpu)
        cpu.registers.e = helper_swap(cpu, cpu.registers.e)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x34] = function(cpu)
        cpu.registers.h = helper_swap(cpu, cpu.registers.h)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x35] = function(cpu)
        cpu.registers.l = helper_swap(cpu, cpu.registers.l)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x36] = function(cpu)
        local address = cpu:readTwoRegisters('h', 'l')
        cpu.mmu:writeByte(address, helper_swap(cpu, cpu.mmu:readByte(address)))

        cpu.registers.clock.m = cpu.registers.clock.m + 4
        cpu.registers.clock.t = cpu.registers.clock.t + 16
    end,
    [0x37] = function(cpu)
        cpu.registers.a = helper_swap(cpu, cpu.registers.a)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x38] = function(cpu)
        cpu.registers.b = helper_rshift(cpu, cpu.registers.b, true, 8)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x39] = function(cpu)
        cpu.registers.c = helper_rshift(cpu, cpu.registers.c, true, 8)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x3a] = function(cpu)
        cpu.registers.d = helper_rshift(cpu, cpu.registers.d, true, 8)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x3b] = function(cpu)
        cpu.registers.e = helper_rshift(cpu, cpu.registers.e, true, 8)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x3c] = function(cpu)
        cpu.registers.h = helper_rshift(cpu, cpu.registers.h, true, 8)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x3d] = function(cpu)
        cpu.registers.l = helper_rshift(cpu, cpu.registers.l, true, 8)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x3e] = function(cpu)
        cpu:writeTwoRegisters('h', 'l', helper_rshift(cpu, cpu:readTwoRegisters('h', 'l'), true, 16))

        cpu.registers.clock.m = cpu.registers.clock.m + 4
        cpu.registers.clock.t = cpu.registers.clock.t + 16
    end,
    [0x3f] = function(cpu)
        cpu.registers.a = helper_rshift(cpu, cpu.registers.a, true, 8)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x40] = function(cpu)
        helper_test(cpu, 0, cpu.registers.b)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x41] = function(cpu)
        helper_test(cpu, 0, cpu.registers.c)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x46] = function(cpu)
        helper_test(cpu, 0, cpu:readTwoRegisters('h', 'l'))

        cpu.registers.clock.m = cpu.registers.clock.m + 4
        cpu.registers.clock.t = cpu.registers.clock.t + 16
    end,
    [0x47] = function(cpu)
        helper_test(cpu, 0, cpu.registers.a)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x48] = function(cpu)
        helper_test(cpu, 1, cpu.registers.b)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x50] = function(cpu)
        helper_test(cpu, 2, cpu.registers.b)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x58] = function(cpu)
        helper_test(cpu, 3, cpu.registers.b)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x5f] = function(cpu)
        helper_test(cpu, 3, cpu.registers.a)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x60] = function(cpu)
        helper_test(cpu, 4, cpu.registers.b)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x61] = function(cpu)
        helper_test(cpu, 4, cpu.registers.c)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x68] = function(cpu)
        helper_test(cpu, 5, cpu.registers.b)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x69] = function(cpu)
        helper_test(cpu, 5, cpu.registers.c)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x6f] = function(cpu)
        helper_test(cpu, 5, cpu.registers.a)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x70] = function(cpu)
        helper_test(cpu, 6, cpu.registers.b)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x77] = function(cpu)
        helper_test(cpu, 6, cpu.registers.a)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x78] = function(cpu)
        helper_test(cpu, 7, cpu.registers.b)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x7c] = function(cpu)
        helper_test(cpu, 7, cpu.registers.h)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x7d] = function(cpu)
        helper_test(cpu, 7, cpu.registers.l)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x7e] = function(cpu)
        helper_test(cpu, 7, cpu:readTwoRegisters('h', 'l'))

        cpu.registers.clock.m = cpu.registers.clock.m + 4
        cpu.registers.clock.t = cpu.registers.clock.t + 16
    end,
    [0x7f] = function(cpu)
        helper_test(cpu, 7, cpu.registers.a)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x86] = function(cpu)
        cpu:writeTwoRegisters('h', 'l', helper_reset(cpu, 0, cpu:readTwoRegisters('h', 'l')))

        cpu.registers.clock.m = cpu.registers.clock.m + 4
        cpu.registers.clock.t = cpu.registers.clock.t + 16
    end,
    [0x87] = function(cpu)
        cpu.registers.a = helper_reset(cpu, 0, cpu.registers.a)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0xbe] = function(cpu)
        cpu:writeTwoRegisters('h', 'l', helper_reset(cpu, 7, cpu:readTwoRegisters('h', 'l')))

        cpu.registers.clock.m = cpu.registers.clock.m + 4
        cpu.registers.clock.t = cpu.registers.clock.t + 16
    end,
    [0xcf] = function(cpu)
        cpu.registers.a = helper_set(cpu, 1, cpu.registers.a)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0xfe] = function(cpu)
        cpu:writeTwoRegisters('h', 'l', helper_set(cpu, 7, cpu:readTwoRegisters('h', 'l')))

        cpu.registers.clock.m = cpu.registers.clock.m + 4
        cpu.registers.clock.t = cpu.registers.clock.t + 16
    end,
}

GameBoy.opcodes = {
    [0x00] = function(cpu)
        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x01] = function(cpu)
        cpu:writeTwoRegisters('b', 'c', cpu.mmu:readUInt16(cpu.registers.pc))

        cpu.registers.pc = cpu.registers.pc + 2
        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0x02] = function(cpu)
        cpu.mmu:writeByte(cpu:readTwoRegisters('b', 'c'), cpu.registers.a)

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x03] = function(cpu)
        cpu:writeTwoRegisters('b', 'c', helper_inc16(cpu, cpu:readTwoRegisters('b', 'c')))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x04] = function(cpu)
        cpu.registers.b = helper_inc(cpu, cpu.registers.b)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x05] = function(cpu)
        cpu.registers.b = helper_dec(cpu, cpu.registers.b)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x06] = function(cpu)
        cpu.registers.b = cpu.mmu:readByte(cpu.registers.pc)

        cpu.registers.pc = cpu.registers.pc + 1
        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x07] = function(cpu)
        cpu.registers.a = helper_lrotate(cpu, cpu.registers.a, true, 8)

        cpu.registers.clock.m = cpu.registers.clock.m + 1
        cpu.registers.clock.t = cpu.registers.clock.t + 4
    end,
    [0x08] = function(cpu)
        cpu.mmu:writeShort(cpu.mmu:readUInt16(cpu.registers.pc), cpu.registers.sp)

        cpu.registers.pc = cpu.registers.pc + 2
        cpu.registers.clock.m = 5
        cpu.registers.clock.t = 20
    end,
    [0x09] = function(cpu)
        cpu:writeTwoRegisters('h', 'l', helper_add16(cpu,
            cpu:readTwoRegisters('h', 'l'), cpu:readTwoRegisters('b', 'c')))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x0a] = function(cpu)
        cpu.registers.a = cpu.mmu:readByte(cpu:readTwoRegisters('b', 'c'))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x0b] = function(cpu)
        cpu:writeTwoRegisters('b', 'c', helper_dec16(cpu, cpu:readTwoRegisters('b', 'c')))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x0c] = function(cpu)
        cpu.registers.c = helper_inc(cpu, cpu.registers.c)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x0d] = function(cpu)
        cpu.registers.c = helper_dec(cpu, cpu.registers.c)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x0e] = function(cpu)
        cpu.registers.c = cpu.mmu:readByte(cpu.registers.pc)

        cpu.registers.pc = cpu.registers.pc + 1
        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x0f] = function(cpu)
        cpu.registers.a = helper_rrotate(cpu, cpu.registers.a, true, 8)
    
        cpu.registers.clock.m = cpu.registers.clock.m + 1
        cpu.registers.clock.t = cpu.registers.clock.t + 4
    end,
    [0x10] = function(cpu)
        cpu:halt(true)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x11] = function(cpu)
        cpu:writeTwoRegisters('d', 'e', cpu.mmu:readUInt16(cpu.registers.pc))

        cpu.registers.pc = cpu.registers.pc + 2
        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0x12] = function(cpu)
        cpu.mmu:writeByte(cpu:readTwoRegisters('d', 'e'), cpu.registers.a)

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x13] = function(cpu)
        cpu:writeTwoRegisters('d', 'e', helper_inc16(cpu, cpu:readTwoRegisters('d', 'e')))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x14] = function(cpu)
        cpu.registers.d = helper_inc(cpu, cpu.registers.d)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x15] = function(cpu)
        cpu.registers.d = helper_dec(cpu, cpu.registers.d)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x16] = function(cpu)
        cpu.registers.d = cpu.mmu:readByte(cpu.registers.pc)

        cpu.registers.pc = cpu.registers.pc + 1
        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x17] = function(cpu)
        cpu.registers.a = helper_lrotate(cpu, cpu.registers.a, true, 8)
    
        cpu.registers.clock.m = cpu.registers.clock.m + 1
        cpu.registers.clock.t = cpu.registers.clock.t + 4
    end,
    [0x18] = function(cpu)
        local addition = cpu.mmu:readSignedByte(cpu.registers.pc)

        cpu.registers.pc = cpu.registers.pc + addition + 1

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0x19] = function(cpu)
        cpu:writeTwoRegisters('h', 'l', helper_add16(cpu,
            cpu:readTwoRegisters('h', 'l'), cpu:readTwoRegisters('d', 'e')))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x1a] = function(cpu)
        cpu.registers.a = cpu.mmu:readByte(cpu:readTwoRegisters('d', 'e'))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x1b] = function(cpu)
        cpu:writeTwoRegisters('d', 'e', helper_dec16(cpu, cpu:readTwoRegisters('d', 'e')))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x1c] = function(cpu)
        cpu.registers.e = helper_inc(cpu, cpu.registers.e)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x1d] = function(cpu)
        cpu.registers.e = helper_dec(cpu, cpu.registers.e)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x1e] = function(cpu)
        cpu.registers.e = cpu.mmu:readByte(cpu.registers.pc)

        cpu.registers.pc = cpu.registers.pc + 1
        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x1f] = function(cpu)
        cpu.registers.a = helper_rrotate(cpu, cpu.registers.a, true, 8)
    
        cpu.registers.f[1] = false -- FLAG_ZERO

        cpu.registers.clock.m = cpu.registers.clock.m + 1
        cpu.registers.clock.t = cpu.registers.clock.t + 4
    end,
    [0x20] = function(cpu)
        if (not cpu.registers.f[1]) then
            cpu.registers.pc = cpu.registers.pc + cpu.mmu:readSignedByte(cpu.registers.pc) + 1

            cpu.registers.clock.m = 3
            cpu.registers.clock.t = 12
        else
            cpu.registers.pc = cpu.registers.pc + 1

            cpu.registers.clock.m = 2
            cpu.registers.clock.t = 8
        end
    end,
    [0x21] = function(cpu)
        cpu:writeTwoRegisters('h', 'l', cpu.mmu:readUInt16(cpu.registers.pc))

        cpu.registers.pc = cpu.registers.pc + 2
        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0x22] = function(cpu)
        local address = cpu:readTwoRegisters('h', 'l')
        cpu.mmu:writeByte(address, cpu.registers.a)

        if (address == 0xff) then
            cpu:writeTwoRegisters('h', 'l', 0)
        else
            cpu:writeTwoRegisters('h', 'l', address + 1)
        end

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x23] = function(cpu)
        cpu:writeTwoRegisters('h', 'l', helper_inc16(cpu, cpu:readTwoRegisters('h', 'l')))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x24] = function(cpu)
        cpu.registers.h = helper_inc(cpu, cpu.registers.h)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x25] = function(cpu)
        cpu.registers.h = helper_dec(cpu, cpu.registers.h)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x26] = function(cpu)
        cpu.registers.h = cpu.mmu:readByte(cpu.registers.pc)

        cpu.registers.pc = cpu.registers.pc + 1
        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x27] = function(cpu)
        local registerA = cpu.registers.a

        if (not cpu.registers.f[2]) then -- FLAG_SUBSTRACT
            if (cpu.registers.f[4] or registerA > 0x99) then -- FLAG_CARRY
                registerA = registerA + 0x60
                cpu.registers.f[4] = true -- FLAG_CARRY
            end

            if (cpu.registers.f[3] or _bitAnd(registerA, 0x0f) > 0x09) then -- FLAG_HALFCARRY
                registerA = registerA + 0x6
            end
        else
            if (cpu.registers.f[4]) then -- FLAG_CARRY
                registerA = registerA - 0x60
            end

            if (cpu.registers.f[3]) then -- FLAG_HALFCARRY
                registerA = registerA - 0x6
            end
        end

        registerA = registerA % 0x100

        cpu.registers.f[1] = (registerA == 0) and true or false -- FLAG_ZERO
        cpu.registers.f[3] = false -- FLAG_HALFCARRY
        cpu.registers.a = registerA

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x28] = function(cpu)
        if (cpu.registers.f[1]) then
            cpu.registers.pc = cpu.registers.pc + cpu.mmu:readSignedByte(cpu.registers.pc) + 1

            cpu.registers.clock.m = 3
            cpu.registers.clock.t = 12
        else
            cpu.registers.pc = cpu.registers.pc + 1

            cpu.registers.clock.m = 2
            cpu.registers.clock.t = 8
        end
    end,
    [0x29] = function(cpu)
        local value = cpu:readTwoRegisters('h', 'l')
        cpu:writeTwoRegisters('h', 'l', helper_add16(cpu, value, value))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x2a] = function(cpu)
        local address = cpu:readTwoRegisters('h', 'l')
        cpu.registers.a = cpu.mmu:readByte(address)

        if (address == 0xff) then
            cpu:writeTwoRegisters('h', 'l', 0)
        else
            cpu:writeTwoRegisters('h', 'l', address + 1)
        end

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x2b] = function(cpu)
        cpu:writeTwoRegisters('h', 'l', helper_dec16(cpu, cpu:readTwoRegisters('h', 'l')))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x2c] = function(cpu)
        cpu.registers.l = helper_inc(cpu, cpu.registers.l)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x2d] = function(cpu)
        cpu.registers.l = helper_dec(cpu, cpu.registers.l)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x2e] = function(cpu)
        cpu.registers.l = cpu.mmu:readByte(cpu.registers.pc)

        cpu.registers.pc = cpu.registers.pc + 1
        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x2f] = function(cpu)
        cpu.registers.a = helper_not(cpu, cpu.registers.a)

        cpu.registers.f[2] = true -- FLAG_SUBSTRACT
        cpu.registers.f[3] = true -- FLAG_HALFCARRY

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x30] = function(cpu)
        if (not cpu.registers.f[4]) then
            cpu.registers.pc = cpu.registers.pc + cpu.mmu:readSignedByte(cpu.registers.pc) + 1

            cpu.registers.clock.m = 3
            cpu.registers.clock.t = 12
        else
            cpu.registers.pc = cpu.registers.pc + 1

            cpu.registers.clock.m = 2
            cpu.registers.clock.t = 8
        end
    end,
    [0x31] = function(cpu)
        cpu.registers.sp = cpu.mmu:readUInt16(cpu.registers.pc)

        cpu.registers.pc = cpu.registers.pc + 2
        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0x32] = function(cpu)
        local address = cpu:readTwoRegisters('h', 'l')
        cpu.mmu:writeByte(address, cpu.registers.a)

        if (address == 0) then
            cpu:writeTwoRegisters('h', 'l', 0xff)
        else
            cpu:writeTwoRegisters('h', 'l', address - 1)
        end

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x33] = function(cpu)
        cpu.registers.sp = helper_inc16(cpu, cpu.registers.sp)

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x34] = function(cpu)
        local address = cpu:readTwoRegisters('h', 'l')
        cpu.mmu:writeByte(address, helper_inc(cpu, cpu.mmu:readByte(address)))

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0x35] = function(cpu)
        local address = cpu:readTwoRegisters('h', 'l')
        cpu.mmu:writeByte(address, helper_dec(cpu, cpu.mmu:readByte(address)))

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0x36] = function(cpu)
        cpu.mmu:writeByte(cpu:readTwoRegisters('h', 'l'), cpu.mmu:readByte(cpu.registers.pc))

        cpu.registers.pc = cpu.registers.pc + 1
        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0x37] = function(cpu)
        cpu.registers.f[2] = true -- FLAG_SUBSTRACT
        cpu.registers.f[3] = true -- FLAG_HALFCARRY
        cpu.registers.f[4] = true

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x38] = function(cpu)
        if (cpu.registers.f[4]) then
            cpu.registers.pc = cpu.registers.pc + cpu.mmu:readSignedByte(cpu.registers.pc) + 1
        else
            cpu.registers.pc = cpu.registers.pc + 1
        end

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x39] = function(cpu)
        cpu:writeTwoRegisters('h', 'l', helper_add16(cpu,
            cpu:readTwoRegisters('h', 'l'), cpu.registers.sp))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x3a] = function(cpu)
        local address = cpu:readTwoRegisters('h', 'l')
        cpu.registers.a = cpu.mmu:readByte(address)

        if (address == 0) then
            cpu:writeTwoRegisters('h', 'l', 0xff)
        else
            cpu:writeTwoRegisters('h', 'l', address - 1)
        end

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x3b] = function(cpu)
        cpu.registers.pc = helper_dec16(cpu, cpu.registers.sp)

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x3c] = function(cpu)
        cpu.registers.a = helper_inc(cpu, cpu.registers.a)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x3d] = function(cpu)
        cpu.registers.a = helper_dec(cpu, cpu.registers.a)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x3e] = function(cpu)
        cpu.registers.a = cpu.mmu:readByte(cpu.registers.pc)

        cpu.registers.pc = cpu.registers.pc + 1
        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x3f] = function(cpu)
        cpu.registers.f[2] = true -- FLAG_SUBSTRACT
        cpu.registers.f[3] = true -- FLAG_HALFCARRY
        cpu.registers.f[4] = not cpu.registers.f[4] -- FLAG_CARRY

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x40] = function(cpu)
        cpu.registers.b = cpu.registers.b

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x41] = function(cpu)
        cpu.registers.b = cpu.registers.c

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x42] = function(cpu)
        cpu.registers.b = cpu.registers.d

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x43] = function(cpu)
        cpu.registers.b = cpu.registers.e

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x44] = function(cpu)
        cpu.registers.b = cpu.registers.h

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x45] = function(cpu)
        cpu.registers.b = cpu.registers.l

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x46] = function(cpu)
        cpu.registers.b = cpu.mmu:readByte(cpu:readTwoRegisters('h', 'l'))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x47] = function(cpu)
        cpu.registers.b = cpu.registers.a

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x48] = function(cpu)
        cpu.registers.c = cpu.registers.b

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x49] = function(cpu)
        cpu.registers.c = cpu.registers.c

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x4a] = function(cpu)
        cpu.registers.c = cpu.registers.d

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x4b] = function(cpu)
        cpu.registers.c = cpu.registers.e

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x4c] = function(cpu)
        cpu.registers.c = cpu.registers.h

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x4d] = function(cpu)
        cpu.registers.c = cpu.registers.l

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x4e] = function(cpu)
        cpu.registers.c = cpu.mmu:readByte(cpu:readTwoRegisters('h', 'l'))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x4f] = function(cpu)
        cpu.registers.c = cpu.registers.a

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x50] = function(cpu)
        cpu.registers.d = cpu.registers.b

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x51] = function(cpu)
        cpu.registers.d = cpu.registers.c

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x52] = function(cpu)
        cpu.registers.d = cpu.registers.d

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x53] = function(cpu)
        cpu.registers.d = cpu.registers.e

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x54] = function(cpu)
        cpu.registers.d = cpu.registers.h

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x55] = function(cpu)
        cpu.registers.d = cpu.registers.l

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x56] = function(cpu)
        cpu.registers.d = cpu.mmu:readByte(cpu:readTwoRegisters('h', 'l'))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x57] = function(cpu)
        cpu.registers.d = cpu.registers.a

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x58] = function(cpu)
        cpu.registers.e = cpu.registers.b

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x59] = function(cpu)
        cpu.registers.e = cpu.registers.c

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x5a] = function(cpu)
        cpu.registers.e = cpu.registers.d

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x5b] = function(cpu)
        cpu.registers.e = cpu.registers.e

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x5c] = function(cpu)
        cpu.registers.e = cpu.registers.h

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x5d] = function(cpu)
        cpu.registers.e = cpu.registers.l

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x5e] = function(cpu)
        cpu.registers.e = cpu.mmu:readByte(cpu:readTwoRegisters('h', 'l'))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x5f] = function(cpu)
        cpu.registers.e = cpu.registers.a

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x60] = function(cpu)
        cpu.registers.h = cpu.registers.b

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x61] = function(cpu)
        cpu.registers.h = cpu.registers.c

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x62] = function(cpu)
        cpu.registers.h = cpu.registers.d

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x63] = function(cpu)
        cpu.registers.h = cpu.registers.e

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x64] = function(cpu)
        cpu.registers.h = cpu.registers.h

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x65] = function(cpu)
        cpu.registers.h = cpu.registers.l

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x66] = function(cpu)
        cpu.registers.h = cpu.mmu:readByte(cpu:readTwoRegisters('h', 'l'))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x67] = function(cpu)
        cpu.registers.h = cpu.registers.a

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x68] = function(cpu)
        cpu.registers.l = cpu.registers.b

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x69] = function(cpu)
        cpu.registers.l = cpu.registers.c

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x6a] = function(cpu)
        cpu.registers.l = cpu.registers.d

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x6b] = function(cpu)
        cpu.registers.l = cpu.registers.e

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x6c] = function(cpu)
        cpu.registers.l = cpu.registers.h

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x6d] = function(cpu)
        cpu.registers.l = cpu.registers.l

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x6e] = function(cpu)
        cpu.registers.l = cpu.mmu:readByte(cpu:readTwoRegisters('h', 'l'))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x6f] = function(cpu)
        cpu.registers.l = cpu.registers.a

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x70] = function(cpu)
        cpu.mmu:writeByte(cpu:readTwoRegisters('h', 'l'), cpu.registers.b)

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x71] = function(cpu)
        cpu.mmu:writeByte(cpu:readTwoRegisters('h', 'l'), cpu.registers.c)

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x72] = function(cpu)
        cpu.mmu:writeByte(cpu:readTwoRegisters('h', 'l'), cpu.registers.d)

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x73] = function(cpu)
        cpu.mmu:writeByte(cpu:readTwoRegisters('h', 'l'), cpu.registers.e)

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x74] = function(cpu)
        cpu.mmu:writeByte(cpu:readTwoRegisters('h', 'l'), cpu.registers.h)

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x75] = function(cpu)
        cpu.mmu:writeByte(cpu:readTwoRegisters('h', 'l'), cpu.registers.l)

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x76] = function(cpu)
        cpu:halt(false)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x77] = function(cpu)
        cpu.mmu:writeByte(cpu:readTwoRegisters('h', 'l'), cpu.registers.a)

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x78] = function(cpu)
        cpu.registers.a = cpu.registers.b

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x79] = function(cpu)
        cpu.registers.a = cpu.registers.c

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x7a] = function(cpu)
        cpu.registers.a = cpu.registers.d

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x7b] = function(cpu)
        cpu.registers.a = cpu.registers.e

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x7c] = function(cpu)
        cpu.registers.a = cpu.registers.h

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x7d] = function(cpu)
        cpu.registers.a = cpu.registers.l

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x7e] = function(cpu)
        cpu.registers.a = cpu.mmu:readByte(cpu:readTwoRegisters('h', 'l'))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x7f] = function(cpu)
        cpu.registers.a = cpu.registers.a

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x80] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a, cpu.registers.b)

        cpu.registers.f[2] = false
        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x81] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a, cpu.registers.c)

        cpu.registers.f[2] = false
        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x82] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a, cpu.registers.d)

        cpu.registers.f[2] = false
        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x83] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a, cpu.registers.e)

        cpu.registers.f[2] = false
        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x84] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a, cpu.registers.h)

        cpu.registers.f[2] = false
        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x85] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a, cpu.registers.l)

        cpu.registers.f[2] = false
        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x86] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a,
            cpu.mmu:readByte(cpu:readTwoRegisters('h', 'l')))

        cpu.registers.f[2] = false
        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x87] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a, cpu.registers.a)

        cpu.registers.f[2] = false
        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x88] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a, cpu.registers.b
            + ((cpu.registers.f[4]) and 1 or 0))

        cpu.registers.f[2] = false
        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x89] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a, cpu.registers.c
            + ((cpu.registers.f[4]) and 1 or 0))

        cpu.registers.f[2] = false
        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x8a] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a, cpu.registers.d
            + ((cpu.registers.f[4]) and 1 or 0))

        cpu.registers.f[2] = false
        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x8b] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a, cpu.registers.e
            + ((cpu.registers.f[4]) and 1 or 0))

        cpu.registers.f[2] = false
        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x8c] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a, cpu.registers.h
            + ((cpu.registers.f[4]) and 1 or 0))

        cpu.registers.f[2] = false
        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x8d] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a, cpu.registers.l
            + ((cpu.registers.f[4]) and 1 or 0))

        cpu.registers.f[2] = false
        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x8e] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a,
            cpu.mmu:readByte(cpu:readTwoRegisters('h', 'l'))
            + ((cpu.registers.f[4]) and 1 or 0))

        cpu.registers.f[2] = false
        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x8f] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a, cpu.registers.a
            + ((cpu.registers.f[4]) and 1 or 0))

        cpu.registers.f[2] = false
        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x90] = function(cpu)
        cpu.registers.a = helper_sub(cpu, cpu.registers.a, cpu.registers.b)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x91] = function(cpu)
        cpu.registers.a = helper_sub(cpu, cpu.registers.a, cpu.registers.c)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x92] = function(cpu)
        cpu.registers.a = helper_sub(cpu, cpu.registers.a, cpu.registers.d)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x93] = function(cpu)
        cpu.registers.a = helper_sub(cpu, cpu.registers.a, cpu.registers.e)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x94] = function(cpu)
        cpu.registers.a = helper_sub(cpu, cpu.registers.a, cpu.registers.h)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x95] = function(cpu)
        cpu.registers.a = helper_sub(cpu, cpu.registers.a, cpu.registers.l)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x96] = function(cpu)
        cpu.registers.a = helper_sub(cpu, cpu.registers.a,
            cpu.mmu:readByte(cpu:readTwoRegisters('h', 'l')))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x97] = function(cpu)
        cpu.registers.a = helper_sub(cpu, cpu.registers.a, cpu.registers.a)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x98] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a,
            cpu.registers.b - ((cpu.registers.f[4]) and 1 or 0))

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x99] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a,
            cpu.registers.c - ((cpu.registers.f[4]) and 1 or 0))

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x9a] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a,
            cpu.registers.d - ((cpu.registers.f[4]) and 1 or 0))

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x9b] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a,
            cpu.registers.e - ((cpu.registers.f[4]) and 1 or 0))

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x9c] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a,
            cpu.registers.h - ((cpu.registers.f[4]) and 1 or 0))

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x9d] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a,
            cpu.registers.l - ((cpu.registers.f[4]) and 1 or 0))

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x9e] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a,
            cpu.mmu:readByte(cpu:readTwoRegisters('h', 'l'))
            - ((cpu.registers.f[4]) and 1 or 0))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x9f] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a,
            cpu.registers.a - ((cpu.registers.f[4]) and 1 or 0))

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xa0] = function(cpu)
        cpu.registers.a = helper_and(cpu, cpu.registers.a, cpu.registers.b)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xa1] = function(cpu)
        cpu.registers.a = helper_and(cpu, cpu.registers.a, cpu.registers.c)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xa2] = function(cpu)
        cpu.registers.a = helper_and(cpu, cpu.registers.a, cpu.registers.d)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xa3] = function(cpu)
        cpu.registers.a = helper_and(cpu, cpu.registers.a, cpu.registers.e)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xa4] = function(cpu)
        cpu.registers.a = helper_and(cpu, cpu.registers.a, cpu.registers.h)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xa5] = function(cpu)
        cpu.registers.a = helper_and(cpu, cpu.registers.a, cpu.registers.l)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xa6] = function(cpu)
        cpu.registers.a = helper_and(cpu, cpu.registers.a, cpu.mmu:readByte(
            cpu:readTwoRegisters('h', 'l'))
        )

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xa7] = function(cpu)
        cpu.registers.a = helper_and(cpu, cpu.registers.a, cpu.registers.a)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xa8] = function(cpu)
        cpu.registers.a = helper_xor(cpu, cpu.registers.a, cpu.registers.b)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xa9] = function(cpu)
        cpu.registers.a = helper_xor(cpu, cpu.registers.a, cpu.registers.c)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xaa] = function(cpu)
        cpu.registers.a = helper_xor(cpu, cpu.registers.a, cpu.registers.d)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xab] = function(cpu)
        cpu.registers.a = helper_xor(cpu, cpu.registers.a, cpu.registers.e)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xac] = function(cpu)
        cpu.registers.a = helper_xor(cpu, cpu.registers.a, cpu.registers.h)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xad] = function(cpu)
        cpu.registers.a = helper_xor(cpu, cpu.registers.a, cpu.registers.l)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xae] = function(cpu)
        cpu.registers.a = helper_xor(cpu, cpu.registers.a, cpu.mmu:readByte(
            cpu:readTwoRegisters('h', 'l'))
        )

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xaf] = function(cpu)
        cpu.registers.a = helper_xor(cpu, cpu.registers.a, cpu.registers.a)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xb0] = function(cpu)
        cpu.registers.a = helper_or(cpu, cpu.registers.a, cpu.registers.b)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xb1] = function(cpu)
        cpu.registers.a = helper_or(cpu, cpu.registers.a, cpu.registers.c)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xb2] = function(cpu)
        cpu.registers.a = helper_or(cpu, cpu.registers.a, cpu.registers.d)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xb3] = function(cpu)
        cpu.registers.a = helper_or(cpu, cpu.registers.a, cpu.registers.e)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xb4] = function(cpu)
        cpu.registers.a = helper_or(cpu, cpu.registers.a, cpu.registers.h)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xb5] = function(cpu)
        cpu.registers.a = helper_or(cpu, cpu.registers.a, cpu.registers.l)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xb6] = function(cpu)
        cpu.registers.a = helper_or(cpu, cpu.registers.a, cpu.mmu:readByte(
            cpu:readTwoRegisters('h', 'l'))
        )

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xb7] = function(cpu)
        cpu.registers.a = helper_or(cpu, cpu.registers.a, cpu.registers.a)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xb8] = function(cpu)
        helper_cp(cpu, cpu.registers.a, cpu.registers.b)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xb9] = function(cpu)
        helper_cp(cpu, cpu.registers.a, cpu.registers.c)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xba] = function(cpu)
        helper_cp(cpu, cpu.registers.a, cpu.registers.d)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xbb] = function(cpu)
        helper_cp(cpu, cpu.registers.a, cpu.registers.e)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xbc] = function(cpu)
        helper_cp(cpu, cpu.registers.a, cpu.registers.h)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xbd] = function(cpu)
        helper_cp(cpu, cpu.registers.a, cpu.registers.l)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xbe] = function(cpu)
        helper_cp(cpu, cpu.registers.a, cpu.mmu:readByte(
            cpu:readTwoRegisters('h', 'l'))
        )

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xbf] = function(cpu)
        helper_cp(cpu, cpu.registers.a, cpu.registers.a)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xc0] = function(cpu)
        if (not cpu.registers.f[1]) then
            cpu.registers.pc = cpu.mmu:popStack()
        end

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xc1] = function(cpu)
        cpu:writeTwoRegisters('b', 'c', cpu.mmu:popStack())

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0xc2] = function(cpu)
        if (not cpu.registers.f[1]) then
            cpu.registers.pc = cpu.mmu:readUInt16(cpu.registers.pc)
        else
            cpu.registers.pc = cpu.registers.pc + 2
        end

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0xc3] = function(cpu)
        cpu.registers.pc = cpu.mmu:readUInt16(cpu.registers.pc)

        cpu.registers.clock.m = 4
        cpu.registers.clock.t = 16
    end,
    [0xc4] = function(cpu)
        if (not cpu.registers.f[1]) then
            cpu.mmu:pushStack(cpu.registers.pc + 2)
            cpu.registers.pc = cpu.mmu:readUInt16(cpu.registers.pc)

            cpu.registers.clock.m = 6
            cpu.registers.clock.t = 24
        else
            cpu.registers.pc = cpu.registers.pc + 2

            cpu.registers.clock.m = 3
            cpu.registers.clock.t = 12
        end
    end,
    [0xc5] = function(cpu)
        cpu.mmu:pushStack(cpu:readTwoRegisters('b', 'c'))

        cpu.registers.clock.m = 4
        cpu.registers.clock.t = 16
    end,
    [0xc6] = function(cpu)
        cpu.registers.a = helper_add(cpu, cpu.registers.a,
            cpu.mmu:readByte(cpu.registers.pc))

        cpu.registers.f[2] = false
        cpu.registers.pc = cpu.registers.pc + 1
        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xc7] = function(cpu)
        cpu.mmu:pushStack(cpu.registers.pc)
        cpu.registers.pc = 0x0

        cpu.registers.clock.m = 8
        cpu.registers.clock.t = 32
    end,
    [0xc8] = function(cpu)
        if (cpu.registers.f[1]) then
            cpu.registers.pc = cpu.mmu:popStack()

            cpu.registers.clock.m = 5
            cpu.registers.clock.t = 20
        else
            cpu.registers.clock.m = 2
            cpu.registers.clock.t = 8
        end
    end,
    [0xc9] = function(cpu)
        cpu.registers.pc = cpu.mmu:popStack()

        cpu.registers.clock.m = 4
        cpu.registers.clock.t = 16
    end,
    [0xca] = function(cpu)
        if (cpu.registers.f[1]) then
            cpu.registers.pc = cpu.mmu:readUInt16(cpu.registers.pc)
        else
            cpu.registers.pc = cpu.registers.pc + 2
        end

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0xcb] = function(cpu)
        local opcode1 = cpu.mmu:readByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1

        if (not GameBoy.cbOpcodes[opcode1]) then
            cpu:pause()
            Log.error("CPU CB", "Unknown opcode: 0x%s at 0x%s", _string_format("%.2x", opcode1), _string_format("%.2x", cpu.registers.pc - 2))
            return
        end

        GameBoy.cbOpcodes[opcode1](cpu)
    end,
    [0xcc] = function(cpu)
        if (cpu.registers.f[1]) then
            cpu.mmu:pushStack(cpu.registers.pc)
            cpu.registers.pc = cpu.mmu:readUInt16(cpu.registers.pc)
        else
            cpu.registers.pc = cpu.registers.pc + 2
        end

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0xcd] = function(cpu)
        local value = cpu.mmu:readUInt16(cpu.registers.pc)

        cpu.mmu:pushStack(cpu.registers.pc + 2)
        cpu.registers.pc = value

        cpu.registers.clock.m = 6
        cpu.registers.clock.t = 24
    end,
    [0xce] = function(cpu)
        cpu.registers.a = helper_adc(cpu, cpu.registers.a,
            cpu.mmu:readByte(cpu.registers.pc))

        cpu.registers.pc = cpu.registers.pc + 1
        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xcf] = function(cpu)
        cpu.mmu:pushStack(cpu.registers.pc)
        cpu.registers.pc = 0x08

        cpu.registers.clock.m = 8
        cpu.registers.clock.t = 32
    end,
    [0xd1] = function(cpu)
        cpu:writeTwoRegisters('d', 'e', cpu.mmu:popStack())

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0xd0] = function(cpu)
        if (not cpu.registers.f[4]) then
            cpu.registers.pc = cpu.mmu:popStack()

            cpu.registers.clock.m = 5
            cpu.registers.clock.t = 20
        else
            cpu.registers.clock.m = 2
            cpu.registers.clock.t = 8
        end
    end,
    [0xd2] = function(cpu)
        if (not cpu.registers.f[4]) then
            cpu.registers.pc = cpu.mmu:readUInt16(cpu.registers.pc)
        else
            cpu.registers.pc = cpu.registers.pc + 2
        end

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0xd4] = function(cpu)
        if (not cpu.registers.f[4]) then
            cpu.mmu:pushStack(cpu.registers.pc)
            cpu.registers.pc = cpu.mmu:readUInt16(cpu.registers.pc)
        else
            cpu.registers.pc = cpu.registers.pc + 2
        end

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0xd5] = function(cpu)
        cpu.mmu:pushStack(cpu:readTwoRegisters('d', 'e'))

        cpu.registers.clock.m = 4
        cpu.registers.clock.t = 16
    end,
    [0xd6] = function(cpu)
        cpu.registers.a = helper_sub(cpu, cpu.registers.a, cpu.mmu:readByte(cpu.registers.pc))

        cpu.registers.pc = cpu.registers.pc + 1
        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xd7] = function(cpu)
        cpu.mmu:pushStack(cpu.registers.pc)
        cpu.registers.pc = 0x10

        cpu.registers.clock.m = 8
        cpu.registers.clock.t = 32
    end,
    [0xd8] = function(cpu)
        if (cpu.registers.f[4]) then
            cpu.registers.pc = cpu.mmu:popStack()
        end

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xd9] = function(cpu)
        cpu.registers.pc = cpu.mmu:popStack()
        cpu.interrupts = true

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xda] = function(cpu)
        if (cpu.registers.f[4]) then
            cpu.registers.pc = cpu.mmu:readUInt16(cpu.registers.pc)
        else
            cpu.registers.pc = cpu.registers.pc + 2
        end

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0xdb] = function(cpu) end,
    [0xdc] = function(cpu)
        if (cpu.registers.f[4]) then
            cpu.mmu:pushStack(cpu.registers.pc)
            cpu.registers.pc = cpu.mmu:readUInt16(cpu.registers.pc)
        else
            cpu.registers.pc = cpu.registers.pc + 2
        end

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0xdf] = function(cpu)
        cpu.mmu:pushStack(cpu.registers.pc)
        cpu.registers.pc = 0x18

        cpu.registers.clock.m = 8
        cpu.registers.clock.t = 32
    end,
    [0xe0] = function(cpu)
        cpu.mmu:writeByte(0xFF00 + cpu.mmu:readByte(cpu.registers.pc), cpu.registers.a)

        cpu.registers.pc = cpu.registers.pc + 1
        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0xe1] = function(cpu)
        cpu:writeTwoRegisters('h', 'l', cpu.mmu:popStack())

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0xe2] = function(cpu)
        cpu.mmu:writeByte(0xFF00 + cpu.registers.c, cpu.registers.a)

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xe3] = function(cpu) end,
    [0xe4] = function(cpu) end,
    [0xe5] = function(cpu)
        cpu.mmu:pushStack(cpu:readTwoRegisters('h', 'l'))

        cpu.registers.clock.m = 4
        cpu.registers.clock.t = 16
    end,
    [0xe6] = function(cpu)
        cpu.registers.a = helper_and(cpu, cpu.registers.a, cpu.mmu:readByte(cpu.registers.pc))

        cpu.registers.pc = cpu.registers.pc + 1
        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xe7] = function(cpu)
        cpu.mmu:pushStack(cpu.registers.pc)
        cpu.registers.pc = 0x20

        cpu.registers.clock.m = 8
        cpu.registers.clock.t = 32
    end,
    [0xe8] = function(cpu)
        cpu.registers.sp = helper_add_sp(cpu, cpu.registers.sp,
            cpu.mmu:readByte(cpu.registers.pc))

        cpu.registers.pc = cpu.registers.pc + 1
        cpu.registers.clock.m = 4
        cpu.registers.clock.t = 16
    end,
    [0xe9] = function(cpu)
        cpu.registers.pc = cpu:readTwoRegisters('h', 'l')

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xea] = function(cpu)
        cpu.mmu:writeByte(cpu.mmu:readUInt16(cpu.registers.pc), cpu.registers.a)

        cpu.registers.pc = cpu.registers.pc + 2
        cpu.registers.clock.m = 4
        cpu.registers.clock.t = 16
    end,
    [0xee] = function(cpu)
        cpu.registers.a = helper_xor(cpu, cpu.registers.a, cpu.mmu:readByte(cpu.registers.pc))

        cpu.registers.pc = cpu.registers.pc + 1
        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xef] = function(cpu)
        cpu.mmu:pushStack(cpu.registers.pc)
        cpu.registers.pc = 0x28

        cpu.registers.clock.m = 8
        cpu.registers.clock.t = 32
    end,
    [0xf0] = function(cpu)
        cpu.registers.a = cpu.mmu:readByte(0xFF00 + cpu.mmu:readByte(cpu.registers.pc))

        cpu.registers.pc = cpu.registers.pc + 1
        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0xf1] = function(cpu)
        cpu:writeTwoRegisters('a', 'f', cpu.mmu:popStack())

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0xf2] = function(cpu)
        cpu.registers.a = cpu.mmu:readByte(0xFF00 + cpu.registers.c)

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xf3] = function(cpu)
        cpu:disableInterrupts()

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xf5] = function(cpu)
        cpu.mmu:pushStack(cpu:readTwoRegisters('a', 'f'))

        cpu.registers.clock.m = 4
        cpu.registers.clock.t = 16
    end,
    [0xf6] = function(cpu)
        cpu.registers.a = helper_or(cpu, cpu.registers.a, cpu.mmu:readByte(cpu.registers.pc))

        cpu.registers.pc = cpu.registers.pc + 1
        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xf7] = function(cpu)
        cpu.mmu:pushStack(cpu.registers.pc)
        cpu.registers.pc = 0x30

        cpu.registers.clock.m = 8
        cpu.registers.clock.t = 32
    end,
    [0xf8] = function(cpu)
        local address = cpu.registers.sp
        local value = cpu.mmu:readByte(cpu.registers.pc)

        cpu:writeTwoRegisters('h', 'l', helper_add_sp(cpu, address, value))

        cpu.registers.pc = cpu.registers.pc + 1
        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0xf9] = function(cpu)
        cpu.registers.sp = cpu:readTwoRegisters('h', 'l')

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xfa] = function(cpu)
        cpu.registers.a = cpu.mmu:readByte(cpu.mmu:readUInt16(cpu.registers.pc))

        cpu.registers.pc = cpu.registers.pc + 2
        cpu.registers.clock.m = 4
        cpu.registers.clock.t = 16
    end,
    [0xfb] = function(cpu)
        cpu:enableInterrupts()

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xfe] = function(cpu)
        helper_cp(cpu, cpu.registers.a, cpu.mmu:readByte(cpu.registers.pc))

        cpu.registers.pc = cpu.registers.pc + 1
        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xff] = function(cpu)
        cpu.mmu:pushStack(cpu.registers.pc)
        cpu.registers.pc = 0x38

        cpu.registers.clock.m = 8
        cpu.registers.clock.t = 32
    end,
}
