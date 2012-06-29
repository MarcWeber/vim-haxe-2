" exec vam#DefineAndBind('s:c','g:vim_haxe','{}')
if !exists('g:vim_haxe_2') | let g:vaxe2 = {} | endif | let s:c = g:vaxe2

" let user choose from list
fun! vaxe2#Select(items, label)
  if len(a:items) == 1
    return a:items[0]
  endif
  " for now use tlib implementation:
  return tlib#input#List("s", a:label, a:items)
endf

" HXML {{{

" try to extract useful information from haxe compiler args
fun! vaxe2#ParseBuildHXMLSection(file, s)
  let r = {'text': a:s, 'file': a:file}
  let words = split(a:s, '[ \t\r\n]\+')

  " detect target
  let targets = {'js': '-js', 'cpp': '-cpp', 'swf': '-swf', 'neko': '-neko'}
  for [type, word] in items(targets)
    let i = index(words, word)
    if i >= 0
      let r.target = type.' '.words[i+1]
      break
    endif
  endfor
  if !has_key(r, 'target')
    " no way to shorten the display - show everything in one line:
    let r.target = substitute(a:s, "\n", " ", 'g')
  endif


  " TODO extract more useful stuff such as libraries being used etc

  return r
endf

" returns sections of hxml file separated by --next
fun! vaxe2#ParseHXML(file)
  return {'file': a:file, 'sections': map( split(join(readfile(a:file), "\n"),"--next"),'vaxe2#ParseBuildHXMLSection(a:file, v:val)')}
endf

" let user choose build hxml section
" this may trigger many events such as tagging etc
fun! vaxe2#SelectBuildHXMLSection()
  let hxml_files = split(glob('*.hxml'),"\n")
  if empty(hxml_files)
    throw "no .hxml file found :-("
  endif
  let hxml_file = vaxe2#ParseHXML(vaxe2#Select(hxml_files, 'select .hxml file'))
  let targets = map(copy(hxml_file.sections),'v:val.target')
  " lets hope ther are no duplicates .. target dir/js/ name should be quite
  " unique
  let target  = vaxe2#Select(targets, 'select target within that')
  let s:c.build_hxml_section = hxml_file.sections[index(targets, target)]
endf

" return BuildHXML section, if none is set ask user
fun! vaxe2#BuildHXMLSection()
  if !has_key(s:c,'build_hxml_section')
    call vaxe2#SelectBuildHXMLSection()
  endif
  return s:c.build_hxml_section
endf


" completion {{{

" add var of current function to complete list
" This should be implemented in HaXe - but it takes me no time doing it in
" VimL
fun! vaxe2#AddLocalVars(regex, additional_regex)
  if b:char_before_completion == '.'
    return
  endif
  let lidx = line('.')
  let r = []
  while lidx > 0
    let l = getline(lidx)
    if l =~ 'function'
      " break
      for x in r | call complete_add(x) | endfor
      return
    endif
    " join lines by " " until ; is found
    if l =~ '^\s*var\>'
      let i = lidx
      let conc = ''
      while l !~ ';' && i < line('.')
        let conc .= l
        let i+=1
        let l = getline(i)
      endwhile
      let conc .= " ".l
      let without_var = matchstr(conc, '^\s*var\>\s*\zs[^;]*')
      for var in split(without_var,',\s*')
        let v = matchstr(var, '\zs[^;: \t]*')
        if v =~ a:regex || (a:additional_regex != "" && v =~ a:additional_regex)
          call add(r, {'word': v, 'menu': 'var in func '.matchstr(var,'^[^;: \t]*\zs.*')})
        endif
      endfor
    endif
    let lidx = lidx -1
  endwhile
endf

