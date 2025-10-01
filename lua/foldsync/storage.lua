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

-- Get signature for cursor position (context lines around cursor)
local function get_cursor_signature(bufnr, line_num)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  
  -- Get 2 lines before, current line, and 2 lines after for context
  local start_line = math.max(1, line_num - 2)
  local end_line = math.min(line_count, line_num + 2)
  
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  
  -- Hash all context lines and include relative position
  local signature = {}
  for i, line in ipairs(lines) do
    table.insert(signature, hash_line(line))
  end
  
  -- Also store the relative offset to indicate which line is the cursor line
  local cursor_offset = line_num - start_line
  
  return table.concat(signature, ','), cursor_offset
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
  local lnum = 1
  
  -- Efficiently iterate through closed folds only
  while lnum <= line_count do
    local fold_closed = vim.fn.foldclosed(lnum)
    
    -- If this line starts a closed fold
    if fold_closed == lnum then
      local fold_end = vim.fn.foldclosedend(lnum)
      local fold_level = vim.fn.foldlevel(lnum)
      local signature = get_fold_signature(bufnr, lnum, fold_end)
      
      table.insert(folds, {
        start = lnum,
        ['end'] = fold_end,
        signature = signature,
        level = fold_level
      })
      
      -- Skip to the end of this fold
      lnum = fold_end + 1
    else
      lnum = lnum + 1
    end
  end
  
  -- Get cursor position from the window displaying this buffer
  local cursor_line = 1
  local cursor_col = 0
  
  -- Find a window displaying this buffer and get its cursor position
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      local cursor_pos = vim.api.nvim_win_get_cursor(win)
      cursor_line = cursor_pos[1]
      cursor_col = cursor_pos[2]
      break
    end
  end
  
  -- Get cursor signature for tracking across file changes
  local cursor_signature, cursor_offset = get_cursor_signature(bufnr, cursor_line)
  
  -- Save to file
  local data = {
    filepath = vim.api.nvim_buf_get_name(bufnr),
    folds = folds,
    cursor = {
      line = cursor_line,
      col = cursor_col,
      signature = cursor_signature,
      offset = cursor_offset
    },
    timestamp = os.time()
  }
  
  local file = io.open(storage_file, 'w')
  if file then
    file:write(vim.json.encode(data))
    file:close()
  end
end

-- Find where a fold moved to based on its signature
local function find_fold_by_signature(bufnr, signature, old_start, old_end)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  
  -- First, try the original location (±5 lines)
  local search_start = math.max(1, old_start - 5)
  local search_end = math.min(line_count, old_start + 5)
  
  for lnum = search_start, search_end do
    local fold_level = vim.fn.foldlevel(lnum)
    if fold_level > 0 then
      -- Find the actual fold boundaries at this line
      local fold_start = lnum
      local fold_end = lnum
      
      -- Find fold start
      while fold_start > 1 and vim.fn.foldlevel(fold_start - 1) >= fold_level do
        fold_start = fold_start - 1
      end
      
      -- Find fold end
      while fold_end < line_count and vim.fn.foldlevel(fold_end + 1) >= fold_level do
        fold_end = fold_end + 1
      end
      
      -- Check if this fold matches our signature
      local current_signature = get_fold_signature(bufnr, fold_start, fold_end)
      if current_signature == signature then
        return fold_start, fold_end
      end
    end
  end
  
  -- If not found nearby, search the entire buffer
  local lnum = 1
  while lnum <= line_count do
    local fold_level = vim.fn.foldlevel(lnum)
    if fold_level > 0 then
      local fold_start = lnum
      local fold_end = lnum
      
      -- Find fold start
      while fold_start > 1 and vim.fn.foldlevel(fold_start - 1) >= fold_level do
        fold_start = fold_start - 1
      end
      
      -- Find fold end
      while fold_end < line_count and vim.fn.foldlevel(fold_end + 1) >= fold_level do
        fold_end = fold_end + 1
      end
      
      -- Check if this fold matches our signature
      local current_signature = get_fold_signature(bufnr, fold_start, fold_end)
      if current_signature == signature then
        return fold_start, fold_end
      end
      
      -- Skip to after this fold
      lnum = fold_end + 1
    else
      lnum = lnum + 1
    end
  end
  
  return nil, nil
