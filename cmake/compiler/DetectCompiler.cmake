# DetectCompiler.cmake
# Compiler detection and selection of appropriate configuration

# Detect compiler - MECE (Mutually Exclusive, Collectively Exhaustive)
if(MSVC)
    set(JEMALLOC_COMPILER "msvc")
    include(${CMAKE_CURRENT_LIST_DIR}/MSVC.cmake)
elseif(CMAKE_C_COMPILER_ID MATCHES "Clang")
    set(JEMALLOC_COMPILER "clang")
    include(${CMAKE_CURRENT_LIST_DIR}/Clang.cmake)
elseif(CMAKE_C_COMPILER_ID MATCHES "GNU")
    set(JEMALLOC_COMPILER "gcc")
    include(${CMAKE_CURRENT_LIST_DIR}/GCC.cmake)
elseif(CMAKE_C_COMPILER_ID MATCHES "Intel")
    set(JEMALLOC_COMPILER "icc")
    message(STATUS "Intel compiler detected - using GCC-like settings")
    include(${CMAKE_CURRENT_LIST_DIR}/GCC.cmake)
else()
    set(JEMALLOC_COMPILER "unknown")
    message(WARNING "Unknown compiler ${CMAKE_C_COMPILER_ID}, using default settings")
endif()

# Include common compiler settings
include(${CMAKE_CURRENT_LIST_DIR}/Common.cmake)

# Export compiler type to parent scope
set(JEMALLOC_COMPILER "${JEMALLOC_COMPILER}")

message(STATUS "Compiler: ${JEMALLOC_COMPILER}")
