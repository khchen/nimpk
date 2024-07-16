[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://paypal.me/khchen0915?country.x=TW&locale.x=zh_TW)

# NimPK

[**PocketLang**](https://thakeenathees.github.io/pocketlang/ "**PocketLang**") is a lightweight, fast embeddable scripting language. And **NimPK** is a powerful PocketLang binding for Nim.

## Features of NimPK
* Deep integration. Nim code can access everything in VM (modules, classes, closure, variables, etc).
* Easy-to-use macro to create native modules and classes.
* Bind Nim procedures or code block as closure or method, support  overloaded procedure, generic procedure, and varargs parameter.
* Bind any Nim types as native class (set, object, ref, tuple, enum, whatever even char or int).
* Automatic type conversion plus custom type conversion can convert any type between Nim value and script variable.
* Well error handling, catching script error in Nim, or catching Nim exception in script.

## Features of PocketLang NimPK Version
NimPK use an [enhanced version of PocketLang](https://github.com/khchen/pocketlang "enhanced version of PocketLang"). Enhancements compare to original version:

* String format via modulo operator.
* Optional parameters, and arguments with default values.
* Command like function call.
* Conditional expression.
* Magic methods: _getter, _setter, _call, _dict, etc.
* Iterator protocol.
* RegExp, Timsort, PRNG, etc via new built-in module.
* Error handling.
* Metaprogramming.
* And more...

Demostartion: https://github.com/khchen/pocketlang/blob/devel/tests/devel/demo.pk

## Features of PocketLang CLI
NimPK provide an enhanced version of CLI program wrote in Nim.

* Script modules can be imported from a zip archive attached to the main executable, instead of from path (powered by [zippy](https://github.com/guzba/zippy "zippy")).
* Native modules can be imported from the zip archive, too (powered by [memlib](https://github.com/khchen/memlib "memlib"), Windows only).
* Builtin `zip` module.
* Additional builtin functions: `echo`, `args`, `load`.

## Examples
Run a piece of script.
```nim
vm.run """
  print "Hello, world! (0)"
"""
```

Run the script and get the return value in nim.
```nim
var ret = vm.run """
  return "Hello, world! (1)"
"""
echo ret
```

Run the script, and then run the returned closure in nim using `()`.
```nim
var closure = vm.run """
  return fn (n)
    return "Hello, world! (${n})"
  end
"""
echo closure(2)
```

Bind nim code as a closure so that we can run it and get the return value in the script. Start the code binding by using the `vm.def` macro.
```nim
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
```

Create a module in nim and use it in the script. In vm.def, use `[]` to create a module, and a named code block or a lambda to create module functions.
```nim
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
```

Create a class in the script and use it in nim. Method 1: Access the class object via vm.main.
```nim
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
```

Method 2: Define a class and return it as class object (NpClass).
```nim
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
```

Create a class in nim and use it in the script. In the module definition of vm.def, use [] to create a class. Use a lambda to create class methods (the first parameter must be self). Note that the name of a lambda can be an identifier, a string, or a symbol.
```nim
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
```

More examples and tutorials: https://github.com/khchen/nimpk/tree/main/examples.

## Docs
* https://khchen.github.io/nimpk

## License
Read license.txt for more details.

Copyright (c) Chen Kai-Hung, Ward. All rights reserved.

## Donate
If this project help you reduce time to develop, you can give me a cup of coffee :)

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://paypal.me/khchen0915?country.x=TW&locale.x=zh_TW)
