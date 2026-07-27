// ohos-smoke-test.c — diagnostic jemalloc round-trip for OHOS aarch64.
//
// Uses dlopen() rather than direct linking so we can see exactly which
// step fails inside dockerharmony (load, symbol resolution, or first call).
//
// Exits 0 on success, non-zero on any failure.

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>

typedef void *(*malloc_t)(size_t);
typedef void  (*free_t)(void *);
typedef void *(*calloc_t)(size_t, size_t);
typedef void *(*realloc_t)(void *, size_t);
typedef size_t (*malloc_usable_size_t)(void *);
typedef int   (*mallctl_t)(const char *, void *, size_t *, void *, size_t);

int main(void) {
    setvbuf(stdout, NULL, _IONBF, 0);
    printf("step 1: before dlopen(libjemalloc.so.5)\n");

    void *h = dlopen("./libjemalloc.so.5", RTLD_NOW);
    if (!h) {
        fprintf(stderr, "FAIL step 1: dlopen: %s\n", dlerror());
        return 1;
    }
    printf("step 2: dlopen succeeded\n");

    malloc_t  je_malloc  = (malloc_t)  dlsym(h, "je_malloc");
    free_t    je_free    = (free_t)    dlsym(h, "je_free");
    calloc_t  je_calloc  = (calloc_t)  dlsym(h, "je_calloc");
    realloc_t je_realloc = (realloc_t) dlsym(h, "je_realloc");
    malloc_usable_size_t je_malloc_usable_size =
        (malloc_usable_size_t) dlsym(h, "je_malloc_usable_size");
    mallctl_t je_mallctl = (mallctl_t) dlsym(h, "je_mallctl");

    if (!je_malloc || !je_free || !je_calloc || !je_realloc
        || !je_malloc_usable_size || !je_mallctl) {
        fprintf(stderr, "FAIL step 2: dlsym: %s\n", dlerror());
        return 2;
    }
    printf("step 3: dlsym resolved all symbols\n");

    // malloc + write + free
    void *p = je_malloc(1024);
    if (!p) { fprintf(stderr, "FAIL: je_malloc returned NULL\n"); return 3; }
    memset(p, 0x42, 1024);
    je_free(p);
    printf("step 4: malloc/free OK\n");

    // calloc zeroes
    void *c = je_calloc(64, 16);
    if (!c) { fprintf(stderr, "FAIL: je_calloc returned NULL\n"); return 4; }
    for (int i = 0; i < 64 * 16; i++) {
        if (((unsigned char *)c)[i] != 0) {
            fprintf(stderr, "FAIL: calloc not zeroed at %d\n", i);
            return 5;
        }
    }
    je_free(c);
    printf("step 5: calloc OK\n");

    // realloc preserves
    void *r = je_malloc(8);
    if (!r) { fprintf(stderr, "FAIL: realloc initial\n"); return 6; }
    strcpy((char *)r, "abcd");
    r = je_realloc(r, 1024);
    if (!r) { fprintf(stderr, "FAIL: realloc returned NULL\n"); return 7; }
    if (strcmp((char *)r, "abcd") != 0) {
        fprintf(stderr, "FAIL: realloc lost contents\n");
        return 8;
    }
    je_free(r);
    printf("step 6: realloc OK\n");

    // mallctl version
    char version[64] = {0};
    size_t sz = sizeof(version);
    int rc = je_mallctl("version", version, &sz, NULL, 0);
    if (rc != 0) {
        fprintf(stderr, "FAIL: mallctl(\"version\") rc=%d\n", rc);
        return 9;
    }
    printf("step 7: mallctl OK, version=%s\n", version);

    // malloc_usable_size
    void *u = je_malloc(100);
    size_t usable = je_malloc_usable_size(u);
    if (usable < 100) {
        fprintf(stderr, "FAIL: malloc_usable_size=%zu (<100)\n", usable);
        return 10;
    }
    je_free(u);
    printf("step 8: malloc_usable_size=%zu OK\n", usable);

    printf("OK jemalloc smoke-test passed\n");
    return 0;
}
