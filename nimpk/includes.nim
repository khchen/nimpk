#====================================================================
#
#          NimPK - Pocketlang Binding for Nim Language
#               Copyright (c) Chen Kai-Hung, Ward
#
#====================================================================

# !! THIS FILE IS GENERATED DO NOT EDIT

{.push hint[Name]: off.}
type
  PkVarType* = enum
    ## Type enum of the pocketlang's first class types. Note that Object isn't
    ## instanciable (as of now) but they're considered first calss.
    PK_OBJECT = 0
    PK_NULL
    PK_BOOL
    PK_NUMBER
    PK_STRING
    PK_LIST
    PK_MAP
    PK_RANGE
    PK_MODULE
    PK_CLOSURE
    PK_METHOD_BIND
    PK_FIBER
    PK_CLASS
    PK_INSTANCE
  PkResult* = enum
    ## Result that pocketlang will return after a compilation or running a script
    ## or a function or evaluating an expression.
    PK_RESULT_SUCCESS = 0
    PK_RESULT_UNEXPECTED_EOF
    PK_RESULT_COMPILE_ERROR
    PK_RESULT_RUNTIME_ERROR
  PKVM* {.bycopy.} = object
    ## PocketLang Virtual Machine. It'll contain the state of the execution, stack,
    ## heap, and manage memory allocations.
  PkHandle* {.bycopy.} = object
    ## A handle to the pocketlang variables. It'll hold the reference to the
    ## variable and ensure that the variable it holds won't be garbage collected
    ## till it's released with pkReleaseHandle().
  PkConfiguration* {.bycopy.} = object
    realloc_fn*: pkReallocFn
    stderr_write*: pkWriteFn
    stdout_write*: pkWriteFn
    stdin_read*: pkReadFn
    resolve_path_fn*: pkResolvePathFn
    load_script_fn*: pkLoadScriptFn
    load_dl_fn*: pkLoadDL
    import_dl_fn*: pkImportDL
    unload_dl_fn*: pkUnloadDL
    use_ansi_escape*: bool
    user_data*: pointer
  pkNativeFn* = proc (vm: ptr PKVM) {.cdecl.}
    ## C function pointer which is callable from pocketLang by native module
    ## functions.
  pkReallocFn* = proc (memory: pointer, new_size: csize_t, user_data: pointer): pointer {.cdecl.}
    ## A function that'll be called for all the allocation calls by PKVM.
    ##
    ## - To allocate new memory it'll pass NULL to parameter [memory] and the
    ##   required size to [new_size]. On failure the return value would be NULL.
    ##
    ## - When reallocating an existing memory if it's grow in place the return
    ##   address would be the same as [memory] otherwise a new address.
    ##
    ## - To free an allocated memory pass [memory] and 0 to [new_size]. The
    ##   function will return NULL.
  pkWriteFn* = proc (vm: ptr PKVM, text: cstring) {.cdecl.}
    ## Function callback to write [text] to stdout or stderr.
  pkReadFn* = proc (vm: ptr PKVM): cstring {.cdecl.}
    ## A function callback to read a line from stdin. The returned string shouldn't
    ## contain a line ending (\n or \r\n). The returned string **must** be
    ## allocated with pkRealloc() and the VM will claim the ownership of the
    ## string.
  pkSignalFn* = proc (a1: pointer) {.cdecl.}
    ## A generic function thiat could be used by the PKVM to signal something to
    ## the host application. The first argument is depend on the callback it's
    ## registered.
  pkLoadScriptFn* = proc (vm: ptr PKVM, path: cstring): cstring {.cdecl.}
    ## Load and return the script. Called by the compiler to fetch initial source
    ## code and source for import statements. Return NULL to indicate failure to
    ## load. Otherwise the string **must** be allocated with pkRealloc() and
    ## the VM will claim the ownership of the string.
  pkLoadDL* = proc (vm: ptr PKVM, path: cstring): pointer {.cdecl.}
    ## Load and return the native extension (*.dll, *.so) from the path, this will
    ## then used to import the module with the pkImportImportDL function. On error
    ## the function should return NULL and shouldn't use any error api function.
  pkImportDL* = proc (vm: ptr PKVM, handle: pointer): ptr PkHandle {.cdecl.}
    ## Native extension loader from the dynamic library. The handle should be vaiid
    ## as long as the module handle is alive. On error the function should return
    ## NULL and shouldn't use any error api function.
  pkUnloadDL* = proc (vm: ptr PKVM, handle: pointer) {.cdecl.}
    ## Once the native module is gargage collected, the dl handle will be released
    ## with pkUnloadDL function.
  pkResolvePathFn* = proc (vm: ptr PKVM, `from`: cstring, path: cstring): cstring {.cdecl.}
    ## A function callback to resolve the import statement path. [from] path can
    ## be either path to a script or a directory or NULL if [path] is relative to
    ## cwd. If the path is a directory it'll always ends with a path separator
    ## which could be either '/' or '\\' regardless of the system. Since pocketlang is
    ## un aware of the system, to indicate that the path is a directory.
    ##
    ## The return value should be a normalized absolute path of the [path]. Return
    ## NULL to indicate failure to resolve. Othrewise the string **must** be
    ## allocated with pkRealloc() and the VM will claim the ownership of the
    ## string.
  pkNewInstanceFn* = proc (vm: ptr PKVM): pointer {.cdecl.}
    ## A function callback to allocate and return a new instance of the registered
    ## class. Which will be called when the instance is constructed. The returned/
    ## data is expected to be alive till the delete callback occurs.
  pkDeleteInstanceFn* = proc (vm: ptr PKVM, a1: pointer) {.cdecl.}
    ## A function callback to de-allocate the allocated native instance of the
    ## registered class. This function is invoked at the GC execution. No object
    ## allocations are allowed during it, so **NEVER** allocate any objects
    ## inside them.
  PkNativeApi* {.bycopy.} = object
    pkNewConfiguration*: proc (): PkConfiguration {.cdecl.}
    pkNewVM*: proc (config: ptr PkConfiguration): ptr PKVM {.cdecl.}
    pkFreeVM*: proc (vm: ptr PKVM) {.cdecl.}
    pkSetUserData*: proc (vm: ptr PKVM, user_data: pointer) {.cdecl.}
    pkGetUserData*: proc (vm: ptr PKVM): pointer {.cdecl.}
    pkRegisterBuiltinFn*: proc (vm: ptr PKVM, name: cstring, fn: pkNativeFn, arity: cint, docstring: cstring) {.cdecl.}
    pkGetBuiltinFn*: proc (vm: ptr PKVM, name: cstring, index: cint): bool {.cdecl.}
    pkGetBuildinClass*: proc (vm: ptr PKVM, name: cstring, index: cint): bool {.cdecl.}
    pkAddSearchPath*: proc (vm: ptr PKVM, path: cstring) {.cdecl.}
    pkRealloc*: proc (vm: ptr PKVM, `ptr`: pointer, size: csize_t): pointer {.cdecl.}
    pkReleaseHandle*: proc (vm: ptr PKVM, handle: ptr PkHandle) {.cdecl.}
    pkNewModule*: proc (vm: ptr PKVM, name: cstring): ptr PkHandle {.cdecl.}
    pkRegisterModule*: proc (vm: ptr PKVM, module: ptr PkHandle) {.cdecl.}
    pkModuleAddFunction*: proc (vm: ptr PKVM, module: ptr PkHandle, name: cstring, fptr: pkNativeFn, arity: cint, docstring: cstring) {.cdecl.}
    pkNewClass*: proc (vm: ptr PKVM, name: cstring, base_class: ptr PkHandle, module: ptr PkHandle, new_fn: pkNewInstanceFn, delete_fn: pkDeleteInstanceFn, docstring: cstring): ptr PkHandle {.cdecl.}
    pkClassAddMethod*: proc (vm: ptr PKVM, cls: ptr PkHandle, name: cstring, fptr: pkNativeFn, arity: cint, docstring: cstring) {.cdecl.}
    pkModuleAddSource*: proc (vm: ptr PKVM, module: ptr PkHandle, source: cstring) {.cdecl.}
    pkModuleInitialize*: proc (vm: ptr PKVM, handle: ptr PkHandle): bool {.cdecl.}
    pkRunString*: proc (vm: ptr PKVM, source: cstring): PkResult {.cdecl.}
    pkRunFile*: proc (vm: ptr PKVM, path: cstring): PkResult {.cdecl.}
    pkRunREPL*: proc (vm: ptr PKVM): PkResult {.cdecl.}
    pkSetRuntimeError*: proc (vm: ptr PKVM, message: cstring) {.cdecl.}
    pkSetRuntimeErrorObj*: proc (vm: ptr PKVM, slot: cint) {.cdecl.}
    pkGetRuntimeError*: proc (vm: ptr PKVM, slot: cint) {.cdecl.}
    pkGetRuntimeStackReport*: proc (vm: ptr PKVM, slot: cint) {.cdecl.}
    pkGetSelf*: proc (vm: ptr PKVM): pointer {.cdecl.}
    pkGetArgc*: proc (vm: ptr PKVM): cint {.cdecl.}
    pkCheckArgcRange*: proc (vm: ptr PKVM, argc: cint, min: cint, max: cint): bool {.cdecl.}
    pkValidateSlotBool*: proc (vm: ptr PKVM, slot: cint, value: ptr bool): bool {.cdecl.}
    pkValidateSlotNumber*: proc (vm: ptr PKVM, slot: cint, value: ptr cdouble): bool {.cdecl.}
    pkValidateSlotInteger*: proc (vm: ptr PKVM, slot: cint, value: ptr int32): bool {.cdecl.}
    pkValidateSlotString*: proc (vm: ptr PKVM, slot: cint, value: ptr cstring, length: ptr uint32): bool {.cdecl.}
    pkValidateSlotType*: proc (vm: ptr PKVM, slot: cint, `type`: PkVarType): bool {.cdecl.}
    pkValidateSlotInstanceOf*: proc (vm: ptr PKVM, slot: cint, cls: cint): bool {.cdecl.}
    pkIsSlotInstanceOf*: proc (vm: ptr PKVM, inst: cint, cls: cint, val: ptr bool): bool {.cdecl.}
    pkReserveSlots*: proc (vm: ptr PKVM, count: cint) {.cdecl.}
    pkGetSlotsCount*: proc (vm: ptr PKVM): cint {.cdecl.}
    pkGetSlotType*: proc (vm: ptr PKVM, index: cint): PkVarType {.cdecl.}
    pkGetSlotBool*: proc (vm: ptr PKVM, index: cint): bool {.cdecl.}
    pkGetSlotNumber*: proc (vm: ptr PKVM, index: cint): cdouble {.cdecl.}
    pkGetSlotString*: proc (vm: ptr PKVM, index: cint, length: ptr uint32): cstring {.cdecl.}
    pkGetSlotHandle*: proc (vm: ptr PKVM, index: cint): ptr PkHandle {.cdecl.}
    pkGetSlotNativeInstance*: proc (vm: ptr PKVM, index: cint): pointer {.cdecl.}
    pkSetSlotNull*: proc (vm: ptr PKVM, index: cint) {.cdecl.}
    pkSetSlotBool*: proc (vm: ptr PKVM, index: cint, value: bool) {.cdecl.}
    pkSetSlotNumber*: proc (vm: ptr PKVM, index: cint, value: cdouble) {.cdecl.}
    pkSetSlotString*: proc (vm: ptr PKVM, index: cint, value: cstring) {.cdecl.}
    pkSetSlotStringLength*: proc (vm: ptr PKVM, index: cint, value: cstring, length: uint32) {.cdecl.}
    pkSetSlotHandle*: proc (vm: ptr PKVM, index: cint, handle: ptr PkHandle) {.cdecl.}
    pkGetSlotHash*: proc (vm: ptr PKVM, index: cint): uint32 {.cdecl.}
    pkPlaceSelf*: proc (vm: ptr PKVM, index: cint) {.cdecl.}
    pkGetClass*: proc (vm: ptr PKVM, instance: cint, index: cint) {.cdecl.}
    pkNewInstance*: proc (vm: ptr PKVM, cls: cint, index: cint, argc: cint, argv: cint): bool {.cdecl.}
    pkNewRange*: proc (vm: ptr PKVM, index: cint, first: cdouble, last: cdouble) {.cdecl.}
    pkNewList*: proc (vm: ptr PKVM, index: cint) {.cdecl.}
    pkNewMap*: proc (vm: ptr PKVM, index: cint) {.cdecl.}
    pkListInsert*: proc (vm: ptr PKVM, list: cint, index: int32, value: cint): bool {.cdecl.}
    pkListPop*: proc (vm: ptr PKVM, list: cint, index: int32, popped: cint): bool {.cdecl.}
    pkListLength*: proc (vm: ptr PKVM, list: cint): uint32 {.cdecl.}
    pkGetSubscript*: proc (vm: ptr PKVM, on: cint, key: cint, ret: cint): bool {.cdecl.}
    pkSetSubscript*: proc (vm: ptr PKVM, on: cint, key: cint, value: cint): bool {.cdecl.}
    pkCallFunction*: proc (vm: ptr PKVM, fn: cint, argc: cint, argv: cint, ret: cint): bool {.cdecl.}
    pkCallMethod*: proc (vm: ptr PKVM, instance: cint, `method`: cstring, argc: cint, argv: cint, ret: cint): bool {.cdecl.}
    pkGetAttribute*: proc (vm: ptr PKVM, instance: cint, name: cstring, index: cint): bool {.cdecl.}
    pkSetAttribute*: proc (vm: ptr PKVM, instance: cint, name: cstring, value: cint): bool {.cdecl.}
    pkImportModule*: proc (vm: ptr PKVM, path: cstring, index: cint): bool {.cdecl.}
    pkGetMainModule*: proc (vm: ptr PKVM, index: cint): bool {.cdecl.}
