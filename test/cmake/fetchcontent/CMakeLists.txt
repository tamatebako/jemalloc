cmake_minimum_required(VERSION 3.24)
project(test_fetchcontent C)

include(FetchContent)

# Test FetchContent integration
# For local testing, use SOURCE_DIR pointing to jemalloc root
# In production, users would use GIT_REPOSITORY instead
FetchContent_Declare(
    jemalloc
    SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../..
    # For production use:
    # GIT_REPOSITORY https://github.com/tamatebako/jemalloc.git
    # GIT_TAG main
)

FetchContent_MakeAvailable(jemalloc)

# Verify variables were populated
message(STATUS "JEMALLOC_INCLUDE_DIRS: ${JEMALLOC_INCLUDE_DIRS}")
message(STATUS "JEMALLOC_LIBRARIES: ${JEMALLOC_LIBRARIES}")

add_executable(test_app main.c)
target_link_libraries(test_app PRIVATE jemalloc::jemalloc)

# Verify target exists
if(TARGET jemalloc::jemalloc)
    message(STATUS "jemalloc::jemalloc target exists")
    get_target_property(JEMALLOC_INCLUDE jemalloc::jemalloc INTERFACE_INCLUDE_DIRECTORIES)
    message(STATUS "jemalloc include: ${JEMALLOC_INCLUDE}")
else()
    message(FATAL_ERROR "jemalloc::jemalloc target not found")
endif()

# Test that we can compile and link
enable_testing()
add_test(NAME jemalloc_fetchcontent_test COMMAND test_app)
