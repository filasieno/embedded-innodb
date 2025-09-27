# ---------------------------------------------------------------------------------------------------------------------
# Build Configuration Checks and Header Generation
# ---------------------------------------------------------------------------------------------------------------------
#
# This file performs compile-time checks to detect system capabilities and generates
# the ib0config.h header file used throughout the codebase. The generated header contains
# preprocessor definitions that adapt the code to the target platform and available features.
#
# Checks performed:
# - Type sizes for cross-platform compatibility
# - Header file availability
# - Function availability
# - System-specific features
#
# Output: ${INNODB_PRIVATE_GENERATED_INCLUDE_DIR}/ib0config.h

# Required CMake Modules
# ----------------------
include(CheckTypeSize)
include(CheckIncludeFiles)

# Type Size Detection
# ------------------
# Check sizes of fundamental types for cross-platform compatibility
# These SIZEOF_* variables will be defined in ib0config.h
check_type_size(char                      SIZEOF_CHAR)
check_type_size("unsigned char"           SIZEOF_UCHAR)
check_type_size(short                     SIZEOF_SHORT)
check_type_size("unsigned short"          SIZEOF_USHORT)
check_type_size(int                       SIZEOF_INT)
check_type_size("unsigned int"            SIZEOF_UINT)
check_type_size(long                      SIZEOF_LONG)
check_type_size("unsigned long"           SIZEOF_ULONG)
check_type_size("long long int"           SIZEOF_LONG_LONG)
check_type_size("unsigned long long int"  SIZEOF_ULONG_LONG)
check_type_size(char*                     SIZEOF_CHARP)
check_type_size(void*                     SIZEOF_VOIDP)
check_type_size(off_t                     SIZEOF_OFF_T)

# Pthread Type Size
# -----------------
# Check pthread_t size with proper includes
set(CMAKE_EXTRA_INCLUDE_FILES pthread.h)
check_type_size(pthread_t SIZEOF_PTHREAD_T)
set(CMAKE_EXTRA_INCLUDE_FILES)

# Header File Detection
# --------------------
# Check for availability of standard and system headers
check_include_files("stdint.h"            HAVE_STDINT_H)

# System Capability Validation
# ---------------------------
# Validate that detected system capabilities meet minimum requirements

# Check for required C++ features
include(CheckCXXSourceCompiles)
check_cxx_source_compiles("
    #include <version>
    #ifdef __cpp_lib_atomic_ref
        int main() { return 0; }
    #else
        #error Atomic ref not available
    #endif
" HAS_CXX20_ATOMIC_REF)

if(NOT HAS_CXX20_ATOMIC_REF)
    message(WARNING "C++20 atomic_ref not available. Some optimizations may be disabled.")
endif()

# Check for thread support
include(CheckIncludeFileCXX)
check_include_file_cxx(pthread.h HAS_PTHREAD_H)
if(NOT HAS_PTHREAD_H)
    message(FATAL_ERROR "pthread.h is required but not found")
endif()

# Validate compiler capabilities
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS "11.0")
    message(WARNING "GCC 11.0+ recommended for best C++23 support")
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS "14.0")
    message(WARNING "Clang 14.0+ recommended for best C++23 support")
endif()

# Configuration Header Generation
# ------------------------------
# Generate ib0config.h from template with detected configuration values
file(MAKE_DIRECTORY ${INNODB_PRIVATE_GENERATED_INCLUDE_DIR})
configure_file(${CMAKE_SOURCE_DIR}/cmake/config.h.cmake ${INNODB_PRIVATE_GENERATED_INCLUDE_DIR}/ib0config.h)

# Validate generated configuration
if(NOT EXISTS ${INNODB_PRIVATE_GENERATED_INCLUDE_DIR}/ib0config.h)
    message(FATAL_ERROR "Failed to generate ib0config.h header file")
endif()
