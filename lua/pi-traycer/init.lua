local M = {}

function M.setup(opts)
  local config = require("pi-traycer.config")
  config.setup(opts)

  require("pi-traycer.commands").register()
  require("pi-traycer.keymaps").setup()
end

function M.health()
  vim.health.start("pi-traycer")

  if vim.fn.executable("pi") == 1 then
    vim.health.ok("pi executable found")
  else
    vim.health.error("pi executable not found", { "Install pi: npm install -g @mariozechner/pi-coding-agent" })
  end

  local has_snacks, _ = pcall(require, "snacks")
  if has_snacks then
    vim.health.ok("snacks.nvim found")
  else
    vim.health.error("snacks.nvim not found", { "Install: https://github.com/folke/snacks.nvim" })
  end

  local has_edgy, _ = pcall(require, "edgy")
  if has_edgy then
    vim.health.ok("edgy.nvim found")
  else
    vim.health.warn("edgy.nvim not found (optional for panel docking)", { "Install: https://github.com/folke/edgy.nvim" })
  end

  local has_plenary, _ = pcall(require, "plenary")
  if has_plenary then
    vim.health.ok("plenary.nvim found")
  else
    vim.health.warn("plenary.nvim not found (needed for tests)", { "Install: https://github.com/nvim-lua/plenary.nvim" })
  end
end

return M
