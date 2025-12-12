# FreeBSD.cmake
# FreeBSD-specific configuration

# Include common Unix configuration first
include(${CMAKE_CURRENT_LIST_DIR}/Unix.cmake)

# FreeBSD-specific headers
list(APPEND JEMALLOC_PLATFORM_HEADERS
    sys/sysctl.h
    sys/user.h
)

# FreeBSD has sbrk support
set(JEMALLOC_HAVE_SBRK TRUE)

# FreeBSD-specific sysctl configuration
set(JEMALLOC_HAVE_SYSCTL TRUE)

# FreeBSD supports utrace
include(CheckSymbolExists)
check_symbol_exists(utrace "sys/param.h;sys/time.h;sys/uio.h;sys/ktrace.h" JEMALLOC_HAVE_UTRACE)

# FreeBSD may need libutil
find_library(UTIL_LIBRARY util)
if(UTIL_LIBRARY)
    list(APPEND JEMALLOC_PLATFORM_LIBS ${UTIL_LIBRARY})
endif()

# Export to parent scope
set(JEMALLOC_PLATFORM_HEADERS "${JEMALLOC_PLATFORM_HEADERS}")
set(JEMALLOC_PLATFORM_DEFINITIONS "${JEMALLOC_PLATFORM_DEFINITIONS}")
set(JEMALLOC_PLATFORM_LIBS "${JEMALLOC_PLATFORM_LIBS}")
