return {
  -- Kept from your existing bundle — migrated to lazy specs.
  { "tpope/vim-commentary", event = "VeryLazy" },
  { "easymotion/vim-easymotion", event = "VeryLazy" },
  { "godlygeek/tabular", cmd = "Tabularize" },

  -- New: surround text with quotes/brackets/tags. ys<motion><char>, ds<char>, cs<old><new>.
  {
    "kylechui/nvim-surround",
    event = "VeryLazy",
    opts = {},
  },

  -- New: file explorer as an editable buffer. Hit "-" to open the parent dir.
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    lazy = false,
    opts = {
      view_options = { show_hidden = true },
    },
    keys = {
      { "-", "<cmd>Oil<cr>", desc = "Open parent directory (oil)" },
    },
  },
}
