local M = {}

--- Filter command-line completion candidates by prefix.
---@param arglead    string The leading portion of the argument being completed.
---@param _cmdline   string Full command line (unused).
---@param _cursorpos number Cursor position in the command line (unused).
---@param plist      string[] List of candidate strings.
---@return string[] Matching candidates.
function M.cmdline_complete(arglead, _cmdline, _cursorpos, plist)
  local result = {}
  for _, p in ipairs(plist) do
    if p and (arglead == "" or p:find(arglead, 1, true) == 1) then
      table.insert(result, p)
    end
  end
  return result
end

--- Complete plugin names for user commands.
--- Uses all plugins currently managed by `vim.pack`.
---@param arglead   string The leading portion of the argument.
---@param cmdline   string Full command line.
---@param cursorpos number Cursor position.
---@return string[] Matching plugin names.
function M.plugins_complete(arglead, cmdline, cursorpos)
  local plist = vim.pack.get() or {}
  local names = {}
  for _, plugin in ipairs(plist) do
    local name = plugin.spec and plugin.spec.name
    if name then
      table.insert(names, name)
    end
  end
  return M.cmdline_complete(arglead, cmdline, cursorpos, names)
end

--- Run build hooks for one or more plugins.
---
--- If `p` is empty, all recorded build hooks are executed. Missing or
--- not-yet-installed plugins are skipped with a notification instead of
--- aborting the whole batch.
---@param p string[] List of plugin names; empty means "all with build hooks".
function M.plugins_build(p)
  if type(p) ~= "table" then
    return
  end

  local build_info = require("mintpack.state").build_info

  if #p == 0 then
    for name, _ in pairs(build_info) do
      table.insert(p, name)
    end
  end

  for _, name in ipairs(p) do
    if name and build_info[name] then
      local info = build_info[name]

      -- `vim.pack.get()` errors for plugins that are not installed yet.
      local ok, packs = pcall(vim.pack.get, { name }, { info = false })
      if not ok or type(packs) ~= "table" or #packs == 0 then
        vim.notify("mintpack: skipping build for '" .. name .. "' (not installed)", vim.log.levels.WARN)
        goto continue
      end

      local pack_info = packs[1]
      local path = pack_info.path
      local build = info.build

      if type(build) == "function" then
        build { name = name, path = path }
      elseif type(build) == "string" then
        local first = build:sub(1, 1)
        if first == ":" then
          -- Ex command, e.g. build = ":TSUpdate".
          vim.cmd(build:sub(2))
        elseif first == "!" then
          -- Async shell command, e.g. build = "!make".
          vim.fn.jobstart(build:sub(2), { cwd = path })
        else
          -- Sync shell command run in the plugin directory.
          local cmd = "cd " .. vim.fn.shellescape(path) .. " && " .. build
          vim.cmd("!" .. cmd)
        end
      end
    end

    ::continue::
  end
end

return M
