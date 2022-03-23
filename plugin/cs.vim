command! -nargs=+ -complete=custom,cs#complete CS call cs#cheatsheet(<f-args>)
nnoremap <expr> <Leader>cs ':CS <C-r>=' . (&syntax==''?'&filetype':'&syntax') . '<CR>/' . expand('<cword>')
vnoremap <expr> <Leader>cs 'y:CS <C-r>=' . (&syntax==''?'&filetype':'&syntax') . '<CR>/<C-r>"'
