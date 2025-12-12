# Common.cmake
# Common platform and compiler settings

# Function to apply common platform-specific settings to a target
function(jemalloc_configure_common_target target)
    # C standard (matching autotools: prefer C11, fallback to C99 with GNU extensions)
    set_target_properties(${target} PROPERTIES
        C_STANDARD 11
        C_STANDARD_REQUIRED ON
        C_EXTENSIONS ON  # GNU extensions enabled (std=gnu11)
    )

    # C++ standard (matching autotools configure.ac:331-334)
    # Prefer C++17 (for aligned_new), fallback to C++14 (for sized deallocation)
    # autotools: AX_CXX_COMPILE_STDCXX([17], [noext], [optional])
    set_target_properties(${target} PROPERTIES
        CXX_STANDARD 17
        CXX_STANDARD_REQUIRED OFF  # Allow fallback to C++14
    )

    # Check if C++17+ is not available, try C++14
    if(NOT CMAKE_CXX_STANDARD OR CMAKE_CXX_STANDARD LESS 14)
        set_target_properties(${target} PROPERTIES
            CXX_STANDARD 14
            CXX_STANDARD_REQUIRED ON
        )
    endif()

    # Suppress -Wundef for C++ feature test macros in jemalloc_cpp.cpp
    # These macros (__cpp_sized_deallocation, __cpp_aligned_new) may not be
    # defined if compiler doesn't fully support C++14/17
    get_target_property(target_sources ${target} SOURCES)
    foreach(source ${target_sources})
        if(source MATCHES "jemalloc_cpp\\.cpp$")
            set_source_files_properties(${source} PROPERTIES
                COMPILE_FLAGS "-Wno-undef"
            )
        endif()
    endforeach()

    # macOS-specific
    if(APPLE)
        target_compile_definitions(${target} PRIVATE
            _DARWIN_C_SOURCE
        )

        # Deployment target
        if(NOT CMAKE_OSX_DEPLOYMENT_TARGET)
            set(CMAKE_OSX_DEPLOYMENT_TARGET "10.13" PARENT_SCOPE)
        endif()
    endif()

    # Linux-specific
    if(JEMALLOC_IS_LINUX)
        target_compile_definitions(${target} PRIVATE
            _GNU_SOURCE
            _REENTRANT
        )
    endif()
endfunction()