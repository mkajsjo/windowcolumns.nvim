local core = require('windowcolumns.core')

local M = {}

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

function M.move_column(direction)
    if not vim.tbl_contains({ 'left', 'right' }, direction) then
        vim.notify('Invalid direction: ' .. tostring(direction), vim.log.levels.WARN)
        return
    end

    core.move_column(direction)
end

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
