# 🔒 marbles.nvim

> Fork of [artstisen/marbles.nvim](https://github.com/artstisen/marbles.nvim) with cross-platform support, configurable security settings, and the ability to encrypt any file.

## Easy file encryption for [Neovim](https://neovim.io/)

**marbles.nvim** encrypts and decrypts file contents on-the-fly using AES-256 encryption via OpenSSL.

![marbles-nvim1](https://github.com/artstisen/marbles.nvim/blob/main/marbles-nvim1.gif)
*Demo from original version*

## Features

- **Works on any file** – Encrypt/decrypt any buffer, not just specific file types
- **Cross-platform** – Works on Linux, macOS, and Windows
- **In-memory password caching** – Set password once, auto-decrypt matching files
- **Configurable security** – Disable swap, backup, undo, and shada for sensitive folders/extensions
- **Built-in menu** – Navigate with j/k or arrow keys
- **Readonly by default** – Decrypted files open readonly to prevent accidental changes

![marbles-nvim2](https://github.com/artstisen/marbles.nvim/blob/main/marbles-nvim2.gif)
*Demo from original version*

## Requirements

- Neovim 0.8+ (tested on 0.11)
- [OpenSSL](https://openssl-library.org/) installed and in PATH

## Installation

### lazy.nvim

```lua
{
  "cklokmose/marbles.nvim",
  lazy = false,
  config = function()
    require("marbles").setup()
  end,
}
```

### Manual

Place `marbles.lua` and `marbles_menu.lua` in your `lua/` folder and add to your init:

```lua
require("marbles").setup()
```

## Configuration

```lua
require("marbles").setup({
  -- File extensions to apply security settings and auto-decrypt
  -- Set to {} to disable extension-based matching
  secure_extensions = { ".marbles" },  -- default

  -- Folder patterns to apply security settings (supports wildcards)
  secure_folders = {
    "~/notes/secure/*",
    "~/secrets/*",
  },

  -- Security settings for matched files
  security = {
    disable_swap = true,       -- Disable swapfile
    disable_backup = true,     -- Disable backup
    disable_writebackup = true,-- Disable writebackup
    disable_undofile = true,   -- Disable persistent undo
    disable_shada = true,      -- Exclude from shada (viminfo)
  },

  -- Set matched files to this filetype (nil to keep original)
  filetype = "markdown",
})

-- Optional: Add a keymap for the menu
vim.keymap.set("n", "<leader>s", "<cmd>MarblesMenu<cr>")
```

## Commands

| Command | Description |
|---------|-------------|
| `:EncryptFile` | Encrypt current buffer (prompts for password if not cached) |
| `:DecryptFile` | Decrypt current buffer |
| `:EncryptAndSaveFile` | Encrypt and write the file |
| `:SetEncryptionPassword` | Set/change the in-memory password |
| `:ClearEncryptionPassword` | Clear password from memory |
| `:ToggleReadonly` | Toggle between writable and readonly modes |
| `:MarblesMenu` | Open the interactive menu |
| `:MarblesStatus` | Show current file's security status |

## Usage

1. **Set a password**: `:SetEncryptionPassword` or use the menu
2. **Write some content** in a file
3. **Encrypt**: `:EncryptFile` then `:w` to save (or `:EncryptAndSaveFile`)
4. **Later**: Open the encrypted file – it auto-decrypts if password is cached
5. **Edit**: Use `:ToggleReadonly` to enable editing, then encrypt before saving

## Security Notes

- **AES-256-CBC** encryption with PBKDF2 key derivation
- **Base64** encoding for safe text storage
- Files matching `secure_extensions` or `secure_folders` automatically have swap, backup, undo, and shada disabled
- Password is stored in memory only – cleared on Neovim exit or with `:ClearEncryptionPassword`

> ⚠️ **Warning**: If you forget your password, encrypted data cannot be recovered.

## Credits

- Original concept and programming by LBS with AI assistance
- Fork modifications by Clemens Nylandsted Klokmose with AI assistance as well

## License

MIT – See [LICENSE](LICENSE)
