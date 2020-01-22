-----------------------------------
-- * Locals & Constants
-----------------------------------

local _bitOr = bitOr
local _bitAnd = bitAnd
local _bitXor = bitXor
local _bitReplace = bitReplace
local _bitLShift = bitLShift
local _bitRShift = bitRShift
local _bitTest = bitTest
local _math_abs = math.abs
local _math_floor = math.floor
local _math_log = math.log
local _string_format = string.format

local FLAGS_ZERO = bitLShift(1, 7)
local FLAGS_NEGATIVE = bitLShift(1, 6)
local FLAGS_HALFCARRY = bitLShift(1, 5)
local FLAGS_CARRY = bitLShift(1, 4)

local _or = function(cpu, value, against)
    against = against or cpu.registers.a

    value = _bitOr(against, value)

    if (cpu.registers.a ~= 0) then
        cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_ZERO))
    else
        cpu.registers.f = _bitOr(cpu.registers.f, FLAGS_ZERO)
    end

    cpu.registers.f= _bitAnd(cpu.registers.f, _bitOr(_bitOr(FLAGS_ZERO, FLAGS_NEGATIVE), FLAGS_HALFCARRY))

    return value
end

local _xor = function(cpu, value, xor)
    xor = xor or cpu.registers.a

    value = _bitXor(xor, value)

    if (cpu.registers.a ~= 0) then
        cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_ZERO))
    else
        cpu.registers.f = _bitOr(cpu.registers.f, FLAGS_ZERO)
    end

    cpu.registers.f= _bitAnd(cpu.registers.f, _bitOr(_bitOr(FLAGS_ZERO, FLAGS_NEGATIVE), FLAGS_HALFCARRY))

    return value
end

local _add = function(cpu, value, add, dual)
    if (_bitAnd(value, 0x0f) == 0x0f) then
        cpu.registers.f= _bitOr(cpu.registers.f, FLAGS_HALFCARRY)
    else
        cpu.registers.f= _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_HALFCARRY))
    end

    value = value + add
    value = (dual) and value % 0x10000 or value % 0x100

    if (value ~= 0) then
        cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_ZERO))
    else
        cpu.registers.f = _bitOr(cpu.registers.f, FLAGS_ZERO)
    end

    if (value < 0) then
        cpu.registers.f = _bitOr(cpu.registers.f, FLAGS_NEGATIVE)
    else
        cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_NEGATIVE))
    end

    return value
end

local _sub = function(cpu, value, sub, dual)
    if (_bitAnd(value, 0x0f) == 0x0f) then
        cpu.registers.f= _bitOr(cpu.registers.f, FLAGS_HALFCARRY)
    else
        cpu.registers.f= _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_HALFCARRY))
    end

    value = value - sub
    value = (dual) and value % 0x10000 or value % 0x100

    if (value ~= 0) then
        cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_ZERO))
    else
        cpu.registers.f = _bitOr(cpu.registers.f, FLAGS_ZERO)
    end

    if (value < 0) then
        cpu.registers.f = _bitOr(cpu.registers.f, FLAGS_NEGATIVE)
    else
        cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_NEGATIVE))
    end

    return value
end

local _inc = function(cpu, value, dual)
    if (_bitAnd(value, 0x0f) == 0x0f) then
        cpu.registers.f= _bitOr(cpu.registers.f, FLAGS_HALFCARRY)
    else
        cpu.registers.f= _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_HALFCARRY))
    end

    value = value + 1
    value = (dual) and value % 0x10000 or value % 0x100

    if (value ~= 0) then
        cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_ZERO))
    else
        cpu.registers.f = _bitOr(cpu.registers.f, FLAGS_ZERO)
    end

    if (value < 0) then
        cpu.registers.f = _bitOr(cpu.registers.f, FLAGS_NEGATIVE)
    else
        cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_NEGATIVE))
    end

    return value
end

local _dec = function(cpu, value, dual)
    cpu.registers.f= _bitOr(cpu.registers.f, FLAGS_HALFCARRY)

    value = value - 1
    value = (dual) and value % 0x10000 or value % 0x100

    if (value < 0) then
        value = 0xFF - (_math_abs(value) - 1)
        cpu.registers.f = _bitOr(cpu.registers.f, FLAGS_NEGATIVE)
    else
        cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_NEGATIVE))
    end

    if (value ~= 0) then
        cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_ZERO))
    else
        cpu.registers.f = _bitOr(cpu.registers.f, FLAGS_ZERO)
    end

    return value
