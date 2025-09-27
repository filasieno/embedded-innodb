# ---------------------------------------------------------------------------------------------------------------------
# Precompiled Headers Configuration
# ---------------------------------------------------------------------------------------------------------------------
#
# This file configures precompiled headers for the InnoDB library using CMake's modern PCH support.
# The PCH will be automatically used for the innodb target and propagated to dependent targets.

# Define the main precompiled header file
set(INNODB_PCH_FILE "${CMAKE_SOURCE_DIR}/innodb/src/pch/innodb_pch.h")

# Create an interface library to hold common PCH settings
# This allows us to configure PCH once and apply it to multiple targets
add_library(innodb_pch INTERFACE)

# Set up common include directories and compile definitions
# These will be inherited by targets that link to innodb_pch
target_include_directories(innodb_pch INTERFACE
    "${CMAKE_SOURCE_DIR}/innodb/include"
    "${CMAKE_SOURCE_DIR}/innodb/src/include"
    "${CMAKE_BINARY_DIR}/include"
)

# Link to dependency targets to get their include directories
target_link_libraries(innodb_pch INTERFACE
    PkgConfig::BS_THREAD_POOL
    $<$<BOOL:${LIBURING_FOUND}>:PkgConfig::LIBURING>
)

target_compile_definitions(innodb_pch INTERFACE
    $<$<CONFIG:Debug>:UNIV_DEBUG>
    UNIV_LINUX
)

# Propagate liburing feature macro (liburing is required)
target_compile_definitions(innodb_pch INTERFACE HAVE_LIBURING)

# Set C++23 standard
target_compile_features(innodb_pch INTERFACE cxx_std_23)

# Configure precompiled headers using CMake's modern PCH support
# This will automatically generate and use PCH for targets that link to innodb_pch
target_precompile_headers(innodb_pch INTERFACE
    $<$<COMPILE_LANGUAGE:CXX>:${INNODB_PCH_FILE}>
)

