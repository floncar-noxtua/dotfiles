-- Lighten the lazygit float's background.
--
-- The float paints itself with NormalFloat, which on dawnfox is bg0 (#ebe5df) --
-- a shade *darker* than the editor's own background, bg1 (#faf4ed). Against
-- dawnfox's muted foreground that leaves the whole TUI looking washed out.
-- On a light background, start from the editor background and lift it towards
-- white instead. Dark variants already separate cleanly, so they keep
-- NormalFloat untouched.

-- How far to pull the light background towards white: 0 keeps the editor
-- background, 1 goes fully white. Turn this up if lazygit still reads flat.
local LIGHTEN = 0.35

---@param rgb integer 24-bit colour as returned by nvim_get_hl
---@param amount number 0..1, fraction of the way to white
local function lighten(rgb, amount)
  local r, g, b = math.floor(rgb / 65536) % 256, math.floor(rgb / 256) % 256, rgb % 256
  local function lift(c)
    return math.floor(c + (255 - c) * amount + 0.5)
  end
  return ("#%02x%02x%02x"):format(lift(r), lift(g), lift(b))
end

local function set_lazygit_hl()
  local float = vim.api.nvim_get_hl(0, { name = "NormalFloat", link = false })
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  local bg = float.bg
  if vim.o.background == "light" and (normal.bg or float.bg) then
    bg = lighten(normal.bg or float.bg, LIGHTEN)
  end
  vim.api.nvim_set_hl(0, "LazygitNormal", { fg = float.fg, bg = bg })
end

return {
  {
    "folke/snacks.nvim",
    init = function()
      -- The colorscheme wipes highlights, so re-derive on every switch. Our
      -- OptionSet handler in themes.lua is nested, so this does fire on a
      -- light/dark flip.
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("lazygit_hl", { clear = true }),
        callback = set_lazygit_hl,
      })
      set_lazygit_hl()
    end,
    opts = {
      styles = {
        lazygit = {
          wo = {
            -- Same mapping snacks uses by default, with Normal/NormalNC
            -- pointed at our lightened group instead of SnacksNormal.
            winhighlight = table.concat({
              "Normal:LazygitNormal",
              "NormalNC:LazygitNormal",
              "WinBar:SnacksWinBar",
              "WinBarNC:SnacksWinBarNC",
              "FloatTitle:SnacksTitle",
              "FloatFooter:SnacksFooter",
              "WinSeparator:SnacksWinSeparator",
            }, ","),
          },
        },
      },
      lazygit = {
        config = {
          os = {
            -- Instead of the default "nvim-remote" preset (which opens the
            -- file in a *new tab* and leaves lazygit running in the background),
            -- leave terminal mode, close the lazygit float, then open the file
            -- in the window behind it — all in this same nvim instance.
            edit = 'nvim --server "$NVIM" --remote-send "<C-\\><C-n>:close<CR>:e {{filename}}<CR>"',
            editAtLine = 'nvim --server "$NVIM" --remote-send "<C-\\><C-n>:close<CR>:e +{{line}} {{filename}}<CR>"',
          },
        },
      },
    },
  },
}
