[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://paypal.me/khchen0915?country.x=TW&locale.x=zh_TW)

# NimPK

[**PocketLang**](https://github.com/khchen/pocketlang "**PocketLang**") is a lightweight, fast embeddable scripting language. And **NimPK** is a powerful PocketLang binding for Nim.

## Features
- Deep integration. Nim code can access everything in VM (modules, classes, closure, variables, etc).
- Easy-to-use macro to create native modules, classes, closures, methods, etc.
- Bind Nim procedures as closure or method (even overloaded and generic).
- Bind any Nim types as native class (set, object, ref, tuple, enum, whatever even char or int).
- Automatic type conversion plus custom type conversion can convert any type between Nim value and script variable.
- Well error handling, catching script error in Nim, or catching Nim exception in script.

## Examples
Run a piece of script.
```nim
vm.run """
  print "Hello, world! (1)"
"""
```

Call nim code and get the return value in script.
```nim
vm.def:
  hello do (n: int) -> string:
    return fmt"Hello, world! ({n})"

vm.run """
  print hello(2)
"""
```

Call script code and get the return value in nim.
```nim
var ret = vm.run """
  return "Hello, world! (3)"
"""
echo ret
```

Call script code, run the returned closure in nim.
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
var foo = Foo(7)
echo foo.hello()
```

Create a class in nim, and use it in script.
```nim
vm.def:
  [Module]:
    [Foo]:
      "_init" do (self: NpVar, n: int):
        self.n = n

      hello do (self: NpVar) -> string:
        return fmt"Hello, world! ({self.n})"

vm.run """
  from Module import Foo
  foo = Foo(8)
  print foo.hello()
"""
```
More examples: https://github.com/khchen/nimpk/tree/main/examples.


## Docs
* https://khchen.github.io/nimpk

## License
Read license.txt for more details.

Copyright (c) 2022 Kai-Hung Chen, Ward. All rights reserved.

## Donate
If this project help you reduce time to develop, you can give me a cup of coffee :)

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://paypal.me/khchen0915?country.x=TW&locale.x=zh_TW)
