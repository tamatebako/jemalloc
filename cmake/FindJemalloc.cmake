# FindJemalloc.cmake
# ------------------
#
# Find jemalloc library
#
# This module defines the following variables:
#   Jemalloc_FOUND          - True if jemalloc library is found
#   Jemalloc_INCLUDE_DIRS   - Include directories for jemalloc
#   Jemalloc_LIBRARIES      - Libraries to link against
#   Jemalloc_VERSION        - Version string (if available)
#   Jemalloc_VERSION_MAJOR  - Major version number
#   Jemalloc_VERSION_MINOR  - Minor version number
#   Jemalloc_VERSION_PATCH  - Patch version number
#
# This module defines the following imported target:
#   Jemalloc::jemalloc      - The jemalloc library (if found)
#
# You can set the following variables to help locate jemalloc:
#   JEMALLOC_ROOT_DIR       - Root directory of jemalloc installation
#   JEMALLOC_INCLUDE_DIR    - Directory containing jemalloc/jemalloc.h
#   JEMALLOC_LIBRARY        - Path to jemalloc library

# Use pkg-config if available
find_package(PkgConfig QUIET)
if(PKG_CONFIG_FOUND)
    pkg_check_modules(PC_Jemalloc QUIET jemalloc)
    set(Jemalloc_VERSION ${PC_Jemalloc_VERSION})
endif()

# Find include directory
find_path(Jemalloc_INCLUDE_DIR
    NAMES jemalloc/jemalloc.h
    HINTS
        ${JEMALLOC_ROOT_DIR}
        ${PC_Jemalloc_INCLUDE_DIRS}
        ENV JEMALLOC_ROOT
    PATH_SUFFIXES include
    DOC "jemalloc include directory"
)

# Find library
find_library(Jemalloc_LIBRARY
    NAMES jemalloc libjemalloc
    HINTS
        ${JEMALLOC_ROOT_DIR}
        ${PC_Jemalloc_LIBRARY_DIRS}
        ENV JEMALLOC_ROOT
    PATH_SUFFIXES lib lib64
    DOC "jemalloc library"
)

# Try to extract version from header if not found via pkg-config
if(Jemalloc_INCLUDE_DIR AND NOT Jemalloc_VERSION)
    if(EXISTS "${Jemalloc_INCLUDE_DIR}/jemalloc/jemalloc.h")
        file(READ "${Jemalloc_INCLUDE_DIR}/jemalloc/jemalloc.h" _jemalloc_header)

        # Extract version components
        string(REGEX MATCH "#define[ \t]+JEMALLOC_VERSION[ \t]+\"([0-9]+)\\.([0-9]+)\\.([0-9]+)"
            _jemalloc_version_match "${_jemalloc_header}")

        if(_jemalloc_version_match)
            set(Jemalloc_VERSION_MAJOR "${CMAKE_MATCH_1}")
            set(Jemalloc_VERSION_MINOR "${CMAKE_MATCH_2}")
            set(Jemalloc_VERSION_PATCH "${CMAKE_MATCH_3}")
            set(Jemalloc_VERSION "${Jemalloc_VERSION_MAJOR}.${Jemalloc_VERSION_MINOR}.${Jemalloc_VERSION_PATCH}")
        endif()

        unset(_jemalloc_header)
        unset(_jemalloc_version_match)
    endif()
endif()

# Handle standard arguments
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Jemalloc
    REQUIRED_VARS
        Jemalloc_LIBRARY
        Jemalloc_INCLUDE_DIR
    VERSION_VAR
        Jemalloc_VERSION
)

# Set output variables
if(Jemalloc_FOUND)
    set(Jemalloc_LIBRARIES ${Jemalloc_LIBRARY})
    set(Jemalloc_INCLUDE_DIRS ${Jemalloc_INCLUDE_DIR})

    # Create imported target if not already exists (lowercase namespace)
    if(NOT TARGET jemalloc::jemalloc)
        add_library(jemalloc::jemalloc UNKNOWN IMPORTED)
        set_target_properties(jemalloc::jemalloc PROPERTIES
            IMPORTED_LOCATION "${Jemalloc_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${Jemalloc_INCLUDE_DIR}"
        )

        # Add pthread dependency on Unix systems
        if(UNIX AND NOT APPLE)
            find_package(Threads REQUIRED)
            set_property(TARGET jemalloc::jemalloc APPEND PROPERTY
                INTERFACE_LINK_LIBRARIES Threads::Threads
            )
        endif()
    endif()

    mark_as_advanced(
        Jemalloc_INCLUDE_DIR
        Jemalloc_LIBRARY
    )
endif()
