cmake_minimum_required(VERSION 3.24)

project(embedded-innodb LANGUAGES C CXX)

# ---------------------------------------------------------------------------------------------------------------------
# General configuration
# ---------------------------------------------------------------------------------------------------------------------
#
#
#
#
#
#
#
#
#
#
#
# ---------------------------------------------------------------------------------------------------------------------

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
# Library and API Versioning section
# ---------------------------------------------------------------------------------------------------------------------
#
#
#
#
#
#
#
#
#
#
#
# ---------------------------------------------------------------------------------------------------------------------

# Define the version for Embedded InnoDB
set(VERSION "0.1")

# Define the API version
set(API_VERSION          6)   # Increment if interfaces have been added, removed or changed
set(API_VERSION_REVISION 0)   # Increment if source code has changed, set to zero if current is incremented
set(API_VERSION_AGE      0)   # Increment if interfaces have been added, set to zero if interfaces have been removed or changed

# API version string used in compile definitions later
set(IB_API_VERSION_STRING "${API_VERSION}:${API_VERSION_REVISION}:${API_VERSION_AGE}")
message(STATUS "VERSION:               " ${VERSION})
message(STATUS "IB_API_VERSION_STRING: " ${IB_API_VERSION_STRING})
# ---------------------------------------------------------------------------------------------------------------------
# end Library and API Versioning section







# ---------------------------------------------------------------------------------------------------------------------
# Setup CI Build Matrix and Build options
# ---------------------------------------------------------------------------------------------------------------------
#
#
#
#
#
#
#
#
#
#
#
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
# ---------------------------------------------------------------------------------------------------------------------
# end Setup CI Build Matrix and Build options

# Collect all options here
option(ENABLE_GCOV                "Enable GCOV code coverage"  OFF)
option(ENABLE_UNIT_TESTING        "Enable Unit Tests"          ON)
option(ENABLE_INTEGRATION_TESTING "Enable Integration Tests"   ON)
option(ENABLE_XA                  "Enable XA"                  ON)
option(ENABLE_INNODB_LUA          "Enable InnoDB LUA Bindings" ON)

# Report all options
message(STATUS "CMAKE_CXX_COMPILER_ID               " ${CMAKE_CXX_COMPILER_ID})
message(STATUS "CMAKE_CXX_COMPILER                  " ${CMAKE_CXX_COMPILER})
message(STATUS "CMAKE_CXX_COMPILER_VERSION          " ${CMAKE_CXX_COMPILER_VERSION})
message(STATUS "ENABLE_GCOV                         " ${ENABLE_GCOV})
message(STATUS "ENABLE_UNIT_TESTING                 " ${ENABLE_UNIT_TESTING})
message(STATUS "ENABLE_INTEGRATION_TESTING          " ${ENABLE_INTEGRATION_TESTING})
message(STATUS "ENABLE_XA                           " ${ENABLE_XA})
message(STATUS "ENABLE_INNODB_LUA                   " ${ENABLE_INNODB_LUA})

# ---------------------------------------------------------------------------------------------------------------------
# Configuration checks (to generate ib0config.h)
# ---------------------------------------------------------------------------------------------------------------------
#
#
#
#
#
#
#
#
#
#
# ---------------------------------------------------------------------------------------------------------------------
include(CheckTypeSize)
include(CheckIncludeFiles)

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

set(CMAKE_EXTRA_INCLUDE_FILES pthread.h)
check_type_size(pthread_t SIZEOF_PTHREAD_T)
set(CMAKE_EXTRA_INCLUDE_FILES)

check_include_files("stdint.h"            HAVE_STDINT_H)

# Objective: Generate configuration header used by sources during compilation
file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/include)
configure_file(
    ${CMAKE_SOURCE_DIR}/cmake/config.h.cmake
    ${CMAKE_BINARY_DIR}/include/ib0config.h
)

