describe("rpc", function()
  local rpc

  before_each(function()
    package.loaded["pi-traycer.rpc"] = nil
    rpc = require("pi-traycer.rpc")
  end)

  describe("parse_line", function()
    it("parses valid JSON", function()
      local result = rpc._parse_line('{"type":"agent_start"}')
      assert.are.same({ type = "agent_start" }, result)
    end)

    it("returns nil for empty string", function()
      assert.is_nil(rpc._parse_line(""))
    end)

    it("strips trailing carriage return", function()
      local result = rpc._parse_line('{"type":"agent_end"}\r')
      assert.are.same({ type = "agent_end" }, result)
    end)

    it("returns nil for invalid JSON", function()
      local result = rpc._parse_line("not json")
      assert.is_nil(result)
    end)

    it("parses nested objects", function()
      local line = '{"type":"message_update","assistantMessageEvent":{"type":"text_delta","delta":"hi"}}'
      local result = rpc._parse_line(line)
      assert.are.equal("message_update", result.type)
      assert.are.equal("text_delta", result.assistantMessageEvent.type)
      assert.are.equal("hi", result.assistantMessageEvent.delta)
    end)
  end)

  describe("process_stdout", function()
    it("handles complete single line", function()
      local events = {}
      rpc.on("agent_start", function(e) table.insert(events, e) end)
      rpc._process_stdout('{"type":"agent_start"}\n')
      assert.are.equal(1, #events)
      assert.are.equal("agent_start", events[1].type)
    end)

    it("handles multiple lines in one chunk", function()
      local events = {}
      rpc.on("*", function(e) table.insert(events, e) end)
      rpc._process_stdout('{"type":"agent_start"}\n{"type":"agent_end"}\n')
      assert.are.equal(2, #events)
    end)

    it("buffers partial lines across chunks", function()
      local events = {}
      rpc.on("agent_start", function(e) table.insert(events, e) end)
      rpc._process_stdout('{"type":')
      assert.are.equal(0, #events)
      rpc._process_stdout('"agent_start"}\n')
      assert.are.equal(1, #events)
    end)

    it("does not split on Unicode line separators", function()
      local events = {}
      rpc.on("*", function(e) table.insert(events, e) end)
      -- U+2028 is \xe2\x80\xa8 in UTF-8
      rpc._process_stdout('{"type":"msg","text":"line\xe2\x80\xa8sep"}\n')
      assert.are.equal(1, #events)
      assert.are.equal("line\xe2\x80\xa8sep", events[1].text)
    end)

    it("handles empty lines gracefully", function()
      local events = {}
      rpc.on("*", function(e) table.insert(events, e) end)
      rpc._process_stdout('\n\n{"type":"agent_start"}\n\n')
      assert.are.equal(1, #events)
    end)
  end)

  describe("event hub", function()
    it("dispatches to specific handler", function()
      local received = nil
      rpc.on("agent_start", function(e) received = e end)
      rpc._dispatch({ type = "agent_start" })
      assert.are.equal("agent_start", received.type)
    end)

    it("dispatches to wildcard handler", function()
      local received = {}
      rpc.on("*", function(e) table.insert(received, e) end)
      rpc._dispatch({ type = "agent_start" })
      rpc._dispatch({ type = "agent_end" })
      assert.are.equal(2, #received)
    end)

    it("supports multiple handlers per event", function()
      local count = 0
      rpc.on("agent_start", function() count = count + 1 end)
      rpc.on("agent_start", function() count = count + 1 end)
      rpc._dispatch({ type = "agent_start" })
      assert.are.equal(2, count)
    end)

    it("removes handler with off()", function()
      local count = 0
      local handler = function() count = count + 1 end
      rpc.on("agent_start", handler)
      rpc._dispatch({ type = "agent_start" })
      assert.are.equal(1, count)
      rpc.off("agent_start", handler)
      rpc._dispatch({ type = "agent_start" })
      assert.are.equal(1, count)
    end)
  end)

  describe("send_command", function()
    it("serializes prompt command", function()
      local written = nil
      rpc._state.proc = {
        write = function(_, data) written = data end,
      }
      rpc.send_command({ type = "prompt", message = "hello" })
      local decoded = vim.json.decode(written:sub(1, -2))
      assert.are.equal("prompt", decoded.type)
      assert.are.equal("hello", decoded.message)
      assert.are.equal("\n", written:sub(-1))
    end)

    it("serializes abort command", function()
      local written = nil
      rpc._state.proc = {
        write = function(_, data) written = data end,
      }
      rpc.send_command({ type = "abort" })
      local decoded = vim.json.decode(written:sub(1, -2))
      assert.are.equal("abort", decoded.type)
    end)

    it("returns false when no process", function()
      rpc._state.proc = nil
      local ok = rpc.send_command({ type = "prompt", message = "hi" })
      assert.is_false(ok)
    end)
  end)
end)
