local M = {}

local defaults = {
  -- core
  auto = true,            -- enable when LSP attaches
  only_current_line = false,
  enabled_filetypes = nil, -- nil == all
  highlight = "Comment",
  toggle_buf_key = "<leader>th",
  toggle_all_key = "<leader>tH",
  refresh_key = "<leader>tr", -- NEW: refresh key
  cmds = true,

  -- extras
  colorize = true,
  right_align_types = true,
  ghost_signature = true,
  viewport_hints = false,

  -- NEW: Enhanced features
  debounce_ms = 150, -- Debounce for ghost signature and viewport
  max_hint_length = 40, -- Truncate long hints
  type_prefix = ": ", -- Prefix for type hints
  param_prefix = "← ", -- Prefix for parameter hints
  chain_prefix = "→ ", -- Prefix for chaining hints
  ghost_position = "above", -- [above|below] cursor line
}

--------------------------------------------------------------------
-- Utility wrappers and state
local function enabled(buf)
  return vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
end

local function set(buf, on)
  vim.lsp.inlay_hint.enable(on, { bufnr = buf })
end

local ns_main = vim.api.nvim_create_namespace("InlayMain")
local ns_ghost = vim.api.nvim_create_namespace("InlayGhost")
local ghost_timer = nil -- NEW: Debounce timer
local viewport_timer = nil

-- NEW: Truncate long hints
local function truncate_hint(label, max_len)
  if type(label) == "string" and #label > max_len then
    return label:sub(1, max_len - 3) .. "..."
  end
  return label
end

--------------------------------------------------------------------
-- Public togglers -------------------------------------------------
function M.toggle(buf)
  buf = buf or 0
  set(buf, not enabled(buf))
end

function M.toggle_all()
  set(0, not enabled())
end

-- NEW: Refresh hints command
function M.refresh(buf)
  buf = buf or 0
  if enabled(buf) then
    set(buf, false)
    vim.defer_fn(function()
      set(buf, true)
    end, 50)
  end
end

--------------------------------------------------------------------
-- Extra #1 & #2: custom handler (colour + right-align) ------------
local function override_handler(cfg)
  local orig = vim.lsp.handlers["textDocument/inlayHint"]

  -- Custom highlight groups
  if cfg.colorize then
    vim.api.nvim_set_hl(0, "InlayParam", { link = cfg.highlight })
    vim.api.nvim_set_hl(0, "InlayType", { fg = "#7fb971", italic = true })
    vim.api.nvim_set_hl(0, "InlayChain", { fg = "#71b7cf" })
  end

  vim.lsp.handlers["textDocument/inlayHint"] = function(err, res, ctx, conf)
    if not res then
      return orig(err, res, ctx, conf)
    end

    for _, h in ipairs(res) do
      -- NEW: Apply prefixes and truncation
      local prefix = ""
      if h.kind == 2 then
        prefix = cfg.param_prefix
      elseif h.kind == 3 then
        prefix = cfg.type_prefix
      elseif h.kind == 4 then
        prefix = cfg.chain_prefix
      end

      if type(h.label) == "string" then
        h.label = prefix .. h.label
        h.label = truncate_hint(h.label, cfg.max_hint_length)
      end

      -- Colour-coding
      if cfg.colorize then
        local hl = (h.kind == 2 and "InlayParam")
            or (h.kind == 3 and "InlayType")
            or (h.kind == 4 and "InlayChain")
        if hl then
          h.label = { { h.label, hl } }
        end
      end

      -- Right-align type hints
      if cfg.right_align_types and h.kind == 3 then
        h.rightAlign = true
      end
    end

    -- Render via original handler
    local ret = orig(err, res, ctx, conf)

    -- Post-process right-aligned extmarks
    if cfg.right_align_types and res then
      vim.schedule(function()
        local buf = ctx.bufnr
        vim.api.nvim_buf_clear_namespace(buf, ns_main, 0, -1)

        for _, h in ipairs(res) do
          if h.rightAlign then
            local lnum = h.position.line
            vim.api.nvim_buf_set_extmark(buf, ns_main, lnum, 0, {
              virt_text = h.label,
              virt_text_pos = "right_align",
              hl_mode = "combine",
            })
          end
        end
      end)
    end
    return ret
  end
end

