#====================================================================
#
#             NimPK - PocketLang Binding for Nim
#                  Copyright (c) 2022 Ward
#
#====================================================================

import nimpk
import nimpk/src

withNimPkVm:
  # vm.new(...) => create new NpVar
  # vm(...) => syntax sugar for vm.new(...)
  # `==` => compare two NpVar variables
  assert vm.new("string") of NpString
  assert vm("string") of NpString
  assert vm.new("string") == vm("string")

  # vm.name or vm{"name"} => get builtin funciton or class.
  # `of` => check variable kind
  # variable.kind => get variable kind
  # variable.class => get variable class
  assert vm.print == vm{"print"}
  assert vm.String == vm{"String"}
  assert vm.print.kind == NpClosure
  assert vm.print of NpClosure
  assert vm.print.class == vm.Closure
  assert vm.print.class of NpClass

  # vm.import("module") => import a module
  # vm["module"] => syntax sugar for vm.import
  assert vm["lang"] == vm.import("lang")
  assert vm["lang"] of NpModule

  # variable.name or variable{"name"} => get attrib of object
  # variable.name= or variable{"name"}= => set attrib of object
  assert vm.print{"_class"} == vm.Closure
  assert vm.new([1, 2, 3]).length == 3
  vm["lang"].PI = 3.14
  assert vm["lang"].PI == 3.14

  # `.()`(vm, ...) => call a builtin function or class
  # `.()`(variable, ...) => call a method
  # `()`(variable, ...) => call a callable variable (closure, class, or methodbind)
  assert vm.eval of NpClosure
  assert vm.eval("{}") of NpMap
  assert vm.eval("fn return 'hello' end") of NpClosure
  assert vm.eval("fn return 'hello' end")() == "hello"

  # `[]`(variable, key) => get a subscript value of variable
  # `[]=`(variable, key, value) => set subscript value of variable
  var list = vm.new([1, 2, 3])
  assert list[2] == 3
  list[2] = 5
  assert list[2] == 5
  var map = vm.eval("{'a': 1, 'b': 2}")
  assert map["a"] == 1

  # vm.null() => return a NpVar represent null, same but faster than vm.new(nil)
  # vm.list() => create a new list, same but faster than vm.List()
  # vm.map() => create a new map, same but faster than vm.Map()
  # isNull() or isNil() => check if a NpVar is null.
  assert vm.null of NpNull
  assert vm.list of NpList
  assert vm.map of NpMap
  assert isNull(vm.null)

  # vm.list(set), vm.list(tuple, valueOnly=true), or vm.list(object, valueOnly=false)
  #   => convert set, tuple, or object to List.
  # vm.map(set), vm.map(tuple), or vm.map(object)
  #   => convert set, tuple, or object to List.
  assert vm.list({'a', 'b', 'c'}) == vm.new(["a", "b", "c"])
  assert vm.map((1, 2, 3)) == vm.eval("{'Field1':2, 'Field0':1, 'Field2':3}")

  # list.insert(x[, index = 0]) => insert an element into list
  # list.insert(x[, index = 0]) => insert an element into list
  # list.add(x) => append an element into list.
