" Maintainer:   <fuenor@gmail.com>
" Description:  日本語gqコマンドスクリプト Version. 1.03
"               日本語の禁則処理に対応した整形処理を行います。
"
" Caution:      !!!!!!!! 動作にはJpFormat.vimが必要です !!!!!!!!
"                 https://sites.google.com/site/fudist/Home/jpformat
"
" Install:
"               formatexprを設定すると通常のgqコマンドとして使用できます。
"                 set formatexpr=jpfmt#formatexpr()
"
"               以下をVimの設定ファイルへ追加するとgqとJpFormat.vimで整形処理
"               に使用されます。
"                 set formatexpr=jpfmt#formatexpr()
"                 let JpFormatGqMode      = 1
"
"               JpFormatでのみ使用する場合はJpFormat_formatexprを設定します。
"                 let JpFormatGqMode      = 1
"                 let JpFormat_formatexpr = 'jpfmt#formatexpr()'
"
" Option:       日本語文書への対応として行頭の 　(全角スペース) か 「 で始まっ
"               た場合は段落開始とみなして処理を行います。
"               段落開始行は jpfmt_paragraph_regexp に正規表現を設定して指定可
"               能です。
"               不要な場合は '' を指定してください。
"                 let jpfmt_paragraph_regexp = '^[　「]'
"
"               現在のカーソル行から次の段落行までを整形させることもできます。
"               gqpなどにマップして使用すると便利かもしれません。
"                 nnoremap <silent> gqp :<C-u>call jpfmt#gqp()<CR>
"
"               日本語の禁則処理にはJpFormat.vimがそのまま使用されているので、
"               JpFormat.vimのオプションが有効です。
"
let s:cpo_save = &cpo
set cpo&vim

" === compat.vim

if exists('*strdisplaywidth')
  let s:strdisplaywidth = function('strdisplaywidth')
else
  function s:strdisplaywidth(str, ...)
    let vcol = get(a:000, 0, 0)
    let w = 0
    for c in split(a:str, '\zs')
      if c == "\t"
        let w += &tabstop - ((vcol + w) % &tabstop)
      elseif c =~ '^.\%2v'  " single-width char
        let w += 1
      elseif c =~ '^.\%3v'  " double-width char or ctrl-code (^X)
        let w += 2
      elseif c =~ '^.\%5v'  " <XX>    (^X with :set display=uhex)
        let w += 4
      elseif c =~ '^.\%7v'  " <XXXX>  (e.g. U+FEFF)
        let w += 6
      endif
    endfor
    return w
  endfunction
endif

let s:lib = {}

function s:lib.format_insert_mode(char)
  " @warning char can be "" when completion is used
  " @return a:char for debug

  let self.textwidth = self.comp_textwidth(0)

  let lnum = line('.')
  let col = col('.') - 1
  let vcol = (virtcol('.') - 1) + s:strdisplaywidth(a:char)
  let line = getline(lnum)

  if self.textwidth == 0
        \ || vcol <= self.textwidth
        \ || (!self.has_format_options('t') && !self.has_format_options('c'))
        \ || (!self.has_format_options('t') && self.has_format_options('c')
        \     && !self.is_comment(line))
    return a:char
  endif

  " split line at the cursor and insert v:char temporarily
  let [line, rest] = [line[: col - 1] . a:char, line[col :]]
  call setline(lnum, line)

  let lnum += self.format_lines(lnum, 1)

  " remove v:char and restore actual line
  let line = getline(lnum)
  let col = len(line) - len(a:char)
  if a:char != ""
    let line = substitute(line, '.$', '', '')
  endif
  call setline(lnum, line . rest)
  call cursor(lnum, col + 1)

  return a:char
endfunction

" vim/src/options.c
" Return TRUE if format option 'x' is in effect.
" Take care of no formatting when 'paste' is set.
function s:lib.has_format_options(x)
  if &paste
    return 0
  endif
  return stridx(&formatoptions, a:x) != -1
endfunction

function s:lib.is_comment(line)
  let com_str = self.parse_leader(a:line)[1]
  return com_str != ""
endfunction

