local M = {}

M._handlers = {}
M._state = {
  proc = nil,
  stdout_buf = "",
  session_file = nil,
  is_streaming = false,
  restart_count = 0,
}

function M.on(event_type, handler)
  if not M._handlers[event_type] then
    M._handlers[event_type] = {}
  end
  table.insert(M._handlers[event_type], handler)
end

function M.off(event_type, handler)
  local handlers = M._handlers[event_type]
  if not handlers then return end
  for i, h in ipairs(handlers) do
    if h == handler then
      table.remove(handlers, i)
      return
    end
  end
end

function M._dispatch(event)
  local handlers = M._handlers[event.type] or {}
  for _, handler in ipairs(handlers) do
    handler(event)
  end
  local wildcard = M._handlers["*"] or {}
  for _, handler in ipairs(wildcard) do
    handler(event)
  end
end

function M._parse_line(line)
  if line == "" then return nil end
  if line:sub(-1) == "\r" then
    line = line:sub(1, -2)
  end
  if line == "" then return nil end
  local ok, data = pcall(vim.json.decode, line)
  if not ok then
    vim.notify("[pi-traycer] JSON parse error: " .. tostring(data), vim.log.levels.WARN)
    return nil
  end
  return data
end

function M._process_stdout(data)
  M._state.stdout_buf = M._state.stdout_buf .. data
  while true do
    local newline_pos = M._state.stdout_buf:find("\n")
    if not newline_pos then break end
    local line = M._state.stdout_buf:sub(1, newline_pos - 1)
    M._state.stdout_buf = M._state.stdout_buf:sub(newline_pos + 1)
    local event = M._parse_line(line)
    if event then
      M._dispatch(event)
    end
  end
end

function M.send_command(cmd)
  if not M._state.proc then
    vim.notify("[pi-traycer] No active pi process", vim.log.levels.ERROR)
    return false
  end
  local json = vim.json.encode(cmd) .. "\n"
  M._state.proc:write(json)
  return true
end

function M.is_connected()
  return M._state.proc ~= nil
end

function M.is_streaming()
  return M._state.is_streaming
end

function M._reset()
  M._handlers = {}
  M._state = {
    proc = nil,
    stdout_buf = "",
    session_file = nil,
    is_streaming = false,
    restart_count = 0,
  }
end

return M
