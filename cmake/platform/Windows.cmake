# Windows.cmake
# Windows-specific configuration

# Detect if using MinGW/MSYS (which provides POSIX compatibility layer)
if(MINGW OR MSYS OR CMAKE_SYSTEM_NAME MATCHES "MSYS|MINGW")
    set(JEMALLOC_IS_MINGW TRUE)
    message(STATUS "MinGW/MSYS detected on Windows")
endif()

# Windows requires specific headers
set(JEMALLOC_PLATFORM_HEADERS
    windows.h
    psapi.h
)

# Windows-specific compile definitions
list(APPEND JEMALLOC_PLATFORM_DEFINITIONS
    _CRT_SECURE_NO_WARNINGS
    _CRT_NONSTDC_NO_WARNINGS
    WIN32_LEAN_AND_MEAN
    NOMINMAX
)

# MinGW specific configuration
if(JEMALLOC_IS_MINGW)
    # MinGW provides pthread and mmap compatibility
    set(JEMALLOC_HAVE_PTHREAD TRUE)
    find_package(Threads REQUIRED)
    list(APPEND JEMALLOC_PLATFORM_LIBS Threads::Threads)

    # MinGW uses mmap emulation
    set(JEMALLOC_HAVE_MMAP TRUE)
    set(JEMALLOC_HAVE_SBRK FALSE)

    # Add GNU source for MinGW
    list(APPEND JEMALLOC_PLATFORM_DEFINITIONS _GNU_SOURCE)
else()
    # Native Windows (MSVC)
    # Windows doesn't have sbrk, uses VirtualAlloc/VirtualFree
    set(JEMALLOC_HAVE_SBRK FALSE)
    set(JEMALLOC_HAVE_MMAP FALSE)

    # Windows uses VirtualAlloc for memory management
    set(JEMALLOC_HAVE_VIRTUALALLOC TRUE)

    # No pthread on Windows (uses native threads)
    set(JEMALLOC_HAVE_PTHREAD FALSE)
endif()

# Windows-specific system libraries
if(NOT JEMALLOC_PLATFORM_LIBS)
    set(JEMALLOC_PLATFORM_LIBS "")
endif()

# Windows ARM64 detection
if(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64|aarch64")
    message(STATUS "Windows ARM64 detected")
    set(JEMALLOC_IS_WINDOWS_ARM64 TRUE)

    # Windows ARM64 requires Visual Studio 2015 or later
    if(MSVC AND MSVC_VERSION LESS 1900)
        message(WARNING "Windows ARM64 requires Visual Studio 2015 or later")
    endif()
endif()

# Export to parent scope
set(JEMALLOC_PLATFORM_HEADERS "${JEMALLOC_PLATFORM_HEADERS}")
set(JEMALLOC_PLATFORM_DEFINITIONS "${JEMALLOC_PLATFORM_DEFINITIONS}")
set(JEMALLOC_PLATFORM_LIBS "${JEMALLOC_PLATFORM_LIBS}")
set(JEMALLOC_IS_MINGW "${JEMALLOC_IS_MINGW}" PARENT_SCOPE)
