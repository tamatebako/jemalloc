// ohos-smoke-test.c — minimal jemalloc round-trip for OHOS aarch64.
//
// Verifies that libjemalloc.so built with the OHOS NDK:
//   - can be dlopen'd by dockerharmony's musl dynamic linker
//   - actually allocates and frees memory
//   - exposes mallctl (the introspection namespace)
//
// Exits 0 on success, non-zero on any failure.

#include <jemalloc/jemalloc.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

int main(void) {
    // Unbuffer stdout so we see how far we get before any crash.
    setvbuf(stdout, NULL, _IONBF, 0);
    printf("smoke-test: starting\n");

    // Test 1: malloc + write + free
    void *p = je_malloc(1024);
    if (!p) {
        fprintf(stderr, "FAIL: je_malloc returned NULL\n");
        return 2;
    }
    memset(p, 0x42, 1024);
    je_free(p);
    printf("smoke-test: malloc/free OK\n");

    // Test 2: calloc zeroes memory
    void *c = je_calloc(64, 16);
    if (!c) {
        fprintf(stderr, "FAIL: je_calloc returned NULL\n");
        return 3;
    }
    for (int i = 0; i < 64 * 16; i++) {
        if (((unsigned char *)c)[i] != 0) {
            fprintf(stderr, "FAIL: je_calloc returned non-zeroed memory at offset %d\n", i);
            return 4;
        }
    }
    je_free(c);

    // Test 3: realloc grows
    void *r = je_malloc(8);
    if (!r) { fprintf(stderr, "FAIL: realloc initial\n"); return 5; }
    strcpy((char *)r, "abcd");
    r = je_realloc(r, 1024);
    if (!r) { fprintf(stderr, "FAIL: je_realloc returned NULL\n"); return 6; }
    if (strcmp((char *)r, "abcd") != 0) {
        fprintf(stderr, "FAIL: je_realloc did not preserve contents\n");
        return 7;
    }
    je_free(r);

    // Test 4: mallctl introspection (version string).
    char version[64] = {0};
    size_t sz = sizeof(version);
    int rc = je_mallctl("version", version, &sz, NULL, 0);
    if (rc != 0) {
        fprintf(stderr, "FAIL: je_mallctl(\"version\") returned %d\n", rc);
        return 8;
    }
    if (version[0] == 0) {
        fprintf(stderr, "FAIL: je_mallctl(\"version\") returned empty string\n");
        return 9;
    }

    // Test 5: malloc_usable_size reports a sane value.
    void *u = je_malloc(100);
    if (!u) { fprintf(stderr, "FAIL: malloc_usable_size initial\n"); return 10; }
    size_t usable = je_malloc_usable_size(u);
    if (usable < 100) {
        fprintf(stderr, "FAIL: malloc_usable_size returned %zu (< 100)\n", usable);
        return 11;
    }
    je_free(u);

    printf("OK jemalloc smoke-test passed; version=%s usable=%zu\n", version, usable);
    return 0;
}
