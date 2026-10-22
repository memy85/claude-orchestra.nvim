-- Tab-mode helpers: a tabline that labels claude tabs by session name,
-- and tab cycling that also works from inside a claude terminal.
local M = {}

local function session_name(bufnr)
  local ok, val = pcall(function() return vim.b[bufnr].claude_orchestra end)
  return ok and val or nil
end

-- Session name shown in a tab, or nil if the tab has no claude window.
local function tab_session(tab)
  local cur = vim.api.nvim_tabpage_get_win(tab)
  local name = session_name(vim.api.nvim_win_get_buf(cur))
  if name then return name end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    name = session_name(vim.api.nvim_win_get_buf(win))
    if name then return name end
  end
end

function M.tabline()
  local out = {}
  local current = vim.api.nvim_get_current_tabpage()
  for i, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local label = tab_session(tab)
    if label then
      label = "claude:" .. label
    else
      local buf = vim.api.nvim_win_get_buf(vim.api.nvim_tabpage_get_win(tab))
      label = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
      if label == "" then label = "[No Name]" end
      if vim.bo[buf].modified then label = label .. " +" end
    end
    local hl = tab == current and "%#TabLineSel#" or "%#TabLine#"
    table.insert(out, hl .. "%" .. i .. "T " .. label:gsub("%%", "%%%%") .. " ")
  end
  table.insert(out, "%#TabLineFill#%T")
  return table.concat(out)
end

-- Move through every tab (claude and editing alike), wrapping around.
function M.cycle(direction)
  vim.cmd(direction > 0 and "tabnext" or "tabprevious")
end

return M
