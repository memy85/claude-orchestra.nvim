local session = require("claude-orchestra.session")

local M = {}

function M.available()
  return pcall(require, "telescope")
end

local function entry_maker(s)
  local display = string.format("%-24s  %s", s.name, vim.fn.fnamemodify(s.cwd, ":~"))
  return {
    value = s,
    display = display,
    ordinal = s.name .. " " .. s.cwd,
    bufnr = s.bufnr,
  }
end

function M.pick(opts)
  opts = opts or {}
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")

  local sessions = session.list()
  if #sessions == 0 then
    vim.notify("claude-orchestra: no sessions yet — `:ClaudeNew`", vim.log.levels.INFO)
    return
  end

  local previewer = previewers.new_buffer_previewer({
    title = "Claude session",
    define_preview = function(self, entry)
      local s = entry.value
      if s.bufnr and vim.api.nvim_buf_is_valid(s.bufnr) then
        local lines = vim.api.nvim_buf_get_lines(s.bufnr, 0, -1, false)
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        local h = vim.api.nvim_win_get_height(self.state.winid)
        local target = math.max(1, #lines - h + 1)
        pcall(vim.api.nvim_win_set_cursor, self.state.winid, { target, 0 })
      else
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { "(buffer gone)" })
      end
    end,
  })

  pickers.new(opts, {
    prompt_title = "Claude sessions",
    finder = finders.new_table({
      results = sessions,
      entry_maker = entry_maker,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = previewer,
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry then session.switch(entry.value.name) end
      end)

      local function delete_current()
        local entry = action_state.get_selected_entry()
        if not entry then return end
        local picker = action_state.get_current_picker(prompt_bufnr)
        session.kill(entry.value.name)
        local remaining = {}
        for _, s in ipairs(session.list()) do table.insert(remaining, s) end
        if #remaining == 0 then
          actions.close(prompt_bufnr)
        else
          picker:refresh(finders.new_table({
            results = remaining,
            entry_maker = entry_maker,
          }), { reset_prompt = false })
        end
      end

      map("i", "<C-x>", delete_current)
      map("n", "<C-x>", delete_current)
      map("n", "dd", delete_current)

      local function rename_current()
        local entry = action_state.get_selected_entry()
        if not entry then return end
        local s = entry.value
        local picker = action_state.get_current_picker(prompt_bufnr)
        vim.ui.input({ prompt = "Rename `" .. s.name .. "` to: ", default = s.name }, function(input)
          if not input or input == "" or input == s.name then return end
          session.rename(s.name, input)
          local remaining = session.list()
          picker:refresh(finders.new_table({
            results = remaining,
            entry_maker = entry_maker,
          }), { reset_prompt = false })
        end)
      end

      map("i", "<C-r>", rename_current)
      map("n", "<C-r>", rename_current)
      map("n", "r", rename_current)

      return true
    end,
  }):find()
end

local function resume_entry_maker(s)
  local rel_cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ":~")
  local time = os.date("%m-%d %H:%M", s.mtime)
  local summary = s.summary ~= "" and s.summary or "(no user message)"
  if #summary > 70 then summary = summary:sub(1, 67) .. "..." end
  local display = string.format("%s  %s", time, summary)
  return {
    value = s,
    display = display,
    ordinal = time .. " " .. summary .. " " .. s.id,
  }
end

function M.pick_resume(opts)
  opts = opts or {}
  local history = require("claude-orchestra.history")
  local sessions = history.list()
  if #sessions == 0 then
    vim.notify("claude-orchestra: no past sessions in " .. history.history_dir(), vim.log.levels.INFO)
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

  pickers.new(opts, {
    prompt_title = "Resume Claude session (" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":~") .. ")",
    finder = finders.new_table({
      results = sessions,
      entry_maker = resume_entry_maker,
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
