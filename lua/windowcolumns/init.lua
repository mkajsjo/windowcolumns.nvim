local tf = require('table_functions')

local function is_normal_window(window_config)
    return not window_config.external and window_config.relative == ''
end

local function get_windows()
    local result = {}
    for _, window_id in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local config = vim.api.nvim_win_get_config(window_id)
        if is_normal_window(config) then
            local row, column = unpack(vim.api.nvim_win_get_position(window_id))
            table.insert(result, {
                id = window_id,
                row = row,
                column = column,
            })
        end
    end
    return result
end

local function build_columns(windows)
    local top_row = tf.min(tf.map(windows, function(win) return win.row end))
    local top_windows = tf.filter(windows, function(win) return win.row == top_row end)
    local column_indexes = tf.flip_kvps(tf.sort(tf.map(top_windows, function(win) return win.column end)))

    local columns = {}
    local remaining = {}
    for _, win in ipairs(windows) do
        local column_index = column_indexes[win.column]
        if column_index then
            columns[column_index] = columns[column_index] or {}
            table.insert(columns[column_index], win)
        else
            table.insert(remaining, win)
        end
    end

    for _, column in ipairs(columns) do
        table.sort(column, function(a, b)
            return a.row < b.row
        end)
    end

    return columns, remaining
end

local function get_window_layout()
    local windows = get_windows()
    local columns, _ = build_columns(windows)
    return columns
end

local function get_window_index(columns, window_id)
    for c, column in ipairs(columns) do
        for r, window in ipairs(column) do
            if window.id == window_id then
                return c, r
            end
        end
    end
end

local function create_context()
    local columns = get_window_layout()
    local window_id = vim.api.nvim_tabpage_get_win(0)
    local column_index, row_index = get_window_index(columns, window_id)
    return {
        columns = columns,
        window_id = window_id,
        column_index = column_index,
        row_index = row_index,
    }
end

local function restore_column(column, skip)
    local top_index = column[1].id == skip and #column > 1 and 2 or 1
    for i = #column, top_index + 1, -1 do
        if column[i].id ~= skip then
            vim.fn.win_splitmove(column[i].id, column[top_index].id, { vertical = false, rightbelow = true })
        end
    end
end

local function move_column(direction)
    local ctx = create_context()

    if direction == 'left' and ctx.column_index == 1 or direction == 'right' and ctx.column_index == #ctx.columns then
        return
    end

    local offset = direction == 'left' and -1 or 1
    local current_column = ctx.columns[ctx.column_index]
    local target_column = ctx.columns[ctx.column_index + offset]

    vim.fn.win_splitmove(
        current_column[1].id,
        target_column[1].id,
        { vertical = true, rightbelow = direction == 'right' }
    )
    restore_column(current_column)
    restore_column(target_column)
end

local function move_row(direction)
    local ctx = create_context()

    local current_column = ctx.columns[ctx.column_index]
    if direction == 'up' and ctx.row_index == 1 or direction == 'down' and ctx.row_index == #current_column then
        return
    end

    if direction == 'up' then
        vim.fn.win_splitmove(ctx.window_id, current_column[ctx.row_index - 1].id, { rightbelow = false })
    else
        vim.fn.win_splitmove(ctx.window_id, current_column[ctx.row_index + 1].id, { rightbelow = true })
    end
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

local function move_window_into(direction)
    local ctx = create_context()

    if direction == 'left' and ctx.column_index == 1 or direction == 'right' and ctx.column_index == #ctx.columns then
        return
    end

    local offset = direction == 'left' and -1 or 1
    local target_column = ctx.columns[ctx.column_index + offset]

    local cursor_row = vim.fn.screenrow()
    local target_window = get_window_at_row(target_column, cursor_row)
    local height = vim.api.nvim_win_get_height(target_window.id)

    local below = cursor_row > target_window.row + height / 2
    vim.fn.win_splitmove(ctx.window_id, target_window.id, { rightbelow = below })
end

local function move_window_out(direction)
    local ctx = create_context()

    local current_column = ctx.columns[ctx.column_index]
    if #current_column == 1 then
        return
    end

    if ctx.window_id == current_column[1].id then
        vim.fn.win_splitmove(
            current_column[2].id,
            ctx.window_id,
            { vertical = true, rightbelow = direction ~= 'right' }
        )
    else
        vim.fn.win_splitmove(
            ctx.window_id,
            current_column[1].id,
            { vertical = true, rightbelow = direction == 'right' }
        )
    end

    restore_column(current_column, ctx.window_id)
    vim.api.nvim_set_current_win(ctx.window_id)
end

local function move_window_in_and_out(direction)
    local ctx = create_context()

    if #ctx.columns[ctx.column_index] > 1 then
        move_window_out(direction)
    else
        move_window_into(direction)
    end
end

local M = {}

function M.move_window_left()
    move_window_in_and_out('left')
end

function M.move_window_right()
    move_window_in_and_out('right')
end

function M.move_window_up()
    move_row('up')
end

function M.move_window_down()
    move_row('down')
end

function M.move_column_left()
    move_column('left')
end

function M.move_column_right()
    move_column('right')
end

function M.vsplit()
    local ctx = create_context()

    vim.cmd 'vsplit'

    local current_column = ctx.columns[ctx.column_index]
    if #current_column == 1 then
        return
    end

    local new_window_id = vim.api.nvim_tabpage_get_win(0)
    vim.fn.win_splitmove(
        new_window_id,
        current_column[1].id,
        { vertical = true, rightbelow = vim.opt.splitright:get() }
    )
    restore_column(current_column)
    vim.api.nvim_set_current_win(new_window_id)
end

return M
