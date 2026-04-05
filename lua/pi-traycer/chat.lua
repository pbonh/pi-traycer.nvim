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

return M
