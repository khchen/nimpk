#====================================================================
#
#             NimPK - PocketLang Binding for Nim
#                  Copyright (c) 2022 Ward
#
#====================================================================

# A PocketLang native module is a .dll or .so file that can be import
# as a module in the script.

# Always import the main module of NimPK
import nimpk

when appType == "lib":
  # This part should be compiled by following command on Windows:
  #   nim c --app:lib -o:mylib.dll tutorial07_native_module

  # or on Linux:
  #   nim c --app:lib -o:mylib.so tutorial07_native_module

  # `exportNimPk`: a tempalte to create the native module.
  #  - Inject `self` as the module object to export.
  #  - Inject `vm` of NpVm.
  exportNimPk("mylib"):

    # `self.def` here just like the module part in `vm.def`.
    self.def:
      # A moudle can be composed of both script code and native code.
      """
        message1 = "Hello, world! (1)"

        def hello1(n)
          return "Hello, world! (${n})"
        end
      """

      message2 = "Hello, world! (4)"

      hello2:
        return "Hello, world! (" & $args[0] & ")"

else:
  # This part can be run by:
  #   nim r tutorial07_native_module

  # The PocketLang VM source code is only required here.
  import nimpk/src

  withNimPkVm:
    # Test the module in nim.
    var mylib = vm.import("mylib")
    echo mylib.message1
    echo mylib.hello1(2)
    echo mylib.hello2(3)

    # Test the module in script.
    vm.run """
      import mylib
      print mylib.message2
      print mylib.hello1(5)
      print mylib.hello2(6)
    """
