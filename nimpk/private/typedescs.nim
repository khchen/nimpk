#====================================================================
#
#          NimPK - Pocketlang Binding for Nim Language
#               Copyright (c) Chen Kai-Hung, Ward
#
#====================================================================

import std/[macros, strformat, strutils, tables, typetraits]
export macros

proc `of`(x: NimNode, k: NimNodeKind): bool = x.kind == k
proc `of`(x: NimNode, k: set[NimNodeKind]): bool = x.kind in k
proc strlit(x: NimNode): NimNode = newStrLitNode(x.strVal)
proc strlit(x: string): NimNode = newStrLitNode(x)

proc getTypeDescRaw(typ: typedesc, symbols: seq[string] = @[]): string

macro objFields(t: typed): untyped =
  # get name, base class, and all type of fields of an object type
  # fields iterator don't support object variants
  proc collect(n: NimNode): seq[NimNode] =
    # collect all type sym in n
    if n of nnkIdentDefs:
      # result.add ident($n[0])
      result.add n[1]

    elif n of nnkOfInherit:
      result.add ident($n[0])
      result.add collect(n[0].getTypeImpl)

    elif n of nnkRecCase:
      result.add collect(n[0])
      # enclosed nnkOfBranch in ()
      for i in 1..<n.len:
        var children = collect(n[i])
        if children.len != 0:
          result.add ident"("
          result.add children
          result.add ident")"
    else:
      for i in n:
        result.add collect(i)

  var
    typ = t.getTypeImpl
    listSym = genSym(nskVar)
    body = newStmtList()

  assert typ.typekind == ntyTypeDesc

  var name =
    if typ[1] of nnkSym:
      strlit(typ[1])
    else:
      strlit(typ[1][0])

  body.add quote do:
    `listSym`.add `name` & ":"

  typ = typ[1].getTypeImpl
  assert typ of nnkObjectTy

  result = newStmtList()
  var symbols = ident"symbols"

  for i in collect(typ):
    if not (i of nnkIdent):
      body.add quote do:
        var x: `i`
        `listSym`.add getTypeDescRaw(x.type, `symbols`)
    else:
      var str = strlit(i)
      body.add quote do:
        if `str` in ["(", ")"]:
          `listSym`.add `str`
        else:
          `listSym`.add `str` & ":"

  result = quote do:
    var `listSym`: seq[string]
    block:
      `body`
    `listSym`

proc getTypeDescEx(n: NimNode): NimNode =
  result = newStmtList()
  var
    n = n
    ntyp = n.getType
    symbols = ident"symbols"

  # n = ref x or ptr x
  if n of {nnkRefTy, nnkPtrTy}:
    let
      x = n[0]
      prefix = if n.typeKind == ntyRef: strlit("ref[") else: strlit("ptr[")

    return quote do:
      `prefix` & getTypeDescRaw(type `x`, `symbols`) & "]"

  # n = X, where X is ref or ptr, ntyp should be ref[x] or ptr[x]
  elif n of nnkSym:
    assert ntyp of nnkBracketExpr
    let
      x = ntyp[1]
      prefix = if ntyp[0].getType.typeKind == ntyRef: strlit("ref[") else: strlit("ptr[")

    return quote do:
      `prefix` & getTypeDescRaw(type `x`, `symbols`) & "]"

  # n = X[...], may generic or seq, etc
  elif n of nnkBracketExpr:
    var
      x = ntyp
      prefix = ""
      suffix = ""

    while not (x of nnkSym):
      assert x of nnkBracketExpr

      # nim version > 2.1 need `x.getType[0].typekind` instead of x.getType.typekind
      case x.getType[0].typekind
      of ntyRef:
        prefix.add "ref["
        suffix.add "]"
      of ntyPtr:
        prefix.add "ptr["
        suffix.add "]"
      else: # not a symbol nor a ref/ptr, maybe seq[int], etc
        return quote do:
          `prefix` & getTypeDescRaw(type `x`, `symbols`) & "]"

      x = x[1]

    # the biggest problem is here!
    # for :ObjectType with generic, there is no simple way to get concrete definition
    # here we resolve the generic type by replace the n(ref or ptr) to :ObjectType,
    # and then redefine it as an new object type in a type section
    let typeSection = newTree(nnkTypeSection, x.getImpl)
    n[0] = x
    result = quote do:
      `typeSection`
      var x: typeof(`n`) # nim version > 2.1 need typeof(`n`) instead of just `n`
      `prefix` & getTypeDescRaw(type x, `symbols`) & `suffix`

