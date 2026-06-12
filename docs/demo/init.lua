-- Minimal nvim config used by docs/demo/grid.tape.
-- Launches via `nvim --noplugin -u init.lua` so no other plugins load.
-- The tape exports CO_DEMO_DIR and CO_REPO_ROOT before launching.

vim.g.mapleader = " "
vim.o.termguicolors = true
vim.o.laststatus = 0
vim.o.showmode = false
vim.o.ruler = false
vim.o.number = false
vim.o.signcolumn = "no"
pcall(vim.cmd, "colorscheme slate")

local demo_dir = assert(os.getenv("CO_DEMO_DIR"), "CO_DEMO_DIR not set")
local repo_root = assert(os.getenv("CO_REPO_ROOT"), "CO_REPO_ROOT not set")
vim.opt.runtimepath:prepend(repo_root)

vim.cmd("runtime! plugin/claude-orchestra.lua")

vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { silent = true })

require("claude-orchestra").setup({
  cmd = { demo_dir .. "/mock-claude.sh" },
  auto_insert = true,
})
