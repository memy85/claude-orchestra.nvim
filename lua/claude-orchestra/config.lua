local M = {}

M.defaults = {
  cmd = { "claude" },
  keymaps = {
    prefix = "<leader>c",
    new = "n",
    switch = "l",
    kill = "k",
    rename = "r",
    next = "]",
    prev = "[",
    resume = "h",
    tab_next = "<C-Tab>",   -- tab mode only; works in normal + terminal mode
    tab_prev = "<C-S-Tab>",
  },
  auto_insert = true,
  open_in = "buffer", -- "buffer" (current window) or "tab" (one tabpage per session)
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
