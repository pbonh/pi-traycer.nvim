local M = {}

local TIMEOUT_MS = 30000

function M.format_response(request_id, value)
  return {
    type = "extension_ui_response",
    id = request_id,
    value = value,
  }
end

function M.format_cancellation(request_id)
  return {
    type = "extension_ui_response",
    id = request_id,
    cancelled = true,
  }
end

local function handle_select(event, rpc)
  local Snacks = require("snacks")
  local items = {}
  for i, option in ipairs(event.options or {}) do
    table.insert(items, {
      idx = i,
      text = option.label or option.value or tostring(option),
      value = option.value or option,
    })
  end

  local responded = false
  local timer = vim.defer_fn(function()
    if not responded then
      responded = true
      rpc.send_command(M.format_cancellation(event.id))
    end
  end, TIMEOUT_MS)

  Snacks.picker({
    title = event.title or "Select",
    items = items,
    format = function(item) return { { item.text } } end,
    confirm = function(picker, item)
      picker:close()
      if not responded then
        responded = true
        if timer then timer:stop() end
        rpc.send_command(M.format_response(event.id, item.value))
      end
    end,
    on_close = function()
      if not responded then
        responded = true
        if timer then timer:stop() end
        rpc.send_command(M.format_cancellation(event.id))
      end
    end,
  })
end

local function handle_confirm(event, rpc)
  local Snacks = require("snacks")
  local responded = false

  Snacks.input({
    prompt = (event.message or "Confirm?") .. " (y/n): ",
  }, function(value)
    if not responded then
      responded = true
      local confirmed = value and (value:lower() == "y" or value:lower() == "yes")
      rpc.send_command(M.format_response(event.id, confirmed))
    end
  end)
end

local function handle_input(event, rpc)
  local Snacks = require("snacks")
  local responded = false

  local timer = vim.defer_fn(function()
    if not responded then
      responded = true
      rpc.send_command(M.format_cancellation(event.id))
    end
  end, TIMEOUT_MS)

  Snacks.input({
    prompt = event.prompt or "Input: ",
    default = event.default or "",
  }, function(value)
    if not responded then
      responded = true
      if timer then timer:stop() end
      if value then
        rpc.send_command(M.format_response(event.id, value))
      else
        rpc.send_command(M.format_cancellation(event.id))
      end
    end
  end)
end

local function handle_editor(event, rpc)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].filetype = event.language or "markdown"

  if event.content then
    local lines = vim.split(event.content, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end

  vim.cmd("botright split")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_height(win, 15)
  vim.api.nvim_win_set_buf(win, buf)

  local responded = false
  vim.keymap.set("n", "<leader>s", function()
    if not responded then
      responded = true
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local content = table.concat(lines, "\n")
      rpc.send_command(M.format_response(event.id, content))
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf })

  vim.keymap.set("n", "q", function()
    if not responded then
      responded = true
      rpc.send_command(M.format_cancellation(event.id))
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf })
end

function M.subscribe(rpc)
  rpc.on("extension_ui_request", function(event)
    if event.method == "select" then
      handle_select(event, rpc)
    elseif event.method == "confirm" then
      handle_confirm(event, rpc)
    elseif event.method == "input" then
      handle_input(event, rpc)
    elseif event.method == "editor" then
      handle_editor(event, rpc)
    else
      rpc.send_command(M.format_cancellation(event.id))
    end
  end)
end

return M
