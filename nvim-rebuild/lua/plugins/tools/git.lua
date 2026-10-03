-- path: ~/.config/nvim-rebuild/lua/plugins/tools/git.lua
-- description: Git buffer signs and hunk operations.
-- patched: Include the reviewed plugin specification in public exports.
-- date: 2026-10-03

return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    signs = {
      add          = { text = "▎" },
      change       = { text = "▎" },
      delete       = { text = "" },
      topdelete    = { text = "" },
      changedelete = { text = "▎" },
      untracked    = { text = "▎" },
    },

    signs_staged = {
      add          = { text = "▎" },
      change       = { text = "▎" },
      delete       = { text = "" },
      topdelete    = { text = "" },
      changedelete = { text = "▎" },
    },
    signs_staged_enable = true,

    current_line_blame = false,
    current_line_blame_opts = {
      virt_text = true,
      virt_text_pos = "eol",
      delay = 300,
      ignore_whitespace = true,
    },
    current_line_blame_formatter = "  <author>, <author_time:%R> · <summary>",

    sign_priority = 6,
    watch_gitdir = { follow_files = true },
    auto_attach = true,
    attach_to_untracked = false,
    max_file_length = 40000,

    preview_config = {
      border = "rounded",
      style = "minimal",
      relative = "cursor",
      row = 0,
      col = 1,
    },

    on_attach = function(bufnr)
      local gs = require("gitsigns")

      local function map(mode, l, r, desc)
        vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
      end

      map("n", "]h", function()
        if vim.wo.diff then
          vim.cmd.normal({ "]c", bang = true })
        else
          gs.nav_hunk("next")
        end
      end, "Next git hunk")

      map("n", "[h", function()
        if vim.wo.diff then
          vim.cmd.normal({ "[c", bang = true })
        else
          gs.nav_hunk("prev")
        end
      end, "Prev git hunk")

      map("n", "]H", function() gs.nav_hunk("last") end, "Last git hunk")
      map("n", "[H", function() gs.nav_hunk("first") end, "First git hunk")

      map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
      map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")

      map("v", "<leader>hs", function()
        gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, "Stage selected lines")

      map("v", "<leader>hr", function()
        gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, "Reset selected lines")

      map("n", "<leader>hS", gs.stage_buffer, "Stage entire buffer")
      map("n", "<leader>hR", gs.reset_buffer, "Reset entire buffer")
      map("n", "<leader>hu", gs.undo_stage_hunk, "Undo last stage")

      map("n", "<leader>hp", gs.preview_hunk, "Preview hunk (popup)")
      map("n", "<leader>hi", gs.preview_hunk_inline, "Preview hunk (inline)")
      map("n", "<leader>hd", gs.diffthis, "Diff against index")
      map("n", "<leader>hD", function() gs.diffthis("~") end, "Diff against last commit")

      map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line (full)")
      map("n", "<leader>hB", gs.blame, "Blame buffer")

      map("n", "<leader>htb", gs.toggle_current_line_blame, "Toggle inline blame")
      map("n", "<leader>htd", gs.toggle_deleted, "Toggle show deleted")
      map("n", "<leader>htw", gs.toggle_word_diff, "Toggle word diff")

      map({ "o", "x" }, "ih", "<cmd>Gitsigns select_hunk<CR>", "inner hunk")
    end,
  },
}
