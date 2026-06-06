local M = {}

local function encoded_cwd(cwd)
  return (cwd:gsub("/", "-"))
end

function M.history_dir(cwd)
  cwd = cwd or vim.fn.getcwd()
  return vim.fn.expand("~/.claude/projects/" .. encoded_cwd(cwd))
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

function M.list(cwd)
  local dir = M.history_dir(cwd)
  if vim.fn.isdirectory(dir) == 0 then return {} end
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
    })
  end
  table.sort(sessions, function(a, b) return a.mtime > b.mtime end)
  return sessions
end

return M
