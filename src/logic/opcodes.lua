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

local _inc = function(cpu, value)
    if (bitAnd(value, 0x0f) == 0x0f) then
        cpu.registers.f= bitOr(cpu.registers.f, FLAGS_HALFCARRY)
    else
        cpu.registers.f= bitAnd(cpu.registers.f, bitXor(0xFF, FLAGS_HALFCARRY))
    end

    value = value + 1

    if (value) then
        cpu.registers.f = bitAnd(cpu.registers.f, bitXor(0xFF, FLAGS_ZERO))
    else
        cpu.registers.f = bitOr(cpu.registers.f, FLAGS_ZERO)
    end

    cpu.registers.f = bitAnd(cpu.registers.f, bitXor(0xFF, FLAGS_NEGATIVE))

    return value
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

GameBoy.cbOpcodes = {
    [0x20] = function (cpu)
        local tmp = (bitAnd(cpu.registers.b, 0x80) and 0x10 or 0)
        cpu.registers.b = bitAnd(bitLShift(cpu.registers.b, 1), 255)
        cpu.registers.f = ((cpu.registers.b) and 0 or 0x80)
        cpu.registers.f = bitAnd(cpu.registers.f, 0xEF) + tmp
        cpu.registers.clock.m = 2
    end,
    [0x7C] = function (cpu)
        cpu.registers.f = bitAnd(cpu.registers.f, 0x1F)
        cpu.registers.f = bitOr(cpu.registers.f, 0x20)
        cpu.registers.f = (bitAnd(cpu.registers.d, 0x40) and 0 or 0x80)
        cpu.registers.clock.m = 2
    end
}

GameBoy.opcodes = {
    [0x00] = function(cpu) end,
    [0x05] = function(cpu)
        cpu.registers.b = _dec(cpu, cpu.registers.b)
    end,
    [0x06] = function(cpu)
        cpu.registers.b = cpu.mmu:readByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1
    end,
    [0x0c] = function(cpu)
        cpu.registers.c = _inc(cpu, cpu.registers.c)
    end,
    [0x0e] = function(cpu)
        cpu.registers.c = cpu.mmu:readByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1
    end,
    [0x11] = function(cpu)
        writeTwoRegisters(cpu, 'D', 'E', cpu.mmu:readUInt16(cpu.registers.pc))
        cpu.registers.pc = cpu.registers.pc + 2
    end,
    [0x1a] = function(cpu)
        local address = readTwoRegisters(cpu, 'D', 'E')
        cpu.registers.a = cpu.mmu:readByte(address)
    end,
    [0x1d] = function(cpu)
        cpu.registers.e = _dec(cpu, cpu.registers.e)
    end,
    [0x20] = function(cpu)
        local offset = cpu.mmu:readByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1

        if (bitAnd(cpu.registers.f, FLAGS_ZERO) > 0) then
            cpu.registers.clock.m = cpu.registers.clock.m + 8
        else
            if (bitTest(offset, 0x80)) then
                offset = -((0xFF - offset) + 1)
            end

            cpu.registers.pc = cpu.registers.pc + offset
            cpu.registers.clock.m = cpu.registers.clock.m + 12
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
    [0x31] = function(cpu)
        cpu.registers.sp = cpu.mmu:readUInt16(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 2
    end,
    [0x32] = function(cpu)
        local address = readTwoRegisters(cpu, 'h', 'l')

        cpu.mmu:writeByte(address, cpu.registers.a)

        address = address - 1
        writeTwoRegisters(cpu, 'h', 'l', address)
    end,
    [0x3e] = function(cpu)
        cpu.registers.a = cpu.mmu:readByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1
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
    [0x77] = function(cpu)
        local address = readTwoRegisters(cpu, 'h', 'l')
        cpu.mmu:writeByte(address, cpu.registers.a)
    end,
    [0x7c] = function(cpu)
        cpu.registers.a = cpu.registers.h
    end,
    [0xaf] = function(cpu)
        _xor(cpu, cpu.registers.a)
    end,
    [0xb] = function(cpu)
        _or(cpu, cpu.registers.b)
    end,
    [0xc3] = function(cpu)
        cpu.registers.pc = cpu.mmu:readUInt16(cpu.registers.pc)
    end,
    [0xcb] = function(cpu)
        local opcode1 = cpu.mmu:readByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1

        local opcode2 = cpu.mmu:readByte(cpu.registers.pc)
        cpu.registers.pc = cpu.registers.pc + 1

        if (not GameBoy.cbOpcodes[opcode1]) then
            Log.error("CPU CB", "Unknown opcode: 0x%s at 0x%s", string.format("%.2x", opcode1), string.format("%.2x", cpu.registers.pc - 2))
            return cpu:pause()
        end

        if (not GameBoy.cbOpcodes[opcode2]) then
            Log.error("CPU CB", "Unknown opcode: 0x%s at 0x%s", string.format("%.2x", opcode2), string.format("%.2x", cpu.registers.pc - 1))
            return cpu:pause()
        end

        GameBoy.cbOpcodes[opcode1](cpu)
        GameBoy.cbOpcodes[opcode2](cpu)
    end,
    [0xe0] = function(cpu)
        cpu.mmu:writeByte(0xff00 + cpu.mmu:readByte(cpu.registers.pc), cpu.registers.a)
        cpu.registers.pc = cpu.registers.pc + 1
    end,
    [0xe2] = function(cpu)
        cpu.mmu:writeByte(0xff00 + cpu.registers.c, cpu.registers.a)
    end,
    [0xfb] = function(cpu)
        cpu.interrupts = true
    end,
}
