-----------------------------------
-- * Functions
-----------------------------------

function switch(input)
    local cases = {}
    local default = nil

    local self = {}

    self = setmetatable({
        case = function(case, callback)
            cases[#cases + 1] = { case, callback }
            return self
        end,
        default = function(callback)
            default = callback
            return self
        end
    }, {
        __call = function()
            for index, case in pairs(cases) do
                if (case[1] == input) then
                    if (case[2] ~= nil) then
                        return case[2]()
                    else
                        for i=index + 1, #cases do
                            if (cases[i] ~= nil) then
                                if (cases[i][2] ~= nil) then
                                    return cases[i][2]()
                                end
                            end
                        end
                    end
                end
            end

            if (default ~= nil) then
                return default()
            end

            return nil
        end
    })

    return self
end
