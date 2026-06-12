local session_mod = require("claude-orchestra.session")
local config = require("claude-orchestra.config")

local M = {}

M._state = nil

local NEW_KEY = "__new__"
local REFRESH_MS = 500

local function shape(n)
  local cols = math.max(1, math.ceil(math.sqrt(n)))
  local rows = math.ceil(n / cols)
  return rows, cols
end

local function new_tile_lines(h, w)
  if h < 1 then return {} end
  local out = {}
  for _ = 1, math.max(0, math.floor(h / 2) - 1) do table.insert(out, "") end
  table.insert(out, string.rep(" ", math.max(0, math.floor((w - 17) / 2))) .. "[+ new session]")
  table.insert(out, string.rep(" ", math.max(0, math.floor((w - 20) / 2))) .. "<CR> to spawn one")
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

local TILE_KEYS = {
  "h", "j", "k", "l",
  "<Left>", "<Down>", "<Up>", "<Right>",
  "<CR>", "q", "<Esc>",
  "x", "dd", "r",
  "i", "a", "I", "A", "o", "O", "c", "C", "s", "S",
  "<leader>q",
}

local function clear_tile_keymaps(bufnr)
  if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then return end
  for _, lhs in ipairs(TILE_KEYS) do
    pcall(vim.keymap.del, "n", lhs, { buffer = bufnr })
  end
  local keys = config.options.keymaps
  if keys.prefix and keys.rename and keys.rename ~= "" then
    pcall(vim.keymap.del, "n", keys.prefix .. keys.rename, { buffer = bufnr })
  end
end

-- Copy the session's terminal buffer lines into the tile's snapshot
-- scratch buffer. Trims trailing empty lines so the visible region
-- shows the actual content rather than padding.
local function refresh_snapshot(snapshot_buf, session)
  if not (snapshot_buf and vim.api.nvim_buf_is_valid(snapshot_buf)) then return end
  if not (session and session.bufnr and vim.api.nvim_buf_is_valid(session.bufnr)) then return end
  local ok, lines = pcall(vim.api.nvim_buf_get_lines, session.bufnr, 0, -1, false)
  if not ok or not lines then return end
  local last = #lines
  while last > 0 and lines[last] == "" do last = last - 1 end
  if last < #lines then
    local trimmed = {}
    for i = 1, last do trimmed[i] = lines[i] end
    lines = trimmed
  end
  vim.bo[snapshot_buf].modifiable = true
  pcall(vim.api.nvim_buf_set_lines, snapshot_buf, 0, -1, false, lines)
  vim.bo[snapshot_buf].modifiable = false
end

local function stop_timer()
  if M._state and M._state.timer then
    pcall(function() M._state.timer:stop() end)
    pcall(function() M._state.timer:close() end)
    M._state.timer = nil
  end
end

function M.close()
  if not M._state then return end
  stop_timer()
  for _, t in ipairs(M._state.tiles) do
    if t.owned_bufnr and vim.api.nvim_buf_is_valid(t.owned_bufnr) then
      clear_tile_keymaps(t.owned_bufnr)
    end
    if t.winid and vim.api.nvim_win_is_valid(t.winid) then
      pcall(vim.api.nvim_win_close, t.winid, true)
    end
    if t.owned_bufnr and vim.api.nvim_buf_is_valid(t.owned_bufnr) then
      pcall(vim.api.nvim_buf_delete, t.owned_bufnr, { force = true })
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
  local name = tile.name
  M.close()
  vim.schedule(function()
    session_mod.kill(name)
    M.open()
  end)
end

local function rename_selected()
  if not M._state then return end
  local tile = M._state.tiles[M._state.selected]
  if not tile or tile.key == NEW_KEY then return end
  local old = tile.name
  M.close()
  vim.ui.input({ prompt = "Rename `" .. old .. "` to: " }, function(input)
    if input and input ~= "" then session_mod.rename(old, input) end
    vim.schedule(function() M.open() end)
  end)
end

local function set_tile_keymaps(bufnr)
  local opts = { buffer = bufnr, silent = true, nowait = true }
  local nop = function() end
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
    r          = rename_selected,
    i = nop, a = nop, I = nop, A = nop, o = nop, O = nop,
    c = nop, C = nop, s = nop, S = nop,
    ["<leader>q"] = nop,
  }
  for lhs, rhs in pairs(mappings) do
    vim.keymap.set("n", lhs, rhs, opts)
  end

  local keys = config.options.keymaps
  if keys.prefix and keys.rename and keys.rename ~= "" then
    vim.keymap.set("n", keys.prefix .. keys.rename, rename_selected, opts)
  end
end

function M.open()
  if M._state then M.close() end

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
    if item.key == NEW_KEY then
      local lines = new_tile_lines(tile_h - 2, tile_w - 2)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.bo[bufnr].modifiable = false
    else
      refresh_snapshot(bufnr, item.session)
    end

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
      key = item.key, name = item.name, session = item.session,
      owned_bufnr = bufnr, winid = winid,
    })

    set_tile_keymaps(bufnr)
  end

  local timer = vim.uv.new_timer()
  timer:start(REFRESH_MS, REFRESH_MS, vim.schedule_wrap(function()
    if not M._state then return end
    for _, t in ipairs(M._state.tiles) do
      if t.session then refresh_snapshot(t.owned_bufnr, t.session) end
    end
  end))

  M._state = {
    bg_winid = bg_winid,
    bg_bufnr = bg_bufnr,
    tiles = tiles,
    rows = rows,
    cols = cols,
    selected = 1,
    timer = timer,
  }

  pcall(vim.api.nvim_set_current_win, tiles[1].winid)
  highlight_selection()
end

return M
