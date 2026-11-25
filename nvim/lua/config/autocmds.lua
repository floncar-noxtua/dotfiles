-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Make word-level diff changes and closed folds visually distinct,
-- regardless of colorscheme. Some themes (e.g. nightfox) give DiffChange
-- and Folded nearly identical backgrounds, so a changed line and a
-- collapsed context region look the same in diffview.nvim.
local function boost_diff_hl()
  vim.api.nvim_set_hl(0, "DiffText", { reverse = true, bold = true })
  vim.api.nvim_set_hl(0, "Folded", { bg = "NONE", italic = true })
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("diff_hl_contrast", { clear = true }),
  callback = boost_diff_hl,
})
-- This file loads on VeryLazy, after the initial colorscheme is already
-- applied, so apply once now too.
boost_diff_hl()

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

-- LazyVim's lazyvim_wrap_spell turns wrap back on for text, markdown and
-- gitcommit buffers. Replace it to keep spell but leave nowrap from options.lua.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("lazyvim_wrap_spell", { clear = true }),
  pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.spell = true
  end,
})

-- Dim the editor while its tmux pane is unfocused. tmux shades inactive panes
-- (tmux/theme-*.conf), but Nvim paints its own background over that, so it
-- darkens itself instead: every group that uses Normal's background gets a
-- darker one on FocusLost and its original definition back on FocusGained.
-- Needs `focus-events on` in tmux.
local FOCUS_DIM = 0.1 -- fraction to darken by

local function darken(rgb)
  local function ch(shift)
    return math.floor(bit.band(bit.rshift(rgb, shift), 0xff) * (1 - FOCUS_DIM) + 0.5)
  end
  return bit.bor(bit.lshift(ch(16), 16), bit.lshift(ch(8), 8), ch(0))
end

local dimmed -- name -> original definition, while unfocused

local function undim()
  for name, def in pairs(dimmed or {}) do
    vim.api.nvim_set_hl(0, name, def)
  end
  dimmed = nil
end

local function dim()
  if dimmed then
    return
  end
  local bg = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
  if not bg then
    return
  end
  dimmed = {}
  for name, def in pairs(vim.api.nvim_get_hl(0, {})) do
    if def.bg == bg and not def.link then
      dimmed[name] = def
      vim.api.nvim_set_hl(0, name, vim.tbl_extend("force", def, { bg = darken(bg) }))
    end
  end
end

local focus_group = vim.api.nvim_create_augroup("focus_dim", { clear = true })
vim.api.nvim_create_autocmd("FocusLost", { group = focus_group, callback = dim })
vim.api.nvim_create_autocmd("FocusGained", { group = focus_group, callback = undim })
-- A colorscheme load replaces every group, so the saved originals are stale.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = focus_group,
  callback = function()
    dimmed = nil
  end,
})
