# Checks the per-binary method dispatch table (patch 0008): the accessor
# `nimMethodDispatchTable` returns one row per branch of every method
# dispatcher, in the dispatcher's if-chain order, and `defined(
# nimHasMethodDispatchTable)` announces it.
#
#   nim c -r tests/method_dispatch_table.nim | grep -q ok
#   nim cpp -r tests/method_dispatch_table.nim | grep -q ok
#   nim c -r --mm:orc tests/method_dispatch_table.nim | grep -q ok

when not defined(nimHasMethodDispatchTable):
  {.error: "nimHasMethodDispatchTable is not defined".}

import std/strutils

type
  A = ref object of RootObj
  B = ref object of A
  C = ref object of RootObj      # a second bucket

method m(x: A): int {.base.} = 1
method m(x: B): int = 2
method n(x: C): int {.base.} = 3

type Row = object
  bucket, fn: pointer
  recv: cstring

proc nimMethodDispatchTable(count: ptr int): pointer
  {.importc: "nimMethodDispatchTable", cdecl.}

proc fail(msg: string) =
  echo "FAIL: " & msg
  quit 1

# Reached through the dispatchers, so the program really uses them.
let a: A = B()
if m(a) != 2: fail "dispatch"
if n(C()) != 3: fail "dispatch n"

var count = 0
let rows = cast[ptr UncheckedArray[Row]](nimMethodDispatchTable(addr count))
if count != 3: fail "expected 3 rows, got " & $count
for i in 0 ..< count:
  if rows[i].bucket == nil or rows[i].fn == nil: fail "nil address"
  if rows[i].fn == rows[i].bucket: fail "fn is the dispatcher"
# `m`'s bucket: the more specific override is tried first.
var mRows: seq[string]
var nBuckets: seq[pointer]
for i in 0 ..< count:
  if rows[i].bucket notin nBuckets: nBuckets.add rows[i].bucket
  if $rows[i].recv notin ["C:ObjectType"]: mRows.add $rows[i].recv
if nBuckets.len != 2: fail "expected 2 buckets"
if mRows.len != 2: fail "expected 2 rows for m, got " & $mRows
if not mRows[0].startsWith("B") or not mRows[1].startsWith("A"):
  fail "if-chain order: " & $mRows
if rows[0].fn == rows[1].fn: fail "rows share a body"
echo "ok"
