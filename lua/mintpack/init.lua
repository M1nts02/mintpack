local M = {}

local add = require "mintpack.add"
local config = require "mintpack.config"

-- Public API
M.add = add.add
M.import = add.import

--- Initialize mintpack.
--- Applies configuration, registers user commands, and sets up the VimEnter
--- autocmd that installs, loads, and configures queued plugins.
---@param opts? mintpack.Config
function M.setup(opts)
  config.setup(opts)
  if config.get().commands then
    require "mintpack.command"
  end
  require "mintpack.autocmd"
end

return M

