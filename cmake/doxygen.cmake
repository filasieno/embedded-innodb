# ---------------------------------------------------------------------------------------------------------------------
# Doxygen Documentation Configuration
# ---------------------------------------------------------------------------------------------------------------------
#
# This file configures Doxygen documentation generation for the Embedded InnoDB project.
# When Doxygen is available, it sets up documentation generation with the following features:
# - HTML output generation
# - Recursive source code parsing
# - Custom project branding
#
# Output directory: ${CMAKE_BINARY_DIR}/docs
# Main page: HTML documentation with project information and API reference

# Doxygen Detection and Configuration
# ----------------------------------
find_package(Doxygen)
if(DOXYGEN_FOUND)
    # Project Information
    set(DOXYGEN_PROJECT_NAME       "Embedded InnoDB")

    # Output Configuration
    set(DOXYGEN_GENERATE_HTML      YES)  # Generate HTML documentation
    set(DOXYGEN_GENERATE_LATEX     NO)   # Skip LaTeX/PDF generation for faster builds
    set(DOXYGEN_RECURSIVE          YES)  # Recursively parse all source files
    set(DOXYGEN_OUTPUT_DIRECTORY   "${CMAKE_BINARY_DIR}/docs")

    # Note: Additional Doxygen variables can be set here as needed
    # The doxygen_add_docs() command would be called in the main CMakeLists.txt if needed
else()
    message(STATUS "Doxygen not found - documentation generation will be skipped")
endif()