when appType == "lib":
  var pk_api*: PkNativeApi
  proc pkInitApi(api: ptr PkNativeApi) {.cdecl, exportc, dynlib.} = pk_api = api[]
  proc pkNewConfiguration*(): PkConfiguration = pk_api.pkNewConfiguration()
  proc pkNewVM*(config: ptr PkConfiguration): ptr PKVM = pk_api.pkNewVM(config)
  proc pkFreeVM*(vm: ptr PKVM) = pk_api.pkFreeVM(vm)
  proc pkSetUserData*(vm: ptr PKVM, user_data: pointer) = pk_api.pkSetUserData(vm, user_data)
  proc pkGetUserData*(vm: ptr PKVM): pointer = pk_api.pkGetUserData(vm)
  proc pkRegisterBuiltinFn*(vm: ptr PKVM, name: cstring, fn: pkNativeFn, arity: cint, docstring: cstring) = pk_api.pkRegisterBuiltinFn(vm, name, fn, arity, docstring)
  proc pkGetBuiltinFn*(vm: ptr PKVM, name: cstring, index: cint): bool = pk_api.pkGetBuiltinFn(vm, name, index)
  proc pkGetBuildinClass*(vm: ptr PKVM, name: cstring, index: cint): bool = pk_api.pkGetBuildinClass(vm, name, index)
  proc pkAddSearchPath*(vm: ptr PKVM, path: cstring) = pk_api.pkAddSearchPath(vm, path)
  proc pkRealloc*(vm: ptr PKVM, `ptr`: pointer, size: csize_t): pointer = pk_api.pkRealloc(vm, `ptr`, size)
  proc pkReleaseHandle*(vm: ptr PKVM, handle: ptr PkHandle) = pk_api.pkReleaseHandle(vm, handle)
  proc pkNewModule*(vm: ptr PKVM, name: cstring): ptr PkHandle = pk_api.pkNewModule(vm, name)
  proc pkRegisterModule*(vm: ptr PKVM, module: ptr PkHandle) = pk_api.pkRegisterModule(vm, module)
  proc pkModuleAddFunction*(vm: ptr PKVM, module: ptr PkHandle, name: cstring, fptr: pkNativeFn, arity: cint, docstring: cstring) = pk_api.pkModuleAddFunction(vm, module, name, fptr, arity, docstring)
  proc pkNewClass*(vm: ptr PKVM, name: cstring, base_class: ptr PkHandle, module: ptr PkHandle, new_fn: pkNewInstanceFn, delete_fn: pkDeleteInstanceFn, docstring: cstring): ptr PkHandle = pk_api.pkNewClass(vm, name, base_class, module, new_fn, delete_fn, docstring)
  proc pkClassAddMethod*(vm: ptr PKVM, cls: ptr PkHandle, name: cstring, fptr: pkNativeFn, arity: cint, docstring: cstring) = pk_api.pkClassAddMethod(vm, cls, name, fptr, arity, docstring)
  proc pkModuleAddSource*(vm: ptr PKVM, module: ptr PkHandle, source: cstring) = pk_api.pkModuleAddSource(vm, module, source)
  proc pkModuleInitialize*(vm: ptr PKVM, handle: ptr PkHandle): bool = pk_api.pkModuleInitialize(vm, handle)
  proc pkRunString*(vm: ptr PKVM, source: cstring): PkResult = pk_api.pkRunString(vm, source)
  proc pkRunFile*(vm: ptr PKVM, path: cstring): PkResult = pk_api.pkRunFile(vm, path)
  proc pkRunREPL*(vm: ptr PKVM): PkResult = pk_api.pkRunREPL(vm)
  proc pkSetRuntimeError*(vm: ptr PKVM, message: cstring) = pk_api.pkSetRuntimeError(vm, message)
  proc pkSetRuntimeErrorObj*(vm: ptr PKVM, slot: cint) = pk_api.pkSetRuntimeErrorObj(vm, slot)
  proc pkGetRuntimeError*(vm: ptr PKVM, slot: cint) = pk_api.pkGetRuntimeError(vm, slot)
  proc pkGetRuntimeStackReport*(vm: ptr PKVM, slot: cint) = pk_api.pkGetRuntimeStackReport(vm, slot)
  proc pkGetSelf*(vm: ptr PKVM): pointer = pk_api.pkGetSelf(vm)
  proc pkGetArgc*(vm: ptr PKVM): cint = pk_api.pkGetArgc(vm)
  proc pkCheckArgcRange*(vm: ptr PKVM, argc: cint, min: cint, max: cint): bool = pk_api.pkCheckArgcRange(vm, argc, min, max)
  proc pkValidateSlotBool*(vm: ptr PKVM, slot: cint, value: ptr bool): bool = pk_api.pkValidateSlotBool(vm, slot, value)
  proc pkValidateSlotNumber*(vm: ptr PKVM, slot: cint, value: ptr cdouble): bool = pk_api.pkValidateSlotNumber(vm, slot, value)
  proc pkValidateSlotInteger*(vm: ptr PKVM, slot: cint, value: ptr int32): bool = pk_api.pkValidateSlotInteger(vm, slot, value)
  proc pkValidateSlotString*(vm: ptr PKVM, slot: cint, value: ptr cstring, length: ptr uint32): bool = pk_api.pkValidateSlotString(vm, slot, value, length)
  proc pkValidateSlotType*(vm: ptr PKVM, slot: cint, `type`: PkVarType): bool = pk_api.pkValidateSlotType(vm, slot, `type`)
  proc pkValidateSlotInstanceOf*(vm: ptr PKVM, slot: cint, cls: cint): bool = pk_api.pkValidateSlotInstanceOf(vm, slot, cls)
  proc pkIsSlotInstanceOf*(vm: ptr PKVM, inst: cint, cls: cint, val: ptr bool): bool = pk_api.pkIsSlotInstanceOf(vm, inst, cls, val)
  proc pkReserveSlots*(vm: ptr PKVM, count: cint) = pk_api.pkReserveSlots(vm, count)
  proc pkGetSlotsCount*(vm: ptr PKVM): cint = pk_api.pkGetSlotsCount(vm)
  proc pkGetSlotType*(vm: ptr PKVM, index: cint): PkVarType = pk_api.pkGetSlotType(vm, index)
  proc pkGetSlotBool*(vm: ptr PKVM, index: cint): bool = pk_api.pkGetSlotBool(vm, index)
  proc pkGetSlotNumber*(vm: ptr PKVM, index: cint): cdouble = pk_api.pkGetSlotNumber(vm, index)
  proc pkGetSlotString*(vm: ptr PKVM, index: cint, length: ptr uint32): cstring = pk_api.pkGetSlotString(vm, index, length)
  proc pkGetSlotHandle*(vm: ptr PKVM, index: cint): ptr PkHandle = pk_api.pkGetSlotHandle(vm, index)
  proc pkGetSlotNativeInstance*(vm: ptr PKVM, index: cint): pointer = pk_api.pkGetSlotNativeInstance(vm, index)
  proc pkSetSlotNull*(vm: ptr PKVM, index: cint) = pk_api.pkSetSlotNull(vm, index)
  proc pkSetSlotBool*(vm: ptr PKVM, index: cint, value: bool) = pk_api.pkSetSlotBool(vm, index, value)
  proc pkSetSlotNumber*(vm: ptr PKVM, index: cint, value: cdouble) = pk_api.pkSetSlotNumber(vm, index, value)
  proc pkSetSlotString*(vm: ptr PKVM, index: cint, value: cstring) = pk_api.pkSetSlotString(vm, index, value)
  proc pkSetSlotStringLength*(vm: ptr PKVM, index: cint, value: cstring, length: uint32) = pk_api.pkSetSlotStringLength(vm, index, value, length)
  proc pkSetSlotHandle*(vm: ptr PKVM, index: cint, handle: ptr PkHandle) = pk_api.pkSetSlotHandle(vm, index, handle)
  proc pkGetSlotHash*(vm: ptr PKVM, index: cint): uint32 = pk_api.pkGetSlotHash(vm, index)
  proc pkPlaceSelf*(vm: ptr PKVM, index: cint) = pk_api.pkPlaceSelf(vm, index)
  proc pkGetClass*(vm: ptr PKVM, instance: cint, index: cint) = pk_api.pkGetClass(vm, instance, index)
  proc pkNewInstance*(vm: ptr PKVM, cls: cint, index: cint, argc: cint, argv: cint): bool = pk_api.pkNewInstance(vm, cls, index, argc, argv)
  proc pkNewRange*(vm: ptr PKVM, index: cint, first: cdouble, last: cdouble) = pk_api.pkNewRange(vm, index, first, last)
  proc pkNewList*(vm: ptr PKVM, index: cint) = pk_api.pkNewList(vm, index)
  proc pkNewMap*(vm: ptr PKVM, index: cint) = pk_api.pkNewMap(vm, index)
  proc pkListInsert*(vm: ptr PKVM, list: cint, index: int32, value: cint): bool = pk_api.pkListInsert(vm, list, index, value)
  proc pkListPop*(vm: ptr PKVM, list: cint, index: int32, popped: cint): bool = pk_api.pkListPop(vm, list, index, popped)
  proc pkListLength*(vm: ptr PKVM, list: cint): uint32 = pk_api.pkListLength(vm, list)
  proc pkGetSubscript*(vm: ptr PKVM, on: cint, key: cint, ret: cint): bool = pk_api.pkGetSubscript(vm, on, key, ret)
  proc pkSetSubscript*(vm: ptr PKVM, on: cint, key: cint, value: cint): bool = pk_api.pkSetSubscript(vm, on, key, value)
  proc pkCallFunction*(vm: ptr PKVM, fn: cint, argc: cint, argv: cint, ret: cint): bool = pk_api.pkCallFunction(vm, fn, argc, argv, ret)
  proc pkCallMethod*(vm: ptr PKVM, instance: cint, `method`: cstring, argc: cint, argv: cint, ret: cint): bool = pk_api.pkCallMethod(vm, instance, `method`, argc, argv, ret)
  proc pkGetAttribute*(vm: ptr PKVM, instance: cint, name: cstring, index: cint): bool = pk_api.pkGetAttribute(vm, instance, name, index)
  proc pkSetAttribute*(vm: ptr PKVM, instance: cint, name: cstring, value: cint): bool = pk_api.pkSetAttribute(vm, instance, name, value)
  proc pkImportModule*(vm: ptr PKVM, path: cstring, index: cint): bool = pk_api.pkImportModule(vm, path, index)
  proc pkGetMainModule*(vm: ptr PKVM, index: cint): bool = pk_api.pkGetMainModule(vm, index)
