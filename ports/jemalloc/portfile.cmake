# For overlay port testing, use the local repository source
# CURRENT_PORT_DIR is ports/jemalloc/, so ../.. goes to repository root
get_filename_component(SOURCE_PATH "${CURRENT_PORT_DIR}/../.." ABSOLUTE)

# Determine build type based on linkage
if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    set(BUILD_SHARED ON)
    set(BUILD_STATIC OFF)
else()
    set(BUILD_SHARED OFF)
    set(BUILD_STATIC ON)
endif()

# Native CMake build on all platforms (Windows, Linux, macOS, FreeBSD)
# No more MSBuild workaround - native CMake works everywhere!
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DJEMALLOC_BUILD_SHARED=${BUILD_SHARED}
        -DJEMALLOC_BUILD_STATIC=${BUILD_STATIC}
        -DJEMALLOC_ENABLE_DOC=OFF
        -DJEMALLOC_ENABLE_PROF=OFF
        -DJEMALLOC_ENABLE_STATS=ON
)

vcpkg_cmake_install()

# Fix CMake config file paths
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/jemalloc)

# Copy PDB files (Windows only)
vcpkg_copy_pdbs()

# Remove duplicate files
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

# Install copyright
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
