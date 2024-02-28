function createFilledTable(size, prefilledData, depth)
    local tbl = {}

    for i=1, size do
        if (type(prefilledData) == "table") then
            prefilledData = copyTable(prefilledData)
        end

        if ((depth or 0) > 1) then
            tbl[i] = createFilledTable(size, prefilledData, depth - 1)
        else
            tbl[i] = prefilledData or 0
        end
    end

    return tbl
end

function copyTable(tbl)
    local newTbl = {}

    for k, v in pairs(tbl) do
        if (type(v) == "table") then
            newTbl[k] = copyTable(v)
        else
            newTbl[k] = v
        end
    end

    return newTbl
end