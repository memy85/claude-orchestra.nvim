local M = {}

M.defaults = {
  cmd = { "claude" },
  float = {
    width = 0.85,
    height = 0.85,
    border = "rounded",
    title_pos = "center",
    winblend = 0,
  },
  keymaps = {
    prefix = "<leader>a",
    new = "n",
    toggle = "a",
    switch = "s",
    kill = "k",
    list = "l",
    rename = "r",
  },
  auto_insert = true,
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
