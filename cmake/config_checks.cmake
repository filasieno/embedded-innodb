# ---------------------------------------------------------------------------------------------------------------------
# Configuration checks (to generate ib0config.h)
# ---------------------------------------------------------------------------------------------------------------------

include(CheckTypeSize)
include(CheckIncludeFiles)

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

set(CMAKE_EXTRA_INCLUDE_FILES pthread.h)
check_type_size(pthread_t SIZEOF_PTHREAD_T)
set(CMAKE_EXTRA_INCLUDE_FILES)

check_include_files("stdint.h"            HAVE_STDINT_H)

# Objective: Generate configuration header used by sources during compilation
file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/include)
configure_file(${CMAKE_SOURCE_DIR}/cmake/config.h.cmake ${CMAKE_BINARY_DIR}/include/ib0config.h)
