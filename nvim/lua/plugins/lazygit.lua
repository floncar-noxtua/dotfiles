return {
  {
    "folke/snacks.nvim",
    opts = {
      lazygit = {
        config = {
          os = {
            -- Instead of the default "nvim-remote" preset (which opens the
            -- file in a *new tab* and leaves lazygit running in the background),
            -- leave terminal mode, close the lazygit float, then open the file
            -- in the window behind it — all in this same nvim instance.
            edit = 'nvim --server "$NVIM" --remote-send "<C-\\><C-n>:close<CR>:e {{filename}}<CR>"',
            editAtLine = 'nvim --server "$NVIM" --remote-send "<C-\\><C-n>:close<CR>:e +{{line}} {{filename}}<CR>"',
          },
        },
      },
    },
  },
}
