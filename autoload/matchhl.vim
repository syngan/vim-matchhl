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
    autocmd CursorMoved,CursorMovedI * call s:matchhl(0)
    autocmd CursorHold,CursorHoldI * call s:matchhl(1)
  augroup END
  let s:flag_enable = 1
endfunction " }}}

function! matchhl#disable() " {{{
  call s:hl_clear()
  augroup vimmatchhl
    autocmd!
  augroup END
  let s:flag_enable = 0
endfunction " }}}

function! matchhl#is_enabled() " {{{
  return s:flag_enable
endfunction " }}}

function! matchhl#hilight() " {{{
  return s:matchhl(1)
endfunction " }}}

" word=1 のときは, pos が変わることに注意
function! s:hi_cursol(poslist, word) " {{{
  let grp = s:get_val('matchhl_group', 'Error')
  let pri = s:get_val('matchhl_priority', 10)
  if !exists('b:matchhl_matchid')
    let b:matchhl_matchid = []
  endif
  for pos in a:poslist
    if a:word
      call setpos(".", [0, pos[0], pos[1], 0])
      keepjumps normal! lb
      let left = getpos(".")
      if left[2] == 1
        keepjumps normal! e
      else
        keepjumps normal! he
      endif
      let right = getpos(".")
      let pat = printf('\%%%dl\%%>%dc.\%%<%dc', pos[0], left[2]-1, right[2]+2)
    else
      let pat = printf('\%%%dl\%%%dc', pos[1], pos[2])
    endif
    call s:log("pat=" . pat)
    let b:matchhl_matchid += [matchadd(grp, pat, pri)]
  endfor
endfunction " }}}

function! s:hl_clear() " {{{
  if exists('b:matchhl_matchid')
    for id in b:matchhl_matchid
      try
        call matchdelete(id)
      catch
      endtry
    endfor
    unlet b:matchhl_matchid
  endif
endfunction " }}}

function! s:pos2str(pos) " {{{
  return printf("%d-%d", a:pos[1], a:pos[2])
endfunction " }}}

function! s:valid_attr(p) " {{{
  " see :h match-parens
  return synIDattr(synID(a:p[1], a:p[2], 0), "name") !~? 'string\|comment'
endfunction " }}}

function! s:samepos(p, q) " {{{
  return a:p[1] == a:q[1] && a:p[2] == a:q[2]
endfunction " }}}

" @vimlint(EVL103, 1, a:mes)
function! s:log(mes) " {{{
"  silent! call vimconsole#log(a:mes)
endfunction " }}}
" @vimlint(EVL103, 0, a:mes)

function! matchhl#s() " {{{
  let hpos = getpos(".")
  keepjumps normal! lb
  let line = getline(".")
  let char = line[hpos[2]-1]
  let r = s:matchit(char, hpos)
  call setpos(".", hpos)
  return r
endfunction " }}}

function! s:searchpair(start, mid, end, flag) " {{{
  return searchpairpos(a:start, a:mid, a:end, a:flag . 'nW',
	     \ 'synIDattr(synID(line("."), col("."), 0), "name") =~? "\(string\|comment\)"')
endfunction " }}}

function! s:get_startpos(pair) " {{{

  let s1 = s:searchpair(a:pair[0], '', a:pair[-1], 'b')
  keepjumps normal! l
  let s2 = s:searchpair(a:pair[0], '', a:pair[-1], 'b')
  if s1 == [0, 0]
    if s2 == [0, 0]
      return s1
    else
      return s2
    endif
  elseif s2 == [0, 0]
    return s1
  elseif s1[0] < s2[0]
    return s2
  elseif s1[0] > s2[0]
    return s1
  elseif s1[1] < s2[1]
    return s2
  else
    return s1
  endif
endfunction " }}}

function! s:get_mid(pair) " {{{
  if len(a:pair) > 3
    return '\(' . join(a:pair[1 : -2]) . '\)'
  elseif len(a:pair) == 3
    return a:pair[1]
  else
    return ''
  endif
endfunction " }}}

function! s:get_pairs(l) " {{{
  let pairs = split(a:l, ':')
  let i = 0
  while i < len(pairs)
    if pairs[i][-1] == '\'
      " merge
      let pairs[i] .= pairs[i+1]
      call remove(pairs, i+1)
    endif
    let i += 1
  endwhile

  return pairs
endfunction " }}}

function! s:chk_found(found, pos) " {{{
  for f in a:found
    if f[0] == a:pos[1] && f[1] == a:pos[2]
      return 1
    endif
  endfor
  return 0
endfunction " }}}

function! s:matchit(char, cpos) " {{{

  if !s:valid_attr(a:cpos)
    return []
  endif

  if b:match_words !~ a:char
    " 必要ない文字は skip
    return []
  endif

  let list = split(b:match_words, ",")
  for l in list
    let pairs = s:get_pairs(l)

    " note: setpos は jumplist を更新しない
    call setpos(".", a:cpos)

    " if の i の部分では前の if を返す.
    " endif の n でやると前の if を返す.
    " なんて仕様なんだ.
    let start = s:get_startpos(pairs)
    call s:log("start=" . string(start) . ":" .pairs[0] .string(a:cpos) . string(getpos(".")))

    call setpos(".", [0, start[0], start[1], 0])
    let end = s:searchpair(pairs[0], '', pairs[-1], '')
    call s:log("end=" . string(end) . string(getpos(".")))

    let mid = s:get_mid(pairs)

    let found = []
    call setpos(".", [0, start[0], start[1], 0])
    call s:log("first move: start=" . string(start) . ":" .string(getpos(".")))
    while 1
      let f = searchpairpos(pairs[0], mid, pairs[-1], 'nW',
	     \ 'synIDattr(synID(line("."), col("."), 0), "name") =~? "\(string\|comment\)"')
      if f == end
        break
      endif
      call s:log("f=" . string(f) . ":" . string(getpos(".")))
      let found = [f] + found
      call setpos(".", [0, f[0], f[1], 0])
    endwhile

    let found = [start] + found + [end]
    if s:chk_found(found, a:cpos)
      return found
    endif
  endfor

  return []
endfunction " }}}

function! s:matchhl(hold) " {{{
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
    let win = winsaveview()
    keepjumps normal! %
    let pos1 = getpos(".")
    keepjumps normal! %
    let pos2 = getpos(".")
    if pos2 == hpos
      call s:hi_cursol([pos1, pos2], 0)
    else
      call s:hi_cursol([pos1], 0)
      call setpos(".", hpos)
    endif
    call winrestview(win)
  elseif s:get_val('matchhl_use_match_words', 1) &&
        \ exists('b:match_words') && a:hold
    let win = winsaveview()
    let pair = s:matchit(char, hpos)
    if len(pair) <= 1
      call s:hl_clear()
    else
      call s:log(pair)
      call s:hi_cursol(pair, 1)
    endif

    " かならず最後にやること.
    call setpos(".", hpos)
    call winrestview(win)
  else
    call s:hl_clear()
  endif
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker cms=\ "\ %s:
