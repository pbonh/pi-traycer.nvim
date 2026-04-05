describe("chat", function()
  local chat

  before_each(function()
    package.loaded["pi-traycer.chat"] = nil
    chat = require("pi-traycer.chat")
  end)

  describe("format_user_message", function()
    it("formats user message with separator", function()
      local lines = chat.format_user_message("Hello pi")
      assert.truthy(vim.tbl_contains(lines, ">>> You"))
      local found = false
      for _, line in ipairs(lines) do
        if line == "Hello pi" then found = true end
      end
      assert.is_true(found)
    end)
  end)

  describe("format_assistant_header", function()
    it("returns assistant header lines", function()
      local lines = chat.format_assistant_header()
      assert.truthy(vim.tbl_contains(lines, "<<< Pi"))
    end)
  end)

  describe("format_tool_start", function()
    it("formats bash tool", function()
      local lines = chat.format_tool_start("bash", { command = "ls -la" })
      local joined = table.concat(lines, "\n")
      assert.truthy(joined:find("bash"))
      assert.truthy(joined:find("ls %-la"))
    end)

    it("formats read tool", function()
      local lines = chat.format_tool_start("read", { path = "src/main.lua" })
      local joined = table.concat(lines, "\n")
      assert.truthy(joined:find("read"))
      assert.truthy(joined:find("src/main.lua"))
    end)

    it("formats edit tool", function()
      local lines = chat.format_tool_start("edit", { path = "src/main.lua" })
      local joined = table.concat(lines, "\n")
      assert.truthy(joined:find("edit"))
    end)
  end)

  describe("format_tool_result", function()
    it("formats tool output", function()
      local lines = chat.format_tool_result("file1.lua\nfile2.lua")
      assert.is_true(#lines > 0)
    end)

    it("truncates long output", function()
      local long_output = string.rep("x", 2000)
      local lines = chat.format_tool_result(long_output)
      local total_len = 0
      for _, line in ipairs(lines) do
        total_len = total_len + #line
      end
      assert.is_true(total_len < 2000)
    end)
  end)
end)
