# ---------------------------------------------------------------------------------------------------------------------
# Precompiled Headers
# ---------------------------------------------------------------------------------------------------------------------
#
# Define a precompiled header for the engine.
# Every module links against this to share common includes/defs.

add_library(innodb_pch INTERFACE)

# Propagate common include directories and compile definitions via innodb_pch
target_include_directories(innodb_pch INTERFACE
    $<$<BOOL:${BS_THREAD_POOL_INCLUDE_DIRS}>:${BS_THREAD_POOL_INCLUDE_DIRS}>
    $<$<BOOL:${LIBURING_INCLUDE_DIRS}>:${LIBURING_INCLUDE_DIRS}>
    $<$<BOOL:${FLEX_INCLUDE_DIR}>:${FLEX_INCLUDE_DIR}>
)

target_compile_definitions(innodb_pch INTERFACE $<$<CONFIG:Debug>:UNIV_DEBUG> UNIV_LINUX)

# Propagate liburing feature macro to all targets consuming the PCH
if(LIBURING_FOUND)
    target_compile_definitions(innodb_pch INTERFACE HAVE_LIBURING)
endif()

# Use CMake 3.24 native PCH support


