local context = require('windowcolumns.context')

local function move_next_to(window, target, direction)
    local opt = {
        vertical = direction == 'left' or direction == 'right',
        rightbelow = direction == 'right' or direction == 'down',
    }
    local window_id = type(window) == 'number' and window or window.id
    local target_id = type(target) == 'number' and target or target.id
    vim.fn.win_splitmove(window_id, target_id, opt)
end

local function restore_column(column, skip)
    local top_index = column[1].id == skip and #column > 1 and 2 or 1
    for i = #column, top_index + 1, -1 do
        if column[i].id ~= skip then
            move_next_to(column[i], column[top_index], 'down')
        end
    end
end

local function restore_dimensions(windows)
    for _, window in ipairs(windows) do
        local width = vim.api.nvim_win_get_width(window.id)
        local height = vim.api.nvim_win_get_height(window.id)
        if width ~= window.width then
            vim.api.nvim_win_set_width(window.id, window.width)
        end
        if height ~= window.height then
            vim.api.nvim_win_set_height(window.id, window.height)
        end
    end
end

local function move_window_vertical(ctx, direction)
    local offset = direction == 'up' and -1 or 1
    local target = ctx.get_column()[ctx.row_index + offset]
    move_next_to(ctx.window, target, direction)
end

local function get_window_at_row(column, row)
    local result = nil
    for _, window in ipairs(column) do
        if window.row > row then
            break
        end

        result = window
    end

    return result
end

local function move_window_to_existing_column(ctx, direction)
    local target_column = ctx.get_column(direction)

    local cursor_row = vim.fn.screenrow()
    local target_window = get_window_at_row(target_column, cursor_row)
    local height = vim.api.nvim_win_get_height(target_window.id)

    local dir = cursor_row > target_window.row + height / 2 and 'down' or 'up'
    move_next_to(ctx.window, target_window, dir)
end

local M = {}

function M.move_column(direction, ctx)
    ctx = ctx or context.create()
    if not ctx then
        return
    end

    if ctx.is_out_of_bounds(direction) then
        return
    end

    local current_column = ctx.get_column()
    local target_column = ctx.get_column(direction)

    move_next_to(current_column[1], target_column[1], direction)
    restore_column(current_column)
    restore_column(target_column)
    restore_dimensions(ctx.ignored_windows)
end

local function move_window_to_new_column(ctx, direction)
    local current_column = ctx.get_column()

    if #current_column == 1 then
        M.move_column(direction, ctx)
        return
    end

    if ctx.window.id == current_column[1].id then
        move_next_to(ctx.window, current_column[2], direction)
    else
        move_next_to(ctx.window, current_column[1], direction)
    end

    restore_column(current_column, ctx.window.id)
    vim.api.nvim_set_current_win(ctx.window.id)
end

function M.move_window(direction, column_opt)
    local ctx = context.create()
    if not ctx then
        return
    end

    if direction == 'up' or direction == 'down' then
        if ctx.is_out_of_bounds(direction) then
            return
        end

        move_window_vertical(ctx, direction)
    else
        if column_opt == 'both' and #ctx.get_column() > 1 or column_opt == 'new' then
            move_window_to_new_column(ctx, direction)
        else
            if ctx.is_out_of_bounds(direction) then
                return
            end

            move_window_to_existing_column(ctx, direction)
        end
    end
    restore_dimensions(ctx.ignored_windows)
end

function M.create_column(direction)
    local ctx = context.create()
    if not ctx then
        return
    end

    vim.cmd 'vsplit'
    local new_window_id = vim.api.nvim_tabpage_get_win(0)
    local current_column = ctx.get_column()
    move_next_to(new_window_id, current_column[1], direction)
    restore_column(current_column)
    vim.api.nvim_set_current_win(new_window_id)
    restore_dimensions(ctx.ignored_windows)
end

return M
