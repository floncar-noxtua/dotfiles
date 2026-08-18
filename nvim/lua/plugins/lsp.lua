return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        pyright = {
          enabled = true,
          settings = {
            python = {
              analysis = {
                typeCheckingMode = "standard",
              },
            },
          },
          before_init = require("util.pyright").before_init,
        },
      },
    },
  },
}
