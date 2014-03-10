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

" searchpostest (for filetype=vim)
function! matchhl#searchpair(kind, f) " {{{
  if a:kind == 'if'
    let start = '\<if\>'
    let mid = '\<el\%[seif]\>'
    let end = '\<en\%[dif]\>'
  elseif a:kind == 'while' || a:kind == 'for'
    let start = '\<\(wh\%[ile]\|for\)\>'
    let mid = '\(\<brea\%[k]\>\|\<con\%[tinue]\>\)'
    let end = '\<end\(w\%[hile]\|fo\%[r]\)\>'
  else
    return [-1, -1]
  endif

  return "mb=" . string(s:searchpair(start, mid, end, 'b' . a:f))
     \ . " b=" . string(s:searchpair(start, '', end, 'b' . a:f))
     \ . "m =" . string(s:searchpair(start, 'mid', end, a:f))
     \ . "  =" . string(s:searchpair(start, '', end, a:f))
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
      call s:setpos(pos)
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

function! s:searchpair(start, mid, end, flag) " {{{
  return searchpairpos(a:start, a:mid, a:end, a:flag . 'nW',
	     \ 'synIDattr(synID(line("."), col("."), 0), "name") =~? "\(string\|comment\)"')
endfunction " }}}

function! s:compos(p, q) " {{{
  if a:p[0] < a:q[0]
    return -1
  elseif a:p[0] > a:q[0]
    return +1
  elseif a:p[1] < a:q[1]
    return -1
  elseif a:p[1] > a:q[1]
    return +1
  else
    return 0
  endif
endfunction " }}}

function! s:get_startpos(pair) " {{{

  let sp = s:searchpair(a:pair[0], '', a:pair[-1], 'bc')
  if sp == [0, 0]
    return [sp, sp]
  endif

  call s:setpos(sp)
  let sq = s:searchpair(a:pair[0], '', a:pair[-1], 'b')
  if sq == [0, 0]
    " sp = start である.
    let en = s:searchpair(a:pair[0], '', a:pair[-1], '')
    return [sp, en]
  endif

  call s:setpos(sq)
  let nx = s:searchpair(a:pair[0], '', a:pair[-1], '')
  if nx == sp
    " sp = end である
    return [sq, sp]
  endif

  " sp = start である
  call s:setpos(sp)
  let en = s:searchpair(a:pair[0], '', a:pair[-1], '')
  return [sp, en]

endfunction " }}}

function! s:setpos(s) " {{{
  return setpos(".", [0, a:s[0], a:s[1], 0])
endfunction " }}}

function! s:setposl(s) " {{{
  return setpos(".", [0, a:s[0], a:s[1]+1, 0])
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
    let [start, end] = s:get_startpos(pairs)
    call s:log("start=" . string(start) . ":" .pairs[0] .string(a:cpos) . string(getpos(".")))
    if start == [0, 0]
      continue
    endif
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
      call s:setpos(f)
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
