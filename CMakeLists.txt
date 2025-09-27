# Main CMakeLists.txt - Orchestrates the build by including modular CMake files

cmake_minimum_required(VERSION 3.24)
project(embedded-innodb LANGUAGES C CXX)

# Generator Validation
# -------------------
# This project requires Ninja Multi-Config generator for proper multi-configuration builds
if(NOT CMAKE_GENERATOR STREQUAL "Ninja Multi-Config")
    message(FATAL_ERROR
        "This project requires Ninja Multi-Config generator.\n"
        "Please run CMake with: -GNinja Multi-Config\n"
        "Current generator: ${CMAKE_GENERATOR}"
    )
endif()

# CMake Version Validation
# -----------------------
# Ensure CMake version supports all features used in this project
if(CMAKE_VERSION VERSION_LESS 3.24)
    message(FATAL_ERROR "CMake 3.24 or higher is required. Current version: ${CMAKE_VERSION}")
endif()

# Validate that required CMake features are available
cmake_policy(SET CMP0135 NEW)  # Use DOWNLOAD_EXTRACT_TIMESTAMP for ExternalProject
cmake_policy(SET CMP0141 NEW)  # Use MSVC_DEBUG_INFORMATION_FORMAT for MSVC

# Project Structure Validation
# ---------------------------
# Ensure we're building from the correct directory
if(NOT CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    message(WARNING "Building from a subdirectory may cause issues with relative paths")
endif()


include(cmake/config.cmake)
include(cmake/version.cmake)
include(cmake/ci_matrix.cmake)
include(cmake/config_checks.cmake)

# ---------------------------------------------------------------------------------------------------------------------
# InnoDB
# ---------------------------------------------------------------------------------------------------------------------

include(innodb/cmake/modules.cmake)
if(INNODB_ENABLE_UNIT_TESTING)
    include(innodb/cmake/unit_tests.cmake)
endif()
if(INNODB_ENABLE_INTEGRATION_TESTING)
    include(innodb/cmake/integration_tests.cmake)
endif()
include(innodb/cmake/install.cmake)

# ---------------------------------------------------------------------------------------------------------------------
# innodb_validate_build_config
# ---------------------------------------------------------------------------------------------------------------------
#
# innodb_validate_build_config()
#
# Performs comprehensive validation of build configuration options.
# This function centralizes all build configuration validation logic.
#
function(innodb_validate_build_config)
    # Coverage validation
    if(INNODB_ENABLE_GCOV AND NOT CMAKE_BUILD_TYPE STREQUAL "Debug")
        message(WARNING "GCOV coverage requires Debug build type for meaningful results")
        message(WARNING "Current build type: ${CMAKE_BUILD_TYPE}")
    endif()

    # Sanitizer validation
    if(INNODB_ENABLE_SANITIZERS)
        set(sanitizer_vars ASAN_OPTIONS TSAN_OPTIONS UBSAN_OPTIONS)
        set(active_sanitizers 0)

        foreach(var IN LISTS sanitizer_vars)
            if(DEFINED ENV{${var}})
                math(EXPR active_sanitizers "${active_sanitizers} + 1")
            endif()
        endforeach()

        if(active_sanitizers GREATER 1)
            message(WARNING "Multiple sanitizers detected. This may cause conflicts.")
            message(WARNING "Consider using only one sanitizer at a time.")
        endif()

        if(INNODB_ENABLE_IPO)
            message(WARNING "IPO/LTO with sanitizers may reduce sanitizer effectiveness")
        endif()
    endif()

    # Unity build validation
    if(INNODB_ENABLE_UNITY_BUILD AND INNODB_ENABLE_IPO)
        message(WARNING "Unity builds with IPO may not provide expected performance benefits")
    endif()
endfunction()

# Perform final build configuration validation
innodb_validate_build_config()


# ---------------------------------------------------------------------------------------------------------------------
# InnoLua
# ---------------------------------------------------------------------------------------------------------------------

# todo

# ---------------------------------------------------------------------------------------------------------------------
# InnoBench
# ---------------------------------------------------------------------------------------------------------------------

# todo