end

local _leftRotate = function(value, positions)
    for i=1, positions do
        local bits = _math_floor(_math_log(value) / _math_log(2)) + 1

        if (bits % 8 == 0) then
            local bit = ((value / (2 ^ (bits - 1))) % 2 >= 1) and 1 or 0
            value = _bitLShift(value, 1)
            value = _bitReplace(value, 0, bits, 1)
            value = _bitReplace(value, bit, 0, 1)
        else
            value = _bitLShift(value, 1)
            value = _bitReplace(value, 0, 0, 1)
        end
    end

    return value
end

local readTwoRegisters = function(cpu, r1, r2)
    local value = cpu.registers[r1]
    value = value * 0xFF + value
    value = value + cpu.registers[r2]

    return value
end

local writeTwoRegisters = function(cpu, r1, r2, value)
    cpu.registers[r1] = _bitRShift(_bitAnd(0xFF00, value), 8)
    cpu.registers[r2] = _bitAnd(0x00FF, value)
end

GameBoy.cbOpcodes = {
    [0x11] = function(cpu)
        cpu.registers.c = _leftRotate(cpu.registers.c, 1)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x17] = function(cpu)
        cpu.registers.a = _leftRotate(cpu.registers.a, 1)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x20] = function(cpu)
        local tmp = (_bitAnd(cpu.registers.b, 0x80) and 0x10 or 0)
        cpu.registers.b = _bitAnd(_bitLShift(cpu.registers.b, 1), 255)
        cpu.registers.f = ((cpu.registers.b) and 0 or 0x80)
        cpu.registers.f = _bitAnd(cpu.registers.f, 0xEF) + tmp

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end,
    [0x7C] = function (cpu)
        cpu.registers.f = _bitAnd(cpu.registers.f, 0x1F)
        cpu.registers.f = _bitOr(cpu.registers.f, 0x20)
        cpu.registers.f = (_bitAnd(cpu.registers.d, 0x40) and 0 or 0x80)

        cpu.registers.clock.m = cpu.registers.clock.m + 2
        cpu.registers.clock.t = cpu.registers.clock.t + 8
    end
}

