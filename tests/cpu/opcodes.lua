TestOpcodes = {}
TestOpcodes.__index = TestOpcodes

-----------------------------------
-- * Functions
-----------------------------------

function TestOpcodes:create()
    local mt = setmetatable({}, TestOpcodes)

    mt.handler = TestHandler("CPU Opcodes", self)
    mt.handler:setTests({
        {mt.testOpcode00, "Opcode 0x00", nil, 0x8000},
        {mt.testOpcode01, "Opcode 0x01", nil, 0x8000},
        {mt.testOpcode02, "Opcode 0x02", nil, 0x8000},
        {mt.testOpcode03, "Opcode 0x03", nil, 0x8000},
        {mt.testOpcode04, "Opcode 0x04", nil, 0x8000},
        {mt.testOpcode05, "Opcode 0x05", nil, 0x8000},
        {mt.testOpcode06, "Opcode 0x06", nil, 0x8000},
        {mt.testOpcode07, "Opcode 0x07", nil, 0x8000},
        {mt.testOpcode07Carry, "Opcode 0x07 (Carry)", nil, 0x8000},
        {mt.testOpcode08, "Opcode 0x08", nil, 0x8000},
        {mt.testOpcode09, "Opcode 0x09", nil, 0x8000},
        {mt.testOpcode09HalfCarry, "Opcode 0x09 (HalfCarry)", nil, 0x8000},
        {mt.testOpcode09Carry, "Opcode 0x09 (Carry)", nil, 0x8000},
        {mt.testOpcode0A, "Opcode 0x0A", nil, 0x8000},
    })

    return mt
end

function TestOpcodes:run()
    while (self.handler:hasNext()) do
        self.handler:next()
    end
end

function TestOpcodes:testOpcode00()
    local cpu = self.handler.gameboy.cpu

    mmuWriteByte(0x8000, 0x00)
    cpu:step()

    self.handler:assertClock(1, 4)
end

function TestOpcodes:testOpcode01()
    local cpu = self.handler.gameboy.cpu

    mmuWriteByte(0x8000, 0x01)
    mmuWriteShort(0x8001, 0x80AA)
    cpu:step()

    self.handler:assertEquals(0x80AA, cpu:readTwoRegisters('b', 'c'))
    self.handler:assertEquals(0x8003, cpu.registers.pc)
    self.handler:assertClock(3, 12)
end

function TestOpcodes:testOpcode02()
    local cpu = self.handler.gameboy.cpu

    mmuWriteByte(0x8000, 0x02)

    cpu.registers.a = 0x76
    cpu:writeTwoRegisters('b', 'c', 0x8066)
    cpu:step()

    self.handler:assertEquals(0x76, mmuReadByte(0x8066))
    self.handler:assertClock(2, 8)
end

function TestOpcodes:testOpcode03()
    local cpu = self.handler.gameboy.cpu

    mmuWriteByte(0x8000, 0x03)
    cpu:writeTwoRegisters('b', 'c', 0x8066)
    cpu:step()

    self.handler:assertEquals(0x8067, cpu:readTwoRegisters('b', 'c'))
    self.handler:assertClock(2, 8)
end

function TestOpcodes:testOpcode04()
    local cpu = self.handler.gameboy.cpu

    mmuWriteByte(0x8000, 0x04)
    cpu.registers.b = 0x76
    cpu:step()

    self.handler:assertEquals(0x77, cpu.registers.b)
    self.handler:assertClock(1, 4)
end

function TestOpcodes:testOpcode05()
    local cpu = self.handler.gameboy.cpu

    mmuWriteByte(0x8000, 0x05)
    cpu.registers.b = 0x76
    cpu:step()

    self.handler:assertEquals(0x75, cpu.registers.b)
    self.handler:assertClock(1, 4)
end

function TestOpcodes:testOpcode06()
    local cpu = self.handler.gameboy.cpu

    mmuWriteByte(0x8000, 0x06)
    mmuWriteByte(0x8001, 0xA6)
    cpu:step()

    self.handler:assertEquals(0xA6, cpu.registers.b)
    self.handler:assertClock(2, 8)
end

function TestOpcodes:testOpcode07()
    local cpu = self.handler.gameboy.cpu

    mmuWriteByte(0x8000, 0x07)
    cpu.registers.a = 0x76 -- 0111 0110
    cpu:step()

    self.handler:assertEquals(0xEC, cpu.registers.a) -- 1110 1100
    self.handler:assertEquals(false, cpu.registers.f[4])
    self.handler:assertClock(1, 4)
end

function TestOpcodes:testOpcode07Carry()
    local cpu = self.handler.gameboy.cpu

    mmuWriteByte(0x8000, 0x07)
    cpu.registers.a = 0xEC -- 1110 1100
    cpu:step()

    self.handler:assertEquals(0xD8, cpu.registers.a) -- 1101 1000
    self.handler:assertEquals(true, cpu.registers.f[4])
end

function TestOpcodes:testOpcode08()
    local cpu = self.handler.gameboy.cpu

    mmuWriteByte(0x8000, 0x08)
    mmuWriteShort(0x8001, 0x8045)
    cpu.registers.sp = 0xFFF6
    cpu:step()

    self.handler:assertEquals(0xFFF6, mmuReadUInt16(0x8045))
    self.handler:assertClock(5, 20)
end

function TestOpcodes:testOpcode09()
    local cpu = self.handler.gameboy.cpu

    mmuWriteByte(0x8000, 0x09)
    cpu:writeTwoRegisters('h', 'l', 0x75A6)
    cpu:writeTwoRegisters('b', 'c', 0x1A66)
    cpu:step()

    self.handler:assertEquals(0x900C, cpu:readTwoRegisters('h', 'l'))
    self.handler:assertClock(2, 8)
end

function TestOpcodes:testOpcode09HalfCarry()
    local cpu = self.handler.gameboy.cpu

    mmuWriteByte(0x8000, 0x09)
    cpu:writeTwoRegisters('h', 'l', 0xAF16)
    cpu:writeTwoRegisters('b', 'c', 0x1875)
    cpu:step()

    self.handler:assertEquals(0xC78B, cpu:readTwoRegisters('h', 'l'))
    self.handler:assertEquals(true, cpu.registers.f[3])
    self.handler:assertEquals(false, cpu.registers.f[4])
end

function TestOpcodes:testOpcode09Carry()
    local cpu = self.handler.gameboy.cpu

    mmuWriteByte(0x8000, 0x09)
    cpu:writeTwoRegisters('h', 'l', 0xF116)
    cpu:writeTwoRegisters('b', 'c', 0x1875)
    cpu:step()

    self.handler:assertEquals(0x098B, cpu:readTwoRegisters('h', 'l'))
    self.handler:assertEquals(false, cpu.registers.f[3])
    self.handler:assertEquals(true, cpu.registers.f[4])
end

function TestOpcodes:testOpcode0A()
    local cpu = self.handler.gameboy.cpu

    mmuWriteByte(0x8000, 0x0A)
    mmuWriteByte(0x8045, 0xA6)
    cpu:writeTwoRegisters('b', 'c', 0x8045)
    cpu:step()

    self.handler:assertEquals(0xA6, cpu.registers.a)
    self.handler:assertClock(2, 8)
end