macro getTypeDescEx(typ: typedesc): untyped =
  var typ = typ.getTypeImpl
  assert typ.typekind == ntyTypeDesc
  return getTypeDescEx(typ[1])

proc getTypeDescRaw(typ: typedesc, symbols: seq[string] = @[]): string =
  macro names(x: varargs[untyped]): untyped =
    result = newStmtList()
    var name = ident("name")
    for i in x:
      result.add quote do:
        proc `name`(x: `i`): string {.used.} = $x.type

  names(
    int, int8, int16, int32, int64,
    uint, uint8, uint16, uint32, uint64,
    float32, float64, string, cstring, bool, char)

  when typ is object:
    if $typ in symbols:
      return $symbols.find($typ)

    var symbols = symbols
    symbols &= @[$typ]

    var fields = objFields(typ)
    result = "object["
    for i in fields:
      if i in ["(", ")"]:
        result.add i
      else:
        if result[^1] notin {'[', '(', ':'}:
          result.add ","
        result.add i
    result.removeSuffix ":"
    result.add "]"
    return result

  elif typ is ref|ptr:
    return getTypeDescEx(typ)

  elif typ is tuple:
    var list: seq[string]
    var x: typ
    for i in x.fields:
      list.add getTypeDescRaw(i.type, symbols)
    return "tuple[" & list.join(",") & "]"

  elif typ is seq:
    var x: typ
    return "seq[" & getTypeDescRaw(x[0].type, symbols) & "]"

  elif typ is range:
    return fmt"range[{typ.low}..{typ.high}]"

  elif typ is SomeNumber|string|cstring|bool|char:
    var x: typ
    return name(x)

  elif typ is set:
    proc iter(s: typ): auto =
      for i in s: return i
    var s: typ
    return "set[" & getTypeDescRaw(iter(s).type, symbols) & "]"

  elif typ is array:
    var x: typ
    return fmt"array[{x.low}..{x.high},{getTypeDescRaw(x[0].type, symbols)}]"

  elif typ is distinct:
    return "distinct[" & getTypeDescRaw(typ.distinctBase, symbols) & "]"

  elif typ is enum:
    return fmt"enum[{$typ}]"

  else:
    # should be unreachable
    return $typ

var typeIds {.compileTime.} = initTable[string, int]()

proc ctGetTypeId(typ: typedesc): int {.compileTime.} =
  let name = getTypeDescRaw(typ)
  if name in typeIds:
    result = typeIds[name]
  else:
    result = typeIds.len + 1
    typeIds[name] = result

proc ctGetTypeDesc(typ: typedesc): string {.compileTime.} =
  return getTypeDescRaw(typ)

template getTypeId*(typ: typedesc): int =
  bind getTypeDescRaw
  const id = ctGetTypeId(typ)
  id

template getTypeDesc*(typ: typedesc): string =
  bind getTypeDescRaw
  const desc = ctGetTypeDesc(typ)
  desc

