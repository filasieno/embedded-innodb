# ---------------------------------------------------------------------------------------------------------------------
# Library and API Versioning section
# ---------------------------------------------------------------------------------------------------------------------

# Define the version for Embedded InnoDB
set(VERSION "0.1")

# Define the API version
set(API_VERSION          6)   # Increment if interfaces have been added, removed or changed
set(API_VERSION_REVISION 0)   # Increment if source code has changed, set to zero if current is incremented
set(API_VERSION_AGE      0)   # Increment if interfaces have been added, set to zero if interfaces have been removed or changed

# API version string used in compile definitions later
set(IB_API_VERSION_STRING "${API_VERSION}:${API_VERSION_REVISION}:${API_VERSION_AGE}")
message(STATUS "VERSION:               " ${VERSION})
message(STATUS "IB_API_VERSION_STRING: " ${IB_API_VERSION_STRING})

