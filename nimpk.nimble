#====================================================================
#
#             NimPK - PocketLang Binding for Nim
#                  Copyright (c) 2022 Ward
#
#====================================================================

# Package
version       = "1.0.0"
author        = "Ward"
description   = "NimPK - PocketLang Binding for Nim"
license       = "MIT"
skipDirs      = @["examples", "docs"]

# Dependencies
requires "nim >= 1.6.0"
requires "zippy >= 0.10.4"
requires "bigints >= 1.0.0"

task cli, "Build the CLI program":
  exec "nim c -d:release -d:strip --opt:speed --mm:orc -o:build/pocket cli/pocket.nim"

task module, "Build all the test modules":
  exec "nim c -d:release -d:strip --opt:speed --mm:orc --app:lib --outdir:build modules/bigints.nim"
  exec "nim c -d:release -d:strip --opt:speed --app:lib --outdir:build modules/pegs.nim"
  exec "nim c -d:release -d:strip --app:lib --outdir:build modules/mylib.nim"
