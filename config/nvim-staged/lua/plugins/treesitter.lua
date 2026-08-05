return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").install({
        "bash", "c", "cpp", "go", "jsonnet", "lua", "markdown",
        "markdown_inline", "python", "rust", "scala", "vim", "vimdoc",
      })

      vim.api.nvim_create_autocmd("FileType", {
        pattern = {
          "sh", "bash", "c", "cpp", "go", "jsonnet", "lua", "markdown",
          "python", "rust", "scala", "vim", "help",
        },
        callback = function()
          vim.treesitter.start()
          vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },
}