# Objective: Define a single PCH target to be reused by all module/object/static targets
# - Every module links against this to share common includes/defs
add_library(innodb_pch INTERFACE)

# Propagate common include directories and compile definitions via innodb_pch
target_include_directories(innodb_pch INTERFACE
    ${CMAKE_SOURCE_DIR}/innodb/src/include
    ${CMAKE_SOURCE_DIR}/innodb/include
    ${CMAKE_BINARY_DIR}/include
    ${BS_THREAD_POOL_INCLUDE_DIRS}
    ${LIBURING_INCLUDE_DIRS}
    ${FLEX_INCLUDE_DIR}
)
target_compile_definitions(innodb_pch INTERFACE
  $<$<CONFIG:Debug>:UNIV_DEBUG>
  UNIV_LINUX
)

# Propagate liburing feature macro to all targets consuming the PCH
if(LIBURING_FOUND)
    target_compile_definitions(innodb_pch INTERFACE HAVE_LIBURING)
endif()

# Build PCH using CMake's native support so each consumer compiles with identical flags
# Build a single GCC PCH once and share it via -include
set(PCH_HEADER_SRC ${CMAKE_SOURCE_DIR}/innodb/src/pch/innodb_pch.h)
set(PCH_DIR        ${CMAKE_BINARY_DIR}/pch)
set(PCH_HEADER     ${PCH_DIR}/innodb_pch.h)
set(PCH_GCH        ${PCH_DIR}/innodb_pch.h.gch)

set(PCH_INCLUDE_FLAGS)
foreach(_dir ${CMAKE_SOURCE_DIR}/innodb/src/include ${CMAKE_SOURCE_DIR}/innodb/include ${CMAKE_BINARY_DIR}/include ${BS_THREAD_POOL_INCLUDE_DIRS} ${LIBURING_INCLUDE_DIRS})
  list(APPEND PCH_INCLUDE_FLAGS -I${_dir})
endforeach()

set(PCH_CXX_FLAGS_LIST)
set(_PCH_BASE_FLAGS "${CMAKE_CXX_FLAGS}")
separate_arguments(_PCH_BASE_FLAGS_LIST UNIX_COMMAND "${_PCH_BASE_FLAGS}")
list(APPEND PCH_CXX_FLAGS_LIST ${_PCH_BASE_FLAGS_LIST})

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(_PCH_DEBUG_FLAGS "${CMAKE_CXX_FLAGS_DEBUG}")
  separate_arguments(_PCH_DEBUG_FLAGS_LIST UNIX_COMMAND "${_PCH_DEBUG_FLAGS}")
  list(APPEND PCH_CXX_FLAGS_LIST ${_PCH_DEBUG_FLAGS_LIST})
endif()

if(ENABLE_GCOV)
  if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    list(APPEND PCH_CXX_FLAGS_LIST -O0 -g --coverage)
  endif()
endif()

if(DEFINED ENV{CPPFLAGS})
  set(_PCH_ENV_CPP "$ENV{CPPFLAGS}")
  separate_arguments(_PCH_ENV_CPP_LIST UNIX_COMMAND "${_PCH_ENV_CPP}")
  list(APPEND PCH_CXX_FLAGS_LIST ${_PCH_ENV_CPP_LIST})
endif()
if(DEFINED ENV{CXXFLAGS})
  set(_PCH_ENV_CXX "$ENV{CXXFLAGS}")
  separate_arguments(_PCH_ENV_CXX_LIST UNIX_COMMAND "${_PCH_ENV_CXX}")
  list(APPEND PCH_CXX_FLAGS_LIST ${_PCH_ENV_CXX_LIST})
endif()
if(DEFINED ENV{NIX_CFLAGS_COMPILE})
  set(_PCH_ENV_NIX "$ENV{NIX_CFLAGS_COMPILE}")
  separate_arguments(_PCH_ENV_NIX_LIST UNIX_COMMAND "${_PCH_ENV_NIX}")
  list(APPEND PCH_CXX_FLAGS_LIST ${_PCH_ENV_NIX_LIST})
