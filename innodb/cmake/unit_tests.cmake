# ---------------------------------------------------------------------------------------------------------------------
# Unit Test Configuration and Infrastructure
# ---------------------------------------------------------------------------------------------------------------------
#
# This file configures comprehensive unit testing for Embedded InnoDB using Google Test framework.
# Unit tests validate individual components and modules in isolation, providing fast feedback during
# development and ensuring code quality through automated regression testing.
#
# Unit tests are crucial for maintaining code quality because they:
# - Catch regressions early in the development cycle
# - Serve as executable documentation of expected behavior
# - Enable safe refactoring by providing confidence in changes
# - Run quickly (seconds) compared to integration tests (minutes)
# - Allow testing edge cases that are difficult to reproduce manually
#
# ARCHITECTURAL DECISIONS:
# ----------------------
# 1. OBJECT Library Pattern: Using OBJECT libraries instead of static libraries avoids
#    linking issues and enables efficient incremental builds during development.
#
# 2. Module-Specific Test Organization: Each InnoDB module (btr, dict, trx, etc.) has
#    dedicated test suites, making it easier to understand what functionality is being tested.
#
# 3. Common Test Infrastructure: Shared test utilities and setup code are centralized
#    to avoid duplication and ensure consistent test behavior across modules.
#
# 4. Aggregated Test Execution: All unit tests are combined into a single executable
#    for efficient CI/CD pipeline execution.
#
# DEPENDENCIES AND INTEGRATION:
# ----------------------------
# - Google Test: Industry-standard C++ testing framework
# - BS Thread Pool: Required for async operations in test infrastructure
# - GTest Integration: Automatic test discovery and XML reporting for CI systems
#
# CONFIGURATION VARIABLES:
# ----------------------
# Test organization and output directories are configured here for consistency
# across all test suites and CI environments.
#
# The configuration is organized into the following sections:
# 1. Common Test Infrastructure Setup
# 2. Test Creation Utilities
# 3. Module Test Registration
# 4. Test Executable Aggregation
# 5. Coverage and Reporting Configuration


# ====================================================================================================================
# 1. Common Test Infrastructure Setup
# ====================================================================================================================
#
# WHY COMMON INFRASTRUCTURE:
# -------------------------
# Many tests require similar setup code (database initialization, mock objects, etc.).
# Centralizing this infrastructure ensures consistency, reduces duplication, and makes
# maintenance easier when test patterns change.
#

# ---------------------------------------------------------------------------------------------------------------------
# innodb_setup_test_common
# ---------------------------------------------------------------------------------------------------------------------
#
# innodb_setup_test_common(name source_glob include_dirs target_folder [extra_compile_defs...])
#
# Creates a common test infrastructure OBJECT library.
#
# Parameters:
#   name:               Name of the test common library
#   source_glob:        GLOB pattern for source files
#   include_dirs:       Include directories for the library
#   target_folder:      IDE folder for organization
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

# ====================================================================================================================
# 2. Test Creation Utilities
# ====================================================================================================================
#
# WHY UTILITY FUNCTIONS:
# ---------------------
# CMake functions encapsulate common patterns and reduce boilerplate code.
# These utilities ensure consistent test setup across all modules while
# allowing customization where needed.
#

# Configuration Variables
# ----------------------
set(INNODB_UNIT_TEST_TARGET_FOLDER     "Unit Tests")  # IDE folder organization
set(INNODB_UNIT_TEST_ROOT_DIR          "${CMAKE_SOURCE_DIR}/innodb/unit-tests")
set(INNODB_UNIT_TEST_SOURCE_DIR        "${INNODB_UNIT_TEST_ROOT_DIR}/src")
set(INNODB_UNIT_TEST_COMMON_INCLUDES   "${CMAKE_SOURCE_DIR}/innodb/include"
                                       "${CMAKE_SOURCE_DIR}/innodb/src/include"
                                       "${INNODB_PRIVATE_GENERATED_INCLUDE_DIR}"
                                       "${INNODB_UNIT_TEST_SOURCE_DIR}/common")

# ---------------------------------------------------------------------------------------------------------------------
# innodb_create_object_library
# ---------------------------------------------------------------------------------------------------------------------
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
# WHY BS THREAD POOL DEPENDENCY:
# -----------------------------
# Unit tests may need to simulate asynchronous operations or multi-threading scenarios.
# The BS Thread Pool library provides a reliable, high-performance thread pool implementation
# that's used throughout Embedded InnoDB for async operations.
#
target_link_libraries(unit_test_common PRIVATE PkgConfig::BS_THREAD_POOL)

# ====================================================================================================================
# 3. Module Test Registration
# ====================================================================================================================
#
# WHY MODULE-SPECIFIC TESTS:
# -------------------------
# Embedded InnoDB is organized into distinct modules (btr for B-trees, dict for data dictionary,
# trx for transactions, etc.). Testing each module in isolation ensures that:
# - Module boundaries are respected and tested
# - Changes to one module don't unexpectedly break another
# - Test failures clearly indicate which component has issues
# - Developers can focus testing efforts on specific functionality
#
# WHY AUTOMATED REGISTRATION:
# --------------------------
# Manual registration of each test module would be error-prone and hard to maintain.
# The innodb_gtest function automates this process while providing flexibility
# for module-specific customization when needed.
#

