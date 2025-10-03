-- Plugin entry point for foldsync.nvim
if vim.g.loaded_foldsync then
  return
end
vim.g.loaded_foldsync = 1

-- Create autocommands for fold persistence
local group = vim.api.nvim_create_augroup('Foldsync', { clear = true })

vim.api.nvim_create_autocmd('BufWinEnter', {
  group = group,
  pattern = '*',
  callback = function()
    -- Skip buffers without a foldmethod
    if vim.wo.foldmethod == '' then
      return
    end

    require('foldsync').restore()
  end,
})

-- Save folds when leaving a buffer
vim.api.nvim_create_autocmd('BufWinLeave', {
  group = group,
  pattern = '*',
  callback = function()
    -- Skip buffers without a foldmethod
    if vim.wo.foldmethod == '' then
      return
    end

    require('foldsync').save()
  end,
})

-- Also save on VimLeave to ensure we don't lose data
vim.api.nvim_create_autocmd('VimLeave', {
  group = group,
  pattern = '*',
  callback = function()
    local ok, foldsync = pcall(require, 'foldsync')
    if not ok or not foldsync.config.enabled then
      return
    end

    -- Save all buffers
    local storage = require('foldsync.storage')
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        storage.save_folds(bufnr)
      end
    end
  end,
})

-- Create user commands
vim.api.nvim_create_user_command('FoldsyncEnable', function()
  require('foldsync').enable()
end, {})

vim.api.nvim_create_user_command('FoldsyncDisable', function()
  require('foldsync').disable()
end, {})

vim.api.nvim_create_user_command('FoldsyncToggle', function()
  require('foldsync').toggle()
end, {})

vim.api.nvim_create_user_command('FoldsyncSave', function()
  require('foldsync').save()
end, {})

vim.api.nvim_create_user_command('FoldsyncRestore', function()
  require('foldsync').restore()
end, {})
