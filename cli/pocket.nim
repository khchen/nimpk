#====================================================================
#
#          NimPK - Pocketlang Binding for Nim Language
#               Copyright (c) Chen Kai-Hung, Ward
#
#====================================================================

import std/[parseopt, strformat, os, strutils, dynlib]
import nimpk, nimpk/src
import zippy, zippy/ziparchives

when defined(windows):
  import memlib

const VersionNo = "0.1.0 nimpk"

const Help = """
Usage: pocket [options] [file] [arguments]
    -c, --cmd:<str>   Evaluate and run the passed string.
    -e, --echo:<expr> Evaluate the expression, and then print the result.
    -z, --zip:path    Load zip archive as embeded file container.
    -i, --cli         Enter interactive mode anyway.
    -h, --help        Prints this help message.
    -q, --quiet       Don't print version and copyright statement on REPL startup.
    -v, --version     Prints the pocketlang version."""

const Version = fmt"""
PocketLang {VersionNo} (https://github.com/khchen/nimpk/)
Copyright (c) 2020-2021 ThakeeNathees
Copyright (c) 2021-2022 Pocketlang Contributors
Free and open source software under the terms of the MIT license."""

type pkExportModuleFn = proc(vm: ptr PkVM): ptr PkHandle {.cdecl.}

proc pathResolveImport(vm: ptr PKVM, fro: cstring, path: cstring): cstring {.importc, cdecl.}
proc osLoadDL(vm: ptr PKVM, path: cstring): pointer {.importc, cdecl.}
proc osImportDL(vm: ptr PKVM, handle: pointer): ptr PkHandle {.importc, cdecl.}
proc osUnloadDL(vm: ptr PKVM, handle: pointer) {.importc, cdecl.}

var
  params = commandLineParams()
  embeds: seq[string]
  zipReader: openZipArchive("").type

proc pkEcho(v: NpVar, repr=false) =
  case v.kind
  of NpList:
    write(stdout, "[")
    for i in 0 ..< v.len:
      if i != 0: write(stdout, ", ")
      pkEcho(v[i], true)
    write(stdout, "]")

  of NpMap:
    write(stdout, "{")
    var keys = v.keys
    var values = v.values
    for i in 0 ..< keys.len:
      if i != 0: write(stdout, ", ")
      pkEcho(keys[i], true)
      write(stdout, ":")
      pkEcho(values[i], true)
    write(stdout, "}")

  of NpString:
    if repr:
      write(stdout, $v.call("_repr"))
    else:
      write(stdout, $v)

  else:
    write(stdout, $v)

