# ---------------------------------------------------------------------------------------------------------------------
# Build Configuration and System Capability Detection
# ---------------------------------------------------------------------------------------------------------------------
#
# This file handles comprehensive build configuration for Embedded InnoDB, including:
# - C++ standard and compilation settings
# - Output directory configuration
# - Dependency detection and validation
# - System capability checks (type sizes, headers, features)
# - Configuration header generation
#
# The configuration is organized into the following sections:
# 1. C++ Standard and Compilation Settings
# 2. Output Directory Configuration
# 3. Dependency Detection and Configuration
# 4. System Capability Validation
# 5. Configuration Header Generation
#
# Configuration Options:
# ---------------------
# The following options control various aspects of the build:
#
# Build Types:
# - CMAKE_BUILD_TYPE: Choose from Debug, Release, RelWithDebInfo, MinSizeRel
#   - Debug: Enables debug symbols, assertions, and development features
#   - Release: Optimized build with no debug symbols
#   - RelWithDebInfo: Release build with debug symbols
#   - MinSizeRel: Minimum size release build
#
# Feature Toggles:
# - INNODB_ENABLE_GCOV: Enable GCOV code coverage analysis (requires Debug build)
# - INNODB_ENABLE_UNIT_TESTING: Enable compilation and execution of unit tests
# - INNODB_ENABLE_INTEGRATION_TESTING: Enable compilation and execution of integration tests
# - INNODB_ENABLE_XA: Enable XA transaction support
# - INNODB_ENABLE_LUA: Enable Lua scripting bindings
# - INNODB_ENABLE_ASAN: Enable Clang Address Sanitizer (ASAN) - detects memory errors
# - INNODB_ENABLE_TSAN: Enable Clang Thread Sanitizer (TSAN) - detects data races
# - INNODB_ENABLE_UBSAN: Enable Clang Undefined Behavior Sanitizer (UBSAN) - detects undefined behavior
# - INNODB_ENABLE_UNITY_BUILD: Enable unity builds for faster compilation
# - INNODB_ENABLE_IPO: Enable Interprocedural Optimization (LTO) for better performance
# - INNODB_ENABLE_CCACHE: Enable ccache for faster rebuilds
# - INNODB_ENABLE_CLANG_TIDY: Enable clang-tidy static analysis
#
# Dependencies:
# - PkgConfig: For finding system libraries
# - FLEX/BISON: For SQL parser generation
# - liburing: Required for high-performance asynchronous I/O
# - BS Thread Pool: High-performance C++ thread pool library
#
# Output: ${INNODB_PRIVATE_GENERATED_INCLUDE_DIR}/ib0config.h
#


# ====================================================================================================================
# 1. C++ Standard and Compilation Settings
# ====================================================================================================================
#
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


# ====================================================================================================================
# 2. Output Directory Configuration
# ====================================================================================================================
#
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


# ====================================================================================================================
# 3. Dependency Detection and Configuration
# ====================================================================================================================
#
# Ensure all required build dependencies are available

# Required CMake Modules
# ----------------------
include(CheckTypeSize)
include(CheckIncludeFiles)

# Build System Tools
# ------------------
# FLEX and BISON are required for SQL parser generation
find_package(PkgConfig       REQUIRED)
find_package(FLEX            REQUIRED)
find_package(BISON           REQUIRED)
find_package(Threads         REQUIRED)

# =========================
# Core Runtime Dependencies
# =========================

# -----------------------------------------------------------------------------------
# liburing: Linux-native asynchronous I/O library (required for high-performance I/O)
# -----------------------------------------------------------------------------------

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

# ----------------------------------------------------------------------------------------
# BS Thread Pool: High-performance C++ thread pool library (required for async operations)
# ----------------------------------------------------------------------------------------

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

# -----------------------------------------------------------------------------------
# luajit: Lua scripting language (required for stored procedures)
# -----------------------------------------------------------------------------------   

pkg_check_modules(LUAJIT REQUIRED IMPORTED_TARGET luajit)
if(NOT LUAJIT_FOUND)
    message(FATAL_ERROR "luajit is required but not found.")
endif()

# Validate luajit version
if(LUAJIT_VERSION)
    if(LUAJIT_VERSION VERSION_LESS "2.1")
        message(FATAL_ERROR "luajit version ${LUAJIT_VERSION} detected. Version 2.1+ recommendeis required.")
    endif()
endif()


