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

# Objective: Centralize all binary outputs for predictable, clean build artifacts
# - Static libraries in:   ${CMAKE_BINARY_DIR}/innodb/lib
# - Shared libraries in:   ${CMAKE_BINARY_DIR}/innodb/lib
# - Runtimes (if any) in:  ${CMAKE_BINARY_DIR}/innodb/lib
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/innodb/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/innodb/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/innodb/lib)


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

# ccache
find_program(CCACHE_PROGRAM ccache)
if(CCACHE_PROGRAM)
  set(CMAKE_C_COMPILER_LAUNCHER   "${CCACHE_PROGRAM}")
  set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
endif()

# Dependencies via pkg-config
find_package(PkgConfig REQUIRED)
pkg_check_modules(BS_THREAD_POOL REQUIRED bs-thread-pool)
pkg_check_modules(LIBURING REQUIRED liburing)

# Platform defines
if(CMAKE_SYSTEM_NAME MATCHES "Linux")
  add_definitions(-DUNIV_LINUX)
endif()

# Define UNIV_DEBUG on Debug builds
add_compile_definitions($<$<CONFIG:Debug>:UNIV_DEBUG>)

# Silence Clang-only warning that fires on some constexpr comparisons in headers
add_compile_options($<$<CXX_COMPILER_ID:Clang>:-Wno-tautological-constant-out-of-range-compare>)
# ---------------------------------------------------------------------------------------------------------------------
# end Setup CI Build Matrix and Build options





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
)
target_compile_definitions(innodb_pch INTERFACE
  $<$<CONFIG:Debug>:UNIV_DEBUG>
  UNIV_LINUX
)

# Build a single PCH once and reuse (-include) across all compilations
set(PCH_HEADER_SRC ${CMAKE_SOURCE_DIR}/innodb/src/pch/innodb_pch.h)
set(PCH_DIR        ${CMAKE_BINARY_DIR}/pch)
set(PCH_HEADER     ${PCH_DIR}/innodb_pch.h)
set(PCH_GCH        ${PCH_DIR}/innodb_pch.h.gch)

set(PCH_INCLUDE_FLAGS)
foreach(_dir ${CMAKE_SOURCE_DIR}/innodb/src/include ${CMAKE_SOURCE_DIR}/innodb/include ${CMAKE_BINARY_DIR}/include ${BS_THREAD_POOL_INCLUDE_DIRS} ${LIBURING_INCLUDE_DIRS})
  list(APPEND PCH_INCLUDE_FLAGS -I${_dir})
endforeach()

set(PCH_DEBUG_DEF)
set(PCH_DEBUG_FLAGS)
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(PCH_DEBUG_DEF -DUNIV_DEBUG)
  set(PCH_DEBUG_FLAGS -g)
endif()

add_custom_command(OUTPUT ${PCH_GCH}
  COMMAND ${CMAKE_COMMAND} -E make_directory ${PCH_DIR}
  COMMAND ${CMAKE_COMMAND} -E copy_if_different ${PCH_HEADER_SRC} ${PCH_HEADER}
  COMMAND ${CMAKE_CXX_COMPILER} -x c++-header -std=c++23 -DUNIV_LINUX ${PCH_DEBUG_DEF} ${PCH_DEBUG_FLAGS} ${PCH_INCLUDE_FLAGS} -o ${PCH_GCH} ${PCH_HEADER}
  DEPENDS ${PCH_HEADER_SRC}
  VERBATIM)

add_custom_target(innodb_pch_build ALL DEPENDS ${PCH_GCH})
set_target_properties(innodb_pch_build PROPERTIES FOLDER "innodb")
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

  # Step 2 — Define per-module OBJECT target (single compilation point for the module)
  set(obj_tgt    "mod_${module_dir}")

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
  # Reuse the single PCH across all compilations
  add_dependencies(${obj_tgt} innodb_pch_build)
  target_compile_options(${obj_tgt} PRIVATE -Winvalid-pch -include ${PCH_HEADER})

  # Step 3 — Register object target for the final aggregated library
  set_property(GLOBAL APPEND PROPERTY INNODB_OBJ_TARGETS ${obj_tgt})

  set_target_properties(${obj_tgt} PROPERTIES FOLDER "innodb")
endfunction()

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
target_link_libraries(innodb PRIVATE innodb_pch ${LIBURING_LIBRARIES})
set_target_properties(innodb PROPERTIES OUTPUT_NAME "innodb")

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









