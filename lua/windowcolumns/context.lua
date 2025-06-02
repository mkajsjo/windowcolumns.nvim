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
            local width = vim.api.nvim_win_get_width(window_id)
            local height = vim.api.nvim_win_get_height(window_id)
            table.insert(result, {
                id = window_id,
                row = row,
                column = column,
                width = width,
                height = height,
            })
        end
    end
    return result
end

local function build_columns(windows)
    local top_row = tf.min(tf.map(windows, function(win) return win.row end))
    local top_windows = tf.filter(windows, function(win) return win.row == top_row end)
    local column_indexes = tf.flip_kv(tf.sort(tf.map(top_windows, function(win) return win.column end)))
    local column_widths = tf.map_kv(top_windows, function(_, win) return win.column, win.width end)

    local columns = {}
    local remaining = {}
    for _, win in ipairs(windows) do
        local column_index = column_indexes[win.column]
        local column_width = column_widths[win.column]
        if column_index and win.width >= column_width - 1 and win.width <= column_width + 1 then
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

local function get_window_index(columns, window_id)
    for c, column in ipairs(columns) do
        for r, window in ipairs(column) do
            if window.id == window_id then
                return c, r
            end
        end
    end
end

local function get_windows_in_columns(columns)
    local result = {}
    for _, column in ipairs(columns) do
        for _, window in ipairs(column) do
            table.insert(result, window)
        end
    end
    return result
end

local M = {}

function M.create()
    local window_id = vim.api.nvim_tabpage_get_win(0)

    local windows = get_windows()
    local ignored_windows = {}
    while #windows > 0 do
        local columns, remaining_windows = build_columns(windows)
        local column_index, row_index = get_window_index(columns, window_id)

        if column_index then
            return {
                columns = columns,
                window = columns[column_index][row_index],
                column_index = column_index,
                row_index = row_index,
                ignored_windows = ignored_windows,
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

        windows = remaining_windows
        ignored_windows = tf.concat(ignored_windows, get_windows_in_columns(columns))
    end

    vim.notify('Error: unable to find columns.', vim.log.levels.WARN)
end

return M
