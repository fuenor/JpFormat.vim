
" let jpfmt_paragraph_regexp = '' かつ、ぶら下げを行わない整形を行う
" Vimデフォルトのgqコマンドに日本語禁則処理を付け加えただけのように振る舞う。

let s:cpo_save = &cpo
set cpo&vim

function! jpcpt#formatexpr()
  return s:lib.formatexpr()
  if exists('b:JpCountOverChars')
    let JpCountOverChars = b:JpCountOverChars
  endif
  let b:JpCountOverChars = 0
  let jpfmt_paragraph_regexp = g:jpfmt_paragraph_regexp
  let g:jpfmt_paragraph_regexp = ''
  let res = s:lib.formatexpr()
  let g:jpfmt_paragraph_regexp = jpfmt_paragraph_regexp
  if exists('b:JpCountOverChars')
    let b:JpCountOverChars = JpCountOverChars
  endif
  return res
endfunction

function! jpcpt#import()
  return s:lib
endfunction

let s:lib = {}
let s:org = jpfmt#import()
call extend(s:lib, s:org)

" finish
" let &cpo = s:cpo_save

" let jpfmt_paragraph_regexp = '' の場合速度的に有利
function! s:lib.format_lines(lnum, count)
  let lnum = a:lnum
  let prev_lines = line('$')
  let jpfmt_compat = self.get_opt('jpfmt_compat')
  if jpfmt_compat == 1
    let leader2 = self.get_2ndleader(lnum)
  elseif jpfmt_compat > 1
    let fo_2 = self.get_second_line_leader(getline(lnum, lnum + a:count - 1))
    let leader2 = fo_2
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
      let [glist, addmarker]  = JpFormatStr([line], 0, leader2)
      let g:JpFormatCountMode = s:JpFormatCountMode
      let b:JpCountChars      = s:JpCountChars
      if len(glist) <= 1
        break
      endif
      let idx = 0
      let llen = strlen(leader2)
      for i in range(len(glist)-1)
        let line1 = glist[i]
        let line2 = glist[i+1]
        let line2 = substitute(line2[llen: ], '^\s*', '', '')
        " 分割位置が日本語の行までJpFormatの整形を使用
        if line1 =~ '[^[:print:]]$' || line2 =~ '^[^[:print:]]'
          let idx += 1
        else
          break
        endif
      endfor
      if idx == 0
      elseif idx == len(glist)-1
        call append(lnum, glist)
        silent! execute printf('silent %ddelete _ %d', lnum, 1)
        break
      else
        let col = strlen(join(glist[: idx-1]))-llen*(idx-1)
        let line2 = strpart(line, col)
        let line2 = substitute(line2, '^\s*', '', '')
        call append(lnum, leader2.line2)
        call append(lnum, glist[: idx-1])
        silent! execute printf('silent %ddelete _ %d', lnum, 1)
        let lnum += idx
        let fo_2 = -1
        continue
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

let &cpo = s:cpo_save

