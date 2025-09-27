# ---------------------------------------------------------------------------------------------------------------------
# Integration Test Configuration
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# innodb_setup_test_common
# ---------------------------------------------------------------------------------------------------------------------
#
# innodb_setup_test_common(name source_glob include_dirs target_folder [extra_compile_defs...])
#
# Creates a common test infrastructure OBJECT library.
#
# Parameters:
#   name: Name of the test common library
#   source_glob: GLOB pattern for source files
#   include_dirs: Include directories for the library
#   target_folder: IDE folder for organization
#   extra_compile_defs: Optional additional compile definitions
#
function(innodb_setup_test_common name source_glob include_dirs target_folder)
    # Expand the glob pattern to get actual source files
    file(GLOB source_files CONFIGURE_DEPENDS ${source_glob})

    # Create the common library using the object library function
    innodb_create_object_library(${name} "${source_files}" "${include_dirs}")

    # Set target folder for IDE organization
    set_target_properties(${name} PROPERTIES FOLDER ${target_folder})

    # Apply test-specific compile definitions
    target_compile_definitions(${name} PRIVATE UNIV_BTR_PRINT UNIT_TESTING)

    # Apply any additional compile definitions
    foreach(def IN LISTS ARGN)
        target_compile_definitions(${name} PRIVATE ${def})
    endforeach()
endfunction()

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

# ---------------------------------------------------------------------------------------------------------------------
#
# This file configures integration testing for Embedded InnoDB. Integration tests
# validate end-to-end functionality and component interactions, typically involving
# database operations, file I/O, and multi-component scenarios.
#
# Architecture:
# - Per-test executables for individual integration test suites
# - Shared common infrastructure in integration_test_common
# - Direct database operations and system-level testing
# - Automatic test discovery and execution
#
# Test Organization:
# - Common test infrastructure in tests/src/common/
# - Individual test suites as separate executables
# - Each test creates its own database environment
#
# Dependencies: Embedded InnoDB library, system libraries (pthread, m)

# Configuration Variables
# ----------------------
set(INNODB_INTEGRATION_TEST_TARGET_FOLDER     "Integration Tests")  # IDE folder organization
set(INNODB_INTEGRATION_TEST_LIBS              Threads::Threads m)   # System libraries for threading/math
set(INNODB_INTEGRATION_TEST_ROOT_DIR          "${CMAKE_SOURCE_DIR}/innodb/tests")
set(INNODB_INTEGRATION_TEST_SOURCE_DIR        "${INNODB_INTEGRATION_TEST_ROOT_DIR}/src")
set(INNODB_INTEGRATION_TEST_BINARY_DIR        "${CMAKE_BINARY_DIR}/innodb/bin/tests")
set(INNODB_INTEGRATION_TEST_COMMON_INCLUDES   "${CMAKE_SOURCE_DIR}/innodb/include"
                                       "${CMAKE_SOURCE_DIR}/innodb/src/include"
                                              "${INNODB_PRIVATE_GENERATED_INCLUDE_DIR}"
                                              "${INNODB_INTEGRATION_TEST_SOURCE_DIR}/common")

# Common Test Infrastructure
# -------------------------
# Create OBJECT library for shared integration test utilities and setup using common function
innodb_setup_test_common(
    integration_test_common
    "${INNODB_INTEGRATION_TEST_SOURCE_DIR}/common/*.cc"
    "${INNODB_INTEGRATION_TEST_COMMON_INCLUDES}"
    "${INNODB_INTEGRATION_TEST_TARGET_FOLDER}"
    UNIV_BTR_PRINT  # Enable B-tree printing in debug output
    UNIT_TESTING    # Enable test-specific code paths
)

# Link Dependencies
# ----------------
# Connect to BS Thread Pool for test infrastructure
target_link_libraries(integration_test_common PRIVATE PkgConfig::BS_THREAD_POOL)
# Reuse library PCH in integration test common

# Integration Test Creation Function
# ---------------------------------
#
# innodb_integration_test(executable_name main_src_file)
#
# Creates an executable for a specific integration test suite. Each integration test
# is a standalone executable that performs end-to-end testing of Embedded InnoDB functionality.
#
# Parameters:
#   executable_name: Name for the test executable (e.g., "itest_cfg")
#   main_src_file:  Main source file for the test (under tests/src/)
#
# Features:
#   - Automatic linking with Embedded InnoDB and common test infrastructure
#   - Coverage support when enabled
#   - Proper output directory organization
#
function(innodb_integration_test executable_name main_src_file)
    # Create the executable
    add_executable(${executable_name} $<TARGET_OBJECTS:integration_test_common> ${INNODB_INTEGRATION_TEST_SOURCE_DIR}/${main_src_file})

    # Configure includes and linking
    target_include_directories(${executable_name} PRIVATE ${INNODB_INTEGRATION_TEST_COMMON_INCLUDES})

    # Link against the innodb target and system libraries
    # Use PUBLIC link to innodb to ensure proper dependency ordering
    target_link_libraries(${executable_name} PRIVATE integration_test_common)
    target_link_libraries(${executable_name} PUBLIC innodb)

    # Add system libraries - use explicit linking for math and threads
    if(CMAKE_THREAD_LIBS_INIT)
        target_link_libraries(${executable_name} PRIVATE ${CMAKE_THREAD_LIBS_INIT})
    endif()
    target_link_libraries(${executable_name} PRIVATE m)  # Math library

    # Set output properties
    set_target_properties(${executable_name} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY ${INNODB_INTEGRATION_TEST_BINARY_DIR}
        FOLDER ${INNODB_INTEGRATION_TEST_TARGET_FOLDER}
    )

    # Add coverage linking if enabled
    if(INNODB_ENABLE_GCOV)
        target_link_libraries(${executable_name} PRIVATE gcov)
    endif()
endfunction()

# Integration Test Registration
# ----------------------------
# Register all available integration test suites
# Each test validates specific Embedded InnoDB functionality and integration points
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

