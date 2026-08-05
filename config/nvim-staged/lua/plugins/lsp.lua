return {
  -- Auto-install language servers into nvim's data dir.
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    opts = {
      ui = { border = "rounded" },
    },
  },

  -- Bridge between mason and lspconfig (auto-setup installed servers).
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    opts = {
      ensure_installed = {
        "lua_ls",
        "bashls",
        "basedpyright",
        "rust_analyzer",
      },
      automatic_installation = true,
    },
  },

  -- Language server client config + keymaps on attach.
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local buf = args.buf
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = buf, desc = "LSP: " .. desc })
          end
          map("gd",         vim.lsp.buf.definition,       "Go to definition")
          map("gD",         vim.lsp.buf.declaration,      "Go to declaration")
          map("gi",         vim.lsp.buf.implementation,   "Go to implementation")
          map("gr",         vim.lsp.buf.references,       "References")
          map("gy",         vim.lsp.buf.type_definition,  "Type definition")
          map("K",          vim.lsp.buf.hover,            "Hover docs")
          map("<leader>rn", vim.lsp.buf.rename,           "Rename symbol")
          map("<leader>ca", vim.lsp.buf.code_action,      "Code action")
          map("<leader>f",  function() vim.lsp.buf.format({ async = true }) end, "Format buffer")
          map("[d",         function() vim.diagnostic.jump({ count = -1 }) end,  "Prev diagnostic")
          map("]d",         function() vim.diagnostic.jump({ count = 1 }) end,   "Next diagnostic")
          map("<leader>e",  vim.diagnostic.open_float,    "Show diagnostic")
          map("<leader>q",  vim.diagnostic.setloclist,    "Diagnostics to loclist")
        end,
      })
    end,
  },

  -- Subtle bottom-right spinner for LSP progress (metals/rust-analyzer indexing).
  {
    "j-hui/fidget.nvim",
    event = "LspAttach",
    opts = {
      notification = { window = { winblend = 0 } },
    },
  },
}