" completes using haxe compiler
"
" this function writes the current buffer
" col=1 is first character
" g:haxe_build_hxml should be set to the buildfile so that important
" compilation flags can be extracted.
" You should consider creating one .hxml file for each target..
" 
" TODO simplify, consider optionally using pyhton (so that it takes less
" lines), or webapi for parsing xml
"
" base: prefix used to filter results
fun! vaxe2#CompleteHAXEFun(line, col, base, ...)
  let opts = a:0 > 0 ? a:1 : {}

  call vaxe2#AddLocalVars(a:base, s:additional_regex)

  " Start constructing the command for haxe
  " The classname will be based on the current filename
  " On both the classname and the filename we make sure
  " the first letter is uppercased.
  let classname = substitute(expand("%:t:r"),"^.","\\u&","")

  let linesTillC = getline(1, a:line-1)+[getline('.')[:(a:col-1)]]
  " hacky: remove package name. This way the file doesn't have to be put into
  " subdirectories
  let [b,eof] = [&binary, &endofline]
  setlocal binary
  setlocal noendofline

  " don't trigger vim-addon-action actions on buf write
  let g:prevent_action = 1
  silent w!
  let g:prevent_action = 0
  " set old settings
  exec 'setlocal '.(b?'':'no').'binary'
  exec 'setlocal '.(eof?'':'no').'endofline'

  let bytePos = len(join(linesTillC,"\n"))
  
  " Construction of the base command line
  let d = vaxe2#BuildHXML()
  let list = matchlist(getline(search(s:regex_package, 'bn')), s:regex_package)
  let package =
        \ len(list) > 1
        \ ? list[1].'.'
        \ : ""

  let strCmd="haxe --no-output -main " . package.classname . " " . substitute(d['ExtraCompletArgs'],'-main\s\+[^ ]*','',''). " --display " . '"' . expand('%') . '"' . "@" . bytePos

  try
    let dolstErrors = 0

    " We keep the results from the comand in a variable
    let g:strCmd = strCmd
    let res=system(strCmd.' 2>&1')

    let g:res = res
    if v:shell_error != 0
      " HaXe still returns completions. However there may be errors
      " So do both: show errors and completions
      let dolstErrors =1
    endif

    let lstXML = split(res,"\n") " We make a list with each line of the xml

    " strip error lines
    let tagLine = 0
    while tagLine < len(lstXML) && lstXML[tagLine] !~ '^<list'
      let tagLine += 1
    endw
    let lstXML = lstXML[(tagLine):]
    if tagLine > 0
      let dolstErrors = 1
    endif

    if len(lstXML) == 0
      let lstComplete = []
    elseif lstXML[0] != '<list>' "If is not a class definition, we check for type definition
      if lstXML[0] != '<type>' " If not a type definition then something went wrong... 
        let dolstErrors = 1
      else " If it was a type definition
        call filter(lstXML,'v:val !~ "type>"') " Get rid of the type tags
        call map(lstXML,'vaxe2#HaxePrepareList(v:val)') " Get rid of the xml in the other lines
        let lstComplete = [] " Initialize our completion list
        for item in lstXML " Create a dictionary for each line, and add them to a list
          let dicTmp={'word': item}
        endfor
        call add(lstComplete,dicTmp)
        return lstComplete " Finally, return the list with completions
      endif
    endif
    call filter(lstXML,'v:val !~ "list>"') " Get rid of the list tags
    call map(lstXML,'vaxe2#HaxePrepareList(v:val)') " Get rid of the xml in the other lines
    let lstComplete = [] " Initialize our completion list
    for item in lstXML " Create a dictionary for each line, and add them to a list
      if item == '' | continue | endif
      let element = split(item,"*")
      if len(element) == 1 " Means we only got a package class name
        let dicTmp={'word': element[0]}
      else " Its a method name
        let dicTmp={'word': element[0], 'menu': element[1], 'info': element[1] }
        if element[1] == "Void -> Void"
          " function does not expect arguments
          let dicTmp["word"] .= "()"
        elseif element[1] =~ "->"
          let dicTmp["word"] .= "("
        endif
      endif
      call add(lstComplete,dicTmp)
    endfor
  catch lstErrors
    let dolstErrors = 1
  endtry

  if dolstErrors
    let lstErrors = split(res,"\n")
    if !exists("s:haxeErrorFile")
      let s:haxeErrorFile = tempname()
    endif
    call writefile(lstErrors,s:haxeErrorFile)
    execute "cgetfile ".s:haxeErrorFile
    " Errors will be available for view with the quickfix commands
    cope | wincmd p
  endif

  call filter(lstComplete,'v:val["word"] =~ '.string('^'.a:base).  ( s:additional_regex == "" ? "" : '|| v:val["word"] =~ '.string('^'.s:additional_regex) ) )
  return lstComplete
