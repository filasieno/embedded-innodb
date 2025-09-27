# ---------------------------------------------------------------------------------------------------------------------
# Setup CI Build Matrix and Build options
# ---------------------------------------------------------------------------------------------------------------------

# Build types: Debug (default) or Release
if(NOT CMAKE_CONFIGURATION_TYPES)
    set(VALID_BUILD_TYPES Debug Release)
    if(NOT CMAKE_BUILD_TYPE OR CMAKE_BUILD_TYPE STREQUAL "")
        set(CMAKE_BUILD_TYPE Debug CACHE STRING "Choose the type of build." FORCE)
    endif()
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS ${VALID_BUILD_TYPES})
endif()

# Platform defines
if(CMAKE_SYSTEM_NAME MATCHES "Linux")
    add_definitions(-DUNIV_LINUX)
endif()

# Define UNIV_DEBUG on Debug builds
add_compile_definitions($<$<CONFIG:Debug>:UNIV_DEBUG>)

# Silence Clang-only warning that fires on some constexpr comparisons in headers
add_compile_options($<$<CXX_COMPILER_ID:Clang>:-Wno-tautological-constant-out-of-range-compare>)

# GCC: Avoid "_FORTIFY_SOURCE requires compiling with optimization (-O)" in Debug/coverage builds
# - Some environments enable fortify by default; it requires -O1 or higher.
# - In Debug and when coverage forces -O0, force _FORTIFY_SOURCE to 0 at the end of flags.
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    if(CMAKE_BUILD_TYPE STREQUAL "Debug" OR ENABLE_GCOV)
        set(FORTIFY_OFF_FLAGS "-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0")
        set(CMAKE_CXX_FLAGS   "${CMAKE_CXX_FLAGS} ${FORTIFY_OFF_FLAGS}")
    endif()
endif()

# Collect all options here
option(ENABLE_GCOV                "Enable GCOV code coverage"                  OFF)
option(ENABLE_UNIT_TESTING        "Enable Unit Tests"                          ON)
option(ENABLE_INTEGRATION_TESTING "Enable Integration Tests"                   ON)
option(ENABLE_XA                  "Enable XA"                                  ON)
option(ENABLE_INNODB_LUA          "Enable InnoDB LUA Bindings"                 ON)
option(ENABLE_SANITIZERS          "Enable sanitizers (ASAN, TSAN, UBSAN)"      OFF)
option(ENABLE_UNITY_BUILD         "Enable unity builds for faster compilation" OFF)
option(ENABLE_IPO                 "Enable Interprocedural Optimization (LTO)"  OFF)
option(ENABLE_CCACHE              "Enable ccache for faster rebuilds"          ON)
option(ENABLE_CLANG_TIDY          "Enable clang-tidy static analysis"          OFF)

# Report all options
# Add to cmake/ci_matrix.cmake
message(STATUS "")
message(STATUS "=== Embedded InnoDB Configuration Summary ===")
message(STATUS "Version:                  ${VERSION}")
message(STATUS "API Version:              ${IB_API_VERSION_STRING}")
message(STATUS "Build Type:               ${CMAKE_BUILD_TYPE}")
message(STATUS "C++ Compiler:             ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
message(STATUS "Install Prefix:           ${CMAKE_INSTALL_PREFIX}")
message(STATUS "")
message(STATUS "Features:")
message(STATUS "  Unit Tests:                   ${ENABLE_UNIT_TESTING}")
message(STATUS "  Integration Tests:            ${ENABLE_INTEGRATION_TESTING}")
message(STATUS "  GCOV Coverage:                ${ENABLE_GCOV}")
message(STATUS "  XA Support:                   ${ENABLE_XA}")
message(STATUS "  Lua Bindings:                 ${ENABLE_INNODB_LUA}")
message(STATUS "  Sanitizers:                   ${ENABLE_SANITIZERS}")
message(STATUS "  Unity Build:                  ${ENABLE_UNITY_BUILD}")
message(STATUS "  Interprocedural Optimization: ${ENABLE_IPO}")
message(STATUS "  ccache:                       ${ENABLE_CCACHE}")
message(STATUS "  clang-tidy:                   ${ENABLE_CLANG_TIDY}")
message(STATUS "")
message(STATUS "Dependencies:")
message(STATUS "  liburing:       ${LIBURING_VERSION}")
message(STATUS "  BS Thread Pool: ${BS_THREAD_POOL_VERSION}")
message(STATUS "  BISON:          ${BISON_VERSION}")
message(STATUS "  FLEX:           ${FLEX_VERSION}")
message(STATUS "  GTest:          ${GTest_VERSION}")
message(STATUS "")

