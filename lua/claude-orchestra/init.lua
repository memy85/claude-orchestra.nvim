local config = require("claude-orchestra.config")
local session = require("claude-orchestra.session")
local picker = require("claude-orchestra.picker")

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
  return session.create(name, { cmd = base })
end

function M.resume_all()
  require("claude-orchestra.telescope").pick_resume({ all = true })
end

function M.toggle() session.toggle() end

function M.next() session.cycle(1) end
function M.prev() session.cycle(-1) end

function M.switch(name)
  if name and name ~= "" then return session.switch(name) end
  picker.pick(function(s) session.switch(s.name) end)
end

function M.kill(name)
  if name and name ~= "" then return session.kill(name) end
  picker.pick(function(s) session.kill(s.name) end)
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
  map(keys.toggle, M.toggle, "Claude: toggle session")
  map(keys.switch, function() M.switch() end, "Claude: switch session")
  map(keys.kill, function() M.kill() end, "Claude: kill session")
  map(keys.rename, function() M.rename() end, "Claude: rename current session")
  map(keys.next, M.next, "Claude: next session")
  map(keys.prev, M.prev, "Claude: previous session")
  map(keys.resume, function() M.resume() end, "Claude: resume previous session")
end

return M
