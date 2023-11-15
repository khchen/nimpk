#====================================================================
#
#          NimPK - Pocketlang Binding for Nim Language
#               Copyright (c) Chen Kai-Hung, Ward
#
#====================================================================

import npeg, strutils, strformat, tables

const PkHeader = staticRead("../pocketlang/src/include/pocketlang.h")
const OutputComments = true
const Header = """
#====================================================================
#
#          NimPK - Pocketlang Binding for Nim Language
#               Copyright (c) Chen Kai-Hung, Ward
#
#====================================================================
"""

type
  Pair = object
    name: string
    data: string

  Func = object
    name: string
    params: seq[Pair]
    ret: string
    comment: string

  Enum = object
    name: string
    items: seq[Pair]
    comment: string

  Struct = object
    name: string
    items: seq[Pair]
    comment: string

  Definition = object
    fnptrs: seq[Func]
    fns: seq[Func]
    enums: seq[Enum]
    structs: OrderedTable[string, Struct]

proc typeToNim(typ: string): string =
  var ptrCount = typ.count('*')
  var typ = typ.replace("const").replace(" ").replace("*")

  case typ
  of "size_t", "double", "int":
    typ = "c" & typ

  of "int32_t", "uint32_t":
    typ.removeSuffix("_t")

  of "char":
    if ptrCount >= 1:
      ptrCount.dec
      typ = "cstring"

  of "void":
    if ptrCount >= 1:
      ptrCount.dec
      typ = "pointer"

  else: discard
  return "ptr ".repeat(ptrCount) & typ

proc nameEscape(name: string): string =
  case name
  of "from", "ptr", "type", "method":
    "`" & name & "`"
  else:
    name

proc paramsToNim(params: seq[Pair], nameOnly=false): string =
  for param in params:
    if param.name == "...": continue
    result.add nameEscape(param.name)
    if not nameOnly:
      result.add ": "
      result.add param.data
    result.add ", "
  result.removeSuffix(", ")

proc removeComment(code: string): string =
  let parser = peg("start", comments: seq[(string, string)]):
    start <- *@(comment1 | comment2 | comment3)
    comment1 <- "/*" * @"*/":
      comments.add ($0, "")

    comment2 <- " //" * @"\n":
      comments.add (($0)[0..^2], "")

    comment3 <- "#" * @"\n":
      comments.add (($0)[0..^2], "")

  var comments: seq[(string, string)]
  discard parser.match(code, comments)
  result = code.multiReplace(comments)

proc parse(code: string): Definition =
  var temp: seq[Pair]

  let parser = peg("start", def: Definition):
    start <- *@(obj | fnptr | fn | enu | stru)
    obj <- >comment * "typedef" * +Space * "struct" * +Space * >ident:
      def.structs[$2] = Struct(name: $2, comment: replace($1, "//", "##").strip())

    fnptr <- >comment * "typedef" * +Space * >typ * *Space * "(*" * >ident * ")" * *Space * "(" * params * ")" :
      def.fnptrs.add Func(name: $3, params: temp, ret: typeToNim($2),
        comment: replace($1, "//", "##").strip())
      temp = @[]

    fn <- >comment * "PK_PUBLIC" * +Space * >typ * +Space * >ident * *Space * "(" * params * ")":
      def.fns.add Func(name: $3, params: temp, ret: typeToNim($2),
        comment: replace($1, "//", "##").strip())
      temp = @[]

    enu <- >comment * "enum" * +Space * >ident * *Space * "{" * *enuitem * *Space * "}":
      def.enums.add Enum(name: $2, items: temp,
        comment: replace($1, "//", "##").strip())
      temp = @[]

    stru <- "struct" * +Space * >ident * *Space * "{" * *struitem * *Space * "}":
      if $1 in def.structs:
        def.structs[$1].items = temp
      else:
        def.structs[$1] = Struct(name: $1, items: temp)
      temp = @[]

    param <- (*Space * >typ * +Space * >ident * *Space) | *Space * >>("void*"|"...") * *Space:
      var name = $2
      if name == "void*": name = "a1"
      temp.add Pair(name: name, data: typeToNim($1))

    params <- *(param * ?(',' * *Space)) * *Space

    enuitem <- *Space * >ident * *Space * >?("=" * *Space * >+Digit) * *Space * ?',':
      temp.add Pair(name: $1, data: if $2 == "": "" else: $3)

    struitem <- *Space * >typ * +Space * >ident * *Space * ";":
      temp.add Pair(name: $2, data: typeToNim($1))

    comment <- *("//" * @"\n")

    typ <- ?("const" * +Space) * ident * *(*Space * '*')
    ident <- +{'A'..'Z','a'..'z','0'..'9', '_'}

  discard parser.match(code, result)

