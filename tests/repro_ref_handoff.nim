# Same lifetime hole, no allocShared involved: a plain ref allocated on a
# producer thread and destroyed on the main thread after the producer exited.
# This is the shape of every Isolated[T]/channel handoff under ORC.
const N = 64

type Node = ref object
  data: array[64, byte]

var blocks: array[N, Node]

proc producer(i: int) {.thread.} =
  {.cast(gcsafe).}:
    blocks[i] = Node()

var threads: array[N, Thread[int]]
for i in 0 ..< N:
  createThread(threads[i], producer, i)
joinThreads(threads)

for i in 0 ..< N:
  blocks[i] = nil   # destroy on main thread -> rawDealloc on foreign chunk

echo "survived"
