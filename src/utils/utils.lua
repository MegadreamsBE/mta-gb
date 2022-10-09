function createFilledTable(size, prefiledData, depth)
    local tbl = {}

    for i=1, size do
        if ((depth or 0) > 1) then
            tbl[i] = createFilledTable(size, prefiledData, depth - 1)
        else
            tbl[i] = prefiledData or false
        end
    end

    return tbl
end