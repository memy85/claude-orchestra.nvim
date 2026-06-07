if vim.g.loaded_claude_orchestra then return end
vim.g.loaded_claude_orchestra = true

local function cmd(name, fn, opts)
  vim.api.nvim_create_user_command(name, fn, opts or {})
end

cmd("ClaudeNew", function(o) require("claude-orchestra").new(o.args) end, { nargs = "?" })
cmd("ClaudeToggle", function() require("claude-orchestra").toggle() end, {})
cmd("ClaudeSwitch", function(o) require("claude-orchestra").switch(o.args) end, {
  nargs = "?",
  complete = function()
    local names = {}
    for _, s in ipairs(require("claude-orchestra.session").list()) do
      table.insert(names, s.name)
    end
    return names
  end,
})
cmd("ClaudeKill", function(o) require("claude-orchestra").kill(o.args) end, {
  nargs = "?",
  complete = function()
    local names = {}
    for _, s in ipairs(require("claude-orchestra.session").list()) do
      table.insert(names, s.name)
    end
    return names
  end,
})
cmd("ClaudeRename", function(o) require("claude-orchestra").rename(o.args) end, { nargs = "?" })
cmd("ClaudeNext", function() require("claude-orchestra").next() end, {})
cmd("ClaudePrev", function() require("claude-orchestra").prev() end, {})
cmd("ClaudeResume", function(o)
  if o.bang then
    require("claude-orchestra").resume_all()
  else
    require("claude-orchestra").resume(o.args)
  end
end, { nargs = "?", bang = true })
