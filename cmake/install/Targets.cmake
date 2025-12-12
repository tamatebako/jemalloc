# Targets.cmake
# Install library targets, headers, and exports

include(GNUInstallDirs)

# Collect targets to install
set(JEMALLOC_INSTALL_TARGETS)
if(JEMALLOC_BUILD_STATIC)
    list(APPEND JEMALLOC_INSTALL_TARGETS jemalloc_static)
endif()
if(JEMALLOC_BUILD_SHARED)
    list(APPEND JEMALLOC_INSTALL_TARGETS jemalloc_shared)
endif()

# Install library targets
install(TARGETS ${JEMALLOC_INSTALL_TARGETS}
    EXPORT JemallocTargets
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        COMPONENT Runtime
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        COMPONENT Runtime
        NAMELINK_COMPONENT Development
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        COMPONENT Development
)

# Install public headers
install(DIRECTORY ${CMAKE_SOURCE_DIR}/include/jemalloc
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    COMPONENT Development
    FILES_MATCHING PATTERN "*.h"
    PATTERN "*.in" EXCLUDE
)

# Install generated headers
install(DIRECTORY ${JEMALLOC_GENERATED_INCLUDE_DIR}/jemalloc
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    COMPONENT Development
    FILES_MATCHING PATTERN "*.h"
)

# Install export file
install(EXPORT JemallocTargets
    FILE JemallocTargets.cmake
    NAMESPACE jemalloc::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/jemalloc
    COMPONENT Development
)

message(STATUS "Installation configured for ${CMAKE_INSTALL_PREFIX}")