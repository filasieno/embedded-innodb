# ---------------------------------------------------------------------------------------------------------------------
# Embedded InnoDB Module Definitions and Library Assembly
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# innodb_create_object_library
# ---------------------------------------------------------------------------------------------------------------------
#
# innodb_create_object_library(name source_files include_dirs [extra_compile_options...])
#
# Creates an OBJECT library with common Embedded InnoDB settings.
#
# Parameters:
#   name: Name of the OBJECT library to create
#   source_files: List of source files (or GLOB expression)
#   include_dirs: List of include directories
#   extra_compile_options: Optional additional compile options
#
# Sets up:
#   - POSITION_INDEPENDENT_CODE for shared library compatibility
#   - C++23 standard
#   - Common compile options (warnings suppression)
#   - Include directories
#
function(innodb_create_object_library name source_files include_dirs)
    # Create the object library
    add_library(${name} OBJECT ${source_files})

    # Configure target properties
    set_target_properties(${name} PROPERTIES POSITION_INDEPENDENT_CODE ON)
    target_compile_features(${name} PRIVATE cxx_std_23)
    target_compile_options(${name} PRIVATE $<$<CXX_COMPILER_ID:Clang>:-Wno-tautological-constant-out-of-range-compare>)

    # Set include directories
    target_include_directories(${name} PRIVATE ${include_dirs})

    # Apply any additional compile options
    foreach(option IN LISTS ARGN)
        target_compile_options(${name} PRIVATE ${option})
    endforeach()
endfunction()

# This file defines the modular structure of Embedded InnoDB and orchestrates the build
# of the final monolithic library from individual modules. The build system uses an
# OBJECT library approach for efficient compilation and linking.
#
# Architecture:
# - Each module is compiled as an OBJECT library for maximum flexibility
# - Objects are aggregated into a single static library (innodb)
# - A shared library variant (innodb_shared) is also built
# - SQL parser is generated from FLEX/BISON grammar files
#
# Key Functions:
# - innodb_module(): Creates an OBJECT library for a specific module
# - innodb_create_object_library(): Creates OBJECT library with common settings
# - Final aggregation: Combines all module objects into complete libraries
#
# Module List: api, btr, buf, data, ddl, dict, eval, fil, fsp, fut, lock, log, mach,
#              mem, mtr, os, page, pars, que, read, rem, row, srv, sync, trx, usr, ut

# Precompiled Headers Setup
# -------------------------
include(${CMAKE_CURRENT_LIST_DIR}/precompiled.cmake)

# Module Creation Function
# -----------------------
#
# innodb_module(module_dir)
#
# Creates an OBJECT library for the specified Embedded InnoDB module and registers
# it for aggregation into the final library. This function handles the common pattern
# of creating modular compilation units.
#
# Parameters:
#   module_dir: Name of the module directory under innodb/src/ (e.g., "api", "buf")
#
# Creates:
#   - OBJECT library: mod_${module_dir} (e.g., mod_api, mod_buf)
#   - Registers objects for final library aggregation via INNODB_OBJ_TARGETS
#
# Features:
#   - Automatic source discovery from module directory
#   - Common include paths and compilation settings
#   - GCOV coverage support when enabled
#   - Position-independent code for shared library compatibility
#
# Reference: https://cmake.org/cmake/help/v3.31/command/target_link_libraries.html#id8
#
# ---------------------------------------------------------------------------------------------------------------------

# Include Directory Configuration
# -----------------------------
# Define include directories with clear separation of public/private and generated headers.
# This ensures proper encapsulation and prevents accidental exposure of internal headers.

# Public Includes: API headers exposed to library users
set(INNODB_PUBLIC_INCLUDE            "${CMAKE_SOURCE_DIR}/innodb/include"     )

# Private Includes: Internal headers not exposed in public API
set(INNODB_PRIVATE_INCLUDE           "${CMAKE_SOURCE_DIR}/innodb/src/include" )

# Generated Private Includes: Build-generated headers for internal use
set(INNODB_GENERATED_PRIVATE_INCLUDE "${INNODB_PRIVATE_GENERATED_INCLUDE_DIR}" )

# Generated Public Includes: Build-generated headers that may be exposed
set(INNODB_GENERATED_PUBLIC_INCLUDE  "${INNODB_PRIVATE_GENERATED_INCLUDE_DIR}" )

# Common Include Set: All include directories used by modules
set(INNODB_COMMON_INCLUDES "${INNODB_PUBLIC_INCLUDE}"
                           "${INNODB_PRIVATE_INCLUDE}"
                           "${INNODB_GENERATED_PRIVATE_INCLUDE}"
                           "${INNODB_GENERATED_PUBLIC_INCLUDE}"
)

# ---------------------------------------------------------------------------------------------------------------------
# Per-Module Object Library Creation
# ---------------------------------------------------------------------------------------------------------------------

