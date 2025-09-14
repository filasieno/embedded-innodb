cmake_minimum_required(VERSION 3.24)

project(embedded-innodb LANGUAGES C CXX)

# C++ standard
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

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

# ----------------------------------------------------------------------------
# Configuration checks (to generate ib0config.h)
# ----------------------------------------------------------------------------
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
if(HAVE_STDINT_H)
  set(CMAKE_EXTRA_INCLUDE_FILES stdint.h)
  check_type_size(int8_t    SIZEOF_INT8_T)
  check_type_size(uint8_t   SIZEOF_UINT8_T)
  check_type_size(int16_t   SIZEOF_INT16_T)
  check_type_size(uint16_t  SIZEOF_UINT16_T)
  check_type_size(int32_t   SIZEOF_INT32_T)
  check_type_size(uint32_t  SIZEOF_UINT32_T)
  check_type_size(int64_t   SIZEOF_INT64_T)
  check_type_size(uint64_t  SIZEOF_UINT64_T)
  set(CMAKE_EXTRA_INCLUDE_FILES)
endif()

# Generate ib0config.h
file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/include)
configure_file(
  ${CMAKE_SOURCE_DIR}/cmake/config.h.cmake
  ${CMAKE_BINARY_DIR}/include/ib0config.h
)

# Precompiled headers (PCH)
add_library(innodb_pch INTERFACE)
target_precompile_headers(innodb_pch INTERFACE
  $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/innodb/src/pch/innodb_pch.h>
)

# Helper: define one OBJECT library per module and a STATIC archive per module
function(innodb_add_module module_basename module_dir)
  file(GLOB module_sources CONFIGURE_DEPENDS
    "${CMAKE_SOURCE_DIR}/innodb/src/${module_dir}/*.cc")

  set(obj_tgt    "${module_basename}_obj")
  set(static_tgt "${module_basename}")

  if(module_sources STREQUAL "")
    add_library(${obj_tgt} OBJECT)
  else()
    add_library(${obj_tgt} OBJECT ${module_sources})
  endif()
  target_compile_options(${obj_tgt}  PRIVATE $<$<CXX_COMPILER_ID:Clang>:-Wno-tautological-constant-out-of-range-compare>)
  target_compile_features(${obj_tgt} PRIVATE cxx_std_23)
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

  add_library(${static_tgt} STATIC $<TARGET_OBJECTS:${obj_tgt}>)
  target_compile_features(${static_tgt} PRIVATE cxx_std_23)
  target_include_directories(${static_tgt} PUBLIC ${CMAKE_SOURCE_DIR}/innodb/include)
  target_include_directories(${static_tgt} PRIVATE ${BS_THREAD_POOL_INCLUDE_DIRS} ${LIBURING_INCLUDE_DIRS})
  target_link_libraries(${static_tgt} PRIVATE innodb_pch)
endfunction()

# ---------------------------------------------------------------------------------------------------------------------
# Configure InnoDB modules section 
# --------------------------------------------------------------------------------------------------------------------
innodb_add_module(innodb_ut     ut)
innodb_add_module(innodb_mach   mach)
innodb_add_module(innodb_os     os)
innodb_add_module(innodb_mem    mem)
innodb_add_module(innodb_sync   sync)
innodb_add_module(innodb_fut    fut)
innodb_add_module(innodb_log    log)
innodb_add_module(innodb_fil    fil)
innodb_add_module(innodb_fsp    fsp)
innodb_add_module(innodb_buf    buf)
innodb_add_module(innodb_page   page)
innodb_add_module(innodb_data   data)
innodb_add_module(innodb_rem    rem)
innodb_add_module(innodb_mtr    mtr)
innodb_add_module(innodb_btr    btr)
innodb_add_module(innodb_row    row)
innodb_add_module(innodb_trx    trx)
innodb_add_module(innodb_lock   lock)
innodb_add_module(innodb_read   read)
innodb_add_module(innodb_dict   dict)
innodb_add_module(innodb_ddl    ddl)
innodb_add_module(innodb_pars   pars)
innodb_add_module(innodb_eval   eval)
innodb_add_module(innodb_que    que)
innodb_add_module(innodb_srv    srv)
innodb_add_module(innodb_usr    usr)
innodb_add_module(innodb_api    api)
# ---------------------------------------------------------------------------------------------------------------------
# configure innodb modules section 

# Final single static archive from all module objects
add_library(innodb STATIC
  $<TARGET_OBJECTS:innodb_ut_obj>
  $<TARGET_OBJECTS:innodb_mach_obj>
  $<TARGET_OBJECTS:innodb_os_obj>
  $<TARGET_OBJECTS:innodb_mem_obj>
  $<TARGET_OBJECTS:innodb_sync_obj>
  $<TARGET_OBJECTS:innodb_fut_obj>
  $<TARGET_OBJECTS:innodb_log_obj>
  $<TARGET_OBJECTS:innodb_fil_obj>
  $<TARGET_OBJECTS:innodb_fsp_obj>
  $<TARGET_OBJECTS:innodb_buf_obj>
  $<TARGET_OBJECTS:innodb_page_obj>
  $<TARGET_OBJECTS:innodb_data_obj>
  $<TARGET_OBJECTS:innodb_rem_obj>
  $<TARGET_OBJECTS:innodb_mtr_obj>
  $<TARGET_OBJECTS:innodb_btr_obj>
  $<TARGET_OBJECTS:innodb_row_obj>
  $<TARGET_OBJECTS:innodb_trx_obj>
  $<TARGET_OBJECTS:innodb_lock_obj>
  $<TARGET_OBJECTS:innodb_read_obj>
  $<TARGET_OBJECTS:innodb_dict_obj>
  $<TARGET_OBJECTS:innodb_ddl_obj>
  $<TARGET_OBJECTS:innodb_pars_obj>
  $<TARGET_OBJECTS:innodb_eval_obj>
  $<TARGET_OBJECTS:innodb_que_obj>
  $<TARGET_OBJECTS:innodb_srv_obj>
  $<TARGET_OBJECTS:innodb_usr_obj>
  $<TARGET_OBJECTS:innodb_api_obj>
)

target_compile_features(innodb PRIVATE cxx_std_23)
target_include_directories(innodb PUBLIC $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/innodb/include>)
target_include_directories(innodb PRIVATE ${BS_THREAD_POOL_INCLUDE_DIRS} ${LIBURING_INCLUDE_DIRS})
target_link_libraries(innodb PRIVATE ${LIBURING_LIBRARIES})
set_target_properties(innodb PROPERTIES OUTPUT_NAME "innodb")

install(TARGETS innodb
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
)
install(FILES ${CMAKE_SOURCE_DIR}/innodb/include/innodb.h DESTINATION include)

# Optional Doxygen target
find_package(Doxygen)
if(DOXYGEN_FOUND)
  set(DOXYGEN_PROJECT_NAME "Embedded InnoDB")
  set(DOXYGEN_GENERATE_HTML YES)
  set(DOXYGEN_GENERATE_LATEX NO)
  set(DOXYGEN_RECURSIVE YES)
  set(DOXYGEN_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/docs")
  doxygen_add_docs(docs ${CMAKE_SOURCE_DIR}/innodb/include)
endif()

 
