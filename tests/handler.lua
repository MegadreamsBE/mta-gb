TestHandler = {}
TestHandler.__index = TestHandler

-----------------------------------
-- * Functions
-----------------------------------

function TestHandler:create(suiteName, testSuite, tests)
    local mt = setmetatable({}, TestHandler)

    mt.suiteName = suiteName
    mt.testSuite = testSuite
    mt.tests = tests

    mt.testName = ""
    mt.testRom = nil
    mt.gameboy = nil

    mt.currentTest = 0

    return mt
end

function TestHandler:setTests(tests)
    self.tests = tests
end

function TestHandler:cleanTest()
    self.testName = ""
    self.testRom = nil

    self.gameboy:stop()
    self.gameboy = nil
end

function TestHandler:next()
    if (not self:hasNext()) then
        return
    end

    self.currentTest = self.currentTest + 1

    local test = self.tests[self.currentTest]

    self.testName = (test[2] == nil) and "" or test[2]
    self.testRom = test[3]

    -- Creating a new clean gameboy instance for testing.
    self.gameboy = GameBoy()

    if (self.testRom ~= nil) then
        self.gameboy:load(self.testRom)
    end

    self.gameboy:start()
    self.gameboy:pause()

    if (test[4] ~= nil) then
        self.gameboy.cpu.registers.pc = test[4]
    end

    test[1](self.testSuite)
    self:cleanTest()
end

function TestHandler:hasNext()
    if (self.tests[self.currentTest + 1] == nil) then
        return false
    end

    return true
end

function TestHandler:assertClock(m ,t)
    local clock = self.gameboy.cpu.registers.clock

    if (clock.m ~= m or clock.t ~= t) then
        Log.error(self.suiteName..": "..self.testName..": assertClock",
            "Expected %d, %d for clock timing but got %d, %d.",
            m, t, clock.m, clock.t)
    end
end

function TestHandler:assertEquals(expected, actual)
    if (expected ~= actual) then
        Log.error(self.suiteName..": "..self.testName..": assertEquals",
            "Expected "..((type(expected) == "number") and "%d" or "%b").." but got "..
                ((type(actual) == "number") and "%d" or "%b")..".",
            expected, actual)
    end
end
