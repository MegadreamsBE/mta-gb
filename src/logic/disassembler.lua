Disassembler = Class()

-----------------------------------
-- * Constants
-----------------------------------

local OPCODE_TABLE = {
    "NOP", "LD BC,nn", "LD (BC),A", "INC BC", "INC B", "DEC B", "LD B,n",
    "RLC A", "LD (nn),SP", "ADD HL,BC", "LD A,(BC)", "DEC BC", "INC C", "DEC C",
    "LD C,n", "RRC A", "STOP", "LD DE,nn", "LD (DE),A", "INC DE", "INC D",
    "DEC D", "LD D,n", "RL A", "JR n", "ADD HL,DE", "LD A,(DE)", "DEC DE",
    "INC E", "DEC E", "LD E,n", "RR A", "JR NZ,n", "LD HL,nn", "LDI (HL),A",
    "INC HL", "INC H", "DEC H", "LD H,n", "DAA", "JR Z,n", "ADD HL,HL",
    "LDI A,(HL)", "DEC HL", "INC L", "DEC L", "LD L,n", "CPL", "JR NC,n",
    "LD SP,nn", "LDD (HL),A", "INC SP", "INC (HL)", "DEC (HL)", "LD (HL),n",
    "SCF", "JR C,n", "ADD HL,SP", "LDD A,(HL)", "DEC SP", "INC A", "DEC A",
    "LD A,n", "CCF", "LD B,B", "LD B,C", "LD B,D", "LD B,E", "LD B,H", "LD B,L",
    "LD B,(HL)", "LD B,A", "LD C,B", "LD C,C", "LD C,D", "LD C,E", "LD C,H",
    "LD C,L", "LD C,(HL)", "LD C,A", "LD D,B", "LD D,C", "LD D,D", "LD D,E",
    "LD D,H", "LD D,L", "LD D,(HL)", "LD D,A", "LD E,B", "LD E,C", "LD E,D",
    "LD E,E", "LD E,H", "LD E,L", "LD E,(HL)", "LD E,A", "LD H,B", "LD H,C",
    "LD H,D", "LD H,E", "LD H,H", "LD H,L", "LD H,(HL)", "LD H,A", "LD L,B",
    "LD L,C", "LD L,D", "LD L,E", "LD L,H", "LD L,L", "LD L,(HL)", "LD L,A",
    "LD (HL),B", "LD (HL),C", "LD (HL),D", "LD (HL),E", "LD (HL),H", "LD (HL),L",
    "HALT", "LD (HL),A", "LD A,B", "LD A,C", "LD A,D", "LD A,E", "LD A,H",
    "LD A,L", "LD A,(HL)", "LD A,A", "ADD A,B", "ADD A,C", "ADD A,D", "ADD A,E",
    "ADD A,H", "ADD A,L", "ADD A,(HL)", "ADD A,A", "ADC A,B", "ADC A,C", "ADC A,D",
    "ADC A,E", "ADC A,H", "ADC A,L", "ADC A,(HL)", "ADC A,A", "SUB A,B", "SUB A,C",
    "SUB A,D", "SUB A,E", "SUB A,H", "SUB A,L", "SUB A,(HL)", "SUB A,A", "SBC A,B",
    "SBC A,C", "SBC A,D", "SBC A,E", "SBC A,H", "SBC A,L", "SBC A,(HL)", "SBC A,A",
    "AND B", "AND C", "AND D", "AND E", "AND H", "AND L", "AND (HL)", "AND A",
    "XOR B", "XOR C", "XOR D", "XOR E", "XOR H", "XOR L", "XOR (HL)", "XOR A",
    "OR B", "OR C", "OR D", "OR E", "OR H", "OR L", "OR (HL)", "OR A", "CP B",
    "CP C", "CP D", "CP E", "CP H", "CP L", "CP (HL)", "CP A", "RET NZ", "POP BC",
    "JP NZ,nn", "JP nn", "CALL NZ,nn", "PUSH BC", "ADD A,n", "RST 0", "RET Z",
    "RET", "JP Z,nn", "Ext ops", "CALL Z,nn", "CALL nn", "ADC A,n", "RST 8",
    "RET NC", "POP DE", "JP NC,nn", "XX", "CALL NC,nn", "PUSH DE", "SUB A,n",
    "RST 10", "RET C", "RETI", "JP C,nn", "XX", "CALL C,nn", "XX", "SBC A,n",
    "RST 18", "LDH (n),A", "POP HL", "LDH (C),A", "XX", "XX", "PUSH HL", "AND n",
    "RST 20", "ADD SP,d", "JP (HL)", "LD (nn),A", "XX", "XX", "XX", "XOR n",
    "RST 28", "LDH A,(n)", "POP AF", "XX", "DI", "XX", "PUSH AF", "OR n", "RST 30",
    "LDHL SP,d", "LD SP,HL", "LD A,(nn)", "EI", "XX", "XX", "CP n", "RST 38"
}

-----------------------------------
-- * Functions
-----------------------------------

function Disassembler:create()
    self.data = {}
    self.romData = {}
end

function Disassembler:load(rom)
    self.data = {}
    self.romData = (type(rom) == "table") and rom or rom:getData()

    local address = 0

    while (address < #self.romData) do
        local opcode = self:readByte(address) + 1
        local instruction = OPCODE_TABLE[self:readByte(address) + 1]
        local pc = address

        if (opcode - 1 == 0xCB) then
            instruction = instruction
            address = address + 2
            self.data[pc + 1] = instruction
        else
            if (instruction ~= nil) then
                local byteCount = (instruction:match("nn") ~= nil) and 2 or
                    ((instruction:match("n") ~= nil) and 1 or 0)

                if (byteCount == 1) then
                    instruction = instruction:gsub("n",
                        string.format("%.2x", self:readByte(address + 1)):upper())
                    address = address + 1
                elseif (byteCount == 2) then
                    instruction = instruction:gsub("nn",
                        string.format("%.4x", self:readInt16(address + 1)):upper())

                    address = address + 2
                end

                self.data[pc + 1] = instruction
            else
                self.data[pc + 1] = "UNKNOWN"
            end
        end

        address = address + 1
    end

    self.romData = {}
end

function Disassembler:readByte(address)
    return self.romData[address + 1]
end

function Disassembler:readUInt16(address)
    local value = 0

    for i=0, 1 do
        value = value + bitLShift(self:readByte(address + i), 8 * i)
    end

    return bitAnd(value, 0xFFFF)
end

function Disassembler:readInt16(address)
    local value = self:readUInt16(address)

    if (bitTest(value, 0x8000)) then
        value = -((0xFFFF - value) + 1)
    end

    return bitAnd(value, 0xFFFF)
end

function Disassembler:getData()
    return self.data
end
