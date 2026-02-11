-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  telescope-favorites.lua — ONLY the favorites & new finds      ║
-- ║                                                                ║
-- ║  HOW TO USE: copy one `find_files_opts` block into your        ║
-- ║  telescope.lua, comment/delete the rest.                       ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ┌──────────────────────────────────────────────────────────────────┐
-- │  ⭐ STARRED FAVORITES                                           │
-- └──────────────────────────────────────────────────────────────────┘

-- ⭐ #8 — Vertical Mirrored
-- ┌────────────────────────────┐
-- │          Prompt            │
-- ├────────────────────────────┤
-- │          Results           │
-- ├────────────────────────────┤
-- │          Preview           │
-- └────────────────────────────┘
local find_files_opts = {
    layout_strategy = "vertical",
    layout_config = {
        width = 0.6,
        height = 0.9,
        preview_height = 0.45,
        prompt_position = "top",
        mirror = true,
    },
    previewer = true,
    border = true,
    winblend = 10,
    prompt_prefix = "  ",
    selection_caret = " ▸ ",
    path_display = { shorten = { len = 1, exclude = { -1 } } },
    sorting_strategy = "ascending",
}

-- ⭐ #14 — Ivy Minimal (no preview, docked bottom)
-- ════════════════════════════════════════════
-- │ Prompt                                   │
-- ├──────────────────────────────────────────┤
-- │ Results                                  │
-- ════════════════════════════════════════════
local find_files_opts = function()
    return require("telescope.themes").get_ivy({
        previewer = false,
        layout_config = {
            height = 0.3,
        },
        winblend = 10,
        prompt_prefix = "  ",
        selection_caret = " ▸ ",
        path_display = { shorten = { len = 1, exclude = { -1 } } },
        sorting_strategy = "ascending",
    })
end

-- ⭐ #18 — Ultra Minimal Center (no preview, no borders) ← YOUR CURRENT ONE
--         ┌──────────────────────┐
--         │       Prompt         │
--         ├──────────────────────┤
--         │       Results        │
--         └──────────────────────┘
local find_files_opts = {
    layout_strategy = "center",
    layout_config = {
        width = 0.4,
        height = 0.35,
    },
    previewer = false,
    border = false,
    winblend = 10,
    prompt_prefix = "  ",
    selection_caret = " ▸ ",
    path_display = { shorten = { len = 1, exclude = { -1 } } },
    sorting_strategy = "ascending",
}

-- ┌──────────────────────────────────────────────────────────────────┐
-- │  🔥 NEW FINDS (your notes from the doc)                        │
-- └──────────────────────────────────────────────────────────────────┘

-- #9 — Full-Screen Vertical ("pretty dope for debugging potentially")
local find_files_opts = {
    layout_strategy = "vertical",
    layout_config = {
        width = 0.99,
        height = 0.99,
        preview_height = 0.6,
        prompt_position = "top",
        mirror = true,
    },
    previewer = true,
    border = true,
    winblend = 10,
    prompt_prefix = "  ",
    selection_caret = " ▸ ",
    path_display = { shorten = { len = 1, exclude = { -1 } } },
    sorting_strategy = "ascending",
}

-- #10 — Vertical Compact ("same as above but pretty cleaner")
local find_files_opts = {
    layout_strategy = "vertical",
    layout_config = {
        width = 0.5,
        height = 0.7,
        preview_height = 0.25,
        prompt_position = "top",
        mirror = true,
    },
    previewer = true,
    border = true,
    winblend = 10,
    prompt_prefix = "  ",
    selection_caret = " ▸ ",
    path_display = { shorten = { len = 1, exclude = { -1 } } },
    sorting_strategy = "ascending",
}

-- #12 — Ivy With Preview ("super minimal but just go big")
-- ════════════════════════════════════════════
-- │ Prompt                                   │
-- ├────────────────────┬─────────────────────┤
-- │ Results            │ Preview             │
-- ════════════════════════════════════════════
local find_files_opts = function()
    return require("telescope.themes").get_ivy({
        layout_config = {
            height = 0.4,
        },
        winblend = 10,
        prompt_prefix = "  ",
        selection_caret = " ▸ ",
        path_display = { shorten = { len = 1, exclude = { -1 } } },
        sorting_strategy = "ascending",
    })
end

-- #16 — Bottom Pane No Preview ("super fucking clean / best for knowing the exact file")
local find_files_opts = {
    layout_strategy = "bottom_pane",
    layout_config = {
        height = 15,
        prompt_position = "top",
    },
    previewer = false,
    border = true,
    winblend = 10,
    prompt_prefix = "  ",
    selection_caret = " ▸ ",
    path_display = { shorten = { len = 1, exclude = { -1 } } },
    sorting_strategy = "ascending",
}

-- #19 — Dropdown With Preview ("best for debugging")
local find_files_opts = function()
    return require("telescope.themes").get_dropdown({
        previewer = true,
        layout_config = {
            width = 0.6,
            height = 0.6,
        },
        winblend = 10,
        prompt_prefix = "  ",
        selection_caret = " ▸ ",
        path_display = { shorten = { len = 1, exclude = { -1 } } },
        sorting_strategy = "ascending",
    })
end

-- #26 — Anchored Top-Center / Notification Style ("has potential")
local find_files_opts = {
    layout_strategy = "horizontal",
    layout_config = {
        width = 0.7,
        height = 0.35,
        anchor = "N",
        prompt_position = "top",
        preview_width = 0.5,
    },
    previewer = true,
    border = true,
    winblend = 10,
    prompt_prefix = "  ",
    selection_caret = " ▸ ",
    path_display = { shorten = { len = 1, exclude = { -1 } } },
    sorting_strategy = "ascending",
}

-- #27 — Anchored Bottom-Center ("looks fancy af")
local find_files_opts = {
    layout_strategy = "horizontal",
    layout_config = {
        width = 0.7,
        height = 0.35,
        anchor = "S",
        prompt_position = "top",
        preview_width = 0.5,
    },
    previewer = true,
    border = true,
    winblend = 10,
    prompt_prefix = "  ",
    selection_caret = " ▸ ",
    path_display = { shorten = { len = 1, exclude = { -1 } } },
    sorting_strategy = "ascending",
}

-- #28 — Tall Narrow Sidebar East ("potential")
local find_files_opts = {
    layout_strategy = "vertical",
    layout_config = {
        width = 0.35,
        height = 0.9,
        anchor = "E",
        prompt_position = "top",
        mirror = true,
        preview_height = 0.4,
    },
    previewer = true,
    border = true,
    winblend = 10,
    prompt_prefix = "  ",
    selection_caret = " ▸ ",
    path_display = { shorten = { len = 1, exclude = { -1 } } },
    sorting_strategy = "ascending",
}

-- #30 — Fixed Pixel Sizes ("central potential")
local find_files_opts = {
    layout_strategy = "horizontal",
    layout_config = {
        width = 120,
        height = 30,
        preview_width = 60,
        prompt_position = "top",
    },
    previewer = true,
    border = true,
    winblend = 10,
    prompt_prefix = "  ",
    selection_caret = " ▸ ",
    path_display = { shorten = { len = 1, exclude = { -1 } } },
    sorting_strategy = "ascending",
}
