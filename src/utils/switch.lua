function switch()
    local lookupTable = {}
    local default = function() end
    local failure = function() end
    local chain = {}

    local self = {}
    self.__index = self

    self = setmetatable({
        case = function(case, callback)
            if (type(case) == "number") then
                if (case > #lookupTable) then
                    for i = #lookupTable + 1, case do
                        lookupTable[i] = default
                    end
                end

                if (callback == nil) then
                    chain[case] = true
                    callback = false
                else
                    for case, _ in pairs(chain) do
                        lookupTable[case] = callback
                    end

                    chain = {}
                end

                lookupTable[case] = callback
                return self
            end

            return false
        end,
        caseRange = function(caseMin, caseMax, callback)
            if (type(caseMin) == "number" and type(caseMax) == "number") then
                for i=caseMin, caseMax do
                    if (lookupTable[i] == nil or lookupTable[i] == false or lookupTable[i] == default) then
                        self.case(i, callback)
                    end
                end

                return self
            end

            return false
        end,
        default = function(callback)
            for i=1, #lookupTable do
                if (lookupTable[i] == default) then
                    lookupTable[i] = callback
                end
            end

            default = callback
            return self
        end,
        assemble = function()
            return lookupTable
        end
    }, self)

    return self
end