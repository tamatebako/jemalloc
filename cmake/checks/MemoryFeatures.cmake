# MemoryFeatures.cmake
# Check for memory-related system features

include(CheckCSourceCompiles)
include(CheckSymbolExists)

# mmap support
if(NOT WIN32)
    check_c_source_compiles("
        #include <sys/mman.h>
        int main() {
            void* p = mmap(NULL, 4096, PROT_READ|PROT_WRITE,
                          MAP_PRIVATE|MAP_ANON, -1, 0);
            return 0;
        }
    " JEMALLOC_HAVE_MMAP)
endif()

# madvise support and variants
if(NOT WIN32)
    check_symbol_exists(madvise "sys/mman.h" JEMALLOC_HAVE_MADVISE)

    if(JEMALLOC_HAVE_MADVISE)
        # MADV_DONTNEED
        check_c_source_compiles("
            #include <sys/mman.h>
            int main() {
                madvise(NULL, 0, MADV_DONTNEED);
                return 0;
            }
        " JEMALLOC_HAVE_MADV_DONTNEED)

        # MADV_FREE
        check_c_source_compiles("
            #include <sys/mman.h>
            int main() {
                madvise(NULL, 0, MADV_FREE);
                return 0;
            }
        " JEMALLOC_HAVE_MADV_FREE)

        # MADV_DONTDUMP
        check_c_source_compiles("
            #include <sys/mman.h>
            int main() {
                madvise(NULL, 0, MADV_DONTDUMP);
                return 0;
            }
        " JEMALLOC_HAVE_MADV_DONTDUMP)

        # MADV_NOHUGEPAGE
        check_c_source_compiles("
            #include <sys/mman.h>
            int main() {
                madvise(NULL, 0, MADV_NOHUGEPAGE);
                return 0;
            }
        " JEMALLOC_HAVE_MADV_NOHUGEPAGE)
    endif()
endif()

# sbrk support (deprecated on many systems)
check_symbol_exists(sbrk "unistd.h" JEMALLOC_HAVE_SBRK)

# VirtualAlloc on Windows
if(WIN32)
    set(JEMALLOC_HAVE_VIRTUALALLOC TRUE)
endif()

# Check for malloc_usable_size
if(NOT WIN32)
    check_symbol_exists(malloc_usable_size "malloc.h" JEMALLOC_HAVE_MALLOC_USABLE_SIZE)
endif()

# Check for pthread_atfork (for handling fork)
if(UNIX)
    check_symbol_exists(pthread_atfork "pthread.h" JEMALLOC_HAVE_PTHREAD_ATFORK)
endif()

# Check for secure_getenv (Linux-specific)
if(CMAKE_SYSTEM_NAME MATCHES "Linux")
    check_symbol_exists(secure_getenv "stdlib.h" JEMALLOC_HAVE_SECURE_GETENV)
endif()

# Check for issetugid (BSD)
if(CMAKE_SYSTEM_NAME MATCHES "BSD|Darwin")
    check_symbol_exists(issetugid "unistd.h" JEMALLOC_HAVE_ISSETUGID)
endif()

# Check for gettimeofday
check_symbol_exists(gettimeofday "sys/time.h" JEMALLOC_HAVE_GETTIMEOFDAY)

# Check for clock_gettime
check_symbol_exists(clock_gettime "time.h" JEMALLOC_HAVE_CLOCK_GETTIME)

# Export all results to parent scope
set(JEMALLOC_HAVE_MMAP "${JEMALLOC_HAVE_MMAP}")
set(JEMALLOC_HAVE_MADVISE "${JEMALLOC_HAVE_MADVISE}")
set(JEMALLOC_HAVE_MADV_DONTNEED "${JEMALLOC_HAVE_MADV_DONTNEED}")
set(JEMALLOC_HAVE_MADV_FREE "${JEMALLOC_HAVE_MADV_FREE}")
set(JEMALLOC_HAVE_MADV_DONTDUMP "${JEMALLOC_HAVE_MADV_DONTDUMP}")
set(JEMALLOC_HAVE_MADV_NOHUGEPAGE "${JEMALLOC_HAVE_MADV_NOHUGEPAGE}")
set(JEMALLOC_HAVE_SBRK "${JEMALLOC_HAVE_SBRK}")
set(JEMALLOC_HAVE_VIRTUALALLOC "${JEMALLOC_HAVE_VIRTUALALLOC}")
set(JEMALLOC_HAVE_PTHREAD_ATFORK "${JEMALLOC_HAVE_PTHREAD_ATFORK}")
set(JEMALLOC_HAVE_SECURE_GETENV "${JEMALLOC_HAVE_SECURE_GETENV}")
set(JEMALLOC_HAVE_ISSETUGID "${JEMALLOC_HAVE_ISSETUGID}")
set(JEMALLOC_HAVE_GETTIMEOFDAY "${JEMALLOC_HAVE_GETTIMEOFDAY}")
set(JEMALLOC_HAVE_CLOCK_GETTIME "${JEMALLOC_HAVE_CLOCK_GETTIME}")
