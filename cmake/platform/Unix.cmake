# Unix.cmake
# Common Unix-specific configuration (Linux, macOS, FreeBSD)

# Unix common headers
set(JEMALLOC_PLATFORM_HEADERS
    pthread.h
    sys/mman.h
    unistd.h
    sys/param.h
    sys/time.h
)

# Unix-specific compile definitions
list(APPEND JEMALLOC_PLATFORM_DEFINITIONS
    _GNU_SOURCE
    _REENTRANT
)

# Unix has mmap support
set(JEMALLOC_HAVE_MMAP TRUE)

# Thread support via pthread
set(JEMALLOC_HAVE_PTHREAD TRUE)
find_package(Threads REQUIRED)
list(APPEND JEMALLOC_PLATFORM_LIBS Threads::Threads)

# Check for sbrk support (may not be available on all platforms)
include(CheckSymbolExists)
check_symbol_exists(sbrk "unistd.h" JEMALLOC_HAVE_SBRK)

# Detect C library type (glibc vs musl)
if(CMAKE_SYSTEM_NAME MATCHES "Linux")
    execute_process(
        COMMAND ${CMAKE_C_COMPILER} -dumpmachine
        OUTPUT_VARIABLE COMPILER_TUPLE
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    if(COMPILER_TUPLE MATCHES "musl")
        message(STATUS "Detected musl libc")
        set(JEMALLOC_IS_MUSL TRUE)
    else()
        message(STATUS "Detected glibc")
        set(JEMALLOC_IS_GLIBC TRUE)
    endif()
endif()

# Export to parent scope
set(JEMALLOC_PLATFORM_HEADERS "${JEMALLOC_PLATFORM_HEADERS}")
set(JEMALLOC_PLATFORM_DEFINITIONS "${JEMALLOC_PLATFORM_DEFINITIONS}")
set(JEMALLOC_PLATFORM_LIBS "${JEMALLOC_PLATFORM_LIBS}")
set(JEMALLOC_IS_MUSL "${JEMALLOC_IS_MUSL}" PARENT_SCOPE)
set(JEMALLOC_IS_GLIBC "${JEMALLOC_IS_GLIBC}" PARENT_SCOPE)