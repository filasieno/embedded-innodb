# ---------------------------------------------------------------------------------------------------------------------
# Unit Test test setup section
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
# end Unit Test test setup section
# ---------------------------------------------------------------------------------------------------------------------
