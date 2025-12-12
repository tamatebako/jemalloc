# Linux.cmake
# Linux-specific configuration

# Include common Unix configuration first
include(${CMAKE_CURRENT_LIST_DIR}/Unix.cmake)

# Linux-specific headers
list(APPEND JEMALLOC_PLATFORM_HEADERS
    linux/unistd.h
    malloc.h
)

# Linux supports transparent huge pages (THP)
set(JEMALLOC_HAVE_THP TRUE)

# Check for Linux-specific memory features
include(CheckSymbolExists)
check_symbol_exists(MADV_DONTNEED "sys/mman.h" JEMALLOC_HAVE_MADV_DONTNEED)
check_symbol_exists(MADV_FREE "sys/mman.h" JEMALLOC_HAVE_MADV_FREE)

# ARM64 musl fix (GH issue #2782)
if(JEMALLOC_IS_MUSL AND CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
    message(STATUS "ARM64 + musl detected: Adding -mno-outline-atomics flag")
    message(STATUS "  (Resolves GH issue #2782: avoids __getauxval dependency)")

    # Test if compiler supports the flag
    include(CheckCCompilerFlag)
    check_c_compiler_flag("-mno-outline-atomics" COMPILER_SUPPORTS_NO_OUTLINE_ATOMICS)

    if(COMPILER_SUPPORTS_NO_OUTLINE_ATOMICS)
        list(APPEND JEMALLOC_PLATFORM_COMPILE_OPTIONS -mno-outline-atomics)
    else()
        message(WARNING "Compiler does not support -mno-outline-atomics flag")
    endif()
endif()

# Export to parent scope
set(JEMALLOC_PLATFORM_HEADERS "${JEMALLOC_PLATFORM_HEADERS}")
set(JEMALLOC_PLATFORM_DEFINITIONS "${JEMALLOC_PLATFORM_DEFINITIONS}")
set(JEMALLOC_PLATFORM_COMPILE_OPTIONS "${JEMALLOC_PLATFORM_COMPILE_OPTIONS}" PARENT_SCOPE)
set(JEMALLOC_PLATFORM_LIBS "${JEMALLOC_PLATFORM_LIBS}")
