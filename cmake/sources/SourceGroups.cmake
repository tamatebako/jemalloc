# SourceGroups.cmake
# Organize source files for IDEs (Visual Studio, Xcode, etc.)

# Group core source files
source_group("Source Files\\Core" REGULAR_EXPRESSION "src/.*\\.c$")

# Group C++ sources
source_group("Source Files\\C++" FILES ${JEMALLOC_CXX_SOURCES})

# Group profiling sources
if(JEMALLOC_ENABLE_PROF)
    source_group("Source Files\\Profiling" FILES ${JEMALLOC_PROF_SOURCES})
endif()

# Group zone allocator sources (macOS)
if(JEMALLOC_ZONE)
    source_group("Source Files\\Zone" FILES ${JEMALLOC_ZONE_SOURCES})
endif()

# Group public headers
source_group("Header Files\\Public"
    REGULAR_EXPRESSION "include/jemalloc/[^/]+\\.h$"
)

# Group internal headers by category
source_group("Header Files\\Internal\\Arena"
    REGULAR_EXPRESSION "include/jemalloc/internal/arena.*\\.h$"
)

source_group("Header Files\\Internal\\Atomics"
    REGULAR_EXPRESSION "include/jemalloc/internal/atomic.*\\.h$"
)

source_group("Header Files\\Internal\\Profiling"
    REGULAR_EXPRESSION "include/jemalloc/internal/prof.*\\.h$"
)

source_group("Header Files\\Internal\\Other"
    REGULAR_EXPRESSION "include/jemalloc/internal/[^/]+\\.h$"
)

# Group generated headers
source_group("Header Files\\Generated"
    FILES
        ${JEMALLOC_GENERATED_INCLUDE_DIR}/jemalloc/jemalloc_defs.h
        ${JEMALLOC_GENERATED_INCLUDE_DIR}/jemalloc/internal/jemalloc_internal_defs.h
)
