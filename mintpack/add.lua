local M = {}

local config = require "mintpack.config"
local state = require "mintpack.state"

--- Resolve the full `src` URL for a plugin spec.
--- Short plugin names (`"user/repo"`) are prefixed with the configured base URL.
---@param opt table Plugin spec table.
---@return string src The resolved source URL.
local function resolve_src(opt)
  if type(opt.src) == "string" then
    return opt.src
  end

  local base_url = config.get().url
  if type(base_url) == "string" and base_url:sub(-1) ~= "/" then
    base_url = base_url .. "/"
  end

  return base_url .. opt[1]
end

--- Resolve the plugin name from a spec.
--- Explicit `opt.name` takes precedence, otherwise the last path segment of
--- the source is used.
---@param opt table Plugin spec table.
---@param src string Resolved source URL.
---@return string name The plugin name.
local function resolve_name(opt, src)
  if type(opt.name) == "string" then
    return opt.name
  end
  return string.gsub(src, ".*/", "")
end

--- Add one or more plugin specs to mintpack.
---
--- Accepts:
---   - A short string: `add("user/repo")`
---   - A single spec table: `add({ "user/repo", config = function() ... end })`
---   - A list of spec tables: `add({ { "user/repo" }, { "user/other" } })`
---
--- Supported spec fields:
---   - `[1]` / `src`: Plugin source (short name or full URL).
---   - `name`: Override the derived plugin directory name.
---   - `version`: Branch, tag, commit, or version range.
---   - `data`: Arbitrary data passed through to `vim.pack.add()`.
---   - `enabled`: Set to `false` to skip this plugin.
---   - `priority`: Config execution priority (higher runs first, default: 50).
---   - `init`: Function called immediately when the spec is registered.
---   - `config`: Function called after plugins are installed and loaded.
---   - `build`: Function, `":Command"`, `"!shell command"`, or shell string.
---   - `dependencies`: List of plugin specs to register before this one.
---@param plugin string | table | nil A plugin spec or a list of specs.
function M.add(plugin)
  -- Normalize a single string into a table spec.
  local opt = type(plugin) == "string" and { plugin } or plugin

  -- Handle a list of specs recursively.
  if type(opt) == "table" and type(opt[1]) == "table" then
    for _, p in ipairs(opt) do
      M.add(p)
    end
    return
  end

  -- Validate that we have a usable spec table.
  if type(opt) ~= "table" then
    return
  end

  -- Skip disabled plugins and specs without a valid source.
  if opt.enabled == false then
    return
  end
  if type(opt[1]) ~= "string" and type(opt.src) ~= "string" then
    return
  end

  -- Register dependencies first so they appear before this plugin in the
  -- install/load order. This ensures runtimepath and plugin/ scripts are
  -- ready before the dependent plugin is loaded.
  if type(opt.dependencies) == "table" then
    for _, dep in ipairs(opt.dependencies) do
      M.add(dep)
    end
  end

  local src = resolve_src(opt)
  local name = resolve_name(opt, src)
  local priority = type(opt.priority) == "number" and opt.priority or 50

  -- Record build hook so it can be invoked after install/update.
  if type(opt.build) == "function" or type(opt.build) == "string" then
    state.build_info[name] = { build = opt.build }
  end

  -- Queue the resolved spec for `vim.pack.add()`.
  table.insert(state.plugins, {
    src = src,
    name = opt.name,
    version = opt.version,
    data = opt.data,
  })

  -- Run immediate initialization hook.
  if type(opt.init) == "function" then
    opt.init()
  end

  -- Queue configuration hook for execution after plugin loading.
  if type(opt.config) == "function" then
    table.insert(state.configs, { name = name, priority = priority, config = opt.config })
  end
end

--- Import plugin specs from module paths, similar to lazy.nvim's `import`.
---
--- Each Lua file (or directory with an `init.lua`) under the given module path
--- is `require()`d; any non-nil return value is passed to `add()`.
---
--- Example: `import("plugins")` will load every `.lua` file in
--- `lua/plugins/` as `plugins.<filename>`.
---@param paths string | string[] Module path or list of module paths.
function M.import(paths)
  if type(paths) == "string" then
    paths = { paths }
  end

  if type(paths) ~= "table" then
    return
  end

  local config_dir = vim.fn.stdpath "config"

  for _, path in ipairs(paths) do
    if type(path) ~= "string" then
      goto continue
    end

    local pattern = config_dir .. "/lua/" .. path:gsub("%.", "/")
    local entries = vim.fn.glob(pattern .. "/*", false, true)

    for _, entry in ipairs(entries) do
      local name = vim.fn.fnamemodify(entry, ":t")
      local module_name

      if vim.fn.isdirectory(entry) == 1 then
        module_name = path .. "." .. name
      elseif entry:match "%.lua$" then
        name = vim.fn.fnamemodify(entry, ":t:r")
        module_name = path .. "." .. name
      end

      if module_name then
        local ok, spec = pcall(require, module_name)
        if ok and spec ~= nil then
          M.add(spec)
        end
      end
    end

    ::continue::
  end
end

return M