endif()

# Ensure fortify is disabled last in Debug/coverage for GCC for the PCH build too
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  if(CMAKE_BUILD_TYPE STREQUAL "Debug" OR ENABLE_GCOV)
    list(APPEND PCH_CXX_FLAGS_LIST -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 -Wno-cpp)
  endif()
endif()

set(PCH_FEATURE_DEFS)
if(LIBURING_FOUND)
  set(PCH_FEATURE_DEFS -DHAVE_LIBURING)
endif()

add_custom_command(OUTPUT ${PCH_GCH}
  COMMAND ${CMAKE_COMMAND} -E make_directory ${PCH_DIR}
  COMMAND ${CMAKE_COMMAND} -E copy_if_different ${PCH_HEADER_SRC} ${PCH_HEADER}
  COMMAND ${CMAKE_CXX_COMPILER} -x c++-header -std=c++23 -DUNIV_LINUX ${PCH_FEATURE_DEFS} ${PCH_INCLUDE_FLAGS} ${PCH_CXX_FLAGS_LIST} -o ${PCH_GCH} ${PCH_HEADER}
  DEPENDS ${PCH_HEADER_SRC}
  VERBATIM)

add_custom_target(innodb_pch_build ALL DEPENDS ${PCH_GCH})
set_target_properties(innodb_pch_build PROPERTIES FOLDER "innodb")


# Include Flex and Bison CMake modules


# Generate Flex/Bison sources into the build tree (avoid polluting source dir)
set(GEN_PARS_DIR ${CMAKE_BINARY_DIR}/generated/pars)
file(MAKE_DIRECTORY ${GEN_PARS_DIR})

find_package(BISON REQUIRED)
BISON_TARGET(innodb_parser ${CMAKE_SOURCE_DIR}/innodb/src/pars/pars0grm.y  ${GEN_PARS_DIR}/pars0grm.cc DEFINES_FILE ${CMAKE_BINARY_DIR}/include/pars0grm.h VERBOSE ${GEN_PARS_DIR}/bison.log)
find_package(FLEX REQUIRED)
FLEX_TARGET(innodb_lexer   ${CMAKE_SOURCE_DIR}/innodb/src/pars/pars0lex.l  ${GEN_PARS_DIR}/lexyy.cc)
ADD_FLEX_BISON_DEPENDENCY(innodb_lexer innodb_parser)
include_directories(${CMAKE_BINARY_DIR}/include ${GEN_PARS_DIR})

add_library(innodb_sql OBJECT ${BISON_innodb_parser_OUTPUTS} ${FLEX_innodb_lexer_OUTPUTS})
target_link_libraries(innodb_sql PRIVATE innodb_pch)
add_dependencies(innodb_sql innodb_pch_build)
target_compile_options(innodb_sql PRIVATE -include ${PCH_HEADER})
set_target_properties(innodb_sql PROPERTIES FOLDER "innodb")
set_target_properties(innodb_sql PROPERTIES POSITION_INDEPENDENT_CODE ON)
set_property(GLOBAL APPEND PROPERTY INNODB_OBJ_TARGETS innodb_sql)

# ---------------------------------------------------------------------------------------------------------------------
# Configuration checks (to generate ib0config.h)











