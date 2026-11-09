type
  A = ref object of RootObj
  B = ref object of A
method m(x: A): int {.base.} = 1
method m(x: B): int = 2
proc libB(): cint {.exportc, cdecl.} = cint(m(B()) + m(A()))