else:
  proc pkNewConfiguration*(): PkConfiguration {.importc, cdecl.}
    ## Create a new PkConfiguration with the default values and return it.
    ## Override those default configuration to adopt to another hosting
    ## application.
  proc pkNewVM*(config: ptr PkConfiguration): ptr PKVM {.importc, cdecl.}
    ## Allocate, initialize and returns a new VM.
  proc pkFreeVM*(vm: ptr PKVM) {.importc, cdecl.}
    ## Clean the VM and dispose all the resources allocated by the VM.
  proc pkSetUserData*(vm: ptr PKVM, user_data: pointer) {.importc, cdecl.}
    ## Update the user data of the vm.
  proc pkGetUserData*(vm: ptr PKVM): pointer {.importc, cdecl.}
    ## Returns the associated user data.
  proc pkRegisterBuiltinFn*(vm: ptr PKVM, name: cstring, fn: pkNativeFn, arity: cint, docstring: cstring) {.importc, cdecl.}
    ## Register a new builtin function with the given [name]. [docstring] could be
    ## NULL or will always valid pointer since PKVM doesn't allocate a string for
    ## docstrings.
  proc pkGetBuiltinFn*(vm: ptr PKVM, name: cstring, index: cint): bool {.importc, cdecl.}
    ## Get builtin function with the given [name] at slot [index].
  proc pkGetBuildinClass*(vm: ptr PKVM, name: cstring, index: cint): bool {.importc, cdecl.}
    ## Get builtin class with the given [name] at slot [index].
  proc pkAddSearchPath*(vm: ptr PKVM, path: cstring) {.importc, cdecl.}
    ## Adds a new search paht to the VM, the path will be appended to the list of
    ## search paths. Search path orders are the same as the registered order.
    ## the last character of the path **must** be a path seperator '/' or '\\'.
  proc pkRealloc*(vm: ptr PKVM, `ptr`: pointer, size: csize_t): pointer {.importc, cdecl.}
    ## Invoke pocketlang's allocator directly.  This function should be called
    ## when the host application want to send strings to the PKVM that are claimed
    ## by the VM once the caller returned it. For other uses you **should** call
    ## pkRealloc with [size] 0 to cleanup, otherwise there will be a memory leak.
    ##
    ## Internally it'll call `pkReallocFn` function that was provided in the
    ## configuration.
  proc pkReleaseHandle*(vm: ptr PKVM, handle: ptr PkHandle) {.importc, cdecl.}
    ## Release the handle and allow its value to be garbage collected. Always call
    ## this for every handles before freeing the VM.
  proc pkNewModule*(vm: ptr PKVM, name: cstring): ptr PkHandle {.importc, cdecl.}
    ## Add a new module named [name] to the [vm]. Note that the module shouldn't
    ## already existed, otherwise an assertion will fail to indicate that.
  proc pkRegisterModule*(vm: ptr PKVM, module: ptr PkHandle) {.importc, cdecl.}
    ## Register the module to the PKVM's modules map, once after it can be
    ## imported in other modules.
  proc pkModuleAddFunction*(vm: ptr PKVM, module: ptr PkHandle, name: cstring, fptr: pkNativeFn, arity: cint, docstring: cstring) {.importc, cdecl.}
    ## Add a native function to the given module. If [arity] is -1 that means
    ## the function has variadic parameters and use pkGetArgc() to get the argc.
    ## Note that the function will be added as a global variable of the module.
    ## [docstring] is optional and could be omitted with NULL.
  proc pkNewClass*(vm: ptr PKVM, name: cstring, base_class: ptr PkHandle, module: ptr PkHandle, new_fn: pkNewInstanceFn, delete_fn: pkDeleteInstanceFn, docstring: cstring): ptr PkHandle {.importc, cdecl.}
    ## Create a new class on the [module] with the [name] and return it.
    ## If the [base_class] is NULL by default it'll set to "Object" class.
    ## [docstring] is optional and could be omitted with NULL.
  proc pkClassAddMethod*(vm: ptr PKVM, cls: ptr PkHandle, name: cstring, fptr: pkNativeFn, arity: cint, docstring: cstring) {.importc, cdecl.}
    ## Add a native method to the given class. If the [arity] is -1 that means
    ## the method has variadic parameters and use pkGetArgc() to get the argc.
    ## [docstring] is optional and could be omitted with NULL.
  proc pkModuleAddSource*(vm: ptr PKVM, module: ptr PkHandle, source: cstring) {.importc, cdecl.}
    ## It'll compile the pocket [source] for the module which result all the
    ## functions and classes in that [source] to register on the module.
  proc pkModuleInitialize*(vm: ptr PKVM, handle: ptr PkHandle): bool {.importc, cdecl.}
    ## Force to initialize an uninitialized module.
  proc pkRunString*(vm: ptr PKVM, source: cstring): PkResult {.importc, cdecl.}
    ## Run the source string. The [source] is expected to be valid till this
    ## function returns.
  proc pkRunFile*(vm: ptr PKVM, path: cstring): PkResult {.importc, cdecl.}
    ## Run the file at [path] relative to the current working directory.
  proc pkRunREPL*(vm: ptr PKVM): PkResult {.importc, cdecl.}
    ## FIXME:
    ## Currently exit function will terminate the process which should exit from
    ## the function and return to the caller.
    ##
    ## Run pocketlang REPL mode. If there isn't any stdin read function defined,
    ## or imput function ruturned NULL, it'll immediatly return a runtime error.
  proc pkSetRuntimeError*(vm: ptr PKVM, message: cstring) {.importc, cdecl.}
    ## Set a runtime error to VM.
  proc pkSetRuntimeErrorFmt*(vm: ptr PKVM, fmt: cstring) {.importc, cdecl, varargs.}
    ## Set a runtime error with C formated string.
  proc pkSetRuntimeErrorObj*(vm: ptr PKVM, slot: cint) {.importc, cdecl.}
    ## Set a runtime error object at slot.
  proc pkGetRuntimeError*(vm: ptr PKVM, slot: cint) {.importc, cdecl.}
    ## Get the runtime error of VM at [slot].
  proc pkGetRuntimeStackReport*(vm: ptr PKVM, slot: cint) {.importc, cdecl.}
    ## Report the runtime error via stderr_write in PkConfiguration.
  proc pkGetSelf*(vm: ptr PKVM): pointer {.importc, cdecl.}
    ## Returns native [self] of the current method as a void*.
  proc pkGetArgc*(vm: ptr PKVM): cint {.importc, cdecl.}
    ## Return the current functions argument count. This is needed for functions
    ## registered with -1 argument count (which means variadic arguments).
  proc pkCheckArgcRange*(vm: ptr PKVM, argc: cint, min: cint, max: cint): bool {.importc, cdecl.}
    ## Check if the argc is in the range of (min <= argc <= max), if it's not, a
    ## runtime error will be set and return false, otherwise return true. Assuming
    ## that min <= max, and pocketlang won't validate this in release binary.
  proc pkValidateSlotBool*(vm: ptr PKVM, slot: cint, value: ptr bool): bool {.importc, cdecl.}
    ## Helper function to check if the argument at the [slot] slot is Boolean and
    ## if not set a runtime error.
  proc pkValidateSlotNumber*(vm: ptr PKVM, slot: cint, value: ptr cdouble): bool {.importc, cdecl.}
    ## Helper function to check if the argument at the [slot] slot is Number and
    ## if not set a runtime error.
  proc pkValidateSlotInteger*(vm: ptr PKVM, slot: cint, value: ptr int32): bool {.importc, cdecl.}
    ## Helper function to check if the argument at the [slot] is an a whold number
    ## and if not set a runtime error.
  proc pkValidateSlotString*(vm: ptr PKVM, slot: cint, value: ptr cstring, length: ptr uint32): bool {.importc, cdecl.}
    ## Helper function to check if the argument at the [slot] slot is String and
    ## if not set a runtime error.
  proc pkValidateSlotType*(vm: ptr PKVM, slot: cint, `type`: PkVarType): bool {.importc, cdecl.}
    ## Helper function to check if the argument at the [slot] slot is of type
    ## [type] and if not sets a runtime error.
  proc pkValidateSlotInstanceOf*(vm: ptr PKVM, slot: cint, cls: cint): bool {.importc, cdecl.}
    ## Helper function to check if the argument at the [slot] slot is an instance
    ## of the class which is at the [cls] index. If not set a runtime error.
  proc pkIsSlotInstanceOf*(vm: ptr PKVM, inst: cint, cls: cint, val: ptr bool): bool {.importc, cdecl.}
    ## Helper function to check if the instance at the [inst] slot is an instance
    ## of the class which is at the [cls] index. The value will be set to [val]
    ## if the object at [cls] slot isn't a valid class a runtime error will be set
    ## and return false.
  proc pkReserveSlots*(vm: ptr PKVM, count: cint) {.importc, cdecl.}
    ## Make sure the fiber has [count] number of slots to work with (including the
    ## arguments).
  proc pkGetSlotsCount*(vm: ptr PKVM): cint {.importc, cdecl.}
    ## Returns the available number of slots to work with. It has at least the
    ## number argument the function is registered plus one for return value.
  proc pkGetSlotType*(vm: ptr PKVM, index: cint): PkVarType {.importc, cdecl.}
    ## Returns the type of the variable at the [index] slot.
  proc pkGetSlotBool*(vm: ptr PKVM, index: cint): bool {.importc, cdecl.}
    ## Returns boolean value at the [index] slot. If the value at the [index]
    ## is not a boolean it'll be casted (only for booleans).
  proc pkGetSlotNumber*(vm: ptr PKVM, index: cint): cdouble {.importc, cdecl.}
    ## Returns number value at the [index] slot. If the value at the [index]
    ## is not a boolean, an assertion will fail.
  proc pkGetSlotString*(vm: ptr PKVM, index: cint, length: ptr uint32): cstring {.importc, cdecl.}
    ## Returns the string at the [index] slot. The returned pointer is only valid
    ## inside the native function that called this. Afterwards it may garbage
    ## collected and become demangled. If the [length] is not NULL the length of
    ## the string will be written.
  proc pkGetSlotHandle*(vm: ptr PKVM, index: cint): ptr PkHandle {.importc, cdecl.}
    ## Capture the variable at the [index] slot and return its handle. As long as
    ## the handle is not released with `pkReleaseHandle()` the variable won't be
    ## garbage collected.
  proc pkGetSlotNativeInstance*(vm: ptr PKVM, index: cint): pointer {.importc, cdecl.}
    ## Returns the native instance at the [index] slot. If the value at the [index]
    ## is not a valid native instance, an assertion will fail.
  proc pkSetSlotNull*(vm: ptr PKVM, index: cint) {.importc, cdecl.}
    ## Set the [index] slot value as pocketlang null.
  proc pkSetSlotBool*(vm: ptr PKVM, index: cint, value: bool) {.importc, cdecl.}
    ## Set the [index] slot boolean value as the given [value].
  proc pkSetSlotNumber*(vm: ptr PKVM, index: cint, value: cdouble) {.importc, cdecl.}
    ## Set the [index] slot numeric value as the given [value].
  proc pkSetSlotString*(vm: ptr PKVM, index: cint, value: cstring) {.importc, cdecl.}
    ## Create a new String copying the [value] and set it to [index] slot.
  proc pkSetSlotStringLength*(vm: ptr PKVM, index: cint, value: cstring, length: uint32) {.importc, cdecl.}
    ## Create a new String copying the [value] and set it to [index] slot. Unlike
    ## the above function it'll copy only the spicified length.
  proc pkSetSlotStringFmt*(vm: ptr PKVM, index: cint, fmt: cstring) {.importc, cdecl, varargs.}
    ## Create a new string copying from the formated string and set it to [index]
    ## slot.
  proc pkSetSlotHandle*(vm: ptr PKVM, index: cint, handle: ptr PkHandle) {.importc, cdecl.}
    ## Set the [index] slot's value as the given [handle]. The function won't
    ## reclaim the ownership of the handle and you can still use it till
    ## it's released by yourself.
  proc pkGetSlotHash*(vm: ptr PKVM, index: cint): uint32 {.importc, cdecl.}
    ## Returns the hash of the [index] slot value. The value at the [index] must be
    ## hashable.
  proc pkPlaceSelf*(vm: ptr PKVM, index: cint) {.importc, cdecl.}
    ## Place the [self] instance at the [index] slot.
  proc pkGetClass*(vm: ptr PKVM, instance: cint, index: cint) {.importc, cdecl.}
    ## Set the [index] slot's value as the class of the [instance].
  proc pkNewInstance*(vm: ptr PKVM, cls: cint, index: cint, argc: cint, argv: cint): bool {.importc, cdecl.}
    ## Creates a new instance of class at the [cls] slot, calls the constructor,
    ## and place it at the [index] slot. Returns true if the instance constructed
    ## successfully.
    ##
    ## [argc] is the argument count for the constructor, and [argv]
    ## is the first argument slot's index.
  proc pkNewRange*(vm: ptr PKVM, index: cint, first: cdouble, last: cdouble) {.importc, cdecl.}
    ## Create a new Range object and place it at [index] slot.
  proc pkNewList*(vm: ptr PKVM, index: cint) {.importc, cdecl.}
    ## Create a new List object and place it at [index] slot.
  proc pkNewMap*(vm: ptr PKVM, index: cint) {.importc, cdecl.}
    ## Create a new Map object and place it at [index] slot.
  proc pkListInsert*(vm: ptr PKVM, list: cint, index: int32, value: cint): bool {.importc, cdecl.}
    ## Insert [value] to the [list] at the [index], if the index is less than zero,
    ## it'll count from backwards. ie. insert[-1] == insert[list.length].
    ## Note that slot [list] must be a valid list otherwise it'll fail an
    ## assertion.
  proc pkListPop*(vm: ptr PKVM, list: cint, index: int32, popped: cint): bool {.importc, cdecl.}
    ## Pop an element from [list] at [index] and place it at the [popped] slot, if
    ## [popped] is negative, the popped value will be ignored.
  proc pkListLength*(vm: ptr PKVM, list: cint): uint32 {.importc, cdecl.}
    ## Returns the length of the list at the [list] slot, it the slot isn't a list
    ## an assertion will fail.
  proc pkGetSubscript*(vm: ptr PKVM, on: cint, key: cint, ret: cint): bool {.importc, cdecl.}
    ## Returns the subscript value (ie. on[key]).
  proc pkSetSubscript*(vm: ptr PKVM, on: cint, key: cint, value: cint): bool {.importc, cdecl.}
    ## Set subscript [value] with the [key] (ie. on[key] = value).
  proc pkCallFunction*(vm: ptr PKVM, fn: cint, argc: cint, argv: cint, ret: cint): bool {.importc, cdecl.}
    ## Calls a function at the [fn] slot, with [argc] argument where [argv] is the
    ## slot of the first argument. [ret] is the slot index of the return value. if
    ## [ret] < 0 the return value will be discarded.
  proc pkCallMethod*(vm: ptr PKVM, instance: cint, `method`: cstring, argc: cint, argv: cint, ret: cint): bool {.importc, cdecl.}
    ## Calls a [method] on the [instance] with [argc] argument where [argv] is the
    ## slot of the first argument. [ret] is the slot index of the return value. if
    ## [ret] < 0 the return value will be discarded.
  proc pkGetAttribute*(vm: ptr PKVM, instance: cint, name: cstring, index: cint): bool {.importc, cdecl.}
    ## Get the attribute with [name] of the instance at the [instance] slot and
    ## place it at the [index] slot. Return true on success.
  proc pkSetAttribute*(vm: ptr PKVM, instance: cint, name: cstring, value: cint): bool {.importc, cdecl.}
    ## Set the attribute with [name] of the instance at the [instance] slot to
    ## the value at the [value] index slot. Return true on success.
  proc pkImportModule*(vm: ptr PKVM, path: cstring, index: cint): bool {.importc, cdecl.}
    ## Import a module with the [path] and place it at [index] slot. The path
    ## sepearation should be '/'. Example: to import module "foo.bar" the [path]
    ## should be "foo/bar". On failure, it'll set an error and return false.
  proc pkGetMainModule*(vm: ptr PKVM, index: cint): bool {.importc, cdecl.}
    ## Returns the main module at the [index] slot.
    ## Returns false if main module don't exist.
