local config = require("claude-orchestra.config")

local M = {}

M._sessions = {}
M._order = {}
M._last_active = nil
M._counter = 0

local function unique_name(name)
  if not M._sessions[name] then return name end
  local i = 2
  while M._sessions[name .. "-" .. i] do i = i + 1 end
  return name .. "-" .. i
end

local function default_name()
  M._counter = M._counter + 1
  return unique_name("claude-" .. M._counter)
end

local function is_claude_buf(bufnr)
  if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then return false end
  return vim.api.nvim_buf_get_name(bufnr):match("^claude://") ~= nil
end

local function windows_showing(bufnr)
  local out = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      table.insert(out, win)
    end
  end
  return out
end

function M.list()
  local out = {}
  for _, name in ipairs(M._order) do
    local s = M._sessions[name]
    if s then table.insert(out, s) end
  end
  return out
end

function M.get(name)
  return M._sessions[name]
end

function M.last_active()
  if M._last_active and M._sessions[M._last_active] then
    return M._sessions[M._last_active]
  end
  local sessions = M.list()
  return sessions[#sessions]
end

function M.mark_active(name)
  if M._sessions[name] then M._last_active = name end
end

function M.is_visible(session)
  if not session or not session.bufnr then return false end
  return #windows_showing(session.bufnr) > 0
end

local function restore_window(win, prev_bufnr)
  if not vim.api.nvim_win_is_valid(win) then return end
  if prev_bufnr and vim.api.nvim_buf_is_valid(prev_bufnr) and not is_claude_buf(prev_bufnr) then
    pcall(vim.api.nvim_win_set_buf, win, prev_bufnr)
  else
    local scratch = vim.api.nvim_create_buf(true, false)
    pcall(vim.api.nvim_win_set_buf, win, scratch)
  end
end

function M.show(session)
  if not session then return end
  if not (session.bufnr and vim.api.nvim_buf_is_valid(session.bufnr)) then
    vim.notify("claude-orchestra: session buffer is gone", vim.log.levels.WARN)
    return
  end
  local visible = windows_showing(session.bufnr)
  if #visible > 0 then
    pcall(vim.api.nvim_set_current_win, visible[1])
  else
    local cur_win = vim.api.nvim_get_current_win()
    local cur_buf = vim.api.nvim_win_get_buf(cur_win)
    if not is_claude_buf(cur_buf) then
      session.prev_bufnr = cur_buf
    end
    pcall(vim.api.nvim_win_set_buf, cur_win, session.bufnr)
  end
  M.mark_active(session.name)
  if config.options.auto_insert then
    vim.schedule(function() vim.cmd("startinsert") end)
  end
end

function M.hide(session)
  if not session then return end
  for _, win in ipairs(windows_showing(session.bufnr)) do
    restore_window(win, session.prev_bufnr)
  end
end

function M.create(name, opts)
  opts = opts or {}
  name = name and name ~= "" and unique_name(name) or default_name()

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = "hide"

  for _, mode in ipairs({ "n", "i", "t", "v" }) do
    vim.keymap.set(mode, "<ScrollWheelLeft>", "<Nop>", { buffer = bufnr, silent = true })
    vim.keymap.set(mode, "<ScrollWheelRight>", "<Nop>", { buffer = bufnr, silent = true })
    vim.keymap.set(mode, "<S-ScrollWheelLeft>", "<Nop>", { buffer = bufnr, silent = true })
    vim.keymap.set(mode, "<S-ScrollWheelRight>", "<Nop>", { buffer = bufnr, silent = true })
  end

  local cur_win = vim.api.nvim_get_current_win()
  local cur_buf = vim.api.nvim_win_get_buf(cur_win)
  local prev_bufnr = is_claude_buf(cur_buf) and nil or cur_buf

  pcall(vim.api.nvim_win_set_buf, cur_win, bufnr)

  local cmd = opts.cmd or config.options.cmd
  local job_id = vim.fn.termopen(cmd, {
    on_exit = function()
      vim.schedule(function() M.kill(name, true) end)
    end,
  })

  if job_id <= 0 then
    if prev_bufnr and vim.api.nvim_buf_is_valid(prev_bufnr) then
      pcall(vim.api.nvim_win_set_buf, cur_win, prev_bufnr)
    end
    vim.api.nvim_buf_delete(bufnr, { force = true })
    vim.notify("claude-orchestra: failed to start `" .. table.concat(cmd, " ") .. "`", vim.log.levels.ERROR)
    return nil
  end

  local session = {
    name = name,
    bufnr = bufnr,
    job_id = job_id,
    cwd = vim.fn.getcwd(),
    created_at = os.time(),
    prev_bufnr = prev_bufnr,
  }

  M._sessions[name] = session
  table.insert(M._order, name)
  M._last_active = name

  vim.api.nvim_buf_set_name(bufnr, "claude://" .. name)

  if config.options.auto_insert then
    vim.schedule(function() vim.cmd("startinsert") end)
  end

  return session
end

function M.cycle(direction)
  if #M._order == 0 then
    vim.notify("claude-orchestra: no sessions", vim.log.levels.INFO)
    return
  end
  local current = M.last_active()
  local idx = 1
  if current then
    for i, n in ipairs(M._order) do
      if n == current.name then idx = i break end
    end
  end
  local n = #M._order
  local next_idx = ((idx - 1 + direction) % n + n) % n + 1
  M.switch(M._order[next_idx])
end

function M.switch(name)
  local s = M._sessions[name]
  if not s then
    vim.notify("claude-orchestra: no session named `" .. name .. "`", vim.log.levels.WARN)
    return
  end
  M.show(s)
end

function M.rename(old, new)
  local s = M._sessions[old]
  if not s then
    vim.notify("claude-orchestra: no session `" .. old .. "`", vim.log.levels.WARN)
    return
  end
  if M._sessions[new] then
    vim.notify("claude-orchestra: name `" .. new .. "` already taken", vim.log.levels.WARN)
    return
  end
  M._sessions[old] = nil
  M._sessions[new] = s
  s.name = new
  for i, n in ipairs(M._order) do
    if n == old then M._order[i] = new break end
  end
  if M._last_active == old then M._last_active = new end
  pcall(vim.api.nvim_buf_set_name, s.bufnr, "claude://" .. new)
end

function M.kill(name, from_exit)
  local s = M._sessions[name]
  if not s then return end
  if not from_exit and s.job_id then pcall(vim.fn.jobstop, s.job_id) end
  for _, win in ipairs(windows_showing(s.bufnr)) do
    restore_window(win, s.prev_bufnr)
  end
  if s.bufnr and vim.api.nvim_buf_is_valid(s.bufnr) then
    pcall(vim.api.nvim_buf_delete, s.bufnr, { force = true })
  end
  M._sessions[name] = nil
  for i, n in ipairs(M._order) do
    if n == name then table.remove(M._order, i) break end
  end
  if M._last_active == name then M._last_active = nil end
end

return M
