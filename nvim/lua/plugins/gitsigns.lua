return {
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      -- Enable inline git blame on the current line
      current_line_blame = true,
      current_line_blame_opts = {
        -- Show blame text as virtual text (doesn't affect actual buffer)
        virt_text = true,
        -- Position blame text at end of line
        virt_text_pos = "eol",
        -- Delay in milliseconds before showing blame (1000ms = 1 second)
        delay = 1000,
      },
    },
  },
}
