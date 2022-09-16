#====================================================================
#
#             NimPK - PocketLang Binding for Nim
#                  Copyright (c) 2022 Ward
#
#====================================================================

{.experimental: "dotOperators".}
{.experimental: "callOperator".}
{.experimental: "dynamicBindSym".}

import std/[macros, strformat, strutils, tables, typetraits]
import nimpk/includes, nimpk/private/[typedescs, npbox]
export includes, typedescs, npbox

# helper functions
proc discardable[T](x: sink T): T {.discardable.} = x
proc `of`(x: NimNode, k: NimNodeKind): bool = x.kind == k
proc `of`(x: NimNode, k: set[NimNodeKind]): bool = x.kind in k
proc strlit(x: NimNode): NimNode = newStrLitNode(x.strVal)
proc strlit(x: string): NimNode = newStrLitNode(x)

proc str(x: NimNode): NimNode =
  case x.kind
  of nnkIdent, nnkStrLit: return strlit(x)
  of nnkAccQuoted: return x[0]
  else: error("Unreachable")

proc doc(x: NimNode): NimNode =
  if x.len >= 1 and x[0] of nnkCommentStmt: strlit(x[0])
  else: strlit("")

proc deprefix(x: NimNode, pre: string): NimNode =
  if x of nnkPrefix and x.len == 2 and x[0] == ident(pre):
    return x[1]

type
  NpVm* = ref object of RootObj
    ## Ref object of NimPk VM.
    pkvm: ptr PkVM

  NpVar* = object
    ## Object of NimPk variant.
    vm: NpVm
    np: NpBox

  NimPkError* = object of CatchableError
    ## Catchable errors for NimPk.
    report*: string

# forward definitions
proc `$`*(v: NpVar): string
proc reraise0(vm: NpVm)

template isOk(vm: NpVm): bool = (not vm.isNil) and (not vm.pkvm.isNil)
template handle(v: NpVar): ptr PkHandle = v.np[ptr PkHandle]

converter convertNpVmToPkVm*(vm: NpVm): ptr PkVM {.inline.} =
  if isOk(vm): vm.pkvm
  else: nil

proc `=destroy`*(vm: var typeof(NpVm()[])) =
  ## Destructors for NimPK VM.
  if not vm.pkvm.isNil:
    pkFreeVM(vm.pkvm)
    vm.pkvm = nil

proc `=destroy`*(x: var NpVar) =
  ## Destructors for NimPK variant.
  if isOk(x.vm) and x.np.isHandle:
    x.vm.pkReleaseHandle(x.handle)

proc `=sink`*(x: var NpVar, y: NpVar) =
  `=destroy`(x)
  wasMoved(x)
  x.vm = y.vm
  x.np = y.np

proc `=copy`*(x: var NpVar, y: NpVar) =
  if x.np == y.np:
    x.vm = y.vm # copy vm anyway, x.vm may be nil
    return

  `=destroy`(x)
  wasMoved(x)
  x.vm = y.vm
  x.np = y.np
  if isOk(y.vm) and y.np.isHandle:
    y.vm.pkReserveSlots(1)
    var backup = y.vm.pkGetSlotHandle(0) # is backup necessary?
    y.vm.pkSetSlotHandle(0, y.handle) # copy the handle
    x.np = npObject(y.np.kind, y.vm.pkGetSlotHandle(0))
    y.vm.pkSetSlotHandle(0, backup)
    y.vm.pkReleaseHandle(backup)

proc newVm*(config: ptr PkConfiguration = nil): NpVm =
  ## Create a new NimPk virtual machine.
  result = NpVm(pkvm: pkNewVM(config))
  result.pkSetUserData(cast[pointer](result))

proc newVm*(T: typedesc, config: ptr PkConfiguration = nil): T =
  ## Create a new NimPk virtual machine with custom type to store user data.
  ## Custom type must be `ref object of NpVm`.
  when T is ref and compiles(T() of NpVm):
    result = T(pkvm: pkNewVM(config))
    result.pkSetUserData(cast[pointer](result))

  else:
    {.error: "Custom type must be ref object of NpVm.".}

proc getVm*(pkvm: ptr PkVM): NpVm =
  ## Get NpVm from a raw PkVm.
  result = cast[NpVm](pkvm.pkGetUserData())
  doAssert isOk(result)

template NpNil*: untyped =
  ## NpNull for default value of NpVar type.
  # should be a const, but how?
  NpVar(vm: nil, np: npNull)

proc `of`*(v: NpVar, typ: NpVarType): bool {.inline.} =
  ## Syntax sugar to check type of variable.
  v.np.kind == typ

proc kind*(v: NpVar): NpVarType {.inline.} =
  ## Return the kind of variable.
  result = v.np.kind

proc null*(vm: NpVm): NpVar =
  ## Returns a variable represent null value.
  assert(vm != nil)
  result = NpVar(vm: vm, np: npNull)

proc `[]`*(vm: NpVm, slot: int): NpVar =
  ## Get low level VM slots as NpVar object.
  ## Among all operations in NimPk, only `[]` and `[]=` won't broken other VM slots.
  ## Any other operations (even vm.new) use slots as temproary buffer.
  assert(vm != nil)
  var slot = cint slot
  if slot >= vm.pkGetSlotsCount():
    raise newException(NimPkError, "Slot out of index.")

  result.vm = vm
  var kind = vm.pkGetSlotType(slot)
  result.np = case kind
    of NpNull: npNull
    of NpBool: npBool(vm.pkGetSlotBool(slot))
    of NpNumber: npNumber(vm.pkGetSlotNumber(slot))
    else: npObject(kind, vm.pkGetSlotHandle(slot))

proc `[]=`*(vm: NpVm, slot: int, v: NpVar) =
  ## Set NpVar object to low level VM slots.
  ## Among all operations in NimPk, only `[]` and `[]=` won't broken other VM slots.
  ## Any other operations (even vm.new) use slots as temproary buffer.
  assert(vm != nil)
  var slot = cint slot
  vm.pkReserveSlots(slot + 1)
  case v.np.kind:
    of NpBool: vm.pkSetSlotBool(slot, v.np[bool])
    of NpNumber: vm.pkSetSlotNumber(slot, v.np[cdouble])
    of NpNull: vm.pkSetSlotNull(slot)
    else: vm.pkSetSlotHandle(slot, v.handle)

proc reserve*(vm: NpVm, n: int, start = 0): seq[NpVar] {.discardable.} =
  ## Reserve n slots count from start, can be restored later.
  assert(vm != nil)
  vm.pkReserveSlots(cint n + start)
  result.setLen(n)
  for i in 0..<n:
    result[i] = vm[i + start]

proc restore*(vm: NpVm, s: seq[NpVar], start = 0) =
  ## Resotre the slots from start.
  assert(vm != nil)
  for i in 0..<s.len:
    vm[i + start] = s[i]

converter toFloat*(v: NpVar): float =
  ## `float v` convert variable into float.
  if not (v of NpNumber):
    raise newException(NimPkError, fmt"{$v.kind} cannot convert to float implicitly.")

  result = v.np[float]

converter toBiggestFloat*(v: NpVar): BiggestFloat =
  ## `BiggestFloat v` convert variable into BiggestFloat.
  if not (v of NpNumber):
    raise newException(NimPkError, fmt"{$v.kind} cannot convert to float implicitly.")

  result = v.np[BiggestFloat]

converter toInt*(v: NpVar): int =
  ## `int v` convert variable into int.
  if not (v of NpNumber):
    raise newException(NimPkError, fmt"{$v.kind} cannot convert to int implicitly.")

  result = v.np[int]

converter toBiggestInt*(v: NpVar): BiggestInt =
  ## `BiggestInt v` convert variable into BiggestInt.
  if not (v of NpNumber):
    raise newException(NimPkError, fmt"{$v.kind} cannot convert to int implicitly.")

  result = v.np[BiggestInt]

converter toBool*(v: NpVar): bool =
  ## `bool v` convert variable into bool.
  if not (v of NpBool):
    raise newException(NimPkError, fmt"{$v.kind} cannot convert to bool implicitly.")

  result = v.np[bool]

