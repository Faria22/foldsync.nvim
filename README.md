# foldsync.nvim
Persistent, smart fold restoration for Neovim

## Features

- **Persistent folds**: Automatically saves and restores fold states across Neovim sessions
- **Smart fold tracking**: Uses content-based signatures to track folds even after file edits by other programs or git operations
- **Intelligent fold detection**: Detects when folds have moved in the file and restores them at their new location
- **Zero configuration**: Works out of the box with sensible defaults
- **Lightweight**: Written entirely in Lua with minimal dependencies

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'Faria22/foldsync.nvim',
  config = function()
    require('foldsync').setup()
  end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'Faria22/foldsync.nvim',
  config = function()
    require('foldsync').setup()
  end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'Faria22/foldsync.nvim'

lua << EOF
require('foldsync').setup()
EOF
```

## Configuration

The plugin works with default settings, but you can customize it:

```lua
require('foldsync').setup({
  enabled = true,  -- Enable/disable the plugin
  debug = false,   -- Enable debug messages
})
```

## Usage

foldsync.nvim works automatically once installed. It will:

1. Save fold states when you leave a buffer (`BufWinLeave`)
2. Restore fold states when you open a buffer (`BufWinEnter`)
3. Track folds using content signatures, so they're restored correctly even if the file was edited externally

### Commands

The plugin provides several commands:

- `:FoldsyncEnable` - Enable fold synchronization
- `:FoldsyncDisable` - Disable fold synchronization
- `:FoldsyncToggle` - Toggle fold synchronization on/off
- `:FoldsyncSave` - Manually save current fold state
- `:FoldsyncRestore` - Manually restore fold state

### How It Works

foldsync.nvim uses a smart content-based approach to track folds:

1. **Content Signatures**: When saving folds, the plugin creates a signature based on the first and last few lines of each fold
2. **Intelligent Matching**: When restoring, it first checks if the fold is still at its original location (±5 lines)
3. **Full Search**: If not found nearby, it searches the entire buffer for matching content
4. **Fallback**: If signature matching fails, it falls back to the original line number

This approach ensures folds are correctly restored even after:
- Editing the file in other editors
- Git operations (merge, rebase, pull, etc.)
- Automated code formatting
- Adding/removing lines above the fold

## Storage

Fold data is stored in JSON format at:
- Unix/Linux/macOS: `~/.local/share/nvim/foldsync/`
- Windows: `%LOCALAPPDATA%\nvim-data\foldsync\`

Each file gets its own storage file named after its full path with special characters replaced.

## Requirements

- Neovim >= 0.7.0 (for the JSON encoding/decoding API)

## License

MIT
