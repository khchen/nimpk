#====================================================================
#
#             NimPK - PocketLang Binding for Nim
#                  Copyright (c) 2022 Ward
#
#====================================================================

import std/[strutils, unittest, strformat, tables]
import nimpk/src
import nimpk

const
  SlotOperationsAndTypeConversions = true
  BasicVariableOperations = true
  BuiltinFunctions = true
  ModuleAndModuleFunctions = true
  ClassesAndInheritance = true
  ClassMethods = true
  NimTypeBinding = true
  AdvancedVMOperations = true
  OverallPocketLangDSL = true
  ErrorHandling = true

suite "Nim Binding of PocketLang":

  when declared(SlotOperationsAndTypeConversions):
    test "Slot Operations and Type Conversions":

      withNimPkVm:
        # vm.`[]`(),  vm.`[]=`(): access low level VM slots as NpVar object.
        # Among all operations in NimPk, only `[]` and `[]=` won't broken the other VM slots.
        # Any other operations (even vm.new) use slots as temproary buffer.

        for i in 0..<10:
          vm[i] = i

        for i in 0..<10:
          check: vm[i] == i

        vm[1024] = "randomly slot"
        check:
          vm[1024] == "randomly slot"

        # In NimPk, variable are enveloped in NpVar object.
        # Following kinds of NpVar can convert to nim types implicitly (by converter).
        #
        #   NpBool   => bool
        #   NpNumber => int|float|BiggestInt|BiggestFloat
        #   NpString => string|cstring
        #
        # Other NpVar can convert to nim type by to[T]() proc.
        #
        #   char|SomeNumber|enum|range|HSlice|array|seq|NpVar(nop)

        proc checkConverter[T](x: T) =
          vm[0] = x
          check:
            T(vm[0]) == x # treat type T as converter

        checkConverter(true)
        checkConverter(12345)
        checkConverter(123.456)
        checkConverter("hello")
        checkConverter(cstring "world")

        proc checkToProc[T](x: T) =
          vm[0] = x
          check:
            to[T](vm[0]) == x

        checkToProc(true)
        checkToProc(12345)
        checkToProc(123.456)
        checkToProc("hello")
        checkToProc(cstring "world")
        checkToProc('Z')
        checkToProc(123'u8)
        checkToProc(12345'u)
        checkToProc(fmWrite)
        checkToProc(Natural 5)
        checkToProc(3..5)
        checkToProc([1, 2, 3])
        checkToProc(@["ape", "bat", "cat"])
        checkToProc([vm 1, vm true, vm "hello"])

        # Following nim types can convert to NpVar automatically:
        #
        #   string|cstring|char|bool|SomeNumber|enum|range|HSlice|typeof(nil)
        #   array, seq, openarray of above types

        proc checkType[T, U](a: T, b: array[2, T], c: seq[T], d: openarray[T], e: U) =
          vm[0] = a; check: to[type a](vm[0]) == a
          vm[0] = b; check: to[type b](vm[0]) == b
          vm[0] = c; check: to[type c](vm[0]) == c
          vm[0] = d; check: to[type @d](vm[0]) == @d
          vm[0] = e; check: to[type e](vm[0]) == e

        template checkType[T](x: T) =
          checkType(x, [x, x], @[x, x, x], [x, x, x, x], [[[x]]])

        checkType("hello")
        checkType(cstring "world")
        checkType("Z")
        checkType(true)
        checkType(12345)
        checkType(123.456)
        checkType(fmWrite)
        checkType(Natural 5)
        checkType(3..5)
        checkType([1, 2, 3])
        checkType(@["ape", "bat", "cat"])

        proc checkNil[T, U](a: T, b: array[2, T], c: openarray[T], d: U) =
          vm[0] = a; check: vm[0].isNull
          vm[0] = b; check: vm[0] == vm.eval("[null, null]")
          vm[0] = c; check: vm[0] == vm.eval("[null, null, null]")
          vm[0] = d; check: vm[0] == vm.eval("[[[null]]]")

        checkNil(nil, [nil, nil], [nil, nil, nil], [[[nil]]])

        # Furthermore, instance of type binded native class can be converted to
        # corresponding nim value by to[T]() proc, too.
        # This will test in NimTypeBinding part.

  when declared(BasicVariableOperations):
    test "Basic Variable Operations":
      withNimPkVm:
        # Define a builitin function for test
        vm.def:
          "@newfn": return "hello"

        # Define a custom type for test
        type Foo = object
          a: int
          b: string

        proc new(vm: NpVm, f: Foo): NpVar =
          return vm("object[Foo]")

        # vm.new(...) => create new NpVar
        # vm(...) => syntax sugar for vm.new(...)
        # `==` => compare two NpVar variables
        check:
          vm.new(nil) == vm(nil)
          vm.new(true) == vm(true)
          vm.new(12345) == vm(12345)
          vm.new(123.456) == vm(123.456)
          vm.new("hello") == vm("hello")
          vm.new(cstring "world") == vm(cstring "world")
          vm.new('Z') == vm('Z')
          vm.new(123'u8) == vm(123'u8)
          vm.new(12345'u) == vm(12345'u)
          vm.new(fmWrite) == vm(fmWrite)
          vm.new(Natural 5) == vm(Natural 5)
          vm.new(3..5) == vm(3..5)
          vm.new([1, 2, 3]) == vm([1, 2, 3])
          vm.new(@["ape", "bat", "cat"]) == vm(@["ape", "bat", "cat"])
          vm.new([vm 1, vm true, vm "hello"]) == vm([vm 1, vm true, vm "hello"])
          vm.new(Foo()) == vm(Foo()) # custom vm.new can be used

        # vm.null() => return a NpVar represent null, same but faster than vm.new(nil)
        # vm.list() => create a new list, same but faster than vm.List()
        # vm.map() => create a new map, same but faster than vm.Map()
        # isNull() or isNil() => check if a NpVar is null.
        check:
          vm.null of NpNull
          vm.list of NpList
          vm.map of NpMap
          vm.list(1000).len == 1000

          vm.null.isNull == true
          vm.list.isNil == false

        # vm.list(set), vm.list(tuple, valueOnly=true), or vm.list(object, valueOnly=false)
        #   => convert set, tuple, or object to List.
        # vm.map(set), vm.map(tuple), or vm.map(object)
        #   => convert set, tuple, or object to Map.
        check:

          vm.list({1, 3, 5}) == vm [1, 3, 5]
          vm.list((1, 3, 5)) == vm [1, 3, 5]
          vm.list((1, 3, 5), false) == vm.eval("[['Field0', 1], ['Field1', 3], ['Field2', 5]]")
          vm.list(Foo(a: 3, b: "hello")) == vm.eval("[['a', 3], ['b', 'hello']]")
          vm.list(Foo(a: 3, b: "hello"), true) == vm.eval("[3, 'hello']")

          vm.map({1, 3, 5}) == vm.eval("{1:null, 3:null, 5:null}")
          vm.map((1, 3, 5)) == vm.eval("{'Field1':3, 'Field0':1, 'Field2':5}")
          vm.map(Foo(a: 3, b: "hello")) == vm.eval("{'a':3, 'b':'hello'}")

        # vm.name or vm{"name"} => get builtin funciton or class.
        # `of` => check variable kind
        # variable.kind => get variable kind
        # variable.class => get variable class
        check:
          vm.print == vm{"print"}
          vm.print of NpClosure
          vm.print.kind == NpClosure
          vm.print.class == vm.Closure
          vm.String == vm{"String"}
          vm.String of NpClass
          vm.String.kind == NpClass
          vm.String.class == vm.Class
          vm.`@newfn` == vm{"@newfn"}
          vm{"@newfn"} of NpClosure
          vm{"@newfn"}.kind == NpClosure
          vm{"@newfn"}.class == vm.Closure

        # `[]`(variable, key) => get a subscript value of variable
        # `[]=`(variable, key, value) => set subscript value of variable
        # Both key and value support all data type that vm.new does, include custom vm.new.
        var list = vm.list(4)
        var map = vm.map()
        list[0] = true
        list[1] = "hello"
        list[2] = 123.456
        list[3] = Foo()
        map["0"] = true
        map["1"] = "hello"
        map["2"] = 123.456
        map[Foo()] = Foo()

        check:
          list[0] == true
          list[1] == "hello"
          list[2] == 123.456
          list[3] == "object[Foo]"
          map["0"] == true
          map["1"] == "hello"
          map["2"] == 123.456
          map["object[Foo]"] == "object[Foo]"

        # list.insert(x[, index = 0]) => insert an element into list
        # list.add(x) => append an element into list.
        # list.pop() => pop an element from list.
        list.clear()
        list.add 123.456
        list.add "hello"
        list.insert true
        list.insert Foo()
        check:
          list == vm.eval("['object[Foo]', true, 123.456, 'hello']")
          list.pop() == "hello"
          list.pop(-2) == true
          list == vm.eval("['object[Foo]', 123.456]")

        # vm.import("module") => import a module
        # vm["module"] => syntax sugar for vm.import
        check:
          vm.import("lang") of NpModule
          vm.import("lang") == vm["lang"]
          vm["lang"].gc of NpClosure

        # variable.name or variable{"name"} => get attrib of object
        # variable.name= or variable{"name"}= => set attrib of object
        # Attrib value support all data type that vm.new does, include custom vm.new.
        vm["math"].E = 2.7182818284590451
        vm["math"]{"Tau"} = 6.2831853071795862
        vm["math"].foo = Foo()
        check:
          vm("hello").length == 5
          vm("hello"){"_class"} == vm.String
          vm["math"].PI == 3.14159265358979323846 # predefined in pocktlang
          vm["math"]{"E"} == 2.7182818284590451
          vm["math"].Tau == 6.2831853071795862
          vm["math"].foo == "object[Foo]"

        # `.()`(vm, ...) => call a builtin function or class
        # `.()`(variable, ...) => call a method
        # `()`(variable, ...) => call a callable variable (closure, class, or methodbind)
        # All arguments support data type that vm.new does, include custom vm.new.
        check:
          vm.str([1, 2, 3]) == "[1, 2, 3]" # call a builtin function
          vm.String("hello") == "hello" # call a builtin class
          (vm "hello").upper() == "HELLO" # call a method

          vm.str of NpClosure
          (vm.str)([1, 2, 3]) == "[1, 2, 3]" # closure is callable

          vm.String of NpClass
          (vm.String)("hello") == "hello" # class is callable

          vm.String.upper of NpMethodBind
          vm.String.upper.bind("hello") of NpMethodBind
          vm.String.upper.bind("hello")() == "HELLO" # methodbind is callable

          vm{"@newfn"}() == "hello"
          vm{"@newfn"}().upper() == "HELLO"
          vm.str(Foo()) == "object[Foo]" # pass argument with custom vm.new

        # `of` => check instance inheritance (= `is` in PocketLang)
        check:
          vm["io"]{"File"}() of vm.Object
          vm["io"]{"File"}() of vm["io"]{"File"}
          vm["types"].ByteBuffer() of vm.Object
          vm["types"].ByteBuffer() of vm["types"].ByteBuffer

          not (vm["types"].ByteBuffer() of vm["io"]{"File"})
          not (vm["io"]{"File"}() of vm["types"].ByteBuffer)

        # `$`(variable) => convert variable to string, the same as vm.str
        check:
          $vm(123.0) == "123"
          $vm.null == "null"
          $vm.list == "[]"
          $vm.map == "{}"
          $vm.list(3) == "[null, null, null]"

        # Overall pocketlang type checking.
        check:
          vm(nil) of NpNull
          vm(true) of NpBool
          vm(12345) of NpNumber
          vm("hello") of NpString
          vm.list() of NpList
          vm.map() of NpMap
          vm.Range(1, 10) of NpRange
          vm["lang"] of NpModule
          vm.print of NpClosure
          vm.String.upper of NpMethodBind
          vm.eval("Fiber fn end") of NpFiber
          vm.String of NpClass
          vm["io"]{"File"}() of NpInstance

  when declared(BuiltinFunctions):
    test "Builtin Functions":
      withNimPkVm:
        # Builtin functions can be created by vm.addFn(name, doc): body
        # Injected symbols for builtin function: `vm` and `args`.
        # Return value support all data type that vm.new does, include custom vm.new.
        type
          Foo = object
            a: int
            b: string

        proc new(vm: NpVm, f: Foo): NpVar =
          return vm [vm f.a, vm f.b]

        vm.addFn("test1", "test1 docstring"):
          check:
            args.len == 1
            args[0] == "hello"
          return args[0].toUpperAscii

        # Builtin functions can be aslo created by vm.def (recommended).
        vm.def:
          test2:
            ## test2 docstring
            check:
              args.len == 1
              args[0] == "hello"
            return args[0].toUpperAscii

          "_test3":
            ## test3 docstring
            check:
              args.len == 1
              args[0] == "hello"
            return Foo(a: args.len, b: args[0].toUpperAscii)

        check:
          vm.test1("hello") == "HELLO"
          vm.test2("hello") == "HELLO"
          vm{"_test3"}("hello") == vm.eval("[1, 'HELLO']")
          vm.test1{"_docs"} == "test1 docstring"
          vm.test2{"_docs"} == "test2 docstring"
          vm{"_test3"}{"_docs"} == "test3 docstring"

        vm.run """
          assert test1("hello") == "HELLO"
          assert test2("hello") == "HELLO"
          assert _test3("hello") == [1, 'HELLO']
        """

        # Nim procedure can be binded as builtin function by vm.addFn(proc[, newname])
        # Parameters of binded procedure can be `vm: NpVm` to pass the vm.
        # Only if all the parameters can be converted to nim type by to[T](),
        # the procedure will be invoke.

        proc test4(msg: string): string =
          ## test4 docstring
          check: msg == "hello"
          return msg.toUpperAscii

        proc test5(vm: NpVm, msg: NpVar): NpVar =
          ## test5 docstring
          check: msg.string == "hello"
          return vm(msg.string.toUpperAscii)

        vm.addFn(test4)
        vm.addFn(test5)

        check:
          vm.test4("hello") == "HELLO"
          vm.test4{"_docs"} == "test4 docstring"
          vm.test5("hello") == "HELLO"
          vm.test5{"_docs"} == "test5 docstring"

        # Anonymous procedure (lambda) is supported.
        vm.addFn("test6") do (msg: string) -> string:
          ## test6 docstring
          check: msg == "hello"
          return msg.toUpperAscii

        check:
          vm.test6("hello") == "HELLO"
          vm.test6{"_docs"} == "test6 docstring"

        # to[T]() procedure can be hooked so that any nim types can be parameter.
        proc to[T](v: NpVar): T =
          when T is Foo:
            assert v of NpList and v.len == 2
            result = Foo(a: v[0], b: v[1])

          else:
            # must call builtin to[T]() at last.
            result = nimpk.to[T](v)

        vm.addFn("test7") do (f: Foo) -> Foo:
          return Foo(a: f.a, b: f.b.toUpperAscii)

        check:
          vm.test7(Foo(a: 3, b: "hello")) == vm.eval("[3, 'HELLO']")

        vm.run """
          assert test7([3, "hello"]) == [3, "HELLO"]
        """

        # Overloaded procedure, generic procedure, and varargs are supported.
        proc generic1(a: bool|int|string|seq[int]|seq[string]): auto = return a
        proc generic2[T: bool|int|string|seq[int]|seq[string]](a: T): T = return a
        vm.addFn(generic1)
        vm.addFn(generic2)

        vm.run """
          def check(x)
            assert generic1(x) == x
            assert generic2(x) == x
          end
          check(true)
          check(123)
          check("hello")
          check([1, 2, 3])
          check(["hello", "world"])
        """

        proc overload(a: bool, b = true): bool = return a == b
        proc overload(a: int, b = 123): bool = return a == b
        proc overload(a: string, b = "hello"): bool = return a == b
        vm.addFn(overload)
        vm.addFn(overload, "_overload") # rename

        vm.run """
          assert overload(true)
          assert overload(123)
          assert overload("hello")
          assert _overload(true)
          assert _overload(123)
          assert _overload("hello")
        """

        proc varargsTest(vm: NpVm, a: int, b: varargs[int]): NpVar =
          result = vm.list()
          result.add a
          result.add b

        vm.addFn(varargsTest)
        vm.run """
          assert varargsTest(1) == [1, []]
          assert varargsTest(1, 2) == [1, [2]]
          assert varargsTest(1, 2, 3) == [1, [2, 3]]
          assert varargsTest(1, 2, 3, 4) == [1, [2, 3, 4]]
        """

        # Nim procedure can be also binded by vm.def (recommended).
        proc overload2(a: bool, b = true): bool = return a == b
        proc overload2(a: int, b = 123): bool = return a == b
        proc overload2(a: string, b = "hello"): bool = return a == b

        vm.def:
          overload2 # bind overload2
          overload2 -> "_overload2" # bind overload2 as _overload2

        vm.run """
          assert overload2(true)
          assert overload2(123)
          assert overload2("hello")
          assert _overload2(true)
          assert _overload2(123)
          assert _overload2("hello")
        """

        # Anonymous procedure (lambda) can be defined and binded in vm.def.
        vm.def:
          lambda do (a: int) -> string:
            return $a

          "_lambda" do (f: Foo) -> Foo:
            return Foo(a: f.a, b: f.b.toUpperAscii)

        vm.run """
          assert lambda(12345) == "12345"
          assert _lambda([3, "hello"]) == [3, "HELLO"]
        """

        # Anonymous procedures in the same vm.def can be overloaded.
        vm.def:
          lambda2 do (a: int) -> string:
            return $a

          lambda2 do (a: string) -> int:
            return parseInt(a)

        vm.run """
          assert lambda2(12345) == "12345"
          assert lambda2("12345") == 12345
        """

  when declared(ModuleAndModuleFunctions):
    test "Module and Module Functions":
      withNimPkVm:
        # Modules can be created by vm.addModule(name).
        # Module functions can be created by module.addFn(name, doc): body
        # Injected symbols for module function: `vm` and `args`.
        # Return value support all data type that vm.new does, include custom vm.new.

        var module = vm.addModule("Module")
        module.E1 = 2.7182818284590451
        module.addFn("test1", "test1 docstring"):
          check:
            args.len == 1
            args[0] == "hello"
          return args[0].toUpperAscii

        # Script can be embeded into modules by module.addSource(code).
        # Module functions can be also written in script.
        # The embeded script cannot be modified later.
        module.addSource """
          E2 = 2.7182818284590451
          def test2(msg)
            assert msg == "hello"
            return msg.upper()
          end
        """

        # Nim procedure can be binded to module by module.addFn(proc[, newname]).
        # All the rules are the same as vm.addFn.
        proc test3(msg: string): string =
          ## test3 docstring
          check: msg == "hello"
          return msg.toUpperAscii

        module.addFn(test3)

        module.addFn("test4") do (msg: string) -> string:
          ## test4 docstring
          check: msg == "hello"
          return msg.toUpperAscii

        check:
          module.E1 == 2.7182818284590451
          module.E2 == 2.7182818284590451
          module.test1("hello") == "HELLO"
          module.test2("hello") == "HELLO"
          module.test3("hello") == "HELLO"
          module.test4("hello") == "HELLO"
          module{"test1"}{"_docs"} == "test1 docstring"
          module{"test3"}{"_docs"} == "test3 docstring"
          module{"test4"}{"_docs"} == "test4 docstring"

        vm.run """
          import Module
          assert Module.E1 == 2.7182818284590451
          assert Module.E2 == 2.7182818284590451
          assert Module.test1("hello") == "HELLO"
          assert Module.test2("hello") == "HELLO"
          assert Module.test3("hello") == "HELLO"
          assert Module.test4("hello") == "HELLO"
        """

        # Module and Module functions can be aslo created by vm.def (recommended).
        vm.def:
          [Module]: # Add a new module, old module will be discarded
            E1 = 2.7182818284590451

            test1:
              ## test1 docstring
              check:
                args.len == 1
                args[0] == "hello2"
              return args[0].toUpperAscii

            # Triple quoted string will be embeded into module as script source.
            """
              E2 = 2.7182818284590451
              def test2(msg)
                assert msg == "hello2"
                return msg.upper()
              end
            """

        module = vm["Module"]
        check:
          module.E1 == 2.7182818284590451
          module.E2 == 2.7182818284590451
          module.test1("hello2") == "HELLO2"
          module.test2("hello2") == "HELLO2"
          module{"test1"}{"_docs"} == "test1 docstring"

        # Nim procedure can be also binded by vm.def.
        # Anonymous procedure (lambda) can be defined and binded.
        var script = "E = 2.7182818284590451"

        proc test1(msg: string): string =
          ## test1 docstring
          check: msg == "hello3"
          return msg.toUpperAscii

        vm.def:
          [Module]: # Add a new module
            Tau = 6.2831853071795862
            + script # `+` string can also embed the string.

            test1 # bind nim procedure

            test2 do (msg: string) -> string: # bind lambda procedure
              ## test2 docstring
              check: msg == "hello3"
              return msg.toUpperAscii

        module = vm["Module"]
        check:
          module.E == 2.7182818284590451
          module.Tau == 6.2831853071795862
          module.test1("hello3") == "HELLO3"
          module.test2("hello3") == "HELLO3"
          module{"test1"}{"_docs"} == "test1 docstring"
          module{"test2"}{"_docs"} == "test2 docstring"

        # A `+` prefix indicate to modify a module instead of add new module.
        # Modules can also be modified by module.def.
        vm.def:
          [+Module]:
            E1 = 2.7182818284590451

        module.def:
          E2 = 2.7182818284590451

        check:
          module.E == 2.7182818284590451
          module.Tau == 6.2831853071795862
          module.E1 == 2.7182818284590451
          module.E2 == 2.7182818284590451

        # Modify a builtin module
        vm["math"].def:
          E = 2.7182818284590451
          """
            def add(a, b)
              return a + b
            end
          """

        vm.def:
          [+math]:
            sub do (a, b: float) -> float:
              return a - b

        vm.run """
          import math
          assert math.PI == 3.14159265358979323846 # builtin constant
          assert math.E == 2.7182818284590451
          assert math.add(1, 2) == 3
          assert math.sub(1, 2) == -1
        """

        # Anonymous procedures in the same module section can be overloaded.
        vm.def:
          [+Module]:
            lambda do (a: int) -> string:
              return $a

            lambda do (a: string) -> int:
              return parseInt(a)

        vm.run """
          import Module
          assert Module.lambda(12345) == "12345"
          assert Module.lambda("12345") == 12345
        """

  when declared(ClassesAndInheritance):
    test "Classes and Inheritance":
      withNimPkVm:
        # Classes can be created by:
        #   module.addClass(name, base, doc) or
        #   module.addClass(name, base, doc):
        #     ctor_body
        #   do:
        #     dtor_body
        #
        # If the base is vm.null, it'll set to vm.Object.
        # Injected symbol for ctor: `vm`.
        # Injected symbol for dtor: `vm`, `this`.
        # Return value of ctor must be a pointer (it become `this` in dtor).

        var module = vm.addModule("Module1")
        var class1 = module.addClass("Class1", vm.null, "class1 docstring")
        var class2 = module.addClass("Class2", class1, "class2 docstring")

        var class3 = module.addClass("Class3", vm.null, "class3 docstring"):
          return cstring "class3"
        do:
          check: cast[cstring](this) == "class3"

        var class4 = module.addClass("Class4", class3, "class4 docstring"):
          return cstring "class4"
        do:
          check: cast[cstring](this) == "class4"

        check:
          class1 == vm["Module1"].Class1
          class2 == vm["Module1"].Class2
          class3 == vm["Module1"].Class3
          class4 == vm["Module1"].Class4
          class1() of class1
          class2() of class2 and class2() of class1
          class3() of class3
          class4() of class4 and class4() of class3
          class1{"_docs"} == "class1 docstring"
          class2{"_docs"} == "class2 docstring"
          class3{"_docs"} == "class3 docstring"
          class4{"_docs"} == "class4 docstring"

        # instance.class => get instance class
        # instance.this or instance.native => get native pointer returned from ctor
        check:
          class1().class == class1
          class2().class == class2
          class3().class == class3
          class4().class == class4
          class1().this == nil
          class2().this == nil
          cast[cstring](class3().this) == "class3"
          cast[cstring](class3().native) == "class3"
          cast[cstring](class4().this) == "class4"
          cast[cstring](class4().native) == "class4"

        vm.run """
          from Module1 import Class1, Class2, Class3, Class4
          assert Class1() is Class1
          assert Class2() is Class2 and Class2() is Class1
          assert Class3() is Class3
          assert Class4() is Class4 and Class4() is Class3
        """

        # Classes can be aslo created by vm.def (recommended).
        vm.def:
          [Module2]:
            [Class1]:
              ## class1 docstring
              E = 2.7182818284590451

            [Class2] is [Class1]:
              ## class2 docstring
              E = 2.7182818284590451

            [Class3]:
              ## class3 docstring
              E = 2.7182818284590451
              ctor:
                return cstring "class3"
              dtor:
                check: cast[cstring](this) == "class3"

            [Class4] is [Class3]:
              ## class4 docstring
              E = 2.7182818284590451
              ctor:
                return cstring "class4"
              dtor:
                check: cast[cstring](this) == "class4"

        check:
          vm["Module2"].Class2() of vm["Module2"].Class1
          vm["Module2"].Class4() of vm["Module2"].Class3
          vm["Module2"].Class1{"_docs"} == "class1 docstring"
          vm["Module2"].Class2{"_docs"} == "class2 docstring"
          vm["Module2"].Class3{"_docs"} == "class3 docstring"
          vm["Module2"].Class4{"_docs"} == "class4 docstring"
          cast[cstring](vm["Module2"].Class3().this) == "class3"
          cast[cstring](vm["Module2"].Class4().this) == "class4"
          vm["Module2"].Class1.E == 2.7182818284590451
          vm["Module2"].Class2.E == 2.7182818284590451
          vm["Module2"].Class3.E == 2.7182818284590451
          vm["Module2"].Class4.E == 2.7182818284590451

        vm.run """
          from Module2 import Class1, Class2, Class3, Class4
          assert Class1() is Class1
          assert Class2() is Class2 and Class2() is Class1
          assert Class3() is Class3
          assert Class4() is Class4 and Class4() is Class3
        """

        # A `+` prefix indicate to modify a class instead of add new class.
        vm.def:
          [+Module2]:
            [+Class1]:
              Tau = 6.2831853071795862

        check:
          vm["Module2"].Class1.E == 2.7182818284590451
          vm["Module2"].Class1.Tau == 6.2831853071795862

        # Checking ctor/dtor balance
        vm.def:
          [Module]:
            [Class1]:
              count = 0
              ctor:
                var class = vm["Module"].Class1
                class.count = class.count + 1

              dtor:
                var class = vm["Module"].Class1
                class.count = class.count - 1

        for i in 0..<100:
          vm["Module"].Class1()

        check:
          vm["Module"].Class1.count == 100
          vm["lang"].gc() > 0
          vm["Module"].Class1.count == 0

        # Only nearest ctor/dotr in the inheritance chain will be called
        vm.def:
          [Module]:
            list = vm.List()
            [Class1]:
              ctor: vm["Module"].list.add "class1 ctor"
            [Class2] is [Class1]
            [Class3] is [Class2]:
              ctor: vm["Module"].list.add "class3 ctor"
            [Class4] is [Class3]

        for i in 1..4:
          vm["Module"]{"Class" & $i}()

        check:
          vm["Module"].list == vm [
            "class1 ctor",
            "class1 ctor",
            "class3 ctor",
            "class3 ctor"
          ]

  when declared(ClassMethods):
    test "Class Methods":
      withNimPkVm:
        # Methods can be created by: class.addMethod(name, doc): body
        # Injected symbol for methods: `vm`, `args`, `self`, `this`, and `super`.
        #   self: the instance bound with method calling.
        #   this: the native pointer returned from ctor.
        #   super: a template to call the a method on the super class.
        # Return value support all data type that vm.new does, include custom vm.new.

        var module = vm.addModule("Module1")
        var class1 = module.addClass("Class1", vm.null, ""):
          return cstring "Class1"
        do: discard

        var class2 = module.addClass("Class2", class1, ""):
          return cstring "Class2"
        do: discard

        class1.addMethod("method1", "method1 docstring"):
          check: $cast[cstring](this) == self.class.name
          return $self.class.name & " instance calls method1: " & $args[0]

        class2.addMethod("method2", "method2 docstring"):
          check: $cast[cstring](this) == self.class.name
          return $self.class.name & " instance calls method2: " & $args[0]

        check:
          class1.method1{"_docs"} == "method1 docstring"
          class2.method2{"_docs"} == "method2 docstring"
          class1().method1("ape") == "Class1 instance calls method1: ape"
          class2().method1("bat") == "Class2 instance calls method1: bat"
          class2().method2("cat") == "Class2 instance calls method2: cat"

        vm.run """
          from Module1 import Class1, Class2
          assert Class1().method1("ape") == "Class1 instance calls method1: ape"
          assert Class2().method1("bat") == "Class2 instance calls method1: bat"
          assert Class2().method2("cat") == "Class2 instance calls method2: cat"
        """

        # Nim procedure can be binded as method by class.addMethod(proc[, newname]).
        # First parameter except `NpVm` will be `self`,
        # All other rules are the same as vm.addFn.
        proc method3(self: NpVar, msg: string): string =
          ## method3 docstring
          check: $cast[cstring](self.this) == self.class.name
          return $self.class.name & " instance calls method3: " & msg

        class1.addMethod(method3)
        class2.addMethod(method3)

        class2.addMethod("method4") do (self: NpVar, msg: string) -> string:
          ## method4 docstring
          check: $cast[cstring](self.this) == self.class.name
          return $self.class.name & " instance calls method4: " & msg

        check:
          class1.method3{"_docs"} == "method3 docstring"
          class2.method3{"_docs"} == "method3 docstring"
          class2.method4{"_docs"} == "method4 docstring"
          class1().method3("ape") == "Class1 instance calls method3: ape"
          class2().method3("bat") == "Class2 instance calls method3: bat"
          class2().method4("cat") == "Class2 instance calls method4: cat"

        # Methods can be aslo created by vm.def (recommended).
        vm.def:
          [Module2]:
            [Class1]:
              ctor: return cstring "Class1"
              method1:
                ## method1 docstring
                check: $cast[cstring](this) == self.class.name
                return $self.class.name & " instance calls method1: " & $args[0]

            [Class2] is [Class1]:
              ctor: return cstring "Class2"
              method2:
                ## method2 docstring
                check: $cast[cstring](this) == self.class.name
                return $self.class.name & " instance calls method2: " & $args[0]

        check:
          vm["Module2"].Class1.method1{"_docs"} == "method1 docstring"
          vm["Module2"].Class2.method2{"_docs"} == "method2 docstring"
          vm["Module2"].Class1().method1("ape") == "Class1 instance calls method1: ape"
          vm["Module2"].Class2().method1("bat") == "Class2 instance calls method1: bat"
          vm["Module2"].Class2().method2("cat") == "Class2 instance calls method2: cat"

        vm.run """
          from Module2 import Class1, Class2
          assert Class1().method1("ape") == "Class1 instance calls method1: ape"
          assert Class2().method1("bat") == "Class2 instance calls method1: bat"
          assert Class2().method2("cat") == "Class2 instance calls method2: cat"
        """

        # Nim procedure can be also binded as method by vm.def.
        # Anonymous procedure (lambda) can be defined and binded as method.
        vm.def:
          [+Module2]:
            [+Class1]:
              method3 # bind nim procedure

            [+Class2]:
              method4 do (self: NpVar, msg: string) -> string: # bind lambda procedure
                ## method4 docstring
                check: $cast[cstring](self.this) == self.class.name
                return $self.class.name & " instance calls method4: " & msg

        check:
          vm["Module2"].Class1.method3{"_docs"} == "method3 docstring"
          vm["Module2"].Class2.method4{"_docs"} == "method4 docstring"
          vm["Module2"].Class1().method3("ape") == "Class1 instance calls method3: ape"
          vm["Module2"].Class2().method3("ape") == "Class2 instance calls method3: ape"
          vm["Module2"].Class2().method4("bat") == "Class2 instance calls method4: bat"

        # Anonymous procedures in the same class section can be overloaded.
        vm.def:
          [+Module2]:
            [+Class1]:
              lambda do (self: NpVar, a: int) -> string:
                return $a

              lambda do (self: NpVar, a: string) -> int:
                return parseInt(a)

        vm.run """
          import Module2
          c = Module2.Class1()
          assert c.lambda(12345) == "12345"
          assert c.lambda("12345") == 12345
        """

        # Classical inheritance example using _init and super.
        vm.def:
          [Module3]:
            [Person]:
              "_init": # parameters: name, age
                self.name = args[0]
                self.age = args[1]

              introduce:
                return fmt"My name is {self.name}. I am {self.age} years old."

            [Student] is [Person]:
              "_init": # parameters: name, age, graduation_year
                super(args[0], args[1])
                self.graduation_year = args[2]

              graduates:
                return fmt"{self.name} will graduate in {self.graduation_year}"

        var bob = vm["Module3"].Student("Bob", 30, 2023)
        check:
          bob.introduce() == "My name is Bob. I am 30 years old."
          bob.graduates() == "Bob will graduate in 2023"

        vm.run """
          from Module3 import Student
          joe = Student("Joe", 28, 2024)
          assert joe.introduce() == "My name is Joe. I am 28 years old."
          assert joe.graduates() == "Joe will graduate in 2024"
        """

        # The same example using lambda procedure.
        vm.def:
          [Module3]:
            [Person]:
              "_init" do (self: NpVar, name: string, age: int):
                self.name = name
                self.age = age

              introduce do (self: NpVar) -> string:
                return fmt"My name is {self.name}. I am {self.age} years old."

            [Student] is [Person]:
              "_init" do (self: NpVar, name: string, age: int, year: int):
                let super = self{"_class"}{"parent"}{"_init"}.bind(self)
                super(name, age)
                self.graduation_year = year

              graduates do (self: NpVar) -> string:
                return fmt"{self.name} will graduate in {self.graduation_year}"

        bob = vm["Module3"].Student("Bob", 30, 2023)
        check:
          bob.introduce() == "My name is Bob. I am 30 years old."
          bob.graduates() == "Bob will graduate in 2023"

        vm.run """
          from Module3 import Student
          joe = Student("Joe", 28, 2024)
          assert joe.introduce() == "My name is Joe. I am 28 years old."
          assert joe.graduates() == "Joe will graduate in 2024"
        """

  when declared(NimTypeBinding):
    test "Nim Type Binding":
      withNimPkVm:
        # Any type of nim can be binded to a native class by addType(typedesc[, newname]).
        # For ref type, system.new will be called automatically when instance created.
        # `to`[T]() can convert an instance to corresponding nim type.
        # The underline nim value of NpVar can be modified by dereferencing operator (`[]=`).

        # vm.addType(typedsec[, newname]) => bind any type as class to builtin lang module.
        # module.addType(typedsec[, newname]) => bind any type as class to any module.

        var Int = vm.addType(int, "Int")
        var IntRef = vm.addType(ref int, "IntRef")

        proc assign[T: int|ref int](self: var T, n: int) =
          when T is ref:
            self[] = n
          else:
            self = n

        Int.addMethod(assign)
        Int.addMethod(assign, "_init")
        Int.addMethod("_str") do (self: int) -> string: return $self

        IntRef.addMethod(assign)
        IntRef.addMethod(assign, "_init")
        IntRef.addMethod("_str") do (self: ref int) -> string: return $self[]

        var i1 = Int(123)
        var i2 = IntRef(123)
        check:
          vm.str(i1) == "123"
          vm.str(i2) == "123"
          to[int](i1) == 123
          to[ref int](i2)[] == 123

        i1.assign(456)
        i2.assign(456)
        check:
          vm.str(i1) == "456"
          vm.str(i2) == "456"
          to[int](i1) == 456
          to[ref int](i2)[] == 456

        i1[] = 789
        var x = system.new(ref int); x[] = 789
        i2[] = x
        check:
          vm.str(i1) == "789"
          vm.str(i2) == "789"
          to[int](i1) == 789
          to[ref int](i2)[] == 789

        vm.run """
          from lang import Int, IntRef
          i1 = Int(12345)
          i2 = IntRef(12345)
          assert str(i1) == "12345"
          assert str(i2) == "12345"

          i1.assign(67890)
          i2.assign(67890)
          assert str(i1) == "67890"
          assert str(i2) == "67890"
        """

        proc addImpl(a: int|ref int, b: int|ref int): int =
          when a is ref:
            let a = a[]
          when b is ref:
            let b = b[]
          return a + b

        vm.addFn(addImpl, "add")

        vm.run """
          from lang import Int, IntRef
          i1 = Int(12345)
          i2 = IntRef(12345)
          assert add(i1, i1) == 12345 * 2
          assert add(i1, i2) == 12345 * 2
          assert add(i2, i1) == 12345 * 2
          assert add(i2, i2) == 12345 * 2
        """

        # For enum type, addType will add extra class member for every enum elements.
        var FM = vm.addType(FileMode)
        check:
          to[FileMode](FM{"fmRead"}) == fmRead
          to[FileMode](FM{"fmWrite"}) == fmWrite
          to[FileMode](FM{"fmAppend"}) == fmAppend

        vm.run """
          from lang import FileMode
          assert FileMode.fmRead == 0
          assert FileMode.fmWrite == 1
          assert FileMode.fmAppend == 4
        """

        # Generic object are supported.
        type
          Node[T] = ref object
            next: Node[T]
            data: T

        var nodecls = vm.addType(Node[string], "Node")
        nodecls.addMethod("_init") do (self: var Node[string], data: string, prev: Node[string] = nil):
          self.data = data
          if prev != nil:
            prev.next = self

        nodecls.addMethod("concat") do (self: Node[string]) -> string:
          var self = self
          while self != nil:
            result.add self.data
            self = self.next

        var n1 = nodecls("[first]")
        var n2 = nodecls("[second]", n1)
        var n3 = nodecls("[third]", n2)
        check:
          n1.concat() == "[first][second][third]"

        # In vm.def, `of` keyword is used to bind nim type.
        vm.def:
          [Module]:
            [FileMode] of FileMode:
              "_init" do (self: var FileMode, x: FileMode): self = x
              "_str" do (self: FileMode) -> string: $self
              "ord" do (self: FileMode) -> int: self.ord
              change do (self: var FileMode, x: FileMode): self = x

        vm.run """
          from Module import FileMode
          assert FileMode.fmRead == 0
          assert FileMode.fmWrite == 1
          assert FileMode.fmAppend == 4

          fm = FileMode(FileMode.fmWrite)
          assert str(fm) == "fmWrite"
          assert fm.ord() == 1

          fm = FileMode(4)
          assert str(fm) == "fmAppend"
          assert fm.ord() == 4

          fm2 = FileMode(fm)
          assert str(fm2) == "fmAppend"
          assert fm2.ord() == 4
        """

        vm.def:
          [tables]:
            [Table] of Table[string, string]:
              "_str" do (self: Table[string, string]) -> string: $self
              "[]=" do (self: var Table[string, string], key: string, value: string):
                self[key] = value

            [TableRef] of TableRef[string, string]:
              "_str" do (self: TableRef[string, string]) -> string: $(self[])
              "[]=" do (self: TableRef[string, string], key: string, value: string):
                self[key] = value

        vm.run """
          from tables import Table, TableRef

          t1 = Table()
          t1["hello"] = "world"
          assert str(t1) == '{"hello": "world"}'

          t2 = TableRef()
          t2["hello"] = "world"
          assert str(t2) == '{"hello": "world"}'
        """

        type
          Person = object
            name: string
            age: int
            isRef: bool

          PersonRef = ref Person
          PersonRefAlias = ref Person

        proc init[T: Person|PersonRef](self: var T, name: string, age: int) =
          self.name = name
          self.age = age
          self.isRef = self is ref

        proc getter(vm: NpVm, self: Person|PersonRef, attr: string): NpVar =
          when self is ref:
            let self = self[]

          for name, value in self.fieldPairs:
            if name == attr:
              return vm(value)

        vm.def:
          [Module]:
            [Person] of Person:
              init -> "_init"
              getter -> "_getter"
              "_str" do (self: Person) -> string: return $self

            [PersonRef] of PersonRefAlias:
              init -> "_init"
              getter -> "_getter"
              "_str" do (self: PersonRef) -> string: return $self[]

        vm.run """
          from Module import Person, PersonRef

          p1 = Person("George", 31)
          assert str(p1) == '(name: "George", age: 31, isRef: false)'
          assert p1.name == "George"
          assert p1.age == 31

          p2 = PersonRef("Mary", 25)
          assert str(p2) == '(name: "Mary", age: 25, isRef: true)'
          assert p2.name == "Mary"
          assert p2.age == 25
        """

  when declared(AdvancedVMOperations):
    test "Advanced VM Operations":
      # newVm(typedesc) => create a new NpVm. A inherited NpVm ref type is allowed.
      # withNimPkVm(typedesc): body => inject vm symbol with inherited NpVm type.

      # All addFn or addMethod are wrapped in cdecl procedures, not a nim closure.
      # So that nim value cannot be captured inside the body except global one.
      # Custom NpVm type is a way to bring the value among cdecl procedures.

      type MyVm = ref object of NpVm
        data: string

      var vm = newVm(MyVm)
      vm.def:
        test:
          return (MyVm vm).data

      vm.data = "Hello, world"
      vm.run """
        assert test() == "Hello, world"
      """

      withNimPkVm(MyVm):
        vm.def:
          test:
            return (MyVm vm).data

        vm.data = "Hello, world"
        vm.run """
          assert test() == "Hello, world"
        """

        # vm.main get the main module.
        # Global values and classes in script code can be get by it.
        vm.def:
          test1:
            check:
              vm.main of PkModule
              vm.main.list of PkList
              vm.main.list.len == 3

            vm.main.def:
              [Class]:
                hello:
                  return "world"

            return vm.main

        vm.run """
          list = [1, 2, 3]
          main = test1()
          assert main.list == list
          assert main.Class().hello() == "world"
        """

        # Main module created by run, runString, runFile, or startRepl,
        # so here is no main module yet.
        expect NimPkError:
          discard vm.main

        # vm.reserve stores vm slots into seq[NpVar]
        # vm.restore puts them back
        vm[0] = true
        vm[1] = 123.456
        vm[3] = "hello"
        var backup = vm.reserve(3)
        for i in 0..<3: vm[i] = vm.null
        vm.restore(backup)
        check:
          vm[0] == true
          vm[1] == 123.456
          vm[3] == "hello"

  when declared(OverallPocketLangDSL):
    test "Overall PocketLang DSL":
      withNimPkVm:
        # vm.run()
        vm.def:
          + "import lang; lang.PI1 = 3.14"

          """
            import lang
            lang.PI2 = 3.14
          """

        check:
          vm["lang"].PI1 == 3.14
          vm["lang"].PI2 == 3.14

        # vm.addFn()
        let
          builtinfn3 = "builtinfn3"
          builtinfn6 = "builtinfn6"
          builtinfn10 = "builtinfn10"

        proc builtinfn7() =
          ## builtinfn7 docstring

        vm.def:
          builtinfn1:
            ## builtinfn1 docstring
          "builtinfn2":
            ## builtinfn2 docstring
          `builtinfn3`:
            ## builtinfn3 docstring
          builtinfn4 do ():
            ## builtinfn4 docstring
          "builtinfn5" do ():
            ## builtinfn5 docstring
          `builtinfn6` do ():
            ## builtinfn6 docstring
          builtinfn7
          builtinfn7 -> builtinfn8
          builtinfn7 -> "builtinfn9"
          builtinfn7 -> `builtinfn10`

        for i in 1..10:
          let fn = fmt"builtinfn{i}"
          check:
            vm{fn} of NpClosure

          if i <= 7:
            check:
              vm{fn}{"_docs"} == fmt"{fn} docstring"

        # vm.addModule()
        let
          Module3 = "Module3"
          Module6 = "Module6"

        vm.def:
          [Module1]
          ["Module2"]
          [`Module3`]
          [Module4]: PI = 3.14
          ["Module5"]: PI = 3.14
          [`Module6`]: PI = 3.14

        for i in 1..6:
          let module = fmt"Module{i}"
          check:
            vm[module] of NpModule

          if i in 4..6:
            check:
              vm[module]{"PI"} == 3.14

        # vm.import() or vm.addModule()
        var modules: seq[NpVar]
        for i in 1..6:
          let module = fmt"Module{i}"
          modules.add vm[module]

        vm.def:
          [+Module1]
          [+"Module2"]
          [+`Module3`]
          [+Module4]: discard
          [+"Module5"]: discard
          [+`Module6`]: discard

        for i in 1..6:
          let module = fmt"Module{i}"
          check:
            modules[i - 1] == vm[module]

        vm.def:
          [Module1]
          ["Module2"]
          [`Module3`]
          [Module4]: discard
          ["Module5"]: discard
          [`Module6`]: discard

        for i in 1..6:
          let module = fmt"Module{i}"
          check:
            modules[i - 1] != vm[module]

        let
          NewModule3 = "NewModule3"
          NewModule6 = "NewModule6"

        vm.def:
          [+NewModule1]
          [+"NewModule2"]
          [+`NewModule3`]
          [+NewModule4]: PI = 3.14
          [+"NewModule5"]: PI = 3.14
          [+`NewModule6`]: PI = 3.14

        for i in 1..6:
          let module = fmt"NewModule{i}"
          check:
            vm[module] of NpModule

          if i in 4..6:
            check:
              vm[module]{"PI"} == 3.14

        # module.addSource()
        vm.def:
          [Module1]:
            + "PI = 3.14"

          [Module2]:
            """PI = 3.14"""

        check:
          vm["Module1"]{"PI"} == 3.14
          vm["Module2"]{"PI"} == 3.14

        # module.`{}=`()
        let PI3 = "PI3"
        vm.def:
          [Module]:
            PI1 = 3.14
            "PI2" = 3.14
            `PI3` = 3.14

        check:
          vm["Module"]{"PI1"} == 3.14
          vm["Module"]{"PI2"} == 3.14
          vm["Module"]{"PI3"} == 3.14

        # module.addFn()
        let
          modulefn3 = "modulefn3"
          modulefn6 = "modulefn6"
          modulefn10 = "modulefn10"

        proc modulefn7() =
          ## modulefn7 docstring

        vm.def:
          [Module]:
            modulefn1:
              ## modulefn1 docstring
            "modulefn2":
              ## modulefn2 docstring
            `modulefn3`:
              ## modulefn3 docstring
            modulefn4 do ():
              ## modulefn4 docstring
            "modulefn5" do ():
              ## modulefn5 docstring
            `modulefn6` do ():
              ## modulefn6 docstring
            modulefn7
            modulefn7 -> modulefn8
            modulefn7 -> "modulefn9"
            modulefn7 -> `modulefn10`

        for i in 1..10:
          let fn = fmt"modulefn{i}"
          check:
            vm["Module"]{fn} of NpClosure

          if i <= 7:
            check:
              vm["Module"]{fn}{"_docs"} == fmt"{fn} docstring"

        # module.addClass()
        let
          Class3 = "Class3"
          Class6 = "Class6"

        vm.def:
          [Module]:
            [Class1]
            ["Class2"]
            [`Class3`]
            [Class4]:
              ## Class4 docstring
            ["Class5"]:
              ## Class5 docstring
            [`Class6`]:
              ## Class6 docstring

        for i in 1..6:
          let cls = fmt"Class{i}"
          check:
            vm["Module"]{cls} of NpClass

          if i in 4..6:
            check:
              vm["Module"]{cls}{"_docs"} == fmt"{cls} docstring"

        vm.def:
          [Module]:
            [Base]

        var
          base = vm["Module"]{"Base"}
          Base = "Base"

        vm.def:
          [+Module]:
            [Class1] is [Base]
            ["Class2"] is [Base]
            [`Class3`] is [Base]
            [Class4] is [Base]:
              ## Class4 docstring
            ["Class5"] is [Base]:
              ## Class5 docstring
            [`Class6`] is [Base]:
              ## Class6 docstring

        for i in 1..6:
          let cls = fmt"Class{i}"
          check:
            vm["Module"]{cls} of NpClass
            vm["Module"]{cls}{"parent"} == base

          if i in 4..6:
            check:
              vm["Module"]{cls}{"_docs"} == fmt"{cls} docstring"

        vm.def:
          [+Module]:
            [Class1] is ["Base"]
            ["Class2"] is ["Base"]
            [`Class3`] is ["Base"]
            [Class4] is ["Base"]:
              ## Class4 docstring
            ["Class5"] is ["Base"]:
              ## Class5 docstring
            [`Class6`] is ["Base"]:
              ## Class6 docstring

        for i in 1..6:
          let cls = fmt"Class{i}"
          check:
            vm["Module"]{cls} of NpClass
            vm["Module"]{cls}{"parent"} == base

          if i in 4..6:
            check:
              vm["Module"]{cls}{"_docs"} == fmt"{cls} docstring"

        vm.def:
          [+Module]:
            [Class1] is [`Base`]
            ["Class2"] is [`Base`]
            [`Class3`] is [`Base`]
            [Class4] is [`Base`]:
              ## Class4 docstring
            ["Class5"] is [`Base`]:
              ## Class5 docstring
            [`Class6`] is [`Base`]:
              ## Class6 docstring

        for i in 1..6:
          let cls = fmt"Class{i}"
          check:
            vm["Module"]{cls} of NpClass
            vm["Module"]{cls}{"parent"} == base

          if i in 4..6:
            check:
              vm["Module"]{cls}{"_docs"} == fmt"{cls} docstring"

        vm.def:
          [+Module]:
            [Class1] is base
            ["Class2"] is base
            [`Class3`] is base
            [Class4] is base:
              ## Class4 docstring
            ["Class5"] is base:
              ## Class5 docstring
            [`Class6`] is base:
              ## Class6 docstring

        for i in 1..6:
          let cls = fmt"Class{i}"
          check:
            vm["Module"]{cls} of NpClass
            vm["Module"]{cls}{"parent"} == base

          if i in 4..6:
            check:
              vm["Module"]{cls}{"_docs"} == fmt"{cls} docstring"

        # module{"name"} or module.addClass()
        var classes: seq[NpVar]
        for i in 1..6:
          let cls = fmt"Class{i}"
          classes.add vm["Module"]{cls}

        vm.def:
          [+Module]:
            [+Class1]
            [+"Class2"]
            [+`Class3`]
            [+Class4]: discard
            [+"Class5"]: discard
            [+`Class6`]: discard

        for i in 1..6:
          let cls = fmt"Class{i}"
          check:
            classes[i - 1] == vm["Module"]{cls}

        vm.def:
          [+Module]:
            [Class1]
            ["Class2"]
            [`Class3`]
            [Class4]: discard
            ["Class5"]: discard
            [`Class6`]: discard

        for i in 1..6:
          let cls = fmt"Class{i}"
          check:
            classes[i - 1] != vm["Module"]{cls}

        # module.addClass() if not exists
        vm.def:
          [NewModule]:
            [+Class1] is base
            [+"Class2"] is base
            [+`Class3`] is base
            [+Class4] is base: discard
            [+"Class5"] is base: discard
            [+`Class6`] is base: discard

        for i in 1..6:
          let cls = fmt"Class{i}"
          check:
            vm["NewModule"]{cls} of NpClass
            vm["NewModule"]{cls}{"parent"} == base

        # module.addClass() with ctor and dtor
        vm.def:
          [Module]:
            list = vm.list()
            [Class]:
              ctor: vm["Module"].list.add "real ctor"
              dtor: vm["Module"].list.add "real dtor"
              "ctor": vm["Module"].list.add "fake ctor"
              "dtor": vm["Module"].list.add "fake dtor"

        var obj = vm["Module"]{"Class"}()
        obj.ctor()
        obj.dtor()
        obj = vm.null
        vm["lang"].gc()
        check:
          vm["Module"].list == vm.eval("['real ctor', 'fake ctor', 'fake dtor', 'real dtor']")

        # module.addType()
        type
          Tuple[T, U] = tuple[a: T, b: U]

        vm.def:
          [Module]:
            [Class1] of Tuple[int, string]
            ["Class2"] of Tuple[int, string]
            [`Class3`] of Tuple[int, string]
            [Class4] of Tuple[int, string]:
              ## Class4 docstring
            ["Class5"] of Tuple[int, string]:
              ## Class5 docstring
            [`Class6`] of Tuple[int, string]:
              ## Class6 docstring

        for i in 1..6:
          let cls = fmt"Class{i}"
          check:
            to[Tuple[int, string]](vm["Module"]{cls}()).a == 0
            to[Tuple[int, string]](vm["Module"]{cls}()).b == ""

          expect NimPkError:
            discard to[Tuple[string, int]](vm["Module"]{cls}())

          if i in 4..6:
            check:
              vm["Module"]{cls}{"_docs"} == fmt"{cls} docstring"

        vm.def:
          [Module]:
            [Class1] of FileMode
            ["Class2"] of FileMode
            [`Class3`] of FileMode
            [Class4] of FileMode: discard
            ["Class5"] of FileMode: discard
            [`Class6`] of FileMode: discard

        for i in 1..6:
          let cls = fmt"Class{i}"
          check:
            vm["Module"]{cls}{"fmWrite"} == 1

        # module.addType() if not exists
        vm.def:
          [NewModule]:
            [+Class1] of FileSeekPos
            [+"Class2"] of FileSeekPos
            [+`Class3`] of FileSeekPos
            [+Class4] of FileSeekPos: discard
            [+"Class5"] of FileSeekPos: discard
            [+`Class6`] of FileSeekPos: discard

        for i in 1..6:
          let cls = fmt"Class{i}"
          check:
            vm["NewModule"]{cls}{"fspEnd"} == 2

        # class.addMethod()
        let
          method3 = "method3"
          method6 = "method6"
          method10 = "method10"

        proc method7(self: NpVar) =
          ## method7 docstring

        vm.def:
          [Module]:
            [Class]:
              method1:
                ## method1 docstring
              "method2":
                ## method2 docstring
              `method3`:
                ## method3 docstring
              method4 do (self: NpVar):
                ## method4 docstring
              "method5" do (self: NpVar):
                ## method5 docstring
              `method6` do (self: NpVar):
                ## method6 docstring
              method7
              method7 -> method8
              method7 -> "method9"
              method7 -> `method10`

        for i in 1..10:
          let mb = fmt"method{i}"
          check:
            vm["Module"]{"Class"}{mb} of NpMethodBind

          if i <= 7:
            check:
              vm["Module"]{"Class"}{mb}{"_docs"} == fmt"{mb} docstring"

        # class.`{}=`()
        vm.def:
          [Module]:
            [Class]:
              PI1 = 3.14
              "PI2" = 3.14
              `PI3` = 3.14

        check:
          vm["Module"]{"Class"}{"PI1"} == 3.14
          vm["Module"]{"Class"}{"PI2"} == 3.14
          vm["Module"]{"Class"}{"PI3"} == 3.14


  when declared(ErrorHandling):
    test "Error Handling":
      withNimPkVm:
        expect NimPkError: discard vm[65536]
        expect NimPkError: discard vm("hello").float
        expect NimPkError: discard vm("hello").int
        expect NimPkError: discard vm("hello").bool
        expect NimPkError: discard vm(123.456).string
        expect NimPkError: discard vm("hello") of vm.null
        expect NimPkError: discard vm("hello"){"key"}
        expect NimPkError: vm("hello"){"key"} = 1
        expect NimPkError: discard vm("hello")[10]
        expect NimPkError: discard vm(true)[0]
        expect NimPkError: discard vm.map()["key"]
        expect NimPkError: vm("hello")[10] = "a"
        expect NimPkError: vm(true)[0] = 0
        expect NimPkError: discard vm(10).len
        expect NimPkError: discard vm("hello")()
        expect NimPkError: discard vm.hex("abc")
        expect NimPkError: discard (vm "hello").startsWith(123)
        expect NimPkError: discard vm("hello").this
        expect NimPkError: vm("hello").insert(1)
        expect NimPkError: vm("hello").insert([1])
        expect NimPkError: vm.list().insert(1, 10)
        expect NimPkError: vm.list().insert([1], 10)
        expect NimPkError: discard vm["nonexist"]
        expect NimPkError: vm.run("assert false")
        expect NimPkError: discard vm.main
        expect NimPkError: discard vm.nonexist
        expect NimPkError: discard vm{"_nonexist"}
        expect NimPkError: vm["lang"].addSource("assert false")
        expect NimPkError: vm.run "assert false"
        expect NimPkError: vm.compile "a = '1 "

        vm.def:
          test:
            vm.error ["error", "in", "list"]

        vm.run """
          fb = Fiber fn
            test()
          end
          fb.try()
          assert fb.error == ["error", "in", "list"]
        """

        try:
          var fn = vm.compile """
            raise ["error", "in", "list"]
          """
          fn()
        except NimPkError:
          check:
            vm.lastError() == vm ["error", "in", "list"]

        try:
          vm.error ["error", "in", "list"]
          vm.reraise()
        except NimPkError:
          check:
            vm.lastError() == vm ["error", "in", "list"]
