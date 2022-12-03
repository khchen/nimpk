#====================================================================
#
#             NimPK - PocketLang Binding for Nim
#                  Copyright (c) 2022 Ward
#
#====================================================================

import std/[strutils, strformat]
import nimpk
import nimpk/src

withNimPkVm:
  # Any nim type can be binded as a native class.
  # In vm.def, use `of` to create type-binding class.

  # The instance (NpVar) of the type-binding class can convert to its nim type
  # automatically. In other word, `to`[T]() can convert the instance to
  # corresponding nim type without hook (see tutorial02 for detail).
  type
    Foo = object
      data: string

  vm.def:
    [Module]:
      [Foo] of Foo: # `of` to bind nim type
        "_str" do (self: Foo) -> string:
          return fmt"Foo[{self.data}]"

        "_init" do (self: var Foo, data: string):
          self.data = data

  # Test the class in script.
  vm.run """
    from Module import Foo
    assert str(Foo("test")) == "Foo[test]"
  """

  # Create an instance by script.
  var foo1 = vm.run """
    import Module
    return Module.Foo("hello")
  """

  # Create an instance by nim code.
  var foo2 = vm["Module"]{"Foo"}("world")

  # Test these instances in nim code.
  assert foo1 of NpInstance and foo2 of NpInstance
  assert $foo1 == "Foo[hello]" and $foo2 == "Foo[world]"
  assert to[Foo](foo1).data == "hello" and to[Foo](foo2).data == "world"

  # The underline nim value of NpVar can be modified by dereferencing operator (`[]=`).
  foo1[] = Foo(data: "HELLO")
  foo2[] = Foo(data: "WORLD")
  assert $foo1 == "Foo[HELLO]" and $foo2 == "Foo[WORLD]"

  # Nim value cannot convert to instance of corresponding type-binding class
  # automatically, because the _init method is customizable. A vm.new() proc
  # is necessary.

  # If Foo class has default _init method (_init without paramter), the common
  # vm.new() will look like:
  when false:
    proc new(vm: NpVm, f: Foo): NpVar =
      result = vm["Module"]{"Foo"}() # not works here
      result[] = f # copy the Foo object

  # But in our design, _init of Foo needs one parameter, so it should be:
  proc new(vm: NpVm, f: Foo): NpVar =
    result = vm["Module"]{"Foo"}(f.data)

  vm.def:
    test:
      return Foo(data: "hello")

  vm.run """
    assert str(test()) == "Foo[hello]"
  """

  # ANY nim type can be binded as a native class. No kidding.
  # Here take `char` and `ref char` as another example.
  vm.def:
    [Module]:
      [Char] of char:
        "_init" do (self: var char, c: string): self = c[0]
        "_str" do (self: char) -> string: $self
        "ord" do (self: char) -> int: self.ord
        "==" do (self: char, another: char) -> bool: self == another

        toLowerChar do (vm: NpVm, self: char) -> NpVar:
          result = vm["Module"]{"Char"}(self.toLowerAscii)

        # Bind strutils.toLowerAscii, the default to[T]() convert nim char
        # to PocketLang string.
        toLowerAscii

      # For ref type, `new` will be called automatically in glue code.
      # `self: var ref char`, and then `new(self)` is not necessary.
      [CharRef] of ref char:
        "_init" do (self: ref char, c: string): self[] = c[0]
        "_str" do (self: ref char) -> string: $self[]
        "ord" do (self: ref char) -> int: self[].ord
        "==" do (self: ref char, another: ref char) -> bool: self[] == another[]

        toLowerChar do (vm: NpVm, self: ref char) -> NpVar:
          result = vm["Module"]{"CharRef"}(self[].toLowerAscii)

  vm.run """
    from Module import Char, CharRef
    A = Char("A")
    assert A.ord() == 65
    assert A.toLowerAscii() == "a"
    assert A.toLowerChar() == Char("a")

    B = CharRef("B")
    assert B.ord() == 66
    assert B.toLowerChar() == CharRef("b")
  """

  # If the binded type is an enum, all items in the enum will be added
  # as class member.
  vm.def:
    [Module]:
      [FileMode] of FileMode

  vm.run """
    from Module import FileMode
    assert FileMode.fmAppend == 4
  """