# ---------------------------------------------------------------------------------------------------------------------
# Embedded InnoDB module definitions
# ---------------------------------------------------------------------------------------------------------------------
# Objective: Define helper to create per-module targets and register their objects for aggregation
#
# innodb_module(<module_dir>) performs:
#  1) Gather sources for the module
#  2) Create an OBJECT library to compile sources once with common flags/includes
#  3) Register the OBJECT target so the final monolithic lib can aggregate all objects
#
# ---------------------------------------------------------------------------------------------------------------------
function(innodb_module module_dir)

    # Step 1 — Gather sources for this module
    file(GLOB module_sources CONFIGURE_DEPENDS 
    "${CMAKE_SOURCE_DIR}/innodb/src/${module_dir}/*.cc")

    # # Exclude legacy monolithic file when modular sources exist to avoid duplicates
    # if(module_dir STREQUAL "log")
    #   # Exclude legacy monolithic implementation to avoid duplicate symbols
    #   list(FILTER module_sources EXCLUDE REGEX ".*/log0log\\.cc$")
    #   # Use canonical recovery implementation from log0recv.cc; exclude temporary split duplicates
    #   list(FILTER module_sources EXCLUDE REGEX ".*/recv_recovery\\.cc$")
    #   list(FILTER module_sources EXCLUDE REGEX ".*/recv_globals\\.cc$")
    #   list(FILTER module_sources EXCLUDE REGEX ".*/recv_parse\\.cc$")
    #   list(FILTER module_sources EXCLUDE REGEX ".*/recv_scan\\.cc$")
    # endif()

    # Step 2 — Define per-module OBJECT target (single compilation point for the module)
    set(obj_tgt "mod_${module_dir}")

    if(module_sources STREQUAL "")
        add_library(${obj_tgt} OBJECT)
    else()
        add_library(${obj_tgt} OBJECT ${module_sources})
    endif()
    target_compile_features(${obj_tgt} PRIVATE cxx_std_23)
    target_compile_options(${obj_tgt} PRIVATE $<$<CXX_COMPILER_ID:Clang>:-Wno-tautological-constant-out-of-range-compare>)
    target_include_directories(${obj_tgt}
    PRIVATE
        ${CMAKE_SOURCE_DIR}/innodb/src/${module_dir}
        ${CMAKE_SOURCE_DIR}/innodb/src/include
        ${CMAKE_SOURCE_DIR}/innodb/include
        ${CMAKE_BINARY_DIR}/include
        ${BS_THREAD_POOL_INCLUDE_DIRS}
        ${LIBURING_INCLUDE_DIRS}
    )
    target_link_libraries(${obj_tgt} PRIVATE innodb_pch)
    add_dependencies(${obj_tgt} innodb_pch_build)
    target_compile_options(${obj_tgt} PRIVATE -include ${PCH_HEADER})
    # Ensure position independent code so objects can link into shared libs
    set_target_properties(${obj_tgt} PROPERTIES POSITION_INDEPENDENT_CODE ON)

    # Step 3 — Register object target for the final aggregated library
    set_property(GLOBAL APPEND PROPERTY INNODB_OBJ_TARGETS ${obj_tgt})

    set_target_properties(${obj_tgt} PROPERTIES FOLDER "innodb")
    if(ENABLE_GCOV)
        if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
            if(NOT CMAKE_BUILD_TYPE STREQUAL "Debug")
                message(WARNING "Coverage is best with Debug; current: ${CMAKE_BUILD_TYPE}")
            endif()
            target_compile_options(${obj_tgt} PRIVATE -O0 -g --coverage)
            target_link_options(${obj_tgt} PRIVATE --coverage)
            message(STATUS "coverage flags enabled for ${obj_tgt}")
        else()
            message(FATAL_ERROR "Coverage: unsupported compiler ${CMAKE_CXX_COMPILER_ID}")
        endif()
    endif()

endfunction() 
# end `innodb_module(module_dir)` function

# Register all modules
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
  ${BS_THREAD_POOL_INCLUDE_DIRS}
  ${LIBURING_INCLUDE_DIRS}
)

if(LIBURING_FOUND)
    target_link_libraries(innodb PUBLIC PkgConfig::LIBURING)
    target_compile_definitions(innodb PUBLIC HAVE_LIBURING)
endif()

