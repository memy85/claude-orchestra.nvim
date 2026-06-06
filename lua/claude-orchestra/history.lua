local M = {}

local function encoded_cwd(cwd)
  return (cwd:gsub("[^A-Za-z0-9]", "-"))
end

function M.history_dir(cwd)
  cwd = cwd or vim.fn.getcwd()
  return vim.fn.expand("~/.claude/projects/" .. encoded_cwd(cwd))
end

function M.projects_root()
  return vim.fn.expand("~/.claude/projects")
end

local function first_user_message(path)
  local f = io.open(path, "r")
  if not f then return "" end
  for _ = 1, 50 do
    local line = f:read("*l")
    if not line then break end
    local ok, obj = pcall(vim.json.decode, line)
    if ok and obj and obj.type == "user" and obj.message then
      local content = obj.message.content
      if type(content) == "string" then
        f:close()
        return (content:gsub("\n", " "))
      elseif type(content) == "table" and content[1] and content[1].text then
        f:close()
        return (content[1].text:gsub("\n", " "))
      end
    end
  end
  f:close()
  return ""
end

function M.last_messages(path, n)
  n = n or 20
  local f = io.open(path, "r")
  if not f then return { "(unable to read)" } end
  local lines = {}
  for line in f:lines() do
    local ok, obj = pcall(vim.json.decode, line)
    if ok and obj and (obj.type == "user" or obj.type == "assistant") and obj.message then
      local role = obj.type
      local text = ""
      local content = obj.message.content
      if type(content) == "string" then
        text = content
      elseif type(content) == "table" then
        for _, part in ipairs(content) do
          if part.text then text = text .. part.text end
        end
      end
      if text ~= "" then
        table.insert(lines, "── " .. role .. " ──")
        for s in (text .. "\n"):gmatch("([^\n]*)\n") do
          table.insert(lines, s)
        end
        table.insert(lines, "")
      end
    end
  end
  f:close()
  local start = math.max(1, #lines - 200)
  local tail = {}
  for i = start, #lines do table.insert(tail, lines[i]) end
  return tail
end

local function recorded_cwd(path)
  local f = io.open(path, "r")
  if not f then return nil end
  for _ = 1, 100 do
    local line = f:read("*l")
    if not line then break end
    local ok, obj = pcall(vim.json.decode, line)
    if ok and obj and obj.cwd then
      f:close()
      return obj.cwd
    end
  end
  f:close()
  return nil
end

local function collect(dir)
  local files = vim.fn.glob(dir .. "/*.jsonl", false, true)
  local sessions = {}
  for _, path in ipairs(files) do
    local id = vim.fn.fnamemodify(path, ":t:r")
    local stat = vim.uv.fs_stat(path)
    table.insert(sessions, {
      id = id,
      path = path,
      mtime = stat and stat.mtime.sec or 0,
      size = stat and stat.size or 0,
      summary = first_user_message(path),
      cwd = recorded_cwd(path),
    })
  end
  return sessions
end

function M.list(cwd)
  local dir = M.history_dir(cwd)
  if vim.fn.isdirectory(dir) == 0 then return {} end
  local sessions = collect(dir)
  table.sort(sessions, function(a, b) return a.mtime > b.mtime end)
  return sessions
end

function M.list_all()
  local root = M.projects_root()
  if vim.fn.isdirectory(root) == 0 then return {} end
  local sessions = {}
  for _, sub in ipairs(vim.fn.glob(root .. "/*", false, true)) do
    if vim.fn.isdirectory(sub) == 1 then
      for _, s in ipairs(collect(sub)) do
        table.insert(sessions, s)
      end
    end
  end
  table.sort(sessions, function(a, b) return a.mtime > b.mtime end)
  return sessions
end

return M