when isMainModule:
  import unittest

  suite "Typedesc":
    test "Basic Types and Aliases":
      type
        A1 = int
        B1 = float32
        C1 = seq[string]
        D1 = set[FileMode]
        E1 = distinct bool
        F1 = array[3..8, (char, range[0..16])]
        G1 = (int, int8, int16, int32, int64,
          uint, uint16, uint32, uint64, float32, float64,
          string, cstring, bool, char)

      type A2 = A1; type B2 = B1; type C2 = C1; type D2 = D1;
      type E2 = E1; type F2 = F1; type G2 = G1

      check:
        getTypeDesc(A1) == "int"
        getTypeDesc(B1) == "float32"
        getTypeDesc(C1) == "seq[string]"
        getTypeDesc(D1) == "set[enum[FileMode]]"
        getTypeDesc(E1) == "distinct[bool]"
        getTypeDesc(F1) == "array[3..8,tuple[char,range[0..16]]]"
        getTypeDesc(G1) == "tuple[int,int8,int16,int32,int64,uint,uint16,uint32,uint64,float32,float64,string,cstring,bool,char]"

        getTypeDesc(A1) == getTypeDesc(A2)
        getTypeDesc(B1) == getTypeDesc(B2)
        getTypeDesc(C1) == getTypeDesc(C2)
        getTypeDesc(D1) == getTypeDesc(D2)
        getTypeDesc(E1) == getTypeDesc(E2)
        getTypeDesc(F1) == getTypeDesc(F2)
        getTypeDesc(G1) == getTypeDesc(G2)

    test "Objects and Inheritance":
      type
        A1 = object
        B1 = object
          a: int
          b: float32
          c: seq[string]
          d: set[FileMode]
          e: distinct bool
          f: array[3..8, (char, range[0..16])]

        C1 = object of RootObj
        D1 = object of C1
          a: int
          b: float32
        E1 = object of D1
          c: seq[string]
          d: set[FileMode]

        F1 = ref object
        G1 = ptr object
        H1 = ref D1
        I1 = ptr D1

      type A2 = A1; type B2 = B1; type C2 = C1; type D2 = D1;
      type E2 = E1; type F2 = F1; type G2 = G1; type H2 = H1;
      type I2 = I1

      check:
        getTypeDesc(A1) == "object[A1]"
        getTypeDesc(B1) == "object[B1:int,float32,seq[string],set[enum[FileMode]],distinct[bool],array[3..8,tuple[char,range[0..16]]]]"
        getTypeDesc(C1) == "object[C1:RootObj]"
        getTypeDesc(D1) == "object[D1:C1:RootObj:int,float32]"
        getTypeDesc(E1) == "object[E1:D1:C1:RootObj:int,float32,seq[string],set[enum[FileMode]]]"
        getTypeDesc(F1) == "ref[object[F1:ObjectType]]"
        getTypeDesc(G1) == "ptr[object[G1:ObjectType]]"
        getTypeDesc(H1) == "ref[object[D1:C1:RootObj:int,float32]]"
        getTypeDesc(I1) == "ptr[object[D1:C1:RootObj:int,float32]]"
        getTypeDesc(ref A1) == "ref[object[A1]]"
        getTypeDesc(ptr A1) == "ptr[object[A1]]"
        getTypeDesc(ref D1) == "ref[object[D1:C1:RootObj:int,float32]]"
        getTypeDesc(ptr D1) == "ptr[object[D1:C1:RootObj:int,float32]]"

        getTypeDesc(A1) == getTypeDesc(A2)
        getTypeDesc(B1) == getTypeDesc(B2)
        getTypeDesc(C1) == getTypeDesc(C2)
        getTypeDesc(D1) == getTypeDesc(D2)
        getTypeDesc(E1) == getTypeDesc(E2)
        getTypeDesc(F1) == getTypeDesc(F2)
        getTypeDesc(G1) == getTypeDesc(G2)
        getTypeDesc(H1) == getTypeDesc(H2)
        getTypeDesc(I1) == getTypeDesc(I2)

      type
        O1 = object
          data: int

        O2 = ref object
          data: int

        O3 = ptr object
          data: int

        OR1 = ref O1
        OR2 = ref O2
        OR3 = ref O3

        OP1 = ptr O1
        OP2 = ptr O2
        OP3 = ptr O3

      check:
        getTypeDesc(O1) == "object[O1:int]"
        getTypeDesc(O2) == "ref[object[O2:ObjectType:int]]"
        getTypeDesc(O3) == "ptr[object[O3:ObjectType:int]]"
        getTypeDesc(OR1) == "ref[object[O1:int]]"
        getTypeDesc(OR2) == "ref[ref[object[O2:ObjectType:int]]]"
        getTypeDesc(OR3) == "ref[ptr[object[O3:ObjectType:int]]]"
        getTypeDesc(OP1) == "ptr[object[O1:int]]"
        getTypeDesc(OP2) == "ptr[ref[object[O2:ObjectType:int]]]"
        getTypeDesc(OP3) == "ptr[ptr[object[O3:ObjectType:int]]]"
        getTypeDesc(ref O1) == "ref[object[O1:int]]"
        getTypeDesc(ref O2) == "ref[ref[object[O2:ObjectType:int]]]"
        getTypeDesc(ref O3) == "ref[ptr[object[O3:ObjectType:int]]]"
        getTypeDesc(ref OR1) == "ref[ref[object[O1:int]]]"
        getTypeDesc(ref OR2) == "ref[ref[ref[object[O2:ObjectType:int]]]]"
        getTypeDesc(ref OR3) == "ref[ref[ptr[object[O3:ObjectType:int]]]]"
        getTypeDesc(ref OP1) == "ref[ptr[object[O1:int]]]"
        getTypeDesc(ref OP2) == "ref[ptr[ref[object[O2:ObjectType:int]]]]"
        getTypeDesc(ref OP3) == "ref[ptr[ptr[object[O3:ObjectType:int]]]]"
        getTypeDesc(ptr O1) == "ptr[object[O1:int]]"
        getTypeDesc(ptr O2) == "ptr[ref[object[O2:ObjectType:int]]]"
        getTypeDesc(ptr O3) == "ptr[ptr[object[O3:ObjectType:int]]]"
        getTypeDesc(ptr OR1) == "ptr[ref[object[O1:int]]]"
        getTypeDesc(ptr OR2) == "ptr[ref[ref[object[O2:ObjectType:int]]]]"
        getTypeDesc(ptr OR3) == "ptr[ref[ptr[object[O3:ObjectType:int]]]]"
        getTypeDesc(ptr OP1) == "ptr[ptr[object[O1:int]]]"
        getTypeDesc(ptr OP2) == "ptr[ptr[ref[object[O2:ObjectType:int]]]]"
        getTypeDesc(ptr OP3) == "ptr[ptr[ptr[object[O3:ObjectType:int]]]]"

    test "Generic Types":
      type
        A1[T] = object
          data: T
        B1[T] = object
          data: seq[T]

      check:
        getTypeDesc(A1[string]) == "object[A1:string]"
        getTypeDesc(B1[string]) == "object[B1:seq[string]]"
        getTypeDesc(A1[A1[int]]) == "object[A1:object[A1:int]]"
        getTypeDesc(A1[B1[int]]) == "object[A1:object[B1:seq[int]]]"
        getTypeDesc(B1[A1[bool]]) == "object[B1:seq[object[A1:bool]]]"
        getTypeDesc(B1[B1[bool]]) == "object[B1:seq[object[B1:seq[bool]]]]"
        getTypeDesc(A1[ref string]) == "object[A1:ref[string]]"
        getTypeDesc(B1[ref string]) == "object[B1:seq[ref[string]]]"
        getTypeDesc(A1[ref A1[int]]) == "object[A1:ref[object[A1:int]]]"
        getTypeDesc(A1[ref B1[int]]) == "object[A1:ref[object[B1:seq[int]]]]"
        getTypeDesc(ref B1[A1[bool]]) == "ref[object[B1:seq[object[A1:bool]]]]"
        getTypeDesc(ref B1[B1[bool]]) == "ref[object[B1:seq[object[B1:seq[bool]]]]]"

      check:
        getTypeDesc(seq[A1[string]]) == "seq[object[A1:string]]"
        getTypeDesc(seq[B1[int]]) == "seq[object[B1:seq[int]]]"
        getTypeDesc(seq[ref A1[string]]) == "seq[ref[object[A1:string]]]"
        getTypeDesc(seq[ref B1[int]]) == "seq[ref[object[B1:seq[int]]]]"
        getTypeDesc(ref seq[A1[string]]) == "ref[seq[object[A1:string]]]"
        getTypeDesc(ref seq[B1[int]]) == "ref[seq[object[B1:seq[int]]]]"

      type
        O1[T, U] = object
          data1: T
          data2: U

        O2[T, U] = ref object
          data1: T
          data2: U

        O3[T, U] = ptr object
          data1: T
          data2: U

        OR1[T, U] = ref O1[T, U]
        OR2[T, U] = ref O2[T, U]
        OR3[T, U] = ref O3[T, U]

        OP1[T, U] = ptr O1[T, U]
        OP2[T, U] = ptr O2[T, U]
        OP3[T, U] = ptr O3[T, U]

        OS1[T] = seq[T]
        OS2[T] = ref seq[T]
        OS3[T] = ptr seq[T]

      check:
        getTypeDesc(O1[int, string]) == "object[O1:int,string]"
        getTypeDesc(O2[int, string]) == "ref[object[O2:ObjectType:int,string]]"
        getTypeDesc(O3[int, string]) == "ptr[object[O3:ObjectType:int,string]]"
        getTypeDesc(OR1[int, string]) == "ref[object[O1:int,string]]"
        getTypeDesc(OR2[int, string]) == "ref[ref[object[O2:ObjectType:int,string]]]"
        getTypeDesc(OR3[int, string]) == "ref[ptr[object[O3:ObjectType:int,string]]]"
        getTypeDesc(OP1[int, string]) == "ptr[object[O1:int,string]]"
        getTypeDesc(OP2[int, string]) == "ptr[ref[object[O2:ObjectType:int,string]]]"
        getTypeDesc(OP3[int, string]) == "ptr[ptr[object[O3:ObjectType:int,string]]]"
        getTypeDesc(ref O1[int, string]) == "ref[object[O1:int,string]]"
        getTypeDesc(ref O2[int, string]) == "ref[ref[object[O2:ObjectType:int,string]]]"
        getTypeDesc(ref O3[int, string]) == "ref[ptr[object[O3:ObjectType:int,string]]]"
        getTypeDesc(ref OR1[int, string]) == "ref[ref[object[O1:int,string]]]"
        getTypeDesc(ref OR2[int, string]) == "ref[ref[ref[object[O2:ObjectType:int,string]]]]"
        getTypeDesc(ref OR3[int, string]) == "ref[ref[ptr[object[O3:ObjectType:int,string]]]]"
        getTypeDesc(ref OP1[int, string]) == "ref[ptr[object[O1:int,string]]]"
        getTypeDesc(ref OP2[int, string]) == "ref[ptr[ref[object[O2:ObjectType:int,string]]]]"
        getTypeDesc(ref OP3[int, string]) == "ref[ptr[ptr[object[O3:ObjectType:int,string]]]]"
        getTypeDesc(ptr O1[int, string]) == "ptr[object[O1:int,string]]"
        getTypeDesc(ptr O2[int, string]) == "ptr[ref[object[O2:ObjectType:int,string]]]"
        getTypeDesc(ptr O3[int, string]) == "ptr[ptr[object[O3:ObjectType:int,string]]]"
        getTypeDesc(ptr OR1[int, string]) == "ptr[ref[object[O1:int,string]]]"
        getTypeDesc(ptr OR2[int, string]) == "ptr[ref[ref[object[O2:ObjectType:int,string]]]]"
        getTypeDesc(ptr OR3[int, string]) == "ptr[ref[ptr[object[O3:ObjectType:int,string]]]]"
        getTypeDesc(ptr OP1[int, string]) == "ptr[ptr[object[O1:int,string]]]"
        getTypeDesc(ptr OP2[int, string]) == "ptr[ptr[ref[object[O2:ObjectType:int,string]]]]"
        getTypeDesc(ptr OP3[int, string]) == "ptr[ptr[ptr[object[O3:ObjectType:int,string]]]]"
        getTypeDesc(OS1[int]) == "seq[int]"
        getTypeDesc(OS2[int]) == "ref[seq[int]]"
        getTypeDesc(OS3[int]) == "ptr[seq[int]]"
        getTypeDesc(ref OS1[int]) == "ref[seq[int]]"
        getTypeDesc(ref OS2[int]) == "ref[ref[seq[int]]]"
        getTypeDesc(ref OS3[int]) == "ref[ptr[seq[int]]]"
        getTypeDesc(ptr OS1[int]) == "ptr[seq[int]]"
        getTypeDesc(ptr OS2[int]) == "ptr[ref[seq[int]]]"
        getTypeDesc(ptr OS3[int]) == "ptr[ptr[seq[int]]]"
