# Repro for patches/2.2.10/0007-backport-24461-packed-case-pragma-pack-leak.patch
#
# A {.packed.} case object makes the C backend emit, for compilers without
# __attribute__ (vcc), a `#pragma pack(push, 1)` around the outer struct and
# one around every branch struct. The branch pops were appended to the
# enclosing record's builder instead of the union body, so they came out
# before the union they were meant to close: push, pop, pop, union { push,
# push }, pop. The pack stack is left one level deep and every struct emitted
# afterwards in the module is laid out with pack(1), while other modules (and
# the compiler's own sizeof/offset tables) use the natural layout. Found as
# `sizeof(VariantArm)` disagreeing between two translation units in nelli's
# MSVC CI (65 vs 72 bytes).
#
# Two uses:
#   * check_packed_case_vcc.nim compiles this with `--compileOnly --cc:vcc`
#     and inspects the emitted C (no MSVC required).
#   * compiled and run normally it prints the C compiler's sizeof next to the
#     compiler's own, and fails if they disagree; the two must agree on every
#     backend, so this also pins the gcc/clang path.

type
  Kind = enum kA, kB
  PackedCase {.packed.} = object
    tag: uint8
    case k: Kind
    of kA:
      a1: uint8
      a2: int64
    of kB:
      b1: int32
      b2: int64
  Plain = object
    x: uint8
    y: int64      # natural layout puts this at offset 8; a leaked pack(1) puts it at 1

# sizeof/offsetof as the C compiler sees the emitted structs, not as Nim
# computed them (Nim's own sizeof is a compile-time constant).
proc cSizeofPackedCase(): int =
  {.emit: [result, " = (NI)sizeof(", PackedCase, ");"].}

proc cSizeofPlain(): int =
  {.emit: [result, " = (NI)sizeof(", Plain, ");"].}

proc cOffsetY(): int =
  {.emit: [result, " = (NI)offsetof(", Plain, ", y);"].}

var pc = PackedCase(tag: 1, k: kB, b1: 2, b2: 3)
var pl = Plain(x: 4, y: 5)

echo "PackedCase: nim=", sizeof(PackedCase), " c=", cSizeofPackedCase()
echo "Plain: nim=", sizeof(Plain), " c=", cSizeofPlain(), " offsetof(y)=", cOffsetY()
doAssert cSizeofPackedCase() == sizeof(PackedCase)
doAssert cSizeofPlain() == sizeof(Plain)
doAssert cOffsetY() == offsetOf(Plain, y)
doAssert pc.b2 == 3 and pl.y == 5
echo "ok"
