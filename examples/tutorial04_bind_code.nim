#====================================================================
#
#          NimPK - Pocketlang Binding for Nim Language
#               Copyright (c) Chen Kai-Hung, Ward
#
#====================================================================

import std/[strutils, strformat]
import nimpk
import nimpk/src

# There are a lot of ways to bind nim code as PocketLang builtin functions,
# module funcitons, or methods.

# Method 1: Bind code block.
#  - Smallest code size of glue code.
#  - No automatic type conversion for parameters.
#  - `vm` (NpVm) and `args` (seq[NpVar]) will inject into scope.
#  - For methods, `self` (NpVar) will inject into scope.
#  - Returns NpVar, or any nim value that can convert to NpVar by vm.new proc.

withNimPkVm:
  vm.def:
    test:
      discard "nim code here"
      return args

    "_test":
      discard "nim code here"
      return args

    [Module]:
      test:
        discard "nim code here"
        return args

      [Class]:
        test:
          discard "nim code here"
          args.insert(self)
          return args

  vm.run """
    assert test(1, 2, 3) == [1, 2, 3]
    assert _test(1, 2, 3) == [1, 2, 3]

    import Module
    assert Module.test(1, 2, 3) == [1, 2, 3]

    c = Module.Class()
    assert c.test(1, 2, 3) == [c, 1, 2, 3]
  """

# Method 2: Bind nim procedure (proc or func).
#  - Automatic type conversion for parameters. Raise exception if no suitable
#    procedure can be called (checking at runtime).
#  - Overloaded procedure, generic procedure, and varargs are supported.
#  - Parameters can be `vm: NpVm` to pass the vm.
#  - For methods, `self: NpVar` must be the first parameter (except NpVm).
#  - Use `->` to rename a symbol.
#  - Relative larger glue code, especially for overloaded or generic procedure,
#    so avoid to bind a heavy overloaded procedure (for example: add, and, etc).

withNimPkVm:
  proc test1(a: int, b: int, c = 3): seq[int] =
    return @[a, b, c]

  proc test2(vm: NpVM, a: int, b: int, c = 3): NpVar =
    return vm.list((a, b, c))

  proc generic(a: float|string): auto =
    when a is float:
      return $a
    else:
      return parseFloat(a)

  proc overload(a: float): string = $a
  proc overload(a: string): float = parseFloat(a)

  proc varargs(a: int, b: varargs[int]): seq[int] =
    result.add a
    result.add b

  proc method1(self: NpVar, a: int, b: int, c = 3): NpVar =
    return vm.list((self, a, b, c))

  vm.def:
    test1 -> test
    test2 -> "_test"
    generic
    overload
    varargs
    [Module]:
      test1 -> test

      [Class]:
        method1 -> "method"

  vm.run """
    assert test(1, 2) == [1, 2, 3]
    assert _test(1, 2) == [1, 2, 3]
    assert generic(123.456) == "123.456"
    assert generic("123.456") == 123.456
    assert overload(123.456) == "123.456"
    assert overload("123.456") == 123.456
    assert varargs(1, 2, 3, 4, 5) == [1, 2, 3, 4, 5]

    import Module
    assert Module.test(1, 2) == [1, 2, 3]

    c = Module.Class()
    assert c.method(1, 2) == [c, 1, 2, 3]

    fb = Fiber fn
      test("wrong")
    end
    fb.try()
    assert fb.error.startswith("Incorrect arguments")
  """

# Method 3: Bind anonymous procedure (lambda).
#  - Very similar to method 2, but this way can avoid problem of heavy
#    overloaded procedures.
#  - Generic procedure, and varargs are supported
#  - Overloaded only support in the same vm.def section.
#  - Parameters can be `vm: NpVm` to pass the vm.
#  - For methods, `self: NpVar` must be the first parameter (except NpVm).

withNimPkVm:
  vm.def:
    test do (a: int, b: int, c = 3) -> seq[int]:
      return @[a, b, c]

    "_test" do (vm: NpVM, a: int, b: int, c = 3) -> NpVar:
      return vm.list((a, b, c))

    generic do (a: float|string) -> auto:
      when a is float:
        return $a
      else:
        return parseFloat(a)

    overload do (a: float) -> string: $a
    overload do (a: string) -> float: parseFloat(a)

    varargs do (a: int, b: varargs[int]) -> seq[int]:
      result.add a
      result.add b

    [Module]:
      test do (a: int, b: int, c = 3) -> seq[int]:
        return @[a, b, c]

      [Class]:
        "method" do (self: NpVar, a: int, b: int, c = 3) -> NpVar:
          return vm.list((self, a, b, c))


  vm.run """
    assert test(1, 2) == [1, 2, 3]
    assert _test(1, 2) == [1, 2, 3]
    assert generic(123.456) == "123.456"
    assert generic("123.456") == 123.456
    assert overload(123.456) == "123.456"
    assert overload("123.456") == 123.456
    assert varargs(1, 2, 3, 4, 5) == [1, 2, 3, 4, 5]

    import Module
    assert Module.test(1, 2) == [1, 2, 3]

    c = Module.Class()
    assert c.method(1, 2) == [c, 1, 2, 3]
  """
