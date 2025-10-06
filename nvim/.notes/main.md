> ~/.conifg/nvim

```lua
echo stdpath("config")
```

> /Users/aharoj/.local/share/nvim
> neovim remember and persist data onto this path for sessions + many things

```lua
echo stdpath("data")
```

```lua
options
```

```lua
nohlsearch
```

> A special interface vim.opt exists for conveniently interacting with list and map-style options from Lua: It allows accessing them as Lua tables and offers object-oriented method for adding and removing entries.

```lua
h vim.opt
```

> find & repalce

```lua
:%s/vim/nvim
```

> only way to invioke `vimscript` in lua

```lua
vim.fn.
```

> it concatinates the left string with the right string

```lua
..
```

> auto-indents current line

```lua
==
```

```lua
neovim only executes the init.lua nothing else!
```

> inspect the current nodes

```lua
InspectTree

- https://github.com/nvim-treesitter/nvim-treesitter/blob/master/queries/lua/highlights.scm
```

> enable or disable snippets

```lua
TSBufEnable highlight
```

> open up the schema file (.scm)

```lua
TSEditQuery highlight
```

> now we can see the "@function.outer"

```lua
TSEditQuery textobjects
```

```lua
lua vim.print(vim.lsp)
OR
=vim.lsp
```

```lua
h vim.lsp.start
```

> get current working directory

```lua
echo getcwd()
```

> lsp outta the box to get working

```lua
=vim.lsp.buf
```

> a dependecy loads before the actual plugin::wtf

```lua
{
    "mason-org/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim", },
    config = function ()
    end,
},
```

```lua
{
    "mason-org/mason.nvim",
    config = function()
        require("mason").setup()
    end,
},
> same as
{
    -- opts={},
}
```

> check capabilities or to debugg issue

```lua
lua vim.print(vim.lsp.protocol.make_client_capabilities())
```

> create your own snippets

```lua
lua vim.snippet.expand()
```

```lua

```

```lua

```

```lua

```

```lua

```

```lua

```

```lua

```

```lua

```

```lua

```

```lua

```

```lua

```

```lua

```

```lua

```

# lua vs vimscript
