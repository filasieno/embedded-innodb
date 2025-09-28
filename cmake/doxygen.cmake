# ---------------------------------------------------------------------------------------------------------------------
# Doxygen Documentation Configuration and API Reference Generation
# ---------------------------------------------------------------------------------------------------------------------
#
# This file configures comprehensive Doxygen documentation generation for the Embedded InnoDB project,
# providing professional API documentation and code navigation capabilities.
#
# WHY API DOCUMENTATION MATTERS:
# -----------------------------
# High-quality API documentation is essential for library adoption because it:
# - Enables developers to understand and use the library effectively
# - Reduces support burden through self-service discovery
# - Serves as executable documentation that stays synchronized with code
# - Facilitates code review and maintenance by explaining design decisions
# - Supports automated documentation testing and validation
#
# DOXYGEN'S ROLE IN MODERN DEVELOPMENT:
# -----------------------------------
# Doxygen is the industry standard for C/C++ documentation because it:
# - Generates comprehensive cross-referenced documentation automatically
# - Supports multiple output formats (HTML, PDF, man pages, etc.)
# - Integrates with IDEs and development tools
# - Provides call graphs, inheritance diagrams, and dependency analysis
# - Enables documentation-as-code workflows with CI/CD integration
#
# CONFIGURATION PHILOSOPHY:
# ------------------------
# Our Doxygen configuration prioritizes developer experience by:
# - Generating HTML documentation as the primary format (most accessible)
# - Enabling recursive parsing for complete code coverage
# - Focusing on API documentation rather than internal implementation details
# - Supporting modern web standards for better navigation and search
#
# WHY OPTIONAL DEPENDENCY:
# ------------------------
# Doxygen is made optional to ensure the build system remains flexible:
# - Not all development environments may have Doxygen installed
# - Documentation generation can be resource-intensive for CI systems
# - Allows for different documentation strategies in various deployment scenarios
# - Maintains compatibility with minimal build environments
#
# The configuration is organized into the following sections:
# 1. Doxygen Detection and Setup
# 2. Documentation Generation Configuration

# ====================================================================================================================
# 1. Doxygen Detection and Setup
# ====================================================================================================================
#
# WHY DETECTION-BASED CONFIGURATION:
# ---------------------------------
# Using find_package(Doxygen) allows the build system to gracefully handle environments
# where Doxygen is not available, ensuring that documentation generation never blocks
# the core build process. This approach supports diverse development environments.
#
find_package(Doxygen)
if(DOXYGEN_FOUND)

    # ====================================================================================================================
    # 2. Documentation Generation Configuration
    # ====================================================================================================================
    #
    # WHY HTML-FIRST APPROACH:
    # ------------------------
    # HTML documentation is prioritized over other formats because:
    # - It's the most accessible format for web-based development workflows
    # - Supports interactive navigation and search capabilities
    # - Integrates seamlessly with web-based documentation platforms
    # - Can be easily deployed to internal documentation servers
    # - Provides the best developer experience for API exploration
    #
    # WHY SKIP LATEX:
    # --------------
    # LaTeX/PDF generation is intentionally disabled because:
    # - It significantly increases build time and resource usage
    # - PDF documentation is less useful for API reference work
    # - HTML provides superior navigation and search capabilities
    # - Allows faster iteration during documentation development
    #
    # WHY RECURSIVE PARSING:
    # ----------------------
    # Recursive parsing ensures comprehensive documentation coverage by:
    # - Automatically discovering all source files in the project
    # - Including documentation from header files and implementation files
    # - Maintaining documentation synchronization with code organization
    # - Reducing manual configuration and maintenance overhead
    #

    # Project Information
    set(DOXYGEN_PROJECT_NAME       "Embedded InnoDB")

    # Output Configuration (common settings)
    set(DOXYGEN_GENERATE_HTML      YES)  # Generate HTML documentation
    set(DOXYGEN_GENERATE_LATEX     NO)   # Skip LaTeX/PDF generation for faster builds
    set(DOXYGEN_RECURSIVE          YES)  # Recursively parse all source files

    # ====================================================================================================================
    # 3. Doxygen Target Creation
    # ====================================================================================================================
    #
    # WHY MULTIPLE TARGETS:
    # -------------------
    # We provide two documentation targets for different audiences:
    # - public-doc: For library users (clean, focused API documentation)
    # - internal-doc: For developers (comprehensive internal documentation)
    # This allows users to get relevant documentation without internal complexity
    #

    # ====================================================================================================================
    # 3.1 Public Documentation Target
    # ====================================================================================================================
    #
    # TARGET: public-doc
    # PURPOSE: Generate user-facing API documentation
    # AUDIENCE: Library users and external developers
    # CONTENT: Only public headers (innodb/include/innodb.h)
    # OUTPUT: ${CMAKE_BINARY_DIR}/doc
    #
    # WHY PUBLIC-ONLY:
    # ---------------
    # Public documentation should be:
    # - Focused on the stable API that users depend on
    # - Free of internal implementation details
    # - Suitable for distribution and external reference
    # - Smaller and faster to generate
    #

    set(DOXYGEN_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/doc")
    doxygen_add_docs(public-doc
        "${CMAKE_SOURCE_DIR}/innodb/include/innodb.h"
        COMMENT "Generate public API documentation for library users"
    )

    # ====================================================================================================================
    # 3.2 Internal Documentation Target
    # ====================================================================================================================
    #
    # TARGET: internal-doc
    # PURPOSE: Generate comprehensive internal documentation
    # AUDIENCE: Project maintainers and contributors
    # CONTENT: Both public and private headers
    # OUTPUT: ${CMAKE_BINARY_DIR}/internal-doc
    #
    # WHY INTERNAL + PUBLIC:
    # ---------------------
    # Internal documentation includes:
    # - Public API (for API consumers)
    # - Private headers (for implementation understanding)
    # - Internal data structures and functions
    # - Development and maintenance information
    #

    set(DOXYGEN_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/internal-doc")
    doxygen_add_docs(internal-doc
        "${CMAKE_SOURCE_DIR}/innodb/include"
        "${CMAKE_SOURCE_DIR}/innodb/src/include"
        COMMENT "Generate comprehensive internal documentation for developers"
    )

    # ====================================================================================================================
    # 4. Target Organization
    # ====================================================================================================================
    #
    # Organizing targets into folders improves IDE navigation by:
    # - Grouping related targets together in the project explorer
    # - Reducing visual clutter in the target list
    # - Making it easier to find documentation-related targets
    #
    set_target_properties(public-doc internal-doc PROPERTIES FOLDER "Documentation")

else()
    message(STATUS "Doxygen not found - documentation generation will be skipped")
endif()
