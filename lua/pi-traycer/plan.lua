local M = {}

M._plan_buf = nil
M._plan_win = nil
M._active_epic_id = nil

local STATUS_CYCLE = { pending = "active", active = "done", done = "pending" }

local function generate_id()
  local template = "xxxxxxxx"
  return string.gsub(template, "x", function()
    return string.format("%x", math.random(0, 15))
  end)
end

local function plans_dir(override)
  if override then return override end
  return ".pi/plans"
end

local function epic_path(epic_id, dir)
  return plans_dir(dir) .. "/" .. epic_id .. ".json"
end

function M.create_epic(title, dir)
  local d = plans_dir(dir)
  vim.fn.mkdir(d, "p")
  local epic = {
    id = generate_id(),
    title = title,
    description = "",
    status = "draft",
    created_at = os.time(),
    updated_at = os.time(),
    session_id = nil,
    tasks = {},
  }
  local path = epic_path(epic.id, dir)
  local json = vim.json.encode(epic)
  local f = io.open(path, "w")
  if f then
    f:write(json)
    f:close()
  end
  return epic
end

function M.load_epic(epic_id, dir)
  local path = epic_path(epic_id, dir)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  local ok, epic = pcall(vim.json.decode, content)
  if not ok then return nil end
  return epic
end

function M.save_epic(epic, dir)
  local path = epic_path(epic.id, dir)
  epic.updated_at = os.time()
  local json = vim.json.encode(epic)
  local f = io.open(path, "w")
  if f then
    f:write(json)
    f:close()
  end
end

function M.set_tasks(epic_id, tasks, dir)
  local epic = M.load_epic(epic_id, dir)
  if not epic then return end
  epic.tasks = {}
  for _, task in ipairs(tasks) do
    table.insert(epic.tasks, {
      id = task.id,
      title = task.title,
      description = task.description or "",
      status = "pending",
      dependencies = task.dependencies or {},
      files_changed = {},
    })
  end
  epic.status = "active"
  M.save_epic(epic, dir)
end

function M.update_task_status(epic_id, task_id, new_status, dir)
  local epic = M.load_epic(epic_id, dir)
  if not epic then return end
  for _, task in ipairs(epic.tasks) do
    if task.id == task_id then
      task.status = new_status
      break
    end
  end
  M.save_epic(epic, dir)
end

function M.toggle_task_status(epic_id, task_id, dir)
  local epic = M.load_epic(epic_id, dir)
  if not epic then return end
  for _, task in ipairs(epic.tasks) do
    if task.id == task_id then
      task.status = STATUS_CYCLE[task.status] or "pending"
      break
    end
  end
  M.save_epic(epic, dir)
end

function M.list_epics(dir)
  local d = plans_dir(dir)
  local files = vim.fn.glob(d .. "/*.json", false, true)
  local epics = {}
  for _, file in ipairs(files) do
    local f = io.open(file, "r")
    if f then
      local content = f:read("*a")
      f:close()
      local ok, epic = pcall(vim.json.decode, content)
      if ok then
        table.insert(epics, { id = epic.id, title = epic.title, status = epic.status })
      end
    end
  end
  return epics
end

-- Plan Panel UI

local STATUS_ICONS = {
  pending = "○",
  active = "▶",
  done = "✓",
}

local function render_task_tree(buf, epic)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  vim.bo[buf].modifiable = true
  local lines = {}
  table.insert(lines, "Epic: " .. epic.title)
  table.insert(lines, "Status: " .. epic.status)
  table.insert(lines, string.rep("─", 40))
  table.insert(lines, "")
  for _, task in ipairs(epic.tasks) do
    local icon = STATUS_ICONS[task.status] or "?"
    local deps = ""
    if task.dependencies and #task.dependencies > 0 then
      deps = " [after: " .. table.concat(task.dependencies, ", ") .. "]"
    end
    table.insert(lines, icon .. " " .. task.id .. ": " .. task.title .. deps)
  end
  if #epic.tasks == 0 then
    table.insert(lines, "(no tasks yet)")
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

local function get_task_id_at_cursor()
  local line = vim.api.nvim_get_current_line()
  local id = line:match("^[○▶✓?] (task%-[%w%-]+):")
  return id
end

