local M = {}

function M.get_context(opts)
  opts = opts or {}
  local buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" then
        table.insert(buffers, name)
      end
    end
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local selected_text = nil
  if opts.include_selection then
    local mode = vim.fn.mode()
    if mode == "v" or mode == "V" or mode == "\22" then
      vim.cmd('noautocmd normal! "vy')
      selected_text = vim.fn.getreg("v")
    end
  end

  local git_status = nil
  if opts.include_git then
    local result = vim.fn.systemlist("git status --porcelain 2>/dev/null")
    if vim.v.shell_error == 0 then
      local branch = vim.fn.systemlist("git branch --show-current 2>/dev/null")
      git_status = {
        branch = branch[1] or "HEAD",
        changed_files = result,
      }
    end
  end

  return {
    cwd = vim.fn.getcwd(),
    open_buffers = buffers,
    cursor_file = vim.api.nvim_buf_get_name(0),
    cursor_line = cursor[1],
    cursor_col = cursor[2],
    selected_text = selected_text,
    git_status = git_status,
  }
end

function M.format_for_prompt(ctx)
  local parts = { "Working in " .. ctx.cwd }

  if #ctx.open_buffers > 0 then
    local names = {}
    for _, buf in ipairs(ctx.open_buffers) do
      table.insert(names, vim.fn.fnamemodify(buf, ":."))
    end
    table.insert(parts, "Open files: " .. table.concat(names, ", "))
  end

  if ctx.cursor_file and ctx.cursor_file ~= "" then
    table.insert(parts, "Cursor at " .. vim.fn.fnamemodify(ctx.cursor_file, ":.") .. ":" .. ctx.cursor_line)
  end

  if ctx.selected_text then
    table.insert(parts, "Selection:\n```\n" .. ctx.selected_text .. "\n```")
  end

  if ctx.git_status then
    table.insert(parts, "Git branch: " .. ctx.git_status.branch)
    if #ctx.git_status.changed_files > 0 then
      table.insert(parts, "Changed files: " .. table.concat(ctx.git_status.changed_files, ", "))
    end
  end

  return table.concat(parts, "\n")
end

return M
