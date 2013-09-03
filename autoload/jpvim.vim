" 設定にかかわらず、ぶら下げを行わない整形を行う
" その他はjpfmt.vimと同じ

scriptencoding utf-8
let s:cpo_save = &cpo
set cpo&vim

" jpvim.vimのときだけ拗音('っ'など)を禁則文字にしない
if !exists('g:jpvim_remove_youon')
  let g:jpvim_remove_youon = 0
endif
function! jpvim#formatexpr()
  if exists('b:JpCountOverChars')
    let JpCountOverChars = b:JpCountOverChars
  endif
  let b:JpCountOverChars = 0

  let s:JpKinsoku  = g:JpKinsoku
  if exists('g:JpKinsokuO')
    let s:JpKinsokuO = g:JpKinsokuO
  endif
  if g:jpvim_remove_youon
    let rmv = 'ァィゥェォッャュョヮヵヶぁぃぅぇぉっゃゅょゎ'
    if &enc == 'utf-8'
      let rmv .= 'ゕゖㇰㇱㇳㇲㇳㇴㇵㇶㇷㇸㇹㇺㇻㇼㇽㇾㇿ'
    endif
    let rmv = '['.rmv.']'
    let g:JpKinsoku = substitute(g:JpKinsoku,  rmv, '', 'g')
    if exists('g:JpKinsokuO')
      let g:JpKinsokuO = substitute(g:JpKinsokuO, rmv, '', 'g')
    endif
  endif

  let res = s:lib.formatexpr()
  if exists('b:JpCountOverChars')
    let b:JpCountOverChars = JpCountOverChars
  endif
  let g:JpKinsoku  = s:JpKinsoku
  if exists('g:JpKinsokuO')
    let g:JpKinsokuO = s:JpKinsokuO
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

