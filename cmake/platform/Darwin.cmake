# Darwin.cmake
# macOS-specific configuration

# Include common Unix configuration first
include(${CMAKE_CURRENT_LIST_DIR}/Unix.cmake)

# macOS-specific headers
list(APPEND JEMALLOC_PLATFORM_HEADERS
    mach/mach.h
    mach/vm_map.h
    mach/vm_statistics.h
)

# macOS-specific compile definitions
list(APPEND JEMALLOC_PLATFORM_DEFINITIONS
    _DARWIN_C_SOURCE
)

# macOS zone allocator integration
set(JEMALLOC_ZONE TRUE)

# No DSS (sbrk) support on modern macOS
set(JEMALLOC_HAVE_SBRK FALSE)

# Apple Silicon detection
if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64")
    message(STATUS "macOS ARM64 (Apple Silicon) detected")
    set(JEMALLOC_IS_APPLE_SILICON TRUE)
endif()

# Export to parent scope
set(JEMALLOC_PLATFORM_HEADERS "${JEMALLOC_PLATFORM_HEADERS}")
set(JEMALLOC_PLATFORM_DEFINITIONS "${JEMALLOC_PLATFORM_DEFINITIONS}")
set(JEMALLOC_PLATFORM_LIBS "${JEMALLOC_PLATFORM_LIBS}")
set(JEMALLOC_ZONE "${JEMALLOC_ZONE}")