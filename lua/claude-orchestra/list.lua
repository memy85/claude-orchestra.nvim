local session_mod = require("claude-orchestra.session")
local config = require("claude-orchestra.config")

local M = {}

M._state = nil

local NEW_LABEL = "+ new session"
local REFRESH_MS = 500

local function selected_index()
  if not (M._state and vim.api.nvim_win_is_valid(M._state.list_winid)) then return nil end
  return vim.api.nvim_win_get_cursor(M._state.list_winid)[1]
end

local function selected_item()
  local idx = selected_index()
  return idx and M._state.items[idx] or nil
end

-- Copy the selected session's terminal lines into the preview buffer and
-- scroll to the bottom, where the latest output is.
local function refresh_preview()
  if not M._state then return end
  local buf, win = M._state.preview_bufnr, M._state.preview_winid
  if not (vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_win_is_valid(win)) then return end
  local item = selected_item()
  local lines = { "", "  <CR> to spawn a new session" }
  local title = " preview "
  if item and item.session then
    title = " " .. item.name .. " "
    local s = item.session
    if s.bufnr and vim.api.nvim_buf_is_valid(s.bufnr) then
      local ok, got = pcall(vim.api.nvim_buf_get_lines, s.bufnr, 0, -1, false)
      if ok and got then
        local last = #got
        while last > 0 and got[last] == "" do last = last - 1 end
        lines = vim.list_slice(got, 1, last)
      end
    end
  end
  vim.bo[buf].modifiable = true
  pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  pcall(vim.api.nvim_win_set_cursor, win, { math.max(1, #lines), 0 })
  pcall(vim.api.nvim_win_set_config, win, { title = title, title_pos = "center" })
end

function M.close()
  if not M._state then return end
  local st = M._state
  M._state = nil
  if st.timer then
    pcall(function() st.timer:stop() end)
    pcall(function() st.timer:close() end)
  end
  if st.augroup then pcall(vim.api.nvim_del_augroup_by_id, st.augroup) end
  for _, win in ipairs({ st.list_winid, st.preview_winid }) do
    if win and vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, true) end
  end
  for _, buf in ipairs({ st.list_bufnr, st.preview_bufnr }) do
    if buf and vim.api.nvim_buf_is_valid(buf) then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
  end
end

local function activate()
  local item = selected_item()
  if not item then return end
  M.close()
  if item.session then
    vim.schedule(function() session_mod.switch(item.name) end)
  else
    vim.schedule(function() session_mod.create(nil) end)
  end
end

local function kill_selected()
  local item = selected_item()
  if not (item and item.session) then return end
  local idx = selected_index()
  M.close()
  vim.schedule(function()
    session_mod.kill(item.name)
    M.open(idx)
  end)
end

local function rename_selected()
  local item = selected_item()
  if not (item and item.session) then return end
  local idx = selected_index()
  M.close()
  vim.ui.input({ prompt = "Rename `" .. item.name .. "` to: " }, function(input)
    if input and input ~= "" then session_mod.rename(item.name, input) end
    vim.schedule(function() M.open(idx) end)
  end)
end

local function set_keymaps(bufnr)
  local opts = { buffer = bufnr, silent = true, nowait = true }
  local nop = function() end
  local mappings = {
    ["<CR>"]  = activate,
    l         = activate,
    q         = M.close,
    ["<Esc>"] = M.close,
    x         = kill_selected,
    dd        = kill_selected,
    r         = rename_selected,
    n         = function() M.close(); vim.schedule(function() session_mod.create(nil) end) end,
    i = nop, a = nop, I = nop, A = nop, o = nop, O = nop,
    c = nop, C = nop, s = nop, S = nop,
  }
  for lhs, rhs in pairs(mappings) do
    vim.keymap.set("n", lhs, rhs, opts)
  end
  local keys = config.options.keymaps
  if keys.prefix and keys.rename and keys.rename ~= "" then
    vim.keymap.set("n", keys.prefix .. keys.rename, rename_selected, opts)
  end
end

function M.open(select)
  if M._state then M.close() end

  local items = {}
  for _, s in ipairs(session_mod.list()) do
    table.insert(items, { name = s.name, session = s })
  end
  table.insert(items, { name = NEW_LABEL })

  local active = session_mod.last_active()
  local lines = {}
  for _, item in ipairs(items) do
    if item.session then
      local mark = (active and active.name == item.name) and "●" or " "
      table.insert(lines, " " .. mark .. " " .. item.name)
    else
      table.insert(lines, "   " .. item.name)
    end
  end

  local W = vim.o.columns
  local H = vim.o.lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0)
  local total_w = math.max(40, math.floor(W * 0.85))
  local height = math.max(6, math.floor(H * 0.75))
  local longest = 0
  for _, l in ipairs(lines) do longest = math.max(longest, vim.fn.strdisplaywidth(l)) end
  local list_w = math.min(math.max(24, longest + 2), math.floor(total_w * 0.35))
  local preview_w = total_w - list_w - 2
  local row = math.floor((H - height) / 2) - 1
  local col = math.floor((W - total_w) / 2) - 1

  local list_bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[list_bufnr].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(list_bufnr, 0, -1, false, lines)
  vim.bo[list_bufnr].modifiable = false

  local list_winid = vim.api.nvim_open_win(list_bufnr, true, {
    relative = "editor",
    width = list_w, height = height, row = row, col = col,
    style = "minimal", border = "rounded",
    title = " claude sessions ", title_pos = "center",
    footer = " <CR> open  n new  r rename  x kill  q close ", footer_pos = "center",
    zindex = 50,
  })
  vim.wo[list_winid].cursorline = true
  vim.wo[list_winid].wrap = false
  vim.wo[list_winid].winhl = "Normal:NormalFloat,FloatBorder:DiagnosticInfo,FloatTitle:DiagnosticInfo"

  local preview_bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[preview_bufnr].bufhidden = "wipe"
  local preview_winid = vim.api.nvim_open_win(preview_bufnr, false, {
    relative = "editor",
    width = preview_w, height = height, row = row, col = col + list_w + 2,
    style = "minimal", border = "rounded",
    title = " preview ", title_pos = "center",
    zindex = 50, focusable = false,
  })
  vim.wo[preview_winid].wrap = false
  vim.wo[preview_winid].winhl = "Normal:NormalFloat,FloatBorder:Comment,FloatTitle:Comment"

  set_keymaps(list_bufnr)

  local augroup = vim.api.nvim_create_augroup("ClaudeOrchestraList", { clear = true })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = augroup, buffer = list_bufnr, callback = refresh_preview,
  })
  vim.api.nvim_create_autocmd("WinLeave", {
    group = augroup, buffer = list_bufnr,
    callback = function() vim.schedule(M.close) end,
  })
  vim.api.nvim_create_autocmd("VimResized", {
    group = augroup,
    callback = function()
      local idx = selected_index()
      vim.schedule(function()
        if M._state then M.open(idx) end
      end)
    end,
  })

  local timer = vim.uv.new_timer()
  timer:start(REFRESH_MS, REFRESH_MS, vim.schedule_wrap(refresh_preview))

  M._state = {
    items = items,
    list_bufnr = list_bufnr, list_winid = list_winid,
    preview_bufnr = preview_bufnr, preview_winid = preview_winid,
    augroup = augroup, timer = timer,
  }

  local start = 1
  if select then
    start = math.min(select, #items)
  elseif active then
    for i, item in ipairs(items) do
      if item.name == active.name and item.session then start = i break end
    end
  end
  pcall(vim.api.nvim_win_set_cursor, list_winid, { start, 0 })
  refresh_preview()
end

return M
