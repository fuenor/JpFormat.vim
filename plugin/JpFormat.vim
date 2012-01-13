"=============================================================================
"    Description: 日本語文書整形プラグイン
"     Maintainer: <fuenor@gmail.com>
"                 http://sites.google.com/site/fudist/Home/jpformat
"=============================================================================
scriptencoding utf-8
let s:Version = 1.19

if exists('disable_JpFormat') && disable_JpFormat
  finish
endif
if exists('g:JpFormat_version') && g:JpFormat_version < s:Version
  let g:loaded_JpFormat = 0
endif
if exists("g:loaded_JpFormat") && g:loaded_JpFormat && !exists('fudist')
  finish
endif
let g:JpFormat_version = s:Version
let g:loaded_JpFormat = 1
if &cp
  finish
endif

" 文字数指定を半角単位にする
" 1:半角
" 2:全角
if !exists('JpFormatCountMode')
  let JpFormatCountMode = 2
endif
" 折り返し(原稿用紙縦)文字数
if !exists('JpCountChars')
  let JpCountChars = 40
endif
" 半角一文字分オーバーしても折り返し処理をする/しない
if !exists('JpFormatHankakuOver')
  let JpFormatHankakuOver = 0
endif
" 折り返し文字数(b:JpCountChars)の値はtextwidthから設定する。
" 有効な場合 g:JpCountCharsは無視される
if !exists('JpCountChars_Use_textwidth')
  let JpCountChars_Use_textwidth = 0
endif
" 原稿用紙行数
if !exists('JpCountLines')
  let JpCountLines = 17
endif
" 禁則処理の最大ぶら下がり字数
if !exists('JpCountOverChars')
  let JpCountOverChars = 1
endif
" 原稿用紙換算計算時に削除するルビ等の正規表現
if !exists('JpCountDeleteReg')
  let JpCountDeleteReg = '\[.\{-}\]\|<.\{-}>\|《.\{-}》\|［.\{-}］\|｜'
endif

" 連結マーカー
if !exists('JpFormatMarker')
  let JpFormatMarker = "\t"
endif
" 整形コマンドを使用したら自動整形もON
if !exists('JpAutoFormat')
  let JpAutoFormat = 1
endif
" カーソル移動ごとに整形
if !exists('JpFormatCursorMovedI')
  let JpFormatCursorMovedI = 0
endif
" カーソル移動ごとに整形する時の行頭から<BS>の挙動
" 1なら文字削除、0なら移動のみ。
" set backspaceで<BS>がインデントや改行を削除できるように
" 設定している場合のみ関係する。
if !exists('JpFormatCursorMovedI_BS')
  let JpFormatCursorMovedI_BS = 1
endif
" 挿入モードへ移行したら自動連結
"  1 : カーソル位置以降を自動連結
"  2 : パラグラフを自動連結
if !exists('JpAutoJoin')
  let JpAutoJoin = 1
endif

" JpFormatGqMode = 0 のときインデントを有効にする
" JpFormatGqMode = 0 のときインデントを有効にする
" 0 : インデント等を使用しないで整形
" 1 : インデント等を内部整形で対応
" 2 : インデント等をJpFormat_iformatexprで処理
if !exists('JpFormatIndent')
  let JpFormatIndent = 1
endif
" 整形にgqコマンドを呼び出し
if !exists('JpFormatGqMode')
  let JpFormatGqMode = 0
endif
if !exists('JpFormat_formatexpr')
  " let JpFormat_formatexpr = 'jpfmt#formatexpr()'
  let JpFormat_formatexpr = ''
endif
if !exists('JpFormat_iformatexpr')
  let g:JpFormat_iformatexpr = ''
endif

" 基本的な処理方法
" 1. まず指定文字数に行を分割
" 2. 次行の行頭禁則文字を現在行へ移動
" 3. 現在行の行末禁則文字を次行へ移動
" 4. ぶら下がり文字数を超えてぶら下がっていたら追い出し
"
" 行頭禁則
if !exists('JpKinsoku')
  let JpKinsoku = '-!?}>－ｰ～！？゛゜ゝゞ）］｡｣､･ﾞﾟヽヾーァィゥェォッャュョヮヵヶぁぃぅぇぉっゃゅょゎ々‐・:;.°￠′″‰℃、。，．,)\]｝〕〉》」』】〟’”≫―…‥'
  if &enc == 'utf-8'
    let JpKinsoku .= 'ゕゖㇰㇱㇳㇲㇳㇴㇵㇶㇷㇸㇹㇺㇻㇼㇽㇾㇿ〻゠–〜¢ℓ㏋‼⁇⁈⁉〙〗｠»—〳〴〵'
  endif
  let JpKinsoku = '['.JpKinsoku.']'
endif
" 行末禁則
if !exists('JpKinsokuE')
  let JpKinsokuE = '-_0-9a-zA-Z([{<（｛〔〈《「『【〝‘“'
  if &enc == 'utf-8'
    let JpKinsokuE .= '〘〖｟«'
  endif
  let JpKinsokuE = '['.JpKinsokuE.']'
endif
" 句点と閉じ括弧
if !exists('JpKutenParen')
  let JpKutenParen = '、。，．,)\]｝〕〉》」』】〟’”'
  if &enc == 'utf-8'
    let JpKutenParen .= '〙〗｠»'
  endif
  let JpKutenParen = '['.JpKutenParen.']'
endif
" 句点と閉じ括弧＋分離不可文字追い出し用
" 分離不可文字を追い出す時にJpNoDivNがあったら、そこから追い出し。
" ですか？――<分割> のような行があったら ？は残して――のみを追い出す。
if !exists('JpNoDivN')
  let JpNoDivN = '、。，．,)\]｝〕〉》」』】〟’”!?！？'
  if &enc == 'utf-8'
    let JpNoDivN .= '〙〗｠»‼⁇⁈⁉'
  endif
  let JpNoDivN = '['.JpNoDivN.']'
endif
" 分離不可
if !exists('JpNoDiv')
  let JpNoDiv = '―…‥'
  if &enc == 'utf-8'
    let JpNoDiv .= '—'
  endif
  let JpNoDiv = '['.JpNoDiv.']'
endif
" 分離不可
if !exists('JpNoDivPair')
  let JpNoDivPair = ''
  if &enc == 'utf-8'
    let JpNoDivPair .= '〳〴〵'
  endif
  let JpNoDivPair = '['.JpNoDivPair.']'
endif
" 追い出し用
" ぶら下がり文字数を超えている時、JpKinsokuO以外の1文字を足して追い出す。
" 未設定時にはJpKinsokuで代用される。
if !exists('JpKinsokuO')
  " let JpKinsokuO = '-!?}>－ｰ～！？゛゜ゝゞ）］｡｣､･ﾞﾟヽヾーァィゥェォッャュョヮヵヶぁぃぅぇぉっゃゅょゎ々‐・:;.°￠′″‰℃、。，．,)\]｝〕〉》」』】〟’”≫―…‥'
  " if &enc == 'utf-8'
  "   let JpKinsokuO .= 'ゕゖㇰㇱㇳㇲㇳㇴㇵㇶㇷㇸㇹㇺㇻㇼㇽㇾㇿ〻゠–〜¢ℓ㏋‼⁇⁈⁉〙〗｠»—〳〴〵'
  " endif
  " let JpKinsokuO = '['.JpKinsokuO.']'