converter toString*(v: NpVar): string =
  ## `string v` convert variable into string.
  if not (v of NpString):
    raise newException(NimPkError, fmt"{$v.kind} cannot convert to string implicitly.")

  v.vm[0] = v
  var len: uint32
  var cs = v.vm.pkGetSlotString(0, addr len)
  result = newString(len)
  if len != 0:
    copyMem(addr result[0], cs, len)

converter toCString*(v: NpVar): cstring =
  ## `cstring v` convert variable into cstring (without copying).
  if not (v of NpString):
    raise newException(NimPkError, fmt"{$v.kind} cannot convert to string implicitly.")

  v.vm[0] = v
  var len: uint32
  result = v.vm.pkGetSlotString(0, addr len)

template convertError(x: untyped) =
  {.error: "Cannot convert type '" & $typeof(x) & "' to NpVar.".}

proc `[]=`*[T](vm: NpVm, slot: int, x: T) =
  ## Set nim value to slot.
  ## Supports string, cstring, char, bool, SomeNumber, enum, HSlice,
  ## typeof(nil); and array, seq, or openarray of above.

  #   string|cstring|char   => NpString
  #   bool                  => NpBool
  #   SomeNumber|enum       => NpNumber
  #   HSlice                => NpRange
  #   type nil              => NpNull
  #   array, seq, openarray => NpList
  assert(vm != nil)
  let slot = cint slot
  vm.pkReserveSlots(slot + 1)
  when T is string:
    vm.pkSetSlotStringLength(slot, cstring x, uint32 x.len)
  elif T is char:
    vm.pkSetSlotStringLength(slot, cast[cstring](unsafeAddr x), 1)
  elif x is bool:
    vm.pkSetSlotBool(slot, x)
  elif T is SomeNumber|enum:
    vm.pkSetSlotNumber(slot, cdouble x)
  elif x is HSlice and compiles(cdouble x.a) and compiles(cdouble x.b):
    vm.pkNewRange(slot, cdouble x.a, cdouble x.b)
  elif T is cstring and T isnot typeof(nil): # nil is cstring == true (compile bug?)
    vm.pkSetSlotString(slot, x)
  elif T is typeof(nil):
    vm.pkSetSlotNull(slot)
  elif T is array|seq|openArray and compiles(`[]=`(vm, slot, x[0])):
    # []= assume not to change slot, so backup it
    var backup = vm.reserve(1, slot + 1)
    defer: vm.restore(backup, slot + 1)

    vm.pkNewList(slot)
    for v in x:
      vm[slot + 1] = v
      # error won't occur if index = -1
      discard vm.pkListInsert(slot, -1, slot + 1)
  else:
    convertError(x)

proc new*[T](vm: NpVm, x: T): NpVar =
  ## Create a new variable on the vm.
  when T is typeof(nil):
    result = vm.null

  elif x is bool:
    result = NpVar(vm: vm, np: npBool(x))

  elif x is SomeNumber|enum:
    result = NpVar(vm: vm, np: npNumber(x))

  elif x is NpVar:
    result = x # don't copy self
    if isOk(result.vm) == false: # if x is default(NpVar) etc.
      result.vm = vm

  elif compiles(`[]=`(vm, 0, x)):
    vm[0] = x
    result = vm[0]

  else:
    convertError(x)

template `()`*[T](vm: NpVm, x: T): untyped =
  ## Syntax sugar for new(vm, ...), vm(x) = vm.new(x).
  when compiles(new(vm, x)):
    vm.new(x)
  else:
    convertError(x)

template `{}=`[T](vm: NpVm, slot: int, x: T) =
  # High level assign for generic type, use vm.new if possible, use internally.
  # Try low level assign first, if not compiles, try to use new (predefined or custom).
  # WARNING: the value of other slots may be broken
  # vm{n} must be used in tempalte to use custom new.
  when compiles(`[]=`(vm, slot, x)):
    vm[slot] = x
  elif compiles(vm.new(x)) and compiles(`[]=`(vm, slot, vm.new(x))):
    vm[slot] = vm.new(x)
  else:
    convertError(x)

template `->`[T](vm: NpVm, x: T): NpVar =
  # High level converter T to NpVar, use vm.new (predefined or custom) at first.
  # If return value of vm.new is not NpVar, try nimpk.new again.
  # `->` must be used in tempalte to use custom new.
  when x is NpVar:
    x
  elif compiles(vm.new(x)):
    when vm.new(x) is NpVar:
      vm.new(x)
    elif compiles(nimpk.new(vm, vm.new(x))):
      nimpk.new(vm, vm.new(x))
    else:
      convertError(x)
  else:
    convertError(x)

template `{}`*(v0: NpVar, attr: string): NpVar =
  ## Get the attribute of a variable.
  # v0 maybe expression instead of symobl
  let v = v0
  assert(v.vm != nil)
  v.vm[0] = v
  if not v.vm.pkGetAttribute(0, cstring attr, 0): reraise0(v.vm)
  v.vm[0]

template `{}=`*[T](v0: NpVar, attr: string, x: T) =
  ## Set the attribute of a variable.
  # v0 maybe expression instead of symobl
  let v = v0
  assert(v.vm != nil)
  v.vm{1} = x
  v.vm[0] = v
  if not v.vm.pkSetAttribute(0, cstring attr, 1): reraise0(v.vm)

template `[]`*(v0: NpVar, key: untyped): NpVar =
  ## Get a subscript value.
  # v0 maybe expression instead of symobl
  let v = v0
  assert(v.vm != nil)
  v.vm{1} = key
  v.vm[0] = v
  if not v.vm.pkGetSubscript(0, 1, 0): reraise0(v.vm)
  v.vm[0]

template `[]=`*(v0: NpVar, key: untyped, value: untyped) =
  ## Set subscript value with the key.
  # v0 maybe expression instead of symobl
  let v = v0
  assert(v.vm != nil)
  # vm{n} may break slots, so get key as NpVar first
  let k = v.vm->key
  v.vm{2} = value
  v.vm[1] = k
  v.vm[0] = v
  if not v.vm.pkSetSubscript(0, 1, 2): reraise0(v.vm)

template insert*(v0: NpVar, x: untyped, index: int = 0) =
  ## Insert an element into list at index.
  # v0 maybe expression instead of symobl
  let v = v0
  assert(v.vm != nil)
  if not (v of NpList):
    raise newException(NimPkError, "Expected a 'List'")

  v.vm{1} = x
  v.vm[0] = v
  if not v.vm.pkListInsert(0, cint index, 1): reraise0(v.vm)

template add*(v: NpVar, x: untyped) =
  ## Add an element into list.
  insert(v, x, -1)

proc `import`*(vm: NpVm, module: string): NpVar =
  ## Import a module and initialize it.
  vm.pkReserveSlots(1)
  if vm.pkImportModule(cstring module, 0):
    result = vm[0]
    if not vm.pkModuleInitialize(handle(result)):
      reraise0(vm)
  else: reraise0(vm)

proc `[]`*(vm: NpVm, module: string): NpVar {.inline.} =
  ## Syntax sugar to import a module and initialize it.
  `import`(vm, module)

template error*(vm: NpVm): NpVar =
  ## Get the current error or null if there is no error.
  vm.pkReserveSlots(1)
  vm.pkGetRuntimeError(0)
  vm[0]

template error*[T](vm: NpVm, err: T) =
  ## Set the error.
  vm{0} = err
  vm.pkSetRuntimeErrorObj(0)

template lastError*(vm: NpVm): NpVar =
  ## Get the last error of the vm in `except` part.
  vm.import("lang"){"_nimerror"}

template lastError*[T](vm: NpVm, err: T) =
  ## Set the last error.
  vm.import("lang"){"_nimerror"} = vm->err

proc reraise0(vm: NpVm) =
  # Quickly reraise an string error in vm, don't reserve slot 0. Use internally.
  vm.pkGetRuntimeError(0)
  var err = vm[0]
  vm.pkGetRuntimeStackReport(0)
  var report = string vm[0]
  vm.lastError(err)
  vm.pkSetRuntimeError(nil) # reset the error
  var e = newException(NimPkError, $err)
  e.report = strip(report, leading = false)
  raise e

