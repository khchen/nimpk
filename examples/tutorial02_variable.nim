#====================================================================
#
#             NimPK - PocketLang Binding for Nim
#                  Copyright (c) 2022 Ward
#
#====================================================================

import std/[strformat, strutils]
import nimpk
import nimpk/src

withNimPkVm:
  # PocketLang variable are enveloped in nim's NpVar object.
  # Use kind proc or `of` operator to test the kind of a variable.
  vm.def:
    kind do (v: NpVar) -> string:
      assert v of v.kind
      return $v.kind

  # Test all available kind.
  vm.run """
    import lang, io
    assert kind(null)         == "NpNull"
    assert kind(false)        == "NpBool"
    assert kind(0)            == "NpNumber"
    assert kind("")           == "NpString"
    assert kind([])           == "NpList"
    assert kind({})           == "NpMap"
    assert kind(1..2)         == "NpRange"
    assert kind(lang)         == "NpModule"
    assert kind(print)        == "NpClosure"
    assert kind(String.upper) == "NpMethodBind"
    assert kind(Fiber fn end) == "NpFiber"
    assert kind(String)       == "NpClass"
    assert kind(io.File())    == "NpInstance"
  """

  # Nim value => NpVar conversion:
  #   Following nim value can convert to NpVar by vm.new() proc.
  #     string|cstring|char   => NpString
  #     bool                  => NpBool
  #     SomeNumber|enum|range => NpNumber
  #     HSlice                => NpRange
  #     typeof(nil)           => NpNull
  #     array|seq|openarray   => NpList
  assert vm.new("string") of NpString
  assert vm.new(true) of NpBool
  assert vm.new(nil) of NpNull
  assert vm.new(1..2) of NpRange
  assert vm.new([1, 2, 3]) of NpList

  # NpVar => Nim value conversion:
  #   Following NpVar can convert to nim value implicitly (by converter) or
  #   to[T]() proc.
  #     NpBool   => bool
  #     NpNumber => int|float|BiggestInt|BiggestFloat
  #     NpString => string|cstring
  #
  #   Following NpVar can convert to nim value only by to[T]() proc.
  #     NpString => char
  #     NpNumber => SomeNumber|enum|range
  #     NpRange  => HSlice
  #     NpList   => array|seq
  assert vm.new(true).bool == true
  assert vm.new("string").string == "string"
  assert to[string](vm.new("string")) == "string"
  assert to[seq[int]](vm.new([1, 2, 3])) == @[1, 2, 3]

  # For a binded procedure:
  #   Parameters use "NpVar => Nim value" conversion.
  #   Return value use "Nim value => NpVar" conversion.

  # In most case, type conversion for binded procedure is done automatically.
  vm.def:
    # Parameters: NpVar => string ok.
    # Return value: float => NpVar ok.
    test do (x: string) -> float:
      return parseFloat(x)

    # Parameters: NpVar => float ok.
    # Return value: string => NpVar ok.
    test do (x: float) -> string:
      return $x

  vm.run """
    assert test("123.456") == 123.456
    assert test(123.456) == "123.456"
  """

  # If a returned value cannot be converted to NpVar automatically,
  # add a custom vm.new procedure to handle it.
  type
    Foo = object
      data: string

  # A custom vm.new procedure to tell how to convert Foo to NpVar.
  proc new(vm: NpVm, f: Foo): NpVar =
    return vm.new(fmt"Foo[{f.data}]")

  vm.def:
    # Need a custom vm.new to return Foo in binded procedure.
    test2 do (data: string) -> Foo:
      return Foo(data: data)

  vm.run """
    assert test2("test2") == "Foo[test2]"
  """

  # If parameters cannot be converted to nim value automatically,
  # hook `to` proc to handle it.
  proc to[T](v: NpVar): T =
    # Tell how to convert NpVar to Foo.
    when T is Foo:
      result = Foo(data: to[string](v))

    else:
      # Must call builtin to[T]() at last.
      result = nimpk.to[T](v)

  vm.def:
    # Need know how to convert NpVar to Foo and then pass into the binded
    # procedure.
    test3 do (f: Foo) -> string:
      return fmt"Foo[{f.data}]"

  vm.run """
    assert test3("test3") == "Foo[test3]"
  """

  # Another way is to handle NpVar object directly instead of depending on
  # type conversion.
  vm.def:
    # If a parameter in binded procedure is type of NpVm, it will be hidden to
    # script and get the current vm when calling.
    test4 do (vm: NpVm, x: NpVar) -> NpVar:
      if x of NpString:
        return vm.new(parseFloat(x))

      elif x of NpNumber:
        return vm.new($x)

  vm.run """
    assert test4("123.456") == 123.456
    assert test4(123.456) == "123.456"
  """