endif

" 整形対象外行の正規表現
if !exists('JpFormatExclude')
  let JpFormatExclude = ''
endif
" 整形対象外行の正規表現()
if !exists('JpFormatExclude_div')
  let JpFormatExclude_div = '^$'
endif

" 連結マーカー非使用時のEOLキャラクター
if !exists('JpJoinEOL')
  let JpJoinEOL = '[。」！？］]'
endif
" 連結マーカー非使用時のTOLキャラクター
if !exists('JpJoinTOL')
  let JpJoinTOL = '[\s　「・＊]'
endif

" Jコマンド代替
if (!exists('JpAltJ') || JpAltJ) && JpFormatMarker != ''
  nnoremap <silent> J :<C-u>JpAltJ<CR>
  vnoremap <silent> J :call JpAltJ()<CR>
endif

" C-v代替
if (!exists('JpAltCv') || JpAltCv)
  nnoremap <silent> <expr> <C-v> JpAltCv()
endif
" gq実行時にJpFormatをオフにする
" if (exists('JpAltgq') && JpAltgq) || (!exists('JpAltgq') && has('Kaoriya') && !exists('plugin_format_disable'))
if (exists('JpAltgq') && JpAltgq)
  " nnoremap <silent> <expr> gq JpFormat_cmd("gq")
endif

" DELコマンド代替
if (exists('JpAltDEL') && JpAltDEL) && JpFormatMarker != '' && JpFormatCursorMovedI
  inoremap <silent> <expr> <DEL> "<C-r>=JpAltDEL()<CR>"
endif

function! JpFormatChk()
  return (!exists('b:jpformat') || b:jpformat == 0 || g:JpFormatMarker != '')
endfunction

" <C-v>コマンド代替
command! -range JpAltCv call JpAltCv(<line1>, <line2>)
function! JpAltCv(...)
  if exists('b:jpformat')
    let b:jpformat = b:jpformat == 0 ? 0 : -1
  endif
  return "\<C-v>"
endfunction

" コマンド実行時にJpFormatをオフにする代替コマンド
function! JpFormat_cmd(cmd)
  let b:jpformat = 0
  return a:cmd
endfunction

" DELコマンド代替
function! JpAltDEL(...)
  if !exists('b:jpformat')
    return "\<Del>"
  endif
  if b:jpformat <= 0 || g:JpFormatMarker == '' || g:JpFormatCursorMovedI == 0
    return "\<Del>"
  endif
  let str = getline('.')
  let start = col('.')-1
  if strpart(str, start) != g:JpFormatMarker
    return "\<Del>"
  endif
  let l = line('.')+1
  let str = getline(l)
  let s = len(matchstr(str, '^.\{1}'))
  let str = strpart(str, s)
  call setline(l, str)
  return ''
endfunction

" 原稿用紙換算
command! -bang -range=% -nargs=* JpCountPages call JpCountPages(<line1>, <line2>, <bang>0, <f-args>)
" 指定範囲と指定範囲最終行を含むパラグラフを整形
" 範囲未指定時は現在行から整形
command! -bang -range -nargs=* JpFormat call JpFormat(<line1>, <line2>, <bang>0, <f-args>)
" パラグラフをフォーマット
command! -bang -range JpFormatP call JpFormatP(<line1>, <line2>, <bang>0)
" 全文整形
command! -bang -range=% -nargs=* JpFormatAll call JpFormatAll(<line1>, <line2>, <bang>0, <f-args>)
" 指定範囲のパラグラフを連結
command! -bang -range JpJoin call JpJoin(<line1>, <line2>, <bang>0)
" 全文連結
command! -bang -range=% JpJoinAll call JpJoinAll(<line1>, <line2>, <bang>0)
" 現在行を連結してからヤンク
command! -bang -range JpYank call JpYank(<line1>, <line2>, <bang>0)
" 自動整形をトグル
command! -count JpFormatToggle call JpFormatToggle()
" gqモードをトグル
command! JpFormatGqToggle call JpFormatGqToggle()

function! JpFormatToggle()
  if count > 0
    let b:JpCountChars = count
    echo 'JpFormat : Chars = '.b:JpCountChars
    return
  endif
  let b:jpformat = !b:jpformat
  echo 'JpFormat : '. (b:jpformat ? 'ON' : 'OFF')
endfunction

function! JpFormatGqToggle()
  let b:JpFormatGqMode = !b:JpFormatGqMode
  echo 'JpFormat : '. (b:JpFormatGqMode ? '(gq)' : '(normal)')
endfunction

augroup JpFormat_
  au!
  " 挿入モードから抜けると自動整形
  au InsertEnter        * call JpFormatEnter()
  au InsertLeave        * call JpFormatLeave()
  au VimEnter           * call JpFormatInit()
  au BufNew,BufWinEnter * call JpFormatInit()
  au BufNewFile,BufRead * call JpFormatInit()
  au CursorMovedI       * call JpFormatCursorMovedI_()
augroup END

if JpKinsoku == ''
  let JpKinsoku = '[]'
endif
if JpKinsokuE == ''
  let JpKinsokuE = '[]'
endif
if JpFormatExclude == ''
  let JpFormatExclude = '^$'
endif
if JpJoinEOL == ''
  let JpJoinEOL = '[]'
endif
if JpJoinTOL == ''
  let JpJoinTOL = '[]'
endif

let s:debug = 0
if exists('g:fudist')
  let s:debug = g:fudist
endif

if JpAutoJoin == 3
  silent! nnoremap <silent> i i<C-g>u
  silent! nnoremap <silent> I I<C-g>u
  silent! nnoremap <silent> a a<C-g>u
endif

function! JpFormatInit()
  if !exists('b:jpformat')
    let b:jpformat = 0
  endif
  if !exists('b:JpFormatExclude')
    let b:JpFormatExclude = g:JpFormatExclude
  endif
  if b:JpFormatExclude == ''
    let b:JpFormatExclude = '^$'
  endif
  if !exists('b:JpCountChars')
    let b:JpCountChars = g:JpCountChars
    if g:JpCountChars_Use_textwidth
      let b:JpCountChars = &textwidth/g:JpFormatCountMode
    endif
  endif
  if !exists('b:JpCountLines')
    let b:JpCountLines = g:JpCountLines
  endif
  if !exists('b:JpCountOverChars')
    let b:JpCountOverChars = g:JpCountOverChars
  endif
  if !exists('b:jpf_sline')
    let b:jpf_sline = line('.')
    let b:jpf_modified = &modified
    let b:jpf_prevtime = localtime()
    let b:jpf_prevstr = []
    let b:jpf_pline = line('.')
    let b:jpf_pcol  = col('.')
    let b:jpf_pmarker = getline(b:jpf_pline-1) =~ g:JpFormatMarker."$"
    if g:JpFormatMarker == ''
      let b:jpf_pmarker = 0
    endif
  endif
  if !exists('b:JpFormatGqMode')
    let b:JpFormatGqMode = g:JpFormatGqMode
  endif
