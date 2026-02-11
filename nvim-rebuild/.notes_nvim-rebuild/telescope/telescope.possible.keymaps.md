# Telescope — Possible Keybindings Reference

## Pickers

### Tier 1 — Daily Drivers

1. `find_files` — fuzzy find project files | `<leader>ff`
2. `live_grep` — search file contents as you type | `<leader>fg` or `<leader>/`
3. `buffers` — switch open buffers | `<leader>fb` or `<leader>,`
4. `oldfiles` — recently opened files | `<leader>fo` or `<leader>fr`
5. `resume` — reopen last picker where you left off | `<leader>f.` or `<leader>fR`

### Tier 2 — High Value

6. `grep_string` — grep word under cursor (instant) | `<leader>fw` or `<leader>ps`
7. `current_buffer_fuzzy_find` — fuzzy search current file lines | `<leader>f/` or `<leader>fz`
8. `help_tags` — search :help docs | `<leader>fh`
9. `git_files` — files tracked by git (fast) | `<C-p>` or `<leader>gf`
10. `git_status` — changed files with diff preview | `<leader>gs`
11. `git_commits` — commit history with diffs | `<leader>gc`
12. `diagnostics` — LSP diagnostics across buffers | `<leader>fd` or `<leader>dd`
13. `keymaps` — all active keybindings | `<leader>fk`

### Tier 3 — Situational

14. `git_branches` — browse/checkout branches | `<leader>gb`
15. `git_bcommits` — commits for current buffer/selection | `<leader>gC`
16. `git_stash` — browse stash entries | `<leader>gS`
17. `lsp_references` — references to symbol under cursor | `grr`
18. `lsp_definitions` — go to definition (multi-result) | `grd` or `gd`
19. `lsp_implementations` — go to implementation | `gri`
20. `lsp_type_definitions` — go to type definition | `gy` or `grt`
21. `lsp_document_symbols` — symbols in current file | `gO` or `<leader>fs`
22. `lsp_workspace_symbols` — symbols across workspace | `gW` or `<leader>fS`
23. `treesitter` — browse treesitter nodes | `<leader>ft`
24. `command_history` — previous : commands | `<leader>f:` or `<leader>:`
25. `search_history` — previous / searches | `<leader>f?`
26. `marks` — browse vim marks | `<leader>fm`
27. `registers` — browse vim registers | `<leader>f"`
28. `quickfix` — fuzzy filter quickfix list | `<leader>fq`
29. `loclist` — fuzzy filter location list | `<leader>fl`
30. `jumplist` — browse jump history | `<leader>fj`
31. `spell_suggest` — spelling suggestions under cursor | `z=`
32. `colorscheme` — preview/switch colorschemes | `<leader>fc`
33. `filetypes` — set filetype for current buffer | (unbound)
34. `highlights` — browse highlight groups | (unbound)
35. `autocommands` — browse active autocommands | (unbound)
36. `vim_options` — browse/toggle vim options | (unbound)
37. `man_pages` — search system man pages | `<leader>fM`
38. `builtin` — meta-picker: list all pickers | `<leader>fF` or `<leader>f<leader>`

## Internal Actions (inside any open picker)

39. `<CR>` — open in current window
40. `<C-x>` — open in horizontal split
41. `<C-v>` — open in vertical split
42. `<C-t>` — open in new tab
43. `<C-n>` / `<C-p>` — move selection down/up
44. `<C-d>` / `<C-u>` — scroll preview down/up
45. `<Tab>` / `<S-Tab>` — toggle selection + move
46. `<C-q>` — send all/selected to quickfix
47. `<M-q>` — send all/selected to loclist
48. `<C-/>` / `?` — show picker mappings
49. `<Esc>` / `q` — close
50. cycle_history_next/prev — recall previous queries
51. delete_buffer — kill buffer (buffers picker only)
