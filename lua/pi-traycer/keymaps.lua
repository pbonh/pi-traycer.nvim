local M = {}

function M.setup()
  local config = require("pi-traycer.config").get()
  local maps = config.keymaps

  if maps.chat then
    vim.keymap.set("n", maps.chat, "<cmd>PiChat<cr>", { desc = "Toggle pi chat" })
  end
  if maps.epic then
    vim.keymap.set("n", maps.epic, "<cmd>PiEpic<cr>", { desc = "Create/focus pi epic" })
  end
  if maps.plan then
    vim.keymap.set("n", maps.plan, "<cmd>PiPlan<cr>", { desc = "Toggle pi plan panel" })
  end
  if maps.send_selection then
    vim.keymap.set("v", maps.send_selection, function()
      vim.cmd('noautocmd normal! "vy')
      local text = vim.fn.getreg("v")
      if text and text ~= "" then
        local chat = require("pi-traycer.chat")
        if not chat.is_open() then chat.open() end
        chat.send(text, { include_selection = true })
      end
    end, { desc = "Send selection to pi chat" })
  end
  if maps.abort then
    vim.keymap.set("n", maps.abort, "<cmd>PiAbort<cr>", { desc = "Abort pi operation" })
  end
end

return M