endfunction

function! JpFormatCursorMovedI_()
  if !exists('b:jpformat')
    let b:jpformat=0
  endif
  if g:JpFormatCursorMovedI == 0 || b:jpformat <= 0 || g:JpFormatMarker == ''
    return
  endif
  if exists('*JpFormatCursorMovedI')
    call JpFormatCursorMovedI()
    return
  endif
  let altch = b:jpf_pmarker && line('.') == b:jpf_pline - 1 && b:jpf_pcol == 1 && col('.') != col('$')
  if (exists('JpAltBS') && JpAltBS==0)
    let altch = 0
  endif
  if altch
    call feedkeys("\<C-h>", 'n')
    if g:JpFormatCursorMovedI_BS
      call feedkeys("\<C-h>", 'n')
    endif
  elseif b:JpFormatGqMode
    call JpFormatGq(line('.'), line('.'), 0)
  else
    if getline('.') =~ '^\s\+' && g:JpFormatIndent == 2
      let saved_fex=g:JpFormat_formatexpr
      let g:JpFormat_formatexpr = 'jpcpt#formatexpr()'
      if g:JpFormat_iformatexpr != ''
        let g:JpFormat_formatexpr = g:JpFormat_iformatexpr
      endif
      call JpFormatGq(line('.'), line('.'), 0)
      let g:JpFormat_formatexpr=saved_fex
    else
      call JpFormat(line('.'), line('.'), 0)
    endif
  endif
  let b:jpf_pline = line('.')
  let b:jpf_pcol  = col('.')
  let b:jpf_pmarker = getline(b:jpf_pline-1) =~ g:JpFormatMarker."$"
  if g:JpFormatMarker == ''
    let b:jpf_pmarker = 0
  endif
endfunction

silent! function JpFormatEnter()
  if !exists('b:jpformat')
    let b:jpformat = 0
  endif
  if g:JpCountChars_Use_textwidth
    let b:JpCountChars = &textwidth/g:JpFormatCountMode
  endif
  let b:jpf_saved_tw=&textwidth
  let b:jpf_saved_bs=&backspace
  if b:jpformat < 1
    return
  endif
  setlocal textwidth=0
  if g:JpFormatCursorMovedI
    setlocal backspace=indent,eol,start
  endif
  let b:jpf_sline = line('.')
  let fline = line('.')
  let lline = line('.')
  let b:jpf_pline = line('.')
  let b:jpf_pcol  = col('.')
  let b:jpf_pmarker = getline(b:jpf_pline-1) =~ g:JpFormatMarker."$"
  if g:JpFormatMarker == ''
    let b:jpf_pmarker = 0
  endif
  let lines = 1
  let l:JpAutoJoin = g:JpAutoJoin
  if g:JpFormatCursorMovedI && b:JpFormatGqMode == 0
    let l:JpAutoJoin = 0
  endif
  if l:JpAutoJoin
    let b:jpf_modified = &modified
    let b:jpf_prevtime = localtime()
    if b:jpf_modified == 0
      let b:jpf_prevstr = getline(1, line('$'))
    endif
  endif
  if b:jpformat > 0
    if l:JpAutoJoin == 1 || l:JpAutoJoin == 3
      if g:JpFormatCursorMovedI
        "
      elseif b:JpFormatGqMode
        call JpJoinGq(fline, lline, 0)
      else
        let lines = JpJoinExec(fline, lline)
      endif
    elseif l:JpAutoJoin == 2
      if b:JpFormatGqMode
        call JpJoinGq(fline, lline, 0)
      else
        call JpJoin(fline, lline)
        let b:jpf_sline = line('.')
      endif
    endif
  endif
endfunction

silent! function JpFormatLeave()
  if !exists('b:jpformat')
    let b:jpformat = 0
  endif
  if b:jpformat <= 0
    silent! exec 'setlocal textwidth='.b:jpf_saved_tw
    silent! exec 'setlocal backspace='.b:jpf_saved_bs
    if b:jpformat <= -1
      let b:jpformat = 1
    endif
    return
  endif
  if b:jpformat > 0
    call JpFormatInsertLeave()
  endif
  let l:JpAutoJoin = g:JpAutoJoin
  if l:JpAutoJoin
    if b:jpf_modified == 0 && b:jpf_prevstr == getline(1, line('$'))
      let save_cursor = getpos(".")
      let ptime = localtime()
      let utime = localtime() - b:jpf_prevtime + 1
      silent! exec 'earlier '.utime.'s'
      for i in range(20)
        if b:jpf_prevstr == getline(1, line('$'))
          break
        endif
        silent! exec 'redo'
      endfor
      call setpos('.', save_cursor)
    endif
  endif
  silent! exec 'setlocal textwidth='.b:jpf_saved_tw
  silent! exec 'setlocal backspace='.b:jpf_saved_bs
endfunction

" 指定範囲以降を整形
function! JpFormat(fline, lline, mode, ...)
  if g:JpCountChars_Use_textwidth
    let b:JpCountChars = &textwidth/g:JpFormatCountMode
  endif
  if a:0 >= 1
    let b:JpCountChars = a:1
  endif
  if a:0 >= 2
    let b:JpCountLines = a:2
  endif
  if a:0 == 3
    let b:JpCountOverChars = a:3
  endif
  let exclude = b:JpFormatExclude
  if a:mode
    let b:JpFormatExclude = '^$'
  endif
  if b:JpFormatGqMode
    call JpFormatGq(a:fline, a:lline, 0)
  else
    call JpFormatExec(a:fline, a:lline)
  endif
  let b:JpFormatExclude = exclude
endfunction