# -----------------------------------------------------------------------------------
# Google Test Framework: Unit testing framework (required for unit tests)
# -----------------------------------------------------------------------------------   

pkg_check_modules(GTEST REQUIRED IMPORTED_TARGET gtest)
if(NOT GTEST_FOUND)
    message(FATAL_ERROR "gtest is required but not found.")
endif()

# -----------------------------------------------------------------------------------
# Google Benchmark Framework: Benchmarking framework (required for benchmarking)
# -----------------------------------------------------------------------------------   

pkg_check_modules(GBENCHMARK REQUIRED IMPORTED_TARGET benchmark)
if(NOT GBENCHMARK_FOUND)
    message(FATAL_ERROR "gbenchmark is required but not found.")
endif()


# -----------------------------------------------------------------------------------
# Google Mock Framework: Mocking framework (required for mocking)
# -----------------------------------------------------------------------------------   

pkg_check_modules(GMOCK REQUIRED IMPORTED_TARGET gmock)
if(NOT GMOCK_FOUND)
    message(FATAL_ERROR "gmock is required but not found.")
endif()

# ====================================================================================================================
# Optional Build Acceleration
# ====================================================================================================================
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


# ====================================================================================================================
# 4. System Capability Validation
# ====================================================================================================================
#
# Perform compile-time checks to detect system capabilities and validate requirements

# Type Size Detection
# ------------------
# Check sizes of fundamental types for cross-platform compatibility
# These SIZEOF_* variables will be defined in ib0config.h
check_type_size(char                      SIZEOF_CHAR)
check_type_size("unsigned char"           SIZEOF_UCHAR)
check_type_size(short                     SIZEOF_SHORT)
check_type_size("unsigned short"          SIZEOF_USHORT)
check_type_size(int                       SIZEOF_INT)
check_type_size("unsigned int"            SIZEOF_UINT)
check_type_size(long                      SIZEOF_LONG)
check_type_size("unsigned long"           SIZEOF_ULONG)
check_type_size("long long int"           SIZEOF_LONG_LONG)
check_type_size("unsigned long long int"  SIZEOF_ULONG_LONG)
check_type_size(char*                     SIZEOF_CHARP)
check_type_size(void*                     SIZEOF_VOIDP)
check_type_size(off_t                     SIZEOF_OFF_T)

# Pthread Type Size
# -----------------
# Check pthread_t size with proper includes
set(CMAKE_EXTRA_INCLUDE_FILES pthread.h)
check_type_size(pthread_t SIZEOF_PTHREAD_T)
set(CMAKE_EXTRA_INCLUDE_FILES)

# Header File Detection
# --------------------
# Check for availability of standard and system headers
check_include_files("stdint.h"            HAVE_STDINT_H)

# System Capability Validation
# ---------------------------
# Validate that detected system capabilities meet minimum requirements

# Check for required C++ features
include(CheckCXXSourceCompiles)
check_cxx_source_compiles("
    #include <version>
    #ifdef __cpp_lib_atomic_ref
        int main() { return 0; }
    #else
        #error Atomic ref not available
    #endif
" HAS_CXX20_ATOMIC_REF)

if(NOT HAS_CXX20_ATOMIC_REF)
    message(WARNING "C++20 atomic_ref not available. Some optimizations may be disabled.")
endif()

# Check for thread support
include(CheckIncludeFileCXX)
check_include_file_cxx(pthread.h HAS_PTHREAD_H)
if(NOT HAS_PTHREAD_H)
    message(FATAL_ERROR "pthread.h is required but not found")
endif()

# Validate compiler capabilities
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS "11.0")
    message(WARNING "GCC 11.0+ recommended for best C++23 support")
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS "14.0")
    message(WARNING "Clang 14.0+ recommended for best C++23 support")
endif()


# ====================================================================================================================
# 5. Configuration Header Generation
# ====================================================================================================================
#
# Generate ib0config.h from template with detected configuration values

# Create the output directory
file(MAKE_DIRECTORY ${INNODB_PRIVATE_GENERATED_INCLUDE_DIR})

# Generate the configuration header
configure_file(${CMAKE_SOURCE_DIR}/cmake/config.h.cmake ${INNODB_PRIVATE_GENERATED_INCLUDE_DIR}/ib0config.h)

# Validate generated configuration
if(NOT EXISTS ${INNODB_PRIVATE_GENERATED_INCLUDE_DIR}/ib0config.h)
    message(FATAL_ERROR "Failed to generate ib0config.h header file")
endif()
