" exec vam#DefineAndBind('s:c','g:vim_haxe','{}')
if !exists('g:vim_haxe_2') | let g:vaxe2 = {} | endif | let s:c = g:vaxe2

" See
" http://majutsushi.github.com/tagbar/
" let s:c.tagbar_support = get(s:c,'tagbar_support',0)
let g:tagbar_type_haxe = {
    \ 'ctagstype' : 'haxe',
    \ 'kinds'     : [
        \ 'c:classes',
        \ 'v:variables',
        \ 'f:functions',
    \ ]
        \ }
