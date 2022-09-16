#====================================================================
#
#             NimPK - PocketLang Binding for Nim
#                  Copyright (c) 2022 Ward
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
