-- Light/dark is driven by the terminal, not by this file.
--
-- Ghostty switches theme with the macOS appearance and notifies everything
-- inside it over DEC mode 2031; tmux relays that to its panes; Nvim re-queries
-- the background colour with OSC 11 and updates 'background' on its own.
-- All this config does is say which colorscheme goes with which background.
--
-- Do NOT set vim.o.background anywhere: setting it marks the option as
-- user-set, and Nvim then permanently disables the automatic detection.

-- nightfox ships its light and dark variants as separate colorschemes, so the
-- mapping has to be explicit.
local function pick()
  local want = vim.o.background == "light" and "dawnfox" or "nightfox"
  -- Changing 'background' reloads the colorscheme and a colorscheme may set
  -- 'background' itself, so guard against the two bouncing off each other.
  if vim.g.colors_name ~= want then
    vim.cmd.colorscheme(want)
  end
end

return {
  {
    "EdenEast/nightfox.nvim",
    lazy = false,
    priority = 1000,
    init = function()
      -- Fires when the terminal tells Nvim the theme flipped.
      vim.api.nvim_create_autocmd("OptionSet", {
        pattern = "background",
        group = vim.api.nvim_create_augroup("theme_sync", { clear = true }),
        callback = pick,
      })
    end,
  },

  -- LazyVim owns the initial colorscheme load; hand it the same chooser so
  -- startup picks the variant matching whatever the terminal already reported.
  { "LazyVim/LazyVim", opts = { colorscheme = pick } },
}
