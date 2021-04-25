command! -nargs=+ -complete=custom,cs#complete CS call cs#cheatsheet(<f-args>)
nnoremap <expr> <Leader>cs ":CS <C-r>=&syntax<CR>/" . expand('<cword>')
vnoremap <Leader>cs y:CS <C-r>=&syntax<CR>/<C-r>"
