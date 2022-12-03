#====================================================================
#
#             NimPK - PocketLang Binding for Nim
#                  Copyright (c) 2022 Ward
#
#====================================================================

import std/[unittest, os]
import nimpk/src
import nimpk

const Root = currentSourcePath().parentDir /../ "pocketlang/tests/"

const TestSuite = {
  "Unit Tests": @[
    "lang/basics.pk",
    "lang/builtin_fn.pk",
    "lang/builtin_ty.pk",
    "lang/class.pk",
    "lang/closure.pk",
    "lang/controlflow.pk",
    "lang/fibers.pk",
    "lang/functions.pk",
    "lang/import.pk",
    "lang/try.pk",
  ],

  "Modules Test" : @[
    # "modules/dummy.pk",
    "modules/math.pk",
    "modules/io.pk",
    "modules/json.pk",
    "modules/re.pk",
  ],

  "Random Scripts" : @[
    "random/linked_list.pk",
    "random/lisp_eval.pk",
    "random/string_algo.pk",
  ],

  "Devel Scripts" : @[
    "devel/tests.pk",
    "devel/fractal.pk",
    "devel/demo.pk",
  ],

  "Examples": @[
    "examples/brainfuck.pk",
    "examples/fib.pk",
    "examples/fizzbuzz.pk",
    "examples/helloworld.pk",
    "examples/matrix.pk",
    "examples/pi.pk",
    "examples/prime.pk",
  ],
}

proc freopen(filename: cstring, mode: cstring, stream: File): File
  {.importc, header: "<stdio.h>", discardable.}

template disableStdout() =
  when defined(windows):
    freopen("nul", "a+", stdout)
  else:
    freopen("/dev/null", "a+", stdout)

template enableStdout() =
  when defined(windows):
    freopen("con", "w", stdout)
  else:
    freopen("/dev/tty", "w", stdout)

proc runTest(vm: NpVm, path: string): PkResult =
  disableStdout()
  result = vm.runFile(Root / path)
  enableStdout()

withNimPkVm:
  for (name, list) in TestSuite:
    suite name:
      for file in list:
        test file:
          check PK_RESULT_SUCCESS == vm.runTest(file)
