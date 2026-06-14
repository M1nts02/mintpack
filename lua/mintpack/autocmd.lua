local utils = require "mintpack.utils"
local state = require "mintpack.state"
local plugins_build = utils.plugins_build
local build_info = state.build_info

-- Queue/defer build hooks for plugins installed by vim.pack.
-- The actual build is run after VimEnter, once the plugin has been loaded.
vim.api.nvim_create_autocmd("PackChanged", {
  group = vim.api.nvim_create_augroup("MintpackChanged", { clear = true }),
  callback = function(args)
    local data = args.data or {}
    local kind = data.kind
    local name = data.spec and data.spec.name

    if kind == "install" and name and build_info[name] then
      -- Defer install-time builds until the plugin is loaded at VimEnter.
      state.pending_builds[name] = true
      return
    end

    if kind == "update" and name and build_info[name] then
      -- Make sure the plugin is loaded before running its build hook.
      if not data.active then
        vim.cmd.packadd(name)
      end
      plugins_build({ name })
    end
  end,
})

-- After Neovim has finished startup, install/load all queued plugins and run
-- their configuration hooks.
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("MintpackLoad", { clear = true }),
  once = true,
  desc = "Load plugin configs",
  callback = function()
    -- Install missing plugins and load all queued plugins via vim.pack.
    -- `confirm = false` avoids prompting during startup.
    -- Wrap in pcall so a single failed download doesn't abort startup.
    local ok, err = pcall(vim.pack.add, state.plugins, { confirm = false })
    if not ok then
      vim.notify("mintpack: plugin install/load failed:\n" .. tostring(err), vim.log.levels.ERROR)
    end

    -- Run build hooks for plugins that were newly installed during the above
    -- call. At this point they have been loaded, so commands like `:TSUpdate`
    -- are available. Already-installed plugins are not rebuilt on every startup.
    local pending = {}
    for name, _ in pairs(state.pending_builds) do
      table.insert(pending, name)
    end
    state.pending_builds = {}
    if #pending > 0 then
      plugins_build(pending)
    end

    -- Sort configuration callbacks by priority (descending).
    table.sort(state.configs, function(a, b)
      return a.priority > b.priority
    end)

    -- Only run config for plugins that were actually loaded. Plugins that
    -- failed to install or were skipped by vim.pack are ignored.
    local active = {}
    for _, plug in ipairs(vim.pack.get() or {}) do
      if plug.active and plug.spec and plug.spec.name then
        active[plug.spec.name] = true
      end
    end

    local skipped = {}
    for _, v in ipairs(state.configs) do
      if active[v.name] then
        v.config()
      else
        table.insert(skipped, v.name)
      end
    end

    if #skipped > 0 then
      vim.notify(
        "mintpack: skipped config for " .. #skipped .. " plugin(s): " .. table.concat(skipped, ", "),
        vim.log.levels.WARN
      )
    end
  end,
})
