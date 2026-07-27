// ohos-trivial-test.c — pure libc, no jemalloc.
//
// If this segfaults inside dockerharmony, the problem is environmental
// (qemu/binfmt/OHOS userland). If it succeeds, the problem is in jemalloc
// or its loader integration.

#include <stdio.h>
int main(void) {
    printf("OK trivial-test\n");
    return 0;
}
