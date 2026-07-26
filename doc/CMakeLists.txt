# Documentation build: asciidoc → man page

if(NOT JEMALLOC_ENABLE_DOC)
    return()
endif()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../cmake/modules")
find_package(Asciidoctor REQUIRED)

# Stage section includes next to the configured .adoc so asciidoctor can resolve them.
file(COPY "${CMAKE_CURRENT_SOURCE_DIR}/sections"
     DESTINATION "${CMAKE_CURRENT_BINARY_DIR}")

# Substitute @jemalloc_version@ (and any other @VAR@ refs) into the .adoc.
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/jemalloc.3.adoc.in"
    "${CMAKE_CURRENT_BINARY_DIR}/jemalloc.3.adoc"
    @ONLY
)

file(GLOB JEMALLOC_SECTION_FILES "${CMAKE_CURRENT_SOURCE_DIR}/sections/*.adoc")

asciidoctor_add_manpage(
    SOURCE "${CMAKE_CURRENT_BINARY_DIR}/jemalloc.3.adoc"
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/jemalloc.3"
    SECTION 3
    DEPENDS ${JEMALLOC_SECTION_FILES}
)

add_custom_target(man_pages ALL
    DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/jemalloc.3"
    COMMENT "Building man pages"
)

install(
    FILES "${CMAKE_CURRENT_BINARY_DIR}/jemalloc.3"
    DESTINATION "${CMAKE_INSTALL_MANDIR}/man3"
    COMPONENT documentation
)
