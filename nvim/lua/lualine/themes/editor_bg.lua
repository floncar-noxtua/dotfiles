-- The colorscheme's own lualine theme, with its darker fill (section c and the
-- inactive statusline) moved onto the editor background. The mode block and
-- section b keep their colours.
--
-- lualine dofile()s this on every ColorScheme, so it follows the light/dark
-- switch in plugins/themes.lua.
local loader = require("lualine.utils.loader")
local ok, theme = pcall(loader.load_theme, vim.g.colors_name or "")
if not ok then
  theme = loader.load_theme("auto")
end

local editor_bg = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
local fill = theme.normal and theme.normal.c and theme.normal.c.bg
if editor_bg and fill then
  editor_bg = string.format("#%06x", editor_bg)
  for _, sections in pairs(theme) do
    for _, color in pairs(sections) do
      if type(color) == "table" and color.bg == fill then
        color.bg = editor_bg
      end
    end
  end
end

return theme
