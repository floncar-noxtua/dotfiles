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
        -- Autocommands do not nest by default, so the ColorScheme event that
        -- :colorscheme fires from in here would be swallowed and every plugin
        -- that repaints itself on ColorScheme (bufferline, lualine) would keep
        -- the old variant's colours.
        nested = true,
        callback = pick,
      })
    end,
  },

  -- LazyVim owns the initial colorscheme load; hand it the same chooser so
  -- startup picks the variant matching whatever the terminal already reported.
  { "LazyVim/LazyVim", opts = { colorscheme = pick } },

  -- bufferline paints its own highlights and repaints them on ColorScheme, but
  -- by default ('themable' = true) it defines them with :highlight default, so
  -- the repaint cannot overwrite groups that already exist. They do already
  -- exist: nightfox's compiled colorscheme only runs "hi clear" when
  -- vim.g.colors_name is set, and on this switch it is nil, so the previous
  -- variant's BufferLine* groups survive and win. Turning 'themable' off makes
  -- bufferline set them unconditionally. Nothing here themes bufferline, so
  -- there is nothing to give up.
  { "akinsho/bufferline.nvim", opts = { options = { themable = false } } },
}
