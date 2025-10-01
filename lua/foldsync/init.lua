-- Main foldsync module
local M = {}
local storage = require('foldsync.storage')

-- Default configuration
M.config = {
  enabled = true,
  debug = false,
}

-- Setup function to initialize the plugin
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend('force', M.config, opts)
  
  if M.config.debug then
    print('foldsync.nvim: initialized')
  end
end

-- Save folds for the current buffer
function M.save()
  if not M.config.enabled then
    return
  end
  
  local bufnr = vim.api.nvim_get_current_buf()
  
  -- Only save for normal buffers with files
  if vim.bo[bufnr].buftype ~= '' then
    return
  end
  
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if filepath == '' then
    return
  end
  
  if M.config.debug then
    print('foldsync.nvim: saving folds for ' .. filepath)
  end
  
  storage.save_folds(bufnr)
end

-- Restore folds for the current buffer
function M.restore()
  if not M.config.enabled then
    return
  end
  
  local bufnr = vim.api.nvim_get_current_buf()
  
  -- Only restore for normal buffers with files
  if vim.bo[bufnr].buftype ~= '' then
    return
  end
  
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if filepath == '' then
    return
  end
  
  if M.config.debug then
    print('foldsync.nvim: restoring folds for ' .. filepath)
  end
  
  storage.restore_folds(bufnr)
end

-- Enable the plugin
function M.enable()
  M.config.enabled = true
  if M.config.debug then
    print('foldsync.nvim: enabled')
  end
end

-- Disable the plugin
function M.disable()
  M.config.enabled = false
  if M.config.debug then
    print('foldsync.nvim: disabled')
  end
end

-- Toggle the plugin
function M.toggle()
  M.config.enabled = not M.config.enabled
  if M.config.debug then
    print('foldsync.nvim: ' .. (M.config.enabled and 'enabled' or 'disabled'))
  end
end

return M
