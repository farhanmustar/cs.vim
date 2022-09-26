command! -nargs=+ -complete=custom,cs#complete CS call cs#cheatsheet(<f-args>)

nnoremap <expr> <Plug>(CS-Promp) ':CS <C-r>=' . (&syntax==''?'&filetype':'&syntax') . '<CR>/' . expand('<cword>')
vnoremap <expr> <Plug>(CS-Promp) 'y:CS <C-r>=' . (&syntax==''?'&filetype':'&syntax') . '<CR>/<C-r>"'
