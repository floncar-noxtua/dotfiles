-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Toggle inline git blame
vim.keymap.set("n", "<leader>gb", "<cmd>Gitsigns toggle_current_line_blame<CR>", { desc = "Toggle git blame" })

-- Open fugitive git status
vim.keymap.set("n", "<leader>gs", "<cmd>Git<CR>", { desc = "Git status (fugitive)" })

-- Diff current file against index in a vertical split
vim.keymap.set("n", "<leader>gd", "<cmd>Gvdiffsplit<CR>", { desc = "Git diff current file" })

-- Browse commit history for current file
vim.keymap.set("n", "<leader>gl", "<cmd>0Gclog<CR>", { desc = "Git log for current file" })

-- Reopen the PR diff for the current worktree (see :PRDiff / pr-worktree)
vim.keymap.set("n", "<leader>gp", "<cmd>PRDiff<CR>", { desc = "Reopen PR diff" })

-- Toggle between nightfox and vscode themes
vim.g.current_theme = vim.g.current_theme or "nightfox"
vim.keymap.set("n", "<leader>tt", function()
	if vim.g.current_theme == "nightfox" then
		vim.cmd.colorscheme("vscode")
		vim.g.current_theme = "vscode"
	else
		vim.cmd.colorscheme("nightfox")
		vim.g.current_theme = "nightfox"
	end
end, { desc = "Toggle between nightfox and vscode themes" })

-- Copy current buffer file path to clipboard
vim.keymap.set("n", "<leader>yp", function()
	local filepath = vim.fn.expand("%:p")
	vim.fn.setreg("+", filepath)
	vim.notify("Copied: " .. filepath, vim.log.levels.INFO)
end, { desc = "Copy buffer file path" })

-- Copy the selected lines to clipboard, prefixed with an @-path + line range
-- header, for pasting into an LLM chat (the @ makes chat UIs attach the file).
vim.keymap.set("v", "<leader>yp", function()
	local filepath = vim.fn.expand("%:p")
	local start_line = vim.fn.line("v")
	local end_line = vim.fn.line(".")
	if start_line > end_line then
		start_line, end_line = end_line, start_line
	end
	-- Whole lines, not the exact charwise selection: the header talks in line
	-- numbers, and keeping the leading indentation matters for the LLM.
	local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
	local range = start_line == end_line and ("line: " .. start_line)
		or ("lines: " .. start_line .. "-" .. end_line)
	local header = "@" .. filepath .. " " .. range
	local body = table.concat(lines, "\n")
	-- Fence must be longer than the longest backtick run inside the snippet,
	-- or yanking from markdown / a docstring would close the block early.
	local longest = 0
	for run in body:gmatch("`+") do
		longest = math.max(longest, #run)
	end
	local fence = string.rep("`", math.max(3, longest + 1))
	-- Header outside the fence: it's metadata, and chat UIs only pick up the
	-- @path for file attachment when it's plain text.
	vim.fn.setreg(
		"+",
		table.concat({ header, fence .. vim.bo.filetype, body, fence, "" }, "\n")
	)
	-- Leave visual mode so it behaves like a normal yank.
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
	vim.notify("Copied: " .. header, vim.log.levels.INFO)
end, { desc = "Copy selection with file path + line numbers" })

-- Toggle blink.cmp's auto-popup while typing (see lua/plugins/blink.lua for
-- the vim.g.cmp_auto_show flag this reads/writes). Registered as a proper
-- Snacks toggle so it shows up in the <leader>u which-key group like
-- LazyVim's other ui toggles. "p" was already taken by LazyVim's mini.pairs
-- toggle (lazyvim/util/mini.lua), so this uses the free "y" slot instead.
Snacks.toggle
	.new({
		name = "Autocomplete Popup",
		get = function()
			return vim.g.cmp_auto_show
		end,
		set = function(state)
			vim.g.cmp_auto_show = state
			if not state then
				-- Hide it now instead of waiting for the next keystroke.
				require("blink.cmp").hide()
			end
		end,
	})
	:map("<leader>uy")
