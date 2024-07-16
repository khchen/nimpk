#====================================================================
#
#          NimPK - Pocketlang Binding for Nim Language
#               Copyright (c) Chen Kai-Hung, Ward
#
#====================================================================

import nimpk
import nimpk/src

# A brief summary of operators provides by NimPk to deal with variables.

withNimPkVm:
  # vm.new(...) => create new NpVar
  # vm(...) => syntax sugar for vm.new(...)
  # `==` => compare two NpVar variables by the VM
  # `of` => check the kind of a variable
  # variable.kind => get the kind of a variable
  # variable.class => get the base class of a variable
  assert vm.new("string") of NpString
  assert vm("string") of NpString
  assert vm.new("string") == vm("string")
  assert vm("string").kind == NpString
  assert vm("string").class == vm.String

  # vm.name or vm{"name"} => get builtin funciton or class
  # `vm.name` is intuitive, but may fail if `name` is invalid identifier,
  # or `name` is already declared.
  assert vm.print == vm{"print"} # `print` is builtin function
  assert vm.print.class == vm.Closure # base class of `print` is `Closure`
  assert vm.String == vm{"String"} # `String` is builtin class
  assert vm.String.class == vm.Class # base class of `String` is `Class`

  # vm.import("module") => import a module
  # vm["module"] => syntax sugar for vm.import
  assert vm["lang"] == vm.import("lang")
  assert vm["lang"] of NpModule

  # variable.name or variable{"name"} => get attrib of object
  # variable.name= or variable{"name"}= => set attrib of object
  assert vm.print.name == "print"
  assert vm.print.arity == -1 # -1 means any
  assert vm.print{"_docs"} of NpString # `_docs` is invalid identifier
  assert vm.print{"_class"} == vm.Closure
  assert vm.new([1, 2, 3]).length == 3

  vm["lang"].PI = 3.14 # module, class, or instance has mutable attribute
  assert vm["lang"].PI == 3.14
  vm["lang"]{"_PI"} = 3.14
  assert vm["lang"]{"_PI"} == 3.14
  vm.String.PI = 3.14
  assert vm.String.PI == 3.14
  try:
    vm.print.PI = 3.14 # closure has no mutable attribute
  except:
    assert getCurrentExceptionMsg() == "'Closure' object has no mutable attribute named 'PI'"

  # `.()`(vm, ...) => call a builtin function or class
  # `.()`(variable, ...) => call a method
  # `()`(variable, ...) => call a callable (closure, class, or methodbind)
  assert vm.eval of NpClosure
  assert vm.eval("{}") of NpMap # call a builtin function: `eval`
  assert vm("1,2,3").split(",") == vm.eval("['1', '2', '3']") # call a method
  assert vm.eval("fn return 'hello' end") of NpClosure
  assert vm.eval("fn return 'hello' end")() == "hello" # call a closure
  assert vm.String("hello") of NpString # call a class => create an instance
  assert vm.String.split of NpMethodBind
  try:
    (vm.String.split)(",") # call a methodbind, but error will occur.
  except:
    assert getCurrentExceptionMsg() == "Cannot call an unbound method."

  assert vm.String.split.bind("1,2,3")(",") of NpList # call a methodbind.

  # `[]`(variable, key) => get a subscript value of variable
  # `[]=`(variable, key, value) => set subscript value of variable
  var list = vm.eval("[0, 1, 2, 3]")
  var map = vm.eval("{'a': 1, 'b': 2}")
  assert list of NpList and map of NpMap
  list[3] = 5
  map["c"] = 3
  assert list[0] == 0 and list[3] == 5
  assert map["a"] == 1 and map["c"] == 3

  # vm.null() => return a NpVar represent null, faster than vm.new(nil)
  # vm.list() => create a new list, faster than vm.List()
  # vm.map() => create a new map, faster than vm.Map()
  # isNull() or isNil() => check if a NpVar is null.
  assert vm.null() of NpNull
  assert vm.list() of NpList
  assert vm.map() of NpMap
  assert isNull(vm.null)

  # vm.list(set)
  # vm.list(tuple, valueOnly=true)
  # vm.list(object, valueOnly=false)
  #   => convert set, tuple, or object to List.
  # vm.map(set)
  # vm.map(tuple)
  # vm.map(object)
  #   => convert set, tuple, or object to Map.
  type
    Object = object
      a, b, c: int
    Tuple = tuple
      a, b, c: int
  assert vm.list({'a', 'b', 'c'}) == vm.new(["a", "b", "c"]) # set
  assert vm.list((1, 2, 3)) == vm.new([1, 2, 3]) # tuple
  assert vm.list(Object(a: 1, b: 2, c: 3), true) == vm.new([1, 2, 3]) # object

  assert vm.map({'a', 'b', 'c'}).keys.sort() == vm.new(["a", "b", "c"]) # set
  assert vm.map((1, 2, 3).Tuple) == vm.eval("{'a':1, 'b':2, 'c':3}") # tuple
  assert vm.map(Object(a: 1, b: 2, c: 3)) == vm.map((1, 2, 3).Tuple) # object

  # list.insert(x[, index = 0]) => insert an element into list.
  # list.add(x) => append an element into list.
  # list.pop(index = -1) => pop an element from list.
  # There are append(), insert() and pop() methods for list in PocketLang.
  # However, these procedures have better performance by using native API.
  list = vm.list()
  list.add("world")
  list.insert("hello")
  assert list == vm.new(["hello", "world"])
  assert list.pop == "world"
  assert list == vm.new(["hello"])

  # By using above operators, nim code can access everything in VM.
  # For example, using built-in re moudle in nim:
  var re = vm["re"]
  assert re.match(r"[A-Za-z]+", "----Hello----")[0] == "Hello"

  # Compile a piece of code by builtin `compile` function.
  var fn = vm.compile """
    return "Hello, world!"
  """

  # And then run it (this is what `vm.run` does).
  assert fn() == "Hello, world!"