proc reraise*(vm: NpVm) =
  ## Raise a nim NimPkError error if there is error in vm.
  var err = vm.error
  vm.lastError(err)
  vm.pkSetRuntimeError(nil) # reset the error
  if not (err of PkNull):
    var e = newException(NimPkError, $err)
    raise e

proc getCurrentPocketLangStackReport*(): string =
  ## Retrieves the stack report that was attached to the current NimPkError.
  var e = getCurrentException()
  if e of (ref NimPkError):
    var e = (ref NimPkError) e
    result = e[].report
  else:
    raise e

proc `of`*(v: NpVar, class: NpVar): bool =
  ## Check if v is an instance of the class.
  if not (class of NpClass):
    raise newException(NimPkError, "Expected a 'Class'")

  v.vm[0] = v
  v.vm[1] = class
  result = v.vm.pkValidateSlotInstanceOf(0, 1)
  if not result:
    v.vm.pkSetRuntimeError(nil) # reset the error

proc toImpl[T](v: NpVar): T {.used.} =
  when T is HSlice and compiles(float T().a) and compiles(float T().a):
    result.a = typeof(T().a) float v{"first"}
    result.b = typeof(T().b) float v{"last"}

  elif T is array:
    if not (v of NpList):
      raise newException(NimPkError, fmt"{$v.kind} cannot convert to {$T}.")

    if v.len != T.len:
      raise newException(NimPkError, fmt"{$v.kind} cannot convert to {$T} (len = {$v.len}).")

    for i in 0..<v.len:
      result[i] = to[typeof(result[0])](v[i])

  elif T is seq:
    if not (v of NpList):
      raise newException(NimPkError, fmt"{$v.kind} cannot convert to {$T}.")

    result.setLen(v.len)
    for i in 0..<v.len:
      result[i] = to[typeof(result[0])](v[i])

  elif T is char:
    if not (v of NpString):
      raise newException(NimPkError, fmt"{$v.kind} cannot convert to {$T}.")

    if v.len != 1:
      raise newException(NimPkError, fmt"{$v.kind} cannot convert to {$T} (len = {$v.len}).")

    result = (v.string)[0]

  else:
    raise newException(NimPkError, fmt"{$v.kind} cannot convert to {$T}.")

proc toNimType[T](v: NpVar): T {.used.} =
  let ok = try: v.class{"_nimid"} == getTypeId(type T)
    except: false

  if ok:
    result = cast[ref T](v.native)[]
  else:
    raise newException(NimPkError, "Inconsistent nim type.")

proc to*[T](v: NpVar): T =
  ## Convert NpVar into nim type.
  ## For instance of native class, it can be converted to corresponding nim type.
  ## For PocketLang builtin types, following type are supported:
  ## bool|int|float|string|cstring|char|SomeNumber|enum|range|HSlice|array|seq|NpVar.
  when T is NpVar:
    v

  else:
    if v of NpInstance:
      toNimType[T](v)

    else:
      when T is bool|int|float|string|cstring:
        when T is range:
          T(int v)

        else:
          T(v)

      elif T is SomeInteger|enum:
        T(BiggestInt v)

      elif T is SomeFloat:
        T(BiggestFloat v)

      else:
        toImpl[T](v)

proc main*(vm: NpVm): NpVar =
  ## Get the main module.
  vm.pkReserveSlots(1)
  if not vm.pkGetMainModule(0):
    raise newException(NimPkError, "No main module available.")
  result = vm[0]

proc `{}`*(vm: NpVm, name: string): NpVar =
  ## Get the builtin funciton or class.
  vm.pkReserveSlots(1)
  # todo: both pkGetBuiltinFn and pkGetBuildinClass
  # compare string one by one, optimize?
  if not vm.pkGetBuiltinFn(cstring name, 0):
    if not vm.pkGetBuildinClass(cstring name, 0):
      raise newException(NimPkError,
        fmt"No builtin function or class named '{name}'.")

  result = vm[0]

proc len*(vm: NpVm): int =
  ## Get the available number of slots.
  result = int vm.pkGetSlotsCount()

proc len*(v: NpVar): int =
  ## Get length of string, list, or map, etc.
  assert(v.vm != nil)
  if v of NpList:
    v.vm[0] = v
    result = int v.vm.pkListLength(0)

  else:
    # error will be raised by `{}` if no implementation of "length"
    result = v{"length"}

proc call*(v: NpVar, args: varargs[NpVar]): NpVar {.discardable} =
  ## Call a "callable" variable, aka method bind, closure, or class.
  assert(v.vm != nil)
  if v.np.kind notin {NpClosure, NpClass, NpMethodBind}:
    raise newException(NimPkError, "Expected a callable")

  v.vm[0] = v
  for i in 0..<args.len:
    v.vm[i + 1] = args[i]

  if not v.vm.pkCallFunction(0, cint args.len, 1, 0): reraise0(v.vm)
  result = v.vm[0]

proc call*(v: NpVar, attr: static[string], args: varargs[NpVar]): NpVar {.discardable.} =
  ## Call a method of a object.
  assert(v.vm != nil)
  v.vm[0] = v
  for i in 0..<args.len:
    v.vm[i + 1] = args[i]

  if not v.vm.pkCallMethod(0, cstring attr, cint args.len, 1, 0): reraise0(v.vm)
  result = v.vm[0]

macro `()`*(v: NpVar, args: varargs[untyped]): untyped =
  ## Syntax suger to call a "callable" variable, aka method bind, closure, or class.
  ## Support automatic value conversion.
  if v of nnkSym or args.len == 0:
    result = newCall(newTree(nnkAccQuoted, ident("call")), v)
    for i in args:
      result.add quote do: `v`.vm -> `i`
  else:
    # v maybe a series of call instead of a simple symbol
    # avoid evaluating it repeatedly
    var sym = genSym()
    result = newStmtList()
    result.add quote do:
      let `sym` = `v`

    result.add newCall(newTree(nnkAccQuoted, ident("call")), sym)
    for i in args:
      result[^1].add quote do: `sym`.vm -> `i`

macro `()`*(x: untyped, vm: NpVm, args: varargs[untyped]): untyped =
  ## Fix compile error to call vm.list or vm.map, etc.
  if x of nnkSym and x.getImpl of nnkIdentDefs:
    var fn = bindSym(strlit(x))
    result = newCall(fn, vm)

  else:
    result = newCall(x, vm)

  for i in args:
    result.add i

macro `.()`*(v: NpVar, attr: untyped, args: varargs[untyped]): untyped =
  ## Syntax suger to call a method of a object.
  ## Support automatic value conversion.
  if v of nnkSym or args.len == 0:
    result = newCall(newTree(nnkAccQuoted, ident("call")), v, strlit(attr))
    for i in args:
      result.add quote do: `v`.vm -> `i`

  else:
    # v maybe a series of call instead of a simple symbol
    # avoid evaluating it repeatedly
    var sym = genSym()
    result = newStmtList()
    result.add quote do:
      let `sym` = `v`

    result.add newCall(newTree(nnkAccQuoted, ident("call")), sym, strlit(attr))
    for i in args:
      result[^1].add quote do: `sym`.vm -> `i`

proc class*(v: NpVar): NpVar =
  ## Get a class object of a variable.
  assert(v.vm != nil)
  v.vm[0] = v
  v.vm.pkGetClass(0, 0)
  result = v.vm[0]

proc isNull*(v: NpVar): bool =
  ## Check a variable is null or not.
  result = v of NpNull

proc isNil*(v: NpVar): bool =
  ## Check a variable is null or not.
  result = v of NpNull

proc this*(v: NpVar): pointer =
  ## Get native pointer of a instance, return nil if there is no native pointer.
  assert(v.vm != nil)
  if not (v of NpInstance):
    raise newException(NimPkError, "Expected a 'Instance'")

  v.vm[0] = v
  result = v.vm.pkGetSlotNativeInstance(0)

proc native*(v: NpVar): pointer =
  ## Get native pointer of a instance, return nil if there is no native pointer.
  ## Alias for `this` to avoid name conflict to injected `this` pointer.
  result = v.this()

template `.`*(v: NpVar, attr: untyped): NpVar =
  ## Syntax sugar to get the attribute.
  `{}`(v, astToStr(attr))