# Build a shared library from the same object files
add_library(innodb_shared SHARED ${INNODB_ALL_OBJECTS})
set_target_properties(innodb_shared PROPERTIES OUTPUT_NAME innodb FOLDER "innodb")
target_compile_features(innodb_shared PRIVATE cxx_std_23)
target_compile_options(innodb_shared PRIVATE $<$<CXX_COMPILER_ID:Clang>:-Wno-tautological-constant-out-of-range-compare>)
target_include_directories(innodb_shared PUBLIC $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/innodb/include>)
target_include_directories(innodb_shared PRIVATE
  ${CMAKE_SOURCE_DIR}/innodb/src/include
  ${CMAKE_BINARY_DIR}/include
  ${BS_THREAD_POOL_INCLUDE_DIRS}
  ${LIBURING_INCLUDE_DIRS}
)
if(LIBURING_FOUND)
    target_link_libraries(innodb_shared PUBLIC PkgConfig::LIBURING)
    target_compile_definitions(innodb_shared PUBLIC HAVE_LIBURING)
endif()

# ---------------------------------------------------------------------------------------------------------------------
# end Embedded InnoDB module definitions














# ---------------------------------------------------------------------------------------------------------------------
# Generate Doxygen Documentation
# ---------------------------------------------------------------------------------------------------------------------
#
#
#
#
#
# ---------------------------------------------------------------------------------------------------------------------
find_package(Doxygen)
if(DOXYGEN_FOUND)
    set(DOXYGEN_PROJECT_NAME       "Embedded InnoDB")
    set(DOXYGEN_GENERATE_HTML      YES)
    set(DOXYGEN_GENERATE_LATEX     NO)
    set(DOXYGEN_RECURSIVE          YES)
    set(DOXYGEN_OUTPUT_DIRECTORY   "${CMAKE_BINARY_DIR}/docs")
endif()


# ---------------------------------------------------------------------------------------------------------------------
# end Generate Doxygen Documentation









# ---------------------------------------------------------------------------------------------------------------------
# Install section
# ---------------------------------------------------------------------------------------------------------------------
#
#
#
#
# ---------------------------------------------------------------------------------------------------------------------
install(TARGETS innodb innodb_shared
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
)
install(FILES ${CMAKE_SOURCE_DIR}/innodb/include/innodb.h DESTINATION include)



# ---------------------------------------------------------------------------------------------------------------------
# Unit Test test setup section
# ---------------------------------------------------------------------------------------------------------------------
#
#
#
#
# ---------------------------------------------------------------------------------------------------------------------
set(UNIT_TEST_TARGET_FOLDER   "Unit Tests")
set(UNIT_TEST_ROOT_DIR        "${CMAKE_SOURCE_DIR}/innodb/unit-tests")
set(UNIT_TEST_SOURCE_DIR      "${UNIT_TEST_ROOT_DIR}/src")
set(UNIT_TEST_COMMON_INCLUDES "${CMAKE_SOURCE_DIR}/innodb/include"
                              "${CMAKE_SOURCE_DIR}/innodb/src/include"
                              "${CMAKE_BINARY_DIR}/include"
                              "${BS_THREAD_POOL_INCLUDE_DIRS}"
                              "${LIBURING_INCLUDE_DIRS}"
                              "${UNIT_TEST_SOURCE_DIR}/common")

file(GLOB UNIT_TEST_COMMON_SOURCE CONFIGURE_DEPENDS "${UNIT_TEST_SOURCE_DIR}/common/*.cc")
add_library(unit_test_common OBJECT ${UNIT_TEST_COMMON_SOURCE})
target_include_directories(unit_test_common PRIVATE ${UNIT_TEST_COMMON_INCLUDES})
target_compile_definitions(unit_test_common PRIVATE UNIV_BTR_PRINT UNIT_TESTING)
set_target_properties(unit_test_common PROPERTIES FOLDER ${UNIT_TEST_TARGET_FOLDER})
set(unit_test_common_libs GTest::gtest_main GTest::gtest innodb)
find_package(GTest REQUIRED)

