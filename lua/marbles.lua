-- marbles.lua v1.0.4-ck
-- License: MIT
-- Original concept and programming by LBS with AI assistance.
-- Fork modifications by Clemens Nylandsted Klokmose.
-- Project URL: https://github.com/cklokmose/marbles.nvim

-- marbles.lua
local M = {}

-- In-memory password cache
local password_cache = nil

-- Default configuration
local default_config = {
  -- File extensions to auto-decrypt and apply security settings
  -- Set to {} to disable extension-based matching
  secure_extensions = { ".marbles" },
  -- Folder patterns to apply security settings (supports wildcards)
  -- Example: { "~/notes/secure/*", "~/secrets/*" }
  secure_folders = {},
  -- Security settings for matched files
  security = {
    disable_swap = true,
    disable_backup = true,
    disable_writebackup = true,
    disable_undofile = true,
    disable_shada = true,  -- Adds folder to shada exclude list
  },
  -- Set matched files to this filetype (nil to keep original)
  filetype = "markdown",
}

local config = {}

-- Check if file matches secure patterns
local function is_secure_file(filepath)
  filepath = filepath or vim.fn.expand("%:p")
  
  -- Check extensions
  for _, ext in ipairs(config.secure_extensions or {}) do
    if filepath:match(vim.pesc(ext) .. "$") then
      return true
    end
  end
  
  -- Check folder patterns
  for _, pattern in ipairs(config.secure_folders or {}) do
    -- Expand ~ to home directory
    local expanded = pattern:gsub("^~", vim.fn.expand("~"))
    -- Convert glob pattern to lua pattern
    local lua_pattern = expanded:gsub("%*", ".*")
    if filepath:match(lua_pattern) then
      return true
    end
  end
  
  return false
end

-- Prompt for password (hidden input)
local function prompt_password(prompt)
  local password = vim.fn.inputsecret(prompt .. ": ")
  if password == "" then
    print("Operation cancelled")
    return nil
  end
  return password
end

-- Confirm password twice
local function prompt_password_confirm()
  local pw1 = vim.fn.inputsecret("Enter encryption password: ")
  local pw2 = vim.fn.inputsecret("Confirm encryption password: ")
  if pw1 == "" or pw2 == "" then
    print("Operation cancelled.")
    return nil
  end
  if pw1 ~= pw2 then
    vim.notify("Passwords do not match. Please try again.", vim.log.levels.ERROR)
    return nil
  end
  return pw1
end

-- Get openssl command based on OS
local function get_openssl_cmd()
  local os_name = vim.loop.os_uname().sysname
  if os_name == "Windows_NT" or os_name:match("Windows") then
    return "C:\\Program Files\\OpenSSL-Win64\\bin\\openssl.exe"
  else
    return "openssl"
  end
end

-- Check if openssl is available
local function check_openssl()
  local cmd = get_openssl_cmd()
  if vim.fn.executable(cmd) == 0 then
    vim.notify("OpenSSL not found. Please install openssl and ensure it's in your PATH.", vim.log.levels.ERROR)
    return false
  end
  return true
end

-- Read buffer content
local function get_buffer_content()
  return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
end

