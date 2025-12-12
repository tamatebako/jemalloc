# MSVC.cmake
# Microsoft Visual C++ compiler settings

# Function to apply MSVC settings to a target
function(jemalloc_configure_msvc_target target)
    # Warning level 3 (W4 is too strict for jemalloc)
    target_compile_options(${target} PRIVATE /W3)

    # Treat warnings as errors in release builds
    if(CMAKE_BUILD_TYPE MATCHES "Release|RelWithDebInfo")
        target_compile_options(${target} PRIVATE /WX)
    endif()

    # Disable specific warnings that are false positives or unavoidable
    target_compile_options(${target} PRIVATE
        /wd4100  # unreferenced formal parameter
        /wd4127  # conditional expression is constant
        /wd4201  # nonstandard extension used: nameless struct/union
        /wd4324  # structure was padded due to alignment specifier
        /wd4456  # declaration hides previous local declaration
        /wd4457  # declaration hides function parameter
        /wd4702  # unreachable code
    )

    # Runtime library selection
    # Note: Use generator expressions for proper multi-config handling
    if(BUILD_SHARED_LIBS)
        set_property(TARGET ${target} PROPERTY
            MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL"
        )
    else()
        set_property(TARGET ${target} PROPERTY
            MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>"
        )
    endif()

    # Optimization flags
    target_compile_options(${target} PRIVATE
        $<$<CONFIG:Release>:/O2 /Ob2 /Oi /Ot /GL>
        $<$<CONFIG:RelWithDebInfo>:/O2 /Ob1 /Oi>
        $<$<CONFIG:MinSizeRel>:/O1 /Ob1>
        $<$<CONFIG:Debug>:/Od /Ob0>
    )

    # Debug information
    # Use /Z7 (embedded debug info) instead of /Zi to avoid PDB contention
    # This fixes "fatal error C1033: cannot open program database" during parallel builds
    target_compile_options(${target} PRIVATE
        $<$<CONFIG:Debug>:/Z7>
        $<$<CONFIG:RelWithDebInfo>:/Z7>
    )

    # Link-time code generation (LTCG) for release builds
    if(CMAKE_BUILD_TYPE MATCHES "Release")
        set_property(TARGET ${target} PROPERTY
            INTERPROCEDURAL_OPTIMIZATION TRUE
        )
        target_link_options(${target} PRIVATE /LTCG)
    endif()

    # Enable function-level linking
    target_compile_options(${target} PRIVATE /Gy)

    # Buffer security check
    target_compile_options(${target} PRIVATE
        $<$<CONFIG:Debug>:/GS>
        $<$<CONFIG:Release>:/GS->  # Disable in release for performance
    )

    # ARM64-specific settings
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64|aarch64")
        message(STATUS "Applying MSVC ARM64 settings to ${target}")
        # ARM64-specific intrinsics are automatically available
    endif()

    # Character set
    target_compile_definitions(${target} PRIVATE
        _UNICODE
        UNICODE
    )
endfunction()

# Export function to parent scope
# Note: Functions are automatically available in parent scope
