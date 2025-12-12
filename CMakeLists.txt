cmake_minimum_required(VERSION 3.24)

# ============================================================================
# Native CMake Build System for jemalloc
# Replaces autotools wrapper - enables pure CMake builds on all platforms
# ============================================================================

# Version detection (from VERSION file or git)
include(cmake/config/GenerateVersion.cmake)

# Project declaration
project(jemalloc
    VERSION ${JEMALLOC_VERSION}
    DESCRIPTION "General purpose malloc implementation"
    LANGUAGES C CXX
)

# ============================================================================
# Options
# ============================================================================

option(JEMALLOC_BUILD_SHARED "Build shared library" ON)
option(JEMALLOC_BUILD_STATIC "Build static library" ON)
option(JEMALLOC_ENABLE_PROF "Enable heap profiling" OFF)
option(JEMALLOC_ENABLE_STATS "Enable statistics" ON)
option(JEMALLOC_ENABLE_CXX "Enable C++ integration" ON)
option(JEMALLOC_ENABLE_DOC "Enable documentation" OFF)

# ============================================================================
# Platform and Compiler Detection
# ============================================================================

include(cmake/platform/DetectPlatform.cmake)
include(cmake/compiler/DetectCompiler.cmake)

# ============================================================================
# Feature Detection
# ============================================================================

include(cmake/checks/CompilerFeatures.cmake)
include(cmake/checks/SystemHeaders.cmake)
include(cmake/checks/MemoryFeatures.cmake)
include(cmake/checks/ThreadSupport.cmake)

# ============================================================================
# Platform-Specific Configuration
# ============================================================================

if(JEMALLOC_PLATFORM STREQUAL "windows")
    include(cmake/platform/Windows.cmake)
elseif(JEMALLOC_PLATFORM STREQUAL "linux")
    include(cmake/platform/Linux.cmake)
elseif(JEMALLOC_PLATFORM STREQUAL "darwin")
    include(cmake/platform/Darwin.cmake)
elseif(JEMALLOC_PLATFORM STREQUAL "freebsd")
    include(cmake/platform/FreeBSD.cmake)
else()
    include(cmake/platform/Unix.cmake)
endif()

# ============================================================================
# Configure and Generate Headers
# ============================================================================

include(cmake/config/GenerateHeaders.cmake)

# ============================================================================
# Source Organization
# ============================================================================

include(cmake/sources/PlatformSources.cmake)
include(cmake/sources/SourceGroups.cmake)

# ============================================================================
# Library Targets
# ============================================================================

# Static library
if(JEMALLOC_BUILD_STATIC)
    add_library(jemalloc_static STATIC ${JEMALLOC_SOURCES})

    set_target_properties(jemalloc_static PROPERTIES
        OUTPUT_NAME jemalloc
        VERSION ${JEMALLOC_VERSION}
    )

    # Configure the target
    jemalloc_configure_common_target(jemalloc_static)

    # Include directories
    target_include_directories(jemalloc_static
        PUBLIC
            $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
            $<BUILD_INTERFACE:${JEMALLOC_GENERATED_INCLUDE_DIR}>
            $<INSTALL_INTERFACE:include>
        PRIVATE
            ${PROJECT_SOURCE_DIR}/src
    )

    # Compile definitions
    target_compile_definitions(jemalloc_static PRIVATE
        JEMALLOC_DEBUG=$<CONFIG:Debug>
        $<$<BOOL:${JEMALLOC_ENABLE_PROF}>:JEMALLOC_PROF>
        $<$<BOOL:${JEMALLOC_ENABLE_STATS}>:JEMALLOC_STATS>
        ${JEMALLOC_PLATFORM_DEFINITIONS}
    )

    # Windows static library - define JEMALLOC_STATIC to avoid dllimport
    if(WIN32)
        target_compile_definitions(jemalloc_static PUBLIC JEMALLOC_STATIC)
    endif()

    # Platform compile options
    if(JEMALLOC_PLATFORM_COMPILE_OPTIONS)
        target_compile_options(jemalloc_static PRIVATE ${JEMALLOC_PLATFORM_COMPILE_OPTIONS})
    endif()

    # Platform libraries
    if(JEMALLOC_PLATFORM_LIBS)
        target_link_libraries(jemalloc_static PRIVATE ${JEMALLOC_PLATFORM_LIBS})
    endif()
