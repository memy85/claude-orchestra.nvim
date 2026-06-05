local session = require("claude-orchestra.session")

local M = {}

local function format_entry(s)
  local age = os.time() - s.created_at
  local mins = math.floor(age / 60)
  return string.format("%-24s  %s  (%dm)", s.name, vim.fn.fnamemodify(s.cwd, ":~"), mins)
end

function M.pick(on_choice)
  local sessions = session.list()
  if #sessions == 0 then
    vim.notify("claude-orchestra: no sessions yet — `:ClaudeNew`", vim.log.levels.INFO)
    return
  end

  vim.ui.select(sessions, {
    prompt = "Claude sessions",
    format_item = format_entry,
  }, function(choice)
    if choice then on_choice(choice) end
  end)
end

return M
