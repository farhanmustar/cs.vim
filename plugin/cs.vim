" TODO: move some to autoload for lazy loading
let s:syntax_map_dict = {
\   '/': 'markdown',
\   'js': 'javascript',
\   'jquery': 'javascript',
\   'git': 'markdown',
\}
let g:syntax_map_dict = get(g:, 'syntax_map_dict', {})

" Main function

function! cs#cheatsheet(...) abort
  let data = call('s:extract_argument', a:000)

  call s:new_buffer(data['syntax'])
  call s:get_cheatsheet(data['argument'], data['options'], data['alt'])
:endfunction

function! s:extract_argument(...) abort
  let argument = substitute(join(a:000, '+'), '\s\+', '+', 'g')
  let argument = substitute(argument, '/*', '/', '')
  let argument = substitute(argument, '^/', '', '')
  let argument = substitute(argument, '/$', '', '')

  " get syntax
  if stridx(argument, '/') < 0
    let syntax = '/'
  else
    let syntax = substitute(argument, '/[^ ]*$', '', '')
  endif
  let syntax = s:syntax_map(syntax)

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

  "get alt number
  let alt = str2nr(matchstr(argument,'/\zs[0-9\-]\+\ze$'), 10)
  let argument = substitute(argument, '/[0-9\-]\+$', '', '')

  return {
        \ 'alt': alt,
        \ 'argument': argument,
        \ 'syntax': syntax,
        \ 'options': options,
        \}
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

function! cs#complete(arg, line, cur) abort
  " TODO: should we cache the resulting list? configurable?
  " TODO: consider user initially put /
  let argument = substitute(a:line, '^CS ', '', '')
  let is_empty_complete = match(argument, '/$') >= 0
  let data = s:extract_argument(argument)
  if !has_key(data, 'argument') ||
        \!has_key(data, 'alt') ||
        \stridx(argument, '?') >= 0 ||
        \stridx(data['argument'], '+') >= 0 ||
        \data['alt'] > 0
    return ''
  elseif data['argument'] == ''
    let cmd = s:get_cmd(':list', 'T', '0')
    echo ':CS ...'
    return system(cmd)
  elseif stridx(data['argument'], '/') < 0 && !is_empty_complete
    echo ':CS '.data['argument'].'...'
    let cmd = s:get_cmd(':list', 'T', '0')
    return system(cmd)
    " let result = system(cmd)
    " return s:multiline_str_startswith(result, data['argument'])
  elseif is_empty_complete
    echo ':CS '.data['argument'].'/...'
    let cmd = s:get_cmd(data['argument'].'/:list', 'T', '0')
    let result = system(cmd)

    " need to match current str in cmdline
    let result = substitute(result, '^', data['argument'].'/', '')
    let result = substitute(result, '\zs\n\ze[^$]', '\n'.data['argument'].'/', 'g')
    echom result
    return result
  else
    echo ':CS '.data['argument'].'...'
    let cmd_argument = substitute(data['argument'], '[^/]*$', '', '')
    let start = matchstr(data['argument'], '[^/]*$')
    let cmd = s:get_cmd(cmd_argument.':list', 'T', '0')
    let result = system(cmd)
    " let result = s:multiline_str_startswith(result, start)

    " need to match current str in cmdline
    let result = substitute(result, '^', cmd_argument, '')
    let result = substitute(result, '\zs\n\ze[^$]', '\n'.cmd_argument, 'g')
    return result
  endif
  return ''
:endfunction

function! s:multiline_str_startswith(expr, start) abort
  " TODO: fix how to include both first line and first string char.
  let escaped = s:escape_regex(a:start)
  let match = substitute(a:expr, '^\('.escaped.'\)\@![^\n]*', '', 'g')
  return substitute(match, '\n\('.escaped.'\)\@![^\n]*', '', 'g')
:endfunction

function! s:escape_regex(str)
  return escape(a:str, '^$.*?/\[]')
endfunction

" Sub functions

function! s:new_buffer(syntax) abort
  execute 'below new'
  setlocal buftype=nofile bufhidden=wipe noswapfile nomodeline
  execute 'set syntax='.a:syntax
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

function! s:syntax_map(syntax)
  if has_key(g:syntax_map_dict, a:syntax)
    return g:syntax_map_dict[a:syntax]
  elseif has_key(s:syntax_map_dict, a:syntax)
    return s:syntax_map_dict[a:syntax]
  else
    return a:syntax
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

command! -nargs=+ -complete=custom,cs#complete CS call cs#cheatsheet(<f-args>)