proc makeNativeApi(): PkNativeApi =
  result.pkNewConfiguration = pkNewConfiguration
  result.pkNewVM = pkNewVM
  result.pkFreeVM = pkFreeVM
  result.pkSetUserData = pkSetUserData
  result.pkGetUserData = pkGetUserData
  result.pkRegisterBuiltinFn = pkRegisterBuiltinFn
  result.pkGetBuiltinFn = pkGetBuiltinFn
  result.pkGetBuildinClass = pkGetBuildinClass
  result.pkAddSearchPath = pkAddSearchPath
  result.pkRealloc = pkRealloc
  result.pkReleaseHandle = pkReleaseHandle
  result.pkNewModule = pkNewModule
  result.pkRegisterModule = pkRegisterModule
  result.pkModuleAddFunction = pkModuleAddFunction
  result.pkNewClass = pkNewClass
  result.pkClassAddMethod = pkClassAddMethod
  result.pkModuleAddSource = pkModuleAddSource
  result.pkModuleInitialize = pkModuleInitialize
  result.pkRunString = pkRunString
  result.pkRunFile = pkRunFile
  result.pkRunREPL = pkRunREPL
  result.pkSetRuntimeError = pkSetRuntimeError
  result.pkSetRuntimeErrorObj = pkSetRuntimeErrorObj
  result.pkGetRuntimeError = pkGetRuntimeError
  result.pkGetRuntimeStackReport = pkGetRuntimeStackReport
  result.pkGetSelf = pkGetSelf
  result.pkGetArgc = pkGetArgc
  result.pkCheckArgcRange = pkCheckArgcRange
  result.pkValidateSlotBool = pkValidateSlotBool
  result.pkValidateSlotNumber = pkValidateSlotNumber
  result.pkValidateSlotInteger = pkValidateSlotInteger
  result.pkValidateSlotString = pkValidateSlotString
  result.pkValidateSlotType = pkValidateSlotType
  result.pkValidateSlotInstanceOf = pkValidateSlotInstanceOf
  result.pkIsSlotInstanceOf = pkIsSlotInstanceOf
  result.pkReserveSlots = pkReserveSlots
  result.pkGetSlotsCount = pkGetSlotsCount
  result.pkGetSlotType = pkGetSlotType
  result.pkGetSlotBool = pkGetSlotBool
  result.pkGetSlotNumber = pkGetSlotNumber
  result.pkGetSlotString = pkGetSlotString
  result.pkGetSlotHandle = pkGetSlotHandle
  result.pkGetSlotNativeInstance = pkGetSlotNativeInstance
  result.pkSetSlotNull = pkSetSlotNull
  result.pkSetSlotBool = pkSetSlotBool
  result.pkSetSlotNumber = pkSetSlotNumber
  result.pkSetSlotString = pkSetSlotString
  result.pkSetSlotStringLength = pkSetSlotStringLength
  result.pkSetSlotHandle = pkSetSlotHandle
  result.pkGetSlotHash = pkGetSlotHash
  result.pkPlaceSelf = pkPlaceSelf
  result.pkGetClass = pkGetClass
  result.pkNewInstance = pkNewInstance
  result.pkNewRange = pkNewRange
  result.pkNewList = pkNewList
  result.pkNewMap = pkNewMap
  result.pkListInsert = pkListInsert
  result.pkListPop = pkListPop
  result.pkListLength = pkListLength
  result.pkGetSubscript = pkGetSubscript
  result.pkSetSubscript = pkSetSubscript
  result.pkCallFunction = pkCallFunction
  result.pkCallMethod = pkCallMethod
  result.pkGetAttribute = pkGetAttribute
  result.pkSetAttribute = pkSetAttribute
  result.pkImportModule = pkImportModule
  result.pkGetMainModule = pkGetMainModule

proc pkAllocString(vm: ptr PKVM, str: string): cstring =
  var buff = cast[cstring](pkRealloc(vm, nil, csizet str.len + 1))
  if buff == nil: return nil

  if str.len == 0:
    buff[0] = '\0'
  else:
    copyMem(buff, unsafeAddr str[0], str.len + 1)

  return buff

template withNimPkVmCustomConfig(body: untyped) =
  var config = pkNewConfiguration()
  config.use_ansi_escape = true

  config.resolve_path_fn = proc (vm: ptr PKVM, fro: cstring, path: cstring): cstring {.cdecl.} =
    var embedPath = ($path).replace("../", "^").replace("/", ".")

    if $path in embeds:
      return pkAllocString(vm, $path)

    elif embedPath & ".pk" in embeds:
      return pkAllocString(vm, embedPath & ".pk")

    when defined(windows):
      if embedPath & ".dll" in embeds:
        return pkAllocString(vm, embedPath & ".dll")

    return pathResolveImport(vm, fro, path)

  config.load_script_fn = proc (vm: ptr PKVM, path: cstring): cstring {.cdecl.} =
    if $path in embeds:
      var path = ($path).replace("../", "^").replace("/", ".")
      let contents = zipReader.extractFile($path).replace("\r\n", "\n")
      return pkAllocString(vm, contents)

    else:
      return pkAllocString(vm, readFile($path).replace("\r\n", "\n"))

  config.load_dl_fn = proc (vm: ptr PKVM, path: cstring): pointer {.cdecl.} =
    when defined(windows):
      if $path in embeds:
        type pkInitApi = proc(api: ptr PkNativeApi) {.cdecl.}
        let path = ($path).replace("../", "^").replace("/", ".")
        let contents = zipReader.extractFile($path)

        var lib = loadLib(DllContent contents)
        if lib == nil: return nil

        var initFn = cast[pkInitApi](lib.symAddr("pkInitApi"))
        if initFn == nil:
          lib.unloadLib()
          return nil

        var api = makeNativeApi()
        initFn(addr api)

        return lib

      else:
        return osLoadDL(vm, path)

    else:
      return osLoadDL(vm, path)

  config.import_dl_fn = proc (vm: ptr PKVM, handle: pointer): ptr PkHandle {.cdecl.} =
    result = osImportDL(vm, handle)
    when defined(windows):
      if result == nil:
        var lib = cast[MemoryModule](handle)
        var exportFn = cast[pkExportModuleFn](lib.symAddr("pkExportModule"))
        if exportFn == nil: return nil
        return exportFn(vm)

  config.unload_dl_fn = proc (vm: ptr PKVM, handle: pointer) {.cdecl.} =
    when defined(windows):
      if symAddr(cast[LibHandle](handle), "pkExportModule") != nil:
        osUnloadDL(vm, handle)

      else:
        var lib = cast[MemoryModule](handle)
        var cleanupFn = cast[pkExportModuleFn](lib.symAddr("pkCleanupModule"))
        if cleanupFn != nil:
          discard cleanupFn(vm)
        lib.unloadLib()

    else:
      osUnloadDL(vm, handle)

  withNimPkVmConfig(addr config):
    body

