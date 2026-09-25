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
  -- Disabled by default: `identify` crashes on some broken/remote images.
  -- Toggle at runtime with :ImageToggle.
  {
    "3rd/image.nvim",
    opts = {
      backend = "kitty",
      processor = "magick_cli",
      integrations = {
        markdown = { enabled = true, filetypes = { "markdown" } },
      },
    },
    config = function(_, opts)
      local image = require("image")
      image.setup(opts)
      image.disable()

      vim.api.nvim_create_user_command("ImageToggle", function()
        if image.is_enabled() then
          image.disable()
          vim.notify("image.nvim disabled")
        else
          image.enable()
          vim.notify("image.nvim enabled")
        end
      end, { desc = "Toggle image.nvim inline image rendering" })
    end,
  },
}
