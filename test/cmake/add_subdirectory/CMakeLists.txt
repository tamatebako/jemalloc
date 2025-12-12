cmake_minimum_required(VERSION 3.24)
project(test_add_subdirectory C)

# Test add_subdirectory() integration
# Point to jemalloc root (three directories up from here)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../../.. ${CMAKE_CURRENT_BINARY_DIR}/jemalloc_build)

# Verify variables were exported
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
add_test(NAME jemalloc_add_subdirectory_test COMMAND test_app)
