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

-- Reopen the PR diff for the current worktree (base branch is written by
-- the pr-worktree script into this worktree's git-dir).
vim.api.nvim_create_user_command("PRDiff", function()
  local git_dir = vim.fn.systemlist("git rev-parse --git-dir")[1]
  local f = io.open(git_dir .. "/PR_BASE", "r")
  if not f then
    vim.notify("No PR_BASE file - run pr-worktree/prw from this worktree first", vim.log.levels.ERROR)
    return
  end
  local base = f:read("*l")
  f:close()
  vim.cmd("DiffviewOpen origin/" .. base .. "...HEAD")
end, {})
