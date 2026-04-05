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
end)
