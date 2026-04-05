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

local MAX_RESTARTS = 3

function M.start_session(session_name, opts)
  opts = opts or {}
  local config = require("pi-traycer.config").get()

  local session_dir = config.pi.session_dir or ".pi/sessions"
  vim.fn.mkdir(session_dir, "p")
  local session_file = session_dir .. "/" .. session_name .. ".jsonl"

  local cmd = { "pi", "--mode", "rpc", "--session", session_file }
  if config.pi.model then
    table.insert(cmd, "--model")
    table.insert(cmd, config.pi.model)
  end
  if config.pi.thinking then
    table.insert(cmd, "--thinking")
    table.insert(cmd, config.pi.thinking)
  end

  M._state.stdout_buf = ""
  M._state.session_file = session_file

  M._state.proc = vim.system(cmd, {
    stdin = true,
    stdout = function(_, data)
      if data then
        vim.schedule(function()
          M._process_stdout(data)
        end)
      end
    end,
    stderr = function(_, data)
      if data and data ~= "" then
        vim.schedule(function()
          vim.notify("[pi-traycer] stderr: " .. vim.trim(data), vim.log.levels.DEBUG)
        end)
      end
    end,
  }, function(result)
    vim.schedule(function()
      M._state.proc = nil
      M._state.is_streaming = false
      M._dispatch({ type = "process_exit", code = result.code })

      if result.code ~= 0 and M._state.restart_count < MAX_RESTARTS then
        M._state.restart_count = M._state.restart_count + 1
        vim.notify(
          "[pi-traycer] pi crashed (exit " .. result.code .. "), restarting ("
            .. M._state.restart_count .. "/" .. MAX_RESTARTS .. ")",
          vim.log.levels.WARN
        )
        M.start_session(session_name, opts)
      elseif result.code ~= 0 then
        vim.notify("[pi-traycer] pi crashed and max restarts reached", vim.log.levels.ERROR)
      end
    end)
  end)

  return M._state.proc, session_file
end

function M.stop()
  if M._state.proc then
    M._state.proc:kill(15)
    M._state.proc = nil
    M._state.is_streaming = false
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

function M._init_internal_handlers()
  M.on("agent_start", function()
    M._state.is_streaming = true
  end)
  M.on("agent_end", function()
    M._state.is_streaming = false
    M._state.restart_count = 0
  end)
end

return M
