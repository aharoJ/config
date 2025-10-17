-- path: nvim/lua/core/generate_fences.lua
local M = {}

local function normalize_lang(lang)
  lang = (lang or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local map = {
    js = "javascript",
    ts = "typescript",
    py = "python",
    sh = "bash",
    yml = "yaml",
    md = "markdown",
    tex = "latex",
    rs = "rust",
    csharp = "csharp",
  }
  return map[lang] or lang
end

local function build_blocks(lang, count, opts)
  lang = normalize_lang(lang)
  count = tonumber(count) or 1
  if count < 1 then count = 1 end
  if count > 200 then count = 200 end

  local lines = {}
  local start = "```" .. lang
  local finish = "```"
  local placeholder = opts and opts.placeholder or nil
  local between_blank = opts and opts.between_blank == true

  for i = 1, count do
    table.insert(lines, start)
    if placeholder and #placeholder > 0 then
      table.insert(lines, placeholder)
    end
    table.insert(lines, finish)
    if between_blank and i < count then
      table.insert(lines, "")
    end
  end

  return table.concat(lines, "\n")
end

local function insert_below_cursor(text)
  local buf = 0
  local pos = vim.api.nvim_win_get_cursor(0) -- {row, col}, 1-indexed
  local row = pos[1]
  local lines = vim.split(text, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(buf, row, row, true, lines)
end

function M.generate(lang, count, opts)
  if not lang or lang == "" then
    lang = vim.bo.filetype or ""
  end
  local text = build_blocks(lang, count, opts)
  insert_below_cursor(text)
end

function M.prompt(opts)
  local detected_lang = vim.bo.filetype or ""
  local default_count = tostring((opts and opts.default_count) or 5)

    -- language input
  vim.ui.input({
    prompt = string.format("Language tag (detected: %s): ", detected_lang),
    default = "", -- force empty so typing overwrites immediately
  }, function(lang)
    -- if user pressed enter without typing, use detected_lang
    lang = (lang and #lang > 0) and lang or detected_lang

    -- count input
    vim.ui.input({
      prompt = string.format("How many code fences? (default: %s): ", default_count),
      default = "", -- empty so user typing replaces instantly
    }, function(n)
      if n == nil then return end
      local num = tonumber((n ~= "" and n) or default_count)
      if not num then
        vim.notify("Not a number: " .. n, vim.log.levels.ERROR)
        return
      end
      M.generate(lang, num, opts)
    end)
  end)
end

-- Wrap current visual selection in a single fence
function M.wrap_visual(lang)
  lang = normalize_lang(lang and #lang > 0 and lang or vim.bo.filetype or "")
  local start = "```" .. lang
  local finish = "```"

  -- Visual marks
  local srow = vim.api.nvim_buf_get_mark(0, "<")[1] - 1 -- 0-indexed
  local erow = vim.api.nvim_buf_get_mark(0, ">")[1]     -- insert AFTER end line

  -- Insert closing fence first (so indices don’t shift the start line)
  vim.api.nvim_buf_set_lines(0, erow, erow, true, { finish })
  vim.api.nvim_buf_set_lines(0, srow, srow, true, { start })
end

function M.setup(opts)
  -- :GenerateFences [lang] [count]
  vim.api.nvim_create_user_command("GenerateFences", function(cmdargs)
    local lang = cmdargs.fargs[1]
    local num  = tonumber(cmdargs.fargs[2] or "")
    if lang and num then
      M.generate(lang, num, opts)
    else
      M.prompt(opts)
    end
  end, {
    nargs = "*",
    complete = function()
      return {
        "", "text", "bash", "zsh", "lua", "javascript", "typescript", "tsx", "jsx",
        "json", "yaml", "toml", "python", "java", "kotlin", "c", "cpp", "csharp",
        "go", "rust", "sql", "html", "css", "scss", "md", "latex",
      }
    end,
    desc = "Insert repeated Markdown code fences with a language tag",
  })

  -- :WrapFence [lang?]  (defaults to current buffer filetype)
  vim.api.nvim_create_user_command("WrapFence", function(cmdargs)
    local lang = cmdargs.args
    M.wrap_visual(lang)
  end, { nargs = "?", range = true, desc = "Wrap visual selection in a code fence" })

  -- mappings (toggle off with opts.map = false)
  if not (opts and opts.map == false) then
    -- vim.keymap.set("n", "<leader>gf", function() M.prompt(opts) end, { desc = "Generate code fences" })
    -- vim.keymap.set("v", "<leader>gw", function() M.wrap_visual("") end, { desc = "Wrap selection in fence" })
  end
end

return M
