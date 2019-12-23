Rom = Class()

-----------------------------------
-- * Functions
-----------------------------------

function Rom:create(path)
    self.position = 0
    self.path = path
    self.data = {}
end

function Rom:load()
    local file = File.open(self.path, true)

    if (not file) then
        Log.error("Rom", "Unable to open file %s", self.path)
        return false
    end

    self.data = {}

    while (not file:isEOF(file)) do
         self.data[#self.data + 1] = utf8.byte(file:read(1))
    end

    file:close()

    return true
end

function Rom:getData()
    return self.data
end
