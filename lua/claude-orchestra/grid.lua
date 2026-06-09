local session_mod = require("claude-orchestra.session")

local M = {}

M._state = nil

local NEW_KEY = "__new__"

local function shape(n)
  local cols = math.max(1, math.ceil(math.sqrt(n)))
  local rows = math.ceil(n / cols)
  return rows, cols
end

local function snapshot(session, h, w)
  if h < 1 then return {} end
  if not session then
    local out = {}
    for _ = 1, math.max(0, math.floor(h / 2) - 1) do table.insert(out, "") end
    table.insert(out, string.rep(" ", math.max(0, math.floor((w - 17) / 2))) .. "[+ new session]")
    table.insert(out, string.rep(" ", math.max(0, math.floor((w - 20) / 2))) .. "<CR> to spawn one")
    return out
  end
  if not (session.bufnr and vim.api.nvim_buf_is_valid(session.bufnr)) then
    return { "(buffer unavailable)" }
  end
  local total = vim.api.nvim_buf_line_count(session.bufnr)
  local last_non_empty = total
  while last_non_empty > 0 do
    local l = vim.api.nvim_buf_get_lines(session.bufnr, last_non_empty - 1, last_non_empty, false)[1] or ""
    if l:match("%S") then break end
    last_non_empty = last_non_empty - 1
  end
  if last_non_empty == 0 then return { "(empty)" } end
  local start = math.max(0, last_non_empty - h)
  local body = vim.api.nvim_buf_get_lines(session.bufnr, start, last_non_empty, false)
  local out = {}
  for _, line in ipairs(body) do
    if vim.fn.strdisplaywidth(line) > w then
      line = vim.fn.strcharpart(line, 0, w)
    end
    table.insert(out, line)
  end
  return out
end

local function highlight_selection()
  if not M._state then return end
  for i, t in ipairs(M._state.tiles) do
    if t.winid and vim.api.nvim_win_is_valid(t.winid) then
      local hl = (i == M._state.selected)
        and "Normal:NormalFloat,FloatBorder:DiagnosticInfo,FloatTitle:DiagnosticInfo"
        or "Normal:NormalFloat,FloatBorder:Comment,FloatTitle:Comment"
      vim.wo[t.winid].winhl = hl
    end
  end
end

function M.close()
  if not M._state then return end
  for _, t in ipairs(M._state.tiles) do
    if t.winid and vim.api.nvim_win_is_valid(t.winid) then
      pcall(vim.api.nvim_win_close, t.winid, true)
    end
    if t.bufnr and vim.api.nvim_buf_is_valid(t.bufnr) then
      pcall(vim.api.nvim_buf_delete, t.bufnr, { force = true })
    end
  end
  if M._state.bg_winid and vim.api.nvim_win_is_valid(M._state.bg_winid) then
    pcall(vim.api.nvim_win_close, M._state.bg_winid, true)
  end
  if M._state.bg_bufnr and vim.api.nvim_buf_is_valid(M._state.bg_bufnr) then
    pcall(vim.api.nvim_buf_delete, M._state.bg_bufnr, { force = true })
  end
  M._state = nil
  vim.schedule(function() pcall(vim.cmd, "redraw!") end)
end

local function activate()
  if not M._state then return end
  local tile = M._state.tiles[M._state.selected]
  if not tile then return end
  if tile.key == NEW_KEY then
    M.close()
    vim.schedule(function() session_mod.create(nil) end)
    return
  end
  M.close()
  vim.schedule(function() session_mod.switch(tile.name) end)
end

local function move(direction)
  if not M._state then return end
  local n = #M._state.tiles
  local idx = M._state.selected
  local cols = M._state.cols
  local row = math.floor((idx - 1) / cols)
  local col = (idx - 1) % cols
  if direction == "h" then col = col - 1
  elseif direction == "l" then col = col + 1
  elseif direction == "j" then row = row + 1
  elseif direction == "k" then row = row - 1
  end
  if row < 0 or col < 0 or col >= cols then return end
  local new_idx = row * cols + col + 1
  if new_idx < 1 or new_idx > n then return end
  M._state.selected = new_idx
  pcall(vim.api.nvim_set_current_win, M._state.tiles[new_idx].winid)
  highlight_selection()
end

local function kill_selected()
  if not M._state then return end
  local tile = M._state.tiles[M._state.selected]
  if not tile or tile.key == NEW_KEY then return end
  session_mod.kill(tile.name)
  M.close()
  vim.schedule(function() M.open() end)
end

local function set_tile_keymaps(bufnr)
  local opts = { buffer = bufnr, silent = true, nowait = true }
  local mappings = {
    h = function() move("h") end,
    j = function() move("j") end,
    k = function() move("k") end,
    l = function() move("l") end,
    ["<Left>"]  = function() move("h") end,
    ["<Down>"]  = function() move("j") end,
    ["<Up>"]    = function() move("k") end,
    ["<Right>"] = function() move("l") end,
    ["<CR>"]    = activate,
    q          = M.close,
    ["<Esc>"]   = M.close,
    x          = kill_selected,
    dd         = kill_selected,
  }
  for lhs, rhs in pairs(mappings) do
    vim.keymap.set("n", lhs, rhs, opts)
  end
end

function M.open()
  if M._state then M.close() end

  for _, s in ipairs(session_mod.list()) do
    if session_mod.is_visible(s) then session_mod.hide(s) end
  end

  local sessions = session_mod.list()
  local items = {}
  for _, s in ipairs(sessions) do
    table.insert(items, { key = s.name, name = s.name, session = s })
  end
  table.insert(items, { key = NEW_KEY })

  local n = #items
  local rows, cols = shape(n)

  local W = vim.o.columns
  local H = vim.o.lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0)

  local pad = 1
  local tile_w = math.max(10, math.floor((W - pad * (cols + 1)) / cols))
  local tile_h = math.max(4, math.floor((H - pad * (rows + 1)) / rows))

  local bg_bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bg_bufnr].bufhidden = "wipe"
  local bg_winid = vim.api.nvim_open_win(bg_bufnr, false, {
    relative = "editor",
    width = W, height = H, row = 0, col = 0,
    style = "minimal", border = "none", focusable = false, zindex = 10,
  })
  vim.wo[bg_winid].winhl = "Normal:NormalFloat"

  local tiles = {}
  for i, item in ipairs(items) do
    local r = math.floor((i - 1) / cols)
    local c = (i - 1) % cols
    local y = pad + r * (tile_h + pad)
    local x = pad + c * (tile_w + pad)

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[bufnr].bufhidden = "wipe"

    local content = snapshot(item.session, tile_h - 2, tile_w - 2)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
    vim.bo[bufnr].modifiable = false

    local title = item.key == NEW_KEY and " + new " or (" " .. item.name .. " ")
    local winid = vim.api.nvim_open_win(bufnr, false, {
      relative = "editor",
      width = tile_w, height = tile_h, row = y, col = x,
      style = "minimal", border = "rounded",
      title = title, title_pos = "center",
      zindex = 20, focusable = true,
    })
    vim.wo[winid].cursorline = false
    vim.wo[winid].wrap = false

    table.insert(tiles, {
      key = item.key, name = item.name, bufnr = bufnr, winid = winid,
    })

    set_tile_keymaps(bufnr)
  end

  M._state = {
    bg_winid = bg_winid,
    bg_bufnr = bg_bufnr,
    tiles = tiles,
    rows = rows,
    cols = cols,
    selected = 1,
  }

  pcall(vim.api.nvim_set_current_win, tiles[1].winid)
  highlight_selection()
end

return M
