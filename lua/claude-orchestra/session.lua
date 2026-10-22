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
  local ok, val = pcall(function() return vim.b[bufnr].claude_orchestra end)
  return ok and val ~= nil
end

local function uuid()
  local b = {}
  for i = 1, 16 do b[i] = math.random(0, 255) end
  b[7] = bit.bor(bit.band(b[7], 0x0f), 0x40)
  b[9] = bit.bor(bit.band(b[9], 0x3f), 0x80)
  local hex = ""
  for i = 1, 16 do hex = hex .. string.format("%02x", b[i]) end
  return string.format("%s-%s-%s-%s-%s",
    hex:sub(1, 8), hex:sub(9, 12), hex:sub(13, 16), hex:sub(17, 20), hex:sub(21, 32))
end

-- Claude reports its live session id here via a SessionStart hook, so we can
-- follow /resume, /clear, and resumed-as-copy sessions to the right transcript.
local function state_dir()
  local dir = vim.fn.stdpath("state") .. "/claude-orchestra"
  vim.fn.mkdir(dir, "p")
  return dir
end

local HOOK_SETTINGS = vim.json.encode({
  hooks = {
    SessionStart = { {
      hooks = { {
        type = "command",
        command = '[ -n "$CLAUDE_ORCHESTRA_KEY" ] && cat > "$CLAUDE_ORCHESTRA_DIR/$CLAUDE_ORCHESTRA_KEY.tmp"'
          .. ' && mv "$CLAUDE_ORCHESTRA_DIR/$CLAUDE_ORCHESTRA_KEY.tmp" "$CLAUDE_ORCHESTRA_DIR/$CLAUDE_ORCHESTRA_KEY.json"; true',
      } },
    } },
  },
})

local function buf_display_name(name)
  return "[claude:" .. name .. "]"
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

local function use_tab()
  return config.options.open_in == "tab"
end

-- Open bufnr in a new tabpage; drop the placeholder buffer :tabnew creates.
local function open_in_tab(bufnr)
  vim.cmd("tabnew")
  local win = vim.api.nvim_get_current_win()
  local placeholder = vim.api.nvim_win_get_buf(win)
  pcall(vim.api.nvim_win_set_buf, win, bufnr)
  if placeholder ~= bufnr and vim.api.nvim_buf_is_valid(placeholder) then
    pcall(vim.api.nvim_buf_delete, placeholder, { force = true })
  end
  return win
end

local function restore_window(win, prev_bufnr)
  if not vim.api.nvim_win_is_valid(win) then return end
  -- In tab mode the session owns its tab, so close the window instead of refilling it.
  if use_tab() and #vim.api.nvim_list_tabpages() > 1 then
    pcall(vim.api.nvim_win_close, win, true)
    return
  end
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
  elseif use_tab() then
    open_in_tab(session.bufnr)
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
  vim.b[bufnr].claude_orchestra = name

  for _, mode in ipairs({ "n", "i", "t", "v" }) do
    vim.keymap.set(mode, "<ScrollWheelLeft>", "<Nop>", { buffer = bufnr, silent = true })
    vim.keymap.set(mode, "<ScrollWheelRight>", "<Nop>", { buffer = bufnr, silent = true })
    vim.keymap.set(mode, "<S-ScrollWheelLeft>", "<Nop>", { buffer = bufnr, silent = true })
    vim.keymap.set(mode, "<S-ScrollWheelRight>", "<Nop>", { buffer = bufnr, silent = true })
  end

  -- Shift+Enter -> insert newline in the claude prompt (Alt+Enter byte sequence).
  -- nvim's terminal collapses <S-CR> to plain <CR> by default, which claude treats as submit.
  vim.keymap.set("t", "<S-CR>", function()
    local job = vim.b[bufnr].terminal_job_id
    if job then pcall(vim.api.nvim_chan_send, job, "\27\r") end
  end, { buffer = bufnr, silent = true })

  local cur_win, prev_bufnr
  if use_tab() then
    cur_win = open_in_tab(bufnr)
  else
    cur_win = vim.api.nvim_get_current_win()
    local cur_buf = vim.api.nvim_win_get_buf(cur_win)
    prev_bufnr = is_claude_buf(cur_buf) and nil or cur_buf
    pcall(vim.api.nvim_win_set_buf, cur_win, bufnr)
  end

  -- Pin the claude session id so we can find its transcript and pick up /rename titles.
  local claude_id = opts.session_id
  local cmd = vim.deepcopy(opts.cmd or config.options.cmd)
  if not claude_id then
    claude_id = uuid()
    table.insert(cmd, "--session-id")
    table.insert(cmd, claude_id)
  end
  local key = uuid()
  table.insert(cmd, "--settings")
  table.insert(cmd, HOOK_SETTINGS)
  local job_id = vim.fn.termopen(cmd, {
    env = { CLAUDE_ORCHESTRA_KEY = key, CLAUDE_ORCHESTRA_DIR = state_dir() },
    on_exit = function()
      vim.schedule(function() M.kill(name, true) end)
    end,
  })

  if job_id <= 0 then
    if use_tab() then
      restore_window(cur_win, nil)
    elseif prev_bufnr and vim.api.nvim_buf_is_valid(prev_bufnr) then
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
    claude_id = claude_id,
    hook_key = key,
    cwd = vim.fn.getcwd(),
    created_at = os.time(),
    prev_bufnr = prev_bufnr,
  }

  M._sessions[name] = session
  table.insert(M._order, name)
  M._last_active = name

  vim.api.nvim_buf_set_name(bufnr, buf_display_name(name))
  M.watch_titles()

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
  if s.bufnr and vim.api.nvim_buf_is_valid(s.bufnr) then
    vim.b[s.bufnr].claude_orchestra = new
    pcall(vim.api.nvim_buf_set_name, s.bufnr, buf_display_name(new))
  end
  pcall(vim.cmd.redrawtabline)
