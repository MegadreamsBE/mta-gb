-----------------------------------
-- * Locals & Constants
-----------------------------------

local _bitOr = bitOr
local _bitAnd = bitAnd
local _bitXor = bitXor
local _bitReplace = bitReplace
local _bitTest = bitTest
local _math_abs = math.abs
local _math_floor = math.floor
local _math_log = math.log
local _string_format = string.format

local _or = function(cpu, value, against)
    against = against or cpu.registers.a

    value = _bitOr(against, value)

    cpu.registers.f[1] = (cpu.registers.a == 0) -- FLAG_ZERO

    return value
end

local _xor = function(cpu, value, xor)
    xor = xor or cpu.registers.a

    value = _bitXor(xor, value)

    cpu.registers.f[1] = (cpu.registers.a == 0) -- FLAG_ZERO

    return value
end

local _add = function(cpu, value, add)
    cpu.registers.f[3] = (_bitAnd((_bitAnd(value, 0x0f) + _bitAnd(add, 0x0f)), 0x10) ~= 0) -- FLAG_HALFCARRY
    cpu.registers.f[4] = (value > _bitAnd((value + add), 0xff)) -- FLAG_CARRY

    value = (value + add) % 0x100
    --value = (dual) and value % 0x10000 or value % 0x100

    cpu.registers.f[1] = (value == 0) -- FLAG_ZERO
    cpu.registers.f[2] = false -- FLAG_SUBSTRACT

    return value
end

local _add16 = function(cpu, value, add)
    cpu.registers.f[3] = (_bitAnd((_bitAnd(value, 0x0f00) + _bitAnd(add, 0x0f00)), 0x1000) ~= 0) -- FLAG_HALFCARRY
    cpu.registers.f[4] = (value > _bitAnd((value + add), 0xff00)) -- FLAG_CARRY

    value = (value + add) % 0x10000
    --value = (dual) and value % 0x10000 or value % 0x100

    cpu.registers.f[1] = (value == 0) -- FLAG_ZERO
    cpu.registers.f[2] = false -- FLAG_SUBSTRACT

    return value
end

local _sub = function(cpu, value, sub)
    cpu.registers.f[3] = (_bitAnd(_math_abs(sub), 0x0f) > (_bitAnd(value, 0x0f))) -- FLAG_HALFCARRY
    cpu.registers.f[4] = (_math_abs(sub) > value) -- FLAG_CARRY

    value = (value - sub) % 0x100

    cpu.registers.f[1] = (value == 0) -- FLAG_ZERO
    cpu.registers.f[2] = true -- FLAG_SUBSTRACT

    return value
end

local _sub16 = function(cpu, value, sub)
    cpu.registers.f[3] = (_bitAnd(_math_abs(sub), 0x0f00) > (_bitAnd(value, 0x0f00))) -- FLAG_HALFCARRY
    cpu.registers.f[4] = (_math_abs(sub) > value) -- FLAG_CARRY

    value = (value - sub) % 0x10000

    cpu.registers.f[1] = (value == 0) -- FLAG_ZERO
    cpu.registers.f[2] = true -- FLAG_SUBSTRACT

    return value
end

local _inc = function(cpu, value)
    cpu.registers.f[3] = (((value / (2 ^ 3)) % 2) >= 1) -- FLAG_HALFCARRY
    cpu.registers.f[4] = (((value / (2 ^ 7)) % 2) >= 1) -- FLAG_CARRY

    value = (value + 1) % 0x100

    cpu.registers.f[3] = (_bitAnd(value, 0xf) == 0) -- FLAG_HALFCARRY
    cpu.registers.f[1] = (value == 0) -- FLAG_ZERO
    cpu.registers.f[2] = false -- FLAG_SUBSTRACT

    return value
end

local _inc16 = function(cpu, value, isSP)
    if (isSP) then
        cpu.registers.f[3] = (((value / (2 ^ 3)) % 2) >= 1) -- FLAG_HALFCARRY
        cpu.registers.f[4] = (((value / (2 ^ 7)) % 2) >= 1) -- FLAG_CARRY
    else
        cpu.registers.f[3] = (((value / (2 ^ 11)) % 2) >= 1) -- FLAG_HALFCARRY
        cpu.registers.f[4] = (((value / (2 ^ 15)) % 2) >= 1) -- FLAG_CARRY
    end

    value = (value + 1) % 0x10000

    cpu.registers.f[1] = (value == 0) -- FLAG_ZERO
    cpu.registers.f[2] = false -- FLAG_SUBSTRACT

    return value
