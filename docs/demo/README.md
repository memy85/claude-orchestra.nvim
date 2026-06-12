# Recording the demo assets

The hero GIF and screenshot under `docs/` are rendered with
[vhs](https://github.com/charmbracelet/vhs) from `grid.tape`.

## Re-recording

From the repo root:

```sh
vhs docs/demo/grid.tape
```

Outputs:

- `docs/grid.gif` — animated hero, embedded at the top of the main README
- `docs/grid.png` — still of the grid view at peak

## How the demo stays deterministic

The real `claude` CLI is replaced by `mock-claude.sh`, a tiny script
that prints a fixed colored transcript and then loops on `read`. The
plugin is wired to it via `cmd = { ".../mock-claude.sh" }` in
`init.lua`, so `:ClaudeNew` spawns the mock instead of the real CLI.

Edit `mock-claude.sh` to change the fake transcript, `init.lua` to
change the colorscheme / keymaps, and `grid.tape` to change the
keystroke timeline.
