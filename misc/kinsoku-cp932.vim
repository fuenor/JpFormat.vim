"=============================================================================
"    Description: 禁則処理文字列設定 for JpFormat.vim
"                 独自に禁則文字列を設定したい場合は、このファイルを
"                 JpFormat.vimと同じ場所かruntimepathの通った場所へコピーして
"                 改変してください。
"
"                 このファイルはWindowsで内部エンコーディングがcp932の場合に使
"                 用します。
"                 内部エンコーディングがUTF-8の場合はkinsoku.vimを参照してみて
"                 ください。
"     Maintainer: fuenor@gmail.com
"        Version: 1.05
"=============================================================================
scriptencoding utf-8

let s:cpo_save = &cpo
set cpo&vim

" 基本的な処理方法
" 1. 指定文字数に行を分割
" 2. 分割した次行の行頭禁則文字(JpKinsoku)を現在行へ移動
" 3. 現在行の行末禁則文字(JpKinsokuE)を次行へ移動
" 4. ぶら下がり文字数を超えてぶら下がっていたら追い出し(JpKinsokuO)
"    (JpKinsokuOが未設定の場合はJpKinsokuで代用されます)

" 行頭禁則
let JpKinsoku = '-}>）―～－ｰ］！？゛゜ゝゞ｡｣､･ﾞﾟ'
            \ . ',)\]｝、〕〉》」』】〟’”'
            \ . 'ヽヾー々'
            \ . 'ァィゥェォッャュョヮヵヶぁぃぅぇぉっゃゅょゎ'
            \ . '‐'
            \ . '?!'
            \ . '・:;'
            \ . '。.'
            \ . '…‥'
let JpKinsoku = '['.JpKinsoku.']'

" 行末禁則
let JpKinsokuE = '{<（［'
             \ . '([｛〔〈《「『【〝‘“'
let JpKinsokuE = '['.JpKinsokuE.']'

" 追い出し用
" ぶら下がり文字数を超えている時、JpKinsokuO以外の1文字を足して追い出す。
" 未設定時にはJpKinsokuで代用される。
" let JpKinsokuO = '-}>）―～－ｰ］！？゛゜ゝゞ｡｣､･ﾞﾟ'
"              \ . ',)\]｝、〕〉》」』】〟’”'
"              \ . 'ヽヾー々'
"              \ . 'ァィゥェォッャュョヮヵヶぁぃぅぇぉっゃゅょゎ'
"              \ . '‐'
"              \ . '?!'
"              \ . '・:;'
"              \ . '。.'
"              \ . '…‥'
" let JpKinsokuO = '['.JpKinsokuO.']'

" 句点と閉じ括弧
let JpKutenParen = '、。，．'
               \ . ',)\]｝、〕〉》」』】〟’”'
let JpKutenParen = '['.JpKutenParen.']'

" 句点と閉じ括弧＋分離不可文字追い出し用
" 分離不可文字を追い出す時にJpNoDivNがあったら、そこから追い出し。
" ですか？――<分割> のような行があったら ？は残して――のみを追い出す。
let JpNoDivN = '、。，．'
           \ . ')\]｝、〕〉》」』】〟’”'
           \ . '!?！？'
let JpNoDivN = '['.JpNoDivN.']'

" 分離不可
let JpNoDiv = '―'
          \ . '…‥'
let JpNoDiv = '['.JpNoDiv.']'

" 分離不可(ペア)
let JpNoDivPair = ''
let JpNoDivPair = '['.JpNoDivPair.']'

let &cpo = s:cpo_save

