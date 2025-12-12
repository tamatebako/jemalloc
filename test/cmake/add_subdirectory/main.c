#include <jemalloc/jemalloc.h>
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    void* ptr = malloc(1024);
    if (!ptr) {
        fprintf(stderr, "malloc failed\n");
        return 1;
    }

    printf("jemalloc version: %s\n", JEMALLOC_VERSION);
    printf("Allocation successful: %p\n", ptr);

    free(ptr);

    printf("Test passed: add_subdirectory(jemalloc) integration works!\n");
    return 0;
}
