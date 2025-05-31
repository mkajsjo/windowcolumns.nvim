local tf = require('windowcolumns.table_functions')

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

local M = {}

function M.create()
    local columns = get_window_layout()
    local window_id = vim.api.nvim_tabpage_get_win(0)
    local column_index, row_index = get_window_index(columns, window_id)
    local window = columns[column_index][row_index]
    return {
        columns = columns,
        window = window,
        column_index = column_index,
        row_index = row_index,
        get_column = function(direction)
            local offset = direction == 'left' and -1 or direction == 'right' and 1 or 0
            return columns[column_index + offset]
        end,
        is_out_of_bounds = function(direction)
            if direction == 'left' then
                return column_index == 1
            elseif direction == 'right' then
                return column_index == #columns
            elseif direction == 'up' then
                return row_index == 1
            elseif direction == 'down' then
                return row_index == #columns[column_index]
            else
                vim.notify('Invalid direction: ' .. tostring(direction), vim.log.levels.WARN)
                return true
            end
        end,
    }
end

return M
