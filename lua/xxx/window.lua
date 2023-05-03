local t = require('xxx.tree')
local c
local Split = require("nui.split")

local W = {
    bufw = nil,
    buff = nil,

    bufwh = 0,
    bufww = 0,

    bufnrw = nil,

    hl_cursorline_name = "hl_hierarchy_csl",
    hl_current_module = "hl_hierarchy_c_m",
    hl_others_module = "hl_hierarchy_o_m",

    position = "bottom_right"
}

function W.setup()
    c = require("xxx.config").get_data()
end

function W.create_window()
    if W.bufnrw == nil then
        W.bufnrw = vim.api.nvim_get_current_win()
    end

    if W.buff == nil then
        W.buff = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_keymap(W.buff, "n", c.keymap.expand, ":lua require'hierarchy-tree-go'.expand()<cr>",
            { silent = true })
        vim.api.nvim_buf_set_keymap(W.buff, "n", c.keymap.jump, ":lua require'hierarchy-tree-go'.jump()<cr>",
            { silent = true })
        vim.api.nvim_buf_set_keymap(W.buff, "n", c.keymap.move, ":lua require'hierarchy-tree-go'.move()<cr>",
            { silent = true })

        vim.api.nvim_buf_set_option(W.buff, "filetype", "hierarchy-tree-go")
        vim.api.nvim_buf_set_name(W.buff, "HIERARCHY-TREE-GO")
    end

    local ew = vim.api.nvim_get_option("columns")

	W.bufww = math.floor(ew / 4)

    if W.bufw == nil or not vim.api.nvim_win_is_valid(W.bufw) then
		local split = Split({
			relative = "editor",
			position = "right",
			size = W.bufww,
		})
		split:map("n", "q", function()
			split:unmount()
		end, { noremap = true })

		split:mount()

		W.bufw = split.winid
		vim.api.nvim_win_set_option(W.bufw, "scl", "no")
        vim.api.nvim_win_set_option(W.bufw, "cursorline", true)
        vim.api.nvim_win_set_option(W.bufw, "wrap", false)
        vim.api.nvim_win_set_buf(W.bufw, W.buff)
    end

    W.write_line()

	vim.cmd("syntax match Number /" .. c.icon.fold .. "/")
	vim.cmd("syntax match Character /" .. c.icon.unfold .. "/")
	vim.cmd("syntax match Function /].*:/hs=s+1,he=e-1")
	vim.cmd([[:syntax match Type ?[a-zA-Z/_]\+.go?]])
end

function W.write_line()
    vim.api.nvim_buf_set_option(W.buff, "modifiable", true)

    local nodes = t.get_lines()
    if nodes == nil then
        return
    end

    local fmt_lines = {}
    local cwd = vim.fn.getcwd()


    for _, node in ipairs(nodes) do
        local fold_icon = c.icon.fold

        if node.status == "open" then
            fold_icon = c.icon.unfold
            if #node.children == 0 then
                fold_icon = c.icon.last
            end
        end

        local kind_icon = c.icon.func
        if node.kind ~= 12 then
            kind_icon = node.kind
        end

        local filename = string.sub(node.uri, 8)
        if string.sub(filename, 1, #cwd) ~= cwd then -- others modules
            filename = node.detail
        else
            filename = string.sub(filename, #cwd + 2)
        end

        local symbol = string.format("%s%s [%s]%s", string.rep("  ", node.level), fold_icon, kind_icon, node.name)
        local line = symbol .. string.rep(" ", math.floor(W.bufww / 2.5) - #symbol) .. ":" .. filename

        table.insert(fmt_lines, line)
    end

    vim.api.nvim_buf_set_lines(W.buff, 0, -1, false, {})
    vim.api.nvim_buf_set_lines(W.buff, 0, #fmt_lines, false, fmt_lines)

    vim.api.nvim_set_current_win(W.bufw)
    vim.api.nvim_buf_set_option(W.buff, "modifiable", false)
end

function W.jump(node)
    local filename = string.sub(node.uri, 8)
    vim.api.nvim_set_current_win(W.bufnrw)

    local fn = function(cmd)
        vim.cmd(cmd .. filename)
        vim.cmd("execute  \"normal! " .. (node.range.start.line + 1) .. "G\"")
        vim.cmd("execute  \"normal! zz\"")
    end

    for _, id in pairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(id)
        if vim.loop.fs_stat(vim.api.nvim_buf_get_name(buf)) then
            vim.api.nvim_set_current_win(id)
            fn("e ")
            return
        end
    end
end

function W.focus()
    if W.bufw == nil then -- open
        W.create_window()
        return
    end

    if W.bufw ~= nil and vim.api.nvim_win_is_valid(W.bufw) then
        if vim.api.nvim_get_current_win() ~= W.bufw then -- focus
            vim.api.nvim_set_current_win(W.bufw)
        else
            W.close()
        end
    end
end

function W.close()
    if vim.api.nvim_win_is_valid(W.bufw) then
        vim.api.nvim_win_close(W.bufw, true)
    end

    W.bufw = nil
end

function W.open()
    if W.buff ~= nil then
        if W.bufw ~= nil and vim.api.nvim_win_is_valid(W.bufw) then
            return
        end
        W.create_window()
    end
end

function W.move()
    local line = vim.api.nvim_exec("echo line('.')", true)
    if W.position == "bottom_right" then
        W.position = "center"
    else
        W.position = "bottom_right"
    end

    W.close()
    W.create_window()

    vim.cmd("execute  \"normal! " .. line .. "G\"")
end

return W
