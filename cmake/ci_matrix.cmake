# ---------------------------------------------------------------------------------------------------------------------
# CI Build Matrix and Build Options Configuration
# ---------------------------------------------------------------------------------------------------------------------
#
# This file configures the build matrix options and feature toggles for Embedded InnoDB.
# It handles platform-specific settings, compilation options, and build configuration validation.
#
# The configuration is organized into the following sections:
# 1. Build Types Configuration
# 2. Platform-Specific Configuration
# 3. Debug Build Configuration
# 4. Compiler-Specific Options
# 5. GCC-Specific Configuration
# 6. Feature Toggle Options
# 7. Build Configuration Validation
# 8. Configuration Summary Report
#
# Feature Options Overview:
# -----------------------
# Core Features:
# - INNODB_ENABLE_UNIT_TESTING: Enable unit test compilation and execution
# - INNODB_ENABLE_INTEGRATION_TESTING: Enable integration test compilation and execution
# - INNODB_ENABLE_XA: Enable XA transaction support for distributed transactions
# - INNODB_ENABLE_LUA: Enable Lua scripting bindings for stored procedures
#
# Debugging and Analysis:
# - INNODB_ENABLE_GCOV: Enable GCOV code coverage analysis (requires Debug build)
# - INNODB_ENABLE_ASAN: Enable Address Sanitizer to detect memory errors (Clang only)
# - INNODB_ENABLE_TSAN: Enable Thread Sanitizer to detect data races (Clang only)
# - INNODB_ENABLE_UBSAN: Enable Undefined Behavior Sanitizer (Clang only)
#
# Performance and Build Optimization:
# - INNODB_ENABLE_UNITY_BUILD: Enable unity builds for faster compilation
# - INNODB_ENABLE_IPO: Enable Interprocedural Optimization (LTO) for better performance
# - INNODB_ENABLE_CCACHE: Enable ccache for faster rebuilds
# - INNODB_ENABLE_CLANG_TIDY: Enable clang-tidy static analysis
#
# All project-specific options use the INNODB_* prefix for consistency.

# ====================================================================================================================
# 1. Build Types Configuration
# ====================================================================================================================
# Configure available build types and set Debug as default.
# VALID_BUILD_TYPES: List of supported build configurations
set(VALID_BUILD_TYPES Debug Release RelWithDebInfo MinSizeRel)
if(NOT CMAKE_CONFIGURATION_TYPES)
    # Single-config generator (Make, Ninja); note currenty we only support Ninja Multi-Config
    # Keep this single-config behavior for consistency with the preset configurations
    # In the future we might add single-config generator
    if(NOT CMAKE_BUILD_TYPE OR CMAKE_BUILD_TYPE STREQUAL "")
        set(CMAKE_BUILD_TYPE Debug CACHE STRING "Choose the type of build." FORCE)
    endif()
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS ${VALID_BUILD_TYPES})
else()
    set(CMAKE_CONFIGURATION_TYPES "${VALID_BUILD_TYPES}" CACHE STRING "Semicolon separated list of supported configuration types" FORCE)
endif()

# ====================================================================================================================
# 2. Platform-Specific Configuration
# ====================================================================================================================
# Define platform-specific preprocessor macros
if(CMAKE_SYSTEM_NAME MATCHES "Linux")
    add_definitions(-DUNIV_LINUX)
endif()

# ====================================================================================================================
# 3. Debug Build Configuration
# ====================================================================================================================
# Enable debug-specific features and assertions in Debug builds
add_compile_definitions($<$<CONFIG:Debug>:UNIV_DEBUG>)

# ====================================================================================================================
# 4. Compiler-Specific Options
# ====================================================================================================================
# Suppress Clang-specific warnings for tautological comparisons in constexpr expressions
# TEMPORARY: some code contains some tautological comparisons
add_compile_options($<$<CXX_COMPILER_ID:Clang>:-Wno-tautological-constant-out-of-range-compare>)

# ====================================================================================================================
# 5. GCC-Specific Configuration
# ====================================================================================================================
# Handle GCC-specific issues with _FORTIFY_SOURCE in Debug/coverage builds.
# FORTIFY_SOURCE requires optimization flags (-O1+) but coverage forces -O0,
# so we disable it to avoid compilation warnings/errors.
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    if(CMAKE_BUILD_TYPE STREQUAL "Debug" OR INNODB_ENABLE_GCOV)
        set(INNODB_FORTIFY_OFF_FLAGS "-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0")
        set(CMAKE_CXX_FLAGS          "${CMAKE_CXX_FLAGS} ${INNODB_FORTIFY_OFF_FLAGS}")
    endif()
endif()

# ====================================================================================================================
# 6. Feature Toggle Options
# ====================================================================================================================
# Configure optional build features and components.
# All options use INNODB_* prefix for consistency with project naming conventions.
option(INNODB_ENABLE_GCOV                "Enable GCOV code coverage (requires Debug build)"  OFF)
option(INNODB_ENABLE_UNIT_TESTING        "Enable unit test compilation and execution"        ON)
option(INNODB_ENABLE_INTEGRATION_TESTING "Enable integration test compilation and execution" ON)
option(INNODB_ENABLE_XA                  "Enable XA transaction support"                     ON)
option(INNODB_ENABLE_LUA                 "Enable Lua scripting bindings"                     ON)
option(INNODB_ENABLE_ASAN                "Enable Clang Address Sanitizer (ASAN)"             OFF)
option(INNODB_ENABLE_TSAN                "Enable Clang Thread Sanitizer (TSAN)"              OFF)
option(INNODB_ENABLE_UBSAN               "Enable Clang Undefined Behavior Sanitizer (UBSAN)" OFF)
option(INNODB_ENABLE_UNITY_BUILD         "Enable unity builds for faster compilation"        OFF)
option(INNODB_ENABLE_IPO                 "Enable Interprocedural Optimization (LTO)"         OFF)
option(INNODB_ENABLE_CLANG_TIDY          "Enable clang-tidy static analysis"                 OFF)