# Ensure GTest headers are visible when compiling unit-test OBJECT libraries
get_target_property(GTEST_INCLUDE_DIRS GTest::gtest INTERFACE_INCLUDE_DIRECTORIES)
if(GTEST_INCLUDE_DIRS)
    list(APPEND UNIT_TEST_COMMON_INCLUDES ${GTEST_INCLUDE_DIRS})
endif()

# Reuse library PCH for unit test common objects (native CMake PCH)
target_link_libraries(unit_test_common PRIVATE innodb_pch)
add_dependencies(unit_test_common innodb_pch_build)
target_compile_options(unit_test_common PRIVATE -include ${PCH_HEADER})

function(innodb_gtest executable_name utest_folder)
    # Gather sources for this unit-test module
    file(GLOB unit_test_sources CONFIGURE_DEPENDS "${UNIT_TEST_SOURCE_DIR}/${utest_folder}/*.cc")

    # If liburing is absent, drop any io_uring-specific tests from this module
    if(NOT LIBURING_FOUND)
        list(FILTER unit_test_sources EXCLUDE REGEX ".*/log_io_uring\\.cc$")
    endif()

    # Create an OBJECT library for the module's tests
    set(obj_tgt "ut_obj_${executable_name}")
    if(unit_test_sources STREQUAL "")
        add_library(${obj_tgt} OBJECT)
    else()
        add_library(${obj_tgt} OBJECT ${unit_test_sources})
    endif()

    target_include_directories(${obj_tgt} PRIVATE ${UNIT_TEST_COMMON_INCLUDES} "${UNIT_TEST_SOURCE_DIR}/${utest_folder}")
    target_compile_definitions(${obj_tgt} PRIVATE UNIV_BTR_PRINT UNIT_TESTING)
    # Reuse the library PCH for all unit-test module compilations
    target_link_libraries(${obj_tgt} PRIVATE innodb_pch)
    add_dependencies(${obj_tgt} innodb_pch_build)
    target_compile_options(${obj_tgt} PRIVATE -include ${PCH_HEADER})
    set_target_properties(${obj_tgt} PROPERTIES FOLDER ${UNIT_TEST_TARGET_FOLDER})

    # Register the object target for aggregation later
    set_property(GLOBAL APPEND PROPERTY UNIT_TEST_OBJ_TARGETS ${obj_tgt})
endfunction()

# ---------------------------------------------------------------------------------------------------------------------
# Integration tests configuration
# ---------------------------------------------------------------------------------------------------------------------
#           | Executable name       | module folder     |
# ---------------------------------------------------------------------------------------------------------------------
innodb_gtest( utest_ut                modules/ut        )
innodb_gtest( utest_dyn               modules/dyn       )
innodb_gtest( utest_usr               modules/usr       )
innodb_gtest( utest_lock              modules/lock      )
innodb_gtest( utest_trx               modules/trx       )
innodb_gtest( utest_dict              modules/dict      )
innodb_gtest( utest_ddl               modules/ddl       )
innodb_gtest( utest_pars              modules/pars      )
innodb_gtest( utest_eval              modules/eval      )
innodb_gtest( utest_que               modules/que       )
innodb_gtest( utest_srv               modules/srv       )
innodb_gtest( utest_api               modules/api       )
innodb_gtest( utest_btr               modules/btr       )
innodb_gtest( utest_buf               modules/buf       )
innodb_gtest( utest_data              modules/data      )
innodb_gtest( utest_fil               modules/fil       )
innodb_gtest( utest_fsp               modules/fsp       )
innodb_gtest( utest_fut               modules/fut       )
innodb_gtest( utest_log               modules/log       )
innodb_gtest( utest_mach              modules/mach      )
innodb_gtest( utest_mem               modules/mem       )
innodb_gtest( utest_mtr               modules/mtr       )
innodb_gtest( utest_os                modules/os        )
innodb_gtest( utest_page              modules/page      )
innodb_gtest( utest_read              modules/read      )
innodb_gtest( utest_rem               modules/rem       )
innodb_gtest( utest_row               modules/row       )
innodb_gtest( utest_sync              modules/sync      )

