-------------------    RUNS PROJECT ------------------------
vim.cmd [[
function! CompileAndRunJavaPackage()
    let l:current_file = expand('%')
    let l:package_directory = expand('%:p:h')
    let l:parent_directory = fnamemodify(l:package_directory, ':h')
    execute '!javac ' . l:package_directory . '/*.java'
    let l:package_name = substitute(l:package_directory, l:parent_directory.'/', '', '')
    let l:package_name = substitute(l:package_name, '/', '.', 'g')
    let l:class_name = fnamemodify(l:current_file, ':t:r')
    let l:full_class = l:package_name . '.' . l:class_name
    execute '!java -cp ' . l:parent_directory . ' ' . l:full_class
endfunction
]]

vim.api.nvim_set_keymap('n', '<Space>rp', ':call CompileAndRunJavaPackage()<CR>:30split',
  { noremap = true, silent = true })
----------------                              ----------------




-------------------    RUNS FILE    ------------------------
vim.api.nvim_set_keymap('n', '<Space>rf', ':w!<CR>:!javac % && echo "" && echo "OUTPUT:" && java %<CR>',
  { noremap = true, silent = true })
----------------                              ----------------





-- -------------------    RUNS FILE    ------------------------  -- NOT WORKING
-- vim.cmd [[
-- function! CompileAndRunJavaFile()
--   let l:current_file = expand('%:p')
--   let l:file_without_extension = expand('%:t:r')
--   let l:current_directory = expand('%:p:h')
--   let l:command = 'javac ' . l:current_file . ' && java -cp ' . l:current_directory . ' ' . l:file_without_extension
--   execute '!'.l:command
-- endfunction

-- ]]

-- vim.api.nvim_set_keymap('n', '<Space>rf', ':call CompileAndRunJavaFile()<CR>',
--   { noremap = true, silent = true })
-- ----------------                              ----------------
