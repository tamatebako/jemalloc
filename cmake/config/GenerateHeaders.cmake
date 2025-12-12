# GenerateHeaders.cmake
# Fully native CMake header generation (replaces autotools shell scripts)

# Get jemalloc root directory
get_filename_component(JEMALLOC_ROOT_DIR "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

# Set up output directories
set(JEMALLOC_INCLUDE_DIR "${CMAKE_BINARY_DIR}/include")
set(JEMALLOC_INTERNAL_INCLUDE_DIR "${JEMALLOC_INCLUDE_DIR}/jemalloc/internal")

# Create output directories
file(MAKE_DIRECTORY "${JEMALLOC_INCLUDE_DIR}/jemalloc")
file(MAKE_DIRECTORY "${JEMALLOC_INTERNAL_INCLUDE_DIR}")

# Convert boolean values to 1/0 for C headers
macro(bool_to_int var)
    if(${var})
        set(${var} 1)
    else()
        set(${var} 0)
    endif()
endmacro()

# Convert all detected features to 1/0
bool_to_int(JEMALLOC_C11_ATOMICS)
bool_to_int(JEMALLOC_GCC_ATOMIC_ATOMICS)
bool_to_int(JEMALLOC_GCC_U8_ATOMIC_ATOMICS)
bool_to_int(JEMALLOC_GCC_SYNC_ATOMICS)
bool_to_int(JEMALLOC_GCC_U8_SYNC_ATOMICS)
bool_to_int(JEMALLOC_HAVE_PTHREAD)
bool_to_int(JEMALLOC_HAVE_MMAP)
bool_to_int(JEMALLOC_HAVE_MADVISE)
bool_to_int(JEMALLOC_HAVE_MADV_DONTNEED)
bool_to_int(JEMALLOC_HAVE_MADV_FREE)
# CRITICAL: Force JEMALLOC_TLS=0 for ALL Windows (MSVC + MinGW)
# Reason: tsd.c and tsd.h have different check orders
# tsd.h checks _WIN32 BEFORE JEMALLOC_TLS → selects tsd_win.h
# tsd.c checks JEMALLOC_TLS BEFORE _WIN32 → would select pthread TSD if JEMALLOC_TLS=1
# Both must consistently use tsd_win.h on Windows to avoid macro expansion errors
if(JEMALLOC_IS_WINDOWS)
    set(JEMALLOC_TLS 0)
    message(STATUS "Windows detected (JEMALLOC_IS_WINDOWS=${JEMALLOC_IS_WINDOWS}): Forcing JEMALLOC_TLS=0 (using tsd_win.h)")
else()
    bool_to_int(JEMALLOC_TLS)
endif()
bool_to_int(JEMALLOC_HAVE_BUILTIN_UNREACHABLE)
bool_to_int(JEMALLOC_HAVE_FFS)
bool_to_int(JEMALLOC_HAVE_BUILTIN_FFS)
bool_to_int(JEMALLOC_HAVE_BUILTIN_FFSL)
bool_to_int(JEMALLOC_HAVE_BUILTIN_FFSLL)
bool_to_int(JEMALLOC_HAVE_BUILTIN_CLZ)

# On Windows, JEMALLOC_TLS is set but not #defined as a preprocessor macro
# (This is different from setting a value for JEMALLOC_TLS_MODEL)
# We must use the value of JEMALLOC_TLS here directly.
set(JEMALLOC_TLS_VALUE ${JEMALLOC_TLS})
string(TOUPPER "${JEMALLOC_TLS_VALUE}" JEMALLOC_TLS_VALUE_UPPER)

# ============================================================================
# Template Variables (from configure.ac)
# ============================================================================

# Version variables
set(jemalloc_version "${JEMALLOC_VERSION}")
set(jemalloc_version_major "${JEMALLOC_VERSION_MAJOR}")
set(jemalloc_version_minor "${JEMALLOC_VERSION_MINOR}")
set(jemalloc_version_bugfix "${JEMALLOC_VERSION_PATCH}")
set(jemalloc_version_nrev "0")
set(jemalloc_version_gid "0000000000000000000000000000000000000000")

# Install suffix (empty by default)
if(NOT DEFINED install_suffix)
    set(install_suffix "")
endif()

# Private namespace prefix (default: "je_")
if(NOT DEFINED private_namespace)
    set(private_namespace "je_")
endif()

# Public API prefix for symbol mangling
# On macOS/Windows, default to "je_" to avoid conflicts
# On Linux/BSD with ELF, can be empty
if(NOT DEFINED je_)
    if(WIN32 OR APPLE)
        set(je_ "je_")
    else()
        set(je_ "")
    endif()
endif()

# Config malloc conf
if(NOT DEFINED config_malloc_conf)
    set(config_malloc_conf "")
endif()

# ABI (Application Binary Interface)
if(WIN32)
    set(abi "pecoff")
elseif(APPLE)
    set(abi "macho")
else()
    set(abi "elf")
endif()

# Platform-specific settings
if(WIN32)
    set(JEMALLOC_HAVE_WINDOWS 1)
    set(JEMALLOC_HAVE_SBRK 0)
else()
    set(JEMALLOC_HAVE_WINDOWS 0)
endif()

# CPU spinwait support
if(JEMALLOC_HAVE_CPU_SPINWAIT_ARM OR JEMALLOC_HAVE_CPU_SPINWAIT_MSVC)
    set(JEMALLOC_HAVE_CPU_SPINWAIT 1)
    set(HAVE_CPU_SPINWAIT 1)
else()
    set(JEMALLOC_HAVE_CPU_SPINWAIT 0)
    set(HAVE_CPU_SPINWAIT 0)
endif()

# ============================================================================
# Compute LG_SIZEOF_* values (log2 of sizeof)
# ============================================================================

# Compute LG_SIZEOF_PTR from CMAKE_SIZEOF_VOID_P
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(LG_SIZEOF_PTR 3)  # 2^3 = 8
elseif(CMAKE_SIZEOF_VOID_P EQUAL 4)
    set(LG_SIZEOF_PTR 2)  # 2^2 = 4
else()
    message(FATAL_ERROR "Unsupported pointer size: ${CMAKE_SIZEOF_VOID_P}")
endif()

# LG_SIZEOF_INT: sizeof(int) = 4 on all modern platforms
set(LG_SIZEOF_INT 2)  # 2^2 = 4

# LG_SIZEOF_LONG: varies by platform
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    if(WIN32)
        set(LG_SIZEOF_LONG 2)  # Windows LLP64: long is 4 bytes
    else()
        set(LG_SIZEOF_LONG 3)  # Unix LP64: long is 8 bytes
    endif()
else()
    set(LG_SIZEOF_LONG 2)  # 32-bit: long is 4 bytes
endif()

# LG_SIZEOF_LONG_LONG: sizeof(long long) = 8 on all platforms
set(LG_SIZEOF_LONG_LONG 3)  # 2^3 = 8

# LG_SIZEOF_INTMAX_T: typically same as long long
set(LG_SIZEOF_INTMAX_T 3)  # 2^3 = 8

# Compute LG_PAGE from page size
set(temp_page ${JEMALLOC_PAGE_SIZE})
math(EXPR LG_PAGE "0")
while(temp_page GREATER 1)
    math(EXPR temp_page "${temp_page} / 2")
    math(EXPR LG_PAGE "${LG_PAGE} + 1")
endwhile()

# LG_VADDR (virtual address bits)
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
        set(LG_VADDR 48)  # x86-64 uses 48-bit virtual addresses
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
        set(LG_VADDR 48)  # ARM64 typically uses 48-bit
    else()
        set(LG_VADDR 64)  # Generic 64-bit
    endif()
else()
    set(LG_VADDR 32)  # 32-bit systems
endif()

# LG_QUANTUM (minimum alignment)
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(LG_QUANTUM 4)  # 16-byte alignment on 64-bit
else()
    set(LG_QUANTUM 3)  # 8-byte alignment on 32-bit
endif()

# LG_HUGEPAGE (2MB on most systems)
set(LG_HUGEPAGE 21)  # 2^21 = 2MB

# ============================================================================
# Additional Required Template Variables
# ============================================================================

# JEMALLOC_MAPS_COALESCE - mappings coalesce on Unix but not Windows
if(WIN32)
    set(JEMALLOC_MAPS_COALESCE 0)
else()
    set(JEMALLOC_MAPS_COALESCE 1)
endif()

# JEMALLOC_RETAIN - retain memory by default on 64-bit systems
if(CMAKE_SIZEOF_VOID_P EQUAL 8 AND NOT WIN32)
    set(JEMALLOC_RETAIN 1)
else()
    set(JEMALLOC_RETAIN 0)
endif()

# JEMALLOC_ZONE - Darwin malloc zones
if(APPLE)
    set(JEMALLOC_ZONE 1)
else()
    set(JEMALLOC_ZONE 0)
endif()

# JEMALLOC_DSS - sbrk support (not on Windows, optional on others)
if(WIN32)
    set(JEMALLOC_DSS 0)
elseif(JEMALLOC_HAVE_SBRK)
    set(JEMALLOC_DSS 1)
else()
    set(JEMALLOC_DSS 0)
endif()

# Config options
set(JEMALLOC_CACHE_OBLIVIOUS 1)  # Default enabled
set(JEMALLOC_FILL 1)  # Memory filling support
set(JEMALLOC_LAZY_LOCK 0)  # Not used on modern systems

# JEMALLOC_TLS_MODEL for __thread variables
if(NOT JEMALLOC_IS_WINDOWS)
    set(JEMALLOC_TLS_MODEL "__attribute__((tls_model(\"initial-exec\")))")
else()
    set(JEMALLOC_TLS_MODEL "")
endif()

# JEMALLOC_CODE_COVERAGE - disabled
set(JEMALLOC_CODE_COVERAGE 0)

# Private namespace
if(NOT DEFINED JEMALLOC_PRIVATE_NAMESPACE)
    set(JEMALLOC_PRIVATE_NAMESPACE "je_")
endif()

# Public prefix
if(NOT DEFINED JEMALLOC_PREFIX)
    set(JEMALLOC_PREFIX "")
endif()
if(NOT DEFINED JEMALLOC_CPREFIX)
    set(JEMALLOC_CPREFIX "JEMALLOC_")
endif()

# Config malloc conf
if(NOT DEFINED JEMALLOC_CONFIG_MALLOC_CONF)
    set(JEMALLOC_CONFIG_MALLOC_CONF "")
endif()

# ============================================================================
# Public Symbols List (from configure.ac line 1221)
# ============================================================================
set(PUBLIC_SYMS
    aligned_alloc
    calloc
    dallocx
    free
    free_sized
    free_aligned_sized
    mallctl
    mallctlbymib
    mallctlnametomib
    malloc
    malloc_conf
    malloc_conf_2_conf_harder
    malloc_message
    malloc_stats_print
    malloc_usable_size
    mallocx
    nallocx
    posix_memalign
    rallocx
    realloc
    sallocx
    sdallocx
    xallocx
)

# Add platform-specific symbols if available
# Note: These would be detected by AC_CHECK_FUNC in configure.ac
# For now, we add the common ones
list(APPEND PUBLIC_SYMS
    smallocx_${jemalloc_version_gid}
)

# ============================================================================
# Generate public_symbols.txt
# Format: symbol_name:mangled_name (one per line)
# ============================================================================
set(PUBLIC_SYMBOLS_TXT "")
foreach(sym ${PUBLIC_SYMS})
    set(PUBLIC_SYMBOLS_TXT "${PUBLIC_SYMBOLS_TXT}${sym}:${je_}${sym}\n")
endforeach()
file(WRITE "${JEMALLOC_INTERNAL_INCLUDE_DIR}/public_symbols.txt" "${PUBLIC_SYMBOLS_TXT}")

# ============================================================================
# Generate Template Headers (.in files)
# ============================================================================

configure_file(
    "${JEMALLOC_ROOT_DIR}/include/jemalloc/jemalloc_defs.h.in"
    "${JEMALLOC_INCLUDE_DIR}/jemalloc/jemalloc_defs.h"
    @ONLY
)

# Post-process jemalloc_defs.h to replace #undef with #define for LG_SIZEOF_PTR
file(READ "${JEMALLOC_INCLUDE_DIR}/jemalloc/jemalloc_defs.h" DEFS_CONTENT)
string(REGEX REPLACE "#undef LG_SIZEOF_PTR\n" "#define LG_SIZEOF_PTR ${LG_SIZEOF_PTR}\n" DEFS_CONTENT "${DEFS_CONTENT}")

# JEMALLOC_USABLE_SIZE_CONST - Linux doesn't have const, others do
# Must always be defined (as either empty or "const")
if(JEMALLOC_IS_LINUX)
    string(REGEX REPLACE "#undef JEMALLOC_USABLE_SIZE_CONST\n" "#define JEMALLOC_USABLE_SIZE_CONST /* empty on Linux */\n" DEFS_CONTENT "${DEFS_CONTENT}")
else()
    string(REGEX REPLACE "#undef JEMALLOC_USABLE_SIZE_CONST\n" "#define JEMALLOC_USABLE_SIZE_CONST const\n" DEFS_CONTENT "${DEFS_CONTENT}")
endif()

file(WRITE "${JEMALLOC_INCLUDE_DIR}/jemalloc/jemalloc_defs.h" "${DEFS_CONTENT}")

configure_file(
    "${JEMALLOC_ROOT_DIR}/include/jemalloc/internal/jemalloc_internal_defs.h.in"
    "${JEMALLOC_INTERNAL_INCLUDE_DIR}/jemalloc_internal_defs.h"
    @ONLY
)

# Post-process jemalloc_internal_defs.h to replace #undef with #define for computed values
file(READ "${JEMALLOC_INTERNAL_INCLUDE_DIR}/jemalloc_internal_defs.h" INTERNAL_DEFS_CONTENT)

# Replace #undef lines with #define for our computed values
string(REGEX REPLACE "#undef LG_SIZEOF_PTR\n" "#define LG_SIZEOF_PTR ${LG_SIZEOF_PTR}\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
string(REGEX REPLACE "#undef LG_SIZEOF_INT\n" "#define LG_SIZEOF_INT ${LG_SIZEOF_INT}\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
string(REGEX REPLACE "#undef LG_SIZEOF_LONG_LONG\n" "#define LG_SIZEOF_LONG_LONG ${LG_SIZEOF_LONG_LONG}\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
string(REGEX REPLACE "#undef LG_SIZEOF_LONG\n" "#define LG_SIZEOF_LONG ${LG_SIZEOF_LONG}\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
string(REGEX REPLACE "#undef LG_SIZEOF_INTMAX_T\n" "#define LG_SIZEOF_INTMAX_T ${LG_SIZEOF_INTMAX_T}\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
string(REGEX REPLACE "#undef LG_PAGE\n" "#define LG_PAGE ${LG_PAGE}\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
string(REGEX REPLACE "#undef LG_VADDR\n" "#define LG_VADDR ${LG_VADDR}\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
string(REGEX REPLACE "#undef LG_QUANTUM\n" "#define LG_QUANTUM ${LG_QUANTUM}\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
string(REGEX REPLACE "#undef LG_HUGEPAGE\n" "#define LG_HUGEPAGE ${LG_HUGEPAGE}\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")

# Replace boolean/integer values
string(REGEX REPLACE "#undef JEMALLOC_MAPS_COALESCE\n" "#define JEMALLOC_MAPS_COALESCE ${JEMALLOC_MAPS_COALESCE}\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
string(REGEX REPLACE "#undef JEMALLOC_RETAIN\n" "#define JEMALLOC_RETAIN ${JEMALLOC_RETAIN}\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")

# CPU spinwait support - define both CPU_SPINWAIT and HAVE_CPU_SPINWAIT
if(JEMALLOC_HAVE_CPU_SPINWAIT_ARM)
    string(REGEX REPLACE "#undef CPU_SPINWAIT\n" "#define CPU_SPINWAIT __asm__ volatile(\"yield\")\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
    string(REGEX REPLACE "#undef HAVE_CPU_SPINWAIT\n" "#define HAVE_CPU_SPINWAIT 1\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
elseif(JEMALLOC_HAVE_CPU_SPINWAIT_MSVC)
    string(REGEX REPLACE "#undef CPU_SPINWAIT\n" "#define CPU_SPINWAIT YieldProcessor()\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
    string(REGEX REPLACE "#undef HAVE_CPU_SPINWAIT\n" "#define HAVE_CPU_SPINWAIT 1\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
else()
    string(REGEX REPLACE "#undef CPU_SPINWAIT\n" "/* #undef CPU_SPINWAIT */\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
    string(REGEX REPLACE "#undef HAVE_CPU_SPINWAIT\n" "#define HAVE_CPU_SPINWAIT 0\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
endif()

# JEMALLOC_ZONE - only define if 1, leave #undef if 0 (because #ifdef checks definition, not value)
if(JEMALLOC_ZONE)
    string(REGEX REPLACE "#undef JEMALLOC_ZONE\n" "#define JEMALLOC_ZONE\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
else()
    string(REGEX REPLACE "#undef JEMALLOC_ZONE\n" "/* #undef JEMALLOC_ZONE */\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
endif()

# JEMALLOC_DSS - only define if 1
if(JEMALLOC_DSS)
    string(REGEX REPLACE "#undef JEMALLOC_DSS\n" "#define JEMALLOC_DSS\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
else()
    string(REGEX REPLACE "#undef JEMALLOC_DSS\n" "/* #undef JEMALLOC_DSS */\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
endif()

string(REGEX REPLACE "#undef JEMALLOC_FILL\n" "#define JEMALLOC_FILL ${JEMALLOC_FILL}\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
string(REGEX REPLACE "#undef JEMALLOC_CACHE_OBLIVIOUS\n" "#define JEMALLOC_CACHE_OBLIVIOUS ${JEMALLOC_CACHE_OBLIVIOUS}\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
string(REGEX REPLACE "#undef JEMALLOC_LAZY_LOCK\n" "/* #undef JEMALLOC_LAZY_LOCK */\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
if(JEMALLOC_TLS_MODEL)
    string(REGEX REPLACE "#undef JEMALLOC_TLS_MODEL\n" "#define JEMALLOC_TLS_MODEL ${JEMALLOC_TLS_MODEL}\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
endif()

# JEMALLOC_TLS - only define if 1, leave #undef if 0
# CRITICAL: tsd.h uses #elif (defined(JEMALLOC_TLS)), so defining as 0 would select wrong implementation
if(JEMALLOC_TLS)
    string(REGEX REPLACE "#undef JEMALLOC_TLS\n" "#define JEMALLOC_TLS\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
else()
    string(REGEX REPLACE "#undef JEMALLOC_TLS\n" "/* #undef JEMALLOC_TLS */\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
endif()

string(REGEX REPLACE "#undef JEMALLOC_CODE_COVERAGE\n" "/* #undef JEMALLOC_CODE_COVERAGE */\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
if(JEMALLOC_PRIVATE_NAMESPACE)
    string(REGEX REPLACE "#undef JEMALLOC_PRIVATE_NAMESPACE\n" "#define JEMALLOC_PRIVATE_NAMESPACE ${JEMALLOC_PRIVATE_NAMESPACE}\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
endif()

# Replace detected feature flags
if(JEMALLOC_C11_ATOMICS)
    string(REGEX REPLACE "#undef JEMALLOC_C11_ATOMICS\n" "#define JEMALLOC_C11_ATOMICS 1\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
endif()
if(JEMALLOC_GCC_ATOMIC_ATOMICS)
    string(REGEX REPLACE "#undef JEMALLOC_GCC_ATOMIC_ATOMICS\n" "#define JEMALLOC_GCC_ATOMIC_ATOMICS 1\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
endif()
if(JEMALLOC_GCC_U8_ATOMIC_ATOMICS)
    string(REGEX REPLACE "#undef JEMALLOC_GCC_U8_ATOMIC_ATOMICS\n" "#define JEMALLOC_GCC_U8_ATOMIC_ATOMICS 1\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
endif()
if(JEMALLOC_GCC_SYNC_ATOMICS)
    string(REGEX REPLACE "#undef JEMALLOC_GCC_SYNC_ATOMICS\n" "#define JEMALLOC_GCC_SYNC_ATOMICS 1\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
endif()
if(JEMALLOC_GCC_U8_SYNC_ATOMICS)
    string(REGEX REPLACE "#undef JEMALLOC_GCC_U8_SYNC_ATOMICS\n" "#define JEMALLOC_GCC_U8_SYNC_ATOMICS 1\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
endif()
if(JEMALLOC_HAVE_PTHREAD)
    string(REGEX REPLACE "#undef JEMALLOC_HAVE_PTHREAD\n" "#define JEMALLOC_HAVE_PTHREAD 1\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
endif()
if(JEMALLOC_HAVE_MADVISE)
    string(REGEX REPLACE "#undef JEMALLOC_HAVE_MADVISE\n" "#define JEMALLOC_HAVE_MADVISE 1\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
endif()

# strerror_r return type detection (GNU vs XSI)
if(JEMALLOC_STRERROR_R_RETURNS_CHAR_WITH_GNU_SOURCE)
    string(REGEX REPLACE "#undef JEMALLOC_STRERROR_R_RETURNS_CHAR_WITH_GNU_SOURCE\n" "#define JEMALLOC_STRERROR_R_RETURNS_CHAR_WITH_GNU_SOURCE 1\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
endif()

# Define JEMALLOC_INTERNAL_UNREACHABLE based on compiler support
if(JEMALLOC_HAVE_BUILTIN_UNREACHABLE)
    string(REGEX REPLACE "#undef JEMALLOC_INTERNAL_UNREACHABLE\n" "#define JEMALLOC_INTERNAL_UNREACHABLE __builtin_unreachable\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
elseif(CMAKE_C_COMPILER_ID MATCHES "MSVC")
    string(REGEX REPLACE "#undef JEMALLOC_INTERNAL_UNREACHABLE\n" "#define JEMALLOC_INTERNAL_UNREACHABLE() __assume(0)\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
else()
    # Fallback: use abort() as unreachable marker
    string(REGEX REPLACE "#undef JEMALLOC_INTERNAL_UNREACHABLE\n" "#define JEMALLOC_INTERNAL_UNREACHABLE abort\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
endif()

# Define JEMALLOC_INTERNAL_FFS/FFSL/FFSLL based on compiler support
if(JEMALLOC_HAVE_BUILTIN_FFS)
    string(REGEX REPLACE "#undef JEMALLOC_INTERNAL_FFS\n" "#define JEMALLOC_INTERNAL_FFS __builtin_ffs\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
    string(REGEX REPLACE "#undef JEMALLOC_INTERNAL_FFSL\n" "#define JEMALLOC_INTERNAL_FFSL __builtin_ffsl\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
    string(REGEX REPLACE "#undef JEMALLOC_INTERNAL_FFSLL\n" "#define JEMALLOC_INTERNAL_FFSLL __builtin_ffsll\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
elseif(JEMALLOC_HAVE_FFS)
    string(REGEX REPLACE "#undef JEMALLOC_INTERNAL_FFS\n" "#define JEMALLOC_INTERNAL_FFS ffs\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
    string(REGEX REPLACE "#undef JEMALLOC_INTERNAL_FFSL\n" "#define JEMALLOC_INTERNAL_FFSL ffsl\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
    string(REGEX REPLACE "#undef JEMALLOC_INTERNAL_FFSLL\n" "#define JEMALLOC_INTERNAL_FFSLL ffsll\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
elseif(CMAKE_C_COMPILER_ID MATCHES "MSVC")
    # MSVC doesn't have ffs, use the wrapper functions defined in bit_util.h
    string(REGEX REPLACE "#undef JEMALLOC_INTERNAL_FFS\n" "#define JEMALLOC_INTERNAL_FFS ffs_impl\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
    string(REGEX REPLACE "#undef JEMALLOC_INTERNAL_FFSL\n" "#define JEMALLOC_INTERNAL_FFSL ffsl_impl\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
    string(REGEX REPLACE "#undef JEMALLOC_INTERNAL_FFSLL\n" "#define JEMALLOC_INTERNAL_FFSLL ffsll_impl\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
else()
    # No ffs support - leave undefined, will cause compile error with helpful message
    message(WARNING "No ffs/ffsl/ffsll support detected - build may fail")
endif()

# Define JEMALLOC_HAVE_BUILTIN_CLZ if detected
if(JEMALLOC_HAVE_BUILTIN_CLZ)
    string(REGEX REPLACE "#undef JEMALLOC_HAVE_BUILTIN_CLZ\n" "#define JEMALLOC_HAVE_BUILTIN_CLZ 1\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")
endif()

# CRITICAL FIX: JEMALLOC_CONFIG_MALLOC_CONF must ALWAYS be defined as a string
# Even if empty, it must be "" not undefined, because jemalloc_preamble.h uses it directly
string(REGEX REPLACE "#undef JEMALLOC_CONFIG_MALLOC_CONF\n" "#define JEMALLOC_CONFIG_MALLOC_CONF \"${JEMALLOC_CONFIG_MALLOC_CONF}\"\n" INTERNAL_DEFS_CONTENT "${INTERNAL_DEFS_CONTENT}")

file(WRITE "${JEMALLOC_INTERNAL_INCLUDE_DIR}/jemalloc_internal_defs.h" "${INTERNAL_DEFS_CONTENT}")

configure_file(
    "${JEMALLOC_ROOT_DIR}/include/jemalloc/internal/jemalloc_preamble.h.in"
    "${JEMALLOC_INTERNAL_INCLUDE_DIR}/jemalloc_preamble.h"
    @ONLY
)

configure_file(
    "${JEMALLOC_ROOT_DIR}/include/jemalloc/jemalloc_macros.h.in"
    "${JEMALLOC_INCLUDE_DIR}/jemalloc/jemalloc_macros.h"
    @ONLY
)

# Post-process jemalloc_macros.h to define JEMALLOC_HAVE_ATTR if detected
if(JEMALLOC_HAVE_ATTR)
    file(READ "${JEMALLOC_INCLUDE_DIR}/jemalloc/jemalloc_macros.h" MACROS_CONTENT)
    # Add #define JEMALLOC_HAVE_ATTR 1 at the top after initial includes
    string(REGEX REPLACE "(#include <limits.h>)" "\\1\n#define JEMALLOC_HAVE_ATTR 1" MACROS_CONTENT "${MACROS_CONTENT}")
    file(WRITE "${JEMALLOC_INCLUDE_DIR}/jemalloc/jemalloc_macros.h" "${MACROS_CONTENT}")
endif()

configure_file(
    "${JEMALLOC_ROOT_DIR}/include/jemalloc/jemalloc_protos.h.in"
    "${JEMALLOC_INCLUDE_DIR}/jemalloc/jemalloc_protos.h"
    @ONLY
)

configure_file(
    "${JEMALLOC_ROOT_DIR}/include/jemalloc/jemalloc_typedefs.h.in"
    "${JEMALLOC_INCLUDE_DIR}/jemalloc/jemalloc_typedefs.h"
    @ONLY
)

# ============================================================================
# Generate jemalloc_rename.h (native CMake implementation of jemalloc_rename.sh)
# ============================================================================
set(RENAME_HEADER "/*
 * Name mangling for public symbols is controlled by --with-mangling and
 * --with-jemalloc-prefix.  With default settings the je_ prefix is stripped by
 * these macro definitions.
 */
#ifndef JEMALLOC_NO_RENAME\n")

foreach(sym ${PUBLIC_SYMS})
    set(RENAME_HEADER "${RENAME_HEADER}#  define je_${sym} ${je_}${sym}\n")
endforeach()

set(RENAME_HEADER "${RENAME_HEADER}#endif\n")
file(WRITE "${JEMALLOC_INCLUDE_DIR}/jemalloc/jemalloc_rename.h" "${RENAME_HEADER}")

# ============================================================================
# Generate jemalloc_mangle.h (native CMake implementation of jemalloc_mangle.sh)
# ============================================================================
set(MANGLE_HEADER "/*
 * By default application code must explicitly refer to mangled symbol names,
 * so that it is possible to use jemalloc in conjunction with another allocator
 * in the same application.  Define JEMALLOC_MANGLE in order to cause automatic
 * name mangling that matches the API prefixing that happened as a result of
 * --with-mangling and/or --with-jemalloc-prefix configuration settings.
 */
#ifdef JEMALLOC_MANGLE\n#  ifndef JEMALLOC_NO_DEMANGLE\n#    define JEMALLOC_NO_DEMANGLE\n#  endif\n")

foreach(sym ${PUBLIC_SYMS})
    set(MANGLE_HEADER "${MANGLE_HEADER}#  define ${sym} ${je_}${sym}\n")
endforeach()

set(MANGLE_HEADER "${MANGLE_HEADER}#endif\n\n/*
 * The ${je_}* macros can be used as stable alternative names for the
 * public jemalloc API if JEMALLOC_NO_DEMANGLE is defined.  This is primarily
 * meant for use in jemalloc itself, but it can be used by application code to
 * provide isolation from the name mangling specified via --with-mangling
 * and/or --with-jemalloc-prefix.
 */
#ifndef JEMALLOC_NO_DEMANGLE\n")

foreach(sym ${PUBLIC_SYMS})
    set(MANGLE_HEADER "${MANGLE_HEADER}#  undef ${je_}${sym}\n")
endforeach()

set(MANGLE_HEADER "${MANGLE_HEADER}#endif\n")
file(WRITE "${JEMALLOC_INCLUDE_DIR}/jemalloc/jemalloc_mangle.h" "${MANGLE_HEADER}")

# ============================================================================
# Generate public_namespace.h (native CMake implementation)
# ============================================================================
set(PUBLIC_NS_HEADER "")
foreach(sym ${PUBLIC_SYMS})
    set(PUBLIC_NS_HEADER "${PUBLIC_NS_HEADER}#define je_${sym} JEMALLOC_N(${sym})\n")
endforeach()
file(WRITE "${JEMALLOC_INTERNAL_INCLUDE_DIR}/public_namespace.h" "${PUBLIC_NS_HEADER}")

# ============================================================================
# Generate public_unnamespace.h (native CMake implementation)
# ============================================================================
set(PUBLIC_UNNS_HEADER "")
foreach(sym ${PUBLIC_SYMS})
    set(PUBLIC_UNNS_HEADER "${PUBLIC_UNNS_HEADER}#undef je_${sym}\n")
endforeach()
file(WRITE "${JEMALLOC_INTERNAL_INCLUDE_DIR}/public_unnamespace.h" "${PUBLIC_UNNS_HEADER}")

# ============================================================================
# Generate private_namespace.h (placeholder for now)
# The actual list would come from analyzing compiled object files
# ============================================================================
file(WRITE "${JEMALLOC_INTERNAL_INCLUDE_DIR}/private_namespace.h"
"/* Generated by CMake */
/* Private symbol namespace - would be generated from object file analysis */
")

# ============================================================================
# Generate main jemalloc.h (native CMake implementation of jemalloc.sh)
# ============================================================================
set(JEMALLOC_H_CONTENT
"#ifndef JEMALLOC_H_
#define JEMALLOC_H_
#ifdef __cplusplus
extern \"C\" {
#endif\n")

# Read and append each header (mimicking jemalloc.sh)
file(READ "${JEMALLOC_INCLUDE_DIR}/jemalloc/jemalloc_defs.h" DEFS_CONTENT)
file(READ "${JEMALLOC_INCLUDE_DIR}/jemalloc/jemalloc_rename.h" RENAME_CONTENT)
file(READ "${JEMALLOC_INCLUDE_DIR}/jemalloc/jemalloc_macros.h" MACROS_CONTENT)
file(READ "${JEMALLOC_INCLUDE_DIR}/jemalloc/jemalloc_protos.h" PROTOS_CONTENT)
file(READ "${JEMALLOC_INCLUDE_DIR}/jemalloc/jemalloc_typedefs.h" TYPEDEFS_CONTENT)
file(READ "${JEMALLOC_INCLUDE_DIR}/jemalloc/jemalloc_mangle.h" MANGLE_CONTENT)

set(JEMALLOC_H_CONTENT "${JEMALLOC_H_CONTENT}${DEFS_CONTENT}\n")
set(JEMALLOC_H_CONTENT "${JEMALLOC_H_CONTENT}${RENAME_CONTENT}\n")
set(JEMALLOC_H_CONTENT "${JEMALLOC_H_CONTENT}${MACROS_CONTENT}\n")
set(JEMALLOC_H_CONTENT "${JEMALLOC_H_CONTENT}${PROTOS_CONTENT}\n")
set(JEMALLOC_H_CONTENT "${JEMALLOC_H_CONTENT}${TYPEDEFS_CONTENT}\n")
set(JEMALLOC_H_CONTENT "${JEMALLOC_H_CONTENT}${MANGLE_CONTENT}\n")

set(JEMALLOC_H_CONTENT "${JEMALLOC_H_CONTENT}
#ifdef __cplusplus
}
#endif
#endif /* JEMALLOC_H_ */
")

file(WRITE "${JEMALLOC_INCLUDE_DIR}/jemalloc/jemalloc${install_suffix}.h" "${JEMALLOC_H_CONTENT}")

# Also create jemalloc.h without suffix
if(NOT install_suffix)
    file(WRITE "${JEMALLOC_INCLUDE_DIR}/jemalloc/jemalloc.h" "${JEMALLOC_H_CONTENT}")
endif()

# Export include directory to parent scope
set(JEMALLOC_GENERATED_INCLUDE_DIR "${JEMALLOC_INCLUDE_DIR}" PARENT_SCOPE)
set(JEMALLOC_GENERATED_INCLUDE_DIR "${JEMALLOC_INCLUDE_DIR}")

# Debug output for Windows platforms
if(WIN32)
    message(STATUS "")
    message(STATUS "=== Windows Header Generation Debug ===")
    message(STATUS "WIN32: ${WIN32}")
    message(STATUS "MINGW: ${MINGW}")
    message(STATUS "MSVC: ${MSVC}")
    message(STATUS "CMAKE_C_COMPILER_ID: ${CMAKE_C_COMPILER_ID}")
    message(STATUS "JEMALLOC_HAVE_ATTR: ${JEMALLOC_HAVE_ATTR}")
    message(STATUS "JEMALLOC_TLS: ${JEMALLOC_TLS}")
    message(STATUS "JEMALLOC_PLATFORM: ${JEMALLOC_PLATFORM}")

    # Check if JEMALLOC_HAVE_ATTR was defined in jemalloc_macros.h
    if(EXISTS "${JEMALLOC_INCLUDE_DIR}/jemalloc/jemalloc_macros.h")
        file(READ "${JEMALLOC_INCLUDE_DIR}/jemalloc/jemalloc_macros.h" MACROS_CHECK)
        if(MACROS_CHECK MATCHES "JEMALLOC_HAVE_ATTR")
            message(STATUS "JEMALLOC_HAVE_ATTR FOUND in jemalloc_macros.h")
        else()
            message(STATUS "JEMALLOC_HAVE_ATTR NOT FOUND in jemalloc_macros.h")
        endif()
        if(MACROS_CHECK MATCHES "#define JEMALLOC_ATTR")
            message(STATUS "JEMALLOC_ATTR definition found")
        endif()
        if(MACROS_CHECK MATCHES "#define JEMALLOC_SECTION")
            message(STATUS "JEMALLOC_SECTION definition found")
        endif()
    endif()
    message(STATUS "======================================")
    message(STATUS "")
endif()

message(STATUS "")
message(STATUS "Native CMake Header Generation Complete:")
message(STATUS "  Generated in: ${JEMALLOC_INCLUDE_DIR}")
message(STATUS "  Build directory: ${CMAKE_BINARY_DIR}")
message(STATUS "  - jemalloc_defs.h")
message(STATUS "  - jemalloc_internal_defs.h")
message(STATUS "  - jemalloc_preamble.h (CRITICAL)")
message(STATUS "  - jemalloc_macros.h")
message(STATUS "  - jemalloc_protos.h")
message(STATUS "  - jemalloc_typedefs.h")
message(STATUS "  - jemalloc_rename.h (native CMake)")
message(STATUS "  - jemalloc_mangle.h (native CMake)")
message(STATUS "  - public_namespace.h (native CMake)")
message(STATUS "  - public_unnamespace.h (native CMake)")
message(STATUS "  - jemalloc${install_suffix}.h (combined)")
message(STATUS "")
