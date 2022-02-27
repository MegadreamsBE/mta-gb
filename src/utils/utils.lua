function createFilledTable(size, prefiledData)
    local tbl = {}

    for i=1, size do
        tbl[i] = prefiledData or false
    end

    return tbl
end