function(innodb_module module_dir)

    # Define per-module `object_target` (single compilation point for the module)
    set(object_target "mod_${module_dir}")

    # Gather sources for this module - CMake checks for file changes on rebuilds
    file(GLOB module_sources CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/innodb/src/${module_dir}/*.cc")

    # Create the object
    add_library(${object_target} OBJECT ${module_sources})

    # Define the target include directories
    target_include_directories(${object_target} PRIVATE "${CMAKE_SOURCE_DIR}/innodb/src/${module_dir}" "${INNODB_COMMON_INCLUDES}")

    # Add external library dependecies
    target_link_libraries(${object_target} PRIVATE PkgConfig::LIBURING)

    # ...
    target_compile_features(${object_target} PRIVATE cxx_std_23)

    # Ensure position independent code so objects can link into shared libs
    set_target_properties(${object_target} PROPERTIES POSITION_INDEPENDENT_CODE ON)

    # Step 3 — Register object target for the final aggregated library
    set_property(GLOBAL APPEND PROPERTY INNODB_OBJ_TARGETS ${object_target})

    set_target_properties(${object_target} PROPERTIES FOLDER "innodb")
    if(INNODB_ENABLE_GCOV)
        if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
            if(NOT CMAKE_BUILD_TYPE STREQUAL "Debug")
                message(WARNING "Coverage is best with Debug; current: ${CMAKE_BUILD_TYPE}")
            endif()
            target_compile_options(${object_target} PRIVATE -O0 -g --coverage)
            target_link_options(${object_target} PRIVATE --coverage)
            message(STATUS "coverage flags enabled for ${object_target}")
        else()
            message(FATAL_ERROR "Coverage: unsupported compiler ${CMAKE_CXX_COMPILER_ID}")
        endif()
    endif()

    # Temp fix
    target_compile_options(${object_target} PRIVATE $<$<CXX_COMPILER_ID:Clang>:-Wno-tautological-constant-out-of-range-compare>)
endfunction()
# end `innodb_module(module_dir)` function

# ---------------------------------------------------------------------------------------------------------------------
# SQL Parser Generation (Flex/Bison)
# ---------------------------------------------------------------------------------------------------------------------
# Generate C++ source files from SQL grammar definitions using Flex and Bison.
# This creates the SQL parser used by Embedded InnoDB for query processing.
#
# Generated files are placed in the build directory to avoid polluting the source tree.

# Output directory for generated parser files
set(GEN_PARS_DIR ${CMAKE_BINARY_DIR}/innodb/generated/pars)
file(MAKE_DIRECTORY ${GEN_PARS_DIR} ${INNODB_PRIVATE_GENERATED_INCLUDE_DIR})

# Bison Grammar Processing
# -----------------------
# Generate parser from YACC grammar file
bison_target(innodb_parser ${CMAKE_SOURCE_DIR}/innodb/src/pars/pars0grm.y
             ${GEN_PARS_DIR}/pars0grm.cc
             DEFINES_FILE ${INNODB_PRIVATE_GENERATED_INCLUDE_DIR}/pars0grm.h
             VERBOSE ${GEN_PARS_DIR}/bison.log)

# Flex Lexer Processing
# --------------------
# Generate lexer from lexical grammar file
flex_target(innodb_lexer ${CMAKE_SOURCE_DIR}/innodb/src/pars/pars0lex.l
            ${GEN_PARS_DIR}/lexyy.cc)

# Dependency Management
# --------------------
# Ensure lexer is rebuilt when parser changes
add_flex_bison_dependency(innodb_lexer innodb_parser)

# SQL Parser Object Library
# ------------------------
# Create OBJECT library for generated parser sources
add_library(innodb_sql OBJECT ${BISON_innodb_parser_OUTPUTS} ${FLEX_innodb_lexer_OUTPUTS})
target_include_directories(innodb_sql PRIVATE
    ${CMAKE_SOURCE_DIR}/innodb/include
    ${CMAKE_SOURCE_DIR}/innodb/src/include
    ${INNODB_PRIVATE_GENERATED_INCLUDE_DIR}  # Generated parser headers
    ${GEN_PARS_DIR}
)
set_target_properties(innodb_sql PROPERTIES FOLDER "innodb")
set_target_properties(innodb_sql PROPERTIES POSITION_INDEPENDENT_CODE ON)
set_property(GLOBAL APPEND PROPERTY INNODB_OBJ_TARGETS innodb_sql)


# ---------------------------------------------------------------------------------------------------------------------
# Module Registration
# ---------------------------------------------------------------------------------------------------------------------
# Register all Embedded InnoDB modules for compilation. Each module represents a
# functional area of the database engine. Modules are processed in dependency order
# to ensure correct linking.
innodb_module("ut")
innodb_module("mach")
innodb_module("os")
innodb_module("mem")
innodb_module("sync")
innodb_module("fut")
innodb_module("log")
innodb_module("fil")
innodb_module("fsp")
innodb_module("buf")
innodb_module("page")
innodb_module("data")
innodb_module("rem")
innodb_module("mtr")
innodb_module("btr")
innodb_module("row")
innodb_module("trx")
innodb_module("lock")
innodb_module("read")
innodb_module("dict")
innodb_module("ddl")
innodb_module("pars")
innodb_module("eval")
innodb_module("que")
innodb_module("srv")
innodb_module("usr")
innodb_module("api")

# ---------------------------------------------------------------------------------------------------------------------
# Final Library Assembly
# ---------------------------------------------------------------------------------------------------------------------
# Aggregate all compiled module objects into the final Embedded InnoDB libraries.
# This creates both static and shared library variants from the same object files.

# Object Collection
# ----------------
# Retrieve all registered OBJECT targets and expand them to object file references
get_property(INNODB_OBJ_TARGETS GLOBAL PROPERTY INNODB_OBJ_TARGETS)

# Expand objects from all modules into a single list for library creation
set(INNODB_ALL_OBJECTS)
foreach(obj_tgt IN LISTS INNODB_OBJ_TARGETS)
    list(APPEND INNODB_ALL_OBJECTS $<TARGET_OBJECTS:${obj_tgt}>)
endforeach()

# Static Library Creation
# ----------------------
# Build the monolithic static library from all module objects
add_library(innodb STATIC ${INNODB_ALL_OBJECTS})
set_target_properties(innodb PROPERTIES FOLDER "innodb")
target_compile_features(innodb PRIVATE cxx_std_23)
target_compile_options(innodb PRIVATE $<$<CXX_COMPILER_ID:Clang>:-Wno-tautological-constant-out-of-range-compare>)

# Public interface: Only expose public headers to consumers
target_include_directories(innodb PUBLIC $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/innodb/include>)

# Private includes: Internal headers only (not exposed to library users)
target_include_directories(innodb PRIVATE
  ${CMAKE_SOURCE_DIR}/innodb/src/include
  ${INNODB_GENERATED_PRIVATE_INCLUDE}
)

# Header File Set Management
# -------------------------
# Use FILE_SET for better header file organization (CMake 3.23+)
target_sources(innodb PUBLIC FILE_SET HEADERS
    BASE_DIRS ${CMAKE_SOURCE_DIR}/innodb/include
    FILES ${CMAKE_SOURCE_DIR}/innodb/include/innodb.h
)

# Link dependencies and precompiled headers
target_link_libraries(innodb PRIVATE innodb_pch)
target_link_libraries(innodb PUBLIC PkgConfig::LIBURING)
target_compile_definitions(innodb PUBLIC HAVE_LIBURING)

# Add sanitizer link options when enabled
target_link_options(innodb PRIVATE
    $<$<AND:$<CXX_COMPILER_ID:Clang>,$<BOOL:${INNODB_ENABLE_ASAN}>>:-fsanitize=address>
    $<$<AND:$<CXX_COMPILER_ID:Clang>,$<BOOL:${INNODB_ENABLE_TSAN}>>:-fsanitize=thread>
    $<$<AND:$<CXX_COMPILER_ID:Clang>,$<BOOL:${INNODB_ENABLE_UBSAN}>>:-fsanitize=undefined>
)

# Shared Library Creation
# ----------------------
# Build shared library variant from the same objects
add_library(innodb_shared SHARED ${INNODB_ALL_OBJECTS})
set_target_properties(innodb_shared PROPERTIES OUTPUT_NAME innodb FOLDER "innodb")
target_compile_features(innodb_shared PRIVATE cxx_std_23)
target_compile_options(innodb_shared PRIVATE $<$<CXX_COMPILER_ID:Clang>:-Wno-tautological-constant-out-of-range-compare>)

# Same include configuration as static library
target_include_directories(innodb_shared PUBLIC $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/innodb/include>)
target_include_directories(innodb_shared PRIVATE
  ${CMAKE_SOURCE_DIR}/innodb/src/include
  ${INNODB_GENERATED_PRIVATE_INCLUDE}
)

# Same header file set as static library
target_sources(innodb_shared PUBLIC FILE_SET HEADERS
    BASE_DIRS ${CMAKE_SOURCE_DIR}/innodb/include
    FILES ${CMAKE_SOURCE_DIR}/innodb/include/innodb.h
)

# Same dependencies as static library
target_link_libraries(innodb_shared PUBLIC PkgConfig::LIBURING)
target_compile_definitions(innodb_shared PUBLIC HAVE_LIBURING)

# Add sanitizer link options when enabled
target_link_options(innodb_shared PRIVATE
    $<$<AND:$<CXX_COMPILER_ID:Clang>,$<BOOL:${INNODB_ENABLE_ASAN}>>:-fsanitize=address>
    $<$<AND:$<CXX_COMPILER_ID:Clang>,$<BOOL:${INNODB_ENABLE_TSAN}>>:-fsanitize=thread>
    $<$<AND:$<CXX_COMPILER_ID:Clang>,$<BOOL:${INNODB_ENABLE_UBSAN}>>:-fsanitize=undefined>
)
