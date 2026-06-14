local M = {}

---@class mintpack.Config
---@field url string Base URL prepended to short plugin names (e.g. `"user/repo"`). Must end with `/`.
M.defaults = {
  url = "https://github.com/",
}

local options = vim.deepcopy(M.defaults)

--- Apply user options on top of the defaults.
---@param opts? mintpack.Config
function M.setup(opts)
  options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

--- Return the current configuration.
---@return mintpack.Config
function M.get()
  return options
end

return M
