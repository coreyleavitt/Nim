# Checks the per-binary subtype-hook table (patch 0009): the accessor
# `nimSubtypeHookTable` returns, per proper ancestor of every inheriting object
# type the binary writes a header for, each user lifetime hook a value of the
# subtype may run, and `defined(nimHasSubtypeHookTable)` announces it. `Hidden`
# (with a `=destroy`) is declared in a module this file never imports.
#
#   nim c -r tests/subtype_hook_table/main.nim | grep -q ok
#   nim cpp -r tests/subtype_hook_table/main.nim | grep -q ok

when not defined(nimHasSubtypeHookTable):
  {.error: "nimHasSubtypeHookTable is not defined".}

import base, maker

type
  Plain = ref object of BaseObj       # no hook
  HeldObj = object of RootObj
  Held = ref HeldObj
  Holder = ref object of BaseObj      # no hook of its own; holds a `ref Held`
    h: Held
  HeldSubObj = object of HeldObj
  HeldSub = ref HeldSubObj
  Closed = ref object of BaseObj      # holds a closure
    f: proc (): int

proc `=destroy`(x: HeldObj) = discard
proc `=destroy`(x: HeldSubObj) = discard

type Row = object
  base, sub: cstring
  hook: pointer
  open: int

proc nimSubtypeHookTable(count: ptr int): pointer
  {.importc: "nimSubtypeHookTable", cdecl.}

proc fail(msg: string) =
  echo "FAIL: " & msg
  quit 1

var n0 = 7
let xs: seq[Base] = @[make(), Plain(), Holder(h: HeldSub()),
                      Closed(f: proc (): int = n0)]
if xs.len != 4: fail "build"

var count = 0
let rows = cast[ptr UncheckedArray[Row]](nimSubtypeHookTable(addr count))
if count <= 0: fail "expected rows, got " & $count
proc rowsOf(base, sub: string): seq[Row] =
  for i in 0 ..< count:
    if $rows[i].base == base and $rows[i].sub == sub: result.add rows[i]

let hid = rowsOf("base.BaseObj", "hidden.HiddenObj")
if hid.len != 1 or hid[0].hook == nil or hid[0].open != 0:
  fail "hidden subtype: " & $hid.len
if rowsOf("system.RootObj", "hidden.HiddenObj").len != 1:
  fail "every proper ancestor names the subtype"
let pl = rowsOf("base.BaseObj", "main.Plain:ObjectType")
if pl.len != 1 or pl[0].hook != nil or pl[0].open != 0: fail "plain subtype"
let hd = rowsOf("base.BaseObj", "main.Holder:ObjectType")
if hd.len != 2: fail "holder reaches the held hierarchy's two hooks: " & $hd.len
var hooks: seq[pointer]
for r in hd:
  if r.hook == nil or r.open != 0: fail "holder row"
  hooks.add r.hook
# The address a consumer takes of the user hook is the table's.
let d: proc (x: HeldObj) {.nimcall.} = `=destroy`
if cast[pointer](d) notin hooks: fail "the hook's address is not the table's"
let cl = rowsOf("base.BaseObj", "main.Closed:ObjectType")
if cl.len != 1 or cl[0].open != 1: fail "closure subtype is open"
if rowsOf("hidden.HiddenObj", "base.BaseObj").len != 0: fail "no row upward"
echo "ok"
