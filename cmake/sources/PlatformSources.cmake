# PlatformSources.cmake
# Platform-specific source file selection

# Start with core sources
include(${CMAKE_CURRENT_LIST_DIR}/CoreSources.cmake)

set(JEMALLOC_SOURCES ${JEMALLOC_CORE_SOURCES})

# Add zone allocator sources for macOS
if(JEMALLOC_ZONE)
    list(APPEND JEMALLOC_SOURCES ${JEMALLOC_ZONE_SOURCES})
endif()

# Add C++ support if enabled
if(JEMALLOC_ENABLE_CXX)
    list(APPEND JEMALLOC_SOURCES ${JEMALLOC_CXX_SOURCES})
endif()

# Export to parent scope
set(JEMALLOC_SOURCES "${JEMALLOC_SOURCES}")

list(LENGTH JEMALLOC_SOURCES JEMALLOC_SOURCE_COUNT)
message(STATUS "Total source files: ${JEMALLOC_SOURCE_COUNT}")