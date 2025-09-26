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
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_C_COMPILER_ID STREQUAL "GNU")
    if(CMAKE_BUILD_TYPE STREQUAL "Debug" OR ENABLE_GCOV)
        set(FORTIFY_OFF_FLAGS "-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0")
        set(CMAKE_C_FLAGS   "${CMAKE_C_FLAGS} ${FORTIFY_OFF_FLAGS}")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${FORTIFY_OFF_FLAGS}")
    endif()
endif()

# Collect all options here
option(ENABLE_GCOV                "Enable GCOV code coverage"  OFF)
option(ENABLE_UNIT_TESTING        "Enable Unit Tests"          ON)
option(ENABLE_INTEGRATION_TESTING "Enable Integration Tests"   ON)
option(ENABLE_XA                  "Enable XA"                  ON)
option(ENABLE_INNODB_LUA          "Enable InnoDB LUA Bindings" ON)

# Report all options
message(STATUS "CMAKE_CXX_COMPILER_ID       " ${CMAKE_CXX_COMPILER_ID})
message(STATUS "CMAKE_CXX_COMPILER          " ${CMAKE_CXX_COMPILER})
message(STATUS "CMAKE_CXX_COMPILER_VERSION  " ${CMAKE_CXX_COMPILER_VERSION})
message(STATUS "ENABLE_GCOV                 " ${ENABLE_GCOV})
message(STATUS "ENABLE_UNIT_TESTING         " ${ENABLE_UNIT_TESTING})
message(STATUS "ENABLE_INTEGRATION_TESTING  " ${ENABLE_INTEGRATION_TESTING})
message(STATUS "ENABLE_XA                   " ${ENABLE_XA})
message(STATUS "ENABLE_INNODB_LUA           " ${ENABLE_INNODB_LUA})

# ---------------------------------------------------------------------------------------------------------------------
# end Setup CI Build Matrix and Build options
# ---------------------------------------------------------------------------------------------------------------------
