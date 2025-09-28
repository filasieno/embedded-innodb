# ====================================================================================================================
# Embedded InnoDB - Main CMakeLists.txt
# ====================================================================================================================
#
# This is the root CMakeLists.txt file that orchestrates the entire Embedded InnoDB build system.
# It serves as the central coordination point for a sophisticated, modular CMake-based build
# infrastructure designed for professional C++ development.
#
# ARCHITECTURAL OVERVIEW:
# ----------------------
# The build system follows a modular architecture where this root file:
# - Validates build environment and requirements
# - Includes specialized CMake modules for different concerns
# - Orchestrates the build of multiple sub-components
# - Provides comprehensive build configuration validation
#
# KEY FEATURES:
# ------------
# - Modern CMake practices (3.24+, target-based builds)
# - Ninja Multi-Config generator for multi-configuration builds
# - Modular cmake/ directory structure for maintainability
# - Comprehensive build validation and error checking
# - Support for unit testing, integration testing, and documentation
# - Cross-platform compatibility with Linux focus
#
# BUILD COMPONENTS:
# ----------------
# 1. Core Library (innodb): Main Embedded InnoDB static/shared library
# 2. Unit Tests: Comprehensive GTest-based unit testing framework
# 3. Integration Tests: End-to-end testing of database functionality
# 4. Documentation: Doxygen-based API documentation generation
# 5. Development Tools: Sanitizers, coverage analysis, static analysis
#
# DEPENDENCIES:
# ------------
# - CMake 3.24+: Modern CMake features and policies
# - Ninja Multi-Config: Required build generator for multi-config support
# - C++23 Compiler: GCC/Clang with C++23 standard support
# - System Libraries: liburing, threading libraries
# - Build Tools: Bison, Flex for SQL parser generation
#
# USAGE:
# -----
#   cmake -GNinja\ Multi-Config -S . -B build
#   cmake --build build --config Debug
#   cmake --build build --config Release
#
# ====================================================================================================================

cmake_minimum_required(VERSION 3.24)
project(embedded-innodb LANGUAGES C CXX)

# ====================================================================================================================
# 1. BUILD ENVIRONMENT VALIDATION
# ====================================================================================================================
#
# This section validates that the build environment meets all requirements for successful compilation.
# It ensures compatibility, prevents build failures, and provides clear error messages for developers.
#

# 1.1 Generator Validation
# -----------------------
# Ninja Multi-Config is required for proper multi-configuration builds (Debug/Release/etc.)
# This generator provides better performance and cleaner build artifacts than traditional make.
if(NOT CMAKE_GENERATOR STREQUAL "Ninja Multi-Config")
    message(FATAL_ERROR
        "This project requires Ninja Multi-Config generator for multi-configuration builds.\n"
        "Please run CMake with: -GNinja Multi-Config\n"
        "Current generator: ${CMAKE_GENERATOR}"
    )
endif()

# 1.2 CMake Version Validation
# ---------------------------
# CMake 3.24+ is required for modern features like FILE_SET, target-based PCH, and improved policies
if(CMAKE_VERSION VERSION_LESS 3.24)
    message(FATAL_ERROR "CMake 3.24 or higher is required. Current version: ${CMAKE_VERSION}")
endif()

# 1.3 CMake Policy Configuration
# -----------------------------
# Set modern CMake policies for consistent behavior across different CMake versions
cmake_policy(SET CMP0135 NEW)  # Use DOWNLOAD_EXTRACT_TIMESTAMP for ExternalProject
cmake_policy(SET CMP0141 NEW)  # Use MSVC_DEBUG_INFORMATION_FORMAT for MSVC

# 1.4 Required Tool Validation
# ----------------------------
# Check for programs required to build InnoDB (Bison and Flex for SQL parser generation)
# These tools are essential for generating the SQL parser from grammar files
find_program(FLEX flex REQUIRED)
find_program(BISON bison REQUIRED)

# Include Flex and Bison CMake modules to provide bison_target and flex_target functions
find_package(FLEX REQUIRED)
find_package(BISON REQUIRED)

