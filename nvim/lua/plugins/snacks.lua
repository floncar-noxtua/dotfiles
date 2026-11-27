return {
  {
    "folke/snacks.nvim",
    opts = {
      -- Disable notification for bigfile detection, increase line_length threshold
      -- Default: size=1.5MB, line_length=1000 chars. Single-line XML/JSON files would trigger warning
      -- See: https://github.com/folke/snacks.nvim/blob/main/docs/bigfile.md
      bigfile = {
        enabled = true,
        size = 1.5 * 1024 * 1024,
        line_length = 20000,
        notify = false,
      },
      -- show hidden and gitignored files/folders by default in the explorer,
      -- fuzzy finder (<leader>ff) and grep (<leader>sg) pickers.
      -- toggle at runtime with H/I in the explorer, or <A-h>/<A-i> in other pickers
      picker = {
        sources = {
          explorer = {
            hidden = true,
            ignored = true,
            -- Draw the tree on the editor background instead of NormalFloat's
            -- darker one. Snacks merges user `win.*.wo` under its own
            -- winhighlight, and the layout rebuilds each pane's options from
            -- layout.win_opts on every update, so the override goes on once the
            -- windows exist and into win_opts so it survives resizes.
            on_show = function(picker)
              local to_editor = { Normal = "Normal", NormalNC = "Normal", NormalFloat = "Normal" }
              local function apply(win, saved)
                for _, opts in ipairs({ win.opts, saved }) do
                  if opts then
                    opts.wo = opts.wo or {}
                    opts.wo.winhighlight = Snacks.util.winhl(opts.wo.winhighlight or "", to_editor)
                  end
                end
                if win:valid() then
                  Snacks.util.wo(win.win, { winhighlight = win.opts.wo.winhighlight })
                end
              end
              local layout = picker.layout
              apply(layout.root)
              for name, win in pairs(layout.wins) do
                apply(win, layout.win_opts[name])
              end
            end,
          },
          files = {
            hidden = true,
            ignored = true,
          },
          grep = {
            hidden = true,
            ignored = true,
          },
        },
        -- <A-h> for toggle_hidden collides with AeroSpace's global "alt-h = focus left"
        -- window-manager shortcut, which swallows the keypress before it reaches the
        -- terminal. <C-A-h>/<C-A-i> are not bound in aerospace.toml, so use those too.
        win = {
          input = {
            keys = {
              ["<C-A-h>"] = { "toggle_hidden", mode = { "i", "n" } },
              ["<C-A-i>"] = { "toggle_ignored", mode = { "i", "n" } },
            },
          },
        },
      },
    },
  },
}
