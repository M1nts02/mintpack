# mintpack

A lightweight Neovim plugin manager built on top of the built-in [`vim.pack`](https://neovim.io/doc/user/pack.html) API.

`mintpack` keeps the simplicity of `vim.pack` while adding a declarative spec format, lazy-like `config` / `init` / `build` hooks, dependency handling, and convenient user commands.

## Features

- **Tiny and transparent** — thin wrapper around `vim.pack`, no external dependencies.
- **Declarative specs** — register plugins with a clean table-based API.
- **Auto-install on startup** — plugins are installed and loaded after `VimEnter`.
- **Config hooks with priority** — run setup code after plugins are loaded, ordered by priority.
- **Build hooks** — run shell commands, Ex commands, or Lua functions after install/update.
- **Dependency support** — register dependencies alongside a plugin.
- **Import from module paths** — split your plugin list across multiple files under `lua/`.
- **User commands** — `:PackBuild`, `:PackClean`, `:PackUpdate`, `:PackStatus`.

## Requirements

- Neovim **nightly 0.11+** or **0.12+** with the built-in `vim.pack` API.

## Installation

Add `mintpack` as a regular plugin. For example, with `vim.pack` directly in your `init.lua`:

```lua
vim.pack.add({
  src = "https://github.com/m1nts02/mintpack",
})
require("mintpack").setup()
```

## Quick Start

```lua
local mintpack = require("mintpack")
local add = mintpack.add

mintpack.setup()

-- Short plugin names are expanded using the configured base URL.
add("nvim-lua/plenary.nvim")

-- Full table spec.
add({
  "nvim-telescope/telescope.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("telescope").setup()
  end,
})

-- Plugins are installed and configured automatically after startup.
```

## Configuration

`mintpack.setup()` accepts an optional configuration table.

```lua
require("mintpack").setup({
  -- Base URL for short plugin names. Must end with "/".
  url = "https://github.com/",
})
```

### Options

| Option | Type     | Default                  | Description                          |
| ------ | -------- | ------------------------ | ------------------------------------ |
| `url`  | `string` | `"https://github.com/"` | Prefix used for short plugin names. |

## API

### `mintpack.setup(opts?)`

Initialize mintpack. Registers user commands and the startup autocmd.

### `mintpack.add(spec)`

Register one or more plugin specs. Accepted forms:

```lua
add("user/repo")                              -- short string
add({ "user/repo", config = function() end }) -- single table spec
add({ { "user/a" }, { "user/b" } })           -- list of specs
```

### `mintpack.import(paths)`

Load plugin specs from Lua modules under `lua/<path>/`.

```lua
mintpack.import("plugins")        -- loads lua/plugins/*.lua
mintpack.import({ "plugins", "colors" })
```

Each file (or directory with an `init.lua`) is `require()`d and the returned value is passed to `add()`.

## Plugin Spec

| Field          | Type                  | Description                                                             |
| -------------- | --------------------- | ----------------------------------------------------------------------- |
| `[1]` / `src`  | `string`              | Plugin source. Short names are expanded with `config.url`.              |
| `name`         | `string?`             | Override the plugin directory name.                                     |
| `version`      | `string?`             | Branch, tag, commit, or version range.                                  |
| `enabled`      | `boolean?`            | Set to `false` to skip this plugin.                                     |
| `priority`     | `number?`             | Config execution priority. Higher runs first. Default: `50`.            |
| `init`         | `function?`           | Called immediately when the spec is registered.                         |
| `config`       | `function?`           | Called after all plugins are installed and loaded.                      |
| `build`        | `function \| string?` | Build hook. Runs only when a plugin is newly installed or updated.     |
| `dependencies` | `table?`              | List of plugin specs to register before this plugin.                    |
| `data`         | `any?`                | Arbitrary data forwarded to `vim.pack.add()`.                           |

### `build` formats

```lua
-- Lua function (sync, receives { name, path }).
build = function(ctx)
  print("Building " .. ctx.name .. " at " .. ctx.path)
end

-- Ex command (the leading ":" is stripped).
build = ":TSUpdate"

-- Shell command run asynchronously via jobstart.
build = "!make"

-- Shell command run synchronously in the plugin directory.
build = "make"
```

## Commands

| Command                | Description                                                        |
| ---------------------- | ------------------------------------------------------------------ |
| `:PackBuild [names...]` | Run build hooks for the named plugins, or all if no names given.  |
| `:PackClean`           | Delete plugins managed by `vim.pack` that are not active this session. |
| `:PackUpdate [names...]` | Update all or selected plugins.                                   |
| `:PackStatus [names...]` | Show update status without downloading changes (offline).         |

## Examples

### Basic plugin list

```lua
local mintpack = require("mintpack")
local add = mintpack.add

mintpack.setup()

add("nvim-lua/plenary.nvim")

add({
  "saghen/blink.cmp",
  version = "v1.10.2",
  dependencies = {
    "rafamadriz/friendly-snippets",
    { "L3MON4D3/LuaSnip", build = "make install_jsregexp" },
  },
  config = function()
    require("blink-cmp").setup()
  end,
})
```

### Split across files

```lua
-- init.lua
require("mintpack").setup()
require("mintpack").import("plugins")
```

```lua
-- lua/plugins/colorscheme.lua
return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  config = function()
    require("catppuccin").setup({
      term_colors = true,
    })
    vim.cmd.colorscheme("catppuccin-mocha")
  end,
}
```

```lua
-- lua/plugins/avante.lua
return {
  "yetone/avante.nvim",
  build = "make",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-mini/mini.nvim",
    {
      "HakonHarnes/img-clip.nvim",
      config = function()
        require("img-clip").setup({
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            use_absolute_path = true,
          },
        })
      end,
    },
    {
      "MeanderingProgrammer/render-markdown.nvim",
      config = function()
        require("render-markdown").setup()
      end,
    },
  },
  config = function()
    require("avante").setup()
  end,
}
```

```lua
-- lua/plugins/treesitter.lua
return {
  "neovim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  dependencies = { "neovim-treesitter/treesitter-parser-registry" },
  config = function()
    require("nvim-treesitter").setup({})
  end,
}
```

### Disabled plugin

```lua
add({
  "some/plugin",
  enabled = false,
})
```

### Custom base URL

```lua
require("mintpack").setup({
  url = "https://git.sr.ht/",
})

add("~user/neovim-plugin") -- resolves to https://git.sr.ht/~user/neovim-plugin
```

## How It Works

1. `mintpack.add()` collects plugin specs into an internal list.
2. `init` callbacks run immediately as specs are registered.
3. After `VimEnter`, `vim.pack.add()` installs/loads all queued plugins.
   - If a download fails, the error is captured and shown via `vim.notify` without aborting startup.
4. `build` hooks run only for plugins that were newly installed or updated in this session.
5. `config` callbacks run in priority order (highest first), but only for plugins that were successfully loaded.

`mintpack` listens to the `PackChanged` event to queue/run `build` hooks automatically when a plugin is installed or updated via `vim.pack`.

## License

MIT
