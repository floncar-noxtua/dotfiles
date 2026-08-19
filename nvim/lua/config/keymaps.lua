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
