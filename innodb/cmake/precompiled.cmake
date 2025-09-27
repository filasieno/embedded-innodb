# ---------------------------------------------------------------------------------------------------------------------
# Precompiled Headers Configuration
# ---------------------------------------------------------------------------------------------------------------------
#
# This file configures precompiled headers (PCH) for the Embedded InnoDB library using CMake's
# modern target-based PCH support. PCH significantly reduces compilation time by precompiling
# frequently-used headers.
#
# Architecture:
# - Interface library (innodb_pch) holds common PCH configuration
# - All modules link to innodb_pch to inherit PCH settings
# - Includes common headers, defines, and dependencies
#
# Benefits:
# - Faster compilation through header precompilation
# - Centralized configuration of common build settings
# - Automatic propagation to dependent targets

# PCH Header File
# ---------------
set(INNODB_PCH_FILE "${CMAKE_SOURCE_DIR}/innodb/src/pch/innodb_pch.h")

# Interface Library Creation
# -------------------------
# Create an INTERFACE library to centralize PCH and common build settings
# This pattern allows settings to be defined once and inherited by all dependent targets
add_library(innodb_pch INTERFACE)

# Include Directories
# ------------------
# Configure common include paths used across all modules
target_include_directories(innodb_pch INTERFACE
    "${CMAKE_SOURCE_DIR}/innodb/include"                   # Public API headers
    "${CMAKE_SOURCE_DIR}/innodb/src/include"              # Private implementation headers
    "${INNODB_PRIVATE_GENERATED_INCLUDE_DIR}"             # Generated configuration headers
)

# Dependency Linking
# -----------------
# Link to external dependencies to inherit their include directories and settings
target_link_libraries(innodb_pch INTERFACE
    PkgConfig::BS_THREAD_POOL                           # Thread pool library
    $<$<BOOL:${LIBURING_FOUND}>:PkgConfig::LIBURING>    # Async I/O library (conditional)
)

# Compile Definitions
# ------------------
# Common preprocessor definitions used throughout the codebase
target_compile_definitions(innodb_pch INTERFACE
    $<$<CONFIG:Debug>:UNIV_DEBUG>  # Debug-specific features
    UNIV_LINUX                     # Linux platform identifier
    HAVE_LIBURING                  # liburing availability flag
)

# C++ Standard
# -----------
target_compile_features(innodb_pch INTERFACE cxx_std_23)

# Precompiled Headers Configuration
# --------------------------------
# Configure PCH using CMake's modern target_precompile_headers()
# This automatically generates and uses PCH for all targets linking to innodb_pch
target_precompile_headers(innodb_pch INTERFACE
    $<$<COMPILE_LANGUAGE:CXX>:${INNODB_PCH_FILE}>
)

