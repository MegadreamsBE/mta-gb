-----------------------------------
-- * Constants
-----------------------------------

local FLAGS_ZERO = bitLShift(1, 7)
local FLAGS_NEGATIVE = bitLShift(1, 6)
local FLAGS_HALFCARRY = bitLShift(1, 5)
local FLAGS_CARRY = bitLShift(1, 4)

-----------------------------------
-- * Locals
-----------------------------------

local _or = function(cpu, value)
    cpu.registers.a = bitOr(cpu.registers.a, value)

    if (cpu.registers.a) then
        cpu.registers.f = bitAnd(cpu.registers.f, bitXor(0xFF, FLAGS_ZERO))
    else
        outputDebugString("set zero: 1")
        cpu.registers.f = bitOr(cpu.registers.f, FLAGS_ZERO)
    end

    cpu.registers.f= bitAnd(cpu.registers.f, bitOr(bitOr(FLAGS_ZERO, FLAGS_NEGATIVE), FLAGS_HALFCARRY))
end

local _xor = function(cpu, value)
    cpu.registers.a = bitXor(cpu.registers.a, value)

    if (cpu.registers.a) then
        cpu.registers.f = bitAnd(cpu.registers.f, bitXor(0xFF, FLAGS_ZERO))
    else
        cpu.registers.f = bitOr(cpu.registers.f, FLAGS_ZERO)
    end

    cpu.registers.f= bitAnd(cpu.registers.f, bitOr(bitOr(FLAGS_ZERO, FLAGS_NEGATIVE), FLAGS_HALFCARRY))
end

local _dec = function(cpu, value)
    if (bitAnd(value, 0x0f) > 0) then
        cpu.registers.f= bitAnd(cpu.registers.f, bitXor(0xFF, FLAGS_HALFCARRY))
    else
        cpu.registers.f= bitOr(cpu.registers.f, FLAGS_HALFCARRY)
    end

    value = value - 1

    if (value < 0) then
        value = 0xFF - (math.abs(value) - 1)
    end

    if (value) then
        cpu.registers.f = bitAnd(cpu.registers.f, bitXor(0xFF, FLAGS_ZERO))
    else
        cpu.registers.f = bitOr(cpu.registers.f, FLAGS_ZERO)
    end

    cpu.registers.f = bitOr(cpu.registers.f, FLAGS_NEGATIVE)

    return value
end

local readTwoRegisters = function(cpu, r1, r2)
    local value = cpu.registers[r2]
    value = value + bitLShift(cpu.registers[r1], 8)

    return value
end

local writeTwoRegisters = function(cpu, r1, r2, value)
    cpu.registers[r1] = bitRShift(bitAnd(0xFF00, value), 8)
    cpu.registers[r2] = bitAnd(0x00FF, value)
end

GameBoy.opcodes = {
    [0x00] = function(cpu) end,
    [0x05] = function(cpu)
        cpu.registers.b = _dec(cpu, cpu.registers.b)
    end,
    [0x06] = function(cpu)
        cpu.registers.b = cpu.mmu:readByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1
    end,
    [0x0e] = function(cpu)
        cpu.registers.c = cpu.mmu:readByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1
    end,
    [0x1d] = function(cpu)
        cpu.registers.e = _dec(cpu, cpu.registers.e)
    end,
    [0x20] = function(cpu)
        local offset = cpu.mmu:readByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1

        if (bitAnd(cpu.registers.f, FLAGS_ZERO) > 0) then
            cpu.clock.m = cpu.clock.m + 8
        else
            if (bitTest(offset, 0x80)) then
                offset = -((0xFF - offset) + 1)
            end

            cpu.registers.pc = cpu.registers.pc + offset
            cpu.clock.m = cpu.clock.m + 12
        end
    end,
    [0x21] = function(cpu)
        writeTwoRegisters(cpu, 'h', 'l', cpu.mmu:readUInt16(cpu.registers.pc))
        cpu.registers.pc = cpu.registers.pc + 2
    end,
    [0x25] = function(cpu)
        cpu.registers.h = _dec(cpu, cpu.registers.h)
    end,
    [0x2f] = function(cpu)
        cpu.registers.a = (1- cpu.registers.a)
        cpu.registers.f = bitOr(cpu.registers.f, bitOr(bitLShift(1, FLAGS_NEGATIVE), bitLShift(1, FLAGS_HALFCARRY)))
    end,
    [0x32] = function(cpu)
        local address = readTwoRegisters(cpu, 'h', 'l')

        cpu.mmu:writeByte(address, cpu.registers.a)

        address = address - 1
        writeTwoRegisters(cpu, 'h', 'l', address)
    end,
    [0x47] = function(cpu)
        cpu.registers.b = cpu.registers.a
    end,
    [0x48] = function(cpu)
        cpu.registers.c = cpu.registers.b
    end,
    [0x49] = function(cpu) end,
    [0x4a] = function(cpu)
        cpu.registers.c = cpu.registers.d
    end,
    [0x4b] = function(cpu)
        cpu.registers.c = cpu.registers.e
    end,
    [0x4c] = function(cpu)
        cpu.registers.c = cpu.registers.h
    end,
    [0x4d] = function(cpu)
        cpu.registers.c = cpu.registers.l
    end,
    [0xaf] = function(cpu)
        _xor(cpu, cpu.registers.a)
    end,
    [0xb] = function(cpu)
        _or(cpu, cpu.registers.b)
    end,
    [0xc3] = function(cpu)
        cpu.registers.pc = cpu.mmu:readUInt16(cpu.registers.pc)
    end
}
