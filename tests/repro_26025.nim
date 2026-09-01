from std/typetraits import distinctBase
type
  M[B] = distinct seq[B]
  W = object
    g: U
  U = M[uint64]
var h: M[W]
seq[W](h).add W(g: U(@[1'u64]))
for _ in items(distinctBase(h)):
  discard
echo "ok"
