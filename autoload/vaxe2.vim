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

" return BuildHXML section, if non is set ask user
fun! vaxe2#BuildHXMLSection()
  if !has_key(s:c,'build_hxml_section')
    call vaxe2#SelectBuildHXMLSection()
  endif
  return s:c.build_hxml_section
endf
