# CMakeConfig.cmake
# Generate and install CMake package configuration files

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# Create package configuration file from template
configure_package_config_file(
    ${CMAKE_SOURCE_DIR}/cmake/JemallocConfig.cmake.in
    ${CMAKE_BINARY_DIR}/jemallocConfig.cmake
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/jemalloc
    PATH_VARS
        CMAKE_INSTALL_INCLUDEDIR
        CMAKE_INSTALL_LIBDIR
)

# Create package version file
write_basic_package_version_file(
    ${CMAKE_BINARY_DIR}/jemallocConfigVersion.cmake
    VERSION ${JEMALLOC_VERSION}
    COMPATIBILITY SameMajorVersion
)

# Install package configuration files
install(
    FILES
        ${CMAKE_BINARY_DIR}/jemallocConfig.cmake
        ${CMAKE_BINARY_DIR}/jemallocConfigVersion.cmake
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/jemalloc
    COMPONENT Development
)

# Install pkg-config file if it exists
if(EXISTS ${CMAKE_SOURCE_DIR}/jemalloc.pc.in)
    configure_file(
        ${CMAKE_SOURCE_DIR}/jemalloc.pc.in
        ${CMAKE_BINARY_DIR}/jemalloc.pc
        @ONLY
    )
    install(
        FILES ${CMAKE_BINARY_DIR}/jemalloc.pc
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig
        COMPONENT Development
    )
endif()