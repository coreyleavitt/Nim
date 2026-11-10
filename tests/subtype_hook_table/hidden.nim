# A subtype of `Base` with a hook, in a module the main file never imports.
import base

type
  HiddenObj* = object of BaseObj
  Hidden* = ref HiddenObj

var destroyed* = 0
proc `=destroy`(x: HiddenObj) = inc destroyed

proc makeHidden*(): Base = Hidden(k: 3)
