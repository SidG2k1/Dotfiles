return {
  -- Kept: best-in-class git frontend. :G, :Gdiff, :Gblame, etc.
  {
    "tpope/vim-fugitive",
    cmd = { "G", "Git", "Gdiff", "Gblame", "Glog", "Gread", "Gwrite", "Gstatus" },
  },

  -- Replaces vim-gitgutter. Fully async, no rename-detection freeze.
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add          = { text = "+" },
        change       = { text = "~" },
        delete       = { text = "_" },
        topdelete    = { text = "‾" },
        changedelete = { text = "~" },
        untracked    = { text = "┆" },
      },
      on_attach = function(bufnr)
        local gs = require("gitsigns")
        local map = function(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = "Git: " .. desc })
        end
        map("n", "]c", function() gs.nav_hunk("next") end, "Next hunk")
        map("n", "[c", function() gs.nav_hunk("prev") end, "Prev hunk")
        map("n", "<leader>hs", gs.stage_hunk,   "Stage hunk")
        map("n", "<leader>hr", gs.reset_hunk,   "Reset hunk")
        map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
        map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line")
        map("n", "<leader>hd", gs.diffthis, "Diff against index")
      end,
    },
  },
}
