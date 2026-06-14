local M = {}

local utils = require "mintpack.utils"
local state = require "mintpack.state"
local plugins_build = utils.plugins_build
local build_info = state.build_info

-- `:PackBuild [plugin ...]`
-- Run build hooks for the named plugins, or for all plugins with build hooks
-- if no names are given.
vim.api.nvim_create_user_command(
  "PackBuild",
  function (opts)
    plugins_build(opts.fargs)
  end,
  {
    desc = "Build plugins",
    nargs = "*",
    complete = function (arglead, cmdline, cursorpos)
      local plist = {}
      for name, _ in pairs(build_info) do
        table.insert(plist, name)
      end
      return utils.cmdline_complete(arglead, cmdline, cursorpos, plist)
    end
  }
)

-- `:PackClean`
-- Delete plugins that are installed on disk but were not added this session.
vim.api.nvim_create_user_command("PackClean", function ()
  local all_packs = vim.pack.get(nil, { info = false })
  local inactive = {}
  for _, pack in ipairs(all_packs) do
    if pack.active == false then
      table.insert(inactive, pack.spec.name)
    end
  end
  if #inactive == 0 then
    vim.notify("No inactive plugins to uninstall", vim.log.levels.INFO)
    return
  end
  vim.pack.del(inactive)
end, { desc = "Uninstall all inactive plugins" }
)

-- `:PackUpdate [plugin ...]`
-- Update all plugins, or only the named plugins.
vim.api.nvim_create_user_command("PackUpdate", function (opts)
  local fargs = opts.fargs
  if #fargs == 0 then
    vim.pack.update()
  else
    vim.pack.update(fargs)
  end
end, { desc = "Update plugins", nargs = "*", complete = utils.plugins_complete }
)

-- `:PackStatus [plugin ...]`
-- Show the update status of all plugins (offline, no download).
vim.api.nvim_create_user_command("PackStatus", function (opts)
  local fargs = opts.fargs
  if #fargs == 0 then
    vim.pack.update(nil, { offline = true })
  else
    vim.pack.update(fargs, { offline = true })
  end
end, { desc = "Show plugins status", nargs = "*", complete = utils.plugins_complete }
)

return M
