# SystemHeaders.cmake
# Check for system header availability

include(CheckIncludeFiles)
include(CheckCSourceCompiles)

# POSIX headers
check_include_files("pthread.h" JEMALLOC_HAVE_PTHREAD_H)
check_include_files("sys/mman.h" JEMALLOC_HAVE_SYS_MMAN_H)
check_include_files("unistd.h" JEMALLOC_HAVE_UNISTD_H)
check_include_files("sys/param.h" JEMALLOC_HAVE_SYS_PARAM_H)
check_include_files("sys/time.h" JEMALLOC_HAVE_SYS_TIME_H)
check_include_files("sys/types.h" JEMALLOC_HAVE_SYS_TYPES_H)
check_include_files("malloc.h" JEMALLOC_HAVE_MALLOC_H)
check_include_files("stdint.h" JEMALLOC_HAVE_STDINT_H)
check_include_files("stdbool.h" JEMALLOC_HAVE_STDBOOL_H)
check_include_files("inttypes.h" JEMALLOC_HAVE_INTTYPES_H)

# Threading headers
check_include_files("sched.h" JEMALLOC_HAVE_SCHED_H)

# Linux-specific headers
if(CMAKE_SYSTEM_NAME MATCHES "Linux")
    check_include_files("linux/unistd.h" JEMALLOC_HAVE_LINUX_UNISTD_H)
    check_include_files("sys/syscall.h" JEMALLOC_HAVE_SYS_SYSCALL_H)
endif()

# Windows headers
if(WIN32)
    check_include_files("windows.h" JEMALLOC_HAVE_WINDOWS_H)
    check_include_files("psapi.h" JEMALLOC_HAVE_PSAPI_H)
endif()

# macOS-specific headers
if(APPLE)
    check_include_files("mach/mach.h" JEMALLOC_HAVE_MACH_MACH_H)
    check_include_files("mach/vm_map.h" JEMALLOC_HAVE_MACH_VM_MAP_H)
endif()

# FreeBSD-specific headers
if(CMAKE_SYSTEM_NAME MATCHES "FreeBSD")
    check_include_files("sys/sysctl.h" JEMALLOC_HAVE_SYS_SYSCTL_H)
    check_include_files("sys/user.h" JEMALLOC_HAVE_SYS_USER_H)
endif()

# Function existence checks
include(CheckSymbolExists)
check_symbol_exists(malloc_usable_size "malloc.h" JEMALLOC_HAVE_MALLOC_USABLE_SIZE)
check_symbol_exists(sched_yield "sched.h" JEMALLOC_HAVE_SCHED_YIELD)

# Check if strerror_r returns char* (GNU version) when _GNU_SOURCE is defined
# This is needed for src/malloc_io.c buferror() function
check_c_source_compiles("
#define _GNU_SOURCE
#include <string.h>
int main() {
    char buf[100];
    char *result = strerror_r(1, buf, sizeof(buf));
    (void)result;
    return 0;
}
" JEMALLOC_STRERROR_R_RETURNS_CHAR_WITH_GNU_SOURCE)

# Export results to parent scope
set(JEMALLOC_HAVE_PTHREAD_H "${JEMALLOC_HAVE_PTHREAD_H}")
set(JEMALLOC_HAVE_SYS_MMAN_H "${JEMALLOC_HAVE_SYS_MMAN_H}")
set(JEMALLOC_HAVE_UNISTD_H "${JEMALLOC_HAVE_UNISTD_H}")
set(JEMALLOC_HAVE_STDINT_H "${JEMALLOC_HAVE_STDINT_H}")
set(JEMALLOC_HAVE_STDBOOL_H "${JEMALLOC_HAVE_STDBOOL_H}")
set(JEMALLOC_HAVE_INTTYPES_H "${JEMALLOC_HAVE_INTTYPES_H}")
set(JEMALLOC_HAVE_MALLOC_H "${JEMALLOC_HAVE_MALLOC_H}")
set(JEMALLOC_HAVE_WINDOWS_H "${JEMALLOC_HAVE_WINDOWS_H}")
set(JEMALLOC_HAVE_MACH_MACH_H "${JEMALLOC_HAVE_MACH_MACH_H}")
set(JEMALLOC_HAVE_SYS_SYSCTL_H "${JEMALLOC_HAVE_SYS_SYSCTL_H}")
set(JEMALLOC_HAVE_MALLOC_USABLE_SIZE "${JEMALLOC_HAVE_MALLOC_USABLE_SIZE}")
set(JEMALLOC_HAVE_SCHED_YIELD "${JEMALLOC_HAVE_SCHED_YIELD}")