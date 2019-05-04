local _or = function(cpu, value)
    cpu.registers.a = bitOr(cpu.registers.a, value)

    if (cpu.registers.a) then
        cpu.registers.f = bitAnd(cpu.registers.f, FLAGS_ZERO)
    else
        cpu.registers.f = bitOr(cpu.registers.f, FLAGS_ZERO)
    end

    cpu.registers.f= bitAnd(cpu.registers.f, bitOr(bitOr(FLAGS_ZERO, FLAGS_NEGATIVE), FLAGS_HALFCARRY))
end

local _dec = function(cpu, value)
    if (bitAnd(value, 0x0f) > 0) then
        cpu.registers.f= bitAnd(cpu.registers.f, FLAGS_HALFCARRY)
    else
        cpu.registers.f= bitOr(cpu.registers.f, FLAGS_HALFCARRY)
    end

    value = value - 1

    if (value > 0) then
        cpu.registers.f = bitAnd(cpu.registers.f, FLAGS_ZERO)
    else
        cpu.registers.f = bitOr(cpu.registers.f, FLAGS_ZERO)
    end

    cpu.registers.f = bitOr(cpu.registers.f, FLAGS_NEGATIVE)

    return value
end

GameBoy.opcodes = {
    [0x0] = function(cpu) end,
    [0x1d] = function(cpu)
        cpu.registers.e = _dec(cpu, cpu.registers.e)
    end,
    [0x25] = function(cpu)
        cpu.registers.h = _dec(cpu, cpu.registers.h)
    end,
    [0x2f] = function(cpu)
        cpu.registers.a = (1- cpu.registers.a)
        cpu.registers.f = bitOr(cpu.registers.f, bitOr(bitLShift(1, FLAGS_NEGATIVE), bitLShift(1, FLAGS_HALFCARRY)))
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
    [0xB] = function(cpu)
        _or(cpu, cpu.registers.b)
    end,
    [0xC3] = function(cpu)
        cpu.registers.pc = cpu.mmu:readUInt16(cpu.registers.pc)
    end
}
