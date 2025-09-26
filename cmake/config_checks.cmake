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
configure_file(
    ${CMAKE_SOURCE_DIR}/cmake/config.h.cmake
    ${CMAKE_BINARY_DIR}/include/ib0config.h
)

# Include Flex and Bison CMake modules

# Generate Flex/Bison sources into the build tree (avoid polluting source dir)
set(GEN_PARS_DIR ${CMAKE_BINARY_DIR}/generated/pars)
file(MAKE_DIRECTORY ${GEN_PARS_DIR})

find_package(BISON REQUIRED)
BISON_TARGET(innodb_parser ${CMAKE_SOURCE_DIR}/innodb/src/pars/pars0grm.y  ${GEN_PARS_DIR}/pars0grm.cc DEFINES_FILE ${CMAKE_BINARY_DIR}/include/pars0grm.h VERBOSE ${GEN_PARS_DIR}/bison.log)
find_package(FLEX REQUIRED)
FLEX_TARGET(innodb_lexer   ${CMAKE_SOURCE_DIR}/innodb/src/pars/pars0lex.l  ${GEN_PARS_DIR}/lexyy.cc)
ADD_FLEX_BISON_DEPENDENCY(innodb_lexer innodb_parser)
include_directories(${CMAKE_BINARY_DIR}/include ${GEN_PARS_DIR})

add_library(innodb_sql OBJECT ${BISON_innodb_parser_OUTPUTS} ${FLEX_innodb_lexer_OUTPUTS})
target_link_libraries(innodb_sql PRIVATE innodb_pch)
set_target_properties(innodb_sql PROPERTIES FOLDER "innodb")
set_target_properties(innodb_sql PROPERTIES POSITION_INDEPENDENT_CODE ON)
set_property(GLOBAL APPEND PROPERTY INNODB_OBJ_TARGETS innodb_sql)

# ---------------------------------------------------------------------------------------------------------------------
# Configuration checks (to generate ib0config.h)
# ---------------------------------------------------------------------------------------------------------------------
