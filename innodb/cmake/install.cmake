# ---------------------------------------------------------------------------------------------------------------------
# Installation Configuration and Package Deployment
# ---------------------------------------------------------------------------------------------------------------------
#
# This file configures the installation targets and deployment strategy for Embedded InnoDB.
# Proper installation is crucial for making the library usable by external applications and
# ensuring it integrates cleanly with package managers and build systems.
#
# WHY PROPER INSTALLATION MATTERS:
# -------------------------------
# A well-designed installation provides several benefits:
# - Enables external applications to easily link against Embedded InnoDB
# - Supports standard package management workflows (apt, yum, vcpkg, etc.)
# - Allows clean separation between build artifacts and installed files
# - Facilitates cross-platform deployment and distribution
# - Enables proper integration with IDEs and build tools
#
# INSTALLATION PHILOSOPHY:
# -----------------------
# We follow CMake installation best practices by:
# - Using standard installation directories (lib/, include/)
# - Providing both static and shared library variants
# - Installing only public API headers (not internal implementation)
# - Supporting CMake's find_package() mechanism for downstream consumers
# - Maintaining compatibility with platform-specific conventions
#
# WHY BOTH STATIC AND SHARED LIBRARIES:
# ------------------------------------
# Providing both library types maximizes flexibility for downstream users:
# - Static libraries: Better performance, no runtime dependencies, larger binaries
# - Shared libraries: Smaller binaries, runtime flexibility, better memory usage
# - Allows users to choose based on their deployment requirements
#
# The configuration is organized into the following sections:
# 1. Library Installation Setup
# 2. Public Header Installation

# ====================================================================================================================
# 1. Library Installation Setup
# ====================================================================================================================
#
# WHY INSTALL MULTIPLE TARGETS:
# ----------------------------
# Installing both innodb (static) and innodb_shared (shared) targets allows downstream
# users to choose their preferred linking strategy. This approach:
# - Maximizes compatibility with different build systems
# - Supports both static and dynamic linking preferences
# - Enables flexible deployment scenarios
#
# WHY STANDARD DESTINATIONS:
# -------------------------
# Using standard CMake destinations (lib/, include/) ensures compatibility with:
# - Platform package managers (apt, yum, brew, etc.)
# - CMake's find_package() mechanism
# - Standard filesystem hierarchies (/usr/lib, /usr/include)
# - Cross-platform development tools and IDEs
#
install(TARGETS innodb innodb_shared
    ARCHIVE DESTINATION lib  # Static library (.a/.lib)
    LIBRARY DESTINATION lib  # Shared library (.so/.dll)
)

# ====================================================================================================================
# 2. Public Header Installation
# ====================================================================================================================
#
# WHY FILE_SET APPROACH:
# ---------------------
# CMake's FILE_SET (introduced in CMake 3.23) is superior to traditional header installation because:
# - Provides better IDE integration and code navigation
# - Enables proper dependency tracking for header files
# - Supports modular header organization
# - Allows for cleaner packaging and distribution
# - Maintains compatibility with modern CMake best practices
#
# WHY ONLY PUBLIC HEADERS:
# ------------------------
# Installing only innodb.h (the public API) rather than all internal headers because:
# - Maintains clear API/implementation separation
# - Prevents external code from depending on internal implementation details
# - Reduces installation footprint and complexity
# - Enables cleaner API evolution without breaking downstream users
# - Follows standard library distribution practices
#
target_sources(innodb PUBLIC FILE_SET HEADERS
    BASE_DIRS ${CMAKE_SOURCE_DIR}/innodb/include
    FILES ${CMAKE_SOURCE_DIR}/innodb/include/innodb.h
)

# WHY INSTALL VIA TARGET:
# ----------------------
# Installing headers through the target (rather than directly) ensures that:
# - Headers are properly associated with the library target
# - CMake's find_package() can locate headers automatically
# - Proper dependency relationships are maintained
# - Cross-platform compatibility is preserved
#
install(TARGETS innodb
    FILE_SET HEADERS DESTINATION include
)

# ---------------------------------------------------------------------------------------------------------------------
# End Installation Configuration
# ---------------------------------------------------------------------------------------------------------------------
