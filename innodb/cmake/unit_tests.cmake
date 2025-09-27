# ---------------------------------------------------------------------------------------------------------------------
# Unit Test Configuration
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
# This file configures unit testing for Embedded InnoDB using Google Test framework.
# Unit tests validate individual components and modules in isolation.
#
# Architecture:
# - Per-module test libraries (OBJECT libraries for efficient compilation)
# - Aggregated test executable combining all unit tests
# - GTest integration with discovery and reporting
# - Optional coverage reporting with gcovr
#
# Test Organization:
# - Common test infrastructure in unit_test_common
# - Module-specific tests in unit-tests/src/modules/
# - Automatic test registration and execution
#
# Dependencies: GTest, gcovr (optional for coverage)

# Configuration Variables
# ----------------------
set(INNODB_UNIT_TEST_TARGET_FOLDER   "Unit Tests")  # IDE folder organization
set(INNODB_UNIT_TEST_ROOT_DIR        "${CMAKE_SOURCE_DIR}/innodb/unit-tests")
set(INNODB_UNIT_TEST_SOURCE_DIR      "${INNODB_UNIT_TEST_ROOT_DIR}/src")
set(INNODB_UNIT_TEST_COMMON_INCLUDES "${CMAKE_SOURCE_DIR}/innodb/include"
                                     "${CMAKE_SOURCE_DIR}/innodb/src/include"
                                     "${INNODB_PRIVATE_GENERATED_INCLUDE_DIR}"
                                     "${INNODB_UNIT_TEST_SOURCE_DIR}/common")

# Common Test Infrastructure
# -------------------------
# Create OBJECT library for shared test utilities and setup using common function
innodb_setup_test_common(
    unit_test_common
    "${INNODB_UNIT_TEST_SOURCE_DIR}/common/*.cc"
    "${INNODB_UNIT_TEST_COMMON_INCLUDES}"
    "${INNODB_UNIT_TEST_TARGET_FOLDER}"
    UNIV_BTR_PRINT  # Enable B-tree printing in debug output
    UNIT_TESTING    # Enable test-specific code paths
)

# Test Dependencies
# ----------------
set(unit_test_common_libs GTest::gtest_main GTest::gtest innodb)
find_package(GTest REQUIRED)

# GTest Include Path Resolution
# ----------------------------
# Ensure GTest headers are available during compilation
get_target_property(GTEST_INCLUDE_DIRS GTest::gtest INTERFACE_INCLUDE_DIRECTORIES)
if(GTEST_INCLUDE_DIRS)
    list(APPEND INNODB_UNIT_TEST_COMMON_INCLUDES ${GTEST_INCLUDE_DIRS})
endif()

# Link Dependencies
# ----------------
# Connect to BS Thread Pool for test infrastructure
target_link_libraries(unit_test_common PRIVATE PkgConfig::BS_THREAD_POOL)

# Module Test Creation Function
# ----------------------------
#
# innodb_gtest(executable_name utest_folder)
#
# Creates an OBJECT library for unit tests targeting a specific Embedded InnoDB module.
# This function handles the common pattern of creating per-module test compilation units.
#
# Parameters:
#   executable_name: Base name for the test target (e.g., "utest_api")
#   utest_folder:    Subdirectory under unit-tests/src/ containing test files
#
# Creates:
#   - OBJECT library: ut_obj_${executable_name} for test compilation
#   - Registers objects for final test executable aggregation
#
function(innodb_gtest executable_name utest_folder)
    # Gather sources for this unit-test module
    file(GLOB unit_test_sources CONFIGURE_DEPENDS "${INNODB_UNIT_TEST_SOURCE_DIR}/${utest_folder}/*.cc")

    # Create an OBJECT library for the module's tests
    set(obj_tgt "ut_obj_${executable_name}")
    if(unit_test_sources STREQUAL "")
        add_library(${obj_tgt} OBJECT)
    else()
        add_library(${obj_tgt} OBJECT ${unit_test_sources})
    endif()

    target_include_directories(${obj_tgt} PRIVATE ${INNODB_UNIT_TEST_COMMON_INCLUDES} "${INNODB_UNIT_TEST_SOURCE_DIR}/${utest_folder}")
    target_compile_definitions(${obj_tgt} PRIVATE UNIV_BTR_PRINT UNIT_TESTING)
    set_target_properties(${obj_tgt} PROPERTIES FOLDER ${INNODB_UNIT_TEST_TARGET_FOLDER})

    # Register the object target for aggregation later
    set_property(GLOBAL APPEND PROPERTY INNODB_UNIT_TEST_OBJ_TARGETS ${obj_tgt})
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

# ---------------------------------------------------------------------------------------------------------------------
# Test Executable Aggregation
# ---------------------------------------------------------------------------------------------------------------------
# Combine all unit test objects into a single executable for efficient testing

# Object Collection
# ----------------
get_property(INNODB_UNIT_TEST_OBJ_TARGETS GLOBAL PROPERTY INNODB_UNIT_TEST_OBJ_TARGETS)
set(INNODB_UNIT_TEST_ALL_OBJECTS)
foreach(obj_tgt IN LISTS INNODB_UNIT_TEST_OBJ_TARGETS)
    list(APPEND INNODB_UNIT_TEST_ALL_OBJECTS $<TARGET_OBJECTS:${obj_tgt}>)
endforeach()

# Main Test Executable
# -------------------
add_executable(utest $<TARGET_OBJECTS:unit_test_common> ${INNODB_UNIT_TEST_ALL_OBJECTS})
target_include_directories(utest PRIVATE ${INNODB_UNIT_TEST_COMMON_INCLUDES})
target_compile_definitions(utest PRIVATE UNIV_BTR_PRINT UNIT_TESTING)

# Link against dependencies with explicit ordering
target_link_libraries(utest PRIVATE unit_test_common)
target_link_libraries(utest PUBLIC innodb)  # Public link to ensure proper dependency
target_link_libraries(utest PRIVATE GTest::gtest_main GTest::gtest)

# Add system libraries if needed
if(CMAKE_THREAD_LIBS_INIT)
    target_link_libraries(utest PRIVATE ${CMAKE_THREAD_LIBS_INIT})
endif()

# Coverage Configuration
# ---------------------
if(INNODB_ENABLE_GCOV)
    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        target_link_options(utest PRIVATE --coverage)
    endif()
endif()

set_target_properties(utest PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/innodb/bin/utests/$<CONFIG>
    FOLDER ${INNODB_UNIT_TEST_TARGET_FOLDER}
)

# GTest Integration
# ----------------
include(CTest)
include(GoogleTest)

gtest_discover_tests(utest
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/innodb/bin/utests/$<CONFIG>
    DISCOVERY_TIMEOUT 30
    PROPERTIES
        LABELS "unit"
        TIMEOUT 120
    XML_OUTPUT_DIR ${CMAKE_BINARY_DIR}/innodb/bin/utests/$<CONFIG>/test-results
)

# Coverage Reporting (Optional)
# ----------------------------
# Generate HTML and XML coverage reports when gcovr is available
if(INNODB_ENABLE_GCOV)
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
