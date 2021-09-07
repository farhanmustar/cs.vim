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
  let l:data = call('s:extract_argument', a:000)

  call s:get_cheatsheet(l:data['syntax'], l:data['argument'], l:data['options'], l:data['alt'], -1)
endfunction

" Buffer actions

function! cs#next() abort
  if !exists('b:cs_buffer')
    return
  endif
  call s:get_cheatsheet(b:cs_syntax, b:cs_argument, b:cs_options, b:cs_alt + 1, bufnr())
endfunction

function! cs#prev() abort
  if !exists('b:cs_buffer')
    return
  endif
  call s:get_cheatsheet(b:cs_syntax, b:cs_argument, b:cs_options, b:cs_alt - 1, bufnr())
endfunction

function! cs#reload() abort
  if !exists('b:cs_buffer') || !exists('b:cs_buffer_fail')
    return
  endif
  call s:get_cheatsheet(b:cs_syntax, b:cs_argument, b:cs_options, b:cs_alt, bufnr())
endfunction

" Command autocomplete

function! cs#complete(arg, line, cur) abort
  let l:argument = substitute(a:line, '^CS ', '', '')
  let l:is_empty_complete = match(l:argument, '/$') >= 0
  let l:is_start_with_slash = match(l:argument, '^/') >= 0
  let l:data = s:extract_argument(l:argument)
  if !has_key(l:data, 'argument') ||
        \!has_key(l:data, 'alt') ||
        \stridx(l:argument, '?') >= 0 ||
        \stridx(l:data['argument'], '+') >= 0 ||
        \l:data['alt'] > 0
    return ''
  elseif l:data['argument'] == ''
    let l:cmd = s:get_cmd(':list', 'T', '0')
    echo ':CS '.(l:is_start_with_slash ? '/' : '').'...'
    let l:result = s:cached_system(l:cmd)
    if l:is_start_with_slash
      " need to match current str in cmdline
      let l:result = substitute(l:result, '^', '/', '')
      let l:result = substitute(l:result, '\zs\n\ze[^$]', '\n/', 'g')
    endif
    return l:result
  elseif stridx(l:data['argument'], '/') < 0 && !l:is_empty_complete
    echo ':CS '.(l:is_start_with_slash ? '/' : '').l:data['argument'].'...'
    let l:cmd = s:get_cmd(':list', 'T', '0')
    let l:result = s:cached_system(l:cmd)
    if l:is_start_with_slash
      " need to match current str in cmdline
      let l:result = substitute(l:result, '^', '/', '')
      let l:result = substitute(l:result, '\zs\n\ze[^$]', '\n/', 'g')
    endif
    return l:result
  elseif l:is_empty_complete
    echo ':CS '.(l:is_start_with_slash ? '/' : '').l:data['argument'].'/...'
    let l:cmd = s:get_cmd(l:data['argument'].'/:list', 'T', '0')
    let l:result = s:cached_system(l:cmd)

    " need to match current str in cmdline
    let l:result = substitute(l:result, '^', (l:is_start_with_slash ? '/' : '').l:data['argument'].'/', '')
    let l:result = substitute(l:result, '\zs\n\ze[^$]', '\n'.(l:is_start_with_slash ? '/' : '').l:data['argument'].'/', 'g')
    return l:result
  else
    echo ':CS '.(l:is_start_with_slash ? '/' : '').l:data['argument'].'...'
    let l:cmd_argument = substitute(l:data['argument'], '[^/]*$', '', '')
    let l:start = matchstr(l:data['argument'], '[^/]*$')
    let l:cmd = s:get_cmd(l:cmd_argument.':list', 'T', '0')
    let l:result = s:cached_system(l:cmd)

    " need to match current str in cmdline
    let l:result = substitute(l:result, '^', (l:is_start_with_slash ? '/' : '').l:cmd_argument, '')
    let l:result = substitute(l:result, '\zs\n\ze[^$]', '\n'.(l:is_start_with_slash ? '/' : '').l:cmd_argument, 'g')
    return l:result
  endif
  return ''
endfunction

" Sub functions

function! s:extract_argument(...) abort
  let l:argument = substitute(join(a:000, '+'), '\s\+', '+', 'g')
  let l:argument = substitute(l:argument, '/*', '/', '')
  let l:argument = substitute(l:argument, '^/', '', '')
  let l:argument = substitute(l:argument, '/$', '', '')

  " get syntax
  if stridx(l:argument, '/') < 0
    let l:syntax = l:argument
  else
    let l:syntax = substitute(l:argument, '/[^ ]*$', '', '')
  endif
  let l:syntax = s:syntax_map(l:syntax)

  " get options
  if stridx(l:argument, '?') < 0
    let l:options = 'T'
  else
    let l:options = substitute(l:argument, '[^?]*?', '', '')
    if stridx(l:options, '?') >= 0
      call s:warn('Invalid cheat.sh options')
      return
    endif
    " force text only
    if stridx(l:options, 'T') < 0
      let l:options = l:options.'T'
    endif

    let l:argument = substitute(l:argument, '?[^ ]*$', '', '')
  endif

  "get alt number
  let l:alt = str2nr(matchstr(l:argument,'/\zs[0-9\-]\+\ze$'), 10)
  let l:argument = substitute(l:argument, '/[0-9\-]\+$', '', '')

  return {
        \ 'alt': l:alt,
        \ 'argument': l:argument,
        \ 'syntax': l:syntax,
        \ 'options': l:options,
        \}
endfunction

