# README screenshots for claude-orchestra.nvim.
# Run from the repo root:  vhs docs/demo/screenshots.tape
# Output:                  docs/images/{list,tabs,resume}.png

Output "/tmp/co-screenshots.gif"

Set Shell "bash"
Set FontSize 13
Set Width 1400
Set Height 850
Set Theme "Catppuccin Mocha"
Set TypingSpeed 20ms

# Shared setup. A fake HOME keeps the resume picker off your real transcripts.
Hide
Type "export CO_REPO_ROOT=$PWD CO_DEMO_DIR=$PWD/docs/demo CO_PLUGIN_DIR=${CO_PLUGIN_DIR:-$HOME/.local/share/nvim/site/pack/packer/start} && export HOME=/tmp/co-demo-home CO_DEMO_COUNTER=/tmp/co-demo-counter CO_AUTO_INSERT=0 && mkdir -p $HOME docs/images && cd docs/demo && clear"
Enter
Sleep 500ms

# --- Session list (buffer mode) ---
Type "rm -f $CO_DEMO_COUNTER && nvim --noplugin -u init.lua"
Enter
Sleep 2s
Type ":ClaudeNew planner"
Enter
Sleep 2s
Type ":ClaudeNew coder"
Enter
Sleep 2s
Type ":ClaudeNew reviewer"
Enter
Sleep 2s
Show

Type " cl"
Sleep 1s
Type "k"
Sleep 1500ms
Screenshot "docs/images/list.png"
Type "q"
Sleep 300ms

Hide
Type ":qa!"
Enter
Sleep 1500ms

# --- Tab mode ---
Type "clear; rm -f $CO_DEMO_COUNTER && CO_OPEN_IN=tab nvim --noplugin -u init.lua"
Enter
Sleep 3s
Type ":ClaudeNew planner"
Enter
Sleep 2s
Type ":ClaudeNew coder"
Enter
Sleep 2s
Type ":ClaudeNew reviewer"
Enter
Sleep 2s
Type ":tabprevious"
Enter
Sleep 1s
Show
Sleep 1s
Ctrl+L
Sleep 1s
Screenshot "docs/images/tabs.png"

Hide
Type ":qa!"
Enter
Sleep 1500ms

# --- Resume picker ---
Type "clear; mkdir -p $HOME/my-app && ./fake-history.sh $HOME $HOME/my-app && cd $HOME/my-app && nvim --noplugin -u $CO_DEMO_DIR/init.lua"
Enter
Sleep 2s
Show
Type " ch"
Sleep 2s
Screenshot "docs/images/resume.png"
Sleep 300ms
