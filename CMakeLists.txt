# Main CMakeLists.txt - Orchestrates the build by including modular CMake files

include(cmake/general_config.cmake)
include(cmake/version.cmake)
include(cmake/ci_matrix.cmake)
include(cmake/config_checks.cmake)
include(cmake/innodb_modules.cmake)

# Include tests if enabled
if(ENABLE_UNIT_TESTING)
    include(cmake/innodb_unit_tests.cmake)
endif()

if(ENABLE_INTEGRATION_TESTING)
    include(cmake/innodb_integration_tests.cmake)
endif()

# Installation
include(cmake/innodb_install.cmake)