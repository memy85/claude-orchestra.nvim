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

local function open_float(bufnr, title)
  local opts = config.options.float
  local total_h = vim.o.lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0)
  local w = math.floor(vim.o.columns * opts.width)
  local h = math.floor(total_h * opts.height)
  local row = math.floor((total_h - h) / 2)
  local col = math.floor((vim.o.columns - w) / 2)
  local win_opts = {
    relative = "editor",
    width = w,
    height = h,
    row = row,
    col = col,
    style = "minimal",
    border = opts.border,
  }
  if opts.border ~= "none" then
    win_opts.title = " " .. title .. " "
    win_opts.title_pos = opts.title_pos
  end
  local winid = vim.api.nvim_open_win(bufnr, true, win_opts)
  vim.wo[winid].winblend = opts.winblend
  vim.wo[winid].wrap = true
  vim.wo[winid].sidescrolloff = 0
  vim.wo[winid].sidescroll = 0
  return winid
end

local function hide_all_visible()
  for _, s in pairs(M._sessions) do
    if s.winid and vim.api.nvim_win_is_valid(s.winid) then
      pcall(vim.api.nvim_win_close, s.winid, true)
      s.winid = nil
    end
  end
end

function M.create(name, opts)
  opts = opts or {}
  name = name and name ~= "" and unique_name(name) or default_name()

  hide_all_visible()

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = "hide"

  local winid = open_float(bufnr, name)

  local cmd = opts.cmd or config.options.cmd
  local job_id = vim.fn.termopen(cmd, {
    on_exit = function()
      M.kill(name, true)
    end,
  })

  if job_id <= 0 then
    vim.api.nvim_buf_delete(bufnr, { force = true })
    vim.notify("claude-orchestra: failed to start `" .. table.concat(cmd, " ") .. "`", vim.log.levels.ERROR)
    return nil
  end

  local session = {
    name = name,
    bufnr = bufnr,
    winid = winid,
    job_id = job_id,
    cwd = vim.fn.getcwd(),
    created_at = os.time(),
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

function M.is_visible(session)
  if not session then return false end
  if not (session.winid and vim.api.nvim_win_is_valid(session.winid)) then
    return false
  end
  local ok, buf_in_win = pcall(vim.api.nvim_win_get_buf, session.winid)
  return ok and buf_in_win == session.bufnr
end

function M.show(session)
  if not session then return end
  if not (session.bufnr and vim.api.nvim_buf_is_valid(session.bufnr)) then
    vim.notify("claude-orchestra: session buffer is gone", vim.log.levels.WARN)
    return
  end
  if M.is_visible(session) then
    vim.api.nvim_set_current_win(session.winid)
  else
    for _, other in pairs(M._sessions) do
      if other ~= session and other.winid and vim.api.nvim_win_is_valid(other.winid) then
        pcall(vim.api.nvim_win_close, other.winid, true)
        other.winid = nil
      end
    end
    session.winid = open_float(session.bufnr, session.name)
  end
  M.mark_active(session.name)
  if config.options.auto_insert then
    vim.schedule(function() vim.cmd("startinsert") end)
  end
end

function M.hide(session)
  if not session then return end
  if M.is_visible(session) then
    vim.api.nvim_win_close(session.winid, true)
  end
  session.winid = nil
end

function M.toggle(session)
  session = session or M.last_active()
  if not session then
    return M.create(nil)
  end
  if M.is_visible(session) then
    M.hide(session)
  else
    M.show(session)
  end
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
  local previous = M.last_active()
  if previous and previous.name ~= name then M.hide(previous) end
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
  if M.is_visible(s) and config.options.float.border ~= "none" then
    pcall(vim.api.nvim_win_set_config, s.winid, { title = " " .. new .. " ", title_pos = config.options.float.title_pos })
  end
end

local function focus_non_claude_window(except_winid)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= except_winid then
      local cfg = vim.api.nvim_win_get_config(win)
      if cfg.relative == "" then
        local buf = vim.api.nvim_win_get_buf(win)
        local n = vim.api.nvim_buf_get_name(buf)
        if not n:match("^claude://") then
          pcall(vim.api.nvim_set_current_win, win)
          return true
        end
      end
    end
  end
  return false
end

function M.kill(name, from_exit)
  local s = M._sessions[name]
  if not s then return end
  if not from_exit and s.job_id then pcall(vim.fn.jobstop, s.job_id) end
  if s.winid and vim.api.nvim_win_is_valid(s.winid) then
    focus_non_claude_window(s.winid)
    pcall(vim.api.nvim_win_close, s.winid, true)
  end
  if s.bufnr and vim.api.nvim_buf_is_valid(s.bufnr) then
    pcall(vim.api.nvim_buf_delete, s.bufnr, { force = true })
  end
  M._sessions[name] = nil
  for i, n in ipairs(M._order) do
    if n == name then table.remove(M._order, i) break end
  end
  if M._last_active == name then M._last_active = nil end
  if from_exit then
    vim.schedule(function() pcall(vim.cmd, "mode") end)
  end
end

return M
