if vim.g.loaded_pi_traycer then
  return
end
vim.g.loaded_pi_traycer = true

if vim.fn.executable("pi") ~= 1 then
  vim.notify("[pi-traycer] 'pi' executable not found in PATH. Plugin disabled.", vim.log.levels.WARN)
  return
end
