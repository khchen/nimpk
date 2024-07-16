#====================================================================
#
#          NimPK - Pocketlang Binding for Nim Language
#               Copyright (c) Chen Kai-Hung, Ward
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
    print "Hello, world! (0)"
  """

  # Run the script and get the return value in nim.
  var ret = vm.run """
    return "Hello, world! (1)"
  """
  echo ret

  # Run the script, and then run the returned closure in nim using `()`.
  var closure = vm.run """
    return fn (n)
      return "Hello, world! (${n})"
    end
  """
  echo closure(2)

  # Bind nim code as a closure so that we can run it and get the return
  # value in the script. Start the code binding by using the `vm.def` macro.
  vm.def:

    # There are many ways to bind nim code, here we use a named code block.
    hello3:
      return "Hello, world! (3)"

    # Here we use an anonymous procedure (lambda).
    hello4 do (n: int) -> string:
      return fmt"Hello, world! ({n})"

  vm.run """
    print hello3()
    print hello4(4)
  """

  # Create a module in nim and use it in the script.
  # In vm.def, use `[]` to create a module, and a named code block or
  # a lambda to create module functions.
  vm.def:
    [Module]:
      hello5:
        echo "Hello, world! (5)"

      hello6 do (n: int) -> string:
        return fmt"Hello, world! ({n})"

  vm.run """
    import Module
    Module.hello5()
    print Module.hello6(6)
  """

  # Create a class in the script and use it in nim.
  # Method 1: Access the class object via vm.main.
  vm.def:
    testMe:
      # `args` is injected symbol
      # `vm.main.Foo` (NpClass) is callable; call it to create an instance.
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

    # Test the class in the script first.
    foo = Foo(7)
    print foo.hello()

    # Test the class in nim code.
    testMe(8)
  """

  # Method 2: Define a class and return it as class object (NpClass).
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
  var foo = fooCls(9)
  echo foo.hello()

  # Create a class in nim and use it in the script.
  # In the module definition of vm.def, use [] to create a class.
  # Use a lambda to create class methods (the first parameter must be self).
  # Note that the name of a lambda can be an identifier, a string, or a symbol.
  var symbol = "helloNext"
  vm.def:
    [Module]:
      [Foo]:
        "_init" do (self: NpVar, n: int):
          self.n = n

        hello do (self: NpVar) -> string:
          return fmt"Hello, world! ({self.n})"

        `symbol` do (self: NpVar) -> string:
          self.n = self.n + 1
          return fmt"Hello, world! ({self.n})"

  # Test the class in nim code first.
  var module = vm.import("Module")
  foo = module.Foo(10)
  echo foo.hello()
  echo foo.helloNext()

  # Test the class in the script.
  vm.run """
    import Module
    foo = Module.Foo(12)
    print foo.hello()
    print foo.helloNext()
  """
