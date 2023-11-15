#====================================================================
#
#          NimPK - Pocketlang Binding for Nim Language
#               Copyright (c) Chen Kai-Hung, Ward
#
#====================================================================

import nimpk

exportNimPk("mylib"):
  self.def:
    """
      data = "mylib"
    """

    hello:
      return "hello from dynamic lib."
