# Hero demo for claude-orchestra.nvim.
# Run from the repo root:  vhs docs/demo/grid.tape
# Output:                  docs/grid.gif (+ docs/grid.png still)

Output docs/grid.gif

Set Shell "bash"
Set FontSize 13
Set Width 1400
Set Height 850
Set Theme "Catppuccin Mocha"
Set TypingSpeed 50ms
Set PlaybackSpeed 1.0

# Launch nvim with the demo config and a clean plugin set.
Hide
Type "rm -f /tmp/co-demo-counter && export CO_REPO_ROOT=$PWD && cd docs/demo && export CO_DEMO_DIR=$PWD && nvim --noplugin -u init.lua"
Enter
Sleep 2s
Show

# Spawn three sessions.
Type ":ClaudeNew planner"
Enter
Sleep 3s

Escape
Type ":ClaudeNew coder"
Enter
Sleep 3s

Escape
Type ":ClaudeNew reviewer"
Enter
Sleep 3s

# Open the grid.
Escape
Type " cl"
Sleep 2s

# Navigate — focusing each tile kicks libvterm to repaint, so
# we screenshot only after we've cycled through them.
Type "l"
Sleep 800ms
Screenshot docs/demo/after-l.png
Type "j"
Sleep 600ms
Type "h"
Sleep 600ms
Type "k"
Sleep 800ms

Screenshot docs/grid.png

# Inline rename of the selected tile.
Type "r"
Sleep 700ms
Type "architect"
Enter
Sleep 2s

# Reopen the grid, switch into a session.
Type " cl"
Sleep 1s
Type "j"
Sleep 500ms
Enter
Sleep 2s

# End on the active session view.
Sleep 800ms
