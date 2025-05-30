local tf = require('table_functions')

local function is_normal_window(window_config)
    return not window_config.external and window_config.relative == ''
end

local function normalize_layout(layout)
    local result = {}

    local columns = vim.tbl_keys(layout)
    table.sort(columns)

    for i, col in ipairs(columns) do
        local rows = vim.tbl_keys(layout[col])
        table.sort(rows)

        for _, row in ipairs(rows) do
            result[i] = result[i] or {}
            table.insert(result[i], layout[col][row])
        end
    end

    return result
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
    local columns, remaining = build_columns(windows)
    return columns
end

local function get_column_index(columns, window_id)
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
    return {
        columns = columns,
        window_id = window_id,
        column_index = get_column_index(columns, window_id),
    }
end

local function restore_column(column)
    for i = #column, 2, -1 do
        vim.fn.win_splitmove(column[i].id, column[1].id, { vertical = false, rightbelow = true })
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
    vim.fn.win_splitmove(current_column[1].id, target_column[1].id,
        { vertical = true, rightbelow = direction == 'right' })
    restore_column(current_column)
    restore_column(target_column)
end

local function create_current_layout(tab_id)
    local window_layout = {}

    for _, window_id in ipairs(vim.api.nvim_tabpage_list_wins(tab_id)) do
        local config = vim.api.nvim_win_get_config(window_id)
        if is_normal_window(config) then
            local pos = vim.api.nvim_win_get_position(window_id)
            local row = pos[1]
            local col = pos[2]

            window_layout[col] = window_layout[col] or {}
            window_layout[col][row] = window_id
        end
    end

    return normalize_layout(window_layout)
end

local function get_window_column_nr(layout, window_id)
    local columns = vim.tbl_keys(layout)
    table.sort(columns)
    for i, column in ipairs(columns) do
        if vim.tbl_contains(layout[column], window_id) then
            return i
        end
    end
    error("Window " .. tostring(window_id) .. " does not exist in layout.")
end

local function find_index(list, element)
    for i, e in ipairs(list) do
        if e == element then
            return i
        end
    end
end

local function move_column_to_far_left(layout, column_nr)
    local top_row_window_id = layout[column_nr][1]
    vim.api.nvim_set_current_win(top_row_window_id)
    vim.cmd 'wincmd H'
    for i = 2, #layout[column_nr] do
        local row_window_id = layout[column_nr][i]
        vim.fn.win_splitmove(row_window_id, top_row_window_id)
    end
end

local function move_column_to_far_right(layout, column_nr)
    local top_row_window_id = layout[column_nr][1]
    vim.api.nvim_set_current_win(top_row_window_id)
    vim.cmd 'wincmd L'
    for i = 2, #layout[column_nr] do
        local row_window_id = layout[column_nr][i]
        vim.fn.win_splitmove(row_window_id, top_row_window_id)
    end
end

local function restore_left(layout, column_nr)
    for i = column_nr, 1, -1 do
        move_column_to_far_left(layout, i)
    end
end

local function restore_right(layout, column_nr)
    for i = column_nr, #layout do
        move_column_to_far_right(layout, i)
    end
end

local function get_window_info(tab_id)
    local layout = create_current_layout(tab_id)
    local current_window_id = vim.api.nvim_tabpage_get_win(tab_id)
    local column_nr = get_window_column_nr(layout, current_window_id)
    return layout, current_window_id, column_nr
end

local function get_window_index_at_row(row_nr, column)
    local window_index = 1
    for i, row_window_id in ipairs(column) do
        local pos = vim.api.nvim_win_get_position(row_window_id)
        local row = pos[1]

        if row > row_nr then
            break
        end

        window_index = i
    end

    return window_index
end

local function swap_buffers(from, to)
    local from_buffer = vim.api.nvim_win_get_buf(from)
    local to_buffer = vim.api.nvim_win_get_buf(to)
    local from_cursor_pos = vim.api.nvim_win_get_cursor(from)
    local to_cursor_pos = vim.api.nvim_win_get_cursor(to)

    vim.api.nvim_win_set_buf(from, to_buffer)
    vim.api.nvim_win_set_buf(to, from_buffer)
    vim.api.nvim_win_set_cursor(from, to_cursor_pos)
    vim.api.nvim_win_set_cursor(to, from_cursor_pos)
