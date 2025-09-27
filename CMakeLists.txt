# Main CMakeLists.txt - Orchestrates the build by including modular CMake files

cmake_minimum_required(VERSION 3.24)
project(embedded-innodb LANGUAGES C CXX)


include(cmake/general_config.cmake)
include(cmake/version.cmake)
include(cmake/ci_matrix.cmake)
include(cmake/config_checks.cmake)

# ---------------------------------------------------------------------------------------------------------------------
# InnoDB
# ---------------------------------------------------------------------------------------------------------------------

include(innodb/cmake/modules.cmake)
if(ENABLE_UNIT_TESTING)
    include(innodb/cmake/unit_tests.cmake)
endif()
if(ENABLE_INTEGRATION_TESTING)
    include(innodb/cmake/integration_tests.cmake)
endif()
include(innodb/cmake/install.cmake)


# ---------------------------------------------------------------------------------------------------------------------
# InnoLua
# ---------------------------------------------------------------------------------------------------------------------

# todo

# ---------------------------------------------------------------------------------------------------------------------
# InnoBench
# ---------------------------------------------------------------------------------------------------------------------

# todo