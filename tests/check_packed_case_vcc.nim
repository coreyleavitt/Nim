# Checks the C that the compiler emits for packed_case_vcc.nim under
# `--compileOnly --cc:vcc`, where packing is expressed with `#pragma pack`
# instead of `__attribute__((__packed__))`. No MSVC is needed: codegen keys
# off the CC's property set and --compileOnly never runs the C compiler, so
# this runs on every platform the toolchain is built for.
#
#   nim r tests/check_packed_case_vcc.nim [nim-binary] [repro.nim]
#
# `nim-binary` defaults to the `nim` on PATH, `repro.nim` to the sibling
# packed_case_vcc.nim. Exit code 0 when every check passes.
#
# The checks walk the module's C with MSVC's pack-stack semantics (a pop on
# an empty stack is a no-op warning, not a negative depth):
#   (a) `#pragma pack(push` and `#pragma pack(pop` occur equally often;
#   (b) the ordinary struct (tyObject_Plain) is emitted at pack depth 0, and
#       the depth is 0 again at the end of the file;
#   (c) every line of the packed case object's own definition, union and
#       branch structs included, sits at pack depth >= 1.
# The defect (nim-lang/Nim#24461) passes (a) and fails (b) and (c): the branch
# pops are emitted before the union, so the sequence is push, pop, pop, push,
# push, pop.

import std/[os, osproc, strutils]

proc fail(msg: string) =
  stderr.writeLine "FAIL: " & msg
  quit 1

let nimExe = if paramCount() >= 1: paramStr(1) else: findExe("nim")
if nimExe.len == 0: fail "no nim binary on PATH"
let repro = if paramCount() >= 2: paramStr(2)
            else: currentSourcePath().parentDir / "packed_case_vcc.nim"
let cache = getTempDir() / "nimcache_packed_case_vcc"
removeDir(cache)

let cmd = quoteShellCommand([nimExe, "c", "--compileOnly", "--cc:vcc", "--hints:off",
                             "--nimcache:" & cache, repro])
let (compOut, rc) = execCmdEx(cmd)
if rc != 0: fail "compile failed (rc=" & $rc & "):\n" & cmd & "\n" & compOut

let cfile = cache / ("@m" & repro.extractFilename & ".c")
if not fileExists(cfile): fail "emitted C not found at " & cfile
let lines = readFile(cfile).splitLines

var pushes, pops, depth, plainDepth, packedMinDepth = 0
var plainLine, packedStart, packedEnd = -1
var braces = 0
packedMinDepth = high(int)
for i, raw in lines:
  let line = raw.strip
  if line.startsWith("#pragma pack(push"):
    inc pushes; inc depth
  elif line.startsWith("#pragma pack(pop"):
    inc pops
    if depth > 0: dec depth
  # pack depth in effect for a declaration on this line
  if line.startsWith("struct tyObject_Plain__") and line.endsWith("{"):
    plainLine = i; plainDepth = depth
  if line.startsWith("struct tyObject_PackedCase__") and line.endsWith("{"):
    packedStart = i; braces = 0
  if packedStart >= 0 and packedEnd < 0:
    packedMinDepth = min(packedMinDepth, depth)
    braces += line.count('{') - line.count('}')
    if braces == 0 and line.endsWith("};"): packedEnd = i

var ok = true
proc check(cond: bool; what: string) =
  echo (if cond: "PASS: " else: "FAIL: "), what
  if not cond: ok = false

if plainLine < 0: fail "struct tyObject_Plain definition not found in " & cfile
if packedStart < 0 or packedEnd < 0: fail "struct tyObject_PackedCase definition not found in " & cfile

check pushes == pops, "(a) pack(push) count " & $pushes & " == pack(pop) count " & $pops
check plainDepth == 0, "(b) tyObject_Plain (line " & $(plainLine + 1) & ") emitted at pack depth " & $plainDepth
check depth == 0, "(b) pack depth at end of module is " & $depth
check packedMinDepth >= 1, "(c) tyObject_PackedCase (lines " & $(packedStart + 1) & "-" & $(packedEnd + 1) &
                            ") never leaves the pack region, min depth " & $packedMinDepth

if not ok:
  echo "--- " & cfile & " lines " & $(packedStart + 1) & "-" & $(plainLine + 1)
  for i in packedStart .. plainLine: echo lines[i]
  quit 1
echo "ok"
