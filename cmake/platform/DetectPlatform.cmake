# DetectPlatform.cmake
# Platform detection and configuration
# Sets JEMALLOC_PLATFORM to one of: windows, linux, darwin, freebsd, unix

# Detect platform - MECE (Mutually Exclusive, Collectively Exhaustive)
if(WIN32)
    set(JEMALLOC_PLATFORM "windows")
    set(JEMALLOC_IS_WINDOWS TRUE)
    set(JEMALLOC_IS_UNIX FALSE)
elseif(APPLE)
    set(JEMALLOC_PLATFORM "darwin")
    set(JEMALLOC_IS_WINDOWS FALSE)
    set(JEMALLOC_IS_UNIX TRUE)
    set(JEMALLOC_IS_DARWIN TRUE)
elseif(CMAKE_SYSTEM_NAME MATCHES "Linux")
    set(JEMALLOC_PLATFORM "linux")
    set(JEMALLOC_IS_WINDOWS FALSE)
    set(JEMALLOC_IS_UNIX TRUE)
    set(JEMALLOC_IS_LINUX TRUE)
elseif(CMAKE_SYSTEM_NAME MATCHES "FreeBSD")
    set(JEMALLOC_PLATFORM "freebsd")
    set(JEMALLOC_IS_WINDOWS FALSE)
    set(JEMALLOC_IS_UNIX TRUE)
    set(JEMALLOC_IS_FREEBSD TRUE)
elseif(CMAKE_SYSTEM_NAME MATCHES "MSYS" OR CMAKE_SYSTEM_NAME MATCHES "MINGW")
    # Windows MinGW/MSYS - treat as Windows
    set(JEMALLOC_PLATFORM "windows")
    set(JEMALLOC_IS_WINDOWS TRUE)
    set(JEMALLOC_IS_UNIX FALSE)
    message(STATUS "MinGW/MSYS detected, treating as Windows platform")
else()
    # Fallback for other Unix-like systems
    set(JEMALLOC_PLATFORM "unix")
    set(JEMALLOC_IS_WINDOWS FALSE)
    set(JEMALLOC_IS_UNIX TRUE)
    message(STATUS "Unknown platform ${CMAKE_SYSTEM_NAME}, treating as generic Unix")
endif()

# Set platform-specific file extensions
if(JEMALLOC_IS_WINDOWS)
    set(JEMALLOC_LIB_SUFFIX ".lib")
    set(JEMALLOC_DLL_SUFFIX ".dll")
    set(JEMALLOC_STATIC_PREFIX "")
    set(JEMALLOC_SHARED_PREFIX "")
    set(JEMALLOC_EXE_SUFFIX ".exe")
elseif(JEMALLOC_IS_DARWIN)
    set(JEMALLOC_LIB_SUFFIX ".a")
    set(JEMALLOC_DLL_SUFFIX ".dylib")
    set(JEMALLOC_STATIC_PREFIX "lib")
    set(JEMALLOC_SHARED_PREFIX "lib")
    set(JEMALLOC_EXE_SUFFIX "")
else()
    # Linux, FreeBSD, and other Unix
    set(JEMALLOC_LIB_SUFFIX ".a")
    set(JEMALLOC_DLL_SUFFIX ".so")
    set(JEMALLOC_STATIC_PREFIX "lib")
    set(JEMALLOC_SHARED_PREFIX "lib")
    set(JEMALLOC_EXE_SUFFIX "")
endif()

# Detect system page size (platform-specific defaults)
if(NOT DEFINED JEMALLOC_PAGE_SIZE)
    if(JEMALLOC_IS_WINDOWS)
        # Windows: 4KB on x86/x64, 64KB allocation granularity
        set(JEMALLOC_PAGE_SIZE 4096)
    elseif(JEMALLOC_IS_DARWIN)
        if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64")
            # Apple Silicon: 16KB pages
            set(JEMALLOC_PAGE_SIZE 16384)
        else()
            # Intel Mac: 4KB pages
            set(JEMALLOC_PAGE_SIZE 4096)
        endif()
    elseif(JEMALLOC_IS_LINUX)
        if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
            # ARM64 Linux: Often 64KB, but can be 4KB or 16KB
            # Use 4KB as safe default, can be overridden
            set(JEMALLOC_PAGE_SIZE 4096)
        else()
            # x86/x64 Linux: 4KB pages
            set(JEMALLOC_PAGE_SIZE 4096)
        endif()
    else()
        # FreeBSD and other Unix: 4KB default
        set(JEMALLOC_PAGE_SIZE 4096)
    endif()
endif()

# Export all variables to parent scope
set(JEMALLOC_PLATFORM "${JEMALLOC_PLATFORM}")
set(JEMALLOC_IS_WINDOWS "${JEMALLOC_IS_WINDOWS}")
set(JEMALLOC_IS_UNIX "${JEMALLOC_IS_UNIX}")
set(JEMALLOC_PAGE_SIZE "${JEMALLOC_PAGE_SIZE}")

message(STATUS "Platform: ${JEMALLOC_PLATFORM}")
message(STATUS "Page size: ${JEMALLOC_PAGE_SIZE} bytes")