function! s:get_cheatsheet(syntax, argument, options, alt, buf_nr) abort
  let l:cmd = s:get_cmd(a:argument, a:options, a:alt)

  let l:content = s:get_cache(a:buf_nr, l:cmd)
  if !empty(l:content)
    call s:process_cheatsheet(l:content, a:syntax, a:argument, a:options, a:alt, a:buf_nr)
    echo 'CS restore cached data... ['.cmd.']'
    return
  endif

  echo 'CS fetching data... ['.l:cmd.']'
  let Callback = function('s:job_callback', [a:syntax, a:argument, a:options, a:alt, a:buf_nr])
  call job_start(l:cmd, {'close_cb': Callback})
endfunction

function! s:job_callback(syntax, argument, options, alt, buf_nr, channel) abort
  let l:response = []
  while ch_status(a:channel, {'part': 'out'}) == 'buffered'
    let l:response += [ch_read(a:channel)]
  endwhile
  call s:process_cheatsheet(l:response, a:syntax, a:argument, a:options, a:alt, a:buf_nr)
endfunction

function! s:process_cheatsheet(content, syntax, argument, options, alt, buf_nr) abort
  let l:cmd = s:get_cmd(a:argument, a:options, a:alt)

  let l:cur_winid = win_getid()

  call s:goto_buf(a:buf_nr, a:syntax)
  silent execute 'file' fnameescape('CS '.a:argument.' ['.a:alt.']')
  call s:save_cache(a:content, l:cmd)
  call s:fill(a:content)
  call s:post_setup(a:syntax, a:argument, a:options, a:alt)

  call win_gotoid(l:cur_winid)
endfunction

function! s:goto_buf(buf_nr, syntax) abort
  let l:buf_nr = bufnr(a:buf_nr)
  if l:buf_nr == -1
    call s:new_buffer(a:syntax)
    return
  elseif l:buf_nr == bufnr()
    return
  endif

  let l:win_id = bufwinid(l:buf_nr)
  if l:win_id == -1
    s:new_window(l:buf_nr)
  else
    call win_gotoid(l:win_id)
  endif
endfunction

function! s:new_buffer(syntax) abort
  execute 'below new'
  setlocal buftype=nofile bufhidden=wipe noswapfile nomodeline nobuflisted
  execute 'set syntax='.a:syntax
endfunction

function! s:new_window(buf_nr) abort
  execute 'below new'
  buffer a:buf_nr
endfunction

function! s:save_cache(content, cmd) abort
  if empty(a:content)
    return
  endif
  let b:fill_cache_list = get(b:, 'fill_cache_list', [])
  let b:fill_cache_content = get(b:, 'fill_cache_content', {})

  if index(b:fill_cache_list, a:cmd) >= 0
    call remove(b:fill_cache_list, index(b:fill_cache_list, a:cmd))
  endif
  let b:fill_cache_list += [a:cmd]
  let b:fill_cache_content[a:cmd] = a:content

  " cache limit = 5
  if len(b:fill_cache_list) > 5
    let l:del_key = b:fill_cache_list[0]
    let b:fill_cache_list = b:fill_cache_list[1:]
    call remove(b:fill_cache_content, l:del_key)
  endif
endfunction

function! s:get_cache(buf_nr, cmd) abort
  let l:cache_content = getbufvar(a:buf_nr, 'fill_cache_content', {})
  if !has_key(l:cache_content, a:cmd)
    return []
  endif
  return l:cache_content[a:cmd]
endfunction

function! s:get_cmd(argument, options, alt) abort
  let l:url = g:cs_cheatsheet_url.'/'.a:argument.(a:alt == 0 ? '' : '/'.a:alt).'?'.a:options
  return g:cs_curl_cmd.' "'.l:url.'"'
endfunction

function! s:fill(content) abort
  setlocal modifiable
  silent normal! gg"_dG

  if empty(a:content)
    execute ':normal! IFail to fetch data, please press r to reload.'
    silent normal! gg
    let b:cs_buffer_fail = 1
  else
    call setline('.', a:content)
    silent! call remove(b:, 'cs_buffer_fail')
  endif

  setlocal nomodifiable
endfunction

function! s:post_setup(syntax, argument, options, alt) abort
  call s:maps()
  " mark buffer
  let b:cs_buffer = 1
  " save buffer data
  let b:cs_syntax = a:syntax
  let b:cs_argument = a:argument
  let b:cs_options = a:options
  let b:cs_alt = a:alt
endfunction

" Helper function

function! s:warn(message) abort
  echohl WarningMsg | echom a:message | echohl None
endfunction

function! s:syntax_map(syntax) abort
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
endfunction

function! s:cached_system(cmd) abort
  let s:system_cache_list = get(s:, 'system_cache_list', [])
  let s:system_cache_data = get(s:, 'system_cache_data', {})
  if has_key(s:system_cache_data, a:cmd)
    call remove(s:system_cache_list, index(s:system_cache_list, a:cmd))
    let s:system_cache_list += [a:cmd]
    return s:system_cache_data[a:cmd]
  endif
  let l:result = system(a:cmd)
  if empty(trim(l:result))
    return ''
  endif

  let s:system_cache_list += [a:cmd]
  let s:system_cache_data[a:cmd] = l:result

  " cache limit = 5
  if len(s:system_cache_list) > 5
    let l:del_key = s:system_cache_list[0]
    let s:system_cache_list = s:system_cache_list[1:]
    call remove(s:system_cache_data, l:del_key)
  endif

  return l:result
endfunction

" CS binding

function! s:maps() abort
  if exists('b:cs_buffer')
    return
  endif
  nnoremap <silent> <buffer> > :call cs#next()<cr>
  nnoremap <silent> <buffer> < :call cs#prev()<cr>
  nnoremap <silent> <buffer> r :call cs#reload()<cr>
endfunction
