" exec vam#DefineAndBind('s:c','g:vim_haxe','{}')
if !exists('g:vim_haxe_2') | let g:vaxe2 = {} | endif | let s:c = g:vaxe2

" requires vim-addon-completion, provides camel case matching
let s:c.use_vim_addon_completion = get(s:c, 'use_vim_addon_completion', 1)

if s:c.use_vim_addon_completion && exists('g:vim_addon_manager')
  ActivateAddon vim-addon-completion
endif

" See http://majutsushi.github.com/tagbar/
" if user has not installed it this does nothing
let g:tagbar_type_haxe = {
    \ 'ctagstype' : 'haxe',
    \ 'kinds'     : [
        \ 'c:classes',
        \ 'v:variables',
        \ 'f:functions',
    \ ]
        \ }

" neocompl cache setup: If user has not installed it this code does nothing
if !exists('g:neocomplcache_omni_patterns')
    let g:neocomplcache_omni_patterns = {}
endif
let g:neocomplcache_omni_patterns.haxe = '\v([\]''"]|\w)(\.|\()'