" 全文整形
function! JpFormatAll(fline, lline, mode, ...)
  if g:JpCountChars_Use_textwidth
    let b:JpCountChars = &textwidth/g:JpFormatCountMode
  endif
  let start = reltime()
  let fline = a:fline
  let lline = a:lline
  let cline = line('.')
  let ccol = col('.')
  let crlen = strlen(g:JpFormatMarker)
  let crlen += &ff=='dos' ? 2 : 1
  let elen = line2byte(cline) + ccol - 1
  let saved_JpCountChars     = b:JpCountChars
  let saved_JpCountLines     = b:JpCountLines
  let saved_JpCountOverChars = b:JpCountOverChars
  if a:0 >= 1
    let b:JpCountChars = a:1
  endif
  if a:0 >= 2
    let b:JpCountLines = a:2
  endif
  if a:0 == 3
    let b:JpCountOverChars = a:3
  endif
  if b:JpFormatGqMode
    " redraw|echo 'JpFormat(gq) : Restore to its original state...'
    " call JpJoin(1, line('$'))
    redraw|echo 'JpFormat(gq) : Formatting...'
    call JpFormatGq(fline, lline, 1)
    if a:mode
     " " マーカーを削除
     " for n in range(fline, lline)
     "   let str = substitute(getline(n), g:JpFormatMarker.'$', '', '')
     "   call setline(n, [str])
     " endfor
    endif
    let lines = line('$')
    let pages = lines/b:JpCountLines + (lines % b:JpCountLines > 0)
    let dmsg = !s:debug ? '' : ' | ('.reltimestr(reltime(start)).' sec )'
    redraw| echom printf("[Easy mode] %d pages (%dx%d) : %d(%d) lines %s", pages, b:JpCountChars, b:JpCountLines, lines, lines % b:JpCountLines, dmsg)
    return
  endif
  echo 'JpFormat : Restore to its original state...'

  let [glist, lines, delmarker] = JpJoinStr(fline, lline, 'marker')
  let clidx = 0
  if fline <= cline && lline >= cline
    let clidx = cline - fline - delmarker
  endif

  let marker = g:JpFormatMarker
  if a:mode
    let g:JpFormatMarker = ''
    let crlen = &ff=='dos' ? 2 : 1
  endif
  redraw| echo 'JpFormat : Formatting...'
  let b:jpformat = g:JpAutoFormat
  let cfline = search('[^'.g:JpFormatMarker.']$', 'ncbW') + 1
  if cfline < fline
    let cfline = fline
  endif
  if fline <= cline && lline >= cline
    let cstr = join(getline(cfline, cline-1)).strpart(getline(cline), 0, ccol-1)
    let cstr = substitute(cstr, '\s\+', '', 'g').matchstr(cstr, '\s\+$')
  endif
  let [glist, cmarker] = JpFormatStr(glist, clidx)
  if fline <= cline && lline >= cline
    let elen = s:InsertPointgq(glist[cmarker :], cstr)
  elseif lline < cline
    let elen += strlen(join(glist)) - strlen(join(getline(fline, lline)))
  endif
  let g:JpFormatMarker = marker

  let lines = len(glist)
  let pages = lines/b:JpCountLines + (lines % b:JpCountLines > 0)
  let dmsg = !s:debug ? '' : ' | ('.reltimestr(reltime(start)).' sec )'
  redraw| echom printf("[Easy mode] %d pages (%dx%d) : %d(%d) lines %s", pages, b:JpCountChars, b:JpCountLines, lines, lines % b:JpCountLines, dmsg)
  " let b:JpCountChars     = saved_JpCountChars
  " let b:JpCountLines     = saved_JpCountLines
  " let b:JpCountOverChars = saved_JpCountOverChars
  if glist == getline(fline, lline)
    return 0
  endif

  call s:setline(glist, fline, lline)
  if fline <= cline && lline >= cline
    let elen += line2byte(cmarker+fline)
  endif
  exec elen.'go'
endfunction

" パラグラフをフォーマット
function! JpFormatP(fline, lline, mode)
  if b:jpformat == 0
    return
  endif
  if g:JpCountChars_Use_textwidth
    let b:JpCountChars = &textwidth/g:JpFormatCountMode
  endif
  let save_cursor = getpos(".")
  let fline = a:fline
  let lline = a:lline
  let pattern = '^$\|[^'.g:JpFormatMarker.']$'
  if g:JpFormatMarker == ''
    let pattern = '^$'
  endif
  let exclude = b:JpFormatExclude
  if a:mode
    let b:JpFormatExclude = '^$'
  endif
  call cursor(fline, 1)
  let fline = search(pattern, 'ncbW') + 1
  call cursor(lline, 1)
  let lline = search(pattern, 'ncW')
  let lline = lline == 0 ? line('$') : lline
  call setpos('.', save_cursor)
  if b:JpFormatGqMode
    call JpFormatGq(fline, lline, 1)
  else
    call JpFormatExec(fline, lline)
  endif
  let b:JpFormatExclude = exclude
endfunction

function! JpJoinAll(fline, lline, ...)
  let mode = ''
  if b:JpFormatGqMode
    let mode = '(gq)'
  endif
  redraw|echo 'JpJoin'.mode.' : Processing...'
  let start = reltime()
  call JpJoin(a:fline, a:lline)
  redraw|echo 'JpJoin'.mode.' : Done. ('. reltimestr(reltime(start)) . ' sec )'
endfunction

" 指定範囲のパラグラフを連結
function! JpJoin(fline, lline, ...)
  let save_cursor = getpos(".")
  let fline = a:fline
  let lline = a:lline
  let saved_marker = g:JpFormatMarker
  if a:0 && a:1 == 1
  let g:JpFormatMarker = ''
  endif
  let pattern = '^$\|[^'.g:JpFormatMarker.']$'
  if g:JpFormatMarker == ''
    let pattern = '^$'
  endif
  call cursor(fline, 1)
  let fline = search(pattern, 'ncbW') + 1
  let fline = fline == 0 ? 1 : fline
  call cursor(lline, 1)
  let lline = search(pattern, 'ncW')
  let lline = lline == 0 ? line('$') : lline
  call setpos('.', save_cursor)
  if b:JpFormatGqMode
    call JpJoinGq(fline, lline, 1)
  else
    call JpJoinExec(fline, lline)
  endif
  let g:JpFormatMarker = saved_marker
endfunction

" 現在行のパラグラフをヤンク
function! JpYank(fline, lline, ...)
  let save_cursor = getpos(".")
  let fline = a:fline
  let lline = a:lline
  let pattern = '^$\|[^'.g:JpFormatMarker.']$'
  if g:JpFormatMarker == ''
    let pattern = '^$'
  endif
  call cursor(fline, 1)
  let fline = search(pattern, 'ncbW') + 1
  let fline = fline == 0 ? 1 : fline
  call cursor(lline, 1)
  let lline = search(pattern, 'ncW')
  let lline = lline == 0 ? line('$') : lline
  call setpos('.', save_cursor)
  exec fline.','.lline.'yank'
endfunction

function! s:setline(glist, fline, lline)
  let nlist = []
  let loop = len(a:glist)
  for i in range(loop)
    call add(nlist, " ")
  endfor
  call cursor(a:lline, col('.'))
  silent! exec 'silent! '.'put=nlist'
  call setline(a:lline+1, a:glist)
  let cmd = 'silent! '.a:fline.','. a:lline . 'delete _'
  silent! exec cmd
endfunction