# 1.5 Project Structure Validation
# -------------------------------
# Ensure we're building from the correct directory to avoid path-related issues
if(NOT CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    message(WARNING "Building from a subdirectory may cause issues with relative paths")
endif()

# ====================================================================================================================
# 2. CORE BUILD CONFIGURATION
# ====================================================================================================================
#
# Include the fundamental build configuration files that define:
# - System capability detection and compiler configuration
# - Library versioning and API compatibility
# - Build matrix options and feature toggles
#

include(cmake/version.cmake)
include(cmake/config.cmake)
include(cmake/ci_matrix.cmake)
include(cmake/doxygen.cmake)

# ====================================================================================================================
# 3. INNODB CORE LIBRARY BUILD
# ====================================================================================================================
#
# This section includes the modular CMake files that build the core Embedded InnoDB library.
# The build is organized into focused modules for better maintainability and parallel development.
#

# 3.1 Core Library Modules
# ------------------------
# Defines the modular structure of Embedded InnoDB with OBJECT libraries for efficient compilation
include(innodb/cmake/modules.cmake)

# 3.2 Unit Testing Framework
# -------------------------
# Conditionally include comprehensive unit testing infrastructure when enabled
# Provides GTest-based testing for individual components and modules
if(INNODB_ENABLE_UNIT_TESTING)
    include(innodb/cmake/unit_tests.cmake)
endif()

# 3.3 Integration Testing Framework
# --------------------------------
# Conditionally include end-to-end integration testing when enabled
# Tests complete database operations and component interactions
if(INNODB_ENABLE_INTEGRATION_TESTING)
    include(innodb/cmake/integration_tests.cmake)
endif()

# 3.4 Installation Configuration
# ----------------------------
# Defines how the library and headers are installed for external consumption
include(innodb/cmake/install.cmake)

# ====================================================================================================================
# 4. BUILD CONFIGURATION VALIDATION
# ====================================================================================================================
#
# This section performs comprehensive validation of build configuration options to ensure
# compatibility and prevent common build issues. It centralizes all validation logic in one place.
#

# 4.1 Build Configuration Validation
# ----------------------------------
# Validates build options for compatibility and best practices
# Prevents common configuration mistakes that could lead to build failures or unexpected behavior

if(INNODB_ENABLE_GCOV AND NOT CMAKE_BUILD_TYPE STREQUAL "Debug")
    message(WARNING "GCOV coverage requires Debug build type for meaningful results")
    message(WARNING "Current build type: ${CMAKE_BUILD_TYPE}")
endif()

# Sanitizer validation
set(enabled_sanitizers "")
if(INNODB_ENABLE_ASAN)
    list(APPEND enabled_sanitizers "ASAN")
endif()
if(INNODB_ENABLE_TSAN)
    list(APPEND enabled_sanitizers "TSAN")
endif()
if(INNODB_ENABLE_UBSAN)
    list(APPEND enabled_sanitizers "UBSAN")
endif()

if(enabled_sanitizers)
    # Check for environment variable conflicts with enabled sanitizers
    set(sanitizer_vars ASAN_OPTIONS TSAN_OPTIONS UBSAN_OPTIONS)
    set(active_env_sanitizers 0)

    foreach(var IN LISTS sanitizer_vars)
        if(DEFINED ENV{${var}})
            math(EXPR active_env_sanitizers "${active_env_sanitizers} + 1")
        endif()
    endforeach()

    if(active_env_sanitizers GREATER 1)
        message(FATAL_ERROR "Multiple sanitizers detected in environment variables. "
                            "Sanitizers are incompatible with each other. "
                            "Please set only one sanitizer environment variable at a time.")
    endif()

    if(INNODB_ENABLE_IPO)
        message(WARNING "IPO/LTO with sanitizers may reduce sanitizer effectiveness")
    endif()
endif()

# Unity build validation
if(INNODB_ENABLE_UNITY_BUILD AND INNODB_ENABLE_IPO)
    message(WARNING "Unity builds with IPO may not provide expected performance benefits")
endif()


# ====================================================================================================================
# 5. FUTURE COMPONENTS (PLACEHOLDERS)
# ====================================================================================================================
#
# These sections are placeholders for future components that will extend the Embedded InnoDB ecosystem.
# They represent planned expansions beyond the core database library.
#

# 5.1 InnoLua - Lua Scripting Integration
# --------------------------------------
# Planned Lua scripting bindings for stored procedures and database extensions
# TODO: Implement Lua integration for embedded scripting capabilities

# 5.2 InnoBench - Performance Benchmarking Suite
# ---------------------------------------------
# Planned comprehensive benchmarking tools for performance analysis and optimization
# TODO: Implement benchmarking suite for performance regression testing