endif()

# Shared library
if(JEMALLOC_BUILD_SHARED)
    add_library(jemalloc_shared SHARED ${JEMALLOC_SOURCES})

    set_target_properties(jemalloc_shared PROPERTIES
        OUTPUT_NAME jemalloc
        VERSION ${JEMALLOC_VERSION}
        SOVERSION ${JEMALLOC_VERSION_MAJOR}
    )

    # Configure the target
    jemalloc_configure_common_target(jemalloc_shared)

    # Include directories
    target_include_directories(jemalloc_shared
        PUBLIC
            $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
            $<BUILD_INTERFACE:${JEMALLOC_GENERATED_INCLUDE_DIR}>
            $<INSTALL_INTERFACE:include>
        PRIVATE
            ${PROJECT_SOURCE_DIR}/src
    )

    # Compile definitions
    target_compile_definitions(jemalloc_shared PRIVATE
        JEMALLOC_DEBUG=$<CONFIG:Debug>
        $<$<BOOL:${JEMALLOC_ENABLE_PROF}>:JEMALLOC_PROF>
        $<$<BOOL:${JEMALLOC_ENABLE_STATS}>:JEMALLOC_STATS>
        ${JEMALLOC_PLATFORM_DEFINITIONS}
    )

    # Platform compile options
    if(JEMALLOC_PLATFORM_COMPILE_OPTIONS)
        target_compile_options(jemalloc_shared PRIVATE ${JEMALLOC_PLATFORM_COMPILE_OPTIONS})
    endif()

    # Windows DLL export/import
    if(WIN32)
        target_compile_definitions(jemalloc_shared
            PRIVATE DLLEXPORT
        )
    endif()

    # Platform libraries
    if(JEMALLOC_PLATFORM_LIBS)
        target_link_libraries(jemalloc_shared PRIVATE ${JEMALLOC_PLATFORM_LIBS})
    endif()
endif()

# ============================================================================
# Alias Targets
# ============================================================================

# Create jemalloc::jemalloc alias (prefer static if both enabled)
if(JEMALLOC_BUILD_STATIC)
    add_library(jemalloc::jemalloc ALIAS jemalloc_static)
    set(JEMALLOC_MAIN_TARGET jemalloc_static)
elseif(JEMALLOC_BUILD_SHARED)
    add_library(jemalloc::jemalloc ALIAS jemalloc_shared)
    set(JEMALLOC_MAIN_TARGET jemalloc_shared)
endif()

# ============================================================================
# Installation
# ============================================================================

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    # Only install if this is the top-level project
    include(cmake/install/Targets.cmake)
    include(cmake/install/CMakeConfig.cmake)
endif()

# ============================================================================
# Testing
# ============================================================================

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR AND BUILD_TESTING)
    enable_testing()
    # Testing infrastructure will be added in Phase 7
    # add_subdirectory(test)
endif()

# ============================================================================
# Configuration Summary
# ============================================================================

message(STATUS "")
message(STATUS "========================================")
message(STATUS "jemalloc ${JEMALLOC_VERSION} - Native CMake Build")
message(STATUS "========================================")
message(STATUS "Platform:        ${JEMALLOC_PLATFORM}")
message(STATUS "Compiler:        ${JEMALLOC_COMPILER}")
message(STATUS "Build type:      ${CMAKE_BUILD_TYPE}")
message(STATUS "Build shared:    ${JEMALLOC_BUILD_SHARED}")
message(STATUS "Build static:    ${JEMALLOC_BUILD_STATIC}")
message(STATUS "Enable prof:     ${JEMALLOC_ENABLE_PROF}")
message(STATUS "Enable stats:    ${JEMALLOC_ENABLE_STATS}")
message(STATUS "Enable C++:      ${JEMALLOC_ENABLE_CXX}")
message(STATUS "Install prefix:  ${CMAKE_INSTALL_PREFIX}")
message(STATUS "========================================")
message(STATUS "")
