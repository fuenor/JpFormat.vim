
" let jpfmt_paragraph_regexp = '' かつ、ぶら下げを行わない整形を行う
" Vimデフォルトのgqコマンドに日本語禁則処理を付け加えただけのように振る舞う。

let s:cpo_save = &cpo
set cpo&vim

function! jpdef#formatexpr()
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

function! jpdef#import()
  return s:lib
endfunction

let s:lib = {}
let s:org = jpfmt#import()
call extend(s:lib, s:org)

let &cpo = s:cpo_save
