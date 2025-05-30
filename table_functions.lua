local M = {}

--- Applies a function M.to each value of table and returns a new table with the results.
-- @param tbl A table of values.
-- @param func A function M.that takes (value) and returns a transformed value.
-- @return A new table where each value is the result of applying `func` to the corresponding value in `tbl`.
function M.map(tbl, func)
    local result = {}
    for k, v in pairs(tbl) do
        result[k] = func(v)
    end
    return result
end

--- Returns the minimum value in a table.
-- @param tbl A table of comparable values.
-- @return The smallest value found in the table.
-- @raise Error if the table is empty.
function M.min(tbl)
    assert(#tbl > 0, "Table must not be empty")

    local min_val = nil
    for _, v in pairs(tbl) do
        min_val = v
        break
    end

    for _, v in pairs(tbl) do
        if v < min_val then
            min_val = v
        end
    end
    return min_val
end

--- Filters a table based on a predicate function.
-- @param tbl The input table
-- @param predicate A function M.that takes (value) and returns true to keep the item
-- @return A new table with only the values for which predicate returned true
function M.filter(tbl, predicate)
    local result = {}
    for _, v in pairs(tbl) do
        if predicate(v) then
            table.insert(result, v)
        end
    end
    return result
end

--- Sorts a table by its values and returns an array-like table (removes old keys).
-- @param tbl A table.
-- @param comp Optional comparison function M.for sorting values (a, b) → boolean.
--             Defaults to ascending order (a < b).
-- @return An array-like table sorted by value.
function M.sort(tbl, comp)
    comp = comp or function(a, b) return a < b end

    local result = {}
    for _, v in pairs(tbl) do
        table.insert(result, v)
    end

    table.sort(result, function(a, b)
        return comp(a, b)
    end)

    return result
end

--- Swaps keys and values in a table.
-- @param tbl A table with unique values that can be used as keys.
-- @return A new table where each key becomes a value and each value becomes a key.
function M.flip_kvps(tbl)
    local result = {}
    for k, v in pairs(tbl) do
        result[v] = k
    end
    return result
end

return M
