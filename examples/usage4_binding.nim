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
  # The instance of the native class can convert to its nim type automatically.
  type
    Foo = object
      data: string

  vm.def:
    [Module]:
      [Foo] of Foo: # `of` to bind nim type
        "_str" do (self: Foo) -> string: # no need to hook `to` proc.
          return fmt"Foo[{self.data}]"

        "_init" do (self: var Foo, data: string):
          self.data = data

  vm.run """
    from Module import Foo
    assert str(Foo("test")) == "Foo[test]"
  """

  # Nim value of binded type cannot convert to corresponding instance
  # automatically. A custom vm.new() proc is necessary.
  proc new(vm: NpVm, f: Foo): NpVar =
    result = vm["Module"]{"Foo"}(f.data) # call _init to create a new instance

  vm.def:
    test:
      return Foo(data: "hello")

  vm.run """
    assert str(test()) == "Foo[hello]"
  """

  # If the binded type is an enum,
  # all items in the enum will be added as class member.
  vm.def:
    [Module]:
      [FileMode] of FileMode

  vm.run """
    from Module import FileMode
    assert FileMode.fmAppend == 4
  """
