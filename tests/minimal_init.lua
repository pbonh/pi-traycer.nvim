local lazypath = vim.fn.stdpath("data") .. "/lazy"
vim.opt.rtp:prepend(lazypath .. "/plenary.nvim")
vim.opt.rtp:prepend(lazypath .. "/snacks.nvim")
vim.opt.rtp:prepend(lazypath .. "/edgy.nvim")
vim.opt.rtp:prepend(".")
vim.cmd("runtime plugin/plenary.vim")
