# ---------------------------------------------------------------------------------------------------------------------
# Embedded InnoDB module definitions
# ---------------------------------------------------------------------------------------------------------------------

# Include precompiled headers configuration
include(${CMAKE_CURRENT_LIST_DIR}/precompiled.cmake)
# Define helper to create per-module targets and register their objects for aggregation
#
# innodb_module(<module_dir>) performs:
#   1) Gather sources for the module
#   2) Create an OBJECT library to compile sources once with common flags/includes
#   3) Register the OBJECT target so the final monolithic lib can aggregate all objects
#
# https://cmake.org/cmake/help/v3.31/command/target_link_libraries.html#id8
#
# ---------------------------------------------------------------------------------------------------------------------

# Explicitly define the include directories according to its usage:
# - public
# - private
# - generated (can be both public or private, in this case is just private)

set(INNODB_PUBLIC_INCLUDE            "${CMAKE_SOURCE_DIR}/innodb/include"     )
set(INNODB_PRIVATE_INCLUDE           "${CMAKE_SOURCE_DIR}/innodb/src/include" )
set(INNODB_GENERATED_PRIVATE_INCLUDE "${CMAKE_BINARY_DIR}/innodb/include"     )
set(INNODB_GENERATED_PUBLIC_INCLUDE  "${CMAKE_BINARY_DIR}/include"             )

set(INNODB_COMMON_INCLUDES "${INNODB_PUBLIC_INCLUDE}"
                           "${INNODB_PRIVATE_INCLUDE}"
                           "${INNODB_GENERATED_PRIVATE_INCLUDE}"
                           "${INNODB_GENERATED_PUBLIC_INCLUDE}"
)

# ---------------------------------------------------------------------------------------------------------------------
# Define per-module `object_target` (single compilation point for the module)
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
    if(ENABLE_GCOV)
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
# Generate Flex/Bison sources into the build tree (avoid polluting source dir)
# ---------------------------------------------------------------------------------------------------------------------

set(GEN_PARS_DIR ${CMAKE_BINARY_DIR}/innodb/generated/pars)
file(MAKE_DIRECTORY ${GEN_PARS_DIR})


bison_target(innodb_parser ${CMAKE_SOURCE_DIR}/innodb/src/pars/pars0grm.y  ${GEN_PARS_DIR}/pars0grm.cc DEFINES_FILE ${CMAKE_BINARY_DIR}/include/pars0grm.h VERBOSE ${GEN_PARS_DIR}/bison.log)
flex_target(innodb_lexer   ${CMAKE_SOURCE_DIR}/innodb/src/pars/pars0lex.l  ${GEN_PARS_DIR}/lexyy.cc)
add_flex_bison_dependency(innodb_lexer innodb_parser)

add_library(innodb_sql OBJECT ${BISON_innodb_parser_OUTPUTS} ${FLEX_innodb_lexer_OUTPUTS})
target_include_directories(innodb_sql PRIVATE
    ${CMAKE_SOURCE_DIR}/innodb/include
    ${CMAKE_SOURCE_DIR}/innodb/src/include
    ${CMAKE_BINARY_DIR}/include
    ${GEN_PARS_DIR}
)
set_target_properties(innodb_sql PROPERTIES FOLDER "innodb")
set_target_properties(innodb_sql PROPERTIES POSITION_INDEPENDENT_CODE ON)
set_property(GLOBAL APPEND PROPERTY INNODB_OBJ_TARGETS innodb_sql)


# ---------------------------------------------------------------------------------------------------------------------
# Register all modules
# ---------------------------------------------------------------------------------------------------------------------
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

# Objective: Resolve all registered module OBJECT targets and expand them to object files
get_property(INNODB_OBJ_TARGETS GLOBAL PROPERTY INNODB_OBJ_TARGETS)

# Ensure the pars module sees generated headers: add directory and order via innodb_sql already

# Expand objects from all modules
set(INNODB_ALL_OBJECTS)
foreach(obj_tgt IN LISTS INNODB_OBJ_TARGETS)
    list(APPEND INNODB_ALL_OBJECTS $<TARGET_OBJECTS:${obj_tgt}>)
endforeach()

# Objective: Build the final monolithic static library from every module's objects
# - Keeps per-module libs for modular linking/testing
# - Provides a single aggregate `innodb` archive
add_library(innodb STATIC ${INNODB_ALL_OBJECTS})
set_target_properties(innodb PROPERTIES FOLDER "innodb")
target_compile_features(innodb PRIVATE cxx_std_23)
target_compile_options(innodb PRIVATE $<$<CXX_COMPILER_ID:Clang>:-Wno-tautological-constant-out-of-range-compare>)
target_include_directories(innodb PUBLIC $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/innodb/include>)
target_include_directories(innodb PRIVATE
  ${CMAKE_SOURCE_DIR}/innodb/src/include
  ${CMAKE_BINARY_DIR}/include
)
# Link to PCH interface library to get precompiled headers and common settings
target_link_libraries(innodb PRIVATE innodb_pch)

target_link_libraries(innodb PUBLIC PkgConfig::LIBURING)
target_compile_definitions(innodb PUBLIC HAVE_LIBURING)

# Build a shared library from the same object files
add_library(innodb_shared SHARED ${INNODB_ALL_OBJECTS})
set_target_properties(innodb_shared PROPERTIES OUTPUT_NAME innodb FOLDER "innodb")
target_compile_features(innodb_shared PRIVATE cxx_std_23)
target_compile_options(innodb_shared PRIVATE $<$<CXX_COMPILER_ID:Clang>:-Wno-tautological-constant-out-of-range-compare>)
target_include_directories(innodb_shared PUBLIC $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/innodb/include>)
target_include_directories(innodb_shared PRIVATE
  ${CMAKE_SOURCE_DIR}/innodb/src/include
  ${CMAKE_BINARY_DIR}/include
)
target_link_libraries(innodb_shared PUBLIC PkgConfig::LIBURING)
target_compile_definitions(innodb_shared PUBLIC HAVE_LIBURING)
