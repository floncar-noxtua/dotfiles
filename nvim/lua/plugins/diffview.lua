-- Toggle the "old" (left) diff pane between its normal width and minimized, so
-- the layout goes |files|old|new| -> |files||new| and back.
--
-- The width is saved per tabpage, since diffview opens each view in its own
-- tab. Setting the old window's width directly (rather than `wincmd |` /
-- `wincmd =`) takes space from the new window only, leaving the file panel at
-- its configured width.
local function toggle_old_pane()
  local view = require("diffview.lib").get_current_view()
  if not view or not view.cur_layout then
    return
  end

  local old, new = view.cur_layout.a, view.cur_layout.b
  if not (old and new and old:is_valid() and new:is_valid()) then
    return
  end

  local old_width = vim.api.nvim_win_get_width(old.id)
  local saved = vim.t.dv_old_width
  -- Selecting another file recreates the windows at equal widths, so confirm
  -- the pane really is still minimized before trusting the saved width.
  local minimized = saved and old_width * 2 < vim.api.nvim_win_get_width(new.id)

  if minimized then
    vim.t.dv_old_width = nil
    vim.api.nvim_win_set_width(old.id, saved)
  else
    vim.t.dv_old_width = old_width
    new:focus()
    vim.api.nvim_win_set_width(old.id, 0)
  end
end

local toggle_keymap = { "n", "<leader>dm", toggle_old_pane, { desc = "Diffview: minimize/restore old pane" } }

return {
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    opts = {
      keymaps = {
        view = { toggle_keymap },
        file_panel = { toggle_keymap },
        file_history_panel = { toggle_keymap },
      },
    },
  },
}
