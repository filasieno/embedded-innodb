# ---------------------------------------------------------------------------------------------------------------------
# Integration test setup section
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

# ---------------------------------------------------------------------------------------------------------------------
# end Integration test setup section
# ---------------------------------------------------------------------------------------------------------------------
