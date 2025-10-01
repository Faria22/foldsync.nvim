-- Storage module for persistent fold information
local M = {}

-- Default storage location
local data_path = vim.fn.stdpath('data') .. '/foldsync'

-- Initialize storage directory
local function ensure_storage_dir()
  if vim.fn.isdirectory(data_path) == 0 then
    vim.fn.mkdir(data_path, 'p')
  end
end

-- Generate a simple hash for a line of text
local function hash_line(line)
  local hash = 0
  for i = 1, #line do
    hash = (hash * 31 + string.byte(line, i)) % 2147483647
  end
  return hash
end

-- Get context lines around a fold to create a unique signature
local function get_fold_signature(bufnr, line_start, line_end)
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_start - 1, line_end, false)
  
  -- Create a signature from the first and last few lines of the fold
  local signature = {}
  
  -- Hash first 3 lines (or all if less than 3)
  local start_lines = math.min(3, #lines)
  for i = 1, start_lines do
    table.insert(signature, hash_line(lines[i]))
  end
  
  -- Hash last 3 lines (or all if less than 3, avoid duplicates)
  if #lines > 6 then
    for i = #lines - 2, #lines do
      table.insert(signature, hash_line(lines[i]))
    end
  end
  
  return table.concat(signature, ',')
end

-- Get storage file path for a buffer
local function get_storage_file(bufnr)
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if filepath == '' then
    return nil
  end
  
  -- Create a unique filename based on the full path
  local filename = filepath:gsub('[/\\:]', '_')
  return data_path .. '/' .. filename .. '.json'
end

-- Save folds for a buffer
function M.save_folds(bufnr)
  ensure_storage_dir()
  
  local storage_file = get_storage_file(bufnr)
  if not storage_file then
    return
  end
  
  local folds = {}
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  
  -- Iterate through all lines to find folds
  for lnum = 1, line_count do
    local fold_level = vim.fn.foldlevel(lnum)
    local fold_closed = vim.fn.foldclosed(lnum)
    
    -- If this line starts a closed fold
    if fold_closed == lnum then
      local fold_end = vim.fn.foldclosedend(lnum)
      local signature = get_fold_signature(bufnr, lnum, fold_end)
      
      table.insert(folds, {
        start = lnum,
        ['end'] = fold_end,
        signature = signature,
        level = fold_level
      })
    end
  end
  
  -- Save to file
  local data = {
    filepath = vim.api.nvim_buf_get_name(bufnr),
    folds = folds,
    timestamp = os.time()
  }
  
  local file = io.open(storage_file, 'w')
  if file then
    file:write(vim.json.encode(data))
    file:close()
  end
end

-- Find where a fold moved to based on its signature
local function find_fold_by_signature(bufnr, signature, old_start)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  
  -- First, try the original location (±5 lines)
  local search_start = math.max(1, old_start - 5)
  local search_end = math.min(line_count, old_start + 5)
  
  for lnum = search_start, search_end do
    local fold_start = vim.fn.foldclosed(lnum)
    if fold_start > 0 then
      local fold_end = vim.fn.foldclosedend(lnum)
      local current_signature = get_fold_signature(bufnr, fold_start, fold_end)
      if current_signature == signature then
        return fold_start
      end
    end
  end
  
  -- If not found nearby, search the entire buffer
  for lnum = 1, line_count do
    local fold_start = vim.fn.foldclosed(lnum)
    if fold_start > 0 then
      local fold_end = vim.fn.foldclosedend(lnum)
      local current_signature = get_fold_signature(bufnr, fold_start, fold_end)
      if current_signature == signature then
        return fold_start
      end
    end
  end
  
  return nil
end

-- Restore folds for a buffer
function M.restore_folds(bufnr)
  local storage_file = get_storage_file(bufnr)
  if not storage_file then
    return
  end
  
  local file = io.open(storage_file, 'r')
  if not file then
    return
  end
  
  local content = file:read('*all')
  file:close()
  
  local ok, data = pcall(vim.json.decode, content)
  if not ok or not data or not data.folds then
    return
  end
  
  -- Verify this is the same file (basic check)
  if data.filepath ~= vim.api.nvim_buf_get_name(bufnr) then
    return
  end
  
  -- Wait a bit for folds to be computed
  vim.defer_fn(function()
    -- Close folds based on saved state
    for _, fold in ipairs(data.folds) do
      -- Try to find the fold by signature (it may have moved)
      local found_line = find_fold_by_signature(bufnr, fold.signature, fold.start)
      
      if found_line then
        -- Close the fold at the found location
        vim.fn.setpos('.', {bufnr, found_line, 1, 0})
        vim.cmd('normal! zc')
      elseif fold.start <= vim.api.nvim_buf_line_count(bufnr) then
        -- Fallback: try the original line if signature search failed
        local fold_exists = vim.fn.foldclosed(fold.start)
        if fold_exists == -1 and vim.fn.foldlevel(fold.start) > 0 then
          vim.fn.setpos('.', {bufnr, fold.start, 1, 0})
          vim.cmd('normal! zc')
        end
      end
    end
  end, 100)
end

return M