# Module Test Creation Function
# ----------------------------
#
# innodb_gtest(executable_name utest_folder)
#
# Creates an OBJECT library for unit tests targeting a specific Embedded InnoDB module.
# This function handles the common pattern of creating per-module test compilation units.
#
# WHY OBJECT LIBRARIES FOR TESTS:
# -----------------------------
# OBJECT libraries allow CMake to compile test sources without linking them immediately.
# This approach provides several benefits:
# - Efficient incremental builds during development
# - Avoids static library linking issues during frequent test changes
# - Enables better parallel compilation
# - Allows for flexible test aggregation strategies
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

    # WHY CONDITIONAL LIBRARY CREATION:
    # ---------------------------------
    # Not all modules may have tests yet, especially during initial development.
    # Creating empty OBJECT libraries ensures the build system remains consistent
    # and allows for incremental test development.
    #
    set(obj_tgt "ut_obj_${executable_name}")
    if(unit_test_sources STREQUAL "")
        add_library(${obj_tgt} OBJECT)
    else()
        add_library(${obj_tgt} OBJECT ${unit_test_sources})
    endif()

    target_include_directories(${obj_tgt} PRIVATE ${INNODB_UNIT_TEST_COMMON_INCLUDES} "${INNODB_UNIT_TEST_SOURCE_DIR}/${utest_folder}")
    target_compile_definitions(${obj_tgt} PRIVATE UNIV_BTR_PRINT UNIT_TESTING)
    set_target_properties(${obj_tgt} PROPERTIES FOLDER ${INNODB_UNIT_TEST_TARGET_FOLDER})

    # WHY GLOBAL PROPERTY REGISTRATION:
    # ---------------------------------
    # CMake properties provide a clean way to collect targets across function calls.
    # This pattern allows us to aggregate all test objects into a single executable
    # without maintaining complex lists manually.
    #
    set_property(GLOBAL APPEND PROPERTY INNODB_UNIT_TEST_OBJ_TARGETS ${obj_tgt})
endfunction()

# Module Test Suite Registration
# -----------------------------
# WHY THESE SPECIFIC MODULES:
# ---------------------------
# These modules represent the core components of Embedded InnoDB that require
# thorough unit testing. Each module handles critical database functionality:
# - btr: B-tree operations (indexing)
# - dict: Data dictionary management
# - trx: Transaction management
# - lock: Concurrency control
# - Various other core subsystems
#
# The registration follows a consistent naming pattern for maintainability.
#
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

# ====================================================================================================================
# 4. Test Executable Aggregation
# ====================================================================================================================
#
# WHY SINGLE EXECUTABLE:
# ---------------------
# Combining all unit tests into one executable provides several advantages:
# - Faster CI/CD execution (single process launch vs. multiple)
# - Comprehensive test reporting in one place
# - Easier debugging of test interdependencies
# - Reduced memory overhead from shared test infrastructure
# - Consistent test execution environment
#
# WHY OBJECT LIBRARY AGGREGATION:
# -----------------------------
# Using $<TARGET_OBJECTS:...> generator expressions allows CMake to properly
# handle the compilation and linking of all test objects. This approach:
# - Enables efficient incremental builds
# - Maintains proper dependency tracking
# - Avoids duplicate compilation of common code
# - Supports parallel compilation effectively
#

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

# Add sanitizer link options when enabled
target_link_options(utest PRIVATE
    $<$<AND:$<CXX_COMPILER_ID:Clang>,$<BOOL:${INNODB_ENABLE_ASAN}>>:-fsanitize=address>
    $<$<AND:$<CXX_COMPILER_ID:Clang>,$<BOOL:${INNODB_ENABLE_TSAN}>>:-fsanitize=thread>
    $<$<AND:$<CXX_COMPILER_ID:Clang>,$<BOOL:${INNODB_ENABLE_UBSAN}>>:-fsanitize=undefined>
)

set_target_properties(utest PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/innodb/bin/utests/$<CONFIG>
    FOLDER ${INNODB_UNIT_TEST_TARGET_FOLDER}
)

# ====================================================================================================================
# 5. Coverage and Reporting Configuration
# ====================================================================================================================
#
# WHY GTEST DISCOVERY:
# -------------------
# Google Test's automatic test discovery eliminates the need to manually register
# each test function. This approach:
# - Reduces boilerplate code in test files
# - Automatically picks up new tests without build system changes
# - Provides consistent test execution across environments
# - Enables better IDE integration and debugging
#
# WHY XML OUTPUT:
# --------------
# XML test results are crucial for CI/CD integration because they:
# - Provide structured, machine-readable test results
# - Enable trend analysis and historical comparisons
# - Integrate with various CI tools (Jenkins, GitLab CI, etc.)
# - Allow for automated quality gate enforcement
#

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

# WHY COVERAGE ANALYSIS:
# ---------------------
# Code coverage measurement is essential for quality assurance because it:
# - Identifies untested code paths that may harbor bugs
# - Ensures adequate test coverage for critical functionality
# - Guides test development efforts to areas needing more testing
# - Provides confidence in refactoring and code changes
# - Meets industry standards for software quality metrics
#
# WHY OPTIONAL GCOVR:
# ------------------
# Making gcovr optional acknowledges that not all development environments
# may have it installed, while still providing coverage capabilities where available.
# This approach maximizes compatibility across different setups.

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
