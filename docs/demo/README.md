# Recording the README screenshots

The screenshots under `docs/images/` are rendered with
[vhs](https://github.com/charmbracelet/vhs) from `screenshots.tape`.

## Re-recording

From the repo root:

```sh
vhs docs/demo/screenshots.tape
```

Outputs:

- `docs/images/list.png` — session list with live preview
- `docs/images/tabs.png` — tab mode with the session tabline
- `docs/images/resume.png` — resume picker over fake history

Telescope and plenary are loaded from `$CO_PLUGIN_DIR` (default: the packer
start directory). The tape runs with a fake `$HOME` under `/tmp`, so the
resume picker never shows your real transcripts.

## How the demo stays deterministic

The real `claude` CLI is replaced by `mock-claude.sh`, a tiny script
that prints a fixed colored transcript and then loops on `read`. The
plugin is wired to it via `cmd = { ".../mock-claude.sh" }` in
`init.lua`, so `:ClaudeNew` spawns the mock instead of the real CLI.
`fake-history.sh` writes the fake transcripts for the resume picker.

Edit `mock-claude.sh` to change the fake transcript, `init.lua` to
change the colorscheme / keymaps, and `screenshots.tape` to change the
keystroke timeline.
