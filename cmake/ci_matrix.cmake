# ---------------------------------------------------------------------------------------------------------------------
# CI Build Matrix and Build Options Configuration
# ---------------------------------------------------------------------------------------------------------------------
#
# This file configures the build matrix options for Embedded InnoDB, including:
# - Build types (Debug/Release)
# - Platform-specific definitions
# - Compilation flags and warnings
# - Feature toggles for various optional components
# - Dependency checks and configuration
#
# All project-specific options use the INNODB_* prefix for consistency.

# Build Types Configuration
# -----------------------
# Configure available build types and set Debug as default.
# VALID_BUILD_TYPES: List of supported build configurations
if(NOT CMAKE_CONFIGURATION_TYPES)
    set(VALID_BUILD_TYPES Debug Release)
    if(NOT CMAKE_BUILD_TYPE OR CMAKE_BUILD_TYPE STREQUAL "")
        set(CMAKE_BUILD_TYPE Debug CACHE STRING "Choose the type of build." FORCE)
    endif()
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS ${VALID_BUILD_TYPES})
endif()

# Platform-Specific Configuration
# -----------------------------
# Define platform-specific preprocessor macros
if(CMAKE_SYSTEM_NAME MATCHES "Linux")
    add_definitions(-DUNIV_LINUX)
endif()

# Debug Build Configuration
# ------------------------
# Enable debug-specific features and assertions in Debug builds
add_compile_definitions($<$<CONFIG:Debug>:UNIV_DEBUG>)

# Compiler-Specific Options
# ------------------------
# Suppress Clang-specific warnings for tautological comparisons in constexpr expressions
add_compile_options($<$<CXX_COMPILER_ID:Clang>:-Wno-tautological-constant-out-of-range-compare>)

# GCC-Specific Configuration
# -------------------------
# Handle GCC-specific issues with _FORTIFY_SOURCE in Debug/coverage builds.
# FORTIFY_SOURCE requires optimization flags (-O1+) but coverage forces -O0,
# so we disable it to avoid compilation warnings/errors.
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    if(CMAKE_BUILD_TYPE STREQUAL "Debug" OR INNODB_ENABLE_GCOV)
        set(INNODB_FORTIFY_OFF_FLAGS "-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0")
        set(CMAKE_CXX_FLAGS   "${CMAKE_CXX_FLAGS} ${INNODB_FORTIFY_OFF_FLAGS}")
    endif()
endif()

# Feature Toggle Options
# ---------------------
# Configure optional build features and components.
# All options use INNODB_* prefix for consistency with project naming conventions.
option(INNODB_ENABLE_GCOV                "Enable GCOV code coverage (requires Debug build)" OFF)
option(INNODB_ENABLE_UNIT_TESTING        "Enable unit test compilation and execution"       ON)
option(INNODB_ENABLE_INTEGRATION_TESTING "Enable integration test compilation and execution" ON)
option(INNODB_ENABLE_XA                  "Enable XA transaction support"                    ON)
option(INNODB_ENABLE_LUA                 "Enable Lua scripting bindings"                    ON)
option(INNODB_ENABLE_SANITIZERS          "Enable sanitizers (ASAN, TSAN, UBSAN)"            OFF)
option(INNODB_ENABLE_UNITY_BUILD         "Enable unity builds for faster compilation"       OFF)
option(INNODB_ENABLE_IPO                 "Enable Interprocedural Optimization (LTO)"        OFF)
option(INNODB_ENABLE_CCACHE              "Enable ccache for faster rebuilds"                ON)
option(INNODB_ENABLE_CLANG_TIDY          "Enable clang-tidy static analysis"                OFF)

# Build Configuration Validation
# -----------------------------
# Validate option combinations and provide helpful error messages

# Coverage requires Debug build
if(INNODB_ENABLE_GCOV AND NOT CMAKE_BUILD_TYPE STREQUAL "Debug")
    message(WARNING "GCOV coverage requires Debug build type. Current: ${CMAKE_BUILD_TYPE}")
    message(WARNING "Consider setting CMAKE_BUILD_TYPE to Debug for meaningful coverage results")
endif()

# Sanitizers are typically incompatible with each other
if(INNODB_ENABLE_SANITIZERS)
    set(SANITIZER_COUNT 0)
    if(DEFINED ENV{ASAN_OPTIONS} OR "$ENV{ASAN_OPTIONS}" STREQUAL "")
        math(EXPR SANITIZER_COUNT "${SANITIZER_COUNT} + 1")
    endif()
    if(DEFINED ENV{TSAN_OPTIONS} OR "$ENV{TSAN_OPTIONS}" STREQUAL "")
        math(EXPR SANITIZER_COUNT "${SANITIZER_COUNT} + 1")
    endif()
    if(DEFINED ENV{UBSAN_OPTIONS} OR "$ENV{UBSAN_OPTIONS}" STREQUAL "")
        math(EXPR SANITIZER_COUNT "${SANITIZER_COUNT} + 1")
    endif()

    if(SANITIZER_COUNT GREATER 1)
        message(WARNING "Multiple sanitizers detected in environment. This may cause issues.")
        message(WARNING "Consider using only one sanitizer at a time for best results.")
    endif()
endif()

# IPO/LTO may conflict with some debugging features
if(INNODB_ENABLE_IPO AND INNODB_ENABLE_SANITIZERS)
    message(WARNING "Interprocedural Optimization (IPO/LTO) with sanitizers may reduce sanitizer effectiveness")
endif()

# Report all options
# Add to cmake/ci_matrix.cmake
message(STATUS "")
message(STATUS "=== Embedded InnoDB Configuration Summary ===")
message(STATUS "Version:                  ${INNODB_VERSION}")
message(STATUS "API Version:              ${INNODB_API_VERSION_STRING}")
message(STATUS "Build Type:               ${CMAKE_BUILD_TYPE}")
message(STATUS "C++ Compiler:             ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
message(STATUS "Install Prefix:           ${CMAKE_INSTALL_PREFIX}")
message(STATUS "")
message(STATUS "Features:")
message(STATUS "  Unit Tests:                   ${INNODB_ENABLE_UNIT_TESTING}")
message(STATUS "  Integration Tests:            ${INNODB_ENABLE_INTEGRATION_TESTING}")
message(STATUS "  GCOV Coverage:                ${INNODB_ENABLE_GCOV}")
message(STATUS "  XA Support:                   ${INNODB_ENABLE_XA}")
message(STATUS "  Lua Bindings:                 ${INNODB_ENABLE_LUA}")
message(STATUS "  Sanitizers:                   ${INNODB_ENABLE_SANITIZERS}")
message(STATUS "  Unity Build:                  ${INNODB_ENABLE_UNITY_BUILD}")
message(STATUS "  Interprocedural Optimization: ${INNODB_ENABLE_IPO}")
message(STATUS "  ccache:                       ${INNODB_ENABLE_CCACHE}")
message(STATUS "  clang-tidy:                   ${INNODB_ENABLE_CLANG_TIDY}")
message(STATUS "")
message(STATUS "Dependencies:")
message(STATUS "  liburing:       ${LIBURING_VERSION}")
message(STATUS "  BS Thread Pool: ${BS_THREAD_POOL_VERSION}")
message(STATUS "  BISON:          ${BISON_VERSION}")
message(STATUS "  FLEX:           ${FLEX_VERSION}")
message(STATUS "  GTest:          ${GTest_VERSION}")
message(STATUS "")

