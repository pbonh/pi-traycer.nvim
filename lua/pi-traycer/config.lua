local M = {}

M.defaults = {
  chat = { position = "right", size = 0.4 },
  plan = { position = "bottom", size = 0.3 },
  keymaps = {
    chat = "<leader>pc",
    epic = "<leader>pe",
    plan = "<leader>pp",
    send_selection = "<leader>ps",
    abort = "<leader>pa",
  },
  pi = {
    model = nil,
    thinking = nil,
    session_dir = nil,
  },
  notifications = {
    cost_on_completion = true,
    context_warning_pct = 80,
  },
}

M._options = {}

function M.setup(opts)
  M._options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

function M.get()
  return M._options
end

return M
