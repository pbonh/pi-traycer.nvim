local M = {}

local _state = {}

local function initial_state()
  return {
    session_file = nil,
    active_epic_id = nil,
    token_stats = {},
    context_pct = 0,
  }
end

_state = initial_state()

function M.get(key)
  return _state[key]
end

function M.set(key, value)
  _state[key] = value
end

function M.update_token_stats(stats)
  _state.token_stats = vim.tbl_deep_extend("force", _state.token_stats, stats)
end

function M.reset()
  _state = initial_state()
end

return M
