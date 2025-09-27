# ---------------------------------------------------------------------------------------------------------------------
# Precompiled Headers Configuration and Build Optimization
# ---------------------------------------------------------------------------------------------------------------------
#
# This file configures precompiled headers (PCH) for the Embedded InnoDB library using CMake's
# modern target-based PCH support. PCH is a critical optimization technique for large C++ projects
# that significantly reduces compilation time by precompiling frequently-used headers.
#
# WHY PRECOMPILED HEADERS MATTER:
# -------------------------------
# In large C++ projects like Embedded InnoDB, compilation time can become a significant bottleneck.
# PCH addresses this by precompiling stable, frequently-included headers once, then reusing
# the compiled state for subsequent compilations. Benefits include:
# - 2-10x faster compilation for translation units that include many headers
# - Reduced CPU usage during builds
# - Better developer productivity through faster iteration cycles
# - Particularly effective for template-heavy code like Embedded InnoDB
#
# ARCHITECTURAL APPROACH:
# ----------------------
# We use an INTERFACE library (innodb_pch) to centralize PCH configuration because:
# - INTERFACE libraries don't create actual build artifacts
# - Settings automatically propagate to all targets that link to them
# - Clean separation between PCH configuration and actual compilation
# - Enables consistent PCH usage across the entire codebase
#
# WHY INTERFACE LIBRARY PATTERN:
# -----------------------------
# The INTERFACE library approach provides superior maintainability compared to manually
# configuring PCH on each target because it:
# - Centralizes PCH configuration in one location
# - Automatically applies to new modules without additional setup
# - Enables easy PCH configuration changes across the entire project
# - Maintains clean target dependencies and build graphs
#
# The configuration is organized into the following sections:
# 1. PCH Header File Specification
# 2. Interface Library Creation and Configuration
# 3. Include Directory Management
# 4. Dependency Integration
# 5. Compile Definitions Setup
# 6. Sanitizer Integration
# 7. Precompiled Headers Activation

# ====================================================================================================================
# 1. PCH Header File Specification
# ====================================================================================================================
#
# WHY DEDICATED PCH HEADER:
# ------------------------
# The PCH header (innodb_pch.h) contains the most frequently included headers across
# the entire codebase. By carefully curating this file, we maximize the compilation
# speedup while minimizing the PCH file size. The header includes:
# - Standard library headers used throughout the project
# - Boost headers and other third-party dependencies
# - Internal headers that are stable and widely used
#
set(INNODB_PCH_FILE "${CMAKE_SOURCE_DIR}/innodb/src/pch/innodb_pch.h")

# ====================================================================================================================
# 2. Interface Library Creation and Configuration
# ====================================================================================================================
#
# WHY INTERFACE LIBRARY FOR PCH:
# -----------------------------
# INTERFACE libraries in CMake are perfect for this use case because they:
# - Don't generate any actual build artifacts (no .a/.so files)
# - Automatically propagate their properties to targets that link to them
# - Provide a clean abstraction for configuration management
# - Enable modular build system design
#
add_library(innodb_pch INTERFACE)

# ====================================================================================================================
# 3. Include Directory Management
# ====================================================================================================================
#
# WHY CENTRALIZED INCLUDE MANAGEMENT:
# ----------------------------------
# Include directories are configured here rather than on individual targets because:
# - Ensures consistency across all modules
# - Avoids duplication and maintenance overhead
# - Provides a single source of truth for include paths
# - Enables easier refactoring of directory structures
#
# WHY THESE SPECIFIC DIRECTORIES:
# ------------------------------
# - innodb/include: Public API headers that external applications use
# - innodb/src/include: Private implementation headers (internal use only)
# - Generated headers: Configuration headers created at build time
#
target_include_directories(innodb_pch INTERFACE
    "${CMAKE_SOURCE_DIR}/innodb/include"                   # Public API headers
    "${CMAKE_SOURCE_DIR}/innodb/src/include"              # Private implementation headers
    "${INNODB_PRIVATE_GENERATED_INCLUDE_DIR}"             # Generated configuration headers
)