GameBoy.opcodes = {
    [0x00] = function(cpu)
        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x01] = function(cpu)
        writeTwoRegisters(cpu, 'b', 'c', cpu.mmu:readInt16(cpu.registers.pc))

        cpu.registers.pc = cpu.registers.pc + 2

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0x03] = function(cpu)
        writeTwoRegisters(cpu, 'b', 'c', _inc(cpu, readTwoRegisters(cpu, 'b', 'c'), true))

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
    [0x0b] = function(cpu)
        writeTwoRegisters(cpu, 'b', 'c',
            _dec(cpu, readTwoRegisters(cpu, 'b', 'c'), true))

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
        writeTwoRegisters(cpu, 'd', 'e', cpu.mmu:readUInt16(cpu.registers.pc))
        cpu.registers.pc = cpu.registers.pc + 2

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0x13] = function(cpu)
        local value = readTwoRegisters(cpu, 'd', 'e')
        writeTwoRegisters(cpu, 'd', 'e', _inc(cpu, value, true))

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
        local offset = cpu.mmu:readByte(cpu.registers.pc)

        if (offset >= 0x80) then
            offset = -((0xFF - offset) + 1)
        end

        cpu.registers.pc = cpu.registers.pc - 1
        cpu.registers.pc = cpu.registers.pc + offset

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 12
    end,
    [0x1a] = function(cpu)
        local address = readTwoRegisters(cpu, 'd', 'e')
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
    [0x20] = function(cpu)
        local offset = cpu.mmu:readByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1

        if (_bitAnd(cpu.registers.f, FLAGS_ZERO) > 0) then
            cpu.registers.clock.m = 2
            cpu.registers.clock.t = 8
        else
            if (offset >= 0x80) then
                offset = -((0xFF - offset) + 1)
            end

            cpu.registers.pc = cpu.registers.pc - 2
            cpu.registers.pc = cpu.registers.pc + offset

            cpu.registers.clock.m = 3
            cpu.registers.clock.t = 12
        end
    end,
    [0x21] = function(cpu)
        writeTwoRegisters(cpu, 'h', 'l', cpu.mmu:readUInt16(cpu.registers.pc))
        cpu.registers.pc = cpu.registers.pc + 2

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0x22] = function(cpu)
        local value = cpu.registers.a
        local address = readTwoRegisters(cpu, 'h', 'l')

        cpu.mmu:writeShort(address, value)
        writeTwoRegisters(cpu, 'h', 'l', _inc(cpu, address, true))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x23] = function(cpu)
        local address = readTwoRegisters(cpu, 'h', 'l')
        writeTwoRegisters(cpu, 'h', 'l', _inc(cpu, address, true))

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
    [0x28] = function(cpu)
        local offset = cpu.mmu:readByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1

        if (_bitAnd(cpu.registers.f, FLAGS_ZERO) == 0) then
            cpu.registers.clock.m = 2
            cpu.registers.clock.t = 8
        else
            if (offset >= 0x80) then
                offset = -((0xFF - offset) + 1)
            end

            cpu.registers.pc = cpu.registers.pc - 2
            cpu.registers.pc = cpu.registers.pc + offset
            cpu.registers.clock.m = 3
            cpu.registers.clock.t = 12
        end
    end,
    [0x2a] = function(cpu)
        local address = readTwoRegisters(cpu, 'h', 'l')
        local value = cpu.mmu:readByte(address)

        cpu.registers.a = value

        writeTwoRegisters(cpu, 'h', 'l', _inc(cpu, value, true))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x2c] = function(cpu)
        cpu.registers.l = _inc(cpu, cpu.registers.l)

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
        cpu.registers.a = (1- cpu.registers.a)
        cpu.registers.f = _bitOr(cpu.registers.f, _bitOr(_bitLShift(1, FLAGS_NEGATIVE), _bitLShift(1, FLAGS_HALFCARRY)))

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x31] = function(cpu)
        cpu.registers.sp = cpu.mmu:readUInt16(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 2

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0x32] = function(cpu)
        local address = readTwoRegisters(cpu, 'h', 'l')

        cpu.mmu:writeByte(address, cpu.registers.a)

        address = address - 1
        writeTwoRegisters(cpu, 'h', 'l', address)

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x36] = function(cpu)
        local address = readTwoRegisters(cpu, 'h', 'l')
        local value = cpu.mmu:readByte(cpu.registers.pc)

        cpu.mmu:writeByte(address, value)

        cpu.registers.pc = cpu.registers.pc + 1

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
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
    [0x4f] = function(cpu)
        cpu.registers.c = cpu.registers.a

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x57] = function(cpu)
        cpu.registers.d = cpu.registers.a

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x60] = function(cpu)
        cpu.registers.h = cpu.registers.b

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x66] = function(cpu)
        cpu.registers.h = cpu.mmu:readByte(readTwoRegisters(cpu, 'h', 'l'))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x67] = function(cpu)
        cpu.registers.h = cpu.registers.a

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0x77] = function(cpu)
        local address = readTwoRegisters(cpu, 'h', 'l')
        cpu.mmu:writeByte(address, cpu.registers.a)

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x78] = function(cpu)
        cpu.registers.a = cpu.registers.b

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
    [0x86] = function(cpu)
        cpu.registers.a = _add(cpu, cpu.registers.a,
            cpu.mmu:readByte(readTwoRegisters(cpu, 'h', 'l')))

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0x90] = function(cpu)
        cpu.registers.a = cpu.registers.a - cpu.registers.b

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xa9] = function(cpu)
        cpu.registers.a = _xor(cpu, cpu.registers.c)

        if (cpu.registers.a ~= 0) then
            cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_ZERO))
        else
            cpu.registers.f = _bitOr(cpu.registers.f, FLAGS_ZERO)
        end

        cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_NEGATIVE))
        cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_CARRY))
        cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_HALFCARRY))

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xaf] = function(cpu)
        cpu.registers.a = _xor(cpu, cpu.registers.a)

        if (cpu.registers.a ~= 0) then
            cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_ZERO))
        else
            cpu.registers.f = _bitOr(cpu.registers.f, FLAGS_ZERO)
        end

        cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_NEGATIVE))
        cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_CARRY))
        cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_HALFCARRY))

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

        if (cpu.registers.a ~= 0) then
            cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_ZERO))
        else
            cpu.registers.f = _bitOr(cpu.registers.f, FLAGS_ZERO)
        end

        cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_NEGATIVE))
        cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_CARRY))
        cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_HALFCARRY))

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xbe] = function(cpu)
        local address = readTwoRegisters(cpu, 'h', 'l')

        if (cpu.registers.a - cpu.mmu:readByte(address) ~= 0) then
            cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_ZERO))
        else
            cpu.registers.f = _bitOr(cpu.registers.f, FLAGS_ZERO)
        end

        cpu.registers.f = _bitOr(cpu.registers.f, FLAGS_NEGATIVE)

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xb7] = function(cpu)
        cpu.registers.a = _or(cpu, cpu.registers.a)

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xc1] = function(cpu)
        writeTwoRegisters(cpu, 'b', 'c', cpu.mmu:popStack())

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

        if (_bitAnd(cpu.registers.f, FLAGS_ZERO) ~= 0) then
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
        cpu.mmu:pushStack(readTwoRegisters(cpu, 'b', 'c'))

        cpu.registers.clock.m = 4
        cpu.registers.clock.t = 16
    end,
    [0xc6] = function(cpu)
        cpu.registers.a = _add(cpu, cpu.registers.a, cpu.mmu:readByte(cpu.registers.pc))
        cpu.registers.pc = cpu.registers.pc + 1

        if (cpu.registers.a ~= 0) then
            cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_ZERO))
        else
            cpu.registers.f = _bitOr(cpu.registers.f, FLAGS_ZERO)
        end

        cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_NEGATIVE))

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
            Log.error("CPU CB", "Unknown opcode: 0x%s at 0x%s", _string_format("%.2x", opcode1), _string_format("%.2x", cpu.registers.pc - 2))
            return cpu:pause()
        end

        if (not GameBoy.cbOpcodes[opcode2]) then
            Log.error("CPU CB", "Unknown opcode: 0x%s at 0x%s", _string_format("%.2x", opcode2), _string_format("%.2x", cpu.registers.pc - 1))
            return cpu:pause()
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
    [0xd6] = function(cpu)
        cpu.registers.a = _sub(cpu, cpu.registers.a,
            cpu.mmu:readByte(cpu.registers.pc))

        cpu.registers.pc = cpu.registers.pc + 1

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
        writeTwoRegisters(cpu, 'h', 'l', cpu.mmu:popStack())

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0xe2] = function(cpu)
        cpu.mmu:writeByte(0xff00 + cpu.registers.c, cpu.registers.a)

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xe5] = function(cpu)
        cpu.mmu:pushStack(readTwoRegisters(cpu, 'h', 'l'))

        cpu.registers.clock.m = 4
        cpu.registers.clock.t = 16
    end,
    [0xe6] = function(cpu)
        cpu.registers.a = _bitAnd(cpu.registers.a, cpu.mmu:readByte(cpu.registers.pc))
        cpu.registers.pc = cpu.registers.pc + 1

        if (cpu.registers.a ~= 0) then
            cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_ZERO))
        else
            cpu.registers.f = _bitOr(cpu.registers.f, FLAGS_ZERO)
        end

        cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_NEGATIVE))
        cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_CARRY))
        cpu.registers.f = _bitOr(cpu.registers.f, FLAGS_HALFCARRY)

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xea] = function(cpu)
        local address = cpu.mmu:readUInt16(cpu.registers.pc)
        cpu.mmu:writeShort(address, cpu.registers.a)
        cpu.registers.pc = cpu.registers.pc + 2

        cpu.registers.clock.m = 4
        cpu.registers.clock.t = 16
    end,
    [0xf0] = function(cpu)
        local offset = cpu.mmu:readByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1
        cpu.registers.a = cpu.mmu:readByte(0xFF00 + offset)

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0xf1] = function(cpu)
        writeTwoRegisters(cpu, 'a', 'f', cpu.mmu:popStack())

        cpu.registers.clock.m = 3
        cpu.registers.clock.t = 12
    end,
    [0xf2] = function(cpu)
        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
    [0xf3] = function(cpu)
        cpu.interrupts = false

        cpu.registers.clock.m = 1
        cpu.registers.clock.t = 4
    end,
    [0xf5] = function(cpu)
        cpu.mmu:pushStack(readTwoRegisters(cpu, 'a', 'f'))

        cpu.registers.clock.m = 4
        cpu.registers.clock.t = 16
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
        if (cpu.registers.a - cpu.mmu:readByte(cpu.registers.pc) ~= 0) then
            cpu.registers.f = _bitAnd(cpu.registers.f, _bitXor(0xFF, FLAGS_ZERO))
        else
            cpu.registers.f = _bitOr(cpu.registers.f, FLAGS_ZERO)
        end

        cpu.registers.pc = cpu.registers.pc + 1

        cpu.registers.clock.m = 2
        cpu.registers.clock.t = 8
    end,
}
