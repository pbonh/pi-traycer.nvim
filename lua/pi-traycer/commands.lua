local M = {}

function M.register()
  vim.api.nvim_create_user_command("PiChat", function(opts)
    local chat = require("pi-traycer.chat")
    local rpc = require("pi-traycer.rpc")

    if not rpc.is_connected() then
      rpc._init_internal_handlers()
      chat.subscribe(rpc)
      require("pi-traycer.plan").subscribe(rpc)
      require("pi-traycer.extension_ui").subscribe(rpc)
      rpc.start_session("chat")
      require("pi-traycer.state").set("session_file", ".pi/sessions/chat.jsonl")
    end

    if opts.args and opts.args ~= "" then
      if not chat.is_open() then chat.open() end
      chat.send(opts.args)
    else
      chat.toggle()
    end
  end, { nargs = "?", desc = "Toggle pi chat panel or send message" })

  vim.api.nvim_create_user_command("PiEpic", function(opts)
    local plan = require("pi-traycer.plan")
    local rpc = require("pi-traycer.rpc")
    local title = opts.args and opts.args ~= "" and opts.args or nil

    if not title then
      vim.ui.input({ prompt = "Epic title: " }, function(input)
        if input and input ~= "" then
          local epic = plan.create_epic(input)
          plan.set_active_epic(epic.id)
          if not rpc.is_connected() then
            rpc._init_internal_handlers()
            require("pi-traycer.chat").subscribe(rpc)
            plan.subscribe(rpc)
            require("pi-traycer.extension_ui").subscribe(rpc)
            rpc.start_session("epic-" .. epic.id)
            require("pi-traycer.state").set("session_file", ".pi/sessions/epic-" .. epic.id .. ".jsonl")
          end
          if not plan.is_open() then plan.open() end
          vim.notify("[pi-traycer] Epic created: " .. input, vim.log.levels.INFO)
        end
      end)
      return
    end

    local epic = plan.create_epic(title)
    plan.set_active_epic(epic.id)
    if not rpc.is_connected() then
      rpc._init_internal_handlers()
      require("pi-traycer.chat").subscribe(rpc)
      plan.subscribe(rpc)
      require("pi-traycer.extension_ui").subscribe(rpc)
      rpc.start_session("epic-" .. epic.id)
      require("pi-traycer.state").set("session_file", ".pi/sessions/epic-" .. epic.id .. ".jsonl")
    end
    if not plan.is_open() then plan.open() end
    vim.notify("[pi-traycer] Epic created: " .. title, vim.log.levels.INFO)
  end, { nargs = "?", desc = "Create a new epic" })

  vim.api.nvim_create_user_command("PiPlan", function(opts)
    local plan = require("pi-traycer.plan")
    if opts.args and opts.args ~= "" then
      plan.set_active_epic(opts.args)
    end
    plan.toggle()
  end, { nargs = "?", desc = "Toggle plan panel or load specific epic" })

  vim.api.nvim_create_user_command("PiFileAdd", function(opts)
    local path = opts.args and opts.args ~= "" and opts.args or vim.api.nvim_buf_get_name(0)
    if path == "" then
      vim.notify("[pi-traycer] No file to add", vim.log.levels.WARN)
      return
    end
    vim.notify("[pi-traycer] Added to context: " .. vim.fn.fnamemodify(path, ":."), vim.log.levels.INFO)
  end, { nargs = "?", complete = "file", desc = "Add file to context" })

  vim.api.nvim_create_user_command("PiBash", function(opts)
    local rpc = require("pi-traycer.rpc")
    if not rpc.is_connected() then
      vim.notify("[pi-traycer] Not connected to pi", vim.log.levels.WARN)
      return
    end
    rpc.send_command({ type = "bash", command = opts.args })
  end, { nargs = "+", desc = "Run bash command through pi" })

  vim.api.nvim_create_user_command("PiAbort", function()
    local rpc = require("pi-traycer.rpc")
    if rpc.is_streaming() then
      rpc.send_command({ type = "abort" })
      vim.notify("[pi-traycer] Aborting...", vim.log.levels.INFO)
    else
      vim.notify("[pi-traycer] Nothing to abort", vim.log.levels.INFO)
    end
  end, { desc = "Abort current pi operation" })

  vim.api.nvim_create_user_command("PiStatus", function()
    local state = require("pi-traycer.state")
    local rpc = require("pi-traycer.rpc")
    local stats = state.get("token_stats") or {}
    local connected = rpc.is_connected() and "Connected" or "Disconnected"
    local epic_id = state.get("active_epic_id") or "none"
    local msg = string.format(
      "[pi-traycer] %s | Epic: %s\nTokens: %d in / %d out\nCache: %d read / %d write",
      connected,
      epic_id,
      stats.input or 0,
      stats.output or 0,
      stats.cache_read or 0,
      stats.cache_write or 0
    )
    vim.notify(msg, vim.log.levels.INFO)
  end, { desc = "Show pi session status" })
end

return M
