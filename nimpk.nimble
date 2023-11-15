#====================================================================
#
#          NimPK - Pocketlang Binding for Nim Language
#               Copyright (c) Chen Kai-Hung, Ward
#
#====================================================================

# Package
version       = "1.0.1"
author        = "Ward"
description   = "NimPK - PocketLang Binding for Nim Language"
license       = "MIT"
skipDirs      = @["examples", "docs"]

# Dependencies
requires "nim >= 1.6.0"
requires "zippy >= 0.10.5"
requires "bigints >= 1.0.0"

task cli, "Build the CLI program":
  exec "nim c -d:release -d:strip --opt:speed --mm:orc -o:build/pocket cli/pocket.nim"

task module, "Build all the test modules":
  exec "nim c -d:release -d:strip --opt:speed --mm:orc --app:lib --outdir:build modules/bigints.nim"
  exec "nim c -d:release -d:strip --opt:speed --app:lib --outdir:build modules/pegs.nim"
  exec "nim c -d:release -d:strip --app:lib --outdir:build modules/mylib.nim"
  if fileExists("build/libbigints.so"): mvFile("build/libbigints.so", "build/bigints.so")
  if fileExists("build/libpegs.so"): mvFile("build/libpegs.so", "build/pegs.so")
  if fileExists("build/libmylib.so"): mvFile("build/libmylib.so", "build/mylib.so")