# ====================================================================================================================
# 7. Build Configuration Validation
# ====================================================================================================================
# Validate option combinations and provide helpful error messages

# Coverage requires Debug build
if(INNODB_ENABLE_GCOV AND NOT CMAKE_BUILD_TYPE STREQUAL "Debug")
    message(WARNING "GCOV coverage requires Debug build type. Current: ${CMAKE_BUILD_TYPE}")
    message(WARNING "Consider setting CMAKE_BUILD_TYPE to Debug for meaningful coverage results")
endif()

# Sanitizer validation
set(ENABLED_SANITIZERS "")
if(INNODB_ENABLE_ASAN)
    list(APPEND ENABLED_SANITIZERS "ASAN")
endif()
if(INNODB_ENABLE_TSAN)
    list(APPEND ENABLED_SANITIZERS "TSAN")
endif()
if(INNODB_ENABLE_UBSAN)
    list(APPEND ENABLED_SANITIZERS "UBSAN")
endif()

# Check if any sanitizers are enabled
if(ENABLED_SANITIZERS)
    # Ensure only Clang compiler is used with sanitizers
    if(NOT CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
        message(FATAL_ERROR "Sanitizers are only supported with Clang compiler. "
                            "Current compiler: ${CMAKE_CXX_COMPILER_ID}. "
                            "Enabled sanitizers: ${ENABLED_SANITIZERS}")
    endif()

    # Sanitizers are typically incompatible with each other
    list(LENGTH ENABLED_SANITIZERS SANITIZER_COUNT)
    if(SANITIZER_COUNT GREATER 1)
        message(FATAL_ERROR "Multiple sanitizers enabled: ${ENABLED_SANITIZERS}. "
                            "Sanitizers are incompatible with each other. "
                            "Please enable only one sanitizer at a time.")
    endif()
endif()

# IPO/LTO may conflict with some debugging features
if(INNODB_ENABLE_IPO AND ENABLED_SANITIZERS)
    message(WARNING "Interprocedural Optimization (IPO/LTO) with sanitizers may reduce sanitizer effectiveness")
endif()

# ====================================================================================================================
# 8. Configuration Summary Report
# ====================================================================================================================
# Display comprehensive build configuration summary
message(STATUS "")
message(STATUS "=== Embedded InnoDB Configuration Summary ===")
message(STATUS "Version:                  ${INNODB_VERSION}")
message(STATUS "API Version:              ${INNODB_API_VERSION_STRING}")

# Handle build type display for different generator types
if(CMAKE_CONFIGURATION_TYPES)
    # Multi-config generator (Ninja Multi-Config, Visual Studio)
    # Shows all available build configurations that can be selected at build time
    message(STATUS "Build Generator:          ${CMAKE_GENERATOR} (Multi-Config)")
    message(STATUS "Available Configs:        ${CMAKE_CONFIGURATION_TYPES}")
else()
    # Single-config generator (Make, Ninja)
    # Shows the single build type set at configure time
    message(STATUS "Build Type:               ${CMAKE_BUILD_TYPE}")
endif()

message(STATUS "C++ Compiler:             ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
message(STATUS "Install Prefix:           ${CMAKE_INSTALL_PREFIX}")
message(STATUS "")
message(STATUS "Features:")
message(STATUS "  Build Unit Tests:             ${INNODB_ENABLE_UNIT_TESTING}")
message(STATUS "  Build Integration Tests:      ${INNODB_ENABLE_INTEGRATION_TESTING}")
message(STATUS "  Enable GCOV Coverage:         ${INNODB_ENABLE_GCOV}")
message(STATUS "  XA Support:                   ${INNODB_ENABLE_XA}")
message(STATUS "  Address Sanitizer (ASAN):     ${INNODB_ENABLE_ASAN} \t[ ~2x slowdown, ~3x memory usage   ]")
message(STATUS "  Thread Sanitizer (TSAN):      ${INNODB_ENABLE_TSAN} \t[ ~5-15x slowdown (very expensive) ]")
message(STATUS "  UBSanitizer (UBSAN):          ${INNODB_ENABLE_UBSAN}\t[ Minimal overhead (~10-20%)       ]")
message(STATUS "  Unity Build:                  ${INNODB_ENABLE_UNITY_BUILD}")
message(STATUS "  Interprocedural Optimization: ${INNODB_ENABLE_IPO}")
message(STATUS "  clang-tidy:                   ${INNODB_ENABLE_CLANG_TIDY}")
message(STATUS "")
message(STATUS "Dependencies:")
message(STATUS "  liburing:         ${LIBURING_VERSION}")
message(STATUS "  BS Thread Pool:   ${BS_THREAD_POOL_VERSION}")
message(STATUS "  Bison:            ${BISON_VERSION}")
message(STATUS "  Flex:             ${FLEX_VERSION}")
message(STATUS "  LuaJIT:           ${LUAJIT_VERSION}")
message(STATUS "  Google Test:      ${GTEST_VERSION}")
message(STATUS "  Google Benchmark: ${GBENCHMARK_VERSION}")
message(STATUS "  Google Mock:      ${GMOCK_VERSION}")
message(STATUS "")

