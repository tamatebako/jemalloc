# OHOS.cmake
# HarmonyOS PC (OpenHarmony) configuration.
# OHOS uses musl libc on a Linux-derived kernel, so the build behavior is
# identical to Linux. The OHOS NDK clang also defines __linux__, which means
# every source-level #ifdef __linux__ path applies unchanged.

# Include common Unix configuration first.
include(${CMAKE_CURRENT_LIST_DIR}/Unix.cmake)

# Linux-equivalent headers.
list(APPEND JEMALLOC_PLATFORM_HEADERS
    linux/unistd.h
    malloc.h
)

# Linux-equivalent memory features.
set(JEMALLOC_HAVE_THP TRUE)

include(CheckSymbolExists)
check_symbol_exists(MADV_DONTNEED "sys/mman.h" JEMALLOC_HAVE_MADV_DONTNEED)
check_symbol_exists(MADV_FREE "sys/mman.h" JEMALLOC_HAVE_MADV_FREE)

# ARM64 + musl: avoid outline-atomics so we don't pull in __getauxval from
# libc (musl doesn't provide it). Same fix as Linux.cmake for #2782.
if(JEMALLOC_IS_MUSL AND CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
    message(STATUS "OHOS ARM64 + musl detected: adding -mno-outline-atomics flag")
    include(CheckCCompilerFlag)
    check_c_compiler_flag("-mno-outline-atomics" COMPILER_SUPPORTS_NO_OUTLINE_ATOMICS)
    if(COMPILER_SUPPORTS_NO_OUTLINE_ATOMICS)
        list(APPEND JEMALLOC_PLATFORM_COMPILE_OPTIONS -mno-outline-atomics)
    else()
        message(WARNING "Compiler does not support -mno-outline-atomics flag")
    endif()
endif()

# Export to parent scope.
set(JEMALLOC_PLATFORM_HEADERS "${JEMALLOC_PLATFORM_HEADERS}")
set(JEMALLOC_PLATFORM_DEFINITIONS "${JEMALLOC_PLATFORM_DEFINITIONS}")
set(JEMALLOC_PLATFORM_COMPILE_OPTIONS "${JEMALLOC_PLATFORM_COMPILE_OPTIONS}" PARENT_SCOPE)
set(JEMALLOC_PLATFORM_LIBS "${JEMALLOC_PLATFORM_LIBS}")