template `.=`*[T](v: NpVar, attr: untyped, x: T) =
  ## Syntax sugar to set the attribute.
  `{}=`(v, astToStr(attr), x)

template `.`*(vm: NpVm, attr: untyped): NpVar =
  ## Syntax sugar to get the builtin function.
  `{}`(vm, astToStr(attr))

macro `.()`*(vm: NpVm, attr: untyped, args: varargs[untyped]): untyped =
  ## Syntax sugar to call a builtin function or class.
  ## Support automatic value conversion.
  var fn = newCall(newTree(nnkAccQuoted, ident("{}")), vm, strlit(attr))
  result = newCall("call", fn)
  for i in args:
    result.add newCall(vm, i)

proc `$`*(v: NpVar): string =
  ## Convert any variable to a string.
  assert(v.vm != nil)
  case v.np.kind
    of NpBool: result = $(bool v)
    of NpString: result = string v
    of NpNull: result = "null"
    else: # call builtin str fn for any other type, even for number
      result = string call(v.vm{"str"}, v)

proc list*(vm: NpVm, L: Natural = 0): NpVar =
  ## Create a new list.
  vm.pkReserveSlots(1)
  vm.pkNewList(0)
  result = vm[0]
  if L != 0:
    result.resize(L)

proc list*[T](vm: NpVm, s: set[T]): NpVar =
  ## Create a new list from set.
  result = vm.list()
  for i in s:
    result.add i

proc list*(vm: NpVm, t: tuple, valueOnly = true): NpVar =
  ## Create a new list from tuple.
  result = vm.list()
  for name, value in t.fieldPairs:
    if valueOnly:
      result.add value
    else:
      result.add [vm name, vm value]

proc list*(vm: NpVm, o: object, valueOnly = false): NpVar =
  ## Create a new list from object.
  result = vm.list()
  for key, val in o.fieldPairs:
    if valueOnly:
      result.add val
    else:
      result.add [vm key, vm val]

proc map*(vm: NpVm): NpVar =
  ## Create a new map.
  vm.pkReserveSlots(1)
  vm.pkNewMap(0)
  result = vm[0]

proc map*[T](vm: NpVm, s: set[T]): NpVar =
  ## Create a new map from set.
  result = vm.map()
  for i in s:
    result[i] = vm.null

proc map*(vm: NpVm, t: tuple): NpVar =
  ## Create a new map from tuple.
  result = vm.map()
  for name, value in t.fieldPairs:
    result[name] = value

proc map*(vm: NpVm, o: object): NpVar =
  ## Create a new map from object.
  result = vm.map()
  for key, val in o.fieldPairs:
    result[key] = val

proc toList(v: NpVar): NpVar =
  if v of NpList: return v

  # cache the compiled closure in bulitin lang module.
  var toList: NpVAr
  try:
    toList = v.vm["lang"]{"`@`"}

  except NimPkError:
    toList = v.vm{"compile"}("""
      return fn(a)
        list = []
        for i in a
          list.append i
        end
        return list
      end
    """)()
    v.vm["lang"]{"`@`"} = toList

  finally:
    result = toList(v)

iterator items*(v: NpVar): NpVar =
  ## The default items iterator for a NpVar object.
  assert(v.vm != nil)
  var list = toList(v)
  for i in 0..<list.len:
    yield list[i]

iterator pairs*(v: NpVar): (NpVar, NpVar) =
  ## The default pairs iterator for a NpVar object.
  assert(v.vm != nil)
  var list = toList(v)
  for i in 0..<list.len:
    let key = list[i]
    yield (key, v[key])

proc `==`*(a: NpVAr, b: NpVAr): bool =
  ## Returns true if both variables are equal.
  assert(a.vm != nil)

  # cache the compiled closure in bulitin lang module.
  var eqeq: NpVAr
  try:
    eqeq = a.vm["lang"]{"`==`"}

  except NimPkError:
    eqeq = a.vm{"compile"}("""
      return fn(a, b)
        return a == b
      end
    """)()
    a.vm["lang"]{"`==`"} = eqeq

  finally:
    result = eqeq(a, b)

template getArgs(vm: NpVm): untyped =
  var args {.inject, used.}: seq[NpVar]
  args.setLen(vm.pkGetArgc())
  for i in 0..<args.len:
    args[i] = vm[i + 1]

proc paramsStandardize(params: NimNode): NimNode =
  # convert (a, b: int) into (a: int; b: int)
  result = newNimNode(nnkFormalParams)
  for n in params:
    if n of nnkIdentDefs:
      for i in 0..<n.len-2:
        result.add newTree(nnkIdentDefs, n[i], n[^2], n[^1])
    else:
      result.add n

proc addProcImpl(x: NimNode, fns: NimNode, rename: NimNode, isMethod: NimNode): NimNode =
  # helper function to add nim proc into x (vm, module, or class)
  # a glue proc will be created and pass into addFn or addMethod
  # fns should be ClosedSymChoice, even there is only one procdef
  fns.expectKind(nnkClosedSymChoice)

  var
    glue = newStmtList()
    paramsList = newStmtList()
    docs: string

  proc addBlock(fnImpl: NimNode, vararg = newStmtList()) =
    # add a block for every proc
    # for generic proc, add block for every possible types

    if not (fnImpl of {nnkProcDef, nnkLambda, nnkFuncDef}):
      # support only proc or lambda, ignore template or macros, etc
      return

    var
      params = fnImpl.params.paramsStandardize()
      body = fnImpl.body
      atleast = 0
      atleastSym = ident("atleast") # enclosed in block, no need genSym(nskVar)
      call = newCall(fnImpl.name)
      vardef, varset = newStmtList()
      vararg = vararg
      genericParams: NimNode

    # collect generic ident, e.g. T, U
    if fnImpl.len > 5 and fnImpl[5].len > 1 and fnImpl[5][1] of nnkGenericParams:
      genericParams = fnImpl[5][1]

    # extract docstring
    if body of nnkCommentStmt:
      docs.add body.strVal.strip()
      docs.add "\n\n"

    elif body of nnkStmtList and body.len >= 1 and body[0] of nnkCommentStmt:
      docs.add body[0].strVal.strip()
      docs.add "\n\n"

    # for every parameters, create `var pn` and `pn = to[typeof pn](args[n])`
    var indexDiff = 0
    for i in 1..<params.len:
      var
        name = ident("p" & $(i-1))
        typ = params[i][1]
        default = params[i][2]
        index = i - 1 - indexDiff

      # parameter can be typeof(NpVm)
      # in this case, pass vm to it, and skip this parameter.
      if typ of nnkSym and typ.eqIdent("NpVm"):
        call.add ident"vm"
        indexDiff.inc
        continue

      call.add name

      # convert `var Type` to `Type`
      if typ of nnkVarTy:
        typ = typ[0]
        # if parameter is var type, the value can be changed in proc
        vararg.add quote do:
          cast[ref (typeof `name`)](args[`index`].native)[] = `name`

      # deal with generic proc
      if not (typ of nnkEmpty):
        var typImpl = typ.getTypeImpl()
        # e.g. test[T: string|int](a: T)
        # typImpl get `Sym "T"` here, convert it to `or[int, string]` and then continue
        if typImpl of nnkSym:
          for g in genericParams:
            if typImpl.eqIdent(g[0]):
              if g[1] of {nnkIdent, nnkEmpty}: return
              typImpl = g[1].getType

        # e.g. test(a: string|int), typImpl get `or[int, string]`
        if typImpl of nnkBracketExpr and typImpl.len >= 1 and typImpl[0].eqIdent("or"):
          for j in 1..<typImpl.len:
            # generate a new call for every type and then add block for it
            params[i][1] = typImpl[j]
            fnImpl.params = params
            addBlock(fnImpl, vararg)
          return

      # deal with varargs, consume all the rest parameters and then break
      if typ of nnkBracketExpr and typ.len >= 2 and typ[0].eqIdent("varargs"):
        typ = typ[1]
        vardef.add quote do:
          var `name`: seq[`typ`]
        varset.add quote do:
          mixin to # call custom to[T]() proc is possible
          for i in `index`..<args.len:
            `name`.add to[typeof `name`[0]](args[i])
        break

      # e.g. a: int
      if not(typ of nnkEmpty) and default of nnkEmpty:
        atleast.inc
        vardef.add quote do:
          var `name`: `typ`
        varset.add quote do:
          mixin to # call custom to[T]() proc is possible
          `name` = to[typeof `name`](args[`index`])

      # e.g. a = 10
      elif typ of nnkEmpty and not(default of nnkEmpty):
        vardef.add quote do:
          var `name` = `default`

          # for default(NpVar), replace it to vm.null
          when `name` is NpVar:
            if isOk(`name`.vm) == false: `name` = vm.null

        varset.add quote do:
          mixin to # call custom to[T]() proc is possible
          if args.len > `index`: `name` = to[typeof `name`](args[`index`])

      # e.g. a: int = 10
      elif not(typ of nnkEmpty) and not(default of nnkEmpty):
        # for generic parameter with default value, the type may be inconsistent
        vardef.add quote do:
          when typeof(`default`) is `typ`:
            var `name`: `typ` = `default`
          else:
            `atleastSym`.inc
            var `name`: `typ`

          # for default(NpVar), replace it to vm.null
          when `name` is NpVar:
            if isOk(`name`.vm) == false: `name` = vm.null

        varset.add quote do:
          mixin to # call custom to[T]() proc is possible
          if args.len > `index`: `name` = to[typeof `name`](args[`index`])

    # for debug message
    paramsList.add params

    var run = if params[0] of nnkEmpty:
      quote do:
        `call`
        `vararg`
        return vm.null

    else:
      quote do:
        result = vm->`call`
        when result is NpVar:
          if result.vm.isNil:
            result = vm.null
        `vararg`
        return result

    glue.add quote do:
      block:
        var `atleastSym` = `atleast`
        `vardef`

        if args.len >= `atleastSym`:
          let ok =
            try:
              `varset`
              true
            except:
              false

          if ok: `run`

  # end of addBlock, addProcImpl start from here

  var
    name = $fns
    rename = if rename.eqIdent(""): name else: rename.strVal
    isMethod = isMethod.eqIdent("true")

  # for a method, first parameter is `self`
  if isMethod:
    glue.add quote do:
      args.insert(self)

  # not return yet, there is no suitable procdef to call
  for fn in fns:
    addBlock(fn.getImpl())

  when defined(release):
    glue.add quote do:
      raise newException(NimPkError,
        "Incorrect arguments to call '" & `rename` & "'")

  else:
    var msg = indent(strip(repr paramsList), 1, "  " & rename)
    glue.add quote do:
      var msg = `msg`
      msg.add "\n\nbut got:\n  " & `rename` & "("
      for i in 0..<args.len:
        if i != 0: msg.add ", "
        msg.add $args[i].kind
      msg.add ")"

      raise newException(NimPkError,
        "Incorrect arguments to call '" & `rename` & "', expect:\n" & msg & "\n")

  result = newStmtList()
  if isMethod:
    result.add newCall("addMethod", x, strlit(rename), strlit(docs.strip()), glue)
  else:
    result.add newCall("addFn", x, strlit(rename), strlit(docs.strip()), glue)

