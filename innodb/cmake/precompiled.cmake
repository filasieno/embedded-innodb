# ---------------------------------------------------------------------------------------------------------------------
# Precompiled Headers Configuration
# ---------------------------------------------------------------------------------------------------------------------
#
# This file configures precompiled headers for the InnoDB library and its modules.
# Precompiled headers improve compilation speed by precompiling common includes.

# Define the main precompiled header file
set(INNODB_PCH_FILE "${CMAKE_SOURCE_DIR}/innodb/src/pch/innodb_pch.h")

# Create an interface library to propagate common PCH settings
add_library(innodb_pch INTERFACE)

# Set up include directories that are commonly used
target_include_directories(innodb_pch INTERFACE
    "${CMAKE_SOURCE_DIR}/innodb/include"
    "${CMAKE_SOURCE_DIR}/innodb/src/include"
    "${CMAKE_BINARY_DIR}/include"
    $<$<BOOL:${BS_THREAD_POOL_INCLUDE_DIR}>:${BS_THREAD_POOL_INCLUDE_DIR}>
    $<$<BOOL:${LIBURING_INCLUDE_DIRS}>:${LIBURING_INCLUDE_DIRS}>
)

# Set up common compile definitions
target_compile_definitions(innodb_pch INTERFACE
    $<$<CONFIG:Debug>:UNIV_DEBUG>
    UNIV_LINUX
)

# Propagate liburing feature macro if available
if(LIBURING_FOUND)
    target_compile_definitions(innodb_pch INTERFACE HAVE_LIBURING)
endif()

# Set up precompiled headers using CMake's native PCH support
# This will precompile the common headers for faster compilation
target_precompile_headers(innodb_pch INTERFACE
    $<$<COMPILE_LANGUAGE:CXX>:${INNODB_PCH_FILE}>
)

# Set C++23 standard for PCH
target_compile_features(innodb_pch INTERFACE cxx_std_23)

# ---------------------------------------------------------------------------------------------------------------------
# end Precompiled Headers Configuration
# ---------------------------------------------------------------------------------------------------------------------
