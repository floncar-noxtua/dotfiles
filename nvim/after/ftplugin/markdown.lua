-- <CR> follows the link under the cursor: "#anchor" jumps to that heading in
-- this file, a relative path opens that file (at its anchor, if any), and a URL
-- goes to the system handler like gx. <C-o> jumps back.
vim.keymap.set("n", "<CR>", function()
  require("util.markdown").follow_link()
end, { buffer = true, desc = "Follow markdown link" })
