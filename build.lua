-- build.lua — executed by lazy.nvim on install and update
-- Copies pi agent extensions to ~/.pi/agent/extensions/

local source_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
local extensions_src = source_dir .. "/extensions"
local extensions_dst = vim.fn.expand("~/.pi/agent/extensions")

local files = { "create-plan.ts" }

coroutine.yield("Installing pi agent extensions...")

vim.fn.mkdir(extensions_dst, "p")

for _, file in ipairs(files) do
  local src = extensions_src .. "/" .. file
  local dst = extensions_dst .. "/" .. file
  local ok, err = vim.uv.fs_copyfile(src, dst)
  if ok then
    coroutine.yield("Installed " .. file .. " to " .. extensions_dst)
  else
    coroutine.yield({
      msg = "Failed to copy " .. file .. ": " .. (err or "unknown error"),
      level = vim.log.levels.ERROR,
    })
  end
end