# TODO: Installation
install(TARGETS innodb
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
)
install(FILES ${CMAKE_SOURCE_DIR}/innodb/include/innodb.h DESTINATION include)



# =====================================================================================================================
# Tests
# =====================================================================================================================

# TODO
set(UNIT_TEST_ROOT_DIR ${CMAKE_SOURCE_DIR}/innodb/tests)

# =====================================================================================================================
# Integration tests configuration
# =====================================================================================================================
set(INTEGRATION_TEST_ROOT_DIR          "${CMAKE_SOURCE_DIR}/innodb/tests")
set(INTEGRATION_TEST_SOURCE_DIR        "${INTEGRATION_TEST_ROOT_DIR}/src")
set(INTEGRATION_TEST_LIBS              pthread m)
set(INTEGRATION_TEST_COMMON_INCLUDES   "${CMAKE_SOURCE_DIR}/innodb/include"
                                       "${CMAKE_SOURCE_DIR}/innodb/src/include"
                                       "${CMAKE_BINARY_DIR}/include"
                                       "${INTEGRATION_TEST_SOURCE_DIR}/common")

# Integration Test Common Object Library configuration

file(GLOB integration_test_common_sources CONFIGURE_DEPENDS "${INTEGRATION_TEST_SOURCE_DIR}/common/*.cc")
add_library(integration_test_common OBJECT ${integration_test_common_sources})
target_include_directories(integration_test_common PRIVATE ${INTEGRATION_TEST_COMMON_INCLUDES})
set_target_properties(integration_test_common PROPERTIES FOLDER "integration_tests")

# Integration Test Cconfiguration: `ib_cfg`
function(innodb_integration_test executable_name main_src_file)
  add_executable(${executable_name} $<TARGET_OBJECTS:integration_test_common> ${INTEGRATION_TEST_SOURCE_DIR}/${main_src_file})
  target_include_directories(${executable_name} PRIVATE ${INTEGRATION_TEST_COMMON_INCLUDES})
  target_link_libraries(${executable_name} PRIVATE integration_test_common innodb ${INTEGRATION_TEST_LIBS})
  set_target_properties(${executable_name} PROPERTIES  RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/tests/bin)
  set_target_properties(${executable_name} PROPERTIES FOLDER "integration_tests")
endfunction()

innodb_integration_test(itest_ib_cfg               ib_cfg.cc             )
innodb_integration_test(itest_ib_cursor            ib_cursor.cc          )
innodb_integration_test(itest_ib_ddl               ib_ddl.cc             )
innodb_integration_test(itest_ib_dict              ib_dict.cc            )
innodb_integration_test(itest_ib_dict-2            ib_dict-2.cc          )
innodb_integration_test(itest_ib_drop              ib_drop.cc            )
innodb_integration_test(itest_ib_index             ib_index.cc           )
innodb_integration_test(itest_ib_logger            ib_logger.cc          )
innodb_integration_test(itest_ib_recover           ib_recover.cc         )
innodb_integration_test(itest_ib_shutdown          ib_shutdown.cc        )
innodb_integration_test(itest_ib_status            ib_status.cc          )
innodb_integration_test(itest_ib_tablename         ib_tablename.cc       )
innodb_integration_test(itest_ib_test1             ib_test1.cc           )
innodb_integration_test(itest_ib_test2             ib_test2.cc           )
innodb_integration_test(itest_ib_test3             ib_test3.cc           )
innodb_integration_test(itest_ib_test5             ib_test5.cc           )
innodb_integration_test(itest_ib_types             ib_types.cc           )
innodb_integration_test(itest_ib_update            ib_update.cc          )
innodb_integration_test(itest_ib_search            ib_search.cc          )
innodb_integration_test(itest_ib_parallel_reader   ib_parallel_reader.cc )
innodb_integration_test(itest_ib_deadlock          ib_deadlock.cc        )
innodb_integration_test(itest_ib_mt_stress         ib_mt_stress.cc       )
innodb_integration_test(itest_ib_perf1             ib_perf1.cc           )

# ---------------------------------------------------------------------------------------------------------------------
# Integration testsconfiguration
# ---------------------------------------------------------------------------------------------------------------------
#
#
#
#
#
# ---------------------------------------------------------------------------------------------------------------------






# ---------------------------------------------------------------------------------------------------------------------


