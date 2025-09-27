# ---------------------------------------------------------------------------------------------------------------------
# General Build Configuration
# ---------------------------------------------------------------------------------------------------------------------
#
# This file handles general CMake configuration including:
# - C++ standard and compilation settings
# - Output directory configuration
# - Dependency detection and configuration
# - Compiler launcher setup (ccache)
# - Feature summary reporting
#
# Dependencies configured:
# - PkgConfig: For finding system libraries
# - FLEX/BISON: For parser generation
# - liburing: Required async I/O library
# - BS Thread Pool: High-performance thread pool library



# C++ Standard and Compilation Settings
# -------------------------------------
# Configure C++23 standard with strict compliance and export compile commands for IDEs
set(CMAKE_CXX_STANDARD            23)
set(CMAKE_CXX_STANDARD_REQUIRED   ON)
set(CMAKE_CXX_EXTENSIONS          OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Compile Commands Export
# ----------------------
# Export compile_commands.json for IDE integration and tooling support
if(CMAKE_EXPORT_COMPILE_COMMANDS)
    add_custom_target(export_compile_commands ALL
        COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_SOURCE_DIR}/build
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                ${CMAKE_BINARY_DIR}/compile_commands.json
                ${CMAKE_SOURCE_DIR}/build/compile_commands.json
        BYPRODUCTS ${CMAKE_SOURCE_DIR}/build/compile_commands.json
        COMMENT "Copy compile_commands.json to source-root build/ for IDE integration"
        VERBATIM
    )
endif()

# Output Directory Configuration
# -----------------------------
# Centralize all binary outputs for predictable, clean build artifacts:
# - CMAKE_ARCHIVE_OUTPUT_DIRECTORY: Static libraries (.a, .lib)
# - CMAKE_LIBRARY_OUTPUT_DIRECTORY: Shared libraries (.so, .dll)
# - CMAKE_RUNTIME_OUTPUT_DIRECTORY: Executables and runtime binaries
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/innodb/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/innodb/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/innodb/lib)

# Generated Headers Directory
# --------------------------
# Directory for generated private headers (config files, parser headers)
set(INNODB_PRIVATE_GENERATED_INCLUDE_DIR "${CMAKE_BINARY_DIR}/innodb/generated/include")

# Dependency Detection and Configuration
# -------------------------------------
# Ensure all required build dependencies are available

# Build System Tools
# ------------------
# FLEX and BISON are required for SQL parser generation
find_package(PkgConfig       REQUIRED)
find_package(FLEX            REQUIRED)
find_package(BISON           REQUIRED)
find_package(Threads         REQUIRED)

# Core Runtime Dependencies
# ------------------------
# liburing: Linux-native asynchronous I/O library (required for high-performance I/O)
pkg_check_modules(LIBURING REQUIRED IMPORTED_TARGET liburing)

if(NOT LIBURING_FOUND)
    message(FATAL_ERROR
        "liburing is required but not found.\n"
        "Please install liburing development headers:\n"
        "  Ubuntu/Debian: sudo apt-get install liburing-dev\n"
        "  CentOS/RHEL: sudo yum install liburing-devel\n"
        "  Arch: sudo pacman -S liburing\n"
        "  Source: https://github.com/axboe/liburing"
    )
endif()

# Validate liburing version if available
if(LIBURING_VERSION)
    if(LIBURING_VERSION VERSION_LESS "2.0")
        message(WARNING "liburing version ${LIBURING_VERSION} detected. Version 2.0+ recommended for best performance.")
    endif()
endif()

# BS Thread Pool: High-performance C++ thread pool library (required for async operations)
pkg_check_modules(BS_THREAD_POOL REQUIRED IMPORTED_TARGET libbsthreadpool)

if(NOT BS_THREAD_POOL_FOUND)
    message(FATAL_ERROR
        "libbsthreadpool is required but not found.\n"
        "Please install libbsthreadpool development headers:\n"
        "  Ubuntu/Debian: sudo apt-get install libbsthreadpool-dev\n"
        "  CentOS/RHEL: sudo yum install libbsthreadpool-devel\n"
        "  Source: https://github.com/bshoshany/thread-pool"
    )
endif()

# Validate BS Thread Pool version
if(BS_THREAD_POOL_VERSION)
    if(BS_THREAD_POOL_VERSION VERSION_LESS "3.0")
        message(WARNING "BS Thread Pool version ${BS_THREAD_POOL_VERSION} detected. Version 3.0+ recommended.")
    endif()
endif()

# Optional Build Acceleration
# --------------------------
# ccache: Compiler cache for faster rebuilds (optional but recommended)
find_program(CCACHE_PROGRAM ccache)
if(CCACHE_PROGRAM)
    set(CMAKE_C_COMPILER_LAUNCHER   "${CCACHE_PROGRAM}")
    set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
    message(STATUS "ccache found: ${CCACHE_PROGRAM}")
else()
    message(STATUS "ccache not found - rebuilds may be slower")
endif()

# Feature Summary
# ---------------
# Display summary of all detected features and packages
include(FeatureSummary)
feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)