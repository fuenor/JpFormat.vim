"=============================================================================
"    Description: 禁則処理文字列設定 for JpFormat.vim
"                 独自に禁則文字列を設定したい場合は、このファイルを
"                 JpFormat.vimと同じ場所かruntimepathの通った場所へコピーして
"                 改変してください。
"     Maintainer: fuenor@gmail.com
"        Version: 1.02
"=============================================================================
scriptencoding utf-8

let s:cpo_save = &cpo
set cpo&vim

" 基本的な処理方法
" 1. 指定文字数に行を分割
" 2. 分割した次行の行頭禁則文字を現在行へ移動
" 3. 現在行の行末禁則文字を次行へ移動
" 4. ぶら下がり文字数を超えてぶら下がっていたら追い出し

" 行頭禁則
let JpKinsoku = '-}>）―～－ｰ］！？゛゜ゝゞ｡｣､･ﾞﾟ'
            \ . ',)\]｝、〕〉》」』】〟’”'
            \ . 'ヽヾーァィゥェォッャュョヮヵヶぁぃぅぇぉっゃゅょゎ々'
            \ . '‐'
            \ . '?!'
            \ . '・:;'
            \ . '。.'
            \ . '…‥'
            \ . '°′″‰℃'
if &enc == 'utf-8'
  let JpKinsoku .= '〙〗｠»'
               \ . 'ゕゖㇰㇱㇳㇲㇳㇴㇵㇶㇷㇸㇹㇺㇻㇼㇽㇾㇿ'
               \ . '〻'
               \ . '〜'
               \ . '‼⁇⁈⁉'
               \ . '゠'
               \ . '–'
               \ . '—〳〴〵'
               \ . '¢ℓ㏋'
endif
let JpKinsoku = '['.JpKinsoku.']'

" 行末禁則
let JpKinsokuE = '-_0-9a-zA-Z{<（［'
             \ . '([｛〔〈《「『【〝‘“'
             \ . '¥\£$＃№'
if &enc == 'utf-8'
  let JpKinsokuE .= '〘〖｟«'
                \ . '€'
endif
let JpKinsokuE = '['.JpKinsokuE.']'

" 句点と閉じ括弧
let JpKutenParen = '、。，．'
               \ . ',)\]｝、〕〉》」』】〟’”'
if &enc == 'utf-8'
  let JpKutenParen .= '〙〗｠»'
endif
let JpKutenParen = '['.JpKutenParen.']'

" 句点と閉じ括弧＋分離不可文字追い出し用
" 分離不可文字を追い出す時にJpNoDivNがあったら、そこから追い出し。
" ですか？――<分割> のような行があったら ？は残して――のみを追い出す。
let JpNoDivN = '、。，．'
           \ . ')\]｝、〕〉》」』】〟’”'
           \ . '!?！？'
if &enc == 'utf-8'
  let JpNoDivN .= '〙〗｠»'
              \ . '‼⁇⁈⁉'
endif
let JpNoDivN = '['.JpNoDivN.']'

" 分離不可
if !exists('JpNoDiv')
  let JpNoDiv = '―'
            \ . '…‥'
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
" let JpKinsokuO = '-}>）―～－ｰ］！？゛゜ゝゞ｡｣､･ﾞﾟ'
"              \ . ',)\]｝、〕〉》」』】〟’”'
"              \ . 'ヽヾーァィゥェォッャュョヮヵヶぁぃぅぇぉっゃゅょゎ々'
"              \ . '‐'
"              \ . '?!'
"              \ . '・:;'
"              \ . '。.'
"              \ . '…‥'
"              \ . '°′″‰℃'
" if &enc == 'utf-8'
"   let JpKinsokuO .= '〙〗｠»'
"                 \ . 'ゕゖㇰㇱㇳㇲㇳㇴㇵㇶㇷㇸㇹㇺㇻㇼㇽㇾㇿ'
"                 \ . '〻'
"                 \ . '〜'
"                 \ . '‼⁇⁈⁉'
"                 \ . '゠'
"                 \ . '–'
"                 \ . '—〳〴〵'
"                 \ . '¢ℓ㏋'
" endif
" let JpKinsokuO = '['.JpKinsokuO.']'

let &cpo = s:cpo_save

