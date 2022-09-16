#====================================================================
#
#             NimPK - PocketLang Binding for Nim
#                  Copyright (c) 2022 Ward
#
#====================================================================

{.experimental: "callOperator".}

import std/options
import pkg/bigints
import nimpk

type
  MyVm = ref object of NpVm
    bigintCls: NpVar

exportNimPk(MyVm, "bigints"):

  proc new(vm: NpVm, bi: BigInt): NpVar =
    result = (MyVm vm).bigintCls()
    result[] = bi

  self.def:
    [BigInt] of BigInt:
      block:
        vm.bigintCls = self{"BigInt"}

      "_init" do (self: var BigInt, v = NpNil, base = 10):
        if v of NpString:
          self = initBigInt(string v, base)
        elif v of NpNumber:
          self = initBigInt(int64 v)
        elif v of NpNull:
          self = initBigInt(0)
        elif v of NpInstance:
          self = initBigInt(to[BigInt](v))

      "_str" do (self: BigInt, base = 10) -> string:
        result = toString(self, base)

      abs do (self: BigInt) -> BigInt: abs(self)
      "==" do (self: BigInt, other: BigInt) -> bool: self == other
      "<" do (self: BigInt, other: BigInt) -> bool: self < other
      "<=" do (self: BigInt, other: BigInt) -> bool: self <= other
      ">" do (self: BigInt, other: BigInt) -> bool: self > other
      ">=" do (self: BigInt, other: BigInt) -> bool: self >= other
      "-self" do (self: BigInt) -> BigInt: -self

      "+" do (self: BigInt, other: BigInt) -> BigInt: self + other
      "+=" do (self: BigInt, other: BigInt) -> BigInt: self + other
      "-" do (self: BigInt, other: BigInt) -> BigInt: self - other
      "-=" do (self: BigInt, other: BigInt) -> BigInt: self - other
      "*" do (self: BigInt, other: BigInt) -> BigInt: self * other
      "*=" do (self: BigInt, other: BigInt) -> BigInt: self * other
      pow do (self: BigInt, other: Natural) -> BigInt: pow(self, other)
      "shl" do (self: BigInt, other: Natural) -> BigInt: `shl`(self, other)
      "shr" do (self: BigInt, other: Natural) -> BigInt: `shr`(self, other)
      "and" do (self: BigInt, other: BigInt) -> BigInt: `and`(self, other)
      "or" do (self: BigInt, other: BigInt) -> BigInt: `or`(self, other)
      "xor" do (self: BigInt, other: BigInt) -> BigInt: `xor`(self, other)

      "div" do (self: BigInt, other: BigInt) -> BigInt: `div`(self, other)
      "mod" do (self: BigInt, other: BigInt) -> BigInt: `mod`(self, other)

      "divmod" do (vm: NpVm, self: BigInt, other: BigInt) -> NpVar:
        let qr = divmod(self, other)
        result = vm.list(2)
        result[0] = vm.new(qr.q)
        result[1] = vm.new(qr.r)

      inc do (self: var BigInt, n = 1): self.inc(n)
      dec do (self: var BigInt, n = 1): self.dec(n)

      "/" do (self: BigInt, other: BigInt) -> BigInt: `div`(self, other)
      "%" do (self: BigInt, other: BigInt) -> BigInt: `mod`(self, other)
      number do (self: BigInt) -> int32:
        let ret = toInt[int32](self)
        if ret.isNone:
          raise newException(ValueError, "Cannot convert " & $self & " to number.")
        else:
          return ret.get
