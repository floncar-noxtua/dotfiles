-- <CR> follows the link under the cursor: "#anchor" jumps to that heading in
-- this file, a relative path opens that file (at its anchor, if any), and a URL
-- goes to the system handler like gx. <C-o> jumps back.
vim.keymap.set("n", "<CR>", function()
  require("util.markdown").follow_link()
end, { buffer = true, desc = "Follow markdown link" })

-- gx opens the link with the system handler, with relative paths taken from
-- this file's folder (see util/markdown.lua for why the built-in one fails).
vim.keymap.set("n", "gx", function()
  require("util.markdown").open_link()
end, { buffer = true, desc = "Open link with system handler" })
