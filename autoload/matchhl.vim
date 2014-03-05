scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

function! s:get_val(key, val) " {{{
  " default 値付きの値取得.
  " b: があったらそれ, なければ g: をみる.
  return get(b:, a:key, get(g:, a:key, a:val))
endfunction " }}}

function! matchhl#enable() " {{{
  augroup vimmatchhl
    autocmd!
    autocmd CursorMoved,CursorMovedI * call s:matchhl()
  augroup END
  let s:flag_enable = 1
endfunction " }}}

function! matchhl#disable() " {{{
  augroup vimmatchhl
    autocmd!
  augroup END
  let s:flag_enable = 0
endfunction " }}}

function! matchhl#is_enabled() " {{{
  return s:flag_enable
endfunction " }}}

function! s:hi_cursol(poslist) " {{{
  if len(a:poslist) == 1
    let pos = a:poslist[0]
    exe printf('match Error /\%%%dl\%%%dc/', pos[1], pos[2])
  else
    let m = ""
    let sep = '\('
    for pos in a:poslist
      let m .= printf('%s\%%%dl\%%%dc', sep, pos[1], pos[2])
      let sep = '\|'
    endfor
    exe printf('match Error /%s\)/', m)
  endif
endfunction " }}}

function! s:pos2str(pos) " {{{
  return printf("%d-%d", a:pos[1], a:pos[2])
endfunction " }}}

function! s:matchhl() " {{{
  let mode = mode()
  if mode != 'n' && mode != 'i'
    return
  endif

  let hpos = getpos(".")
  if foldclosed(hpos[1]) != -1
    return
  endif

  let line = getline(".")
  let char = line[hpos[2]-1]
redraw | echo printf("''=%s, '.=%s, '^=%s", string(getpos("''")), string(getpos("'.")), string(getpos("'^")))
  if char =~# '[{}()\[\]]'
    keepjumps normal! %
    let pos1 = getpos(".")
    keepjumps normal! %
    let pos2 = getpos(".")
    if pos2 == hpos
      call s:hi_cursol([pos1, pos2])
    else
      call s:hi_cursol([pos1])
      call setpos(".", hpos)
    endif
  elseif s:get_val('matchhl_use_mapping', 0)
    let dict = {}
    " @vimlint(EVL102, 1, l:_)
    for _ in range(100)
      normal %
      "call keepmatchit#do('', 1, 'n')
      let pos = getpos(".")
      let key = s:pos2str(pos)
      if has_key(dict, key)
        break
      endif
      let dict[key] = pos
    endfor

    if len(dict) == 1 || !has_key(dict, s:pos2str(hpos))
      match NONE
    else
      call s:hi_cursol(values(dict))
    endif
    call setpos(".", hpos)
  else
    match NONE
  endif
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker cms=\ "\ %s:
