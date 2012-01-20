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
"               設定にかかわらず「ぶら下げ」処理を行いたくない場合は
"               jpvim#formatexpr()を使用します。
"                 set formatexpr=jpvim#formatexpr()
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
scriptencoding utf-8
let s:cpo_save = &cpo
set cpo&vim

function! jpfmt#formatexpr()
  return s:lib.formatexpr()
endfunction

function! jpfmt#gqp(...)
  let saved_cursor = getpos(".")
  let sreg = '^$\|'.s:lib.get_opt('jpfmt_paragraph_regexp')
  let l = search(sreg, 'nW')
  let c = (l != 0 ? l : line('.')) - line('.')
  silent! exe 'silent! normal! '.c.'gqq'
  call setpos('.', saved_cursor)
endfunction

function! jpfmt#import()
  return s:lib
endfunction

let s:lib = {}

" === from compat.vim

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

function s:lib.comp_indent(lnum)
  if &indentexpr != ''
    if &paste
      return 0
    endif
    let v:lnum = a:lnum
    return eval(&indentexpr)
  elseif &cindent
    if &paste
      return 0
    endif
    return cindent(a:lnum)
  elseif &lisp
    if &paste
      return 0
    endif
    if !&autoindent
      return 0
    endif
    return lispindent(a:lnum)
  elseif &smartindent
    if &paste
      return 0
    endif
    return self.smartindent(a:lnum)
  elseif &autoindent
    return indent(a:lnum - 1)
  endif
  return 0
endfunction

function s:lib.smartindent(lnum)
  if &paste
    return 0
  endif
  let prev_lnum = a:lnum - 1
  while prev_lnum > 1 && getline(prev_lnum) =~ '^#'
    let prev_lnum -= 1
  endwhile
  if prev_lnum <= 1
    return 0
  endif
  let prev_line = getline(prev_lnum)
  let firstword = matchstr(prev_line, '^\s*\zs\w\+')
  let cinwords = split(&cinwords, ',')
  if prev_line =~ '{$' || index(cinwords, firstword) != -1
    let n = indent(prev_lnum) + &shiftwidth
    if &shiftround
      let n = n - (n % &shiftwidth)
    endif
    return n
  endif
  return indent(prev_lnum)
endfunction

" === jpfmt.vim

if !exists('g:jpfmt_use_autofmt')
  let g:jpfmt_use_autofmt = 0
endif
if g:jpfmt_use_autofmt
  silent! let s:autofmt = autofmt#compat#import()
  if exists('s:autofmt')
    let s:lib = {}
    call extend(s:lib, s:autofmt)
  endif
endif

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
    " let offset += self.format_lines(lnum, len(lines))
    let offset += self.format_lines(lnum, lines)
  endfor

  " The cursor is left on the first non-blank of the last formatted line.
  let lnum = a:lnum + (a:count - 1) + offset
  silent! execute printf('keepjumps normal! %dG', lnum)
endfunction

let s:lib.jpfmt_compat = 1
" 0 : built-in formatexr
" 1 : JpFormat.vim + built-in formatexr
" 2 : JpFormat.vim
" 3 : JpFormat.vim + autofmt.vim
" 4 : autofmt.vim
function! s:lib.format_lines(lnum, count)
  let lnum = a:lnum
  let prev_lines = line('$')
  let jpfmt_compat = self.get_opt('jpfmt_compat')
  if jpfmt_compat >= 3
    let fo_2 = self.get_second_line_leader(getline(lnum, lnum + a:count - 1))
  endif
  let lines = getline(lnum, lnum + a:count - 1)
  let tw = strdisplaywidth(join(lines), '')
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
    if compat != 4
      let leader2 = self.get_2ndleader(lnum)
      let s:JpFormatCountMode = g:JpFormatCountMode
      let g:JpFormatCountMode = 1
      let s:JpCountChars      = exists('b:JpCountChars') ? b:JpCountChars : g:JpCountChars
      let b:JpCountChars      = self.textwidth
      if !exists('b:JpCountOverChars')
        let b:JpCountOverChars = g:JpCountOverChars
      endif
      let [glist, subspc]  = JpFormatStr([line], 0, '', leader2)
      let g:JpFormatCountMode = s:JpFormatCountMode
      let b:JpCountChars      = s:JpCountChars
      if len(glist) <= 1
        break
      endif
      if compat == 2
        call append(lnum, glist)
        silent! execute printf('silent %ddelete _ %d', lnum, 1)
        break
      endif
      let idx = 0
      let llen = strlen(leader2)
      for i in range(1, len(glist)-1)
        let line1 = glist[i-1]
        let line2 = glist[i]
        let line2 = substitute(line2[llen :], '^\s*', '', '')
        " 分割位置が日本語の行までJpFormatの整形を使用
        if line1 =~ '[^[:print:]]$' || line2 =~ '^[^[:print:]]'
          let idx += 1
        else
          break
        endif
      endfor
      if idx == 0
        if compat == 1
          let vcount = 0
          for str in glist
            if str =~ '[^[:print:]]$'
              let vcount = 1
              break
            endif
          endfor
          if vcount == 0
            let l = self.vimformatexpr(lnum, 1, tw)
            break
          endif
        endif
      elseif idx == len(glist)-1
        call append(lnum, glist)
        silent! execute printf('silent %ddelete _ %d', lnum, 1)
        break
      else
        call append(lnum, glist[: idx-1])
        silent! execute printf('silent %ddelete _ %d', lnum, 1)
        let lnum += idx-1
        let col = strlen(join(glist[: idx-1], ''))-llen*(idx-1)
        for i in range(idx-1)
          let col += subspc[i]
        endfor
        let line2 = strpart(line, col)
        let line2 = substitute(line2, '^\s*', '', '')
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
    elseif compat >= 3
      let col = self.find_boundary(line)
      if col == -1
        break
      endif
      let line1 = substitute(line[: col - 1], '\s*$', '', '')
      let line2 = substitute(line[col :], '^\s*', '', '')
      call setline(lnum, line1)
    endif
    if jpfmt_compat >= 3
      call append(lnum, line2)
      if fo_2 != -1
        let leader = fo_2
      else
        let leader = self.make_leader(lnum + 1)
      endif
      call setline(lnum + 1, leader . line2)
    else
      if leader2 =~ '^\s*$'
        call append(lnum, line2)
        let leader = self.get_indent(lnum+1)
        call setline(lnum + 1, leader . line2)
      else
        let leader = leader2
        call append(lnum, leader.line2)
      endif
    endif
    let lnum += 1
    let fo_2 = -1
  endwhile
  return line('$') - prev_lines
endfunction

function! s:lib.is_comment(line)
  let leader = self.get_2ndleader(line('.'))
  return leader =~ '[[:graph:]]'
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
  for idx in range(0, len(glist)-1)
    if glist[idx] =~ '^\s*$'
      if glist[idx-1] !~ '^\s*$' && start <= idx-1
        " call add(res, [start, glist[start : idx-1]])
        call add(res, [start, idx - start])
      endif
      let start = idx+1
      let pleader = ''
      continue
    endif

    let cleader = self.get_2ndleader(fline+idx)
    let cleader = cleader =~ '^\s\+$' ? ' ' : substitute(cleader, '^\s*\|\s*$', '', 'g')
    let write = 0

    """""" のように2nd leaderが '' でコメント行の場合
    " gqはコメント記号のみの行を整形しない
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
        " call add(res, [start, glist[start : idx-1]])
        call add(res, [start, idx - start])
      endif
      let start = idx
    endif
    let pleader = cleader
  endfor
  if glist[-1] != ''
    " call add(res, [start, glist[start : -1]])
    call add(res, [start, len(glist)-start])
  endif
  return res
endfunction

function! s:lib.get_indent(lnum)
  let prev_line = getline(a:lnum - 1)

  let listpat = matchstr(prev_line, &formatlistpat)

  if self.has_format_options('n') && listpat != ''
    let indent = repeat(' ', s:strdisplaywidth(listpat))
  else
    let indent = repeat(' ', self.comp_indent(a:lnum))
  endif

  return indent
endfunction

let &cpo = s:cpo_save

