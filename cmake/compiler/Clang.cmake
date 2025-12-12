# Clang.cmake
# Clang/LLVM compiler settings

# Function to apply Clang settings to a target
function(jemalloc_configure_clang_target target)
    # Warning flags - Match autotools configure.ac behavior
    target_compile_options(${target} PRIVATE
        -Wall
        -Wextra
        -Wshorten-64-to-32
        -Wsign-compare
        -Wundef
        -Wno-format-zero-length
        -Wpointer-arith
        -Wno-missing-braces           # From configure.ac line 287
        -Wno-missing-field-initializers  # From configure.ac line 289
        -pipe
    )

    # Suppress unknown warning options
    target_compile_options(${target} PRIVATE
        -Wno-unknown-warning-option
    )

    # Clang-specific
    target_compile_options(${target} PRIVATE
        -Wno-ignored-attributes
    )

    # macOS-specific warning suppressions
    if(APPLE)
        target_compile_options(${target} PRIVATE
            -Wno-deprecated-declarations
        )
    endif()

    # Optimization flags
    target_compile_options(${target} PRIVATE
        $<$<CONFIG:Release>:-O3 -funroll-loops>
        $<$<CONFIG:RelWithDebInfo>:-O2 -g3>
        $<$<CONFIG:MinSizeRel>:-Oz>  # Clang's -Oz is more aggressive than -Os
        $<$<CONFIG:Debug>:-O0 -g3>
    )

    # Debug flags (matching autotools)
    target_compile_options(${target} PRIVATE
        $<$<CONFIG:Debug>:-g3>  # Maximum debug info
    )

    # Position independent code
    set_target_properties(${target} PROPERTIES
        POSITION_INDEPENDENT_CODE ON
    )

    # Link time optimization (LTO) - disabled by default like autotools
    # Can be enabled with -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON
    # if(CMAKE_BUILD_TYPE MATCHES "Release")
    #     set_target_properties(${target} PROPERTIES
    #         INTERPROCEDURAL_OPTIMIZATION TRUE
    #     )
    # endif()

    # Stack protection
    target_compile_options(${target} PRIVATE
        $<$<CONFIG:Debug>:-fstack-protector-strong>
    )

    # Function sections
    target_compile_options(${target} PRIVATE
        -ffunction-sections
        -fdata-sections
    )

    # Linker flags
    if(NOT APPLE)
        target_link_options(${target} PRIVATE
            $<$<CONFIG:Release>:-Wl,--gc-sections>
        )
    endif()

    # Symbol visibility (autotools uses -fvisibility=hidden for Clang on ELF)
    if(NOT WIN32 AND NOT APPLE)
        target_compile_options(${target} PRIVATE
            -fvisibility=hidden
        )
    endif()
endfunction()