function M.is_open()
  return M._plan_win ~= nil and vim.api.nvim_win_is_valid(M._plan_win)
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
    vim.api.nvim_set_current_win(M._plan_win)
    return
  end

  local config = require("pi-traycer.config").get()

  if not M._plan_buf or not vim.api.nvim_buf_is_valid(M._plan_buf) then
    M._plan_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[M._plan_buf].buftype = "nofile"
    vim.bo[M._plan_buf].bufhidden = "hide"
    vim.bo[M._plan_buf].swapfile = false
    vim.bo[M._plan_buf].filetype = "pi-traycer-plan"
    vim.api.nvim_buf_set_name(M._plan_buf, "pi-traycer://plan")
    vim.bo[M._plan_buf].modifiable = false
  end

  local split_cmd = config.plan.position == "bottom" and "botright split" or "botright vsplit"
  vim.cmd(split_cmd)
  M._plan_win = vim.api.nvim_get_current_win()

  if config.plan.position == "bottom" then
    local height = math.floor(vim.o.lines * config.plan.size)
    vim.api.nvim_win_set_height(M._plan_win, height)
  else
    local width = math.floor(vim.o.columns * config.plan.size)
    vim.api.nvim_win_set_width(M._plan_win, width)
  end

  vim.api.nvim_win_set_buf(M._plan_win, M._plan_buf)

  vim.keymap.set("n", "t", function()
    local task_id = get_task_id_at_cursor()
    if task_id and M._active_epic_id then
      M.toggle_task_status(M._active_epic_id, task_id)
      M.refresh()
    end
  end, { buffer = M._plan_buf })

  vim.keymap.set("n", "<CR>", function()
    local task_id = get_task_id_at_cursor()
    if task_id and M._active_epic_id then
      local epic = M.load_epic(M._active_epic_id)
      if epic then
        for _, task in ipairs(epic.tasks) do
          if task.id == task_id then
            vim.notify("[pi-traycer] Task: " .. task.title .. "\n" .. (task.description or ""), vim.log.levels.INFO)
            break
          end
        end
      end
    end
  end, { buffer = M._plan_buf })

  vim.keymap.set("n", "d", function()
    local task_id = get_task_id_at_cursor()
    if task_id and M._active_epic_id then
      local epic = M.load_epic(M._active_epic_id)
      if epic then
        for _, task in ipairs(epic.tasks) do
          if task.id == task_id then
            local detail = task.id .. ": " .. task.title .. "\n"
              .. "Status: " .. task.status .. "\n"
              .. "Description: " .. (task.description or "(none)") .. "\n"
              .. "Dependencies: " .. (#task.dependencies > 0 and table.concat(task.dependencies, ", ") or "(none)")
            vim.notify(detail, vim.log.levels.INFO)
            break
          end
        end
      end
    end
  end, { buffer = M._plan_buf })

  vim.keymap.set("n", "q", function() M.close() end, { buffer = M._plan_buf })

  M.refresh()
end

function M.close()
  if M._plan_win and vim.api.nvim_win_is_valid(M._plan_win) then
    vim.api.nvim_win_close(M._plan_win, true)
  end
  M._plan_win = nil
end

function M.refresh()
  if not M._active_epic_id then
    if M._plan_buf and vim.api.nvim_buf_is_valid(M._plan_buf) then
      vim.bo[M._plan_buf].modifiable = true
      vim.api.nvim_buf_set_lines(M._plan_buf, 0, -1, false, { "No active epic.", "", "Use :PiEpic <title> to create one." })
      vim.bo[M._plan_buf].modifiable = false
    end
    return
  end
  local epic = M.load_epic(M._active_epic_id)
  if epic then
    render_task_tree(M._plan_buf, epic)
  end
end

function M.set_active_epic(epic_id)
  M._active_epic_id = epic_id
  require("pi-traycer.state").set("active_epic_id", epic_id)
  M.refresh()
end

function M.get_active_epic_id()
  return M._active_epic_id
end

function M.subscribe(rpc)
  rpc.on("tool_execution_start", function(event)
    if event.toolName == "create_plan" and event.args then
      local args = event.args
      if not M._active_epic_id then
        local epic = M.create_epic(args.epic_title or "Untitled Epic")
        M.set_active_epic(epic.id)
      end
      if args.tasks then
        M.set_tasks(M._active_epic_id, args.tasks)
        M.refresh()
        vim.notify(
          "[pi-traycer] Plan created: " .. (args.epic_title or "") .. " (" .. #args.tasks .. " tasks)",
          vim.log.levels.INFO
        )
      end
    end
  end)
end

return M
