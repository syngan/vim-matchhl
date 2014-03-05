scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim


function! s:get_val(key, val) " {{{
  " default $BCMIU$-$NCM<hF@(B.
  " b: $B$,$"$C$?$i$=$l(B, $B$J$1$l$P(B g: $B$r$_$k(B.
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
  let grp = s:get_val('matchhl_group', 'Error')
  let pri = s:get_val('matchhl_priority', 10)
  if !exists('b:matchhl_matchid')
    let b:matchhl_matchid = []
  endif
  for pos in a:poslist
    let pat = printf('\%%%dl\%%%dc', pos[1], pos[2])
    let b:matchhl_matchid += [matchadd(grp, pat, pri)]
  endfor
endfunction " }}}

function! s:hl_clear() " {{{
  if exists('b:matchhl_matchid')
    for id in b:matchhl_matchid
      call matchdelete(id)
    endfor
    unlet b:matchhl_matchid
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
"redraw | echo printf("''=%s, '.=%s, '^=%s", string(getpos("''")), string(getpos("'.")), string(getpos("'^")))
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
      call s:hl_clear()
    else
      call s:hi_cursol(values(dict))
    endif
    call setpos(".", hpos)
  else
    call s:hl_clear()
  endif
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker cms=\ "\ %s:
