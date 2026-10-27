local config = require("claude-orchestra.config")
local session = require("claude-orchestra.session")

local M = {}

function M.new(name) return session.create(name) end

function M.resume(id, name)
  if not id or id == "" then
    require("claude-orchestra.telescope").pick_resume()
    return
  end
  local base = vim.deepcopy(config.options.cmd)
  table.insert(base, "--resume")
  table.insert(base, id)
  return session.create(name, { cmd = base, session_id = id })
end

function M.resume_all()
  require("claude-orchestra.telescope").pick_resume({ all = true })
end

function M.list() require("claude-orchestra.list").open() end

function M.next() session.cycle(1) end
function M.prev() session.cycle(-1) end

function M.switch(name)
  if name and name ~= "" then return session.switch(name) end
  M.list()
end

function M.kill(name)
  if name and name ~= "" then return session.kill(name) end
  local cur = vim.b[0].claude_orchestra
  if cur then session.kill(cur) end
end

function M.rename(new_name)
  local current = session.last_active()
  if not current then
    vim.notify("claude-orchestra: no active session to rename", vim.log.levels.WARN)
    return
  end
  if not new_name or new_name == "" then
    vim.ui.input({ prompt = "Rename `" .. current.name .. "` to: " }, function(input)
      if input and input ~= "" then session.rename(current.name, input) end
    end)
  else
    session.rename(current.name, new_name)
  end
end

function M.setup(opts)
  config.setup(opts)

  local keys = config.options.keymaps
  local p = keys.prefix
  local map = function(suffix, cmd, desc)
    if not suffix or suffix == "" then return end
    vim.keymap.set("n", p .. suffix, cmd, { desc = desc, silent = true })
  end

  map(keys.new, function() M.new() end, "Claude: new session")
  map(keys.switch, function() M.switch() end, "Claude: switch session")
  map(keys.kill, function() M.kill() end, "Claude: kill session")
  map(keys.rename, function() M.rename() end, "Claude: rename current session")
  map(keys.next, M.next, "Claude: next session")
  map(keys.prev, M.prev, "Claude: previous session")
  map(keys.resume, function() M.resume() end, "Claude: resume previous session")

  if config.options.open_in == "tab" then
    local tabs = require("claude-orchestra.tabs")
    vim.o.tabline = "%!v:lua.require'claude-orchestra.tabs'.tabline()"
    for key, dir in pairs({ [keys.tab_next] = 1, [keys.tab_prev] = -1 }) do
      if key and key ~= "" then
        vim.keymap.set({ "n", "t" }, key, function() tabs.cycle(dir) end,
          { desc = "Claude: cycle tabs", silent = true })
      end
    end
  end
end

return M
