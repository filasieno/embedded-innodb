# ---------------------------------------------------------------------------------------------------------------------
# Library and API Versioning Configuration
# ---------------------------------------------------------------------------------------------------------------------
#
# This file defines version information for Embedded InnoDB library and API.
# Version numbers follow semantic versioning principles with API compatibility guarantees.
#
# Version Components:
# - INNODB_VERSION: Human-readable version string (e.g., "0.1")
# - INNODB_API_VERSION: Major API version (incremented on breaking changes)
# - INNODB_API_VERSION_REVISION: Minor revision (incremented on additions)
# - INNODB_API_VERSION_AGE: Backward compatibility age (incremented on additions)
#
# The API version string follows the format: CURRENT:REVISION:AGE
# This is used by pkg-config and other package management systems.

# Library Version
# ---------------
# Human-readable version string for the Embedded InnoDB library
set(INNODB_VERSION "0.1")

# API Version Components
# ---------------------
# API versioning follows GNU libtool conventions: CURRENT:REVISION:AGE
# - CURRENT:  Interface version (incremented on breaking changes)
# - REVISION: Implementation revision (incremented on bug fixes/backward-compatible changes)
# - AGE:      Number of previous interface versions still supported
set(INNODB_API_VERSION          6)   # Increment if interfaces have been added, removed or changed
set(INNODB_API_VERSION_REVISION 0)   # Increment if source code has changed, set to zero if current is incremented
set(INNODB_API_VERSION_AGE      0)   # Increment if interfaces have been added, set to zero if interfaces have been removed or changed

# API Version String
# -----------------
# Combined version string used in build configuration and pkg-config files
set(INNODB_API_VERSION_STRING "${INNODB_API_VERSION}:${INNODB_API_VERSION_REVISION}:${INNODB_API_VERSION_AGE}")

# Version Reporting
# ----------------
message(STATUS "INNODB_VERSION:            " ${INNODB_VERSION})
message(STATUS "INNODB_API_VERSION_STRING: " ${INNODB_API_VERSION_STRING})