end

local function swap_buffer(direction)
    local layout, current_window_id, column_nr = get_window_info(0)

    if direction == 'up' then
        local row_nr = find_index(layout[column_nr], current_window_id)
        if row_nr > 1 then
            local target_window_id = layout[column_nr][row_nr - 1]
            swap_buffers(current_window_id, target_window_id)
            return target_window_id
        else
            return
        end
    elseif direction == 'down' then
        local row_nr = find_index(layout[column_nr], current_window_id)
        if row_nr < #layout[column_nr] then
            local target_window_id = layout[column_nr][row_nr + 1]
            swap_buffers(current_window_id, target_window_id)
            return target_window_id
        else
            return
        end
    elseif direction == 'left' and column_nr == 1 or direction == 'right' and column_nr == #layout then
        return
    end

    local offset = direction == 'left' and -1 or 1
    local column = layout[column_nr + offset]

    local cursor_row = vim.fn.screenrow()
    local row_nr = get_window_index_at_row(cursor_row, column)
    local target_window_id = column[row_nr]

    swap_buffers(current_window_id, target_window_id)

    return target_window_id
end

local function move_buffer(direction)
    local target_window_id = swap_buffer(direction)
    if target_window_id then
        vim.api.nvim_set_current_win(target_window_id)
    end
end

local function move_window_into(direction)
    local layout, current_window_id, column_nr = get_window_info(0)

    if direction == 'left' and column_nr == 1 then
        vim.cmd 'wincmd H'
        return
    end

    if direction == 'right' and column_nr == #layout then
        vim.cmd 'wincmd L'
        return
    end

    local offset = direction == 'left' and -1 or 1
    local column = layout[column_nr + offset]

    local cursor_row = vim.fn.screenrow()
    local row_nr = get_window_index_at_row(cursor_row, column)
    local row_window_id = column[row_nr]

    local height = vim.api.nvim_win_get_height(row_window_id)
    local row, _ = unpack(vim.api.nvim_win_get_position(row_window_id))

    local below = cursor_row > row + height / 2
    vim.fn.win_splitmove(current_window_id, row_window_id, { rightbelow = below })
end

local function move_window_out(direction)
    local layout, _, column_nr = get_window_info(0)
    local current_window_id = vim.api.nvim_tabpage_get_win(0)

    if direction == 'left' then
        vim.cmd 'wincmd H'
        restore_left(layout, column_nr - 1)
    else
        vim.cmd 'wincmd L'
        restore_right(layout, column_nr + 1)
    end

    vim.api.nvim_set_current_win(current_window_id)
end

local function move_window_in_and_out(direction)
    local layout, _, column_nr = get_window_info(0)

    if #layout[column_nr] > 1 then
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

function M.move_column_left()
    move_column('left')
end

function M.move_column_right()
    move_column('right')
end

function M.swap_buffer_left()
    swap_buffer('left')
end

function M.swap_buffer_right()
    swap_buffer('right')
end

function M.swap_buffer_up()
    swap_buffer('up')
end

function M.swap_buffer_down()
    swap_buffer('down')
end

function M.move_buffer_left()
    move_buffer('left')
end

function M.move_buffer_right()
    move_buffer('right')
end

function M.move_buffer_up()
    move_buffer('up')
end

function M.move_buffer_down()
    move_buffer('down')
end

function M.vsplit()
    local layout, _, column_nr = get_window_info(0)

    vim.cmd 'vsplit'

    if #layout[column_nr] == 1 then
        return
    end

    local new_window_id = vim.api.nvim_tabpage_get_win(0)
    vim.cmd 'wincmd H'

    local offset = vim.opt.splitright and 0 or -1
    restore_left(layout, column_nr + offset)

    vim.api.nvim_set_current_win(new_window_id)
end

return M