" 指定範囲を整形
function! JpFormatExec(fline, lline)
  let start = reltime()

  let fline = a:fline
  let lline = a:lline
  let cline = line('.')

  let crlen = strlen(g:JpFormatMarker)
  let crlen += &ff=='dos' ? 2 : 1
  let elen = line2byte(cline) + col('.') - 1

  let [glist, lines, delmarker] = JpJoinStr(fline, lline)
  let elen = elen - delmarker
  let clidx = elen - line2byte(fline)
  let lline = fline + lines - 1

  let b:jpformat = g:JpAutoFormat
  let cstr = strpart(join(glist), 0, clidx)
  let cstr = substitute(cstr, '\s\+', '', 'g').matchstr(cstr, '\s\+$')
  let [glist, cline] = JpFormatStr(glist, cline)
  let elen = s:InsertPointgq(glist, cstr) + line2byte(fline)
  if glist == getline(fline, lline)
    return 0
  endif

  call s:setline(glist, fline, lline)
  exec elen.'go'
  return (lline - fline + 1)
endfunction

" 指定範囲を連結
function! JpJoinExec(fline, lline)
  let start = reltime()
  let fline = a:fline
  let lline = a:lline

  let crlen = strlen(g:JpFormatMarker)
  let crlen += &ff=='dos' ? 2 : 1
  let elen = line2byte(line('.'))+col('.')-1

  let [glist, lines, delmarker] = JpJoinStr(fline, lline)
  let elen -= delmarker
  let lline = fline + lines - 1

  if glist == getline(fline, lline)
    return 0
  endif

  call s:setline(glist, fline, lline)
  exec elen.'go'
  return (lline-fline+1)
endfunction

" リストを連結
function! JpJoinStr(fline, lline, ...)
  let fline = a:fline
  let lline = a:lline
  let cline = line('.')
  let clidx = cline - fline
  let delmarker = 0
  let delindent = 0

  let eol = g:JpJoinEOL.'$'
  let tol = '^'.g:JpJoinTOL
  let loop = lline - fline + 1
  let idx = 0
  let lines = 0
  let glist = []
  let catpattern = g:JpFormatMarker.'$'
  while loop - lines > 0
    call add(glist, getline(fline+lines))
    let indent = matchstr(getline(fline+lines), '^\s*')
    if g:JpFormatIndent == 0
      let indent = ''
    endif

    " 最後に連結記号が有ったら強制連結
    while glist[idx] =~ catpattern
      if g:JpFormatMarker == '' || glist[idx] =~ b:JpFormatExclude
        break
      endif
      let glist[idx] = substitute(glist[idx], catpattern, '' , '')
      let lines = lines + 1
      let str = getline(fline+lines)
      if indent != ''
        if fline+lines <= cline
          let delindent += strlen(matchstr(str, '^\s*'))
        endif
        let str = substitute(str, '^\s*', '', '')
      endif
      let glist[idx] = glist[idx] . str
      if lines <= clidx
        let delmarker += 1
      endif
      if fline+lines >= line('$')
        break
      endif
    endwhile
    while g:JpFormatMarker == ''
      if fline+lines == line('$') || glist[idx] == ''
        break
      endif
      if glist[idx] =~ b:JpFormatExclude
        break
      endif
      if glist[idx] =~ eol
        break
      endif
      let nstr = getline(fline+lines+1)
      if nstr == '' || nstr =~ tol || nstr =~ b:JpFormatExclude
        break
      endif
      let glist[idx] = glist[idx] . nstr
      let lines = lines + 1
    endwhile
    let lines = lines + 1
    let idx = idx + 1
  endwhile
  let crlen = strlen(g:JpFormatMarker)
  let crlen += &ff=='dos' ? 2 : 1
  let lline = fline + lines - 1
  let ofs = a:0 ? delmarker : delindent + delmarker * crlen
  return [glist, lines, ofs]
endfunction

" リストを整形
function! JpFormatStr(str, clidx, ...)
  let clidx = a:clidx
  let fstr = []
  let idx = 0
  let JpKinsoku  = '^'.g:JpKinsoku.'\+'
  let JpKinsokuO = g:JpKinsoku.'\+$'
  if exists('g:JpKinsokuO')
    let JpKinsokuO = g:JpKinsokuO.'\+$'
  endif
  let JpKinsokuS = g:JpKinsoku.'\+$'
  let JpKinsokuE = g:JpKinsokuE.'\+$'
  let JpNoDiv = g:JpNoDiv.'\+$'
  let JpNoDivPair = g:JpNoDivPair.'\+$'
  let JpNoDivL = '^'.g:JpNoDiv.'\+'
  let JpNoDivN = g:JpNoDivN.g:JpNoDiv.'\{2}$'
  let cmode = g:JpFormatCountMode
  " let hankakuover = g:JpFormatHankakuOver*(cmode-1)
  " let chars  = (b:JpCountChars)*cmode-hankakuover
  let chars  = (b:JpCountChars)*cmode
  let ochars = (b:JpCountOverChars)*cmode
  let catmarker = a:0 ? '' : g:JpFormatMarker
  let addcr = 0
  let crlen = &ff=='dos' ? 2 : 1
  if chars <= 0
    return [a:str, 0]
  endif
  let defchars = (b:JpCountChars)*cmode
  for l in range(len(a:str))
    let addline = l < clidx ? 1 : 0
    let lstr = a:str[l]
    if lstr == '' || lstr =~ b:JpFormatExclude
      let addcr += addline
      call add(fstr, lstr)
      continue
    endif
    let leader  = a:0 ? '' : matchstr(lstr, '^\s*')
    let sleader = a:0 ? '' : leader
    if g:JpFormatIndent == 0
      let leader = ''
      let sleader = ''
    endif
    if leader != ''
      let col = strlen(leader)
      let lstr = lstr[col :]
    endif
    while 1
      let chars = defchars
      if leader != ''
        let col = strlen(leader)
        let chars -= col
        if chars < 1
          let chars = 1
        endif
      endif
      let str = substitute(lstr, '\%>'.chars.'v.*','','')
      if !g:JpFormatHankakuOver && str != '[[:print:]]$'
        let str = substitute(lstr, '\%>'.(chars-1).'v.*','','')
      endif
      let lstr = strpart(lstr, strlen(str))
      if lstr == ''
        let addcr += addline
        call add(fstr, leader.str)
        break
      endif
      " strの行末禁則文字を全て次行へ移動
      if str =~ JpKinsokuE
        let ostr = matchstr(str, JpKinsokuE)
        let str = strpart(str, 0, strlen(str)-strlen(ostr))
        let lstr = ostr.lstr
        if str != ''
          let str = str . catmarker
          let addcr += addline
          call add(fstr, leader.str)
          continue
        endif
      endif

      " lstrの行頭禁則文字を全て現在行へ移動
      if lstr =~ JpKinsoku
        let ostr = matchstr(str, '.\{1}$').matchstr(lstr, JpKinsoku)
        " 句点関係があったらそこまで
        if ostr =~ g:JpKutenParen
          let ostr = strpart(ostr, 0, matchend(ostr, g:JpKutenParen.'\+'))
        endif
        let ostr = strpart(ostr, strlen(matchstr(str, '.\{1}$')))
        let str = str.ostr
        let lstr = strpart(lstr, strlen(ostr))
      endif

      " ---------- 禁則処理のメインループ ----------
      " 行末の分離不可文字の追い出し
      if str =~ JpNoDivN
        let ostr = matchstr(str, '.\{2}$')
        let str = strpart(str, 0, strlen(str)-strlen(ostr))
        let lstr = ostr.lstr
      endif
      let slen = strlen(str)

      " 追い出し処理
      let outstr = 1

      " 分離不可文字は境界で2文字単位で追い出し
      if ochars > 0
        let div = 0
        if g:JpNoDiv != '' && str =~ JpNoDiv
          let dchar = matchstr(str, '.$')
          if lstr =~ '^'.dchar && strlen(substitute(matchstr(str, dchar.'\+$'), '.', '.', 'g')) % 2
            let str .= dchar
            let lstr = substitute(lstr, '^.', '', '')
            let div = 1
          endif
        elseif g:JpNoDivPair != '' && str =~ g:JpNoDivPair.'$'
          if lstr =~ '^'.g:JpNoDivPair && strlen(substitute(matchstr(str, g:JpNoDivPair.'\+$'), '.', '.', 'g')) % 2
            let str .= matchstr(lstr, '^.')
            let lstr = substitute(lstr, '^.', '', '')
            let div = 1
          endif
        endif
        if div
          " lstrの行頭禁則文字を全て現在行へ移動
          if lstr =~ JpKinsoku
            let ostr = matchstr(str, '.\{1}$').matchstr(lstr, JpKinsoku)
            " 句点関係があったらそこまで
            if ostr =~ g:JpKutenParen
              let ostr = strpart(ostr, 0, matchend(ostr, g:JpKutenParen.'\+'))
            endif
            let ostr = strpart(ostr, strlen(matchstr(str, '.\{1}$')))
            let str = str.ostr
            let lstr = strpart(lstr, strlen(ostr))
          endif
        endif
      endif

      " ぶら下がり文字数を超えている時、JpKinsokuO以外の1文字を足して追い出す。
      if outstr && ochars >= 0
        if substitute(str, '\%>'.(chars+ochars).'v.*','','') != str
          let ostr = matchstr(str, JpKinsokuO)
          let str = strpart(str, 0, strlen(str)-strlen(ostr))
          let ostr = matchstr(str, '.\{1}$').ostr
          let str = strpart(str, 0, strlen(str)-strlen(matchstr(str, '.\{1}$')))
          let lstr = ostr.lstr
          " 行末禁則文字を全て次行へ移動
          if str =~ JpKinsokuE
            let ostr = matchstr(str, JpKinsokuE)
            let str = strpart(str, 0, strlen(str)-strlen(ostr))
            let lstr = ostr.lstr
          endif
        endif
      endif
      " ---------- ここまでが禁則処理のメインループ ----------
      if str == ''
        let str = substitute(lstr, '\%>'.chars.'v.*','','')
        let lstr = strpart(lstr, strlen(str))
      endif
      if lstr != ''
        let str = str . catmarker
      endif
      let addcr += addline
      call add(fstr, leader.str)
      if strlen(lstr) == ''
        break
      endif
      let leader = sleader
    endwhile
  endfor
  return [fstr, addcr]
