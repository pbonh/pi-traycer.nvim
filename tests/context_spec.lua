describe("context", function()
  local context

  before_each(function()
    package.loaded["pi-traycer.context"] = nil
    context = require("pi-traycer.context")
  end)

  it("gathers cwd", function()
    local ctx = context.get_context()
    assert.are.equal(vim.fn.getcwd(), ctx.cwd)
  end)

  it("includes cursor file", function()
    local ctx = context.get_context()
    assert.is_string(ctx.cursor_file)
  end)

  it("includes cursor position", function()
    local ctx = context.get_context()
    assert.is_number(ctx.cursor_line)
    assert.is_number(ctx.cursor_col)
  end)

  it("lists open buffers", function()
    local ctx = context.get_context()
    assert.is_table(ctx.open_buffers)
  end)

  it("formats context for prompt", function()
    local ctx = context.get_context()
    local formatted = context.format_for_prompt(ctx)
    assert.is_string(formatted)
    assert.truthy(formatted:find("Working in"))
  end)
end)
