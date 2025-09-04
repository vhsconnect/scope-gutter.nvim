## What is it

scope-gutter is a Neovim plugin to help delineate the most inner [scope(s)](https://en.wikipedia.org/wiki/Scope) a cursor occupies. It aims to give the user scope information at a glance and not be noisy about it.

## Requirements

Treesitter to be installed

## Installation

Using [packer](https://github.com/wbthomason/packer.nvim) in lua

```lua
use {"vhsconnect/scope-gutter.nvim", config = function()
  require("scope-gutter").setup({
	enabled = true,
  })
end}
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim) in lua

```lua
{
  {'vhsconnect/scope-gutter.nvim', opts = { enabled = true}}
}
```

Using lua

```lua
  require('scope-gutter').setup {} 
```

## Configuration
```lua
  local config = { 
	enabled = true,
	min_window_height = 10,
	clobber_priority = 10,
	gutter_char_open = "{",
	gutter_char_close = "}",
  }
```



## Development

Append the path to the plugin's `init.lua` to your `package.path`

```lua
`package.path = package.path .. ';/path/to/scope-gutter.nvim/lua/scope-gutter/init.lua'`
```


### Commands

- GutterContextEnable
- GutterContextDisable
- GutterContextToggle
