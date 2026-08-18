-- blink.cmp is pulled in automatically by LazyVim's default `coding.blink`
-- extra (see lazy-lock.json) even though it's not listed in lazyvim.json.
-- This file only overrides the auto-show behavior; everything else (keymap
-- preset, sources, ghost text, etc) still comes from LazyVim's stock config.

-- Controls whether the completion menu pops up automatically while typing.
-- Toggled at runtime via <leader>uy (see lua/config/keymaps.lua).
vim.g.cmp_auto_show = true

return {
  "saghen/blink.cmp",
  opts = {
    completion = {
      menu = {
        -- Gate auto-show on vim.g.cmp_auto_show instead of always `true`.
        -- Manual trigger (e.g. <C-space>) still works regardless, since it
        -- calls show() directly and isn't governed by this setting.
        auto_show = function()
          return vim.g.cmp_auto_show
        end,
      },
    },
  },
}
