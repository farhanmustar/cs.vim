" TODO: move some to autoload for lazy loading
let s:filetype_map_dict = {
\   '/': 'markdown',
\   'js': 'javascript',
\   'jquery': 'javascript',
\   'git': 'markdown',
\}
let g:filetype_map_dict = get(g:, 'filetype_map_dict', {})

" Main function

function! cs#cheatsheet(...) abort
  let argument = substitute(join(a:000, '+'), '\s\+', '+', 'g')
  let argument = substitute(argument, '/*', '/', '')
  let argument = substitute(argument, '^/', '', '')
  let argument = substitute(argument, '/$', '', '')

  " get filetype
  if stridx(argument, '/') < 0
    let filetype = '/'
  else
    let filetype = substitute(argument, '/[^ ]*$', '', '')
  endif
  let filetype = s:filetype_map(filetype)

  " get options
  if stridx(argument, '?') < 0
    let options = 'T'
  else
    let options = substitute(argument, '[^?]*?', '', '')
    if stridx(options, '?') >= 0
      call s:warn('Invalid cheat.sh options')
      return
    endif
    " force text only
    if stridx(options, 'T') < 0
      let options = options.'T'
    endif

    let argument = substitute(argument, '?[^ ]*$', '', '')
  endif
  " TODO: validate options

  let alt = str2nr(matchstr(argument,'/\zs[0-9\-]\+\ze$'), 10)

  call s:new_buffer(filetype)
  call s:get_cheatsheet(argument, options, alt)
:endfunction

" Buffer actions

function! cs#next() abort
  if !exists('b:cs_buffer')
    return
  endif
  call s:get_cheatsheet(b:cs_argument, b:cs_options, b:cs_alt + 1)
:endfunction

function! cs#prev() abort
  if !exists('b:cs_buffer')
    return
  endif
  call s:get_cheatsheet(b:cs_argument, b:cs_options, b:cs_alt - 1)
:endfunction

" Sub functions

function! s:new_buffer(filetype) abort
  execute 'below new'
  setlocal buftype=nofile bufhidden=wipe noswapfile nomodeline
  execute 'set ft='.a:filetype
:endfunction

function! s:get_cheatsheet(argument, options, alt) abort
  let bufname = 'CS '.a:argument.' ['.a:alt.']'
  let cmd = s:get_cmd(a:argument, a:options, a:alt)

  echo 'CS fetching data... ['.cmd.']'
  silent execute 'file' fnameescape(bufname)
  call s:fill(cmd)
  call s:post_setup(a:argument, a:options, a:alt)
:endfunction

function! s:get_cmd(argument, options, alt) abort
  let curl_cmd = get(g:, 'cs_curl_cmd', 'curl --silent')
  let cheatsheet_url = get(g:, 'cs_cheatsheet_url', 'https://cht.sh')
  return join([curl_cmd, cheatsheet_url.'/'.a:argument.(a:alt == 0 ? '' : '/'.a:alt).'?'.a:options])
:endfunction

function! s:fill(cmd) abort
  setlocal modifiable
  silent normal! gg"_dG
  silent execute 'read' escape('!'.a:cmd, '%')
  normal! gg"_dd
  setlocal nomodifiable
:endfunction

function! s:post_setup(argument, options, alt) abort
  call s:maps()
  " mark buffer
  let b:cs_buffer = 1
  " save buffer data
  let b:cs_argument = a:argument
  let b:cs_options = a:options
  let b:cs_alt = a:alt
:endfunction

" Helper function

function! s:warn(message)
  echohl WarningMsg | echom a:message | echohl None
:endfunction

function! s:filetype_map(filetype)
  if has_key(g:filetype_map_dict, a:filetype)
    return g:filetype_map_dict[a:filetype]
  elseif has_key(s:filetype_map_dict, a:filetype)
    return s:filetype_map_dict[a:filetype]
  else
    return a:filetype
  endif
:endfunction

" CS binding

function! s:maps()
  if exists('b:cs_buffer')
    return
  endif
  nnoremap <silent> <buffer> > :call cs#next()<cr>
  nnoremap <silent> <buffer> < :call cs#prev()<cr>
:endfunction

command! -nargs=+ CS call cs#cheatsheet(<f-args>)
