local M = {}

--- Build hooks keyed by plugin name.
--- Each entry stores the original `build` value (function or string).
---@type table<string, {build: function|string}>
M.build_info = {}

--- Resolved plugin specs queued for `vim.pack.add()`.
---@type { src: string, name?: string, version?: string, data?: any }[]
M.plugins = {}

--- Configuration callbacks queued for execution after plugin loading.
--- Sorted by priority (higher first) inside the VimEnter autocmd.
--- The `name` field is used to skip configs for plugins that failed to load.
---@type { name: string, priority: number, config: function }[]
M.configs = {}

--- Plugin names whose build hooks should run after the next `vim.pack.add()`.
--- Populated by the `PackChanged` install event and cleared by VimEnter.
---@type table<string, boolean>
M.pending_builds = {}

return M
