# Example: How foldsync.nvim Works

This document demonstrates how foldsync.nvim tracks and restores folds and cursor position intelligently.

## Testing the Plugin

### Step 1: Create a test file with foldable content

Create a file with some code that can be folded:

```lua
-- test.lua
function calculate_sum(a, b)
  local result = a + b
  print("Sum:", result)
  return result
end

function calculate_product(a, b)
  local result = a * b
  print("Product:", result)
  return result
end

function calculate_difference(a, b)
  local result = a - b
  print("Difference:", result)
  return result
end
```

### Step 2: Set up folding

In Neovim, open the test file and set up folding:

```vim
:set foldmethod=indent
" or
:set foldmethod=syntax
```

### Step 3: Create some folds

Close some functions using `zc` when your cursor is on the function line:
- Close the first function
- Leave the second function open
- Close the third function

### Step 4: Save and quit

```vim
:wq
```

The plugin will automatically save the fold state.

### Step 5: Edit the file externally

Open the file in another editor (or use git/sed/etc.) and add lines above the folds:

```bash
# Add a comment at the top
sed -i '1i-- This is a new comment' test.lua
```

This moves all the functions down by one line.

### Step 6: Reopen in Neovim

Open the file again in Neovim:

```vim
nvim test.lua
```

**Result**: The folds will be restored at their correct locations, even though the line numbers changed! The cursor position will also be restored to where it was, tracking the content if the file has changed. The plugin uses content-based signatures to find where each fold and cursor position moved to.

## How Content-Based Tracking Works

### Signature Generation

For each closed fold, the plugin:
1. Hashes the first 3 lines of the fold
2. Hashes the last 3 lines of the fold
3. Combines these hashes into a unique signature

For the cursor position, the plugin:
1. Hashes 2 lines before the cursor
2. Hashes the cursor line
3. Hashes 2 lines after the cursor
4. Combines these hashes into a unique signature

### Smart Restoration

When restoring folds and cursor position:
1. First checks if the fold/cursor is still at its original location (±5 lines)
2. If not found, searches the entire buffer for matching content
3. Falls back to the original line number if signature matching fails

### Example Scenarios

**Scenario 1: Lines added above**
- Original fold at lines 10-20, cursor at line 15
- 5 lines added at line 1
- Plugin finds fold at lines 15-25 and cursor at line 20 using content signatures ✓

**Scenario 2: Lines removed above**
- Original fold at lines 10-20, cursor at line 12
- 3 lines removed at line 5
- Plugin finds fold at lines 7-17 and cursor at line 9 using content signatures ✓

**Scenario 3: Fold content modified**
- Original fold content changed
- Plugin attempts signature match (may fail if content heavily modified)
- Falls back to line number if available ✓

**Scenario 4: File reordered (e.g., by git rebase)**
- Functions moved to different parts of the file
- Plugin searches entire buffer for matching signatures
- Restores folds and cursor position at new locations ✓

## Advanced Usage

### Debugging

Enable debug mode to see what the plugin is doing:

```lua
require('foldsync').setup({
  debug = true
})
```

### Manual Control

```vim
" Temporarily disable
:FoldsyncDisable

" Re-enable
:FoldsyncEnable

" Toggle
:FoldsyncToggle

" Force save current state
:FoldsyncSave

" Force restore from saved state
:FoldsyncRestore
```

### Storage Location

Fold data is stored at:
- Linux/macOS: `~/.local/share/nvim/foldsync/`
- Windows: `%LOCALAPPDATA%\nvim-data\foldsync\`

Each file gets a JSON storage file with the fold information.

## Limitations

- Works best with `foldmethod=indent` or `foldmethod=syntax`
- Manual folds (created with `zf`) are not tracked across sessions
- Very large folds (>1000 lines) may have slower signature matching
- If fold content is completely rewritten, signature matching may fail

## Tips

1. Use with version control: The plugin works great with git workflows
2. Combine with sessions: Save your session along with fold states for complete restoration
3. File-specific folds: Each file maintains its own fold state independently
