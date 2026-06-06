# claude-orchestra.nvim

Orchestrate multiple Claude Code CLI sessions inside Neovim. Spawn them in a fullscreen float, cycle between them, preview their transcripts with telescope, and resume past sessions.

Requires Neovim 0.10+, the `claude` CLI on `$PATH`, and (optionally) [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for the rich picker. Without telescope, the plugin falls back to `vim.ui.select`.

## Install (packer)

```lua
use {
  "memy85/claude-orchestra.nvim",
  config = function() require("claude-orchestra").setup({}) end,
}
```

For local development with a working copy at `~/projects/claude-orchestra.nvim`:

```lua
use {
  vim.fn.isdirectory(vim.fn.expand("~/projects/claude-orchestra.nvim")) == 1
    and "~/projects/claude-orchestra.nvim"
    or "memy85/claude-orchestra.nvim",
  config = function() require("claude-orchestra").setup({}) end,
}
```

## Commands

| Command | Description |
|---------|-------------|
| `:ClaudeNew [name]` | Spawn a new `claude` session in a fullscreen float. Optionally name it. |
| `:ClaudeToggle` | Show/hide the last-active session. |
| `:ClaudeSwitch [name]` | Open the picker (telescope or `vim.ui.select`). With a name, switch directly. |
| `:ClaudeNext` / `:ClaudePrev` | Cycle to the next/previous session in creation order. |
| `:ClaudeList` | Print the session list to `:messages`. |
| `:ClaudeRename [name]` | Rename the active session. Prompts if no argument. |
| `:ClaudeKill [name]` | Kill a session. Opens the picker if no argument. |
| `:ClaudeResume [id]` | Resume a past session for the current cwd. Opens the history picker if no argument. |
| `:ClaudeResume!` | Resume picker across **all** past projects (shows cwd column). |

## Default keymaps

All under the `<leader>c` prefix (mnemonic: **C**laude).

| Keys | Action |
|------|--------|
| `<leader>cn` | new session |
| `<leader>ca` | toggle the last-active session |
| `<leader>cs` | switch (picker) |
| `<leader>c]` / `<leader>c[` | next / previous session |
| `<leader>cl` | list sessions |
| `<leader>cr` | rename active session |
| `<leader>ck` | kill (picker) |
| `<leader>ch` | resume past session (history picker) |

### Inside the switch picker (telescope)

| Keys | Action |
|------|--------|
| `<CR>` | switch to the highlighted session |
| `<C-x>` (insert/normal) or `dd` (normal) | kill the highlighted session, list refreshes |
| `<C-r>` (insert/normal) or `r` (normal) | rename the highlighted session inline |

## Terminal-mode tip

When you're inside a Claude float, you're in terminal-insert mode and most keymaps are swallowed. Press `<C-\><C-n>` to drop into terminal-normal mode, then the `<leader>c*` keymaps work.

## Configuration

`setup({})` defaults — override any subset:

```lua
require("claude-orchestra").setup({
  cmd = { "claude" },              -- command used to launch a session
  float = {
    width = 1.0,                    -- 0–1 fraction of editor width
    height = 1.0,                   -- 0–1 fraction of editor height (minus cmdline/statusline)
    border = "none",                -- any nvim_open_win border style
    title_pos = "center",           -- only used when border ~= "none"
    winblend = 0,
  },
  auto_insert = true,               -- enter terminal-insert mode after spawn/show
  keymaps = {
    prefix = "<leader>c",
    new = "n",
    toggle = "a",
    switch = "s",
    kill = "k",
    list = "l",
    rename = "r",
    next = "]",
    prev = "[",
    resume = "h",
  },
})
```

Set any keymap field to `false` (or `""`) to disable just that binding.

## Resume

`:ClaudeResume` (or `<leader>ch`) reads `~/.claude/projects/<encoded-cwd>/*.jsonl` — the on-disk transcripts maintained by the `claude` CLI — and shows them in a telescope picker sorted newest-first. Selecting one spawns `claude --resume <session-id>` in a new float.

By default, only sessions whose recorded `cwd` matches Neovim's current working directory are listed (mirroring `claude --resume` behavior). Use `:ClaudeResume!` to browse sessions from every project — useful when you started a session from a terminal in a different directory.

## Status

Early-stage. Working: spawn, switch, cycle, picker preview, inline rename, resume from history. Not yet: cross-session merge, persistent named sessions across nvim restarts, custom telescope themes.
