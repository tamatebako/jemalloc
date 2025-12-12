# GCC.cmake
# GNU GCC compiler settings

# Function to apply GCC settings to a target
function(jemalloc_configure_gcc_target target)
    # Warning flags (matching autotools configure.ac behavior)
    target_compile_options(${target} PRIVATE
        -Wall
        -Wextra
        -Wsign-compare
        -Wundef
        -Wno-format-zero-length
        -Wpointer-arith
        -Wno-missing-braces           # From configure.ac line 287
        -Wno-missing-field-initializers  # From configure.ac line 289
        -pipe
    )

    # Only add -Werror for specific warnings (like autotools does)
    # DO NOT use blanket -Werror as it's too strict

    # Additional useful warnings
    target_compile_options(${target} PRIVATE
        -Wstrict-prototypes
        -Wmissing-prototypes
        -Wwrite-strings
    )

    # Optimization flags
    target_compile_options(${target} PRIVATE
        $<$<CONFIG:Release>:-O3 -funroll-loops>
        $<$<CONFIG:RelWithDebInfo>:-O2 -g3>
        $<$<CONFIG:MinSizeRel>:-Os>
        $<$<CONFIG:Debug>:-O0 -g3>
    )

    # Debug flags (matching autotools)
    target_compile_options(${target} PRIVATE
        $<$<CONFIG:Debug>:-g3>  # Maximum debug info
    )

    # Position independent code (required for shared libraries)
    set_target_properties(${target} PROPERTIES
        POSITION_INDEPENDENT_CODE ON
    )

    # Link time optimization for release builds
    if(CMAKE_BUILD_TYPE MATCHES "Release")
        set_target_properties(${target} PROPERTIES
            INTERPROCEDURAL_OPTIMIZATION TRUE
        )
    endif()

    # Function sections for better dead code elimination
    target_compile_options(${target} PRIVATE
        -ffunction-sections
        -fdata-sections
    )

    # Linker flags for garbage collection
    if(NOT APPLE)  # macOS doesn't support --gc-sections
        target_link_options(${target} PRIVATE
            $<$<CONFIG:Release>:-Wl,--gc-sections>
        )
    endif()

    # Visibility (autotools uses -fvisibility=hidden for GCC on ELF systems)
    if(NOT WIN32 AND NOT APPLE)
        target_compile_options(${target} PRIVATE
            -fvisibility=hidden
        )
    endif()

    # GCC-specific optimizations (optional, only for native builds)
    if(NOT CMAKE_CROSSCOMPILING AND CMAKE_BUILD_TYPE MATCHES "Release")
        # Note: -march=native is NOT used by autotools by default
        # Uncomment if needed for specific deployments
        # target_compile_options(${target} PRIVATE -march=native)
    endif()
endfunction()
