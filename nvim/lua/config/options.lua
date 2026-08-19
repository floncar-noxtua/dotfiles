-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Better diff hunks (histogram) and word-level highlighting within changed
-- lines (linematch) - default diffopt only highlights whole changed lines.
vim.opt.diffopt:append("algorithm:histogram")
vim.opt.diffopt:append("linematch:60")