proc addProcSymChoice(x: NimNode, fn: NimNode, rename: NimNode, isMethod: NimNode): NimNode =
  if fn of nnkClosedSymChoice:
    result = addProcImpl(x, fn, rename, isMethod)

  # elif fn of nnkSym and fn.strVal.startsWith ":anonymous":
  #   # anonymous generated by genSym, no overloaded
  #   result = addProcImpl(x, newTree(nnkClosedSymChoice, fn), rename, isMethod)

  elif fn of nnkLambda:
    # lambda proc, no overloaded
    result = addProcImpl(x, newTree(nnkClosedSymChoice, fn[0]), rename, isMethod)

  else:
    # sometimes, even if there are overloaded procs, typed fn still get nnkSym
    # instead of nnkClosedSymChoice (compiler bug?), for example:
    # proc test(a: int), proc test(a: string) => typed fn get nnkClosedSymChoice
    # proc test(a: int), proc test(a: var string) => typed fn get nnkSym
    #
    # here is a solution: creating a macro on compile time, the macro calls `bindSym("test")`
    # and then the result is always nnkClosedSymChoice for overloaded procs.
    var
      name = fn.strVal
      macroName = genSym(nskMacro)

    result = quote do:
      macro `macroName`(x: untyped, fn: untyped, rename, isMethod): untyped =
        var f = bindSym(`name`)
        if f of nnkClosedSymChoice:
          result = addProcImpl(x, f, rename, isMethod)

        elif f.getImpl() of {nnkProcDef, nnkLambda, nnkFuncDef}: # for non-overloaded proc
          result = addProcImpl(x, newTree(nnkClosedSymChoice, f), rename, isMethod)

        else:
          error(fmt"Expects a proc here, get '" & $f & "'.")

      `macroName`(`x`, `fn`, `rename`, `isMethod`)

proc addModule*(vm: NpVm, module: string): NpVar {.discardable.} =
  ## Add a new module to the vm.
  var handle = vm.pkNewModule(cstring module)
  vm.pkRegisterModule(handle)
  discard vm.pkModuleInitialize(handle) # must not fail
  result = NpVar(vm: vm, np: npObject(NpModule, handle))

template addFn*(vm1: NpVm, name: string, doc: static[string], body: untyped) =
  ## Add a builtin function to the vm with a static docstring.

  # define all proc to cdecl to avoid illegible variable capture error
  proc fn(vm2: NpVm): auto {.cdecl, gensym.} =
    let vm {.inject, used.} = vm2
    getArgs(vm2)
    try:
      body
    except:
      vm2.pkSetRuntimeError(cstring getCurrentException().msg)

  proc wrap(pkvm: ptr PkVM) {.cdecl, gensym.} =
    when not defined(gcDestructors):
      GC_disable()

    let vm3 {.used.} = getVm(pkvm)
    when compiles(fn(vm3).type):
      vm3[0] = vm3->fn(vm3)
    else: # no return type
      fn(vm3)
      vm3.pkSetSlotNull(0)

    when not defined(gcDestructors):
      GC_enable()

  vm1.pkRegisterBuiltinFn(cstring name, wrap, -1, doc)

macro addFn*(vm: NpVm, fn: untyped, rename = ""): untyped =
  ## Add nim proc as a builtin function to the vm.
  ## Parameters of nim proc can be `NpVm` to pass the vm.
  result = addProcSymChoice(vm, fn, rename, ident"false")

macro addFn*(vm: NpVm, name: string, fn: proc): untyped =
  ## This is a overloaded addFn macro to support lambda proc.
  result = addProcSymChoice(vm, fn, name, ident"false")

template addFn*(module0: NpVar, name: string, doc: static[string], body: untyped) =
  ## Add a new function to the module with a static docstring.

  # don't let module = module0 here becasue body may use `module0`
  proc fn(vm2: NpVm): auto {.cdecl, gensym.} =
    let vm {.inject, used.} = vm2
    getArgs(vm2)
    try:
      body
    except:
      vm2.pkSetRuntimeError(cstring getCurrentException().msg)

  proc wrap(pkvm: ptr PkVM) {.cdecl, gensym.} =
    when not defined(gcDestructors):
      GC_disable()

    let vm3 {.used.} = getVm(pkvm)
    when compiles(fn(vm3).type):
      vm3[0] = vm3->fn(vm3)
    else: # no return type
      fn(vm3)
      vm3.pkSetSlotNull(0)

    when not defined(gcDestructors):
      GC_enable()

  # let module = module0
  # the compile "=sink" here wrong, then module `wasMoved` by missing.
  # however, module0 should not moved because it may use in body
  var module: NpVar
  `=copy`(module, module0)
  module.vm.pkModuleAddFunction(handle(module), cstring name, wrap, -1, doc)

macro addFn*(module: NpVar, fn: untyped, rename = ""): untyped =
  ## Add nim proc as a new function to the module.
  ## Parameters of nim proc can be `NpVm` to pass the vm.
  result = addProcSymChoice(module, fn, rename, ident"false")

