local M = {}

local function resume_entry_maker(show_cwd)
  return function(s)
    local time = os.date("%m-%d %H:%M", s.mtime)
    local summary = s.summary ~= "" and s.summary or "(no user message)"
    local max_len = show_cwd and 50 or 70
    if #summary > max_len then summary = summary:sub(1, max_len - 3) .. "..." end
    local display
    if show_cwd then
      local cwd = s.cwd and vim.fn.fnamemodify(s.cwd, ":~") or "?"
      if #cwd > 30 then cwd = "..." .. cwd:sub(-27) end
      display = string.format("%s  %-30s  %s", time, cwd, summary)
    else
      display = string.format("%s  %s", time, summary)
    end
    return {
      value = s,
      display = display,
      ordinal = time .. " " .. (s.cwd or "") .. " " .. summary .. " " .. s.id,
    }
  end
end

function M.pick_resume(opts)
  opts = opts or {}
  local history = require("claude-orchestra.history")
  local all = opts.all == true
  local sessions = all and history.list_all() or history.list()
  if #sessions == 0 then
    local where = all and history.projects_root() or history.history_dir()
    vim.notify("claude-orchestra: no past sessions in " .. where, vim.log.levels.INFO)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")

  local previewer = previewers.new_buffer_previewer({
    title = "Transcript",
    define_preview = function(self, entry)
      local lines = history.last_messages(entry.value.path, 20)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
    end,
  })

  local title = all and "Resume Claude session (all projects)"
    or ("Resume Claude session (" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":~") .. ")")
  pickers.new(opts, {
    prompt_title = title,
    finder = finders.new_table({
      results = sessions,
      entry_maker = resume_entry_maker(all),
    }),
    sorter = conf.generic_sorter(opts),
    previewer = previewer,
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry then
          require("claude-orchestra").resume(entry.value.id)
        end
      end)
      return true
    end,
  }):find()
end

return M
