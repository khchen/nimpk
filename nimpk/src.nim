#====================================================================
#
#          NimPK - Pocketlang Binding for Nim Language
#               Copyright (c) Chen Kai-Hung, Ward
#
#====================================================================

{.used.}
import os
const pkSrcPath = currentSourcePath.parentDir().parentDir() / "pocketlang/src"
{.passc: "-I" & pkSrcPath / "include".}
{.compile: pkSrcPath / "core/compiler.c".}
{.compile: pkSrcPath / "core/core.c".}
{.compile: pkSrcPath / "core/debug.c".}
{.compile: pkSrcPath / "core/public.c".}
{.compile: pkSrcPath / "core/utils.c".}
{.compile: pkSrcPath / "core/value.c".}
{.compile: pkSrcPath / "core/vm.c".}
{.compile: pkSrcPath / "libs/libs.c".}
{.compile: pkSrcPath / "libs/std_algorithm.c".}
{.compile: pkSrcPath / "libs/std_io.c".}
{.compile: pkSrcPath / "libs/std_json.c".}
{.compile: pkSrcPath / "libs/std_math.c".}
{.compile: pkSrcPath / "libs/std_os.c".}
{.compile: pkSrcPath / "libs/std_path.c".}
{.compile: pkSrcPath / "libs/std_random.c".}
{.compile: pkSrcPath / "libs/std_re.c".}
{.compile: pkSrcPath / "libs/std_time.c".}
{.compile: pkSrcPath / "libs/std_types.c".}
