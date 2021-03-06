let g:syntax_map_dict = get(g:, 'syntax_map_dict', {})
let g:cs_curl_max_time = get(g:, 'cs_curl_max_time', 10)
let g:cs_curl_cmd = get(g:, 'cs_curl_cmd', 'curl --silent --max-time '.g:cs_curl_max_time)
let g:cs_cheatsheet_url = get(g:, 'cs_cheatsheet_url', 'https://cht.sh')

let s:syntax_map_dict = {
\   '/': 'markdown',
\   'git': 'markdown',
\   'jquery': 'javascript',
\   'js': 'javascript',
\   'vimscript': 'vim',
\}

" Main function

function! cs#cheatsheet(...) abort
  let data = call('s:extract_argument', a:000)

  call s:new_buffer(data['syntax'])
  call s:get_cheatsheet(data['argument'], data['options'], data['alt'])
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

function! cs#reload() abort
  if !exists('b:cs_buffer')
    return
  endif
  call s:get_cheatsheet(b:cs_argument, b:cs_options, b:cs_alt)
:endfunction

" Command autocomplete

function! cs#complete(arg, line, cur) abort
  let argument = substitute(a:line, '^CS ', '', '')
  let is_empty_complete = match(argument, '/$') >= 0
  let is_start_with_slash = match(argument, '^/') >= 0
  let data = s:extract_argument(argument)
  if !has_key(data, 'argument') ||
        \!has_key(data, 'alt') ||
        \stridx(argument, '?') >= 0 ||
        \stridx(data['argument'], '+') >= 0 ||
        \data['alt'] > 0
    return ''
  elseif data['argument'] == ''
    let cmd = s:get_cmd(':list', 'T', '0')
    echo ':CS '.(is_start_with_slash ? '/' : '').'...'
    let result = s:cached_system(cmd)
    if is_start_with_slash
      " need to match current str in cmdline
      let result = substitute(result, '^', '/', '')
      let result = substitute(result, '\zs\n\ze[^$]', '\n/', 'g')
    endif
    return result
  elseif stridx(data['argument'], '/') < 0 && !is_empty_complete
    echo ':CS '.(is_start_with_slash ? '/' : '').data['argument'].'...'
    let cmd = s:get_cmd(':list', 'T', '0')
    let result = s:cached_system(cmd)
    if is_start_with_slash
      " need to match current str in cmdline
      let result = substitute(result, '^', '/', '')
      let result = substitute(result, '\zs\n\ze[^$]', '\n/', 'g')
    endif
    return result
  elseif is_empty_complete
    echo ':CS '.(is_start_with_slash ? '/' : '').data['argument'].'/...'
    let cmd = s:get_cmd(data['argument'].'/:list', 'T', '0')
    let result = s:cached_system(cmd)

    " need to match current str in cmdline
    let result = substitute(result, '^', (is_start_with_slash ? '/' : '').data['argument'].'/', '')
    let result = substitute(result, '\zs\n\ze[^$]', '\n'.(is_start_with_slash ? '/' : '').data['argument'].'/', 'g')
    return result
  else
    echo ':CS '.(is_start_with_slash ? '/' : '').data['argument'].'...'
    let cmd_argument = substitute(data['argument'], '[^/]*$', '', '')
    let start = matchstr(data['argument'], '[^/]*$')
    let cmd = s:get_cmd(cmd_argument.':list', 'T', '0')
    let result = s:cached_system(cmd)

    " need to match current str in cmdline
    let result = substitute(result, '^', (is_start_with_slash ? '/' : '').cmd_argument, '')
    let result = substitute(result, '\zs\n\ze[^$]', '\n'.(is_start_with_slash ? '/' : '').cmd_argument, 'g')
    return result
  endif
  return ''
:endfunction

" Sub functions

function! s:extract_argument(...) abort
  let argument = substitute(join(a:000, '+'), '\s\+', '+', 'g')
  let argument = substitute(argument, '/*', '/', '')
  let argument = substitute(argument, '^/', '', '')
  let argument = substitute(argument, '/$', '', '')

  " get syntax
  if stridx(argument, '/') < 0
    let syntax = argument
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
  let url = g:cs_cheatsheet_url.'/'.a:argument.(a:alt == 0 ? '' : '/'.a:alt).'?'.a:options
  return g:cs_curl_cmd.' "'.url.'"'
:endfunction

function! s:fill(cmd) abort
  setlocal modifiable
  silent normal! gg"_dG

  let b:fill_cache_list = get(b:, 'fill_cache_list', [])
  let b:fill_cache_data = get(b:, 'fill_cache_data', {})

  if has_key(b:fill_cache_data, a:cmd)
    call remove(b:fill_cache_list, index(b:fill_cache_list, a:cmd))
    let b:fill_cache_list += [a:cmd]

    set paste
    execute ':normal! o'.b:fill_cache_data[a:cmd]
    set nopaste

    normal! gg"_dd
    setlocal nomodifiable
    return
  endif

  silent execute 'read' escape('!'.a:cmd, '%')
  normal! gg"_dd
  if v:shell_error != 0
    set paste
    execute ':normal! OFail to fetch data, please press r to reload.'
    set nopaste
    silent normal! G
  else
    let b:fill_cache_list += [a:cmd]
    let b:fill_cache_data[a:cmd] = join(getline(1, '$'), "\n")
  endif

  " cache limit = 5
  if len(b:fill_cache_list) > 5
    let del_key = b:fill_cache_list[0]
    let b:fill_cache_list = b:fill_cache_list[1:]
    call remove(b:fill_cache_data, del_key)
  endif

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
  elseif index(getcompletion('', 'syntax'), a:syntax) >= 0
    return a:syntax
  elseif has_key(g:syntax_map_dict, '/')
    return g:syntax_map_dict['/']
  endif
  return s:syntax_map_dict['/']
:endfunction

function! s:cached_system(cmd) abort
  let s:system_cache_list = get(s:, 'system_cache_list', [])
  let s:system_cache_data = get(s:, 'system_cache_data', {})
  if has_key(s:system_cache_data, a:cmd)
    call remove(s:system_cache_list, index(s:system_cache_list, a:cmd))
    let s:system_cache_list += [a:cmd]
    return s:system_cache_data[a:cmd]
  endif
  let result = system(a:cmd)
  if empty(trim(result))
    return ''
  endif

  let s:system_cache_list += [a:cmd]
  let s:system_cache_data[a:cmd] = result

  " cache limit = 5
  if len(s:system_cache_list) > 5
    let del_key = s:system_cache_list[0]
    let s:system_cache_list = s:system_cache_list[1:]
    call remove(s:system_cache_data, del_key)
  endif

  return result
:endfunction

" CS binding

function! s:maps()
  if exists('b:cs_buffer')
    return
  endif
  nnoremap <silent> <buffer> > :call cs#next()<cr>
  nnoremap <silent> <buffer> < :call cs#prev()<cr>
  nnoremap <silent> <buffer> r :call cs#reload()<cr>
:endfunction
