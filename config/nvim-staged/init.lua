-- Bootstrap lazy.nvim (stock install snippet)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Leader must be set before plugins load (plugins bake keymaps at setup time).
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Keep ~/.vim on runtimepath so templates, spellfiles, and anything else in
-- there still work.
vim.opt.runtimepath:prepend(vim.fn.expand("~/.vim"))
vim.opt.runtimepath:append(vim.fn.expand("~/.vim/after"))

-- Load plugin specs from lua/plugins/*.lua (lazy.nvim convention).
require("lazy").setup("plugins", {
  change_detection = { notify = false },
  install = { colorscheme = { "habamax" } },
})

-- Diagnostics UI — inline virtual text + signs + float on CursorHold.
vim.diagnostic.config({
  virtual_text = { spacing = 2, prefix = "●" },
  severity_sort = true,
  float = { border = "rounded", source = "if_many" },
  signs = true,
  underline = true,
  update_in_insert = false,
})

-- Source the existing vimrc for non-plugin settings (mappings, filetype
-- tricks, autocmds). Pathogen call and syntastic/airline blocks have been
-- removed from vimrc as part of this migration.
vim.cmd("source ~/.vimrc")
