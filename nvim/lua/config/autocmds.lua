-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

vim.api.nvim_create_user_command("Fxml", function()
  vim.cmd("!/Users/fran/dotfiles/bin/format-xml %")
  vim.cmd("e")
end, {})

vim.api.nvim_create_user_command("Fjson", function()
  vim.cmd("!/Users/fran/dotfiles/bin/format-json %")
  vim.cmd("e")
end, {})
