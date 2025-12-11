# CompilerFeatures.cmake
# Detect compiler capabilities and features

include(CheckIncludeFiles)
include(CheckCSourceCompiles)
include(CheckCCompilerFlag)

# C11 atomics
check_include_files("stdatomic.h" JEMALLOC_HAVE_STDATOMIC_H)

if(JEMALLOC_HAVE_STDATOMIC_H)
    check_c_source_compiles("
        #include <stdatomic.h>
        int main() {
            atomic_int x = ATOMIC_VAR_INIT(0);
            atomic_fetch_add(&x, 1);
            return 0;
        }
    " JEMALLOC_C11_ATOMICS)
endif()

# GCC/Clang __atomic builtins
check_c_source_compiles("
    int main() {
        int x = 0;
        __atomic_add_fetch(&x, 1, __ATOMIC_RELAXED);
        __atomic_load_n(&x, __ATOMIC_ACQUIRE);
        __atomic_store_n(&x, 1, __ATOMIC_RELEASE);
        return 0;
    }
" JEMALLOC_GCC_ATOMIC_ATOMICS)

# GCC/Clang __sync builtins (older fallback)
check_c_source_compiles("
    int main() {
        int x = 0;
        __sync_add_and_fetch(&x, 1);
        __sync_sub_and_fetch(&x, 1);
        return 0;
    }
" JEMALLOC_GCC_SYNC_ATOMICS)

# 8-bit atomics support for GCC __atomic
if(JEMALLOC_GCC_ATOMIC_ATOMICS)
    check_c_source_compiles("
        int main() {
            unsigned char x = 0;
            __atomic_load_n(&x, __ATOMIC_RELAXED);
            __atomic_store_n(&x, 1, __ATOMIC_RELEASE);
            return 0;
        }
    " JEMALLOC_GCC_U8_ATOMIC_ATOMICS)
endif()

# 8-bit atomics support for GCC __sync
if(JEMALLOC_GCC_SYNC_ATOMICS)
    check_c_source_compiles("
        int main() {
            unsigned char x = 0;
            __sync_add_and_fetch(&x, 1);
            __sync_sub_and_fetch(&x, 1);
            return 0;
        }
    " JEMALLOC_GCC_U8_SYNC_ATOMICS)
endif()

# __attribute__ support
check_c_source_compiles("
    void __attribute__((noinline)) test(void) {}
    int main() { return 0; }
" JEMALLOC_HAVE_ATTR_NOINLINE)

check_c_source_compiles("
    void __attribute__((always_inline)) test(void) {}
    int main() { return 0; }
" JEMALLOC_HAVE_ATTR_ALWAYS_INLINE)

check_c_source_compiles("
    void __attribute__((format(printf, 1, 2))) test(const char* fmt, ...) {}
    int main() { return 0; }
" JEMALLOC_HAVE_ATTR_FORMAT_PRINTF)

check_c_source_compiles("
    int __attribute__((unused)) x;
    int main() { return 0; }
" JEMALLOC_HAVE_ATTR_UNUSED)

check_c_source_compiles(`
    int __attribute__((used)) x;
    int main() { return 0; }
" JEMALLOC_HAVE_ATTR_USED)

check_c_source_compiles(`
    void __attribute__((constructor)) test(void) {}
    int main() { return 0; }
" JEMALLOC_HAVE_ATTR_CONSTRUCTOR)

check_c_source_compiles(`
    void __attribute__((destructor)) test(void) {}
    int main() { return 0; }
" JEMALLOC_HAVE_ATTR_DESTRUCTOR)

# Thread-local storage
check_c_source_compiles(`
    __thread int x;
    int main() { return x; }
" JEMALLOC_TLS)

# C11 _Static_assert
check_c_source_compiles(`
    _Static_assert(1, \"test\");
    int main() { return 0; }
" JEMALLOC_STATIC_ASSERT)

# typeof support (GNU extension)
check_c_source_compiles(`
    int main() {
        int x = 5;
        typeof(x) y = x;
        return 0;
    }
" JEMALLOC_HAVE_TYPEOF)

# __builtin_expect (branch prediction)
check_c_source_compiles(`
    int main() {
        int x = 0;
        if (__builtin_expect(x == 0, 1)) {
            return 1;
        }
        return 0;
    }
" JEMALLOC_HAVE_BUILTIN_EXPECT)

# __builtin_unreachable (unreachable code marking)
check_c_source_compiles(`
    int main() {
        __builtin_unreachable();
        return 0;
    }
" JEMALLOC_HAVE_BUILTIN_UNREACHABLE)

# __builtin_clz and __builtin_clzl (count leading zeros)
check_c_source_compiles(`
    int main() {
        unsigned int x = 1;
        unsigned long y = 1;
        __builtin_clz(x);
        __builtin_clzl(y);
        return 0;
    }
" JEMALLOC_HAVE_BUILTIN_CLZ)

# ffs/ffsl/ffsll (find first set bit) - check for builtin versions first
check_c_source_compiles(`
    int main() {
        int x = __builtin_ffs(1);
        long y = __builtin_ffsl(1L);
        long long z = __builtin_ffsll(1LL);
        return 0;
    }
" JEMALLOC_HAVE_BUILTIN_FFS)

# If builtin versions don't exist, check for standard library versions
if(NOT JEMALLOC_HAVE_BUILTIN_FFS)
    check_c_source_compiles(`
        #include <strings.h>
        int main() {
            int x = ffs(1);
            long y = ffsl(1L);
            long long z = ffsll(1LL);
            return 0;
        }
    " JEMALLOC_HAVE_FFS)
endif()

# Check for TLS (Thread-Local Storage) support
# Note: On Windows, we use native TSD implementation (tsd_win.h) instead of TLS,
# so we explicitly disable JEMALLOC_TLS on Windows to avoid pthread dependency
if(NOT WIN32)
    check_c_source_compiles(`
        __thread int x;
        int main() { return x; }
    " JEMALLOC_HAVE_TLS_THREAD)

    check_c_source_compiles(`
        __declspec(thread) int x;
        int main() { return x; }
    " JEMALLOC_HAVE_TLS_DECLSPEC)

    if(JEMALLOC_HAVE_TLS_THREAD OR JEMALLOC_HAVE_TLS_DECLSPEC)
        set(JEMALLOC_TLS 1)
    else()
        set(JEMALLOC_TLS 0)
    endif()
else()
    # Windows uses native TSD (tsd_win.h), not TLS (tsd_tls.h)
    # Setting JEMALLOC_TLS to 0 ensures tsd.h selects tsd_win.h
    set(JEMALLOC_TLS 0)
endif()

# Export all results to parent scope
set(JEMALLOC_C11_ATOMICS "${JEMALLOC_C11_ATOMICS}")
set(JEMALLOC_GCC_ATOMIC_ATOMICS "${JEMALLOC_GCC_ATOMIC_ATOMICS}")
set(JEMALLOC_GCC_U8_ATOMIC_ATOMICS "${JEMALLOC_GCC_U8_ATOMIC_ATOMICS}")
set(JEMALLOC_GCC_SYNC_ATOMICS "${JEMALLOC_GCC_SYNC_ATOMICS}")
set(JEMALLOC_GCC_U8_SYNC_ATOMICS "${JEMALLOC_GCC_U8_SYNC_ATOMICS}")
set(JEMALLOC_TLS "${JEMALLOC_TLS}")
set(JEMALLOC_HAVE_BUILTIN_FFS "${JEMALLOC_HAVE_BUILTIN_FFS}")
set(JEMALLOC_HAVE_FFS "${JEMALLOC_HAVE_FFS}")
set(JEMALLOC_HAVE_MSVC_INTRINSICS "${JEMALLOC_HAVE_MSVC_INTRINSICS}")
set(JEMALLOC_HAVE_BUILTIN_CLZ "${JEMALLOC_HAVE_BUILTIN_CLZ}")