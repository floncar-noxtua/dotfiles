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

-- Open the full diff of a PR in a new diffview tab, as `prw` does, without a
-- worktree or checkout.
--   :PRDiff      PR of the current branch, diffed against HEAD (local code,
--                so LSP and unpushed commits are included)
--   :PRDiff 123  any PR, diffed against its head commit on GitHub
-- Without gh (offline, no PR), it falls back to the PR_BASE file the
-- pr-worktree script writes into a prw worktree's git-dir.
local function pr_diff_from_pr_base()
  local git_dir = vim.fn.systemlist("git rev-parse --git-dir")[1]
  local f = git_dir and io.open(git_dir .. "/PR_BASE", "r")
  if not f then
    return false
  end
  local base = f:read("*l")
  f:close()
  vim.cmd("DiffviewOpen origin/" .. base .. "...HEAD")
  return true
end

vim.api.nvim_create_user_command("PRDiff", function(opts)
  local pr = opts.args ~= "" and opts.args or nil
  local view = { "gh", "pr", "view", "--json", "number,baseRefName,headRefOid" }
  if pr then
    table.insert(view, 4, pr)
  end

  vim.notify("PRDiff: looking up " .. (pr and ("PR #" .. pr) or "PR for current branch") .. "...")
  vim.system(view, { text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        if not pr and pr_diff_from_pr_base() then
          return
        end
        vim.notify("PRDiff: gh pr view failed: " .. vim.trim(res.stderr), vim.log.levels.ERROR)
        return
      end

      local info = vim.json.decode(res.stdout)
      local base = info.baseRefName
      -- Fetch the base so origin/<base> is current; for another PR also fetch
      -- its head so the headRefOid commit exists locally.
      local fetch = { "git", "fetch", "origin", base }
      if pr then
        table.insert(fetch, "pull/" .. info.number .. "/head")
      end

      vim.notify("PRDiff: fetching origin/" .. base .. "...")
      vim.system(fetch, { text = true }, function(fres)
        vim.schedule(function()
          if fres.code ~= 0 then
            vim.notify("PRDiff: git fetch failed: " .. vim.trim(fres.stderr), vim.log.levels.ERROR)
            return
          end
          local head = pr and info.headRefOid or "HEAD"
          vim.cmd(("DiffviewOpen origin/%s...%s"):format(base, head))
        end)
      end)
    end)
  end)
end, { nargs = "?", desc = "Open the PR diff (current branch or PR number) in diffview" })

-- Open the whole commit that last changed the cursor line in a new diffview
-- tab. Blames the buffer's current contents, so unsaved edits above the
-- cursor don't shift the line onto the wrong commit.
vim.api.nvim_create_user_command("CommitDiff", function()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("CommitDiff: buffer has no file", vim.log.levels.ERROR)
    return
  end
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local contents = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n") .. "\n"
  local cmd = { "git", "blame", "--porcelain", "-L", line .. "," .. line, "--contents", "-", "--", file }

  vim.system(cmd, { text = true, stdin = contents, cwd = vim.fs.dirname(file) }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        vim.notify("CommitDiff: git blame failed: " .. vim.trim(res.stderr), vim.log.levels.ERROR)
        return
      end
      local sha = res.stdout:match("^(%x+)")
      if not sha or sha:match("^0+$") then
        vim.notify("CommitDiff: line is not committed yet", vim.log.levels.WARN)
        return
      end
      local summary = res.stdout:match("\nsummary ([^\n]*)") or ""
      vim.notify(("CommitDiff: %s %s"):format(sha:sub(1, 8), summary))
      vim.cmd("DiffviewOpen " .. sha .. "^!")
    end)
  end)
end, { desc = "Open the commit that last changed the cursor line in diffview" })

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
