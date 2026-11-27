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

-- Sum the additions/deletions of every file below a "directory" component,
-- appending the totals to each directory row it passes, collapsed or not.
local function add_dir_stats(comp)
  if comp.name == "file" then
    local stats = comp.context.stats
    if stats and stats.additions then
      return stats.additions, stats.deletions or 0
    end
    return nil
  end

  local add, del
  for _, child in ipairs(comp.components or {}) do
    local a, d = add_dir_stats(child)
    if a then
      add, del = (add or 0) + a, (del or 0) + d
    end
  end

  -- A directory renders its row into its first child ("dir_name"), one line.
  local row = comp.name == "directory" and comp.components[1]
  if add and row and #row.lines == 1 then
    local line = row.lines[1]
    local a_txt, d_txt = " " .. add, tostring(del)
    row:add_hl("DiffviewFilePanelInsertions", 0, #line, #line + #a_txt)
    row:add_hl("DiffviewFilePanelDeletions", 0, #line + #a_txt + 2, #line + #a_txt + 2 + #d_txt)
    row.lines[1] = line .. a_txt .. ", " .. d_txt
  end
  return add, del
end

-- diffview renders folder rows in a local function, so wrap the whole render
-- module (FilePanel:render requires it on every call) and post-process.
local function patch_dir_stats()
  local mod = "diffview.scene.views.diff.render"
  local render = require(mod)
  package.loaded[mod] = function(panel)
    render(panel)
    if panel.render_data then
      for _, comp in ipairs(panel.render_data.components) do
        add_dir_stats(comp)
      end
    end
  end
end

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
    config = function(_, opts)
      require("diffview").setup(opts)
      patch_dir_stats()
    end,
  },
}