proc main(): int =

  withNimPkVmCustomConfig:
    vm.def:
      [zip]:
        DefaultCompression = DefaultCompression
        BestCompression = BestCompression
        BestSpeed = BestSpeed
        NoCompression = NoCompression
        HuffmanOnly = HuffmanOnly
        Detect = ord dfDetect
        Zlib = ord dfZlib
        Gzip = ord dfGzip
        Deflate = ord dfDeflate

        compress:
          ## compress(src: String, level: Number = DefaultCompression, dataFormat = Gzip) -> String
          ##
          ## Compresses src and returns the compressed data.
          var
            src = string args[0]
            level = if args.len > 1: int args[1] else: DefaultCompression
            dataFormat = if args.len > 2: CompressedDataFormat int args[2] else: dfGzip
          return compress(src, level, dataFormat)

        uncompress:
          ## uncompress(src: String, dataFormat = Detect) -> String
          ##
          ## Uncompresses src and returns the uncompressed data.
          var
            src = string args[0]
            dataFormat = if args.len > 1: CompressedDataFormat int args[1] else: dfDetect
          return uncompress(src, dataFormat)

      "echo":
        ## echo(...) -> Null
        ##
        ## Writes and flushes the parameters to the standard output.
        for arg in args: pkEcho(arg)
        echo ""

      args:
        ## args() -> List
        ##
        ## Returns the command line parameters.
        return params

      load:
        ## load(path: String) -> Module
        ##
        ## Load a script or dynamic library as module.
        try:
          var file = string args[0]
          return vm.import(file)
        except:
          return vm nil

    try:
      zipReader = openZipArchive(getAppFilename())
      for path in zipReader.walkFiles:
        embeds.add path
    except: discard

    # if there is _init.pk in embeded archive, don't parse the command line
    if "_init.pk" in embeds:
      return int vm.runFile("_init.pk")

    var
      quiet, ver, help, cli, exec = false
      file: string
      code: int

    var p = initOptParser()
    for kind, key, value in p.getOpt():
      case kind
      of cmdArgument:
        if file == "":
          file = key
          params = p.remainingArgs
          break

      of cmdLongOption, cmdShortOption:
        case key
        of "quiet", "q": quiet = true
        of "version", "v": ver = true
        of "help", "h": help = true
        of "cli", "i": cli = true

        of "cmd", "c":
          code = int vm.runString value
          exec = true

        of "echo", "e":
          code = int vm.runString fmt"print ({value})"
          exec = true

        of "zip", "z":
          try:
            zipReader = openZipArchive(value)
            embeds.setLen(0)
            for path in zipReader.walkFiles:
              embeds.add path

          except:
            echo "Error loading archive: ", value

      of cmdEnd:
        discard

    if file == "" and "_init.pk" in embeds:
      file = "_init.pk"

    if ver:
      echo Version
      exec = true

    if help:
      echo Help
      exec = true

    if file != "":
      code = int vm.runFile(file)
      exec = true

    if not exec or cli:
      if not ver and not quiet:
        echo Version

      vm.startRepl()

    return code

quit(main())