# ====================================================================================================================
# 4. Dependency Integration
# ====================================================================================================================
#
# WHY DEPENDENCY LINKING IN PCH:
# -----------------------------
# Linking dependencies to the PCH interface library ensures that all targets
# using PCH automatically inherit the necessary link dependencies. This approach:
# - Eliminates the need to manually link dependencies on each target
# - Maintains proper link ordering automatically
# - Reduces build system complexity and potential errors
# - Enables seamless addition of new modules
#
# WHY CONDITIONAL LIBURING LINKING:
# ---------------------------------
# liburing is conditionally linked because it's only available on Linux systems.
# The generator expression ensures proper cross-platform compatibility while
# maintaining the INTERFACE library benefits.
#
target_link_libraries(innodb_pch INTERFACE
    PkgConfig::BS_THREAD_POOL                           # Thread pool library
    $<$<BOOL:${LIBURING_FOUND}>:PkgConfig::LIBURING>    # Async I/O library (conditional)
)

# ====================================================================================================================
# 5. Compile Definitions Setup
# ====================================================================================================================
#
# WHY CENTRALIZED DEFINITIONS:
# ---------------------------
# Preprocessor definitions are centralized here to ensure consistency and avoid
# duplication. These definitions control core Embedded InnoDB behavior and must
# be applied uniformly across all compilation units.
#
# WHY THESE SPECIFIC DEFINITIONS:
# ------------------------------
# - UNIV_DEBUG: Enables debug assertions and additional safety checks in debug builds
# - UNIV_LINUX: Identifies the target platform for platform-specific code paths
# - HAVE_LIBURING: Indicates liburing availability for async I/O optimizations
#
target_compile_definitions(innodb_pch INTERFACE
    $<$<CONFIG:Debug>:UNIV_DEBUG>  # Debug-specific features
    UNIV_LINUX                     # Linux platform identifier
    HAVE_LIBURING                  # liburing availability flag
)

# ====================================================================================================================
# 6. Sanitizer Integration
# ====================================================================================================================
#
# WHY SANITIZER INTEGRATION IN PCH:
# ---------------------------------
# Placing sanitizer flags in the PCH interface ensures they apply to all targets
# that use precompiled headers. This approach:
# - Guarantees consistent sanitizer application across the codebase
# - Simplifies sanitizer configuration management
# - Enables easy sanitizer enable/disable without touching individual targets
# - Maintains proper flag propagation through the build system
#
# WHY CLANG-ONLY SANITIZERS:
# -------------------------
# Sanitizers are currently only supported on Clang because:
# - GCC sanitizer support is less mature and reliable
# - Clang provides better error messages and performance
# - Ensures consistent behavior across different compiler versions
#
target_compile_options(innodb_pch INTERFACE
    $<$<AND:$<CXX_COMPILER_ID:Clang>,$<BOOL:${INNODB_ENABLE_ASAN}>>:-fsanitize=address>
    $<$<AND:$<CXX_COMPILER_ID:Clang>,$<BOOL:${INNODB_ENABLE_TSAN}>>:-fsanitize=thread>
    $<$<AND:$<CXX_COMPILER_ID:Clang>,$<BOOL:${INNODB_ENABLE_UBSAN}>>:-fsanitize=undefined>
)

# ====================================================================================================================
# 7. Precompiled Headers Activation
# ====================================================================================================================
#
# WHY TARGET_PRECOMPILE_HEADERS:
# -----------------------------
# CMake's target_precompile_headers() is the modern, recommended approach for PCH because:
# - Provides automatic dependency tracking and rebuilds
# - Works seamlessly with generator expressions and conditional compilation
# - Integrates cleanly with INTERFACE libraries and target properties
# - Supports both GCC and Clang compilers with consistent syntax
# - Enables better IDE integration and debugging
#
# WHY CONDITIONAL ON COMPILE LANGUAGE:
# -----------------------------------
# The $<COMPILE_LANGUAGE:CXX> generator expression ensures PCH is only applied
# to C++ compilation units, preventing issues with C files or other languages.
#
target_precompile_headers(innodb_pch INTERFACE
    $<$<COMPILE_LANGUAGE:CXX>:${INNODB_PCH_FILE}>
)

