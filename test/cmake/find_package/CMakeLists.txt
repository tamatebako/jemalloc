cmake_minimum_required(VERSION 3.24)
project(test_find_package C)

# Test installed find_package()
find_package(jemalloc CONFIG REQUIRED)

# Verify version was set
message(STATUS "Found jemalloc version: ${jemalloc_VERSION}")

add_executable(test_app main.c)
target_link_libraries(test_app PRIVATE jemalloc::jemalloc)

# Verify target exists and properties are set
get_target_property(JEMALLOC_INCLUDE jemalloc::jemalloc INTERFACE_INCLUDE_DIRECTORIES)
get_target_property(JEMALLOC_LOCATION jemalloc::jemalloc IMPORTED_LOCATION)
message(STATUS "jemalloc include: ${JEMALLOC_INCLUDE}")
message(STATUS "jemalloc library: ${JEMALLOC_LOCATION}")

# Test that we can compile and link
enable_testing()
add_test(NAME jemalloc_find_package_test COMMAND test_app)