macro addFn*(module: NpVar, name: string, fn: proc): untyped =
  ## This is a overloaded addFn macro to support lambda proc.
  result = addProcSymChoice(module, fn, name, ident"false")

proc addSource*(module: NpVar, source: string) =
  ## Add script code into the module and then initialize (run) it.
  assert(module of NpModule)
  let vm = module.vm
  vm.pkModuleAddSource(handle(module), cstring source)
  if not vm.pkModuleInitialize(handle(module)): reraise0(vm)

template addClass*(module0: NpVar, name: string, base: NpVar, doc: static[string],
    ctor: untyped, dtor: untyped): NpVar =
  ## Add a class to the module with a static docstring, ctor, and dtor.
  ## If the `base` is vm.null by default it'll set to Object class
  # module0 may be expression instead of symbol
  let module = module0
  assert(module of NpModule)
  let vm1 {.used.} = module.vm

  proc ctorfn(pkvm: ptr PkVM): pointer {.cdecl, genSym.} =
    let vm {.inject, used.} = getVm(pkvm)
    try:
      ctor
    except:
      vm.pkSetRuntimeError(cstring getCurrentException().msg)

  proc dtorfn(pkvm: ptr PkVM, this: pointer) {.cdecl, genSym.} =
    let vm {.inject, used.} = getVm(pkvm)
    let this {.inject, used.} = this
    # A strange bug:
    #   `addClass` used in `addType` macro cannot catch `this`,
    #    but `this2` works.
    let this2 {.inject, used.} = this
    try:
      dtor
    except:
      discard # nothing to do if error occurs

  var cls = vm1.pkNewClass(cstring name, handle(base), handle(module), ctorfn, dtorfn, doc)
  discardable NpVar(vm: vm1, np: npObject(NpClass, cls))

template addClass*(module0: NpVar, name: string, base: NpVar, doc: static[string]): NpVar =
  ## Add a class to the module with a static docstring, but no ctor or dtor.
  ## If the `base` is vm.null by default it'll set to Object class
  # module0 may be expression instead of symbol
  let module = module0
  assert(module of NpModule)
  let vm = module.vm
  var cls = vm.pkNewClass(cstring name, handle(base), handle(module), nil, nil, doc)
  discardable NpVar(vm: vm, np: npObject(NpClass, cls))

template addMethod*(class0: NpVar, name: string, doc: static[string], body: untyped) =
  ## Add a method to the class with a static docstring.
  # class0 may be expression instead of symbol
  let class = class0
  assert(class of NpClass)

  proc fn(vm2: NpVm): auto {.cdecl, gensym.} =
    let vm {.inject, used.} = vm2
    let this {.inject, used.} = vm.pkGetSelf()
    getArgs(vm2)
    vm.pkPlaceSelf(0)
    let self {.inject, used.} = vm[0]
    try:
      template super(superargs: varargs[NpVar]) {.used.} =
        var superfn: NpVar
        let parent = self{"_class"}{"parent"}
        try:
          superfn = parent{name}.bind(self)
        except:
          raise newException(NimPkError,
            "'" & parent{"name"} & "' class has no method named '" & name & "'")

        superfn(superargs)

      body
    except:
      vm2.pkSetRuntimeError(cstring getCurrentException().msg)

  proc wrap(pkvm: ptr PkVM) {.cdecl, gensym.} =
    when not defined(gcDestructors):
      GC_disable()

    let vm3 {.used.} = getVm(pkvm)
    when compiles(fn(vm3).type):
      vm3[0] = vm3->fn(vm3)
    else: # no return type
      fn(vm3)
      vm3.pkSetSlotNull(0)

    if name == "_init": # always return self for _init
      vm3.pkPlaceSelf(0)

    when not defined(gcDestructors):
      GC_enable()

  class.vm.pkClassAddMethod(handle(class), cstring name, wrap, -1, doc)

macro addMethod*(class: NpVar, fn: untyped, rename = ""): untyped =
  ## Add nim proc as a method to specified class.
  ## Parameters of nim proc can be `NpVm` to pass the vm.
  ## First parameter except `NpVm` will be `self`,
  ## it should correspond to the nim type of the class.
  result = addProcSymChoice(class, fn, rename, ident"true")

macro addMethod*(class: NpVar, name: string, fn: proc): untyped =
  ## This is a overloaded addMethod macro to support lambda proc.
  result = addProcSymChoice(class, fn, name, ident"true")

template addType*(module0: NpVar, typ: typedesc, rename = "", doc: static[string] = ""): untyped =
  ## Add any nim type as a class into specified module.
  # module0 may be expression instead of symbol
  let module = module0
  assert(module of NpModule)
  let name = if rename == "": $typ else: rename
  type T = ref typ
  var class = addClass(module, name, vm.null, doc) do:
    var r: T
    new(r)
    when typ is ref:
      new(r[])
    GC_ref(r)
    return cast[pointer](r)

  do:
    var r = cast[T](this2)
    GC_unref(r)

  class{"_nimid"} = getTypeId(typ)
  when not defined(release):
    class{"_nimtype"} = getTypeDesc(typ)

  when typ is enum:
    for i in typ:
      class{$i} = ord i

  discardable class

template addType*(vm: NpVm, typ: typedesc, rename = ""): untyped =
  ## Add nim type (enum|object|ref) as a class into `lang` module.
  var module = vm.import("lang")
  module.addType(typ, rename)

proc `[]=`*[T](v: NpVar, x: T) =
  ## Set value to instance of nim type binded class.
  let ok = try:
      if v of PkInstance: v.class{"_nimid"} == getTypeId(T)
      else: false
    except: false

  if ok:
    cast[ref T](v.native)[] = x
  else:
    raise newException(NimPkError, "Inconsistent nim type.")

proc run*(vm: NpVm, source: string): NpVar {.discardable.} =
  ## Run the source code with error handling. Convert pocketlang error into nim error.
  var closure = call(vm{"compile"}, vm source)
  result = closure()

proc runString*(vm: NpVm, source: string): PkResult {.discardable.} =
  ## Low-level run source code. No error handling.
  result = vm.pkRunString(cstring source)

proc runFile*(vm: NpVm, path: string): PkResult {.discardable.} =
  ## Low-level run a file. No error handling.
  result = vm.pkRunFile(cstring path)

proc startRepl*(vm: NpVm) =
  ## Run pocketlang REPL mode.
  discard vm.pkRunREPL()

template withNimPkVmConfig*(config: ptr PkConfiguration, body: untyped) =
  ## Start a VM with given config.
  block:
    let vm {.inject, used.} = newVm(config)
    vm.pkReserveSlots(1) # mare sure fiber exists
    vm.pkSetSlotNull(0)
    if true: # avoid compile error if last call has discardable value
      body

template withNimPkVmConfig*(t: typedesc, config: ptr PkConfiguration, body: untyped) =
  ## Start a VM with custom type and given config.
  block:
    let vm {.inject, used.} = newVm(t, config)
    vm.pkReserveSlots(1) # mare sure fiber exists
    vm.pkSetSlotNull(0)
    if true: # avoid compile error if last call has discardable value
      body

template withNimPkVm*(body: untyped) =
  ## Start a vm with default config.
  withNimPkVmConfig(nil, body)

template withNimPkVm*(t: untyped, body: untyped) =
  ## Start a vm with custom type and default config.
  withNimPkVmConfig(t, nil, body)

template exportNimPk*(t: typedesc, name: string, body: untyped) =
  ## Export native code to dynamic library.
  ## Inject `self` as the module object to export.
  ## Inject `vm` of custom type (must be `ref object of NpVm`).
  proc pkExportModule(pkvm: ptr PkVM): ptr PkHandle {.cdecl, exportc, dynlib.} =
    when t is ref and compiles(t() of NpVm):
      let vm {.inject, used.} = t(pkvm: pkvm)
      vm.pkSetUserData(cast[pointer](vm))
      let module = vm.pkNewModule(name)
      vm.pkReserveSlots(1)
      vm.pkSetSlotHandle(0, module)
      let self {.inject, used.} = vm[0]
      try:
        body
      except:
        vm.pkSetRuntimeError(cstring getCurrentException().msg)
      finally:
        return module

    else:
      {.error: "Custom type must be ref object of NpVm.".}

