# ---------------------------------------------------------------------------------------------------------------------
# Library and API Versioning Configuration
# ---------------------------------------------------------------------------------------------------------------------
#
# This file defines comprehensive versioning information for the Embedded InnoDB library,
# ensuring proper version management, compatibility guarantees, and release tracking.
#
# WHY PROPER VERSIONING MATTERS:
# -----------------------------
# Versioning is critical for library distribution because it:
# - Enables dependency management tools to resolve compatible versions
# - Provides clear compatibility guarantees to downstream users
# - Supports automated update mechanisms and security patching
# - Facilitates communication about breaking changes and new features
# - Enables proper package management and distribution workflows
#
# VERSIONING STRATEGY:
# -------------------
# We employ a dual versioning approach to serve different audiences:
# 1. Human-readable version (INNODB_VERSION): For users, documentation, and marketing
# 2. API version (GNU libtool convention): For build systems and binary compatibility
#
# This approach provides maximum flexibility while maintaining clear compatibility contracts.
#
# GNU LIBTOOL VERSIONING CONVENTION:
# ---------------------------------
# The CURRENT:REVISION:AGE format provides precise compatibility information:
# - CURRENT: Incremented when interfaces are added/removed/changed
# - REVISION: Incremented when implementation changes but interfaces remain compatible
# - AGE: Indicates how many previous versions are backward compatible
#
# Example: 6:0:0 means "API version 6, first revision, no backward compatibility"
#
# The configuration is organized into the following sections:
# 1. Library Version Definition
# 2. API Version Components
# 3. Version Reporting
#
# ====================================================================================================================
# 1. Library Version Definition
# ====================================================================================================================
#
# WHY HUMAN-READABLE VERSION:
# --------------------------
# The library version serves multiple important purposes:
# - User-facing identification in documentation and release notes
# - Marketing and communication about library capabilities
# - Package manager identification and dependency resolution
# - Clear communication of feature sets and compatibility
#
# WHY SEMANTIC VERSIONING:
# -----------------------
# We follow semantic versioning (MAJOR.MINOR.PATCH) principles to clearly communicate:
# - Breaking changes (major version bumps)
# - New features (minor version bumps)
# - Bug fixes (patch version bumps)
#
set(INNODB_VERSION "0.1")

# ====================================================================================================================
# 2. API Version Components
# ====================================================================================================================
#
# WHY GNU LIBTOOL CONVENTION:
# --------------------------
# The libtool versioning scheme is the industry standard for shared libraries because it:
# - Provides precise binary compatibility guarantees
# - Works across different platforms and package managers
# - Integrates seamlessly with build systems and deployment tools
# - Has proven reliability over decades of use in major projects
#
# VERSION UPDATE RULES:
# -------------------
# - CURRENT: Increment when you add/remove/change interfaces
# - REVISION: Increment when you make backward-compatible changes
# - AGE: Increment when you add interfaces, reset to 0 when removing/changing
#
# This ensures downstream users can safely upgrade within compatibility windows.
#
set(INNODB_API_VERSION          6)   # Increment if interfaces have been added, removed or changed
set(INNODB_API_VERSION_REVISION 0)   # Increment if source code has changed, set to zero if current is incremented
set(INNODB_API_VERSION_AGE      0)   # Increment if interfaces have been added, set to zero if interfaces have been removed or changed

# ====================================================================================================================
# 3. Version Reporting
# ====================================================================================================================
#
# WHY VERSION REPORTING:
# ---------------------
# Build-time version reporting serves several purposes:
# - Confirms correct version configuration during builds
# - Aids in debugging version-related issues
# - Provides visibility into what version is being built
# - Helps with automated build verification and compliance
#
set(INNODB_API_VERSION_STRING "${INNODB_API_VERSION}:${INNODB_API_VERSION_REVISION}:${INNODB_API_VERSION_AGE}")

message(STATUS "INNODB_VERSION:            " ${INNODB_VERSION})
message(STATUS "INNODB_API_VERSION_STRING: " ${INNODB_API_VERSION_STRING})

