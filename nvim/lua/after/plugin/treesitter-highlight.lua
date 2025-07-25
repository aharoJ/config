-- path: nvim/lua/after/plugin/treesitter-highlight.lua

-- 1. Require the highlight module
local highlight_mod = require("nvim-treesitter.highlight")

-- 2. Save the original attach function (in case you ever want to call or fallback to it)
local old_attach = highlight_mod.attach

-- 3. Define our new attach function
highlight_mod.attach = function(bufnr, lang)
  ----------------------------------------------------------------------------
  -- The snippet from Reddit starts here:
  ----------------------------------------------------------------------------

  local function begin_ts_highlight(bufnr, lang, owner)
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    vim.treesitter.start(bufnr, lang)
  end

  local vim_enter = true

  local function new_attach(bufnr, lang)
    if vim_enter then
      vim.treesitter.start(bufnr, lang)
      vim_enter = false
      return
    end

    local timer = vim.loop.new_timer()
    local has_start = false

    local function timout(opts)
      local force = opts.force
      if not vim.api.nvim_buf_is_valid(bufnr) then
        if timer:is_active() then
          timer:close()
        end
        return
      end
      if (not force) and has_start then
        return
      end
      if timer:is_active() then
        timer:close()
        has_start = true
        begin_ts_highlight(bufnr, lang, "highlighter")
      end
    end

    -- Attempt after 100ms
    vim.defer_fn(function()
      timout { force = false }
    end, 100)

    -- Force after 1s in case user doesn't move
    vim.defer_fn(function()
      timout { force = true }
    end, 1000)

    local col = vim.fn.screencol()
    local row = vim.fn.screenrow()

    -- Re-check every 2ms until the user moves
    timer:start(5, 2, function()
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(bufnr) then
          if timer:is_active() then
            timer:close()
          end
          return
        end
        if has_start then
          return
        end

        local new_col = vim.fn.screencol()
        local new_row = vim.fn.screenrow()
        if new_row ~= row and new_col ~= col then
          if timer:is_active() then
            timer:close()
            has_start = true
            begin_ts_highlight(bufnr, lang, "highlighter")
          end
        end
      end)
    end)
  end

  -- Actually call our new logic:
  new_attach(bufnr, lang)

  ----------------------------------------------------------------------------
  -- End of snippet
  ----------------------------------------------------------------------------

  -- Uncomment this line if you also want to run the original attach code
  -- after your timer-based approach finishes (for example):
  --
  -- old_attach(bufnr, lang)
end