template exportNimPk*(name: string, body: untyped) =
  ## Export native code to dynamic library.
  ## Inject `self` as the module object to export.
  ## Inject `vm` of NpVm.
  exportNimPk(NpVm, name, body)

macro def*(module: NpVar, body: untyped): untyped =
  var doNotationAddFnMap: Table[string, NimNode]
  var doNotationAddMethodMap: Table[string, NimNode]

  ## PocketLang DSL to add source, attributes, and classes to a module.
  result = newStmtList()

  type
    Mode = enum Overwriting, Appending
    BaseKind = enum None, NimType, PkClass

  # avoid repeatedly evaluate `module` if it is not a symbol
  let module = if module of nnkSym:
    module
  else:
    let m = genSym(nskLet, "module")
    result.add quote do:
      let `m` = `module`
    m

  defer:
    # call `addFn` at last
    for name, symbol in doNotationAddFnMap:
      result.add newCall("addFn", module, symbol, strlit(name))

    # wrap all in a block
    result = newBlockStmt(result)

  # var c: NpVar
  var c = ident("c")
  result.add quote do:
    var `c` {.used.}: NpVar

  body.expectKind(nnkStmtList)
  for n in body:
    var n = n

    # base = vm.null
    var
      base = newDotExpr(ident("vm"), ident("null"))
      baseKind = None
      hasbase = false
      nimtype = false

    proc parseBase(m, n: NimNode): NimNode =
      # [base] or ["base"] or [`base`] => m{"base"} (base in the same module)
      if n of nnkBracket and n.len == 1 and n[0] of {nnkIdent, nnkStrLit, nnkAccQuoted}:
        return newTree(nnkCurlyExpr, m, str(n[0]))
      else: # base is any other expr
        return n

    # block: body => nim code
    if n of nnkBlockStmt and n.len == 2:
      result.add n[1]
      continue

    # """ code """ => module.addSource(code)
    elif n of nnkTripleStrLit:
      result.add newCall("addSource", module, n)
      continue

    # + ... => module.addSource(...)
    elif n of nnkPrefix and n.len == 2 and n[0] == ident("+"):
      result.add newCall("addSource", module, n[1])
      continue

    # name or "name" or `name` = value => `{"name"}=`(m, value)
    elif n of nnkAsgn and n[0] of {nnkIdent, nnkStrLit, nnkAccQuoted}:
      result.add newCall(newTree(nnkAccQuoted, ident("{}=")), module, str(n[0]), n[1])
      continue

    # name or "name" or `name`: body => module.addFn("name", doc, body)
    elif n of nnkCall and n.len == 2 and n[0] of {nnkIdent, nnkStrLit, nnkAccQuoted} and
        n[1] of nnkStmtList:

      result.add newCall("addFn", module, str(n[0]), doc(n[1]), n[1])
      continue

    # name => module.addFn(name)
    elif n of nnkIdent:
      result.add newCall("addFn", module, n)
      continue

    # name -> newname or "newname" or `newname` => module.addFn(name, "newname")
    elif n of nnkInfix and n.len == 3 and n[0] == ident("->") and
        n[1] of {nnkIdent, nnkAccQuoted} and
        n[2] of {nnkIdent, nnkStrLit, nnkAccQuoted}:
      result.add newCall("addFn", module, n[1], str(n[2]))
      continue

    # name do: or "name" do: or `name` do: => module.addFn(anonymous, "name")
    elif n of nnkCall and n.len == 2 and n[1] of nnkDo:
      var
        name = $str(n[0])
        symbol = doNotationAddFnMap.mgetOrPut(name,
          ident(repr genSym(nskProc, ":" & name)) # -> this line generate unique symobl
        )
        procdef = newNimNode(nnkProcDef)

      n[1].copyChildrenTo(procdef)
      procdef.name = symbol
      result.add procdef
      continue

    # n `is` base => reformat to n and store the base
    # n `of` type => reformat to n and store the nim type
    elif n of nnkInfix and n.len == 3 and (n[0] == ident("is") or n[0] == ident("of")):
      base = parseBase(module, n[2])
      if n[0] == ident("of"):
        nimtype = true
      else:
        hasbase = true

      baseKind = if n[0] == ident("of"): NimType else: PkClass
      n = n[1]

    # n `is` base: body => reformat to n: body and store the base
    # n `of` type: body => reformat to n: body and store the nim type
    elif n of nnkInfix and n.len == 4 and (n[0] == ident("is") or n[0] == ident("of")) and
        n[3] of nnkStmtList:

      base = parseBase(module, n[2])
      if n[0] == ident("of"):
        nimtype = true
      else:
        hasbase = true

      baseKind = if n[0] == ident("of"): NimType else: PkClass
      n = newTree(nnkCall, n[1], n[3])

    ### after reformating (maybe), restart a new `if branch` ###
    # elif n of nnkCall and n.len == 2 and n[1] of nnkDo:

    # [name] or ["name"] or [`name`] => module.addClass("name", base, doc)
    # [+name] or [+"name"] or [+`name`] => module{"name"} or module.addClass(...)
    # for NimType => module.addType(type, "name")
    if n of nnkBracket and n.len == 1 and
        (n[0] of {nnkIdent, nnkStrLit, nnkAccQuoted} or
        deprefix(n[0], "+") of {nnkIdent, nnkStrLit, nnkAccQuoted}):

      let mode =
        if n[0] of {nnkIdent, nnkStrLit, nnkAccQuoted}: Overwriting
        else: Appending

      case baseKind
      of NimType:
        case mode
        of Overwriting:
          result.add newCall("addType", module, base, str(n[0]))

        of Appending:
          var name = str(n[0][1])
          result.add quote do:
            let hascls = try: discard `module`{`name`}; true except: false
            if hascls: raise newException(NimPkError,
              "Cannot reassign nim type to '" & `name` & "'.")
            else: addType(`module`, `base`, `name`)

      of PkClass, None:
        case mode
        of Overwriting:
          result.add newCall("addClass", module, str(n[0]), base, strlit(""))

        of Appending:
          var name = str(n[0][1])
          if baseKind == PkClass:
            result.add quote do:
              let hascls = try: discard `module`{`name`}; true except: false
              if hascls: raise newException(NimPkError,
                "Cannot reassign base to '" & `name` & "'.")
              else: addClass(`module`, `name`, `base`, "")
          else:
            result.add quote do:
              try: discard `module`{`name`}
              except NimPkError: addClass(`module`, `name`, `base`, "")

    # [name]: or ["name"] or [`name`]: => c = module.addClass("name", base, doc, [, ctor, dtor])
    # [+name]: or [+"name"] or [+`name`]: => c = module{""} or module.addClass(...)
    # for NimType => module.addType(type, "name")
    elif n of nnkCall and n.len == 2 and n[0] of nnkBracket and
        n[1] of nnkStmtList and n[0].len == 1 and
        (n[0][0] of {nnkIdent, nnkStrLit, nnkAccQuoted} or
        deprefix(n[0][0], "+") of {nnkIdent, nnkStrLit, nnkAccQuoted}):

      var
        ctor, dtor: NimNode
        discardStmt = newStmtList(newTree(nnkDiscardStmt, newNimNode(nnkEmpty)))
        clsdoc = doc(n[1])

        mode =
          if n[0][0] of {nnkIdent, nnkStrLit, nnkAccQuoted}: Overwriting
          else: Appending

        classname = case mode
          of Overwriting: str(n[0][0])
          of Appending: str(n[0][0][1])

      # find custom ctor and dtor, notice: find ident only (e.g.: "ctor" is method)
      for n in n[1]:
        if n of nnkCall and n.len == 2 and n[0] of nnkIdent and n[1] of nnkStmtList:
          case n[0].strVal
          of "ctor": ctor = n[1]
          of "dtor": dtor = n[1]
          else: discard

      if ctor.isNil: ctor = discardStmt
      if dtor.isNil: dtor = discardStmt

      case baseKind
      of NimType:
        if ctor != discardStmt or dtor != discardStmt:
          error("Custom ctor and dtor are not allowed in nim type binding.")

        case mode
        of Overwriting:
          result.add quote do: `c` = addType(`module`, `base`, `classname`, `clsdoc`)

        of Appending:
          result.add quote do:
            let hascls = try: discard `module`{`classname`}; true except: false
            if hascls: raise newException(NimPkError,
              "Cannot reassign nim type to '" & `classname` & "'.")
            else: `c` = addType(`module`, `base`, `classname`, `clsdoc`)

      of None, PkClass:
        var addast = # if there are no ctor and dtor, avoid to create empty proc
          if ctor == discardStmt and dtor == discardStmt: quote do:
            addClass(`module`, `classname`, `base`, `clsdoc`)
          else: quote do:
            addClass(`module`, `classname`, `base`, `clsdoc`, `ctor`, `dtor`)

        case mode
        of Overwriting:
          result.add quote do:
            `c` = `addast`

        of Appending:
          if baseKind == PkClass or
              ctor != discardStmt or
              dtor != discardStmt or
              clsdoc.strVal != "":

            result.add quote do:
              let hascls = try: discard `module`{`classname`}; true except: false
              if hascls: raise newException(NimPkError,
                "Cannot reassign base, ctor, dtor, or docstring to '" & `classname` & "'.")
              else: `c` = `addast`

          else:
            result.add quote do:
              `c` = try: `module`{`classname`}
                except NimPkError:
                  `addast`

      # deal with class methods
      doNotationAddMethodMap.clear()

      # call `addMethod` at last
      defer:
        for name, symbol in doNotationAddMethodMap:
          result.add newCall("addMethod", ident("c"), symbol, strlit(name))

      for n in n[1]:
        # block: body => nim code
        if n of nnkBlockStmt and n.len == 2:
          result.add n[1]
          continue

        # skip ctor and dtor
        if n of nnkCall and n.len == 2 and n[0] of nnkIdent and n[1] of nnkStmtList and
          n[0].strVal in ["ctor", "dtor"]: continue

        # name or "name" or `name` = value => `{}=`(c, "name", value)
        if n of nnkAsgn and n[0] of {nnkIdent, nnkStrLit, nnkAccQuoted}:
          result.add newCall(newTree(nnkAccQuoted, ident("{}=")), ident("c"), str(n[0]), n[1])

        # name or "name" or `name`: body => c.addMethod("name", doc, body)
        elif n of nnkCall and n.len == 2 and
            n[0] of {nnkIdent, nnkStrLit, nnkAccQuoted} and n[1] of nnkStmtList:
          result.add newCall("addMethod", ident("c"), str(n[0]), doc(n[1]), n[1])

        # name => c.addMethod(name)
        elif n of nnkIdent:
          result.add newCall("addMethod", ident("c"), n)

        # name -> newname or "newname" or `newname` => c.addMethod(name, "rename")
        elif n of nnkInfix and n.len == 3 and n[0] == ident("->") and
            n[1] of {nnkIdent, nnkAccQuoted} and
            n[2] of {nnkIdent, nnkStrLit, nnkAccQuoted}:

          # result.add newCall("addMethod", ident("c"), n[1], n[2])
          let
            sym = n[1]
            name = str(n[2])

          result.add quote do: addMethod(`c`, `sym`, `name`)

        # name do: or "name" do: or `name` do: => c.addMethod(anonymous, "name")
        elif n of nnkCall and n.len == 2 and n[1] of nnkDo:
          var
            name = $str(n[0])
            symbol = doNotationAddMethodMap.mgetOrPut(name,
              ident(repr genSym(nskProc, ":" & name)) # -> this line generate unique symobl
            )
            procdef = newNimNode(nnkProcDef)

          n[1].copyChildrenTo(procdef)
          procdef.name = symbol
          result.add procdef

        elif not (n of {nnkCommentStmt, nnkDiscardStmt}):
          error(fmt"I don't know how to parse '{repr n}' here.")

    elif not (n of {nnkCommentStmt, nnkDiscardStmt}):
      error(fmt"I don't know how to parse '{repr n}' here.")

