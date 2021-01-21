" TODO: move some to autoload for lazy loading
" TODO: add all filetype map
let s:filetype_map_dict = {
\   'js': 'javascript',
\}


function! s:warn(message)
  echohl WarningMsg | echom a:message | echohl None
:endfunction

function! s:new_buffer(filetype)
  execute 'below new'
  setlocal buftype=nofile bufhidden=wipe noswapfile nomodeline
  execute 'set ft='.a:filetype
:endfunction

function! s:fill(cmd)
  setlocal modifiable
  silent execute 'read' escape('!'.a:cmd, '%')
  setlocal nomodifiable
:endfunction

function! s:filetype_map(filetype)
  if has_key(s:filetype_map_dict, a:filetype)
    return s:filetype_map_dict[a:filetype]
  else
    return a:filetype
  endif
:endfunction

" Plugin development
function! cs#cheatsheet(...)
  let s:argument = substitute(join(a:000, '+'), '\s\+', '+', 'g')
  let s:argument = substitute(s:argument, '/*', '/', '')
  let s:argument = substitute(s:argument, '^/', '', '')

  " get filetype
  if stridx(s:argument, '/') < 0
    let s:filetype = 'bash'
  else
    let s:filetype = substitute(s:argument, '/[^ ]*$', '', '')
  endif
  let s:filetype = s:filetype_map(s:filetype)

  " get options
  if stridx(s:argument, '?') < 0
    let s:options = 'T'
  else
    let s:options = substitute(s:argument, '[^?]*?', '', '')
    if stridx(s:options, '?') >= 0
      call s:warn('Invalid cheat.sh options')
      return
    endif
    " force text only
    if stridx(s:options, 'T') < 0
      let s:options = s:options.'T'
    endif

    let s:argument = substitute(s:argument, '?[^ ]*$', '', '')
  endif
  " TODO: validate options

  call s:get_cheatsheet(s:filetype, s:argument, s:options)
:endfunction

function! s:get_cheatsheet(filetype, argument, options)
  let curl_cmd = 'curl --silent'
  let cheatsheet_url = 'https://cht.sh'
  if exists('g:cs_curl_cmd')
    let curl_cmd = g:cs_curl_cmd
  endif
  if exists('g:cs_cheatsheet_url')
    let cheatsheet_url = g:cs_cheatsheet_url
  endif

  let cmd = join([curl_cmd, cheatsheet_url.'/'.a:argument.'?'.a:options])

  call s:new_buffer(a:filetype)
  call s:fill(cmd)
:endfunction

" command! -nargs=+ CS silent cs#cheatsheet! <args>
command! -nargs=+ CS call cs#cheatsheet(<f-args>)
