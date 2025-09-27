# ---------------------------------------------------------------------------------------------------------------------
# Doxygen Documentation
# ---------------------------------------------------------------------------------------------------------------------

find_package(Doxygen)
if(DOXYGEN_FOUND)
    set(DOXYGEN_PROJECT_NAME       "Embedded InnoDB")
    set(DOXYGEN_GENERATE_HTML      YES)
    set(DOXYGEN_GENERATE_LATEX     NO)
    set(DOXYGEN_RECURSIVE          YES)
    set(DOXYGEN_OUTPUT_DIRECTORY   "${CMAKE_BINARY_DIR}/docs")
endif()
