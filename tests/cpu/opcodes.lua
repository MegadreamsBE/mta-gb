TestOpcodes = Class()

-----------------------------------
-- * Functions
-----------------------------------

function TestOpcodes:create()
    self.handler = TestHandler("CPU Opcodes", self)
    self.handler:setTests({
        {self.testOpcode00, "Opcode 0x00", nil, 0x8000},
        {self.testOpcode01, "Opcode 0x01", nil, 0x8000}
    })
end

function TestOpcodes:run()
    while (self.handler:hasNext()) do
        self.handler:next()
    end
end

function TestOpcodes:testOpcode00()
    local cpu = self.handler.gameboy.cpu

    cpu.mmu:writeByte(0x8000, 0x00)
    cpu:step()

    self.handler:assertClock(1, 4)
end

function TestOpcodes:testOpcode01()
    local cpu = self.handler.gameboy.cpu

    cpu.mmu:writeByte(0x8000, 0x01)
    cpu.mmu:writeShort(0x8001, 0x80AA)
    cpu:step()

    self.handler:assertEquals(0x80AA, cpu:readTwoRegisters('b', 'c'))
    self.handler:assertEquals(0x8003, cpu.registers.pc)
    self.handler:assertClock(3, 12)
end