endf


fun! vaxe2#CompleteClassNamesFun(line, col, base, ...)
  let opts = a:0 > 0 ? a:1 : {}

  " tag based, cause its faster
  for t in taglist('^'.a:base.'.*')+(s:additional_regex == "" ? [] : taglist(s:additional_regex))
    if t['kind'] == 'c'
      let scanned = cached_file_contents#CachedFileContents(t['filename'], s:c['f_scan_as'])
      " add package prefix if not yet imported
      let p = ''
      if get(scanned,'package','') != "" && !search('import\s\+'.scanned['package'].'\s\+;','n')
        let p = scanned['package'].'.'
      endif
      call complete_add({'word': p.t['name'], 'menu': 'class by tag file: '.t['filename']})

    elseif t['kind'] == 'f'
      " assume tags generated by ctags ..
      if t['cmd'] !~ '\<static\>' | continue | endif
      let fun_name = t['name']
      let scanned = cached_file_contents#CachedFileContents(t['filename'], s:c['f_scan_as'])
      " add package prefix if not yet imported
      let p = ''
      if get(scanned, 'package','') != "" && !search('import\s\+'.scanned['package'].'\s\+;','n')
        let p = scanned['package'].'.'
      endif

      " find class providing functions
      let class = ""
      for [k,v] in items(get(scanned, 'classes', {}))
        if index(keys(get(v,'functions', {})), fun_name) != -1
          let class = k
        endif
        unlet k v
      endfor
      let p .= class.'.'
      let args = matchstr(t['cmd'], '.*\zs([^{]*')
      call complete_add({'word': p.fun_name.'(', 'menu': args.' tag file: '.t['filename']})
    endif
  endfor
  return []
endf

" completion helper function calling completion functions {{{1
" calls completion functions
fun! vaxe2#CompleteHelper(findstart, base, funs, break)
  if a:findstart
    let b:haxePos = vaxe2#CursorPositions()
    return b:haxePos['col']
  else
    let result = []

    let s:additional_regex = ""
    if s:c.use_vim_addon_completion
      let patterns = vim_addon_completion#AdditionalCompletionMatchPatterns(a:base
            \ , "vim_dev_plugin_completion_func", {'match_beginning_of_string': 0})
      let s:additional_regex = get(patterns, 'vim_regex', "")
    endif

    for f in a:funs
      call extend(result, call(function('vaxe2#'.f),[b:haxePos['line'], b:haxePos['col'], a:base, {'use_additional_regex':1}]))
      if len(result) > 0 && a:break
        break
      endif
    endfor
    return result
  endif
endf

" complete using haxe executable
fun! vaxe2#CompleteHAXE(findstart, base)
  return vaxe2#CompleteHelper(a:findstart, a:base, ["CompleteHAXEFun"], 0)
endfun

" complete classnames (may be slow)
fun! vaxe2#CompleteClassNames(findstart, base)
  return vaxe2#CompleteHelper(a:findstart, a:base, ["CompleteClassNamesFun"], 0)
endfun

" complete both
fun! vaxe2#CompleteAll(findstart, base)
  return vaxe2#CompleteHelper(a:findstart, a:base, ["CompleteHAXEFun", "CompleteClassNamesFun"], 0)
endfun

" complete both, smart: only use class name completion if haxe did not return
" anything useful.
fun! vaxe2#CompleteAllSmart(findstart, base)
  return vaxe2#CompleteHelper(a:findstart, a:base, ["CompleteHAXEFun", "CompleteClassNamesFun"], 1)
endfun
