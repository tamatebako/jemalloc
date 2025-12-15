# ProfilingSupport.cmake
# Detect profiling backend support for heap profiling

include(CheckCSourceCompiles)

# Only check for profiling backends if profiling is enabled
if(NOT JEMALLOC_ENABLE_PROF)
    return()
endif()

# ============================================================================
# Windows MSVC Profiling Backend Detection
# ============================================================================

# Check for Windows MSVC profiling backend (CaptureStackBackTrace)
# This works on ALL Windows compilers (MSVC, MinGW) on all architectures
if(WIN32)
    check_c_source_compiles("
        #include <windows.h>
        int main() {
            void* backtrace[10];
            CaptureStackBackTrace(0, 10, backtrace, NULL);
            return 0;
        }
    " JEMALLOC_HAVE_CAPTURESTACKBACKTRACE)

    if(JEMALLOC_HAVE_CAPTURESTACKBACKTRACE)
        set(JEMALLOC_PROF_MSVC 1 PARENT_SCOPE)
        message(STATUS "Windows profiling backend: ENABLED (CaptureStackBackTrace)")
    else()
        set(JEMALLOC_PROF_MSVC 0 PARENT_SCOPE)
        message(WARNING "Windows profiling backend not found - CaptureStackBackTrace unavailable")
    endif()
else()
    # Non-Windows platforms: MSVC backend not applicable
    set(JEMALLOC_PROF_MSVC 0 PARENT_SCOPE)
endif()

# Note: Other profiling backends (libunwind, libgcc, frame pointer)
# will be added in future work. For now, those are handled by the
# existing source code's #ifdef fallbacks.