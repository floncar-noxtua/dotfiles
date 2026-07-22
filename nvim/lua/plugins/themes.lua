return {
	{
		"EdenEast/nightfox.nvim",
		priority = 1000,
		config = function()
			vim.cmd.colorscheme("nightfox")
		end,
	},
	{
		"mofiqul/vscode.nvim",
		config = function()
			require("vscode").setup({
				style = "light",
			})
		end,
	},
}