endfunction

" 挿入モード後に自動整形
silent! function JpFormatInsertLeave()
  if b:jpformat == 0
    return
  endif
  if exists('*JpFormatInsert')
    call JpFormatInsert()
    return
  endif
  let fline = line('.')
  let lline = line('.')
  if fline > b:jpf_sline
    let fline = b:jpf_sline
  endif
  if lline < b:jpf_sline
    let lline = b:jpf_sline
  endif

  if b:JpFormatGqMode
    call JpFormatGq(line('.'), lline, 0)
  elseif g:JpFormatCursorMovedI == 0 && g:JpFormatIndent == 2
    let saved_fex=g:JpFormat_formatexpr
    let g:JpFormat_formatexpr = 'jpfmt#formatexpr()'
    if g:JpFormat_iformatexpr != ''
      let g:JpFormat_formatexpr = g:JpFormat_iformatexpr
    endif
    call JpFormatGq(line('.'), lline, 0)
    let g:JpFormat_formatexpr=saved_fex
  else
    let cline = JpFormatExec(fline, lline)
  endif
endfunction

" 原稿用紙換算
function! JpCountPages(fline, lline, mode, ...)
  if g:JpCountChars_Use_textwidth
    let b:JpCountChars = &textwidth/g:JpFormatCountMode
  endif
  if a:0 == 1 && a:1 =~ 'easy'
    if JpSetAutoFormat('check')
      let lines = line('$')
      let pages = lines/b:JpCountLines + (lines % b:JpCountLines > 0)
      redraw| echom printf("[Easy mode] %d pages (%dx%d) : %d(%d) lines", pages, b:JpCountChars, b:JpCountLines, lines, lines % b:JpCountLines)
    else
      JpCountPages
    endif
    return
  endif
  let start = reltime()
  let fline = a:fline
  let lline = a:lline
  let saved_jpformat         = b:jpformat
  let saved_JpCountChars     = b:JpCountChars
  let saved_JpCountLines     = b:JpCountLines
  let saved_JpCountOverChars = b:JpCountOverChars
  if a:0 >= 1 && a:1 =~ '^[0-9]\+$'
    let b:JpCountChars = a:1
  endif
  if a:0 >= 2 && a:2 =~ '^[0-9]\+$'
    let b:JpCountLines = a:2
  endif
  if a:0 == 3 && a:3 =~ '^[0-9]\+$'
    let b:JpCountOverChars = a:3
  endif

  echo 'JpCount : Restore to its original state...'
  let [glist, lines, delmarker] = JpJoinStr(fline, lline)
  let wc0 = 0
  for str in glist
    let wc0 += strlen(substitute(str, '.', 'x', 'g'))
  endfor
  if g:JpCountDeleteReg != ''
    for l in range(len(glist))
      let glist[l] = substitute(glist[l], g:JpCountDeleteReg, '', 'g')
    endfor
  endif
  let wc = 0
  for str in glist
    let wc += strlen(substitute(str, '.', 'x', 'g'))
  endfor
  redraw|echo 'JpCount : Formatting...'
  let b:jpformat = g:JpAutoFormat
  let [glist, cline] = JpFormatStr(glist, 0)

  let lines = len(glist)
  let pages = lines/b:JpCountLines + (lines % b:JpCountLines > 0)
  let dmsg = !s:debug ? '' : ' | ('.reltimestr(reltime(start)).' sec )'
  redraw| echom printf("%d pages (%dx%d) : %d(%d) lines : %d/%d chars %s", pages, b:JpCountChars, b:JpCountLines, lines, lines % b:JpCountLines, wc, wc0, dmsg)
  let b:JpCountChars     = saved_JpCountChars
  let b:JpCountLines     = saved_JpCountLines
  let b:JpCountOverChars = saved_JpCountOverChars
  let b:jpformat         = saved_jpformat
  if a:mode == 0 || glist == getline(fline, lline)
    return
  endif

  call s:setline(glist, fline, lline)
  call cursor(fline, 1)
