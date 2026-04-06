local M = {}

local MAX_TOOL_OUTPUT_LINES = 20
local MAX_TOOL_OUTPUT_CHARS = 1500

M._history_buf = nil
M._input_buf = nil
M._history_win = nil
M._input_win = nil
M._split_win = nil
M._streaming_text = ""

function M.format_user_message(text)
  return { "", ">>> You", text, "" }
end

function M.format_assistant_header()
  return { "<<< Pi" }
end

function M.format_tool_start(tool_name, args)
  local detail = ""
  if tool_name == "bash" and args.command then
    detail = ": " .. args.command
  elseif tool_name == "read" and args.path then
    detail = ": " .. args.path
  elseif tool_name == "edit" and args.path then
    detail = ": " .. args.path
  elseif tool_name == "write" and args.path then
    detail = ": " .. args.path
  end
  return { "", "[" .. tool_name .. detail .. "]" }
end

function M.format_tool_result(output)
  if not output or output == "" then
    return { "[done]" }
  end
  if #output > MAX_TOOL_OUTPUT_CHARS then
    return { "  " .. output:sub(1, MAX_TOOL_OUTPUT_CHARS) .. "  ... (truncated)" }
  end
  local lines = vim.split(output, "\n")
  if #lines > MAX_TOOL_OUTPUT_LINES then
    local truncated = {}
    for i = 1, MAX_TOOL_OUTPUT_LINES do
      table.insert(truncated, "  " .. lines[i])
    end
    table.insert(truncated, "  ... (" .. (#lines - MAX_TOOL_OUTPUT_LINES) .. " more lines)")
    return truncated
  end
  local result = {}
  for _, line in ipairs(lines) do
    table.insert(result, "  " .. line)
  end
  return result
end

local function create_history_buf()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "pi-traycer-chat"
  vim.api.nvim_buf_set_name(buf, "pi-traycer://chat")
  vim.bo[buf].modifiable = false
  return buf
end

local function create_input_buf()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "pi-traycer-input"
  vim.api.nvim_buf_set_name(buf, "pi-traycer://input")
  return buf
end

local function append_to_history(lines)
  if not M._history_buf or not vim.api.nvim_buf_is_valid(M._history_buf) then return end
  vim.bo[M._history_buf].modifiable = true
  vim.api.nvim_buf_set_lines(M._history_buf, -1, -1, false, lines)
  vim.bo[M._history_buf].modifiable = false
  if M._history_win and vim.api.nvim_win_is_valid(M._history_win) then
    local line_count = vim.api.nvim_buf_line_count(M._history_buf)
    vim.api.nvim_win_set_cursor(M._history_win, { line_count, 0 })
  end
end

function M.is_open()
  return M._split_win ~= nil
    and vim.api.nvim_win_is_valid(M._split_win)
end

function M.toggle()
  if M.is_open() then
    M.close()
    return
  end
  M.open()
end

function M.open()
  if M.is_open() then
    vim.api.nvim_set_current_win(M._input_win)
    return
  end

  local config = require("pi-traycer.config").get()
  local position = config.chat.position
  local size = config.chat.size

  if not M._history_buf or not vim.api.nvim_buf_is_valid(M._history_buf) then
    M._history_buf = create_history_buf()
  end
  if not M._input_buf or not vim.api.nvim_buf_is_valid(M._input_buf) then
    M._input_buf = create_input_buf()
  end

  local split_cmd = position == "right" and "botright vsplit" or "botright split"
  vim.cmd(split_cmd)
  M._split_win = vim.api.nvim_get_current_win()

  if position == "right" then
    local width = math.floor(vim.o.columns * size)
    vim.api.nvim_win_set_width(M._split_win, width)
  else
    local height = math.floor(vim.o.lines * size)
    vim.api.nvim_win_set_height(M._split_win, height)
  end

  vim.api.nvim_win_set_buf(M._split_win, M._history_buf)
  M._history_win = M._split_win

  vim.cmd("belowright split")
  M._input_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_height(M._input_win, 3)
  vim.api.nvim_win_set_buf(M._input_win, M._input_buf)

  vim.keymap.set("n", "<CR>", function() M._send_from_input() end, { buffer = M._input_buf })
  vim.keymap.set("i", "<CR>", function()
    vim.cmd("stopinsert")
    M._send_from_input()
  end, { buffer = M._input_buf })
  vim.keymap.set("n", "q", function() M.close() end, { buffer = M._input_buf })
  vim.keymap.set("n", "q", function() M.close() end, { buffer = M._history_buf })

  vim.api.nvim_set_current_win(M._input_win)
  vim.cmd("startinsert")
end

function M.close()
  if M._split_win and vim.api.nvim_win_is_valid(M._split_win) then
    vim.api.nvim_win_close(M._split_win, true)
  end
  if M._input_win and vim.api.nvim_win_is_valid(M._input_win) then
    vim.api.nvim_win_close(M._input_win, true)
  end
  M._split_win = nil
  M._history_win = nil
  M._input_win = nil
end

function M._send_from_input()
  if not M._input_buf or not vim.api.nvim_buf_is_valid(M._input_buf) then return end
  local lines = vim.api.nvim_buf_get_lines(M._input_buf, 0, -1, false)
  local text = vim.trim(table.concat(lines, "\n"))
  if text == "" then return end
  vim.api.nvim_buf_set_lines(M._input_buf, 0, -1, false, { "" })
  M.send(text)
end

function M.send(text, opts)
  opts = opts or {}
  local rpc = require("pi-traycer.rpc")
  if not rpc.is_connected() then
    vim.notify("[pi-traycer] Not connected to pi. Start a session first.", vim.log.levels.WARN)
    return
  end
  append_to_history(M.format_user_message(text))
  local context = require("pi-traycer.context")
  local ctx = context.get_context({ include_selection = opts.include_selection })
  local message = text .. "\n\n---\n" .. context.format_for_prompt(ctx)
  rpc.send_command({ type = "prompt", message = message })
end

function M.clear()
  if M._history_buf and vim.api.nvim_buf_is_valid(M._history_buf) then
    vim.bo[M._history_buf].modifiable = true
    vim.api.nvim_buf_set_lines(M._history_buf, 0, -1, false, { "" })
    vim.bo[M._history_buf].modifiable = false
  end
  M._streaming_text = ""
end

M._append_to_history = append_to_history

function M.subscribe(rpc)
  rpc.on("agent_start", function()
    M._streaming_text = ""
    M._append_to_history(M.format_assistant_header())
  end)

  rpc.on("message_update", function(event)
    local msg_event = event.assistantMessageEvent
    if not msg_event then return end

    if msg_event.type == "text_delta" then
      M._streaming_text = M._streaming_text .. msg_event.delta
      local lines = vim.split(M._streaming_text, "\n")
      if not M._history_buf or not vim.api.nvim_buf_is_valid(M._history_buf) then return end
      vim.bo[M._history_buf].modifiable = true
      local buf_lines = vim.api.nvim_buf_line_count(M._history_buf)
      local header_line = buf_lines
      for i = buf_lines, 1, -1 do
        local line = vim.api.nvim_buf_get_lines(M._history_buf, i - 1, i, false)[1]
        if line == "<<< Pi" then
          header_line = i
          break
        end
      end
      vim.api.nvim_buf_set_lines(M._history_buf, header_line, -1, false, lines)
      vim.bo[M._history_buf].modifiable = false
      if M._history_win and vim.api.nvim_win_is_valid(M._history_win) then
        local new_count = vim.api.nvim_buf_line_count(M._history_buf)
        vim.api.nvim_win_set_cursor(M._history_win, { new_count, 0 })
      end
    end
  end)

  rpc.on("tool_execution_start", function(event)
    M._append_to_history(M.format_tool_start(event.toolName or "tool", event.args or {}))
  end)

  rpc.on("tool_execution_update", function(event)
    if event.partialResult then
      local text = ""
      if type(event.partialResult) == "string" then
        text = event.partialResult
      elseif event.partialResult.content then
        for _, block in ipairs(event.partialResult.content) do
          if block.text then text = text .. block.text end
        end
      end
      if text ~= "" then
        local lines = M.format_tool_result(text)
        if not M._history_buf or not vim.api.nvim_buf_is_valid(M._history_buf) then return end
        vim.bo[M._history_buf].modifiable = true
        local buf_lines = vim.api.nvim_buf_line_count(M._history_buf)
        local tool_start = buf_lines
        for i = buf_lines, math.max(1, buf_lines - 30), -1 do
          local line = vim.api.nvim_buf_get_lines(M._history_buf, i - 1, i, false)[1]
          if line and line:match("^%[") then
            tool_start = i
            break
          end
        end
        vim.api.nvim_buf_set_lines(M._history_buf, tool_start, -1, false, lines)
        vim.bo[M._history_buf].modifiable = false
      end
    end
  end)

  rpc.on("tool_execution_end", function()
    M._append_to_history({ "" })
  end)

  rpc.on("agent_end", function(event)
    M._streaming_text = ""
    M._append_to_history({ "", "---", "" })
    local state = require("pi-traycer.state")
    if event.messages then
      for _, msg in ipairs(event.messages) do
        if msg.usage then
          state.update_token_stats({
            input = (state.get("token_stats").input or 0) + (msg.usage.inputTokens or 0),
            output = (state.get("token_stats").output or 0) + (msg.usage.outputTokens or 0),
            cache_read = (state.get("token_stats").cache_read or 0) + (msg.usage.cacheReadTokens or 0),
            cache_write = (state.get("token_stats").cache_write or 0) + (msg.usage.cacheWriteTokens or 0),
          })
        end
      end
    end
    local config = require("pi-traycer.config").get()
    if config.notifications.cost_on_completion then
      local stats = state.get("token_stats")
      if stats.input then
        vim.notify(
          string.format("[pi-traycer] Tokens: %d in / %d out", stats.input or 0, stats.output or 0),
          vim.log.levels.INFO
        )
      end
    end
  end)
end

return M
