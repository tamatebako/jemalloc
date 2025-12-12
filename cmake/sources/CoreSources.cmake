# CoreSources.cmake
# List all core jemalloc source files

# Get jemalloc root directory (works with add_subdirectory too)
get_filename_component(JEMALLOC_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

# Core source files (platform-independent)
set(JEMALLOC_CORE_SOURCES
    ${JEMALLOC_ROOT}/src/jemalloc.c
    ${JEMALLOC_ROOT}/src/arena.c
    ${JEMALLOC_ROOT}/src/background_thread.c
    ${JEMALLOC_ROOT}/src/base.c
    ${JEMALLOC_ROOT}/src/bin.c
    ${JEMALLOC_ROOT}/src/bin_info.c
    ${JEMALLOC_ROOT}/src/bitmap.c
    ${JEMALLOC_ROOT}/src/buf_writer.c
    ${JEMALLOC_ROOT}/src/cache_bin.c
    ${JEMALLOC_ROOT}/src/ckh.c
    ${JEMALLOC_ROOT}/src/counter.c
    ${JEMALLOC_ROOT}/src/ctl.c
    ${JEMALLOC_ROOT}/src/decay.c
    ${JEMALLOC_ROOT}/src/div.c
    ${JEMALLOC_ROOT}/src/ecache.c
    ${JEMALLOC_ROOT}/src/edata.c
    ${JEMALLOC_ROOT}/src/edata_cache.c
    ${JEMALLOC_ROOT}/src/ehooks.c
    ${JEMALLOC_ROOT}/src/emap.c
    ${JEMALLOC_ROOT}/src/eset.c
    ${JEMALLOC_ROOT}/src/exp_grow.c
    ${JEMALLOC_ROOT}/src/extent.c
    ${JEMALLOC_ROOT}/src/extent_dss.c
    ${JEMALLOC_ROOT}/src/extent_mmap.c
    ${JEMALLOC_ROOT}/src/fxp.c
    ${JEMALLOC_ROOT}/src/hook.c
    ${JEMALLOC_ROOT}/src/hpa.c
    ${JEMALLOC_ROOT}/src/hpa_hooks.c
    ${JEMALLOC_ROOT}/src/hpdata.c
    ${JEMALLOC_ROOT}/src/inspect.c
    ${JEMALLOC_ROOT}/src/large.c
    ${JEMALLOC_ROOT}/src/log.c
    ${JEMALLOC_ROOT}/src/malloc_io.c
    ${JEMALLOC_ROOT}/src/mutex.c
    ${JEMALLOC_ROOT}/src/nstime.c
    ${JEMALLOC_ROOT}/src/pa.c
    ${JEMALLOC_ROOT}/src/pa_extra.c
    ${JEMALLOC_ROOT}/src/pac.c
    ${JEMALLOC_ROOT}/src/pages.c
    ${JEMALLOC_ROOT}/src/pai.c
    ${JEMALLOC_ROOT}/src/peak_event.c
    ${JEMALLOC_ROOT}/src/prof.c
    ${JEMALLOC_ROOT}/src/prof_data.c
    ${JEMALLOC_ROOT}/src/prof_log.c
    ${JEMALLOC_ROOT}/src/prof_recent.c
    ${JEMALLOC_ROOT}/src/prof_stack_range.c
    ${JEMALLOC_ROOT}/src/prof_stats.c
    ${JEMALLOC_ROOT}/src/prof_sys.c
    ${JEMALLOC_ROOT}/src/prof_threshold.c
    ${JEMALLOC_ROOT}/src/psset.c
    ${JEMALLOC_ROOT}/src/rtree.c
    ${JEMALLOC_ROOT}/src/safety_check.c
    ${JEMALLOC_ROOT}/src/san.c
    ${JEMALLOC_ROOT}/src/san_bump.c
    ${JEMALLOC_ROOT}/src/sc.c
    ${JEMALLOC_ROOT}/src/sec.c
    ${JEMALLOC_ROOT}/src/stats.c
    ${JEMALLOC_ROOT}/src/sz.c
    ${JEMALLOC_ROOT}/src/tcache.c
    ${JEMALLOC_ROOT}/src/test_hooks.c
    ${JEMALLOC_ROOT}/src/thread_event.c
    ${JEMALLOC_ROOT}/src/thread_event_registry.c
    ${JEMALLOC_ROOT}/src/ticker.c
    ${JEMALLOC_ROOT}/src/tsd.c
    ${JEMALLOC_ROOT}/src/util.c
    ${JEMALLOC_ROOT}/src/witness.c
)

# macOS zone allocator
set(JEMALLOC_ZONE_SOURCES
    ${JEMALLOC_ROOT}/src/zone.c
)

# C++ support
set(JEMALLOC_CXX_SOURCES
    ${JEMALLOC_ROOT}/src/jemalloc_cpp.cpp
)

# Public headers
set(JEMALLOC_PUBLIC_HEADERS
    ${JEMALLOC_ROOT}/include/jemalloc/jemalloc.h
)

# Internal headers - not needed in target, found via include directories
# (Header files don't need to be listed in add_library() sources)

# Export to parent scope
set(JEMALLOC_CORE_SOURCES "${JEMALLOC_CORE_SOURCES}")
set(JEMALLOC_ZONE_SOURCES "${JEMALLOC_ZONE_SOURCES}")
set(JEMALLOC_CXX_SOURCES "${JEMALLOC_CXX_SOURCES}")
set(JEMALLOC_PUBLIC_HEADERS "${JEMALLOC_PUBLIC_HEADERS}")