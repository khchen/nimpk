#====================================================================
#
#          NimPK - Pocketlang Binding for Nim Language
#               Copyright (c) Chen Kai-Hung, Ward
#
#====================================================================

import ../includes

type
  NpVarType* = enum # must compatible to PkVarType
    NpObject = 0
    NpNull
    NpBool
    NpNumber
    NpString
    NpList
    NpMap
    NpRange
    NpModule
    NpClosure
    NpMethodBind
    NpFiber
    NpClass
    NpInstance

  NpBox* = distinct uint64 # a modified nan-boxing type for nimpk

converter npVarTypeToPkVarType*(x: NpVarType): PkVarType =
  PkVarType x.ord

converter pkVarTypeToNpVarType*(x: PkVarType): NpVarType =
  NpVarType x.ord

const
  MaskQnan =  0x7ff8000000000000'u64
  Payload = 0x0000ffffffffffff'u64

proc `==`*(x, y: NpBox): bool {.borrow.}
proc `and`*(x: NpBox, y: uint64): uint64 {.borrow.}
proc `or`*(x: NpBox, y: uint64): NpBox {.borrow.}

template packEnum(e: NpVarType): NpBox =
  # todo, switch PK_OBJECT and PK_NUMBER ?
  NpBox((e.uint64 shl 48) or (e.uint64 shl 60) or MaskQnan)

template unpackEnum(np: NpBox): NpVarType =
  NpVarType((np.uint64 shr 60 and 0x8) or (np.uint64 shr 48 and 0x7))

const
  NpNil = packEnum(NpNull)
  NpFalse = packEnum(NpBool)
  NpTrue = packEnum(NpBool) or 1

template npNull*: NpBox = NpNil

template npBool*(x: bool): NpBox =
  if x: NpTrue else: NpFalse

template npNumber*(x: SomeNumber|enum): NpBox =
  NpBox(cast[uint64](float64 x))

template npObject*(kind: NpVarType, handle: pointer): NpBox =
  packEnum(kind) or (uint64 cast[uint](handle))

template kind*(np: NpBox): NpVarType =
  if (np and MaskQnan) != MaskQnan: NpNumber
  else: unpackEnum(np)

template isHandle*(np: NpBox): bool =
  np.kind notin {NpObject, NpNull, NpBool, NpNumber}

proc `[]`*(np: NpBox, T: typedesc): T =
  when T is bool:
    np == NpTrue
  elif T is SomeNumber:
    T cast[float64](np)
  elif T is pointer|ptr:
    cast[T](np and Payload)
  else:
    nil

when isMainModule:
  var np = npNull()
  doAssert np.kind == NpNull
  doAssert np.isHandle == false

  np = npBool(false)
  doAssert np.kind == NpBool
  doAssert np[bool] == false
  doAssert np.isHandle == false

  np = npBool(true)
  doAssert np.kind == NpBool
  doAssert np[bool] == true
  doAssert np.isHandle == false

  np = npNumber(0)
  doAssert np.kind == NpNumber
  doAssert np[int] == 0
  doAssert np.isHandle == false

  np = npNumber(3.14)
  doAssert np.kind == NpNumber
  doAssert np[float] == 3.14
  doAssert np.isHandle == false

  np = npObject(NpClass, cast[pointer](cstring "Class"))
  doAssert np.kind == NpClass
  doAssert np.isHandle == true
  doAssert $cast[cstring](np[pointer]) == "Class"

  np = npObject(NpInstance, cast[pointer](cstring "Instance"))
  doAssert np.kind == NpInstance
  doAssert np.isHandle == true
  doAssert $cast[cstring](np[pointer]) == "Instance"