proc ident(n: int): string = "  ".repeat(n)
proc comment(n: int, comment: string) =
  if OutputComments and comment != "":
    echo comment.indent(n, padding="  ")

proc outputTypes(def: Definition, n = 0) =
  echo ident(n) & "type"
  for enu in def.enums:
    echo fmt"{ident(n+1)}{enu.name}* = enum"
    comment(n+2, enu.comment)
    for item in enu.items:
      if item.data == "":
        echo fmt"{ident(n+2)}{item.name}"
      else:
        echo fmt"{ident(n+2)}{item.name} = {item.data}"

  for stru in def.structs.values:
    echo fmt"{ident(n+1)}{stru.name}* {{.bycopy.}} = object"
    comment(n+2, stru.comment)
    for item in stru.items:
      echo fmt"{ident(n+2)}{item.name}*: {item.data}"

  for fn in def.fnptrs:
    if fn.ret == "void":
      echo fmt"{ident(n+1)}{fn.name}* = proc ({paramsToNim(fn.params)}) {{.cdecl.}}"
    else:
      echo fmt"{ident(n+1)}{fn.name}* = proc ({paramsToNim(fn.params)}): {fn.ret} {{.cdecl.}}"
    comment(n+2, fn.comment)

  echo fmt"{ident(n+1)}PkNativeApi* {{.bycopy.}} = object"
  for fn in def.fns:
    if fn.params.len != 0 and fn.params[^1].name == "...": continue
    var ret = if fn.ret == "void": "" else: fmt": {fn.ret}"

    echo fmt"{ident(n+2)}{fn.name}*: proc ({paramsToNim(fn.params)}){ret} {{.cdecl.}}"

proc outputProcDef(def: Definition, n = 0) =
  for fn in def.fns:
    var ret = if fn.ret == "void": "" else: fmt": {fn.ret}"
    var pragma =
      if fn.params.len != 0 and fn.params[^1].name == "...": "{.importc, cdecl, varargs.}"
      else: "{.importc, cdecl.}"

    echo fmt"{ident(n)}proc {fn.name}*({paramsToNim(fn.params)}){ret} {pragma}"
    comment(n+1, fn.comment)

proc outputModuleFile(def: Definition, n = 0) =
  echo fmt"{ident(n)}var pk_api*: PkNativeApi"
  echo fmt"{ident(n)}proc pkInitApi(api: ptr PkNativeApi) {{.cdecl, exportc, dynlib.}} = pk_api = api[]"

  for fn in def.fns:
    if fn.params.len != 0 and fn.params[^1].name == "...": continue
    var ret = if fn.ret == "void": "" else: fmt": {fn.ret}"
    echo fmt"{ident(n)}proc {fn.name}*({paramsToNim(fn.params)}){ret} = pk_api.{fn.name}({paramsToNim(fn.params, true)})"

when isMainModule:
  var code = removeComment(PkHeader)
  var def = code.parse()

  echo Header
  echo "# !! THIS FILE IS GENERATED DO NOT EDIT\n"
  echo "{.push hint[Name]: off.}"
  def.outputTypes(0)
  echo "when appType == \"lib\":"
  def.outputModuleFile(1)
  echo "else:"
  def.outputProcDef(1)
