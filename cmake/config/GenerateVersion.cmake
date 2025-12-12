# GenerateVersion.cmake
# Extract version information from VERSION file or git

# Get jemalloc root directory (works with add_subdirectory too)
get_filename_component(JEMALLOC_ROOT_DIR "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

# Try to read VERSION file first
if(EXISTS "${JEMALLOC_ROOT_DIR}/VERSION")
    file(STRINGS "${JEMALLOC_ROOT_DIR}/VERSION" JEMALLOC_VERSION_RAW)
    string(REGEX MATCH "^([0-9]+)\\.([0-9]+)\\.([0-9]+)" JEMALLOC_VERSION_MATCH "${JEMALLOC_VERSION_RAW}")

    if(JEMALLOC_VERSION_MATCH)
        set(JEMALLOC_VERSION_MAJOR "${CMAKE_MATCH_1}")
        set(JEMALLOC_VERSION_MINOR "${CMAKE_MATCH_2}")
        set(JEMALLOC_VERSION_PATCH "${CMAKE_MATCH_3}")
        set(JEMALLOC_VERSION "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${CMAKE_MATCH_3}")

        message(STATUS "jemalloc version from VERSION file: ${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${CMAKE_MATCH_3}")
        return()
    endif()
endif()

# Fall back to git if VERSION file not found or invalid
message(STATUS "VERSION file not found or invalid, attempting to extract from git")

execute_process(
    COMMAND git describe --tags --abbrev=0
    WORKING_DIRECTORY "${JEMALLOC_ROOT_DIR}"
    OUTPUT_VARIABLE GIT_TAG
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
    RESULT_VARIABLE GIT_RESULT
)

if(GIT_RESULT EQUAL 0 AND GIT_TAG)
    # Strip leading 'v' if present
    string(REGEX REPLACE "^v" "" VERSION_STRING "${GIT_TAG}")
    string(REGEX MATCH "^([0-9]+)\\.([0-9]+)\\.([0-9]+)" VERSION_MATCH "${VERSION_STRING}")

    if(VERSION_MATCH)
        set(JEMALLOC_VERSION_MAJOR "${CMAKE_MATCH_1}")
        set(JEMALLOC_VERSION_MINOR "${CMAKE_MATCH_2}")
        set(JEMALLOC_VERSION_PATCH "${CMAKE_MATCH_3}")
        set(JEMALLOC_VERSION "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${CMAKE_MATCH_3}")

        message(STATUS "jemalloc version from git: ${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${CMAKE_MATCH_3}")

        # Generate VERSION file for future builds
        file(WRITE "${JEMALLOC_ROOT_DIR}/VERSION" "${VERSION_STRING}-0-g0000000000000000000000000000000000000000\n")
        return()
    endif()
endif()

# Final fallback to known version
message(WARNING "Could not determine version from VERSION file or git, using fallback version 5.5.0")
set(JEMALLOC_VERSION_MAJOR "5")
set(JEMALLOC_VERSION_MINOR "5")
set(JEMALLOC_VERSION_PATCH "0")
set(JEMALLOC_VERSION "5.5.0")
