return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.nvim' },
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = { enabled = false },
  },

  -- Paste clipboard images into the current note, saved next to it.
  {
    "HakonHarnes/img-clip.nvim",
    event = "VeryLazy",
    opts = {
      default = {
        dir_path = ".", -- save alongside the current file (folder-per-note layout)
        relative_to_current_file = true,
      },
    },
    keys = {
      { "<leader>p", "<cmd>PasteImage<cr>", desc = "Paste image from clipboard", ft = "markdown" },
    },
  },

  -- Render markdown images inline in the buffer (needs Kitty-graphics-protocol
  -- terminal like Ghostty, plus `imagemagick` installed on the system).
  {
    "3rd/image.nvim",
    opts = {
      backend = "kitty",
      processor = "magick_cli",
      integrations = {
        markdown = { enabled = true, filetypes = { "markdown" } },
      },
    },
  },
}