endfunction

" J コマンド代替
command! -count JpAltJ call JpAltJ()
function! JpAltJ() range
  let cnt = count
  let fline = a:firstline
  let lline = a:lastline
  if count
    let lline = lline + count - 1
  endif
  if fline != lline
    let cnt = lline-fline+1
  endif
  if exists('b:jpformat') && b:jpformat == 1 && g:JpFormatMarker != ''
    let save_cursor = getpos(".")
    let l:JpFormatExclude = b:JpFormatExclude
    let glist = getline(fline, lline)
    let lines = lline - fline - 1
    let lines = lines > 0 ? lines : 0
    for i in range(0, lines)
      if glist[i] != l:JpFormatExclude
        let glist[i] = substitute(glist[i], g:JpFormatMarker.'$', '', '')
      endif
    endfor
    call setline(fline, glist)
    call setpos('.', save_cursor)
  endif
  exe 'normal! '.cnt.'J'
endfunction

" マーカーが存在するなら自動整形をON
" au BufRead *.txt call JpSetAutoFormat()
function! JpSetAutoFormat(...)
  call JpFormatInit()

  let save_cursor = getpos(".")
  call cursor(1, 1)
  let sl = search(g:JpFormatMarker."$", 'cW')
  while 1
    if sl == 0
      break
    endif
    if getline('.') !~ b:JpFormatExclude
      break
    endif
    let sl = search(g:JpFormatMarker."$", 'W')
  endwhile
  call setpos('.', save_cursor)
  if a:0 == 0
    let b:jpformat = sl != 0 ? 1 : 0
  endif
  return sl
endfunction

"=============================================================================
"  Description: gqを使用したJpFormat形式の整形
"=============================================================================
command! -bang -range JpFormatGq call JpFormatGq(<line1>, <line2>, <bang>0)
function!  JpFormatGq(fline, lline, mode, ...)
  call JpFormatGqPre()

  let b:jpformat = 1
  let b:jpf_saved_tw=&textwidth
  let b:jpf_saved_fex=&formatexpr
  if g:JpCountChars_Use_textwidth
    let b:JpCountChars = &textwidth/g:JpFormatCountMode
  endif

  let cmode = g:JpFormatCountMode
  let chars = (b:JpCountChars)*cmode
  silent! exec 'setlocal textwidth='.chars

  if g:JpFormat_formatexpr != ''
    silent! exec 'setlocal formatexpr='.g:JpFormat_formatexpr
  endif

  let mode = a:mode
  let fline = a:fline
  let lines = a:lline-a:fline+1

  if a:0
    let chars = strlen(join(getline(a:fline, a:lline)))
    silent! exec 'setlocal textwidth='.chars
  endif

  let s:InsertPoint = -1
  let lnum = line('.')
  let col  = col('.')
  let nline = fline
  while nline <= line('$') && lines > 0
    call cursor(nline, 1)
    let l = nline
    let [nline, lines, lnum] = s:JpFormatGqExec(mode, lines, lnum, col)
  endwhile
  if s:InsertPoint > -1
    exec s:InsertPoint.'go'
  endif
  silent! exec 'setlocal formatexpr='.b:jpf_saved_fex
  silent! exec 'setlocal textwidth='.b:jpf_saved_tw
  call JpFormatGqPost()
endfunction

if !exists('g:jpfmt_paragraph_regexp')
  let g:jpfmt_paragraph_regexp = '^[　「]'
endif
if !exists('*JpFormatGqPre')
function! JpFormatGqPre(...)
  let s:jpfmt_paragraph_regexp = g:jpfmt_paragraph_regexp
  let g:jpfmt_paragraph_regexp = '^$'
endfunction
endif
if !exists('*JpFormatGqPost')
function! JpFormatGqPost(...)
  let g:jpfmt_paragraph_regexp = s:jpfmt_paragraph_regexp
endfunction
endif

function! s:JpFormatGqExec(mode, lines, lnum, col)
  let mode  = a:mode
  let lines = a:lines
  let lnum  = a:lnum
  let col   = a:col

  let cline = line('.')
  let elen = line2byte(cline) + col - 1

  let fline = cline
  let lline = cline
  if g:JpFormatMarker != ''
    if getline(lline) =~ g:JpFormatMarker.'$'
      let lline = search('[^'.g:JpFormatMarker.']$\|^$', 'ncW')
      if lline == 0
        let lline = line('$')
      endif
    endif
    " paragraph
    if mode
      let ff = search('[^'.g:JpFormatMarker.']$\|^$', 'ncbW')
      if ff == 0
        let fline = 1
      elseif fline > ff
        let fline = ff+1
      endif
    endif
  endif
  let lines -= (lline-fline)+1

  let l = lline - fline + 1
  call cursor(fline, 1)

  " 整形後のカーソル位置を得る
  let cpoint = 0
  if fline <= lnum && lline >= lnum
    let cpoint = 1
    let glist = getline(fline, lnum)
    let glist[-1] = strpart(glist[-1], 0, col-1)
    let cstr = join(glist)
    let cstr = substitute(cstr, '\s\+', '', 'g').matchstr(cstr, '\s\+$')
  endif

  " マーカーを削除
  if g:JpFormatMarker != ""
    for n in range(fline, lline)
      let str = substitute(getline(n), g:JpFormatMarker.'$', '', '')
      call setline(n, [str])
    endfor
  endif

  exec 'normal! '.l.'gqq'
  if fline < lnum && lline < lnum
    let lnum += line('.')-lline
  endif
  let eline = line('.')
  let nline = eline+1

  " マーカーを付加
  if eline > fline && g:JpFormatMarker != ""
    for n in range(fline, eline-1)
      let str = getline(n)
      if str !~ '^$'
        let str = str . g:JpFormatMarker
      endif
      call setline(n, [str])
    endfor
  endif

  if cpoint && s:InsertPoint == -1
    let gstr = getline(fline, eline)
    let elen = line2byte(fline)
    let s:InsertPoint = s:InsertPointgq(gstr, cstr) + elen
  endif

  return [nline, lines, lnum]
endfunction