end

-- Find where cursor line moved to based on its signature
local function find_cursor_by_signature(bufnr, signature, cursor_offset, old_line)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  
  -- First, try the original location (±5 lines)
  local search_start = math.max(1, old_line - 5)
  local search_end = math.min(line_count, old_line + 5)
  
  for lnum = search_start, search_end do
    -- Calculate the context window for this potential cursor position
    local context_start = math.max(1, lnum - 2)
    local context_end = math.min(line_count, lnum + 2)
    
    -- Generate signature for this position
    local lines = vim.api.nvim_buf_get_lines(bufnr, context_start - 1, context_end, false)
    local sig_parts = {}
    for _, line in ipairs(lines) do
      table.insert(sig_parts, hash_line(line))
    end
    local current_signature = table.concat(sig_parts, ',')
    
    -- Check if signatures match
    if current_signature == signature then
      return lnum
    end
  end
  
  -- If not found nearby, search the entire buffer
  for lnum = 1, line_count do
    local context_start = math.max(1, lnum - 2)
    local context_end = math.min(line_count, lnum + 2)
    
    -- Generate signature for this position
    local lines = vim.api.nvim_buf_get_lines(bufnr, context_start - 1, context_end, false)
    local sig_parts = {}
    for _, line in ipairs(lines) do
      table.insert(sig_parts, hash_line(line))
    end
    local current_signature = table.concat(sig_parts, ',')
    
    -- Check if signatures match
    if current_signature == signature then
      return lnum
    end
  end
  
  return nil
end

-- Close a fold at a specific line efficiently
local function close_fold_at_line(bufnr, lnum)
  -- Use vim's fold API directly without cursor movement
  -- This avoids the overhead of normal mode commands
  local current_win = vim.api.nvim_get_current_win()
  local current_buf = vim.api.nvim_win_get_buf(current_win)
  
  if current_buf == bufnr then
    -- We're in the right buffer, use foldclose directly
    pcall(vim.cmd, string.format('silent! %dfoldclose', lnum))
  end
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
  
  -- Apply folds and restore cursor
  local function apply_folds_and_cursor()
    -- Check if buffer is still valid
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    
    -- Close folds based on saved state
    for _, fold in ipairs(data.folds) do
      -- Try to find the fold by signature (it may have moved)
      local found_start, found_end = find_fold_by_signature(bufnr, fold.signature, fold.start, fold['end'])
      
      if found_start and found_end then
        -- Close the fold using efficient foldclose command
        close_fold_at_line(bufnr, found_start)
      elseif fold.start <= vim.api.nvim_buf_line_count(bufnr) then
        -- Fallback: try the original line if signature search failed
        local fold_level = vim.fn.foldlevel(fold.start)
        if fold_level > 0 then
          close_fold_at_line(bufnr, fold.start)
        end
      end
    end
    
    -- Restore cursor position if saved
    if data.cursor then
      local cursor_line = data.cursor.line
      local cursor_col = data.cursor.col
      
      -- Try to find where the cursor line moved to using signature
      if data.cursor.signature then
        local found_line = find_cursor_by_signature(bufnr, data.cursor.signature, data.cursor.offset, cursor_line)
        if found_line then
          cursor_line = found_line
        end
      end
      
      -- Ensure cursor position is within buffer bounds
      local line_count = vim.api.nvim_buf_line_count(bufnr)
      cursor_line = math.min(cursor_line, line_count)
      cursor_line = math.max(1, cursor_line)
      
      -- Get the actual line length to ensure column is valid
      local line_content = vim.api.nvim_buf_get_lines(bufnr, cursor_line - 1, cursor_line, false)[1] or ''
      cursor_col = math.min(cursor_col, #line_content)
      
      -- Set cursor position for all windows displaying this buffer
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
          pcall(vim.api.nvim_win_set_cursor, win, {cursor_line, cursor_col})
        end
      end
    end
  end
  
  -- Schedule the restoration to ensure window is ready
  vim.schedule(apply_folds_and_cursor)
end

return M
