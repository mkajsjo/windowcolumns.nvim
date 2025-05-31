local core = require('windowcolumns.core')

local M = {}

--- Moves the current window in the specified direction, with column-aware behavior.
-- If the direction is 'up' or 'down', the window moves vertically within its column.
-- If the direction is 'left' or 'right', behavior depends on column_opt:
-- - 'new': always moves the window into a new column.
-- - 'existing': moves the window into an existing column, based on the cursor's screen row.
-- - 'both': moves to a new column if the current column has multiple windows,
--           otherwise moves to an existing column.
-- @param direction 'up', 'down', 'left', or 'right' — direction to move the window.
-- @param column_opt (optional) 'new', 'existing', or 'both' — how to handle horizontal moves. Defaults to 'both'.
-- @return nil
function M.move_window(direction, column_opt)
    column_opt = column_opt or 'both'

    if not vim.tbl_contains({ 'left', 'right', 'up', 'down' }, direction) then
        vim.notify('Invalid direction: ' .. tostring(direction), vim.log.levels.WARN)
    end

    if not vim.tbl_contains({ 'new', 'existing', 'both' }, column_opt) then
        vim.notify('Invalid column_opt: ' .. tostring(column_opt), vim.log.levels.WARN)
    end

    core.move_window(direction, column_opt)
end

--- Moves the entire column (all horizontal splits in the current column) left or right.
-- This allows repositioning a group of vertically aligned windows as a unit.
-- @param direction 'left' or 'right' — the direction to move the column.
-- @return nil
function M.move_column(direction)
    if not vim.tbl_contains({ 'left', 'right' }, direction) then
        vim.notify('Invalid direction: ' .. tostring(direction), vim.log.levels.WARN)
        return
    end

    core.move_column(direction)
end

--- Creates a new full-height vertical window (column) on the left or right.
-- Unlike a standard vertical split, the new window spans the full editor height,
-- ignoring any existing horizontal splits.
-- @param direction (optional) 'left' or 'right'. If omitted, uses the 'splitright' option to decide direction.
-- @return nil
function M.create_column(direction)
    if direction then
        if not vim.tbl_contains({ 'left', 'right' }, direction) then
            vim.notify('Invalid direction: ' .. tostring(direction), vim.log.levels.WARN)
            return
        end
    else
        direction = vim.opt.splitright:get() and 'right' or 'left'
    end

    core.create_column(direction)
end

return M