function! s:InsertPointgq(glist, cstr)
  let glist = a:glist
  let maker = g:JpFormatMarker
  let crlen = strlen(g:JpFormatMarker)
  let crlen += &ff=='dos' ? 2 : 1

  let cstr = a:cstr
  let cspc = matchstr(cstr, '\s\+$')

  let pstr = ''
  let idx = 0
  let cidx = strlen(substitute(cstr, '.', '.', 'g'))-strlen(cspc)
  for str in glist
    let len = strlen(substitute(substitute(str, '\s', '', 'g'), '.', '.', 'g'))
    if len < cidx
      let pstr .= str
      let idx += strlen(str)+crlen-1
      let cidx -= len
      continue
    elseif cidx == -1
      let idx += strlen(matchstr(str, '^\s*'))-1
      break
    else
      let rest = strlen(matchstr(str, '^\(\s*.\)\{'.cidx.'}'))
      if stridx(str, strpart(str, 0, rest) . cspc) >= 0
        let idx += rest + strlen(cspc)
        let pstr .= matchstr(str, rest + strlen(cspc))
        break
      endif
      let idx += strlen(str)+crlen
      let cidx = -1
    endif
  endfor
  return idx
endfunction

function! JpJoinGq(fline, lline, mode)
  call JpFormatGq(a:fline, a:lline, a:mode, 'join')
endfunction

"=============================================================================
"    Description: 外部ビューア呼び出し
"     Maintainer: fuenor@gmail.com
"                 http://sites.google.com/site/fudist/Home/extviewer
"  Last Modified: 2009-11-08 18:00
"        Version: 1.00
"=============================================================================
if exists("loaded_ExtViewer") && !exists('fudist')
  finish
endif
if exists('disable_ExtViewer') && disable_ExtViewer
  finish
endif
let loaded_ExtViewer = 1
if &cp
  finish
endif

if !exists('g:ExtViewer_cmd')
  let ExtViewer_cmd = '!start "'.$windir.'/notepad.exe" "%f"'
  " let ExtViewer_cmd = '!start "C:/Program Files/Mozilla firefox/firefox.exe" file://%f'
  " let ExtViewer_cmd = '!start "C:/Program Files/Internet Explorer/iexplore.exe" file://%f'
  if has('unix')
    let ExtViewer_cmd = "call system('evince %f &')"
  endif
endif

" JpFormatを使用した連結を行う
if !exists('EV_JoinStr')
  let EV_JoinStr = 1
endif
" ビューア一ページあたりの行数
if !exists('EV_CountLines')
  let EV_CountLines = 16
endif

" JpFormat.vimを使用している時にマーカーを削除する
if !exists('EV_RemoveMarker')
  let EV_RemoveMarker = 0
endif
" Windows?
let s:MSWindows = has('win95') + has('win16') + has('win32') + has('win64')
let s:tmpname = tempname()

" 外部ビューア起動
command! -nargs=* -range=% -bang ExtViewer call ExtViewer(<bang>0, <line1>, <line2>, <f-args>)
command! -nargs=* -range=% -bang JpExtViewer call ExtViewer(<bang>0, <line1>, <line2>, 'txt')
function! ExtViewer(mode, fline, lline, ...)
  let fline = a:fline
  let lline = a:lline
  let file = ''
  let line = 0
  let suffix = ''

  if a:0
    let suffix = a:1
  endif
  if suffix == ''
    let suffix = expand("%:e")
  endif
  if suffix == 'howm' || suffix == 'nvl'
    let suffix = expand("txt")
  endif
  if a:mode == 0
    if exists('g:EV_Tempname_'.suffix)
      exec 'let s:tmpname = '. 'g:'.'EV_Tempname_'.suffix
    endif
    let s:tmpname = fnamemodify(s:tmpname, ":r") .'.'.suffix
    let file = s:tmpname
  else
    let file = expand('%:p')
  endif
  if line == 0
    let line = line('.')
    if fline != 1 || lline != line('$')
      let line = 1
    endif
  endif
  let file = expand(file)
  let file = substitute(file, '\\', '/', 'g')

  if a:mode == 0
    if exists('*EVwrite_'.suffix)
      exec 'let line = EVwrite_'.suffix.'("'.file.'", '.fline.', '. lline.')'
    else
      let line = EVwrite_template(file, fline, lline)
    endif
  endif
  call EVAddTempFileList(file)
  if suffix =~ 'html\|htm'
    let file = substitute(file, ' ', '%20', 'g')
  elseif has('unix')
    let file = escape(file, ' ')
  endif
  let cmd = g:ExtViewer_cmd
  if exists('g:ExtViewer_'.suffix)
    exec 'let cmd = g:ExtViewer_'.suffix
  endif
  let cmd = substitute(cmd, '%f', escape(file, '\\'), 'g')
  let cmd = substitute(cmd, '%l', escape(line, '\\'), 'g')
  if s:MSWindows
    let cmd = iconv(cmd, &enc, 'cp932')
  endif
  let cmd = escape(cmd, '%#')
  silent! exec cmd
endfunction

" 外部ビューアに渡すファイルを出力(template)
function! EVwrite_template(file, fline, lline)
  let line = line('.')
  let glist = getline(a:fline, a:lline)
  let cnvCR = &fileformat == 'dos'
  let toFenc = &fileencoding
  " fencと改行を元ファイルと同一にする。
  let loop = len(glist)
  for i in range(loop)
    let glist[i] = iconv(glist[i], &enc, toFenc)
    if cnvCR
      let glist[i] = substitute(glist[i], '$', '\r', '')
    endif
  endfor
  call writefile(glist, a:file, 'b')
  return line
endfunction

" 外部ビューアに渡すファイルを出力
function! EVwrite_txt(file, fline, lline)
  let suffix = 'txt'
  let removeMarker = g:EV_RemoveMarker
  if !exists('g:JpFormatMarker') || g:JpFormatMarker == ''
    let removeMarker = 0
    let catmarker=''
  else
    let catmarker = g:JpFormatMarker.'$'
  endif
  let cnvCR = &ff == 'dos'
  let toFenc = &fenc

  if exists('g:EV_toFenc_'.suffix)
    exec 'let toFenc = g:EV_toFenc_'.suffix
  endif
  let line = line('.')

  if g:EV_JoinStr && exists('b:jpformat')
    let [glist, lines, delmarker] = JpJoinStr(a:fline, a:lline, 'marker')
    let line -= delmarker
    let removeMarker = 0
    let catmarker=''
  else
    let glist = getline(a:fline, a:lline)
  endif
  let loop = len(glist)
  for i in range(loop)
    let glist[i] = iconv(glist[i], &enc, toFenc)
    if removeMarker && glist[i] != b:JpFormatExclude
      let glist[i] = substitute(glist[i], catmarker, '', '')
    endif
    if cnvCR
      let glist[i] = substitute(glist[i], '$', '\r', '')
    endif
  endfor
  call writefile(glist, a:file, 'b')
  return line
endfunction

command! -count EVJumpPage silent! exec 'normal! '.((count-1)*g:EV_CountLines).'gg'

augroup ExtViewer
  au!
  au VimLeave * call s:EVLeave()
augroup END

let s:flist = []
function! EVAddTempFileList(file)
  if count(s:flist, a:file) > 0
    return
  endif
  call add(s:flist, a:file)
endfunction

function! s:EVLeave()
  for fname in s:flist
    call delete(fname)
  endfor
endfunction

