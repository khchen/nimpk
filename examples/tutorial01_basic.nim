#====================================================================
#
#             NimPK - PocketLang Binding for Nim
#                  Copyright (c) 2022 Ward
#
#====================================================================

import std/strformat

# Import the main module.
import nimpk

# Import the PocketLang VM source code (in C language).
import nimpk/src

# A tempalte to create the vm object.
withNimPkVm:

  # Run a piece of script.
  vm.run """
    print "Hello, world! (1)"
  """

  # Call nim code and get the return value in script.
  # There are a lot of ways to bind nim code as closure in the VM.
  # Here using `vm.def` macro and anonymous procedure (lambda).
  vm.def:
    hello do (n: int) -> string:
      return fmt"Hello, world! ({n})"

  vm.run """
    print hello(2)
  """

  # Run script code and get the return value in nim.
  var ret = vm.run """
    return "Hello, world! (3)"
  """
  echo ret

  # Run script code, and then run the returned closure in nim.
  var closure = vm.run """
    return fn (n)
      return "Hello, world! (${n})"
    end
  """
  echo closure(4)

  # Create a module in nim, and use it in script.
  # In vm.def, [] to create a module, and lambda to create module function.
  vm.def:
    [Module]:
      hello do (n: int) -> string:
        return fmt"Hello, world! ({n})"

  vm.run """
    import Module
    print Module.hello(5)
  """

  # Create a class in script, and use it in nim.
  # Method 1: access the class object by vm.main.
  vm.def:
    testMe:
      assert vm.main.Foo of NpClass
      var foo = vm.main.Foo(args[0])
      echo foo.hello()

  vm.run """
    class Foo
      def _init(n)
        self.n = n
      end
      def hello()
        return "Hello, world! (${self.n})"
      end
    end

    # Test the class in script at first.
    foo = Foo(6)
    print foo.hello()

    # Test the class in nim code.
    testMe(7)
  """

  # Method 2: define a class and return it as class object (NpClass).
  var fooCls = vm.run """
    class Foo
      def _init(n)
        self.n = n
      end
      def hello()
        return "Hello, world! (${self.n})"
      end
    end
    return Foo
  """
  assert fooCls of NpClass
  var foo = fooCls(8)
  echo foo.hello()

  # Create a class in nim, and use it in script.
  # In module definition of vm.def, [] to create a class.
  # Lambda to create class methods (first parameter must be self).
  vm.def:
    [Module]:
      [Foo]:
        "_init" do (self: NpVar, n: int):
          self.n = n

        hello do (self: NpVar) -> string:
          return fmt"Hello, world! ({self.n})"

  # Test the class in nim code at first.
  var module = vm.import("Module")
  foo = module.Foo(9)
  echo foo.hello()

  # Test the class in script.
  vm.run """
    import Module
    foo = Module.Foo(10)
    print foo.hello()
  """