function s:lib.parse_leader(line)
  "  +-------- indent
  "  | +------ com_str
  "  | | +---- mindent
  "  | | |   + text
  "  v v v   v
  " |  /*    xxx|
  "
  " @return [indent, com_str, mindent, text, com_flags]

  if a:line =~# '^\s*$'
    return [a:line, "", "", "", ""]
  endif
  let middle = []
  for [flags, str] in self.parse_opt_comments(&comments)
    let mx = printf('\v^(\s*)(\V%s\v)(\s%s|$)(.*)$', escape(str, '\'),
          \ (flags =~# 'b') ? '+' : '*')
    " If we found a middle match previously, use that match when this is
    " not a middle or end. */
    if !empty(middle) && flags !~# '[me]'
      break
    endif
    if a:line =~# mx
      let res = matchlist(a:line, mx)[1:4] + [flags]
      " We have found a match, stop searching unless this is a middle
      " comment. The middle comment can be a substring of the end
      " comment in which case it's better to return the length of the
      " end comment and its flags.  Thus we keep searching with middle
      " and end matches and use an end match if it matches better.
      if flags =~# 'm'
        let middle = res
        continue
      elseif flags =~# 'e'
        if !empty(middle) && strchars(res[1]) <= strchars(middle[1])
          let res = middle
        endif
      elseif flags =~# 'n'
        " nested comment
        while 1
          let [indent, com_str, mindent, text, com_flags] = self.parse_leader(res[3])
          if com_flags !~# 'n'
            break
          endif
          let res = [res[0], res[1] . res[2] . com_str, mindent, text, res[4]]
        endwhile
      endif
      return res
    endif
  endfor
  if !empty(middle)
    return middle
  endif
  return matchlist(a:line, '\v^(\s*)()()(.*)$')[1:4] + [""]
endfunction

function s:lib.parse_opt_comments(comments)
  " @param  comments  'comments' option
  " @return           [[flags, str], ...]

  let res = []
  for com in split(a:comments, '[^\\]\zs,')
    let [flags; _] = split(com, ':', 1)
    " str can contain ':' and ','
    let str = join(_, ':')
    let str = substitute(str, '\\,', ',', 'g')
    call add(res, [flags, str])
  endfor
  return res
endfunction

function s:lib.retab(line, ...)
  let col = get(a:000, 0, 0)
  let expandtab = get(a:000, 1, &expandtab)
  let tabstop = get(a:000, 2, &tabstop)
  let s2 = matchstr(a:line, '^\s*', col)
  if s2 == ''
    return a:line
  endif
  let s1 = strpart(a:line, 0, col)
  let t = strpart(a:line, col + len(s2))
  let n1 = s:strdisplaywidth(s1)
  let n2 = s:strdisplaywidth(s2, n1)
  if expandtab
    let s2 = repeat(' ', n2)
  else
    if n1 != 0 && n2 >= (tabstop - (n1 % tabstop))
      let n2 += n1 % tabstop
    endif
    let s2 = repeat("\t", n2 / tabstop) . repeat(' ', n2 % tabstop)
  endif
  return s1 . s2 . t
endfunction

function s:lib.get_opt(name)
  return  get(w:, a:name,
        \ get(t:, a:name,
        \ get(b:, a:name,
        \ get(g:, a:name,
        \ get(self, a:name)))))
endfunction

" vim/src/edit.c
" Find out textwidth to be used for formatting:
"	if 'textwidth' option is set, use it
"	else if 'wrapmargin' option is set, use W_WIDTH(curwin) - 'wrapmargin'
"	if invalid value, use 0.
"	Set default to window width (maximum 79) for "gq" operator.
" @param ff   force formatting (for "gq" command)
function s:lib.comp_textwidth(ff)
  let textwidth = &textwidth

  if textwidth == 0 && &wrapmargin
    " The width is the window width minus 'wrapmargin' minus all the
    " things that add to the margin.
    let textwidth = winwidth(0) - &wrapmargin

    if self.is_cmdwin()
      let textwidth -= 1
    endif

    if has('folding')
      let textwidth -= &foldcolumn
    endif

    if has('signs')
      if self.has_sign() || has('netbeans_enabled')
        let textwidth -= 1
      endif
    endif

    if &number || &relativenumber
      let textwidth -= 8
    endif
  endif

  if textwidth < 0
    let textwidth = 0
  endif

  if a:ff && textwidth == 0
    let textwidth = winwidth(0) - 1
    if textwidth > 79
      let textwidth = 79
    endif
  endif

  return textwidth
endfunction

" FIXME: How to detect command-line window?
function s:lib.is_cmdwin()

  " workaround1
  "return bufname('%') == '[Command Line]'

  " workaround2
  " MEMO: In formatexpr, exception is not raised without setting 'debug'.
  let debug_save = &debug
  set debug=throw
  try
    execute winnr() . "wincmd w"
    " or
    "execute "tabnext " . tabpagenr()
  catch /^Vim\%((\a\+)\)\=:E11:/
    " Vim(wincmd):E11: Invalid in command-line window; <CR> executes, CTRL-C quits: 2wincmd w
    " Vim(tabnext):E11: Invalid in command-line window; <CR> executes, CTRL-C quits: tabnext 1
    return 1
  finally
    let &debug = debug_save
  endtry
  return 0

endfunction

" FIXME: This may break another :redir session?
" It is useful if vim provide builtin function for this.
function s:lib.has_sign()
  redir => s
  execute printf('silent sign place buffer=%d', bufnr('%'))
  redir END
  let lines = split(s, '\n')
  " When no sign, lines == ['--- Signs ---']
  return len(lines) > 1
endfunction

" === jpfmt.vim

" let s:autofmt = autofmt#compat#import()
" let s:autofmt = autofmt#japanese#import()
" let s:lib = {}
" call extend(s:lib, s:autofmt)

let s:lib.jpfmt_paragraph        = 1
let s:lib.jpfmt_paragraph_regexp = '^[　「]'
function! s:lib.formatexpr()
  if mode() =~# '[iR]' && self.has_format_options('a')
    " When 'formatoptions' have "a" flag (paragraph formatting), it is
    " impossible to format using User Function.  Paragraph is concatenated to
    " one line before this function is invoked and cursor is placed at end of
    " line.
    return 1
  elseif mode() !~# '[niR]' || (mode() =~# '[iR]' && v:count != 1) || v:char =~# '\s'
    echohl ErrorMsg
    echomsg "Assert(formatexpr): Unknown State: " mode() v:lnum v:count string(v:char)
    echohl None
    return 1
  endif
  if mode() == 'n'
    " Modify start
    let jpfmt_paragraph = self.get_opt('jpfmt_paragraph')
    if jpfmt_paragraph
      call self.jpformat_normal_mode(v:lnum, v:count)
      return 0
    endif
    " Modify end
    call self.format_normal_mode(v:lnum, v:count)
  else
    call self.format_insert_mode(v:char)
  endif
  return 0
endfunction

function! s:lib.jpformat_normal_mode(lnum, count)
  let self.textwidth = self.comp_textwidth(1)
  if self.textwidth == 0
    return
  endif

  let offset = 0
  let para = self.get_vim_paragraph(a:lnum, a:lnum + a:count - 1)
  for [i, lines] in para
    let lnum = a:lnum + i + offset
    " call setline(lnum, self.retab(getline(lnum)))
    let offset += self.format_lines(lnum, len(lines))
  endfor

  " The cursor is left on the first non-blank of the last formatted line.
  let lnum = a:lnum + (a:count - 1) + offset
  silent! execute printf('keepjumps normal! %dG', lnum)
endfunction

let s:lib.jpfmt_compat = 1
" 0 : built-in formatexr
" 1 : JpFormat.vim + built-in formatexr
" 2 : JpFormat.vim + autofmt.vim
" 3 : autofmt.vim
function! s:lib.format_lines(lnum, count)
  let lnum = a:lnum
  let prev_lines = line('$')
  let jpfmt_compat = self.get_opt('jpfmt_compat')
  if jpfmt_compat > 1
    let fo_2 = self.get_second_line_leader(getline(lnum, lnum + a:count - 1))
  endif
  let lines = getline(lnum, lnum + a:count - 1)
  let tw = strdisplaywidth(join(lines))
  let l = self.vimformatexpr(lnum, a:count, tw)
  let tw = self.textwidth
  if jpfmt_compat == 0
    let l = self.vimformatexpr(lnum, 1, tw)
    return line('$') - prev_lines
  endif
  while 1
    let line = getline(lnum)
    let compat = jpfmt_compat
    if compat == 1 && !(line =~ '[^[:print:]]')
      let l = self.vimformatexpr(lnum, 1, tw)
      break
    endif
    if compat != 3 && strdisplaywidth(matchstr(line, '^\s*[^[:space:]]')) < self.textwidth-1
      let s:JpFormatCountMode = g:JpFormatCountMode
      let g:JpFormatCountMode = 1
      let s:JpCountChars      = exists('b:JpCountChars') ? b:JpCountChars : g:JpCountChars
      let b:JpCountChars      = self.textwidth
      if !exists('b:JpCountOverChars')
        let b:JpCountOverChars = g:JpCountOverChars
      endif
      let [glist, addmarker]  = JpFormatStr([line], 0, '')
      let g:JpFormatCountMode = s:JpFormatCountMode
      let b:JpCountChars      = s:JpCountChars
      if len(glist) <= 1
        break
      endif
      let line1 = glist[0]
      let col = strlen(line1)
      let line2 = strpart(line, col)
      let line2 = substitute(line2, '^\s*', '', '')
      " 分割位置が日本語の時だけJpFormatの整形を使用
      if line1 =~ '[^[:print:]]$' || line2 =~ '^[^[:print:]]'
        call setline(lnum, line1)
        let compat = 0
      endif
    endif
    if compat == 1
      let l = self.vimformatexpr(lnum, 1, tw)
      let line1 = getline(lnum)
      let col = l == 1 ? -1 : (strlen(getline(lnum)))
      let line2 = substitute(line[col :], '^\s*', '', '')
      if l == 1
        break
      else
        silent! execute printf('silent %ddelete _ %d', lnum + 1, l - 1)
      endif
    elseif compat >= 2
      let col = self.find_boundary(line)
      if col == -1
        break
      endif
      let line1 = substitute(line[: col - 1], '\s*$', '', '')
      let line2 = substitute(line[col :], '^\s*', '', '')
      call setline(lnum, line1)
    endif
    if jpfmt_compat == 1
      let leader = self.get_2ndleader(lnum)
    else
      if fo_2 != -1
        let leader = fo_2
      else
        let leader = self.make_leader(lnum + 1)
      endif
    endif
    call append(lnum, leader.line2)
    let lnum += 1
    let fo_2 = -1
  endwhile
  return line('$') - prev_lines
endfunction

function! s:lib.vimformatexpr(lnum, count, ...)
  let lnum = a:lnum
  let lines = line('$')
  if a:count == 0 || lnum > line('$')
    return 1
  endif
  let saved_tw  = &textwidth
  let saved_fex = &formatexpr
  let saved_fo  = &formatoptions
  call cursor(lnum, 1)
  exe 'setlocal formatexpr='
  if a:0
    exe 'setlocal textwidth='.a:1
  endif
  setlocal formatoptions+=mM
  silent! exe 'silent! normal! '.a:count.'gqq'
  exe 'setlocal textwidth='.saved_tw
  exe 'setlocal formatexpr='.saved_fex
  exe 'setlocal formatoptions='.saved_fo
  let l = line('$') - lines + 1
  return l
endfunction

function! s:lib.get_2ndleader(lnum)
  let lnum = a:lnum
  if lnum < 0 || lnum > line('$')
    return ''
  endif
  let saved_cursor = getpos(".")
  let line = getline(lnum)
  let tw = strdisplaywidth(line)
  let test = line . repeat('あ', 2)
  call setline(lnum, test)
  let l = self.vimformatexpr(lnum, 1, tw)
  call setline(lnum, line)
  let leader2 = ''
  if l > 1
    let leader2 = substitute(getline(lnum+1), 'あ\+$', '', '')
    silent! execute printf('silent %ddelete _ %d', lnum + 1, l - 1)
  endif
  call setpos('.', saved_cursor)
  return leader2
endfunction

function! s:lib.get_vim_paragraph(fline, lline)
  let fline = a:fline
  let lline = a:lline
  let sreg = self.get_opt('jpfmt_paragraph_regexp')
  let sreg = sreg == '' ? '^$' : sreg

  let glist = getline(fline, lline)
  let res = []
  let idx = 0
  let start = 0
  let pleader = self.get_2ndleader(fline)
  let pleader = pleader =~ '^\s\+$' ? ' ' : substitute(pleader, '^\s*\|\s*$', '', 'g')
  for idx in range(0, lline-fline)
    if glist[idx] == ''
      if glist[idx-1] != '' && start <= idx-1
        call add(res, [start, glist[start : idx-1]])
      endif
      let start = idx+1
      let pleader = ''
      continue
    endif

    let cleader = self.get_2ndleader(fline+idx)
    let cleader = cleader =~ '^\s\+$' ? ' ' : substitute(cleader, '^\s*\|\s*$', '', 'g')
    let write = 0

    """""" のように2nd leaderが '' だがコメント行の場合
    if cleader == '' && pleader =~ '[^[:space:]]'
      if glist[idx] =~ '^\s*\V'.escape(pleader, '\\')
        let cleader = 'パパラパー'
      endif
    endif

    if pleader != cleader
      let write = 1
    endif
    if cleader == ' ' && pleader == ''
      let pleader = cleader
      let write = 0
    endif
    if cleader == '' && pleader == ' '
      let cleader = pleader
      let write = 0
    endif

    if glist[idx] =~ sreg
      let write = 1
    endif

    if write
      if start <= idx-1
        call add(res, [start, glist[start : idx-1]])
      endif
      let start = idx
    endif
    let pleader = cleader
  endfor
  if glist[-1] != ''
    call add(res, [start, glist[start : -1]])
  endif
  return res
endfunction

function! jpfmt#formatexpr()
  return s:lib.formatexpr()
endfunction

function! jpfmt#import()
  return s:lib
endfunction

function! jpfmt#gqp(...)
  let saved_cursor = getpos(".")
  let sreg = '^$\|'.s:lib.get_opt('jpfmt_paragraph_regexp')
  let l = search(sreg, 'nW')
  let c = (l != 0 ? l : line('.')) - line('.')
  silent! exe 'silent! normal! '.c.'gqq'
  call setpos('.', saved_cursor)
endfunction

let &cpo = s:cpo_save