end

-- Read transcript lines appended since the last check and return the newest
-- /rename title, if any. Only complete lines are consumed.
-- Switch to whichever session claude last reported starting (new, /resume, /clear).
local function follow_hook(s)
  local file = state_dir() .. "/" .. s.hook_key .. ".json"
  local stat = vim.uv.fs_stat(file)
  if not stat or stat.mtime.sec == s.hook_mtime then return end
  s.hook_mtime = stat.mtime.sec
  local f = io.open(file, "r")
  if not f then return end
  local ok, obj = pcall(vim.json.decode, f:read("*a") or "")
  f:close()
  if not (ok and obj and obj.session_id) then return end
  if obj.session_id ~= s.claude_id or obj.transcript_path ~= s.transcript then
    s.claude_id = obj.session_id
    s.transcript = obj.transcript_path
    s.title_offset = 0
  end
end

local function read_new_title(s)
  follow_hook(s)
  local path = s.transcript
    or require("claude-orchestra.history").history_dir(s.cwd) .. "/" .. s.claude_id .. ".jsonl"
  local stat = vim.uv.fs_stat(path)
  s.title_offset = s.title_offset or 0
  if not stat or stat.size <= s.title_offset then return nil end
  local f = io.open(path, "rb")
  if not f then return nil end
  f:seek("set", s.title_offset)
  local chunk = f:read(stat.size - s.title_offset) or ""
  f:close()
  local last_nl = chunk:match(".*()\n")
  if not last_nl then return nil end
  s.title_offset = s.title_offset + last_nl
  local title
  for line in chunk:sub(1, last_nl):gmatch("[^\n]+") do
    if line:find('"custom-title"', 1, true) then
      local ok, obj = pcall(vim.json.decode, line)
      if ok and obj and obj.type == "custom-title" and obj.customTitle and obj.customTitle ~= "" then
        title = obj.customTitle
      end
    end
  end
  return title
end

-- Poll transcripts so a /rename inside claude renames the session (and its tab).
function M.watch_titles()
  if M._title_timer then return end
  M._title_timer = vim.uv.new_timer()
  M._title_timer:start(2000, 2000, vim.schedule_wrap(function()
    for _, name in ipairs(vim.deepcopy(M._order)) do
      local s = M._sessions[name]
      if s and s.claude_id then
        local title = read_new_title(s)
        if title and title ~= s.name then M.rename(s.name, unique_name(title)) end
      end
    end
  end))
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
  if s.hook_key then os.remove(state_dir() .. "/" .. s.hook_key .. ".json") end
  M._sessions[name] = nil
  for i, n in ipairs(M._order) do
    if n == name then table.remove(M._order, i) break end
  end
  if M._last_active == name then M._last_active = nil end
end

return M
