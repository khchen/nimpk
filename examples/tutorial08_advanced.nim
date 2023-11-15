#====================================================================
#
#          NimPK - Pocketlang Binding for Nim Language
#               Copyright (c) Chen Kai-Hung, Ward
#
#====================================================================

import std/[strutils, strformat]
import nimpk
import nimpk/src

# ================
# Custom NpVm Type
# ================

# Both `withNimPkVm` or `exportNimPk` accept a vm in custom NpVm type.
# Because vm is the only nim value that can across all part the native
# code (except global value). So custom NpVm type is a way to store the
# user data.

# Custom NpVm type must be `ref object of NpVm`
# Rewrite the Foo class in "tutorial05_bind_type.nim".
type
  MyVm = ref object of NpVm
    fooCls: NpVar

  Foo = object
    data: string

withNimPkVm(MyVm):
  vm.def:
    [Module]:
      [Foo] of Foo:
        block: # a `block` can write nim code in vm.def.
          vm.fooCls = vm["Module"]{"Foo"} # cache the Foo class object.
          assert vm.fooCls of NpClass

        "_str" do (self: Foo) -> string:
          return fmt"Foo[{self.data}]"

        "_init" do (self: var Foo, data: string):
          self.data = data

  proc new(vm: NpVm, f: Foo): NpVar =
    # result = vm["Module"]{"Foo"}(f.data)

    # Use cached object to create instance to avoid searching module and then
    # searching class name everytime.
    result = (vm.MyVm.fooCls)(f.data)

  vm.def:
    test:
      return Foo(data: "hello")

  vm.run """
    assert str(test()) == "Foo[hello]"
  """

# ==============
# Error Handling
# ==============

withNimPkVm:
  # To handle error in pure script, using a fiber and try.
  vm.run """
    def test()
      ["index 1 not exists"][1]
    end

    fb = Fiber(test)
    fb.try()
    assert fb.error == "List index out of bound."
  """

  # If the error is not catched in script, an nim exception will be raised.
  try:
    vm.run """
      ["index 1 not exists"][1]
    """
  except NimPkError:
    assert getCurrentExceptionMsg() == "List index out of bound."

  # System errors are all string type, but a raised error can be any type.
  try:
    vm.run """
      raise ['an', 'error', 'as', 'list']
    """
  except NimPkError:
    assert vm.lastError() == vm.eval("['an', 'error', 'as', 'list']")

  # Unhandled nim exception in binding code can be catched in script, too.
  vm.def:
    error:
      raise newException(NimPkError, "This is an error.")

  vm.run """
    # Fiber of native closure is not supported. Wrap it in script closure.
    def test()
      error()
    end

    fb = Fiber(test)
    fb.try()
    assert fb.error == "This is an error."
  """

  # Or use `vm.error` to set an error.
  vm.def:
    error2:
      vm.error(["an", "error", "as", "list"])

  vm.run """
    def test()
      error2()
    end

    fb = Fiber(test)
    fb.try()
    assert fb.error == ['an', 'error', 'as', 'list']
  """

# =====================
# Behind `vm.def` Macro
# =====================

# Until now, we use vm.def macro for all example. This macro provides
# convenient DSL to write code. However, there is still some magic that
# cannot be done by vm.def macro. For advanced users, knowing the
# procedures behind vm.def may be helpful. They are addModule, addFn,
# addSource, addClass, addMethod, and addType.

withNimPkVm:

  # Here is an example: Add a method to built-in class.
  vm.String.addMethod("repeat") do (self: NpVar, n: Natural) -> string:
    return self.string.repeat(n)

  vm.run """
    assert "Hello".repeat(3) == "HelloHelloHello"
  """