--------------------------------------------------------------------
-- Extra #3: ghost signature (virtual-line above/below cursor) -----
local function setup_ghost_sig(cfg)
  if not cfg.ghost_signature then
    return
  end

  local function refresh()
    local buf = 0
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    vim.api.nvim_buf_clear_namespace(buf, ns_ghost, 0, -1)

    local extmarks = vim.api.nvim_buf_get_extmarks(buf, ns_main, { row, 0 }, { row, -1 }, { details = true })

    if #extmarks > 0 then
      local label = extmarks[1][4].virt_text[1][1]:gsub("^%s+", "")
      local virt_config = {
        virt_lines = { { { "↳ " .. label, cfg.highlight } } },
        virt_lines_above = (cfg.ghost_position == "above"),
      }
      vim.api.nvim_buf_set_extmark(buf, ns_ghost, row, 0, virt_config)
    end
  end

  -- NEW: Debounced refresh
  local function debounced_refresh()
    if ghost_timer and ghost_timer:is_active() then
      ghost_timer:close()
    end
    ghost_timer = vim.defer_fn(refresh, cfg.debounce_ms)
  end

  vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI", "InsertLeave" }, {
    group = vim.api.nvim_create_augroup("InlayGhost", { clear = true }),
    callback = debounced_refresh,
  })
end

--------------------------------------------------------------------
-- Extra #4: viewport-only hint requests (perf) --------------------
local function setup_viewport(cfg)
  if not cfg.viewport_hints then
    return
  end

  local function request()
    local buf = 0
    local top = vim.fn.line("w0") - 1
    local bot = vim.fn.line("w$") - 1
    vim.lsp.buf_request(buf, "textDocument/inlayHint", {
      textDocument = vim.lsp.util.make_text_document_params(buf),
      range = {
        start = { line = top, character = 0 },
        ["end"] = { line = bot, character = 0 },
      },
    }, vim.lsp.handlers["textDocument/inlayHint"])
  end

  -- NEW: Debounced viewport update
  local function debounced_request()
    if viewport_timer and viewport_timer:is_active() then
      viewport_timer:close()
    end
    viewport_timer = vim.defer_fn(request, cfg.debounce_ms)
  end

  vim.api.nvim_create_autocmd({ "WinScrolled", "BufEnter", "CursorMoved" }, {
    group = vim.api.nvim_create_augroup("InlayViewport", { clear = true }),
    callback = debounced_request,
  })
end

--------------------------------------------------------------------
-- Auto-enable on LspAttach + setup --------------------------------
function M.setup(opts)
  local cfg = vim.tbl_deep_extend("force", defaults, opts or {})

  -- Base highlight
  if type(cfg.highlight) == "string" then
    vim.api.nvim_set_hl(0, "LspInlayHint", { link = cfg.highlight })
  else
    vim.api.nvim_set_hl(0, "LspInlayHint", cfg.highlight)
  end

  -- Custom handler
  override_handler(cfg)

  -- Ghost line & viewport features
  setup_ghost_sig(cfg)
  setup_viewport(cfg)

  -- LspAttach: auto-enable
  if cfg.auto then
    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        local buf = args.buf
        if not client.server_capabilities.inlayHintProvider then
          return
        end

        local ok_ft = not cfg.enabled_filetypes or vim.tbl_contains(cfg.enabled_filetypes, vim.bo[buf].filetype)
        if ok_ft then
          set(buf, true)
        end
      end,
    })
  end

  -- Current-line only mode
  if cfg.only_current_line then
    local grp = vim.api.nvim_create_augroup("InlayCurrentLine", { clear = true })
    vim.api.nvim_create_autocmd({ "CursorMoved", "InsertLeave" }, {
      group = grp,
      callback = function()
        local buf = 0
        set(buf, false)
        set(buf, true)
      end,
    })
  end

  -- Keymaps
  vim.keymap.set("n", cfg.toggle_buf_key, M.toggle, { desc = "[LSP] Toggle inlay hints (buf)" })
  vim.keymap.set("n", cfg.toggle_all_key, M.toggle_all, { desc = "[LSP] Toggle inlay hints (all)" })
  vim.keymap.set("n", cfg.refresh_key, M.refresh, { desc = "[LSP] Refresh inlay hints" }) -- NEW

  -- Commands
  if cfg.cmds then
    vim.api.nvim_create_user_command(
      "InlayHintsToggle",
      M.toggle,
      { desc = "Toggle inlay hints in current buffer" }
    )
    vim.api.nvim_create_user_command(
      "InlayHintsToggleAll",
      M.toggle_all,
      { desc = "Toggle inlay hints in all buffers" }
    )
    vim.api.nvim_create_user_command( -- NEW
      "InlayHintsRefresh",
      M.refresh,
      { desc = "Refresh inlay hints in current buffer" }
    )
  end
end

return M

