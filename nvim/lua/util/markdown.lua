-- Following markdown links, GitHub-flavored: anchors are slugged the way
-- GitHub slugs its heading permalinks, which is the convention these notes
-- follow. render-markdown.nvim only draws links; it never follows them, and
-- Neovim's built-in gx resolves the destination correctly but then hands it
-- to the system opener, which cannot do anything with a bare "#anchor". This
-- fills that gap: in-file anchors, relative files, and a fall-through to gx
-- for everything that really is a URL.

local M = {}

-- GitHub's anchor slug: lowercase, drop anything that is not a word character,
-- space, hyphen or underscore (which also strips the ** of a bold heading),
-- then spaces become hyphens.
local function slugify(heading)
  return (heading:lower():gsub("[^%w%s%-_]", ""):gsub("%s+", "-"))
end

-- Line number of the heading `anchor` points at, or nil. Walks headings and
-- slugs them in one pass (no need to materialize a list first). Skips fenced
-- code blocks so a `# comment` in a shell block can't shadow a real heading,
-- and tracks the "-1", "-2" suffixes GitHub appends to repeated headings.
local function find_anchor(bufnr, anchor)
  local seen, fence = {}, nil
  for lnum, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    local marker = line:match("^%s*(```+)") or line:match("^%s*(~~~+)")
    if fence then
      if marker and marker:sub(1, 1) == fence:sub(1, 1) and #marker >= #fence then
        fence = nil
      end
    elseif marker then
      fence = marker
    else
      -- Closed ATX headings ("## Foo ##") keep only the text.
      local text = line:match("^#+%s+(.-)%s*#*%s*$")
      if text then
        local slug = slugify(text)
        seen[slug] = (seen[slug] or 0) + 1
        local unique = seen[slug] == 1 and slug or (slug .. "-" .. (seen[slug] - 1))
        if unique == anchor then
          return lnum
        end
      end
    end
  end
end

--- Follow the link under the cursor. Anything that is not an inline markdown
--- link falls through to gx, so this can own the keymap on its own.
--- Inline links only: reference-style links are resolved by their definition
--- elsewhere in the file, which is a different lookup and rare enough in
--- notes to skip.
function M.follow_link()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local dest, init = nil, 1
  while true do
    local from, to, d = line:find("%[[^%]]*%]%(([^)]*)%)", init)
    if not from then
      break
    end
    if col >= from and col <= to then
      dest = (d:gsub("%s+['\"(].*$", "")) -- drop an optional link title
      break
    end
    init = to + 1
  end

  if not dest or dest == "" then
    return vim.cmd.normal({ "gx" })
  end

  local path, anchor = dest:match("^([^#]*)#(.*)$")
  if not path then
    path, anchor = dest, nil
  end

  if path:match("^%a[%w+.-]*://") or path:match("^mailto:") then
    return vim.ui.open(dest)
  end

  vim.cmd("normal! m'") -- so <C-o> comes back, whether or not we change buffer

  if path ~= "" then
    local file = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
    if vim.startswith(path, ".") or not vim.startswith(path, "/") then
      file = vim.fs.normalize(vim.fs.joinpath(vim.fn.expand("%:p:h"), path))
    end
    -- Wiki-style links leave the extension off.
    if vim.fn.filereadable(file) == 0 and vim.fn.filereadable(file .. ".md") == 1 then
      file = file .. ".md"
    end
    if vim.fn.filereadable(file) == 0 then
      return vim.notify("No such file: " .. file, vim.log.levels.WARN)
    end
    vim.cmd.edit(vim.fn.fnameescape(file))
  end

  if anchor and anchor ~= "" then
    local lnum = find_anchor(0, vim.uri_decode(anchor):lower())
    if not lnum then
      return vim.notify("No heading for anchor: #" .. anchor, vim.log.levels.WARN)
    end
    vim.api.nvim_win_set_cursor(0, { lnum, 0 })
    vim.cmd("normal! zz")
  end
end

return M