-- Set buffer content
local function set_buffer_content(str)
    vim.bo.readonly = false 
    vim.bo.modifiable = true 
  local lines = vim.split(str, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

-- OpenSSL interface
local function run_openssl(input, mode, password)
  local args = (mode == "encrypt")
    and { "enc", "-aes-256-cbc", "-salt", "-base64", "-pbkdf2", "-iter", "600000", "-pass", "pass:" .. password }
    or  { "enc", "-d", "-aes-256-cbc", "-base64", "-pbkdf2", "-iter", "600000", "-pass", "pass:" .. password }

  local result = vim.fn.system({ get_openssl_cmd(), unpack(args) }, input)
  local success = vim.v.shell_error == 0
  return success, result
end

-- Core processing
local function process_buffer(mode)
  if not check_openssl() then return end
  
  local password = nil

  if mode == "encrypt" then
    if password_cache then
      password = password_cache
    else
      password = prompt_password_confirm()
      if password then
        password_cache = password
      end
    end
  elseif mode == "decrypt" then
    if password_cache then
      password = password_cache
    else
      password = prompt_password("Enter decryption password")
      if not password then return end
      password_cache = password
    end
  end

  if not password then return end

  local content = get_buffer_content()
  local success, result = run_openssl(content, mode, password)

  if success then
    set_buffer_content(result)
    vim.bo.readonly = true
    vim.bo.modifiable = false
    vim.notify("File " .. mode .. "ed successfully.")
  else
    password_cache = nil -- Remove cached key
    vim.notify(mode .. "ion failed:\n" .. result, vim.log.levels.ERROR)
  end
end

-- Try auto-decrypting on open if password is cached
local function try_auto_decrypt()
  if not password_cache then
    return
  end

  local content = get_buffer_content()
  local success, result = run_openssl(content, "decrypt", password_cache)

  if success then
    set_buffer_content(result)
    vim.bo.readonly = false
    vim.bo.modifiable = false
    vim.notify("File auto-decrypted using cached password.")
    vim.bo.readonly = true
    vim.bo.modifiable = false
  else
    vim.notify("Auto-decryption failed. Opening as is.", vim.log.levels.WARN)
  end
end

-- Exported helper
function M.is_password_cached()
  return password_cache ~= nil
end

-- Apply security settings to current buffer
local function apply_security_settings()
  local sec = config.security or {}
  if sec.disable_swap then
    vim.opt_local.swapfile = false
  end
  if sec.disable_backup then
    vim.opt_local.backup = false
  end
  if sec.disable_writebackup then
    vim.opt_local.writebackup = false
  end
  if sec.disable_undofile then
    vim.opt_local.undofile = false
  end
  if config.filetype then
    vim.bo.filetype = config.filetype
  end
end

-- Build autocmd patterns from config
local function get_autocmd_patterns()
  local patterns = {}
  
  -- Add extension patterns
  for _, ext in ipairs(config.secure_extensions or {}) do
    table.insert(patterns, "*" .. ext)
  end
  
  -- Add folder patterns
  for _, folder in ipairs(config.secure_folders or {}) do
    -- Expand ~ to home directory for pattern
    local expanded = folder:gsub("^~", vim.fn.expand("~"))
    table.insert(patterns, expanded)
  end
  
  return patterns
end

function M.setup(opts)
  -- Merge user config with defaults
  config = vim.tbl_deep_extend("force", default_config, opts or {})
  
  -- Add secure folders to shada exclude list
  if config.security and config.security.disable_shada then
    for _, folder in ipairs(config.secure_folders or {}) do
      local expanded = folder:gsub("^~", vim.fn.expand("~"))
      -- Remove trailing /* for shada pattern
      local shada_path = expanded:gsub("/%*$", "")
      vim.opt.shada:append("r" .. shada_path)
    end
  end

  vim.api.nvim_create_user_command("EncryptFile", function()
    vim.bo.readonly = false
    vim.bo.modifiable = true
    process_buffer("encrypt")
    vim.bo.readonly = false
    vim.bo.modifiable = false
  end, {})

  vim.api.nvim_create_user_command("DecryptFile", function()
    vim.bo.readonly = true
    vim.bo.modifiable = true
    process_buffer("decrypt")
    vim.bo.readonly = true
    vim.bo.modifiable = false
  end, {})

  vim.api.nvim_create_user_command("EncryptAndSaveFile", function()
    vim.bo.readonly = false
    vim.bo.modifiable = true
    process_buffer("encrypt")
    vim.bo.readonly = false
    vim.bo.modifiable = true
    vim.cmd("write")
    vim.notify("File encrypted and saved.")
    vim.bo.readonly = false
    vim.bo.modifiable = false
  end, {})

  vim.api.nvim_create_user_command("ToggleReadonly", function()
    if vim.bo.readonly or not vim.bo.modifiable then
      vim.bo.readonly = false
      vim.bo.modifiable = true
      vim.notify("File is now writable.")
    else
      vim.bo.readonly = true
      vim.bo.modifiable = false
      vim.notify("File is now readonly.")
    end
  end, {})

  vim.api.nvim_create_user_command("ClearEncryptionPassword", function()
    password_cache = nil
    vim.notify("Encryption password cleared from memory.")
  end, {})

  vim.api.nvim_create_user_command("SetEncryptionPassword", function()
    local pw = prompt_password_confirm()
    if pw then
      password_cache = pw
      vim.notify("Password set in memory.")
    end
  end, {})

  -- Set up autocmds for secure files
  local patterns = get_autocmd_patterns()
  
  if #patterns > 0 then
    -- Auto-decrypt on open
    vim.api.nvim_create_autocmd({ "BufReadPost" }, {
      pattern = patterns,
      callback = try_auto_decrypt,
    })

    -- Apply security settings
    vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
      pattern = patterns,
      callback = apply_security_settings,
    })
  end

  -- Menu integration
  local marbles_menu = require("marbles_menu")

  local marbles_menu_items = {
    { label = "Set key ....... :SetEncryptionPassword", action = function() vim.cmd("SetEncryptionPassword") end },
    { label = "Clear key ..... :ClearEncryptionPassword", action = function() vim.cmd("ClearEncryptionPassword") end },
    { label = "Decrypt ....... :DecryptFile", action = function() vim.cmd("DecryptFile") end },
    { label = "Encrypt ....... :EncryptFile", action = function() vim.cmd("EncryptFile") end },
    { label = "Encrypt+Save .. :EncryptAndSaveFile", action = function() vim.cmd("EncryptAndSaveFile") end },
    { label = "Toggle RO ..... :ToggleReadonly", action = function() vim.cmd("ToggleReadonly") end },
  }

  function M.open_marbles_menu()
    marbles_menu.open_menu({
      title = "# Marbles (j/k/l/Enter/Esc)",
      menu_items = marbles_menu_items,
      footer = function()
        return M.is_password_cached() and "Encryption password cached." or "No encryption password cached."
      end,
    })
  end

  vim.api.nvim_create_user_command("MarblesStatus", function()
    local filepath = vim.fn.expand("%:p")
    local is_secure = is_secure_file(filepath)
    local lines = {
      "Marbles Status",
      "──────────────────────────",
      "File: " .. filepath,
      "Secure file: " .. (is_secure and "yes" or "no"),
      "Password cached: " .. (password_cache and "yes" or "no"),
      "",
      "Buffer settings:",
      "  swapfile: " .. (vim.opt_local.swapfile:get() and "on" or "OFF"),
      "  backup: " .. (vim.opt_local.backup:get() and "on" or "OFF"),
      "  undofile: " .. (vim.opt_local.undofile:get() and "on" or "OFF"),
    }
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  end, {})

  vim.api.nvim_create_user_command("MarblesMenu", function() M.open_marbles_menu() end, {})
end

return M
