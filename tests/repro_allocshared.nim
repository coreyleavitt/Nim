# Cross-thread deallocShared after the allocating thread exited (ARC/ORC).
# Each producer thread allocates one block from its thread-local region and
# exits; the main thread then frees every block, writing through each dead
# thread's TLS-resident MemRegion via addToSharedFreeList.
const N = 64

var blocks: array[N, pointer]

proc producer(i: int) {.thread.} =
  blocks[i] = allocShared(64)

var threads: array[N, Thread[int]]
for i in 0 ..< N:
  createThread(threads[i], producer, i)
joinThreads(threads)

for i in 0 ..< N:
  deallocShared(blocks[i])

echo "survived"
