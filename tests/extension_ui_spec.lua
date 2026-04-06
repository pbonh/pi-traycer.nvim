describe("extension_ui", function()
  local ext_ui

  before_each(function()
    package.loaded["pi-traycer.extension_ui"] = nil
    ext_ui = require("pi-traycer.extension_ui")
  end)

  describe("format_response", function()
    it("formats select response", function()
      local resp = ext_ui.format_response("req-1", "option_a")
      assert.are.equal("extension_ui_response", resp.type)
      assert.are.equal("req-1", resp.id)
      assert.are.equal("option_a", resp.value)
      assert.is_nil(resp.cancelled)
    end)

    it("formats cancellation response", function()
      local resp = ext_ui.format_cancellation("req-1")
      assert.are.equal("extension_ui_response", resp.type)
      assert.are.equal("req-1", resp.id)
      assert.is_true(resp.cancelled)
    end)
  end)
end)
