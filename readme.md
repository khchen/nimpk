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
  print "Hello, world! (1)"
"""
```

Call nim code and get the return value in script.
```nim
# There are a lot of ways to bind nim code as closure in the VM.
# Here using vm.def macro and anonymous procedure (lambda).

vm.def:
  hello do (n: int) -> string:
    return fmt"Hello, world! ({n})"

vm.run """
  print hello(2)
"""
```

Run script code and get the return value in nim.
```nim
var ret = vm.run """
  return "Hello, world! (3)"
"""
echo ret
```

Run script code, and then run the returned closure in nim.
```nim
var closure = vm.run """
  return fn (n)
    return "Hello, world! (${n})"
  end
"""
echo closure(4)
```

Create a module in nim, and use it in script.
```nim
# In vm.def, [] to create a module, and lambda to create module function.

vm.def:
  [Module]:
    hello do (n: int) -> string:
      return fmt"Hello, world! ({n})"

vm.run """
  import Module
  print Module.hello(5)
"""
```

Create a class in script, and use it in nim.
```nim
var Foo = vm.run """
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
var foo = Foo(6)
echo foo.hello()
```

Create a class in nim, and use it in script.
```nim
# In module definition of vm.def, [] to create a class.
# Lambda to create class methods (first parameter must be self).

vm.def:
  [Module]:
    [Foo]:
      "_init" do (self: NpVar, n: int):
        self.n = n

      hello do (self: NpVar) -> string:
        return fmt"Hello, world! ({self.n})"

vm.run """
  from Module import Foo
  foo = Foo(7)
  print foo.hello()
"""
```
More examples and tutorials: https://github.com/khchen/nimpk/tree/main/examples.

## Docs
* https://khchen.github.io/nimpk

## License
Read license.txt for more details.

Copyright (c) 2022 Kai-Hung Chen, Ward. All rights reserved.

## Donate
If this project help you reduce time to develop, you can give me a cup of coffee :)

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://paypal.me/khchen0915?country.x=TW&locale.x=zh_TW)
