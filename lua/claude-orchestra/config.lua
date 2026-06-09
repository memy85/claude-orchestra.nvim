local M = {}

M.defaults = {
  cmd = { "claude" },
  float = {
    width = 1.0,
    height = 1.0,
    border = "none",
    title_pos = "center",
    winblend = 0,
  },
  keymaps = {
    prefix = "<leader>c",
    new = "n",
    toggle = "a",
    switch = "l",
    kill = "k",
    rename = "r",
    next = "]",
    prev = "[",
    resume = "h",
  },
  auto_insert = true,
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