end

local _dec = function(cpu, value)
    value = (value - 1) % 0x100

    cpu.registers.f[3] = (_bitAnd(value, 0xf) == 0xf) -- FLAG_HALFCARRY
    cpu.registers.f[1] = (value == 0) -- FLAG_ZERO
    cpu.registers.f[2] = true -- FLAG_SUBSTRACT

    return value
end

local _dec16 = function(cpu, value, isSP)
    if (isSP) then
        cpu.registers.f[3] = (((value / (2 ^ 4)) % 2) >= 1) -- FLAG_HALFCARRY
        cpu.registers.f[4] = ((value % 2) >= 1) -- FLAG_CARRY
    else
        cpu.registers.f[3] = (((value / (2 ^ 4)) % 2) >= 1) -- FLAG_HALFCARRY
        cpu.registers.f[4] = ((value % 2) >= 1) -- FLAG_CARRY
    end

    value = (value - 1) % 0x10000

    cpu.registers.f[1] = (value == 0) -- FLAG_ZERO
    cpu.registers.f[2] = true -- FLAG_SUBSTRACT

    return value
end

local _leftRotate = function(cpu, value, positions)
    cpu.registers.f[4] = (((value / (2 ^ 7)) % 2) > 1)  -- FLAG_CARRY

    for i=1, positions do
        local bits = _math_floor(_math_log(value) / _math_log(2)) + 1

        if (bits == 0 or value == 0) then
            break
        end

        if (bits % 8 == 0) then
            local bit = ((value / (2 ^ (bits - 1))) % 2 >= 1) and 1 or 0
            value = value * 2
            value = _bitReplace(value, 0, bits, 1)
            value = _bitReplace(value, bit, 0, 1)
        else
            value = value * 2
            value = _bitReplace(value, 0, 0, 1)
        end
    end

    cpu.registers.f[1] = (value == 0) -- FLAG_ZERO
    cpu.registers.f[2] = false -- FLAG_SUBSTRACT
    cpu.registers.f[3] = false -- FLAG_HALFCARRY

    return value
end

local _rightRotate = function(cpu, value, positions)
    cpu.registers.f[4] = (((value / (2 ^ 0)) % 2) > 1)  -- FLAG_CARRY

    for i=1, positions do
        local bits = _math_floor(_math_log(value) / _math_log(2)) + 1

        if (bits == 0 or value == 0) then
            break
        end

        local bit = ((value / (2 ^ 0)) % 2 >= 1) and 1 or 0
        value = value / 2
        value = _bitReplace(value, bit, bits, 1)
    end

    cpu.registers.f[1] = (value == 0) -- FLAG_ZERO
    cpu.registers.f[2] = false -- FLAG_SUBSTRACT
    cpu.registers.f[3] = false -- FLAG_HALFCARRY

    return value
end

local _leftShift = function(cpu, value, positions)
    cpu.registers.f[4] = (((value / (2 ^ 7)) % 2) > 1)  -- FLAG_CARRY

    for i=1, positions do
        local bits = _math_floor(_math_log(value) / _math_log(2)) + 1

        if (bits == 0 or value == 0) then
            break
        end

        if (bits % 8 == 0) then
            local bit = ((value / (2 ^ (bits - 1))) % 2 >= 1) and 1 or 0
            value = value * 2
            value = _bitReplace(value, 0, bits, 1)
            value = _bitReplace(value, 0, 0, 1)
        else
            value = value * 2
            value = _bitReplace(value, 0, 0, 1)
        end
    end

    cpu.registers.f[1] = (value == 0) -- FLAG_ZERO
    cpu.registers.f[2] = false -- FLAG_SUBSTRACT
    cpu.registers.f[3] = false -- FLAG_HALFCARRY

    return value
end

local _rightShift = function(cpu, value, positions)
    cpu.registers.f[4] = (((value / (2 ^ 7)) % 2) > 1)  -- FLAG_CARRY

    for i=1, positions do
        local bits = _math_floor(_math_log(value) / _math_log(2)) + 1

        if (bits == 0 or value == 0) then
            break
        end

        local bit = ((value / (2 ^ (bits - 1))) % 2 >= 1) and 1 or 0
        value = value / 2
        value = _bitReplace(value, 0, bits - 1, 1)
    end

    cpu.registers.f[1] = (value == 0) -- FLAG_ZERO
    cpu.registers.f[2] = false -- FLAG_SUBSTRACT
    cpu.registers.f[3] = false -- FLAG_HALFCARRY

    return value
