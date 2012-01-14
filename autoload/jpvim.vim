" 設定にかかわらず、ぶら下げを行わない整形を行う
" その他はjpfmt.vimと同じ

let s:cpo_save = &cpo
set cpo&vim

function! jpvim#formatexpr()
  if exists('b:JpCountOverChars')
    let JpCountOverChars = b:JpCountOverChars
  endif
  let b:JpCountOverChars = 0
  let res = s:lib.formatexpr()
  if exists('b:JpCountOverChars')
    let b:JpCountOverChars = JpCountOverChars
  endif
  return res
endfunction

function! jpvim#import()
  return s:lib
endfunction

let s:lib = {}
let s:org = jpfmt#import()
call extend(s:lib, s:org)

let &cpo = s:cpo_save