# Aggregate all unit-test module objects into a single test executable
get_property(UNIT_TEST_OBJ_TARGETS GLOBAL PROPERTY UNIT_TEST_OBJ_TARGETS)
set(UNIT_TEST_ALL_OBJECTS)
foreach(obj_tgt IN LISTS UNIT_TEST_OBJ_TARGETS)
    list(APPEND UNIT_TEST_ALL_OBJECTS $<TARGET_OBJECTS:${obj_tgt}>)
endforeach()

add_executable(utest $<TARGET_OBJECTS:unit_test_common> ${UNIT_TEST_ALL_OBJECTS})
target_include_directories(utest PRIVATE ${UNIT_TEST_COMMON_INCLUDES})
target_compile_definitions(utest PRIVATE UNIV_BTR_PRINT UNIT_TESTING)
target_link_libraries(utest PRIVATE unit_test_common ${unit_test_common_libs} innodb_pch)
if(ENABLE_GCOV)
    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        target_link_options(utest PRIVATE --coverage)
    endif()
endif()
target_link_libraries(utest PRIVATE innodb_pch)
add_dependencies(utest innodb_pch_build)
target_compile_options(utest PRIVATE -include ${PCH_HEADER})
set_target_properties(utest PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/unit_tests/bin)
set_target_properties(utest PROPERTIES FOLDER ${UNIT_TEST_TARGET_FOLDER})

include(CTest)
include(GoogleTest)

gtest_discover_tests(utest
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/unit_tests/bin
    DISCOVERY_TIMEOUT 30
    PROPERTIES
        LABELS "unit"
        TIMEOUT 120
    XML_OUTPUT_DIR ${CMAKE_BINARY_DIR}/test-results/unit
)

# Convenience target: generate gcovr HTML and XML reports after tests
if(ENABLE_GCOV)
    find_program(GCOVR_BIN gcovr)
    if(GCOVR_BIN)
        set(COVERAGE_DIR ${CMAKE_BINARY_DIR}/build/innodb/coverage)
        add_custom_target(coverage
            COMMAND ${CMAKE_COMMAND} -E make_directory ${COVERAGE_DIR}
            COMMAND ${CMAKE_CTEST_COMMAND} --test-dir ${CMAKE_BINARY_DIR} --output-on-failure
            COMMAND ${GCOVR_BIN}
                    -r ${CMAKE_SOURCE_DIR}
                    ${CMAKE_BINARY_DIR}
                    --exclude '.*tests/.*'
                    --exclude '.*unit-tests/.*'
                    --xml -o ${COVERAGE_DIR}/coverage.xml
            COMMAND ${GCOVR_BIN}
                    -r ${CMAKE_SOURCE_DIR}
                    ${CMAKE_BINARY_DIR}
                    --exclude '.*tests/.*'
                    --exclude '.*unit-tests/.*'
                    --html --html-details -o ${COVERAGE_DIR}/coverage.html
            WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
            COMMENT "Running tests and generating coverage report with gcovr"
            VERBATIM
        )
    else()
        message(STATUS "gcovr not found; 'coverage' target will not be available")
    endif()
endif()
# ---------------------------------------------------------------------------------------------------------------------
# Integration test setup section
# ---------------------------------------------------------------------------------------------------------------------
#
#
#
#
# ---------------------------------------------------------------------------------------------------------------------
set(INTEGRATION_TEST_TARGET_FOLDER     "Integration Tests")
set(INTEGRATION_TEST_LIBS              pthread m)
set(INTEGRATION_TEST_ROOT_DIR          "${CMAKE_SOURCE_DIR}/innodb/tests")
set(INTEGRATION_TEST_SOURCE_DIR        "${INTEGRATION_TEST_ROOT_DIR}/src")
set(INTEGRATION_TEST_COMMON_INCLUDES   "${CMAKE_SOURCE_DIR}/innodb/include"
                                       "${CMAKE_SOURCE_DIR}/innodb/src/include"
                                       "${CMAKE_BINARY_DIR}/include"
                                       "${BS_THREAD_POOL_INCLUDE_DIRS}"
                                       "${LIBURING_INCLUDE_DIRS}"
                                       "${INTEGRATION_TEST_SOURCE_DIR}/common")

