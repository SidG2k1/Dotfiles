return {
  -- Jsonnet filetype + syntax. Kept from your existing bundle.
  { "google/vim-jsonnet", ft = { "jsonnet", "libsonnet" } },

  -- Thesaurus lookup via ;th mapping (defined in ~/.vimrc).
  {
    "ron89/thesaurus_query.vim",
    cmd = { "ThesaurusQueryReplaceCurrentWord", "Thesaurus" },
    keys = { ";th" },
  },

  -- plenary is a shared dep for many modern plugins; keep available.
  { "nvim-lua/plenary.nvim", lazy = true },
}
