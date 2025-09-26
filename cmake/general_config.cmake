# ---------------------------------------------------------------------------------------------------------------------
# General configuration
# ---------------------------------------------------------------------------------------------------------------------

cmake_minimum_required(VERSION 3.24)

project(embedded-innodb LANGUAGES C CXX)

# C++ standard
set(CMAKE_CXX_STANDARD            23)
set(CMAKE_CXX_STANDARD_REQUIRED   ON)
set(CMAKE_CXX_EXTENSIONS          OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(CMAKE_EXPORT_COMPILE_COMMANDS)
    add_custom_target(export_compile_commands ALL
        COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_SOURCE_DIR}/build
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                ${CMAKE_BINARY_DIR}/compile_commands.json
                ${CMAKE_SOURCE_DIR}/build/compile_commands.json
        BYPRODUCTS ${CMAKE_SOURCE_DIR}/build/compile_commands.json
        COMMENT "Copy compile_commands.json to source-root build/"
        VERBATIM
    )
endif()

# Objective: Centralize all binary outputs for predictable, clean build artifacts
# - Static libraries in:   ${CMAKE_BINARY_DIR}/innodb/lib
# - Shared libraries in:   ${CMAKE_BINARY_DIR}/innodb/lib
# - Runtimes (if any) in:  ${CMAKE_BINARY_DIR}/innodb/lib
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/innodb/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/innodb/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/innodb/lib)

# Ensure that the required dependecies are available
find_package(PkgConfig REQUIRED)
find_package(FLEX      REQUIRED)
find_package(BISON     REQUIRED)

pkg_check_modules(BS_THREAD_POOL REQUIRED bs-thread-pool)
pkg_check_modules(LIBURING       IMPORTED_TARGET liburing)

# OptionalL if available use `ccache`
find_program(CCACHE_PROGRAM ccache)
if(CCACHE_PROGRAM)
    set(CMAKE_C_COMPILER_LAUNCHER   "${CCACHE_PROGRAM}")
    set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
endif()

# ---------------------------------------------------------------------------------------------------------------------
# end General configuration
# ---------------------------------------------------------------------------------------------------------------------
