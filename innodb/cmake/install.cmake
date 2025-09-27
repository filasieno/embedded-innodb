# ---------------------------------------------------------------------------------------------------------------------
# Installation Configuration
# ---------------------------------------------------------------------------------------------------------------------
#
# This file configures the installation targets for Embedded InnoDB libraries and headers.
# It defines where built artifacts should be installed on the system.
#
# Installation targets:
# - innodb: Static library
# - innodb_shared: Shared library
# - innodb.h: Public API header
#
# Install locations (relative to CMAKE_INSTALL_PREFIX):
# - Libraries: lib/
# - Headers: include/

# Library Installation
# -------------------
# Install both static and shared library variants
install(TARGETS innodb innodb_shared
    ARCHIVE DESTINATION lib  # Static library (.a/.lib)
    LIBRARY DESTINATION lib  # Shared library (.so/.dll)
)

# Public Header Installation
# -------------------------
# Use FILE_SET for better header file management (CMake 3.23+)
# This provides better IDE integration and cleaner installation
target_sources(innodb PUBLIC FILE_SET HEADERS
    BASE_DIRS ${CMAKE_SOURCE_DIR}/innodb/include
    FILES ${CMAKE_SOURCE_DIR}/innodb/include/innodb.h
)

# Install headers using the FILE_SET
install(TARGETS innodb
    FILE_SET HEADERS DESTINATION include
)

# ---------------------------------------------------------------------------------------------------------------------
# End Installation Configuration
# ---------------------------------------------------------------------------------------------------------------------
