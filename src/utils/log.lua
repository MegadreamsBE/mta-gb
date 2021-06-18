Log = {}
Log.__index = Log

-----------------------------------
-- * Functions
-----------------------------------

function Log.info(tag, message, ...)
    Log.log(tag, message, 3, nil, nil, nil, ...)
end

function Log.error(tag, message, ...)
    Log.log(tag, message, 1, nil, nil, nil, ...)
end

function Log.log(tag, message, level, r, g ,b, ...)
    local matches = pregMatch(message, "%([sdb])")

    if (#matches ~= #arg) then
        error("Invalid parameter count in log message."..
            " Expected "..#matches.." but got "..#arg..".", 3)
        return
    end

    for index, match in pairs(matches) do
        local expected = "string"

        if (match == "s") then
            expected = "string"
        elseif (match == "d") then
            expected = "number"
        elseif (match == "b") then
            expected = "boolean"
        end

        if (expected ~= type(arg[index])) then
            error("Invalid parameter in log message."..
                " Expected "..expected.." on position "..index.." but got "..
                type(arg[index])..".", 3)
            return
        end

        message = message:gsub("%%"..match, tostring(arg[index]), 1)
    end

    if (level == 1) then
        error("["..tag.."]: ".. message, 3)
    else
        outputDebugString("["..tag.."]: ".. message, level, r, g, b)
    end
end
