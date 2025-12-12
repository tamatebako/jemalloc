# ThreadSupport.cmake
# Check for threading support

include(CheckCSourceCompiles)
include(CheckSymbolExists)

# Find threads package (provides Threads::Threads)
find_package(Threads)

if(Threads_FOUND)
    set(JEMALLOC_HAVE_PTHREAD TRUE)

    # Check for specific pthread functions
    set(CMAKE_REQUIRED_LIBRARIES ${CMAKE_THREAD_LIBS_INIT})

    check_symbol_exists(pthread_create "pthread.h" JEMALLOC_HAVE_PTHREAD_CREATE)
    check_symbol_exists(pthread_atfork "pthread.h" JEMALLOC_HAVE_PTHREAD_ATFORK)
    check_symbol_exists(pthread_setname_np "pthread.h" JEMALLOC_HAVE_PTHREAD_SETNAME_NP)
    check_symbol_exists(pthread_getname_np "pthread.h" JEMALLOC_HAVE_PTHREAD_GETNAME_NP)

    # Check for pthread_mutex_adaptive_np (Linux-specific)
    check_c_source_compiles("
        #include <pthread.h>
        int main() {
            pthread_mutexattr_t attr;
            pthread_mutexattr_init(&attr);
            pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_ADAPTIVE_NP);
            return 0;
        }
    " JEMALLOC_HAVE_PTHREAD_MUTEX_ADAPTIVE_NP)

    unset(CMAKE_REQUIRED_LIBRARIES)
else()
    set(JEMALLOC_HAVE_PTHREAD FALSE)
endif()

# Check for CPU yield instruction
if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64|ARM64")
    # ARM64 CPU yield
    check_c_source_compiles("
        int main() {
            __asm__ volatile(\"isb\");
            return 0;
        }
    " JEMALLOC_HAVE_CPU_SPINWAIT_ARM)

    # MSVC ARM64 intrinsic
    if(MSVC)
        check_c_source_compiles("
            #include <intrin.h>
            int main() {
                __yield();
                return 0;
            }
        " JEMALLOC_HAVE_CPU_SPINWAIT_MSVC)
    endif()
endif()

# Export to parent scope
set(JEMALLOC_HAVE_PTHREAD "${JEMALLOC_HAVE_PTHREAD}")
set(JEMALLOC_HAVE_PTHREAD_ATFORK "${JEMALLOC_HAVE_PTHREAD_ATFORK}")