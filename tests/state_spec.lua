describe("state", function()
  local state

  before_each(function()
    package.loaded["pi-traycer.state"] = nil
    state = require("pi-traycer.state")
  end)

  it("starts with empty state", function()
    assert.is_nil(state.get("session_file"))
    assert.is_nil(state.get("active_epic_id"))
    assert.are.same({}, state.get("token_stats"))
  end)

  it("sets and gets values", function()
    state.set("session_file", ".pi/sessions/test.jsonl")
    assert.are.equal(".pi/sessions/test.jsonl", state.get("session_file"))
  end)

  it("updates token stats", function()
    state.update_token_stats({ input = 100, output = 50, cost = 0.01 })
    local stats = state.get("token_stats")
    assert.are.equal(100, stats.input)
    assert.are.equal(50, stats.output)
    assert.are.equal(0.01, stats.cost)
  end)

  it("resets to initial state", function()
    state.set("session_file", "test")
    state.reset()
    assert.is_nil(state.get("session_file"))
  end)
end)
