command! -nargs=+ -complete=custom,cs#complete CS call cs#cheatsheet(<f-args>)
nnoremap <Leader>cs :CS <C-r>=&syntax<CR>/<C-r><C-w>
vnoremap <Leader>cs y:CS <C-r>=&syntax<CR>/<C-r>"