end

GameBoy.cbOpcodes = {
    [0x11] = function(cpu)
        cpu.registers.c = _leftRotate(cpu, cpu.registers.c, 1)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x17] = function(cpu)
        cpu.registers.a = _leftRotate(cpu, cpu.registers.a, 1)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x1a] = function(cpu)
        cpu.registers.d = _rightRotate(cpu, cpu.registers.d, 1)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x1f] = function(cpu)
        cpu.registers.a = _rightRotate(cpu, cpu.registers.a, 1)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x20] = function(cpu)
        local bitSet = (((cpu.registers.b / (2 ^ 7)) % 2) >= 1)
        cpu.registers.b = cpu.registers.b * 2

        cpu.registers.f[1] = (cpu.registers.b == 0) -- FLAG_ZERO
        cpu.registers.f[2] = false -- FLAG_SUBSTRACT
        cpu.registers.f[3] = false -- FLAG_HALFCARRY
        cpu.registers.f[4] = bitSet -- FLAG_CARRY

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x38] = function(cpu)
        cpu.registers.b = _rightShift(cpu, cpu.registers.b, 1)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x3f] = function(cpu)
        cpu.registers.a = _rightShift(cpu, cpu.registers.a, 1)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x7c] = function(cpu)
        cpu.registers.f[1] = (0 - (((cpu.registers.h / (2 ^ 7)) % 2 >= 1) and 1 or 0) == 0) -- FLAG_ZERO
        cpu.registers.f[2] = false -- FLAG_SUBSTRACT
        cpu.registers.f[3] = true -- FLAG_HALFCARRY

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0xcb] = function(cpu)
        cpu.registers.e = _bitReplace(cpu.registers.e, 1, 1, 1)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
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
        cpu:writeTwoRegisters('b', 'c', _inc16(cpu, cpu:readTwoRegisters('b', 'c')))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x04] = function(cpu)
        cpu.registers.b = _inc(cpu, cpu.registers.b)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x05] = function(cpu)
        cpu.registers.b = _dec(cpu, cpu.registers.b)

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
        cpu.registers.a = _leftRotate(cpu, cpu.registers.a, 1)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x08] = function(cpu)
        local address = cpu.mmu:readUInt16(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 2

        cpu.mmu:writeShort(address, cpu.registers.sp)

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0x09] = function(cpu)
        cpu:writeTwoRegisters('h', 'l',
            _add16(cpu, cpu:readTwoRegisters('h', 'l'), cpu:readTwoRegisters('b', 'c'))
        )

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x0a] = function(cpu)
        cpu.registers.a = cpu.mmu:readByte(cpu:readTwoRegisters('b', 'c'))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x0b] = function(cpu)
        cpu:writeTwoRegisters('b', 'c',
            _dec16(cpu, cpu:readTwoRegisters('b', 'c'), false))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x0c] = function(cpu)
        cpu.registers.c = _inc(cpu, cpu.registers.c)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x0d] = function(cpu)
        cpu.registers.c = _dec(cpu, cpu.registers.c)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x0e] = function(cpu)
        cpu.registers.c = cpu.mmu:readByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
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
        local value = cpu:readTwoRegisters('d', 'e')
        cpu:writeTwoRegisters('d', 'e', _inc16(cpu, value, false))

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 8
    end,
    [0x15] = function(cpu)
        cpu.registers.d = _dec(cpu, cpu.registers.d)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x16] = function(cpu)
        cpu.registers.d = cpu.mmu:readByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x18] = function(cpu)
        local offset = cpu.mmu:readSignedByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1 + offset

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 12
    end,
    [0x19] = function(cpu)
        cpu:writeTwoRegisters('h', 'l',
            _add16(cpu, cpu:readTwoRegisters('h', 'l'), cpu:readTwoRegisters('d', 'e'))
        )

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x1a] = function(cpu)
        local address = cpu:readTwoRegisters('d', 'e')
        cpu.registers.a = cpu.mmu:readByte(address)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 8
    end,
    [0x1d] = function(cpu)
        cpu.registers.e = _dec(cpu, cpu.registers.e)

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
        cpu.registers.a = _rightRotate(cpu, cpu.registers.a, 1)
        cpu.registers.f[4] = false

        cpu.registers.clock.m = cpu.registers.clock.m + 1
        cpu.registers.clock.t = cpu.registers.clock.t + 4
    end,
    [0x20] = function(cpu)
        local offset = cpu.mmu:readSignedByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1

        if (cpu.registers.f[1]) then -- FLAG_ZERO
            cpu.registers.clock.m = 2
            cpu.registers.clock.t = 8
        else
            cpu.registers.pc = cpu.registers.pc + offset

            cpu.registers.clock.m = 3
            cpu.registers.clock.t = 12
        end
    end,
    [0x21] = function(cpu)
        cpu:writeTwoRegisters('h', 'l', cpu.mmu:readUInt16(cpu.registers.pc))
        cpu.registers.pc = cpu.registers.pc + 2

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0x22] = function(cpu)
        local value = cpu.registers.a
        local address = cpu:readTwoRegisters('h', 'l')

        cpu.mmu:writeByte(address, value)
        cpu:writeTwoRegisters('h', 'l', _inc16(cpu, address, false))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x23] = function(cpu)
        local address = cpu:readTwoRegisters('h', 'l')
        cpu:writeTwoRegisters('h', 'l', _inc16(cpu, address, false))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x24] = function(cpu)
        cpu.registers.h = _inc(cpu, cpu.registers.h)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x25] = function(cpu)
        cpu.registers.h = _dec(cpu, cpu.registers.h)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x26] = function(cpu)
        cpu.registers.h = cpu.mmu:readByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x28] = function(cpu)
        local offset = cpu.mmu:readSignedByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1

        if (cpu.registers.f[1]) then -- FLAG_ZERO
            cpu.registers.clock.m = 2
            cpu.registers.clock.t = 8
        else
            cpu.registers.pc = cpu.registers.pc + offset
            cpu.registers.clock.m = 3
            cpu.registers.clock.t = 12
        end
    end,
    [0x29] = function(cpu)
        cpu:writeTwoRegisters('h', 'l',
            _add16(cpu, cpu:readTwoRegisters('h', 'l'), cpu:readTwoRegisters('h', 'l'))
        )

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x2a] = function(cpu)
        local address = cpu:readTwoRegisters('h', 'l')
        local value = cpu.mmu:readByte(address)

        cpu.registers.a = value

        cpu:writeTwoRegisters('h', 'l', _inc16(cpu, address, false))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x2c] = function(cpu)
        cpu.registers.l = _inc(cpu, cpu.registers.l)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x2d] = function(cpu)
        cpu.registers.l = _dec(cpu, cpu.registers.l)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x2e] = function(cpu)
        cpu.registers.l = cpu.mmu:readByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x30] = function(cpu)
        local offset = cpu.mmu:readSignedByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1

        if (cpu.registers.f[4]) then -- FLAG_CARRY
            cpu.registers.clock.m = 2
            cpu.registers.clock.t = 8
        else
            cpu.registers.pc = cpu.registers.pc + offset

            cpu.registers.clock.m = 3
            cpu.registers.clock.t = 12
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

        cpu:writeTwoRegisters('h', 'l', _dec16(cpu, address, false))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x35] = function(cpu)
        local address = cpu:readTwoRegisters('h', 'l')
        cpu.mmu:writeByte(address, _dec(cpu, cpu.mmu:readByte(address)))

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0x36] = function(cpu)
        local address = cpu:readTwoRegisters('h', 'l')
        local value = cpu.mmu:readByte(cpu.registers.pc)

        cpu.mmu:writeByte(address, value)

        cpu.registers.pc = cpu.registers.pc + 1

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0x3a] = function(cpu)
        local address = cpu:readTwoRegisters('h', 'l')
        cpu.registers.a = cpu.mmu:readByte(address)

        cpu:writeTwoRegisters('h', 'h', _dec16(cpu, address, false))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x3c] = function(cpu)
        cpu.registers.a = _inc(cpu, cpu.registers.a)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x3d] = function(cpu)
        cpu.registers.a = _dec(cpu, cpu.registers.a)

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
        cpu.registers.f[4] = false -- FLAG_CARRY

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
    [0x77] = function(cpu)
        local address = cpu:readTwoRegisters('h', 'l')
        cpu.mmu:writeByte(address, cpu.registers.a)

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
    [0x86] = function(cpu)
        cpu.registers.a = _add(cpu, cpu.registers.a,
            cpu.mmu:readByte(cpu:readTwoRegisters('h', 'l')))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x90] = function(cpu)
        cpu.registers.a = _sub(cpu, cpu.registers.a, cpu.registers.b)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xa9] = function(cpu)
        cpu.registers.a = _xor(cpu, cpu.registers.c)

        cpu.registers.f[1] = (cpu.registers.a == 0) -- FLAG_ZERO
        cpu.registers.f[2] = false -- FLAG_SUBSTRACT
        cpu.registers.f[3] = false -- FLAG_CARRY
        cpu.registers.f[4] = false -- FLAG_HALFCARRY

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xae] = function(cpu)
        local address = cpu:readTwoRegisters('h', 'l')
        cpu.registers.a = _xor(cpu, cpu.mmu:readByte(address))

        cpu.registers.f[1] = (cpu.registers.a == 0) -- FLAG_ZERO
        cpu.registers.f[2] = false -- FLAG_SUBSTRACT
        cpu.registers.f[3] = false -- FLAG_CARRY
        cpu.registers.f[4] = false -- FLAG_HALFCARRY

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xaf] = function(cpu)
        cpu.registers.a = _xor(cpu, cpu.registers.a)

        cpu.registers.f[1] = (cpu.registers.a == 0) -- FLAG_ZERO
        cpu.registers.f[2] = false -- FLAG_SUBSTRACT
        cpu.registers.f[3] = false -- FLAG_CARRY
        cpu.registers.f[4] = false -- FLAG_HALFCARRY

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xb0] = function(cpu)
        cpu.registers.a = _or(cpu, cpu.registers.b)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xb1] = function(cpu)
        cpu.registers.a = _bitOr(cpu.registers.a, cpu.registers.c)

        cpu.registers.f[1] = (cpu.registers.a == 0) -- FLAG_ZERO
        cpu.registers.f[2] = false -- FLAG_SUBSTRACT
        cpu.registers.f[3] = false -- FLAG_CARRY
        cpu.registers.f[4] = false -- FLAG_HALFCARRY

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xb6] = function(cpu)
        cpu.registers.a = _or(cpu, cpu.mmu:readByte(cpu:readTwoRegisters('h', 'l')))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xb7] = function(cpu)
        cpu.registers.a = _or(cpu, cpu.registers.a)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xbe] = function(cpu)
        local address = cpu:readTwoRegisters('h', 'l')
        local value = cpu.mmu:readByte(address)

        cpu.registers.f[1] = ((cpu.registers.a - value) == 0) -- FLAG_ZERO
        cpu.registers.f[2] = false -- FLAG_SUBSTRACT

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xc0] = function(cpu)
        if (not cpu.registers.f[1]) then -- FLAG_ZERO
            local address = cpu.mmu:popStack()
            cpu.registers.pc = address
        end

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xc1] = function(cpu)
        cpu:writeTwoRegisters('b', 'c', cpu.mmu:popStack())

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0xc3] = function(cpu)
        cpu.registers.pc = cpu.mmu:readUInt16(cpu.registers.pc)

        cpu.registers.clock.m = 4
        cpu.registers.clock.t = 16
    end,
    [0xc4] = function(cpu)
        local address = cpu.mmu:readUInt16(cpu.registers.pc)

        if (cpu.registers.f[1]) then -- FLAG_ZERO
            cpu.mmu:pushStack(cpu.registers.pc + 2)
            cpu.registers.pc = address

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
        cpu.registers.a = _add(cpu, cpu.registers.a, cpu.mmu:readByte(cpu.registers.pc))
        cpu.registers.pc = cpu.registers.pc + 1

        cpu.registers.f[1] = (cpu.registers.a == 0) -- FLAG_ZERO
        cpu.registers.f[2] = false -- FLAG_SUBSTRACT

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xc8] = function(cpu)
        if (cpu.registers.f[1]) then -- FLAG_ZERO
            local address = cpu.mmu:popStack()
            cpu.registers.pc = address
        end

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xc9] = function(cpu)
        local address = cpu.mmu:popStack()
        cpu.registers.pc = address

        cpu.registers.clock.m = 4
        cpu.registers.clock.t = 16
    end,
    [0xcb] = function(cpu)
        local opcode1 = cpu.mmu:readByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1

        local opcode2 = cpu.mmu:readByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4

        if (not GameBoy.cbOpcodes[opcode1]) then
            cpu:pause()
            Log.error("CPU CB", "Unknown opcode: 0x%s at 0x%s", _string_format("%.2x", opcode1), _string_format("%.2x", cpu.registers.pc - 2))
            return
        end

        if (not GameBoy.cbOpcodes[opcode2]) then
            cpu:pause()
            Log.error("CPU CB", "Unknown opcode: 0x%s at 0x%s", _string_format("%.2x", opcode2), _string_format("%.2x", cpu.registers.pc - 1))
            return
        end

        GameBoy.cbOpcodes[opcode1](cpu)
        GameBoy.cbOpcodes[opcode2](cpu)
    end,
    [0xcd] = function(cpu)
        local value = cpu.mmu:readUInt16(cpu.registers.pc)
        cpu.mmu:pushStack(cpu.registers.pc + 2)
        cpu.registers.pc = value

        cpu.registers.clock.m = 6
        cpu.registers.clock.t = 24
    end,
    [0xce] = function(cpu)
        local value = cpu.mmu:readByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1

        local carryFlag = cpu.registers.f[4]
        cpu.registers.a = _add(cpu, cpu.registers.a, value + ((carryFlag == 1) and 1 or 0))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xd0] = function(cpu)
        if (not cpu.registers.f[4]) then -- FLAG_CARRY
            local address = cpu.mmu:popStack()
            cpu.registers.pc = address
        end

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xd1] = function(cpu)
        cpu:writeTwoRegisters('d', 'e', cpu.mmu:popStack())

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0xd5] = function(cpu)
        cpu.mmu:pushStack(cpu:readTwoRegisters('d', 'e'))

        cpu.registers.clock.m = 4
        cpu.registers.clock.t = 16
    end,
    [0xd6] = function(cpu)
        cpu.registers.a = _sub(cpu, cpu.registers.a,
            cpu.mmu:readByte(cpu.registers.pc))

        cpu.registers.pc = cpu.registers.pc + 1

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xd8] = function(cpu)
        if (cpu.registers.f[4]) then -- FLAG_CARRY
            local address = cpu.mmu:popStack()
            cpu.registers.pc = address
        end

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xe0] = function(cpu)
        cpu.mmu:writeByte(0xff00 + cpu.mmu:readByte(cpu.registers.pc), cpu.registers.a)
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
        cpu.mmu:writeByte(0xff00 + cpu.registers.c, cpu.registers.a)

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xe5] = function(cpu)
        cpu.mmu:pushStack(cpu:readTwoRegisters('h', 'l'))

        cpu.registers.clock.m = 4
        cpu.registers.clock.t = 16
    end,
    [0xe6] = function(cpu)
        cpu.registers.a = _bitAnd(cpu.registers.a, cpu.mmu:readByte(cpu.registers.pc))
        cpu.registers.pc = cpu.registers.pc + 1

        cpu.registers.f[1] = (cpu.registers.a == 0) -- FLAG_ZERO
        cpu.registers.f[2] = false -- FLAG_SUBSTRACT
        cpu.registers.f[3] = false -- FLAG_CARRY
        cpu.registers.f[4] = true -- FLAG_HALFCARRY

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xe9] = function(cpu)
        cpu.registers.pc = cpu:readTwoRegisters('h', 'l')

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xea] = function(cpu)
        local address = cpu.mmu:readUInt16(cpu.registers.pc)
        cpu.mmu:writeByte(address, cpu.registers.a)
        cpu.registers.pc = cpu.registers.pc + 2

        cpu.registers.clock.m = 4
        cpu.registers.clock.t = 16
    end,
    [0xee] = function(cpu)
        cpu.registers.a = _xor(cpu, cpu.mmu:readByte(cpu.registers.pc))
        cpu.registers.pc = cpu.registers.pc + 1

        cpu.registers.f[1] = (cpu.registers.a == 0) -- FLAG_ZERO
        cpu.registers.f[2] = false -- FLAG_SUBSTRACT
        cpu.registers.f[3] = false -- FLAG_CARRY
        cpu.registers.f[4] = false -- FLAG_HALFCARRY

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xf0] = function(cpu)
        local offset = cpu.mmu:readSignedByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1
        cpu.registers.a = cpu.mmu:readByte(0xFF00 + offset)

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0xf1] = function(cpu)
        cpu:writeTwoRegisters('a', 'f', cpu.mmu:popStack())

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0xf2] = function(cpu)
        cpu.registers.a = cpu.mmu:readByte(0xff00 + cpu.registers.c)

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xf3] = function(cpu)
        cpu.interrupts = false

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xf5] = function(cpu)
        cpu.mmu:pushStack(cpu:readTwoRegisters('a', 'f'))

        cpu.registers.clock.m = 4
        cpu.registers.clock.t = 16
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
        cpu.interrupts = true

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xfe] = function(cpu)
        cpu.registers.f[1] =
            (cpu.registers.a - cpu.mmu:readByte(cpu.registers.pc) == 0) -- FLAG_ZERO

        cpu.registers.pc = cpu.registers.pc + 1

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
}
