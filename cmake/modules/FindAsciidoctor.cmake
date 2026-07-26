# FindAsciidoctor.cmake
# Find the Asciidoctor documentation generation tool
#
# This module defines:
#  ASCIIDOCTOR_FOUND        - True if asciidoctor was found
#  ASCIIDOCTOR_EXECUTABLE   - Path to asciidoctor executable
#  ASCIIDOCTOR_VERSION      - Version of asciidoctor found
#
# Functions:
#  asciidoctor_add_manpage  - Generate a man page from an AsciiDoc source

find_program(ASCIIDOCTOR_EXECUTABLE
    NAMES asciidoctor
    DOC "Path to asciidoctor executable"
)

if(ASCIIDOCTOR_EXECUTABLE)
    # Get version
    execute_process(
        COMMAND ${ASCIIDOCTOR_EXECUTABLE} --version
        OUTPUT_VARIABLE ASCIIDOCTOR_VERSION_OUTPUT
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )

    if(ASCIIDOCTOR_VERSION_OUTPUT MATCHES "Asciidoctor ([0-9]+\\.[0-9]+\\.[0-9]+)")
        set(ASCIIDOCTOR_VERSION "${CMAKE_MATCH_1}")
    endif()
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Asciidoctor
    REQUIRED_VARS ASCIIDOCTOR_EXECUTABLE
    VERSION_VAR ASCIIDOCTOR_VERSION
)

mark_as_advanced(ASCIIDOCTOR_EXECUTABLE)

# Function to generate man page from AsciiDoc source
#
# asciidoctor_add_manpage(
#     SOURCE <source.adoc>
#     OUTPUT <output.3>
#     SECTION <section_number>
#     [DEPENDS <dep1> <dep2> ...]
# )
#
function(asciidoctor_add_manpage)
    if(NOT ASCIIDOCTOR_FOUND)
        message(WARNING "Asciidoctor not found, cannot generate man page")
        return()
    endif()

    set(options "")
    set(oneValueArgs SOURCE OUTPUT SECTION)
    set(multiValueArgs DEPENDS)
    cmake_parse_arguments(ADOC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT ADOC_SOURCE)
        message(FATAL_ERROR "asciidoctor_add_manpage: SOURCE is required")
    endif()

    if(NOT ADOC_OUTPUT)
        message(FATAL_ERROR "asciidoctor_add_manpage: OUTPUT is required")
    endif()

    if(NOT ADOC_SECTION)
        message(FATAL_ERROR "asciidoctor_add_manpage: SECTION is required")
    endif()

    # Get absolute paths
    get_filename_component(SOURCE_ABS "${ADOC_SOURCE}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
    get_filename_component(OUTPUT_ABS "${ADOC_OUTPUT}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_BINARY_DIR}")
    get_filename_component(OUTPUT_DIR "${OUTPUT_ABS}" DIRECTORY)

    # Create output directory
    file(MAKE_DIRECTORY "${OUTPUT_DIR}")

    # Add custom command to generate man page
    add_custom_command(
        OUTPUT "${OUTPUT_ABS}"
        COMMAND ${ASCIIDOCTOR_EXECUTABLE}
            --backend=manpage
            --doctype=manpage
            --out-file=${OUTPUT_ABS}
            ${SOURCE_ABS}
        DEPENDS "${SOURCE_ABS}" ${ADOC_DEPENDS}
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        COMMENT "Generating man page ${ADOC_OUTPUT}"
        VERBATIM
    )

    # Add to parent scope so it can be used in add_custom_target
    set(MAN_PAGE_OUTPUT "${OUTPUT_ABS}" PARENT_SCOPE)
endfunction()