macro def*(vm: NpVm, body: untyped): untyped =
  ## PocketLang DSL to add builtin functions and modules to the vm.
  var doNotationAddFnMap: Table[string, NimNode]
  result = newStmtList()

  defer:
    # call `addFn` at last
    for name, symbol in doNotationAddFnMap:
      result.add newCall("addFn", vm, symbol, strlit(name))

    # wrap all in a block
    result = newBlockStmt(result)

  # var m: NpVar
  var m = ident("m")
  result.add quote do:
    var `m` {.used.}: NpVar

  body.expectKind(nnkStmtList)
  for n in body:
    # block: body => nim code
    if n of nnkBlockStmt and n.len == 2:
      result.add n[1]

    # """ code """ => vm.run(code)
    elif n of nnkTripleStrLit:
      result.add newCall("run", vm, n)

    # + ... => vm.run(...)
    elif n of nnkPrefix and n.len == 2 and n[0] == ident("+"):
      result.add newCall("run", vm, n[1])

    # name or "name" or `name`: body => vm.addFn("name", doc, body)
    elif n of nnkCall and n.len == 2 and
        n[0] of {nnkIdent, nnkStrLit, nnkAccQuoted} and n[1] of nnkStmtList:
      result.add newCall("addFn", vm, str(n[0]), doc(n[1]), n[1])

    # name => vm.addFn(name)
    elif n of nnkIdent:
      result.add newCall("addFn", vm, n)

    # name -> newname or "newname" or `newname` => vm.addFn(name, "newname")
    elif n of nnkInfix and n.len == 3 and n[0] == ident("->") and
        n[1] of {nnkIdent, nnkAccQuoted} and
        n[2] of {nnkIdent, nnkStrLit, nnkAccQuoted}:
      result.add newCall("addFn", vm, n[1], str(n[2]))

    # name do: or "name" do: or `name` do: => vm.addFn(anonymous, "name")
    elif n of nnkCall and n.len == 2 and n[1] of nnkDo:
      # let anonymous proc of do notation can be overloaded
      #  1. must be in the same def macro section
      #  2. the same name produce the same unique symbol
      #  3. call `addFn` at last of the macro so that it can use the overloaded procs
      var
        name = $str(n[0])
        symbol = doNotationAddFnMap.mgetOrPut(name,
          ident(repr genSym(nskProc, ":" & name)) # -> this line generate unique symobl
        )
        procdef = newNimNode(nnkProcDef)

      n[1].copyChildrenTo(procdef)
      procdef.name = symbol
      result.add procdef

    # [name] or ["name"] or [`name`] => vm.addModule("name")
    # [+name] or [+"name"] or [+`name`] => vm.import("name") or vm.addModule("name")
    elif n of nnkBracket and n.len == 1 and
        (n[0] of {nnkIdent, nnkStrLit, nnkAccQuoted} or
        deprefix(n[0], "+") of {nnkIdent, nnkStrLit, nnkAccQuoted}):

      if n[0] of {nnkIdent, nnkStrLit, nnkAccQuoted}:
        result.add newCall("addModule", vm, str(n[0]))
      else:
        var name = str(n[0][1])
        result.add quote do:
          try: discard vm.import(`name`)
          except NimPkError: discard vm.addModule(`name`)

    # [name]: or ["name"] or [`name`]: => m = vm.addModule("name")
    # [+name]: or [+"name"] or [+`name`]: => m = vm.import("name") or vm.addModule("name")
    elif n of nnkCall and n.len == 2 and n[0] of nnkBracket and
        n[1] of nnkStmtList and n[0].len == 1 and
        (n[0][0] of {nnkIdent, nnkStrLit, nnkAccQuoted} or
        deprefix(n[0][0], "+") of {nnkIdent, nnkStrLit, nnkAccQuoted}):

      var body = n[1]
      if n[0][0] of {nnkIdent, nnkStrLit, nnkAccQuoted}:
        var name = str(n[0][0])
        result.add quote do:
          `m` = addModule(vm, `name`)
          def(`m`, `body`)

      else:
        var name = str(n[0][0][1])
        result.add quote do:
          `m` = try: vm.import(`name`)
            except NimPkError: addModule(vm, `name`)
          def(`m`, `body`)

    elif not (n of {nnkCommentStmt, nnkDiscardStmt}):
      error(fmt"I don't know how to parse '{repr n}' here.")
