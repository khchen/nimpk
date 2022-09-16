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
  # Using built-in moudle in nim.
  var re = vm["re"]
  # There is a bug in stable nim (1.6.x), this line should be ok in devel nim.
  # echo re.match(r"[A-Za-z]+", "----Hello----")[0]

  # Workaround for stable nim.
  echo (re.match)(r"[A-Za-z]+", "----Hello----")[0]

  # Add method to built-in class.
  vm.String.addMethod("repeat") do (self: NpVar, n: Natural) -> string:
    return self.string.repeat(n)

  vm.run """
    print "Hello".repeat(2)
  """