# Integration Test Common Object Library configuration

file(GLOB integration_test_common_sources CONFIGURE_DEPENDS "${INTEGRATION_TEST_SOURCE_DIR}/common/*.cc")
add_library(integration_test_common OBJECT ${integration_test_common_sources})
target_include_directories(integration_test_common PRIVATE ${INTEGRATION_TEST_COMMON_INCLUDES})
set_target_properties(integration_test_common PROPERTIES FOLDER ${INTEGRATION_TEST_TARGET_FOLDER})
# Reuse library PCH in integration test common
target_link_libraries(integration_test_common PRIVATE innodb_pch)

# Integration Test Cconfiguration: `ib_cfg`
function(innodb_integration_test executable_name main_src_file)
    add_executable(${executable_name} $<TARGET_OBJECTS:integration_test_common> ${INTEGRATION_TEST_SOURCE_DIR}/${main_src_file})
    target_include_directories(${executable_name} PRIVATE ${INTEGRATION_TEST_COMMON_INCLUDES})
    target_link_libraries(${executable_name} PRIVATE integration_test_common innodb ${INTEGRATION_TEST_LIBS} innodb_pch)
  add_dependencies(${executable_name} innodb_pch_build)
  target_compile_options(${executable_name} PRIVATE -include ${PCH_HEADER})
    set_target_properties(${executable_name} PROPERTIES  RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/tests/bin)
    set_target_properties(${executable_name} PROPERTIES FOLDER ${INTEGRATION_TEST_TARGET_FOLDER})
    if(ENABLE_GCOV)
        target_link_libraries(${executable_name} PRIVATE gcov)
    endif()
endfunction()


# ----------------------------------------------------------------------------------------------------
#                      |  Executable name      |  Main source file          | Other files folder     |
# ----------------------------------------------------------------------------------------------------
innodb_integration_test( itest_cfg               ib_cfg.cc                                           )
innodb_integration_test( itest_cursor            ib_cursor.cc                                        )
innodb_integration_test( itest_ddl               ib_ddl.cc                                           )
innodb_integration_test( itest_dict              ib_dict.cc                                          )
innodb_integration_test( itest_dict-2            ib_dict-2.cc                                        )
innodb_integration_test( itest_drop              ib_drop.cc                                          )
innodb_integration_test( itest_index             ib_index.cc                                         )
innodb_integration_test( itest_logger            ib_logger.cc                                        )
innodb_integration_test( itest_recover           ib_recover.cc                                       )
innodb_integration_test( itest_shutdown          ib_shutdown.cc                                      )
innodb_integration_test( itest_status            ib_status.cc                                        )
innodb_integration_test( itest_tablename         ib_tablename.cc                                     )
innodb_integration_test( itest_test1             ib_test1.cc                                         )
innodb_integration_test( itest_test2             ib_test2.cc                                         )
innodb_integration_test( itest_test3             ib_test3.cc                                         )
innodb_integration_test( itest_test5             ib_test5.cc                                         )
innodb_integration_test( itest_types             ib_types.cc                                         )
innodb_integration_test( itest_update            ib_update.cc                                        )
innodb_integration_test( itest_search            ib_search.cc                                        )
innodb_integration_test( itest_parallel_reader   ib_parallel_reader.cc                               )
innodb_integration_test( itest_deadlock          ib_deadlock.cc                                      )
innodb_integration_test( itest_mt_stress         ib_mt_stress.cc                                     )
innodb_integration_test( itest_perf1             ib_perf1.cc                                         )
